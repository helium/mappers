const path = require('path');
const glob = require('glob');
const HardSourceWebpackPlugin = require('hard-source-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const webpack = require('webpack')
const dotenv = require('dotenv').config( {
  path: path.join(__dirname, '../.env')
} );

module.exports = (env, options) => {
  const devMode = options.mode !== 'production';

  return {
    optimization: {
      minimizer: [
        new TerserPlugin({ cache: true, parallel: true, sourceMap: devMode }),
        new OptimizeCSSAssetsPlugin({})
      ]
    },
    entry: {
      'app': glob.sync('./vendor/**/*.js').concat(['./js/app.js'])
    },
    output: {
      filename: '[name].js',
      path: path.resolve(__dirname, '../priv/static/js'),
      publicPath: '/js/'
    },
    devtool: devMode ? 'eval-cheap-module-source-map' : undefined,
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
        {
          test: /\.[s]?css$/,
          use: [
            MiniCssExtractPlugin.loader,
            'css-loader',
            'sass-loader',
          ],
        }
      ]
    },
    plugins: [
      new MiniCssExtractPlugin({ filename: '../css/app.css' }),
      new CopyWebpackPlugin([{ from: 'static/', to: '../' }]),
      new webpack.EnvironmentPlugin({
        PUBLIC_MAPBOX_KEY: undefined,
        PUBLIC_MAPBOX_STYLE: 'mapbox://styles/petermain/ckmwdn50a1ebk17o3h5e6wwui',
        PUBLIC_TILESERVER_URL: 'https://mappers-tileserver.helium.wtf'
      })
    ]
    // .env is in the cache hash because EnvironmentPlugin bakes its values into cached modules
    .concat(devMode ? [new HardSourceWebpackPlugin({
      environmentHash: { root: __dirname, directories: [], files: ['yarn.lock', '../.env'] }
    })] : [])
  }
};
