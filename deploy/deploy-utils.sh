#!/usr/bin/env bash
#
# This script is intended to be sourced instead of executed directly.

# This function read the deploy.config file at the specified path and convert
# the key-vaue pairs into environment variable-value pairs.
# Parameters:
# $1=file: path to the deploy.config file to be read
#
function read_deploy_config {
    file=$1

    # Append a newline at the end of the file so that all lines can be correctly read
    echo "" >> $file

    if [ -f "$file" ]; then
        echo "Importing $file"
        while IFS='= ' read -r key value
        do
            value=`echo $value | tr -d '\r'`
            echo "key=$key, value=$value"
            if [[ -n "$key" && ! $key =~ ^#.*$ && -n "$value" ]]; then
                eval "${key}='${value}'"
            fi
        done < "$file"
    fi
}

# This function prepare the lock file to be uploaded to the specified bucket later.
# The actual upload will only happen if deployment checks for all buckets have passed.
# Parameters:
# $1=bucket: the name of the target S3 bucket to which the lock file is to be uploaded
#
function prepare_lock {
    bucket=$1
    lock_file="lock_file_${bucket}"
    echo "Preparing local path lock $lock_file for bucket $bucket"
    echo $LOCK_PHRASE > $lock_file
}

# This function create a lock file specified path_prefix on the target S3 bucket.
# Parameters:
# $1=bucket: the name of the target S3 bucket to which the lock file is to be created
# $2=path_prefix: the path prefix for the deployment
function create_lock {
    bucket=$1
    path_prefix=$2

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
# and see if there is a <sha>.txt file there.
# $1=path_prefix:  the path prefix for the deployment
function check_deploy {
    # parameter $1: path_prefix
    path_prefix=$1
    count=`ls manifests$path_prefix | grep "^.\+\\.txt$" | wc -l`
    echo $count
}

# Check if the s3 object with the specified prefix exists. If the object
# exists, an non-empty string is returned
function check_s3_object {
    bucket=$1
    obj_prefix=$2
    obj_check=`aws s3api list-objects-v2 --bucket $bucket --prefix $obj_prefix`
    echo "$obj_check"
}

# Validate if the path_prefix being used is a valid one, that is, not
# clobbering any other deployments.
# Parameters:
# $1=bucket: the target S3 bucket
# $2=path_prefix: the path_prefix for this deployment
function validate_path_prefix {
    bucket=$1
    path_prefix=$2

    echo ---------- Validating path_prefix $path_prefix on S3: $bucket ----------

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
                echo "The current path lock content for prefix \"$path_prefix\": $lock_content"
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
}