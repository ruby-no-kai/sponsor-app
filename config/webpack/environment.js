const { environment } = require('@rails/webpacker')
const webpack = require('webpack');

environment.loaders.append('ts', {
  test: /\.tsx?$/,
  use: 'ts-loader',
});

environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery',
}));

module.exports = environment;
