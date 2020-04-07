#!/bin/bash -e

# This script is for running the project's post-merge hook.
# When this script is executed, you don't have access to built content, but you
# have access to the project's source files. This means you can access config
# information, source code, run npm commands, etc.

# Getting "_auth" and "email" values from Artifactory for .npmrc file.
# Assumption: ARTIFACTORY_USER and ARTIFACTORY_API_TOKEN need to have
# already been defined in the environment.
auth=$(curl -u$ARTIFACTORY_USER:$ARTIFACTORY_API_TOKEN https://artifactory.corp.adobe.com/artifactory/api/npm/auth)
export NPM_AUTH=$(echo "$auth" | grep "_auth" | awk -F " " '{ print $3 }')
export NPM_EMAIL=$(echo "$auth" | grep "email" | awk -F " " '{ print $3 }')

echo "Running post-merge hook."
if [ -z "$GITHUB_TOKEN" ]
then
      echo "\$GITHUB_TOKEN is empty"
else
      echo "\$GITHUB_TOKEN is NOT empty"
fi

curl -v -H "Authorization: token $GITHUB_TOKEN" https://git.corp.adobe.com/EchoSign/cdnexample

