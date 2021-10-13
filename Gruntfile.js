/* eslint-env node */

var webpack = require('webpack'),
  webpackConfig = require('./webpack.config.js');

module.exports = function (grunt) {

  grunt.initConfig({
    clean: {
      build: ['dist/**']
    },

    copy: {
      assets: {
        files: [{
          // This is to copy css files
          expand: true,
          cwd: '.',
          src: ['css/**'],
          dest: './dist/__VERSION__/'
        }]
      },
      top_level: {
        files: [{
          expand: true,
          cwd: '.',
          src: ['index.html'],
          dest: './dist/'
        }]
      }
    },
    webpack: {
      options: webpackConfig,
      build: {
        devtool: 'source-map',
        plugins: [
          new webpack.optimize.UglifyJsPlugin({
            compress: {warnings: false}
          }),
          new webpack.DefinePlugin({
            'process.env.NODE_ENV': JSON.stringify('production')
          })
        ]
      },

      'build-dev': {
        devtool: 'inline-source-map'
      }
    },

    run: {
      npm_test_jest: {
        cmd: 'npm',
        args: [
          'run',
          'test',
          '--coverage'
        ]
      }
    }
  });

  // Load Grunt task modules (prefixed with 'grunt-'):
  require('load-grunt-tasks')(grunt, {
    pattern: [
      'grunt-*',
      '!grunt-timer'
    ]
  });

  grunt.registerTask('clean-all', ['clean:build']);

  // Production build
  grunt.registerTask('build', [
    'clean-all',
    'copy:top_level',
    'copy:assets',
    'webpack:build'
  ]);

  // dev build with un-minified dc-signature-panel-bundle.js
  grunt.registerTask('build-dev', [
    'clean-all',
    'copy:top_level',
    'copy:assets',
    'webpack:build-dev'
  ]);

  grunt.registerTask('test', [
    'run:npm_test_jest'
  ]);
  grunt.registerTask('sonar', function () {
    console.log('[Grunt:sonar] Running task...');

    const done = this.async();
    const sonarqubeScanner = require('sonarqube-scanner'),
        packageName = require('./package.json').name;

    if (process.env.SONAR_TOKEN) {
      console.log('[Grunt:sonar] process.env.SONAR_TOKEN is defined');
    }
    console.log('[Grunt:sonar] process.env.SONAR_ANALYSIS_TYPE=' + process.env.SONAR_ANALYSIS_TYPE);

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
      'sonar.javascript.lcov.reportPaths': 'coverage/lcov.info',
      'sonar.coverage.exclusions': 'src/**/*.spec.js'
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

    console.log('[Grunt:sonar] Calling SonarQube Scanner');
    sonarqubeScanner({
     serverUrl: 'https://adobesign.cq.corp.adobe.com',
     token: process.env.SONAR_TOKEN,
     options: sonarProperties
   }, () => {
      console.log('[Grunt:sonar] Done with SonarQube Scanner');
      done(true);
    });
  });
};
