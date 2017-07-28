#!/bin/bash

# Exit on failure
set -e

VERSION_STRING=__VERSION__

if [ -e build-artifacts ]; then
     echo Error: Deploy pipeline needs to create build-artifacts but already exists.
     exit 1
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

for file in `
find dist -type f \
\( -name "*.htm" \
-o -name "*.html" \
-o -name "*.css" \
-o -name "*.js" \
-o -name "*.json" \) \
-exec grep -l "$VERSION_STRING" {} \;`
do
    echo Replacing $VERSION_STRING with $sha in $file
    sed -i "s/$VERSION_STRING/$sha/g" $file
done

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

# If the deployment config file exists, read it.
if [ -f "deploy.config" ]; then
    read_deploy_config "deploy.config"

    # also copy the file to build-artifacts so that copy-to-s3.sh can use it
    echo "Copying deploy.config to build-artifacts/deploy.config"
    cp deploy.config build-artifacts/deploy.config
fi

echo Moving dist to build-artifacts/dist
mv dist build-artifacts/dist

if [ -z "$VERSION" ]; then
    dest=dist${PATH_PREFIX}
else
    dest=dist${PATH_PREFIX}/${VERSION}
fi

echo "Creating $dest directory"
mkdir -p $dest

echo Moving build-artifacts/dist/$VERSION_STRING to $dest/$sha
mv build-artifacts/dist/$VERSION_STRING $dest/$sha

echo "Moving build-artifacts/dist/* into $dest"
mv build-artifacts/dist/* $dest

echo Removing build-artifacts/dist
rm -r build-artifacts/dist

echo Creating build-artifacts/manifests${PATH_PREFIX} directory
mkdir -p build-artifacts/manifests${PATH_PREFIX}

if [ -z "${VERSION}" ]; then
    manifest_file=build-artifacts/manifests${PATH_PREFIX}/$sha.txt
else
    # Here we use ${VERSION}_$sha.txt instead of ${VERSION}/$sha.txt to make
    # clobbering detection logic easier.
    manifest_file=build-artifacts/manifests${PATH_PREFIX}/${VERSION}_$sha.txt
fi

echo Writing manifest to $manifest_file
find $dest -maxdepth 1 | grep -v "^${dest}$" > $manifest_file
