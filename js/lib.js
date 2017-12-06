/**
 * Created by emanfu on 2/16/17.
 */
/* global require, module */

var jQuery = require('jquery'),
  _ = require('underscore'),
  UiStrings = require('./nls/ui-strings'),
  images = [
    require('../images/Bethoven.png'),
    require('../images/obama-signature.jpg')];

function sayHello() {
  // here, we assume that UiStrings already initialized with proper language via call into UiStrings.loadTranslations()
  jQuery('.title').html(UiStrings.getTranslatedString('helloWorldMsg'));
}

function showImageInfo() {
  // insert all images into image-list div
  var imageList = jQuery('.image-list');
  _.each(images, function (imageUrl) {
    if (imageUrl.charAt(0) !== '/') {
      imageUrl = '../' + imageUrl;
    }
    var imageDiv = jQuery('<div class="sample-image">\n' +
      '    <img src="' + imageUrl +'">\n' +
      '  </div>');
    imageList.append(imageDiv);
  });

  // populate image info
  var imageInfoMsg = UiStrings.getTranslatedString('imageInfoMsg')
      .replace('{numImages}', images.length),
    info = '<div>' + imageInfoMsg + '</div><ul>';
  info += _.reduce(images, function(imgItems, imageUrl) {
    return imgItems + '<li>' + imageUrl + '</li>';
  }, '');
  info += '</ul>';
  jQuery('.image-info').html(info);
}

module.exports = {
  sayHello: sayHello,
  showImageInfo: showImageInfo
};