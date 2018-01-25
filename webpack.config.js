/* eslint-env node */

var path = require('path');
var fs = require('fs');

module.exports = {
  entry: {
    // depending on what your project's entry point javascript file is,
    // you will need to moodify the following line.
    main: './js/app.js'
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        enforce: 'pre',

        loader: 'eslint-loader',
        options: {
          emitWarning: true,
          failOnWarning: false,
          failOnError: true
        }
      }
    ]
  },

  output: {
    filename: '__VERSION__/[name].js',
    chunkFilename: '__VERSION__/nls/translations_[name].js',
    path: path.resolve(__dirname, 'dist')
  },
  devtool  : 'inline-source-map',
  devServer: {
    contentBase: path.join(__dirname, 'dist/__VERSION__'),

    // overlay: true captures only errors
    overlay: {
      errors: true,
      warnings: true
    },

    port: 9000,
    publicPath: '/',
    host: 'secure.local.echocdn.com',

    // comment out the following 3 lines if you don't want HTTPS support
    https: true,
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem')
  }
};
