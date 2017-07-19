#!/bin/bash

# Exit on failure
set -e

if [ -z "$S3_BUCKETS" ]; then
    echo Error: S3_BUCKETS not specified
    exit 1
fi

echo Preparing environment

rm -rf ~/.aws
mkdir ~/.aws

cat > ~/.aws/config << EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
aws_session_token = $AWS_SESSION_TOKEN
EOF

if [ -n "$AWS_ROLE" ]; then
    echo CLI will assume role $AWS_ROLE

    # append the role
    cat >> ~/.aws/config << EOF
role_arn = $AWS_ROLE
source_profile = default
EOF

fi

# These need to be unset for the CLI to read config from ~/.aws/config
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

TOP_LEVEL_MAX_AGE=60
VERSIONED_MAX_AGE=86400

echo "Reading path prefix from build-artifacts/path-prefix.txt"
path_prefix=`cat build-artifacts/path-prefix.txt`
echo "path prefix is \"$path_prefix\""

echo "Reading Git sha from dist$path_prefix/sha.txt"
sha=`cat dist$path_prefix/sha.txt`
echo "Git sha is \"$sha\""

echo "Reading git repo URL from build-artifacts/git-repo.txt"
git_repo=`cat build-artifacts/git-repo.txt`
echo "Git repo URL is \"$git_repo\""

if [ -z "$LOCK_PHRASE" ]; then
    echo "No LOCK_PHRASE is provided in the environment. Using Git repo URL."
    LOCK_PHRASE=$git_repo
fi
echo "LOCK_PHRASE is \"$LOCK_PHRASE\""

IFS=', ' read -r -a buckets <<< $S3_BUCKETS

function create_lock {
    # parameter $1: path_prefix
    s3_lock_path="s3://$bucket/manifests$path_prefix/lock"
    echo "Creating path lock $s3_lock_path"
    echo $LOCK_PHRASE > lock_file
    aws s3 cp lock_file $s3_lock_path
}

# Check if the specified path_prefix has a deployment in it.
# The function runs an "ls" command for the manifests/$path_prefix folder
# and see if there is a <sha>.txt file there
function check_deploy {
    # parameter $1: path_prefix
    path_prefix=$1
    count=`ls manifests/$path_prefix | grep "[a-f0-9]\{7\}\\.txt" | wc -l`
    echo $count
}

for bucket in "${buckets[@]}"
do
    # Download manifests folder for deployment detection
    rm -rf manifests
    aws s3 cp s3://$bucket/manifests manifests --recursive

    # Make sure the path_prefix belongs to this git repo
    echo "Checking deployment locks in $bucket"

    # check if there is already a deployment at exactly path_prefix
    deploy_check=`check_deploy $path_prefix`
    lock_file_path="manifests$path_prefix/lock"

    if [ $deploy_check -gt 0 ]; then
        # There is a deployment at path_prefix. check if the lock file exists.
        if [ -f "$lock_file_path" ]; then
            # The lock file also exists. we will allow the deployment if the content of
            # the lock file match the git repo url.
            lock_content=`cat $lock_file_path`
            if [ "$LOCK_PHRASE" != "$lock_content" ]; then
                echo "The path prefix \"$path_prefix\" does not belongs to repo $git_repo"
                exit 1
            fi
            echo "Deployment path $path_prefix exists, and it belong to repo $git_repo -- allowing deployment"
        else
            # The lock file does not exist. create one in this case and allow the deployment.
            echo "Deployment path $path_prefix exists, but path lock does not exist -- allowing deployment"
            create_lock $lock_file_path
        fi
    elif [ -d "manifests$path_prefix" ]; then
        # No deployment at the path, but the path does exist, which means the path must be
        # some other projects' descendant or ancestor. we don't allow this case.
        echo "Deployment path $path_prefix is a descendant or ancestor of 1 or more projects' deployment path -- aborting deployment"
        exit 1
    else
        # No deployment at the path, and the path does not exist, we need to check if there is any
        # deployment at the path's ancestor folders
        IFS='/ ' read -r -a path_parts <<< $path_prefix
        ancestor_path=""
        num_path_parts=${#path_parts[@]}
        for index in "${!path_parts[@]}"
        do
            if [ ! -z ${path_parts[index]} ] && [ $index -lt $((num_path_parts-1)) ]; then
                ancestor_path="$ancestor_path/${path_parts[index]}"
                deploy_check=`check_deploy $ancestor_path`
                if [ $deploy_check -gt 0 ]; then
                    # Found a deployment in an ancestor path. Aborting deployment
                    echo "Deployment path $path_prefix is a descendant of the deployment at $ancestor_path -- aborting deployment"
                    exit 1
                fi
            fi
        done

        # No existing deployment at the path prefix and no conflict cases found.
        # Create the lock file and allow the deployment.
        echo "Deployment path $path_prefix does not exist and no conflicts found -- allowing deployment"
        create_lock $lock_file_path
    fi

    echo ---------- Pushing to S3: $bucket ----------

    echo "--- Pushing dist$path_prefix/$sha/* into dist$path_prefix/$sha with max-age=$VERSIONED_MAX_AGE ---"
    aws s3 cp dist$path_prefix/$sha s3://$bucket/dist$path_prefix/$sha --recursive --cache-control max-age=$VERSIONED_MAX_AGE

    # Push top level assets AFTER pushing sha assets so we don't publish a reference to sha assets before they're available
    echo "--- Pushing dist$path_prefix/* (excluding dist$path_prefix/$sha and dist$path_prefix/sha.txt) into dist$path_prefix with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp dist$path_prefix s3://$bucket/dist$path_prefix --recursive --exclude $sha/* --exclude sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing dist$path_prefix/sha.txt to dist$path_prefix/sha.txt with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp dist$path_prefix/sha.txt s3://$bucket/dist$path_prefix/sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing build-artifacts/manifests$path_prefix/$sha.txt to manifests$path_prefix/$sha.txt ---"
    aws s3 cp build-artifacts/manifests$path_prefix/$sha.txt s3://$bucket/manifests$path_prefix/$sha.txt
done

