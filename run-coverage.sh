#!/bin/bash -e

# This script is for running the project's test coverage report after the build.
# The developer can expect the build results are already in place, and they can
# run anything here to get coverage report done. So far, only Coveralls is
# supported by the static pipeline. We will soon support SonarQube as well.

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


# Sample command for running unit test with coverage and push the coverage
# data to Coveralls server. Here it is assumed you have the script
# "test:coveralls" defined in package.json.
#
# npm run test:coveralls

echo "TODO: Run your coverage report here."
