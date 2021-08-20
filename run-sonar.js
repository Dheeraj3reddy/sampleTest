/*************************************************************************
 * ADOBE CONFIDENTIAL
 * ___________________
 *
 *  Copyright 2020 Adobe Systems Incorporated
 *  All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of Adobe Systems Incorporated and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Adobe Systems Incorporated and its
 * suppliers and are protected by all applicable intellectual property laws,
 * including trade secret and or copyright laws.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Adobe Systems Incorporated.
 **************************************************************************/

const sonarqubeScanner = require('sonarqube-scanner'),
    packageName = require('./package.json').name;

let sonarProperties = {
    // #################################################
    // # General Configuration
    // #################################################
    'sonar.projectKey': `microservice:${packageName}`,
    'sonar.projectName': `Microservice - Adobe Sign - ${packageName}`,

    'sonar.sourceEncoding': 'UTF-8',
    'sonar.login': process.env.SONAR_TOKEN,
    'sonar.host.url': 'https://adobesign.cq.corp.adobe.com',

    // #################################################
    // # Javascript Configuration
    // #################################################
    'sonar.language': 'javascript',
    'sonar.sources': 'js',
    'sonar.javascript.lcov.reportPaths': 'test_coverage/lcov.info',
};

if (process.env.SONAR_ANALYSIS_TYPE === 'pr') {
    sonarProperties = Object.assign({}, sonarProperties, {
        // #################################################
        // # Github Configuration
        // #################################################
        'sonar.github.endpoint': 'https://git.corp.adobe.com/api/v3',
        'sonar.pullrequest.provider': 'github',
        'sonar.pullrequest.branch': process.env.branch,
        'sonar.pullrequest.key': process.env.pr_numbers,
        'sonar.pullrequest.base': process.env.base_branch,
        'sonar.pullrequest.github.repository': process.env.repo,
        'sonar.scm.revision': process.env.sha
    });
}

sonarqubeScanner({
 serverUrl: 'https://adobesign.cq.corp.adobe.com',
 token: process.env.SONAR_TOKEN,
 options: sonarProperties
}, () => {});