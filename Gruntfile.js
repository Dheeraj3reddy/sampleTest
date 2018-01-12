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
          // This is to copy css and images
          expand: true,
          cwd: '.',
          src: ['css/**', 'images/**'],
          dest: './dist/__VERSION__/'
        }, {
          // This is to copy localized strings
          expand: true,
          cwd: '.',
          src: ['nls/**'],
          dest: './dist/__VERSION__'
        }]
      },

      top_level: {
        files: [{
          // This is to copy the favicon
          expand: true,
          cwd: '.',
          src: ['index.html', 'favicon.ico'],
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

    karma: {
      unit: {
        configFile: './karma.conf.js'
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
    'karma:unit'
  ]);
};
