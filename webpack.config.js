var path = require('path');

module.exports = {
  entry: {
    // depending on what your project's entry point javascript file is,
    // you will need to moodify the following line.
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
