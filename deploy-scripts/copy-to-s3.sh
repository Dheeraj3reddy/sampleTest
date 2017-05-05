#!/bin/bash

# Exit on failure
set -e

if [ -z "$S3_BUCKETS" ]; then
    echo Error: S3_BUCKETS not specified
    exit 1
fi

if [ -n "$AWS_ROLE" ]; then
    echo Preparing CLI to assume role $AWS_ROLE
    mkdir ~/.aws

    cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
aws_session_token=$AWS_SESSION_TOKEN
EOF

    cat > ~/.aws/config << EOF
[profile deploy]
role_arn = $AWS_ROLE
source_profile = default
EOF

    export AWS_DEFAULT_PROFILE=deploy
fi

TOP_LEVEL_MAX_AGE=60
VERSIONED_MAX_AGE=86400

echo Reading path prefix from build-artifacts/path-prefix.txt
path_prefix=`cat build-artifacts/path-prefix.txt`
echo "path prefix is \"$path_prefix\""

echo Reading Git sha from dist$path_prefix/sha.txt
sha=`cat dist$path_prefix/sha.txt`
echo "Git sha is \"$sha\""

IFS=', ' read -r -a buckets <<< $S3_BUCKETS

for bucket in "${buckets[@]}"
do
    echo ---------- Pushing to S3: $bucket ----------

    echo "--- Pushing dist$path_prefix/$sha/* into dist$path_prefix/$sha with max-age=$VERSIONED_MAX_AGE ---"
    aws s3 cp --profile=deploy dist$path_prefix/$sha s3://$bucket/dist$path_prefix/$sha --recursive --cache-control max-age=$VERSIONED_MAX_AGE

    # Push top level assets AFTER pushing sha assets so we don't publish a reference to sha assets before they're available
    echo "--- Pushing dist$path_prefix/* (excluding dist$path_prefix/$sha and dist$path_prefix/sha.txt) into dist$path_prefix with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp --profile=deploy dist$path_prefix s3://$bucket/dist$path_prefix --recursive --exclude $sha/* --exclude sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing dist$path_prefix/sha.txt to dist$path_prefix/sha.txt with max-age=$TOP_LEVEL_MAX_AGE ---"
    aws s3 cp --profile=deploy dist$path_prefix/sha.txt s3://$bucket/dist$path_prefix/sha.txt --cache-control max-age=$TOP_LEVEL_MAX_AGE

    echo "--- Pushing build-artifacts/manifests$path_prefix/$sha.txt to manifests$path_prefix/$sha.txt ---"
    aws s3 cp --profile=deploy build-artifacts/manifests$path_prefix/$sha.txt s3://$bucket/manifests$path_prefix/$sha.txt
done

