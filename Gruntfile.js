var webpack = require("webpack"),
  webpackConfig = require("./webpack.config.js");

module.exports = function (grunt) {

  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks("grunt-webpack");
  grunt.loadNpmTasks('grunt-env');

  grunt.initConfig({
    clean: {
      build: ["dist/**"]
    },

    copy: {
      assets: {
        files: [{
          // This is to copy css, images and localized strings
          expand: true,
          cwd: ".",
          src: ["css/**", "images/**"/*, "nls/**"*/],
          dest: "./dist/__VERSION__/"
        }]
      },

      top_level: {
        files: [{
          // This is to copy the favicon
          expand: true,
          cwd: ".",
          src: ["index.html", "favicon.ico"],
          dest: "./dist/"
        }]
      }
    },

    webpack: {
      options: webpackConfig,
      build: {
        devtool: "source-map",
        plugins: [
          new webpack.optimize.UglifyJsPlugin({
            compress: {warnings: false}
          }),
          new webpack.DefinePlugin({
            "process.env.NODE_ENV": JSON.stringify("production")
          })
        ]
      },

      "build-dev": {
        devtool: "inline-source-map"
      }
    }
  });

  grunt.registerTask('clean-all', ['clean:build']);

  // Production build
  grunt.registerTask("build", [
    "clean-all",
    "copy:top_level",
    "copy:assets",
    "webpack:build"
  ]);

  // dev build with un-minified dc-signature-panel-bundle.js
  grunt.registerTask("build-dev", [
    "clean-all",
    "copy:top_level",
    "copy:assets",
    "webpack:build-dev"
  ]);
};
