/* eslint-env node */

var path = require('path');

module.exports = {
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'testdist')
  },

  plugins: [],
  devtool: 'inline-source-map'
};
