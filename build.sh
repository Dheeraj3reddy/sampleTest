#!/bin/bash -e

# This script is responsible for building the project's static content.
#
# Developers are free to alter the build process, even significantly, as long
# as they ensure:
# - Their build produces a dist folder
# - Their entry point asset exists at the top of dist
# - All child assets are placed in dist/__VERSION__
#
# They also must acknowledge that at deploy time:
# - The string __VERSION__ will be replaced in all of their assets with a
#   string unique to the deployment
# - The contents of the dist/__VERSION__ folder will be deployed to a new
#   subfolder of dist in the S3 bucket named using that same unique string
# - Any files under dist/__VERSION__ will be assigned a long cache time
#   (default 1 day). All other files will be assigned a short cache time
#   (default 1 minute).

# Getting "_auth" and "email" values from Artifactory for .npmrc file.
# Assumption: ARTIFACTORY_USER and ARTIFACTORY_API_TOKEN need to have
# already been defined in the environment.
auth=$(curl -u$ARTIFACTORY_USER:$ARTIFACTORY_API_TOKEN https://artifactory.corp.adobe.com/artifactory/api/npm/auth)
export NPM_AUTH=$(echo "$auth" | grep "_auth" | awk -F " " '{ print $3 }')
export NPM_EMAIL=$(echo "$auth" | grep "email" | awk -F " " '{ print $3 }')

# Append the git sha to the version in package.json if $PUSH_ARTIFACTS exists.
# it is usually the case when the script is running in the BUILD job.
if [ -n "$PUSH_ARTIFACTS" ]; then
    echo "Determining Git sha"
    sha=`git rev-parse --short HEAD`
    echo "Git sha is $sha"

    # Append hash to the version number in package.json
    sed -i "s/\"version\": \"\(.*\)\"/\"version\": \"\1-$sha\"/g" package.json

    package_name=$([[ "`grep \"\\\"name\\\"[[:blank:]]*:\" package.json`" =~ \"name\".*\"(.*)\" ]] && echo ${BASH_REMATCH[1]})
    package_version=$([[ "`grep \"\\\"version\\\"[[:blank:]]*:\" package.json`" =~ \"version\".*\"(.*)\" ]] && echo ${BASH_REMATCH[1]})
    echo "Current package & version: $package_name@$package_version"
fi

rm -rf dist dist-test
npm install
npm run build
npm run test

# Report dependencies to TESSA
if [ -n "$TESSA2_API_KEY" ]; then
    echo "TESSA2_API_KEY found. Reporting dependencies to TESSA"
    npm run report-dependencies-tessa
fi

# Publish page objects if $PUSH_ARTIFACTS exists.
if [[ -n "$PUSH_ARTIFACTS" && -n "$package_version" && -d dist-test ]]; then
    cd dist-test
    cat > .npmrc << EOF
registry=https://artifactory.corp.adobe.com/artifactory/api/npm/npm-dcloud/
_auth=$NPM_AUTH
email=$NPM_EMAIL
always-auth=true
EOF

    # If the publishing version is already in the artifactory, don't need to publish again.
    version_found=`npm view $package_name versions | grep "$package_version" || true`
    if [ -z "$version_found" ]; then
        echo "Publishing $package_name@$package_version"
        npm publish
        echo "Page objects published: $package_name@$package_version"
    else
        echo "The page objects package $package_name@$package_version is already in the artifactory. Skipping publishing"
    fi
fi
