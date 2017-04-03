/**
 * Created by emanfu on 2/16/17.
 */
/* global require, module */

var jQuery = require('jquery');
var _ = require('underscore');
var UiStrings = require('./nls/ui-strings');

function sayHello() {
  // here, we assume that UiStrings already initialized with proper language via call into UiStrings.loadTranslations()
  jQuery('.title').html(UiStrings.getTranslatedString('helloWorldMsg'));
}

function showImageInfo() {
  var images = jQuery('.sample-image img'),
    imageInfoMsg = UiStrings.getTranslatedString('imageInfoMsg')
      .replace('{numImages}', images.length),
    info = '<div>' + imageInfoMsg + '</div><ul>';
  info += _.reduce(images, function(imgItems, img) {
    return imgItems + '<li>' + jQuery(img).attr('src') + '</li>';
  }, '');
  info += '</ul>';
  jQuery('.image-info').html(info);
}

module.exports = {
  sayHello: sayHello,
  showImageInfo: showImageInfo
};