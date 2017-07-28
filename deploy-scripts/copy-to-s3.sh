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
SECOND_LEVEL_MAX_AGE=86400

function read_deploy_config {
    file=$1
    if [ -f "$file" ]; then
        echo "Importing $file"
        while IFS='=' read -r key value
        do
            echo "key=$key, value=$value"
            if [[ -n "$key" && ! $key =~ ^#.*$ && -n "$value" ]]; then
                eval "${key}='${value}'"
            fi
        done < "$file"
    fi
}

# Import the variables in deploy.config. This could override the default
# cache times specified above
read_deploy_config "build-artifacts/deploy.config"

echo "Reading path prefix from build-artifacts/path-prefix.txt"
path_prefix=`cat build-artifacts/path-prefix.txt`
echo "path prefix is \"$path_prefix\""

if [ -z "$VERSION" ]; then
    sha_file=dist$path_prefix/sha.txt
else
    sha_file=dist$path_prefix/${VERSION}/sha.txt
fi

echo "Reading Git sha from $sha_file"
sha=`cat $sha_file`
echo "Git sha is \"$sha\""

if [ -z "$LOCK_PHRASE" ]; then
    echo "No LOCK_PHRASE is provided in the environment"
    echo "Reading default lock phrase from build-artifacts/default-lock-phrase.txt"
    default_lock_phrase=`cat build-artifacts/default-lock-phrase.txt`
    echo "Default lock phrase is \"$default_lock_phrase\""

    if [ -z "$default_lock_phrase" ]; then
        echo "No default lock phrase is found. Deployment locking is disabled."
    else
        LOCK_PHRASE=$default_lock_phrase
        echo "LOCK_PHRASE is \"$LOCK_PHRASE\""
    fi
else
    echo "LOCK_PHRASE is \"$LOCK_PHRASE\""
fi

IFS=', ' read -r -a buckets <<< $S3_BUCKETS

# This function prepare the lock file to be uploaded to the specified bucket later.
# The actual upload will only happen if deployment checks for all buckets have passed.
function prepare_lock {
    bucket=$1
    lock_file="lock_file_${bucket}"
    echo "Preparing local path lock $lock_file for bucket $bucket"
    echo $LOCK_PHRASE > $lock_file
}

function create_lock {
    bucket=$1

    # Only when the local lock file exists we will upload the lock file to the target bucket.
    lock_file="lock_file_${bucket}"
    if [ -f "$lock_file" ]; then
        s3_lock_path="s3://$bucket/manifests$path_prefix/lock"
        echo "Creating path lock $s3_lock_path"
        aws s3 cp $lock_file $s3_lock_path
    fi
}

# Check if the specified path_prefix has a deployment in it.
# The function runs an "ls" command for the manifests/$path_prefix folder
# and see if there is a <sha>.txt file there
function check_deploy {
    # parameter $1: path_prefix
    path_prefix=$1
    count=`ls manifests$path_prefix | grep "^\([a-zA-Z0-9.-]\+_\)\?[a-f0-9]\+\\.txt$" | wc -l`
    echo $count
}

# Perform clobbering and lock check for all the buckets first.
# We will only push the contents if all buckets pass the checks

for bucket in "${buckets[@]}"
do
    echo ---------- Performing deployment checks on S3: $bucket ----------

    # Download manifests folder for deployment detection
    echo "Downloading manifests folder from s3://$bucket/manifests"
    rm -rf manifests
    aws s3 cp s3://$bucket/manifests manifests --recursive

    # check if there is already a deployment at exactly path_prefix
    deploy_check=`check_deploy $path_prefix`
    lock_file_path="manifests$path_prefix/lock"

    if [ $deploy_check -gt 0 ]; then
        # There is a deployment at path_prefix.
        if [ -z "$LOCK_PHRASE" ]; then
            # If locking is disabled, just allow deployment.
            # However, no lock file will be generated.
            echo "Deployment locking is disabled -- allowing deployment"

        elif [ -f "$lock_file_path" ]; then
            # The lock file also exists. we will allow the deployment if the content of
            # the lock file match the git repo url.
            lock_content=`cat $lock_file_path`
            if [ "$LOCK_PHRASE" != "$lock_content" ]; then
                echo "The path lock for prefix \"$path_prefix\" does not match the lock phrase -- aborting deployment"
                exit 1
            fi
            echo "Deployment path $path_prefix exists, and its path lock matches the lock phrase -- allowing deployment"
        else
            # The lock file does not exist. create one in this case and allow the deployment.
            echo "Deployment path $path_prefix exists, but its path lock does not exist -- allowing deployment"
            prepare_lock $bucket
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
        prepare_lock $bucket
    fi
done

# If the script reaches here, all buckets has passed the deployment checks.
# We are going to push the contents to those buckets.

for bucket in "${buckets[@]}"
do
    echo ---------- Pushing to S3: $bucket ----------
    create_lock $bucket

    if [ -z "$VERSION" ]; then
        dist_src=dist$path_prefix
        s3_dest=s3://$bucket/dist$path_prefix
        manifest_src=build-artifacts/manifests$path_prefix/$sha.txt
        manifest_dest=s3://$bucket/manifests$path_prefix/$sha.txt
    else
        dist_src=dist$path_prefix/${VERSION}
        s3_dest=s3://$bucket/dist$path_prefix/${VERSION}
        manifest_src=build-artifacts/manifests$path_prefix/${VERSION}_$sha.txt
        manifest_dest=s3://$bucket/manifests$path_prefix/${VERSION}_$sha.txt
    fi

    echo "--- Pushing $dist_src/$sha/* into $s3_dest with max-age=$SECOND_LEVEL_MAX_AGE ---"
    aws s3 cp $dist_src/$sha $s3_dest/$sha --recursive --cache-control max-age=$SECOND_LEVEL_MAX_AGE

    # Push top level assets AFTER pushing sha assets so we don't publish a reference to sha assets before they're available
    echo "--- Pushing $dist_src/* (excluding $dist_src/$sha and $dist_src/sha.txt) into $s3_dest with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp $dist_src $s3_dest --recursive --exclude $sha/* --exclude sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing $dist_src/sha.txt to $s3_dest/sha.txt with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp $dist_src/sha.txt $s3_dest/sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing $manifest_src to $manifest_dest ---"
    aws s3 cp $manifest_src $manifest_dest
done

