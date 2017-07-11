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
git_repo=`git ls-remote --get-url`

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

echo "Writing git repo url \"$git_repo\" to build-artifacts/git-repo.txt"
echo $git_repo > build-artifacts/git-repo.txt

echo "Writing path prefix \"$PATH_PREFIX\" to build-artifacts/path-prefix.txt"
echo $PATH_PREFIX > build-artifacts/path-prefix.txt

echo Moving dist to build-artifacts/dist
mv dist build-artifacts/dist

echo Creating dist${PATH_PREFIX} directory
mkdir -p dist${PATH_PREFIX}

echo Moving build-artifacts/dist/$VERSION_STRING to dist${PATH_PREFIX}/$sha
mv build-artifacts/dist/$VERSION_STRING dist${PATH_PREFIX}/$sha

echo "Moving build-artifacts/dist/* into dist${PATH_PREFIX}"
mv build-artifacts/dist/* dist${PATH_PREFIX}

echo Removing build-artifacts/dist
rm -r build-artifacts/dist

echo Creating build-artifacts/manifests${PATH_PREFIX} directory
mkdir -p build-artifacts/manifests${PATH_PREFIX}

echo Writing manifest to build-artifacts/manifests${PATH_PREFIX}/$sha.txt
find dist${PATH_PREFIX} -maxdepth 1 | grep -v "^dist${PATH_PREFIX}$" > build-artifacts/manifests${PATH_PREFIX}/$sha.txt
