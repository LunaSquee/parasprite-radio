'use strict'
// CommonJS on purpose: gulp 5 only runs Babel on *.babel.js files
const webpack = require('webpack')
const path = require('path')

const inProduction = process.env.NODE_ENV === 'production' || process.argv.indexOf('-p') !== -1

module.exports = {
  entry: {
    main: ['./src/script/main'],
    admin: ['./src/script/admin'],
    popout: ['./src/script/popout'],
    livestream: ['./src/script/livestream']
  },
  output: {
    path: path.join(__dirname, 'build/script'),
    filename: '[name].js',
    chunkFilename: '[id].js'
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        loader: 'babel-loader',
        exclude: /node_modules/,
        options: {
          presets: [
            ['@babel/preset-env', {
              targets: {
                browsers: ['last 2 versions']
              }
            }]
          ]
        }
      },
      { test: /\.coffee$/, loader: 'coffee-loader', exclude: /node_modules/ },
      { test: /\.mustache$/, loader: 'mustache-loader', exclude: /node_modules/ }
    ],
    noParse: [
      /node_modules\/hls\.js/
    ]
  },

  resolve: {
    extensions: ['.coffee', '.js', '.json', '.mustache'],
    // No underscore -> lodash alias: the admin's Marionette 2.4 relies on
    // underscore's `_.each(list, fn, context)`, which lodash 4 dropped.
    modules: [path.join(__dirname, '/src/script'), 'node_modules']
  },

  plugins: [
    new webpack.ProvidePlugin({
      // Detect and inject
      $: 'jquery',
      Backbone: 'backbone',
      _: 'underscore',
      Marionette: 'backbone.marionette',
      Radio: 'backbone.radio'
    })
  ],

  devtool: 'inline-source-map',
  mode: inProduction ? 'production' : 'development',
  target: 'web'
}
