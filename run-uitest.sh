#!/bin/bash -e

# This script is for running the project's UI tests. When this script is
# executed, you don't have access to built content, but you have access to the
# project's source files. This means you can access config information, source
# code, run npm commands, etc.

# Getting "_auth" and "email" values from Artifactory for .npmrc file.
# Assumption: ARTIFACTORY_USER and ARTIFACTORY_API_TOKEN need to have
# already been defined in the environment.
auth=$(curl -u$ARTIFACTORY_USER:$ARTIFACTORY_API_TOKEN https://artifactory.corp.adobe.com/artifactory/api/npm/auth)
export NPM_AUTH=$(echo "$auth" | grep "_auth" | awk -F " " '{ print $3 }')
export NPM_EMAIL=$(echo "$auth" | grep "email" | awk -F " " '{ print $3 }')

# Sample commands for running UI tests on AiC's test grid. It is assumed that
# you have the "wdio:dev:grid-aic" script defined in package.json.
#
# npm install
# npm run wdio:dev:grid-aic

echo "TODO: Run your UI tests here."
