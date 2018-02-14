#!/bin/bash

# Exit on failure
set -e

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


VERSION_PLACEHOLDER=__VERSION__

if [ -e build-artifacts ]; then
     rm -rf build-artifacts
fi

if [ -e dist/sha.txt ]; then
     echo Error: Deploy pipeline needs to create dist/sha.txt but already exists.
     exit 1
fi

echo Determining Git sha and repo url
sha=`git rev-parse --short HEAD`
default_lock_phrase=`git ls-remote --get-url` || echo "No remote repo found. Default lock phrase is empty."

echo "Writing Git sha \"$sha\" to dist/sha.txt"
echo $sha > dist/sha.txt

# Make sure PATH_PREFIX has a leading /
if [[ "${PATH_PREFIX:0:1}" != "/" ]]; then
    PATH_PREFIX="/$PATH_PREFIX"
fi

# Make sure PATH_PREFIX does not have a trailing /
# If, at this point, it is just a single /, we change it to the empty string
if [[ "${PATH_PREFIX: -1}" == "/" ]]; then
    PATH_PREFIX="${PATH_PREFIX::-1}"
fi

echo Creating build-artifacts directory
mkdir build-artifacts

echo "Writing git repo url \"$default_lock_phrase\" to build-artifacts/default-lock-phrase.txt"
echo $default_lock_phrase > build-artifacts/default-lock-phrase.txt

echo "Writing path prefix \"$PATH_PREFIX\" to build-artifacts/path-prefix.txt"
echo $PATH_PREFIX > build-artifacts/path-prefix.txt

echo "Copying copy-to-s3.sh & deploy-utils.sh to build-artifacts"
cp /scripts/static-deploy/copy-to-s3.sh build-artifacts
cp /scripts/static-deploy/deploy-utils.sh build-artifacts

# If the deployment config file exists, copy the file to build-artifacts and read it.
if [ -f "deploy.config" ]; then
    # Copy the file to build-artifacts so that copy-to-s3.sh can use it.
    echo "Copying deploy.config to build-artifacts/deploy.config"
    cp deploy.config build-artifacts/deploy.config

    read_deploy_config "build-artifacts/deploy.config"
fi

# Determine the version string based on the VERSION variable value in deploy.config we just read.
# If it is not defined, use the git sha value.
if [ -z "$VERSION" ]; then
    version_string=$sha
else
    version_string=$VERSION
fi

if [ -d "dist/$VERSION_PLACEHOLDER" ]; then
    if [ -e dist/$VERSION_PLACEHOLDER/sha.txt ]; then
         echo Error: Deploy pipeline needs to create dist/$VERSION_PLACEHOLDER/sha.txt but already exists.
         exit 1
    fi
    echo "Writing Git sha \"$sha\" to dist/$VERSION_PLACEHOLDER/sha.txt"
    echo $sha > dist/$VERSION_PLACEHOLDER/sha.txt

    for file in `
    find -L dist -type f \
    \( -name "*.htm" \
    -o -name "*.html" \
    -o -name "*.css" \
    -o -name "*.js" \
    -o -name "*.json" \) \
    -exec grep -l "$VERSION_PLACEHOLDER" {} \;`
    do
        echo Replacing $VERSION_PLACEHOLDER with $version_string in $file
        sed -i "s/$VERSION_PLACEHOLDER/$version_string/g" $file
    done
fi

# If mime.types file exists, copy it
if [ -f "mime.types" ]; then
    echo "Copying mime.types to build-artifacts/mime.types"
    cp mime.types build-artifacts/mime.types
fi

echo Moving dist to build-artifacts/dist
mv dist build-artifacts/dist

dest=dist${PATH_PREFIX}
echo "Creating $dest directory"
mkdir -p $dest

if [ -d "build-artifacts/dist/$VERSION_PLACEHOLDER" ]; then
    echo Moving build-artifacts/dist/$VERSION_PLACEHOLDER to $dest/$version_string
    mv build-artifacts/dist/$VERSION_PLACEHOLDER $dest/$version_string
fi

echo "Moving build-artifacts/dist/* into $dest"
mv build-artifacts/dist/* $dest

echo Removing build-artifacts/dist
rm -r build-artifacts/dist

echo Creating build-artifacts/manifests${PATH_PREFIX} directory
manifest_dir=build-artifacts/manifests${PATH_PREFIX}
mkdir -p $manifest_dir

# Capture a list of all files to be deployed into the menifest file.
# Follow symbolic links, like the S3 CLI does during upload.
manifest_file=$manifest_dir/$version_string.txt
echo Writing manifest to $manifest_file
find -L $dest -type f > $manifest_file
