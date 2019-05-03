#!/bin/bash -e

# This script is for running the project's test coverage report after the build.
# The developer can expect the build results are already in place, and they can
# run anything here to get coverage report done. So far, only Coveralls is
# supported by the static pipeline. We will soon support SonarQube as well.

# Getting "_auth" and "email" values from Artifactory for .npmrc file.
# Assumption: ARTIFACTORY_USER and ARTIFACTORY_API_TOKEN need to have
# already been defined in the environment.
auth=$(curl -u$ARTIFACTORY_USER:$ARTIFACTORY_API_TOKEN https://artifactory.corp.adobe.com/artifactory/api/npm/auth)
export NPM_AUTH=$(echo "$auth" | grep "_auth" | awk -F " " '{ print $3 }')
export NPM_EMAIL=$(echo "$auth" | grep "email" | awk -F " " '{ print $3 }')

# Sample command for running unit test with coverage and push the coverage
# data to Coveralls server. Here it is assumed you have the script
# "test:coveralls" defined in package.json.
#
# npm run test:coveralls

echo "TODO: Run your coverage report here."
