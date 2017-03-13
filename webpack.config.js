var path = require('path');


module.exports = {
  entry: {
    main: './js/app.js'
  },
  output: {
    filename: '__VERSION__/[name].js',
    path: path.resolve(__dirname, 'dist')
  },
  devtool  : 'inline-source-map',
  devServer: {
    contentBase: path.join(__dirname, "dist"),
    port: 9000,
    publicPath: '/'
  }
};
