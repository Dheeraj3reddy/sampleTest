var path = require('path');
var fs = require('fs');
var _ = require('underscore');
var webpack = require('webpack');
var ExtractTextPlugin = require('extract-text-webpack-plugin');

function HtmlAssetsFixUpPlugin(options) {
  this.options = options;
}

HtmlAssetsFixUpPlugin.prototype.apply = function(compiler) {
  compiler.plugin("emit", _.bind(function(compilation, callback) {
    if (!this.options || !this.options.files) {
      console.warn('WARNING: HtmlAssetsFixUpPlugin needs to be supplied with files in options to work');
      return;
    }

    if (!(this.options.files instanceof Array) && typeof this.options.files !== 'string') {
      throw new Error('HtmlAssetsFixUpPlugin: options.files has to be an string or a string array');
    }

    var htmlFiles =  typeof this.options.files === 'string' ?
      [this.options.files] : this.options.files;
    _.each(htmlFiles, function(htmlFileName) {
      var htmlSource = compilation.assets[htmlFileName];
      var html = htmlSource.source().toString('utf-8');

      _.each(compilation.chunks, function (chunk) {
        var key = chunk.name;
        _.each(chunk.files, function (chunkFile) {
          var matches = chunkFile.match(/(.+)(\..+)$/);
          var actualKey = key + matches ? (key + matches[2]) : '';

          var regEx = new RegExp('<script\\s+(.*)src=(["\'])(.*)' + actualKey + '\\2', 'i');
          matches = html.match(regEx);
          if (matches) {
            console.log('> Replacing "' + actualKey + '" with "' +
                        JSON.stringify(chunkFile) + '" in ' + htmlFileName);
            html = html.replace(regEx, '<script $1src=$2$3' + chunkFile + '$2');
          } else {
            regEx = new RegExp('<link\\s+(.*)href=(["\'])(.*)' + actualKey + '\\2', 'i');
            matches = html.match(regEx);
            if (matches) {
              console.log('> Replacing "' + actualKey + '" with "' +
                          JSON.stringify(chunkFile) + '" in ' + htmlFileName);
              html = html.replace(regEx, '<link $1href=$2$3' + chunkFile + '$2');
            }
          }
        });
      });

      compilation.assets[htmlFileName] = new htmlSource.constructor(html);
    });

    callback();
  }, this));
};

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
    new HtmlAssetsFixUpPlugin({
      files: ['index.html']
    })
  ],
  devServer: {
    contentBase: path.join(__dirname, "dist"),
    port: 9000,
    publicPath: '/'
  }
};
