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

echo Reading path prefix from build-artifacts/path-prefix.txt
path_prefix=`cat build-artifacts/path-prefix.txt`
echo "path prefix is \"$path_prefix\""

echo Reading Git sha from dist$path_prefix/sha.txt
sha=`cat dist$path_prefix/sha.txt`
echo "Git sha is \"$sha\""

echo Reading Git repo URL from build-artifacts/git-repo.txt
git_repo=`cat build-artifacts/git-repo.txt`
echo "Git repo URL is \"$git_repo\""

IFS=', ' read -r -a buckets <<< $S3_BUCKETS

function create_lock {
    echo "Creating path lock s3://$bucket/locks$path_prefix/lock"
    echo $git_repo > path.lock
    aws s3 cp path.lock s3://$bucket/locks$path_prefix/lock
}

function s3_object_exists {
    # It is tricky to check if an S3 object exists. There is no explicit S3
    # command for that purpose. Here we use the "ls" command. However,
    # "ls s3://<bucket><s3_path>" will show any objects prefixed with s3_path. For example,
    # "ls s3://cdn-ue1-preview/dist/abc" will show /dist/abc, /dist/abcde, /dist/abcdef, etc.
    # Therefore, we will need to only count the exact object name listed in the output.
    # Another tricky thing is, if the object is a folder, the output is like this:
    #                            PRE cdnexample/
    # but if the object is a file, the output is like this:
    # 2017-07-10 22:01:30          8 sha.txt
    # That is, for folders, the object name is at column 2 with a trailing "/", and for
    # files, the object name is at column 4. The logic below is based on the above facts.

    obj_path=`echo $1 | sed 's/\(.*\)\/\([^/]*\)/\1/'`
    obj_name=`echo $1 | sed 's/\(.*\)\/\([^/]*\)/\2/'`
    count=$(aws s3 ls s3://$bucket$obj_path/$obj_name | \
        awk -v re=$obj_name"/" "{ if (\$4 == \"${obj_name}\") print \$4; else if (\$2 ~ re) print \$2 }" | wc -l)
    echo $count
}

for bucket in "${buckets[@]}"
do
    # Make sure the path_prefix belongs to this git repo
    echo "Checking deployment locks in $bucket"

    # check if there is already a deployment at exactly path_prefix
    path_check=`s3_object_exists /dist$path_prefix`
    deploy_check=`s3_object_exists /dist$path_prefix/sha.txt`
    lock_check=`s3_object_exists /locks$path_prefix/lock`

    if [ $deploy_check -gt 0 ]; then
        # There is a deployment at path_prefix. check if the lock file exists.
        if [ $lock_check -gt 0 ]; then
            # The lock file also exists. we will allow the deployment if the content of
            # the lock file match the git repo url.
            aws s3 cp s3://$bucket/locks$path_prefix/lock path.lock
            lock_content=`cat path.lock`
            if [ "$git_repo" != "$lock_content" ]; then
                echo "The path prefix \"$path_prefix\" does not belongs to repo $git_repo"
                exit 1
            fi
            echo "Deployment path $path_prefix exists, and it belong to repo $git_repo -- allowing deployment"
        else
            # The lock file does not exist. create one in this case and allow the deployment.
            echo "Deployment path $path_prefix exists, but path lock does not exist -- allowing deployment"
            create_lock
        fi
    elif [ $path_check -gt 0 ]; then
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
                deploy_check=`s3_object_exists /dist$ancestor_path/sha.txt`
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
        create_lock
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

