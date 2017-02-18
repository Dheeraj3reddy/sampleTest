var path = require('path');
var fs = require('fs');
var _ = require('underscore');
var webpack = require('webpack');
var ExtractTextPlugin = require('extract-text-webpack-plugin');

function fixHtml() {
  this.plugin("done", function(statsData) {
    var stats = statsData.toJson();
    if (!stats.errors.length) {

      var htmlFileName = "index.html";
      var html = fs.readFileSync(path.join(__dirname, 'dist', htmlFileName), "utf8");

      _.each(stats.assetsByChunkName, function(chunkInfo, key) {
        var chunkNames = typeof chunkInfo === 'string' ? [chunkInfo] : chunkInfo;
        _.each(chunkNames, function(chunkName) {
          var matches = chunkName.match(/(.+)(\..+)$/);
          var actualKey = key + matches ? (key + matches[2]) : '';

          var regEx = new RegExp('<script\\s+(.*)src=(["\'])(.*)' + actualKey + '\\2', 'i');
          matches = html.match(regEx);
          if (matches) {
            console.log('> Replacing "' + actualKey + '" with "' +
                        JSON.stringify(chunkName) + '" in ' + htmlFileName);
            html = html.replace(regEx, '<script $1src=$2$3' + chunkName + '$2');
          } else {
            regEx = new RegExp('<link\\s+(.*)href=(["\'])(.*)' + actualKey + '\\2', 'i');
            matches = html.match(regEx);
            if (matches) {
              console.log('> Replacing "' + actualKey + '" with "' +
                          JSON.stringify(chunkName) + '" in ' + htmlFileName);
              html = html.replace(regEx, '<link $1href=$2$3' + chunkName + '$2');
            }
          }
        });
      });

      fs.writeFileSync(
        path.join(__dirname, "dist", htmlFileName),
        html);
    }
  });
}

module.exports = {
  entry: {
    main: './app/js/app.js',
    vendor: ['jquery', 'underscore'],
    index: './index.html'
  },
  module: {
    rules: [{
      test: /\.css$/,
      use: ExtractTextPlugin.extract({
        use: ['css-loader']
      })
    }, {
      test: /\.(jpg|png)$/,
      loader: 'file-loader',
      options: {
        name: './assets/[name]-[hash].[ext]'
      }
    }, {
      test: /\.html/,
      use: [{
        loader: 'file-loader',
        options: {
          name: '[path][name].[ext]'
        }
      }, {
        loader: 'extract-loader'
      }, {
        loader: 'html-loader'
      }]
    }]
  },
  output: {
    filename: 'assets/[name]-[chunkhash].js',
    path: path.resolve(__dirname, 'dist')
  },
  devtool  : 'inline-source-map',
  plugins: [
    new ExtractTextPlugin('assets/[name]-[chunkhash].css'),
    new webpack.optimize.CommonsChunkPlugin({
      names: ['vendor', 'manifest']
    }),
    fixHtml
  ]
};
