module.exports = function (grunt) {

  grunt.initConfig({
    "clean": {
      build: [
        "dist/**"
      ]
    }
  });

  grunt.loadNpmTasks('grunt-contrib-clean');

  grunt.registerTask('clean-all', ['clean:build']);
};