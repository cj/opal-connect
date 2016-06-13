const path              = require("path");
const LiveReloadPlugin  = require('webpack-livereload-plugin');
const stubs             = process.env.CONNECT_STUBS.split(',');
const WatchIgnorePlugin = require("webpack").WatchIgnorePlugin;

module.exports = {
  resolve: {
    extensions: ['', '.js', '.css', '.rb'],
    alias: {
      app: path.resolve(__dirname, "app"),
      spec: path.resolve(__dirname, "spec")
    }
  },
  entry: {
    connect: ['./.connect/opal.js', './.connect/connect.js'],
    app: './.connect/entry.rb',
    rspec: './.connect/rspec.js'
  },
  output: {
    path: path.resolve(__dirname, ".connect", "output"),
    filename: '[name].js'
  },
  module: {
    test: /\.rb$/,
    loaders: [
      {
        exclude: /node_modules|\.connect\/(opal|cache|connect|rspec|output)/,
        loader: "opal-webpack",
        query: { dynamic_require_severity: 'ignore' }
      }
    ]
  },
  // watchOptions: { poll: true, lazy: true },
  plugins: [
    new LiveReloadPlugin({ ignore: /entry\.rb/ }),
  ],
  opal: {
    stubs: stubs,
    cacheDirectory: '.connect/cache'
  },
  devtool: 'inline-source-map'
}
