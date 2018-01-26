// Karma configuration
// Generated on Mon Mar 27 2017 11:48:26 GMT-0700 (PDT)

/* eslint-env node */

var webpackConfig = require('./webpack-test.config.js'),
  debugging = false; // change it to true for debugging in browser

module.exports = function(config) {
  config.set({

    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '.',

    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['mocha'],

    // list of files / patterns to load in the browser
    files: [
      // this file is needed so that es6-promise can work correctly in PhantomJS
      'node_modules/babel-polyfill/dist/polyfill.js',

      // test scripts
      'test/**/*.js',

      // images used by the text_context.html file. they are not strictly needed,
      // but it's better to have a test environment as close to the real world
      // as possible.
      {
        pattern: 'images/*.*',
        included: false,
        served: true,
        watched: true
      },

      // the following files are for debugging purpose only when we set autoWatch:true
      // and singleRun:false, so that karma will re-run the tests when those files are changed.
      {
        pattern: 'test/context/*.*',
        included: false,
        served: false,
        watched: true
      },
      {
        pattern: 'webpack-test.config.js',
        included: false,
        served: false,
        watched: true
      }
    ],

    // list of files to exclude
    exclude: [
    ],

    proxies: {
      '/nls/': '/base/nls/',
      '/images/': '/base/images/'
    },

    path: '/',
    urlRoot: '/',

    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      'test/**/*.js': [
        'webpack',
        'sourcemap'
      ]
    },

    customContextFile: 'test/context/test_context.html',
    customDebugFile: 'test/context/test_debug_context.html',

  // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['mocha'],

    // web server port
    port: 9876,


    // enable / disable colors in the output (reporters and logs)
    colors: false,


    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: debugging,

    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    singleRun: !debugging,


    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: [
      debugging ? 'Chrome' : 'PhantomJS'
    ],


    // Concurrency level
    // how many browser should be started simultaneous
    concurrency: Infinity,

    webpack: webpackConfig
  });
};

