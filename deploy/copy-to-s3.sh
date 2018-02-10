#!/bin/bash

# Exit on failure
set -e

# Disable file name expansion
set -f

if [ -z "$S3_BUCKETS" ]; then
    echo Error: S3_BUCKETS not specified
    exit 1
fi

echo Preparing environment

# Get the path of this script.
pushd . > /dev/null
script_path="${BASH_SOURCE[0]}";
if [ -h "${script_path}" ]; then
    while [ -h "${script_path}" ]; do
        cd `dirname "$script_path"`; script_path=`readlink "${script_path}"`
    done
fi
cd `dirname ${script_path}` > /dev/null
script_path=`pwd`;
popd  > /dev/null


# Include the deploy-utils.sh file
echo "Loading $script_path/deploy-utils.sh"
. $script_path/deploy-utils.sh

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


# Import the variables in deploy.config. This could override the default
# cache times specified above
read_deploy_config "build-artifacts/deploy.config"

if [ "$rollback" == "true" ]; then
    read_deploy_config /prev-deploy/build-artifacts/deploy.config "PREV_"
fi

echo "Reading path prefix from build-artifacts/path-prefix.txt"
path_prefix=`cat build-artifacts/path-prefix.txt`
echo "path prefix is \"$path_prefix\""

sha_file=dist$path_prefix/sha.txt
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


# Perform clobbering and lock check for all the buckets first.
# We will only push the contents if all buckets pass the checks

IFS=', ' read -r -a buckets <<< $S3_BUCKETS

for bucket in "${buckets[@]}"
do
    validate_path_prefix $bucket $path_prefix
done

# Determine the version string being used for this deployment
if [ -z "$VERSION" ]; then
    version_string=$sha
else
    version_string=$VERSION
fi

# If it is a rollback Determine the previous version string being used
prev_version_string=''
if [ "$rollback" == "true" ]; then
    if [ -z "$PREV_VERSION" ]; then
        prev_version_string=$previous_sha
    else
        prev_version_string=$PREV_VERSION
    fi
fi

# At this point, we are sure the project is the rightful owner of the destination path.
# We still need to verify if the content of $version_string/sha.txt matches the project's current sha.
# Here we use "aws s3api list-object-v2" command instead of "aws s3 ls" command because the latter
# will return a return code 1 when the target file does not exist, and the non-zero return code will
# fail the whole script. If the remote sha.txt file does not exist, the former command outputs
# nothing and returns 0, which is exactly what we want.
version_sha_path=$path_prefix/$version_string/sha.txt
sha_check=$(check_s3_object $bucket dist$version_sha_path)
if [ -n "$sha_check" ]; then
    # Download the sha.txt file
    aws s3 cp s3://$bucket/dist$version_sha_path sha.txt
    remote_sha=`cat sha.txt`
    if [ "$sha" != "$remote_sha" ]; then
        echo "The current sha '$sha' does not match the content of $version_sha_path '$remote_sha' -- aborting deployment"
        exit 1
    else
        echo "The current sha '$sha' match the content of $version_sha_path"
    fi
else
    echo "$version_sha_path does not exist in the remote store."
fi

# If the script reaches here, all buckets has passed the deployment checks.
# We are going to push the contents to those buckets.

# If mime.types file is provided in the project, append it to /etc/mime.types
if [ -f "build-artifacts/mime.types" ]; then
    echo "Adding the following MIME types to /etc/mime.types"
    cat build-artifacts/mime.types
    cat build-artifacts/mime.types >> /etc/mime.types
fi

# Exclude the test folder (at the top level, directly under the version folder,
# and directly under any other folder marked as second-level) except if the
# $DEPLOY_TEST_FOLDERS variable is non-empty.
exclude_test_folder_arg='--exclude test/*'
if [ -n "$DEPLOY_TEST_FOLDERS" ]; then
    exclude_test_folder_arg=''
fi

# This variable will accumulate the "--exclude xxx" arguments needed for the AWS CLI
# to exclude the gzipped files when we push non-gzipped files to S3.
exclude_gzip_files_arg=''

# Similar to the above, but this variable will accumulate the "--include xxx"
# arguments needed for the AWS CLI to only include the gzipped files when we push
# the gzipped files to S3. We need to push those files separately because we need
# to specify the "--content-encoding gzip" argument when we push them.
include_gzip_files_arg=''

dist_src=dist$path_prefix
manifest_src=build-artifacts/manifests$path_prefix/$version_string.txt

# Handle file compression first
if [ -n "$EXPLICIT_GZIP_EXTENSIONS" ]; then
    IFS=', ' read -r -a compressFileTypes <<< $EXPLICIT_GZIP_EXTENSIONS
    for fileType in "${compressFileTypes[@]}"
    do
        exclude_gzip_files_arg="$exclude_gzip_files_arg --exclude *.$fileType"
        include_gzip_files_arg="$include_gzip_files_arg --include *.$fileType"
        for file in `find -L $dist_src -type f -name "*.$fileType"`
        do
            echo "--- Compressing $file ---"
            # zip the file in-place and rename it back to its original name
            gzip $file
            mv ${file}.gz $file
        done
    done
fi

for bucket in "${buckets[@]}"
do
    # If it is a rollback deployment, rename the manifest file as <file>.rollback.txt
    if [ "$rollback" == "true" ]; then
        echo "-- It's a rollback depoyment. Renaming the manifest file for the previous deployment --"
        prev_manifest="manifests$path_prefix/$prev_version_string.txt"
        prev_manifest_check=$(check_s3_object $bucket $prev_manifest)
        if [ -n "$prev_manifest_check" ]; then
            echo "-- Renaming s3://$bucket/$prev_manifest as s3://$bucket/manifests$path_prefix/$prev_version_string.rollback.txt --"
            aws s3 mv s3://$bucket/$prev_manifest s3://$bucket/manifests$path_prefix/$prev_version_string.rollback.txt
        else
            echo "s3://$bucket$prev_manifest does not exist"
        fi
    fi

    echo ---------- Pushing to S3: $bucket ----------
    create_lock $bucket $path_prefix

    s3_dest=s3://$bucket/dist$path_prefix
    manifest_dest=s3://$bucket/manifests$path_prefix/$version_string.txt

    # This variable will accumulate the "--exclude xxx" arguments needed for the AWS CLI to
    # exclude folders that we push first with long cache time when we push the top level assets.
    top_level_exclude_folders_arg=''

    if [ -d "$dist_src/$version_string" ]; then
        # Push the files under the $version_string folder, excluding sha.txt,
        # compressed files if any, and test folder accordingly
        echo "--- Pushing $dist_src/$version_string/* (--exclude sha.txt $exclude_gzip_files_arg $exclude_test_folder_arg) into $s3_dest with max-age=$SECOND_LEVEL_MAX_AGE ---"
        aws s3 cp $dist_src/$version_string $s3_dest/$version_string \
            --exclude sha.txt \
            $exclude_gzip_files_arg \
            $exclude_test_folder_arg \
            --recursive \
            --cache-control "max-age=$SECOND_LEVEL_MAX_AGE, must-revalidate"

        if [ -n "$include_gzip_files_arg" ]; then
            # Push the compressed files under the $version_string folder
            # and exclude test folder accordingly
            echo "--- Pushing $dist_src/$version_string/* (--exclude * $include_gzip_files_arg $exclude_test_folder_arg) into $s3_dest with max-age=$SECOND_LEVEL_MAX_AGE and content-encoding=gzip ---"
            aws s3 cp $dist_src/$version_string $s3_dest/$version_string \
                --exclude '*' \
                $include_gzip_files_arg \
                $exclude_test_folder_arg \
                --recursive \
                --cache-control "max-age=$SECOND_LEVEL_MAX_AGE, must-revalidate" \
                --content-encoding gzip
        fi

        top_level_exclude_folders_arg="--exclude $version_string/*"
    fi

    # If the user has specified SECOND_LEVEL_FOLDERS in deploy.config, push those folders with long cache time.
    if [ -n "$SECOND_LEVEL_FOLDERS" ]; then
        IFS=', ' read -r -a long_cache_folders <<< $SECOND_LEVEL_FOLDERS
        for folder in "${long_cache_folders[@]}"
        do
            if [ -d "$dist_src/$folder" ]; then
                # Push the files under the long-cached folder, excluding compressed files if any,
                # and exclude test folder accordingly.
                echo "--- Pushing $dist_src/$folder/* ($exclude_gzip_files_arg $exclude_test_folder_arg) into $s3_dest with max-age=$SECOND_LEVEL_MAX_AGE ---"
                aws s3 cp $dist_src/$folder $s3_dest/$folder \
                    $exclude_gzip_files_arg \
                    $exclude_test_folder_arg \
                    --recursive \
                    --cache-control "max-age=$SECOND_LEVEL_MAX_AGE, must-revalidate"

                if [ -n "$include_gzip_files_arg" ]; then
                    # Push the compressed file under the long cached folder
                    # and exclude test folder accordingly.
                    echo "--- Pushing $dist_src/$folder/* (--exclude * $include_gzip_files_arg $exclude_test_folder_arg) into $s3_dest with max-age=$SECOND_LEVEL_MAX_AGE and content-encoding=gzip ---"
                    aws s3 cp $dist_src/$folder $s3_dest/$folder \
                        --exclude '*' \
                        $include_gzip_files_arg \
                        $exclude_test_folder_arg \
                        --recursive \
                        --cache-control "max-age=$SECOND_LEVEL_MAX_AGE, must-revalidate" \
                        --content-encoding gzip
                fi

                top_level_exclude_folders_arg="$top_level_exclude_folders_arg --exclude $folder/*"
            else
                echo "Second level folder $dist_src/$folder does not exist!"
            fi
        done
    fi

    # Push top level assets AFTER pushing 2nd level assets so we don't publish a
    # reference to 2nd level assets before they're available.
    # Exclude sha.txt and compressed files if any, and exclude test folder accordingly.
    echo "--- Pushing $dist_src/* ($top_level_exclude_folders_arg $exclude_gzip_files_arg $exclude_test_folder_arg --exclude sha.txt) into $s3_dest with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp $dist_src $s3_dest \
        --recursive \
        $top_level_exclude_folders_arg \
        $exclude_gzip_files_arg \
        $exclude_test_folder_arg \
        --exclude sha.txt \
        --cache-control "max-age=$TOP_LEVEL_MAX_AGE, must-revalidate"

    if [ -n "$include_gzip_files_arg" ]; then
        # Push compressed files not in the $version_string folder and long cached folders,
        # and exclude test folder accordingly.
        echo "--- Pushing $dist_src/* (--exclude '*' $include_gzip_files_arg $top_level_exclude_folders_arg $exclude_test_folder_arg --exclude sha.txt) into $s3_dest with max-age=$TOP_LEVEL_MAX_AGE and content-encoding=gzip ---"
        aws s3 cp $dist_src $s3_dest \
            --recursive \
            --exclude '*' \
            $include_gzip_files_arg \
            $top_level_exclude_folders_arg \
            $exclude_test_folder_arg \
            --exclude sha.txt \
            --cache-control "max-age=$TOP_LEVEL_MAX_AGE, must-revalidate" \
            --content-encoding gzip
    fi

    if [ -f "$dist_src/$version_string/sha.txt" ]; then
        echo "--- Pushing $dist_src/$version_string/sha.txt to $s3_dest/$version_string/sha.txt with max-age=$SECOND_LEVEL_MAX_AGE ---"
        aws s3 cp $dist_src/$version_string/sha.txt $s3_dest/$version_string/sha.txt \
            --cache-control "max-age=$SECOND_LEVEL_MAX_AGE, must-revalidate"
    fi

    echo "--- Pushing $dist_src/sha.txt to $s3_dest/sha.txt with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp $dist_src/sha.txt $s3_dest/sha.txt \
        --cache-control "max-age=$TOP_LEVEL_MAX_AGE, must-revalidate"

    echo "--- Pushing $manifest_src to $manifest_dest ---"
    aws s3 cp $manifest_src $manifest_dest
done

