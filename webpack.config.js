const path             = require("path");
const LiveReloadPlugin = require('webpack-livereload-plugin');
const stubs            = process.env.CONNECT_STUBS.split(',');

module.exports = {
  entry: {
    opal: './.connect/opal.js',
    connect: './.connect/entry.rb',
  },
  output: {
    path: path.resolve(__dirname, ".connect", "output"),
    filename: '[name].js'
  },
  module: {
    test: /\.rb$/,
    loaders: [
      {
        exclude: /node_modules|\.connect\/(opal|cache)/,
        loader: "opal-webpack",
        query: { dynamic_require_severity: 'ignore' }
      }
    ]
  },
  watchOptions: { poll: true },
  plugins: [
    new LiveReloadPlugin({ ignore: '.connect' })
  ],
  opal: {
    stubs: stubs,
    cacheDirectory: '.connect/cache'
  },
  devtool: 'inline-source-map'
}
