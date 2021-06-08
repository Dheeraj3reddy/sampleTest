#!/bin/bash -e
# -e to exit on first error.

# This script is responsible for building the project's static content.
# It is also responsible for updating Tessa and running code coverage (i.e. SonarQube).
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

if [[ -n "$ARTIFACTORY_USER" ]]; then
    # Get "email" and "_auth" values from Artifactory for .npmrc file.
    # Assumption: ARTIFACTORY_USER and ARTIFACTORY_API_TOKEN need to have
    # already been defined in the environment.
    auth=$(curl -s -u$ARTIFACTORY_USER:$ARTIFACTORY_API_TOKEN https://artifactory.corp.adobe.com/artifactory/api/npm/auth)
else
    # If missing $ARTIFACTORY_USER, try the user-level .npmrc file.
    auth=$(<~/.npmrc)
fi
[[ "$auth" =~ email\ *=\ *([[:graph:]]*) ]]; export NPM_EMAIL="${BASH_REMATCH[1]}"
[[ "$auth" =~ _auth\ *=\ *([[:graph:]]*) ]]; export NPM_AUTH="${BASH_REMATCH[1]}"

# It is assumed that the build result being deployed to S3/CDN will be stored
# in the "dist" folder, and if you want to publish an NPM package to the
# Artifactory, it will be stored in the "dist-pub" folder.
rm -rf dist dist-pub
npm install
npm run build
npm run test

# Publish an NPM package if $PUSH_ARTIFACTS is non-empty and the "dist-pub"
# folder exists.
if [[ -n "$PUSH_ARTIFACTS" && -d dist-pub ]]; then
    cd dist-pub

    # Change the value of PUBLISH_REGISTRY to the registry URL to which you
    # want to publish your package. Please note that you will have to grant
    # publish and view permission to the user dckosmos@adobe.com if your
    # project is in the "dc" organization, or dcms@adobe.com if your project
    # is in the "echosign" organization. Those accounts are the utility
    # Artifactory users used by the Jenkins job.
    PUBLISH_REGISTRY=https://artifactory.corp.adobe.com/artifactory/api/npm/npm-adobesign-release-local/
    cat > .npmrc << EOF
registry=$PUBLISH_REGISTRY
_auth=$NPM_AUTH
email=$NPM_EMAIL
always-auth=true
EOF

    # If you would like to publish an NPM package, it is assumed that
    # "npm run build" will generate a package.json file in the dist-pub folder
    # with the right package name and version being published and a valid
    # registry URL in publishConfig.
    package_name=$([[ "`grep \"\\\"name\\\"[[:blank:]]*:\" package.json`" =~ \"name\".*\"(.*)\" ]] && echo ${BASH_REMATCH[1]})
    package_version=$([[ "`grep \"\\\"version\\\"[[:blank:]]*:\" package.json`" =~ \"version\".*\"(.*)\" ]] && echo ${BASH_REMATCH[1]})

    if [ -z "$package_name" ]; then
        echo "No 'name' property found in package.json! Publishing cannot continue."
        exit 1
    fi

    if [ -z "$package_version" ]; then
        echo "No 'version' property found in package.json! Publishing cannot continue."
        exit 1
    fi

    # If the publishing version is already in the artifactory, don't need to publish again.
    # Ignore any not-found exit error using || true since we look for a non-zero length string.
    version_found=`npm view $package_name versions | grep "$package_version"` || true
    if [ -z "$version_found" ]; then
        echo "Publishing $package_name@$package_version"
        npm publish
        echo "Package published: $package_name@$package_version"
    else
        echo "The package $package_name@$package_version is already in the artifactory. Skipping publishing"
    fi

    cd ..
fi

# Report dependencies to TESSA
if [ -n "$TESSA2_API_KEY" ]; then
    echo "TESSA2_API_KEY found. Reporting dependencies to TESSA"
    npm run report-dependencies-tessa
fi

# SonarQube analysis
if [ -n "$SONAR_TOKEN" ]; then
    if [ -z "$sha" ]; then
        echo sha is required for SonarQube analysis
        exit 1
    fi

    ############# TODO - Add SonarQube analysis here #############
fi
