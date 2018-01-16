/* eslint-env node */

var path = require('path');

module.exports = {
  module: {
    rules: [
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
    filename: '[name].js',
    path: path.resolve(__dirname, 'testdist')
  },

  plugins: [],
  devtool: 'inline-source-map'
};
