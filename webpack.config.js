/* eslint-env node */

var path = require('path');
var fs = require('fs');

module.exports = {
  mode: 'production',
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
      },
      {
        test: /\.(png|jpg|gif)$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: 'images/[name]-[hash].[ext]'
            }
          }
        ]
      },
      {
        test: /\.(md)$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: 'docs/[name]-[hash].[ext]'
            }
          }
        ]
      }]
  },

  output: {
    filename: '__VERSION__/[name].js',
    chunkFilename: '__VERSION__/nls/translations_[name].js',
    path: path.resolve(__dirname, 'dist')
  },
  devtool  : 'inline-source-map',
  devServer: {

    client: {
      // overlay: true captures only errors
      overlay: {
        errors: true,
        warnings: false,
      },
    },

    port: 9000,
    static: {
      directory: path.join(__dirname, 'dist'),
      publicPath: '/',
    },
    host: 'secure.local.adobesigncdn.com',

    // comment out the following 3 lines if you don't want HTTPS support
    https: {
      key: fs.readFileSync('key.pem'),
      cert: fs.readFileSync('cert.pem'),
    },
  }
};
