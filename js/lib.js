/**
 * Created by emanfu on 2/16/17.
 */
/* global require, module */

var jQuery = require('jquery'),
  UiStrings = require('./nls/ui-strings'),
  images = [
    require('../images/Bethoven.png'),
    require('../images/obama-signature.jpg')],
  readMeUrl = require('../README.md'),
  exampleLib = require('npmlibexample');

function sayHello() {
  // here, we assume that UiStrings already initialized with proper language via call into UiStrings.loadTranslations()
  exampleLib.insertText('.title', UiStrings.getTranslatedString('helloWorldMsg'));
}

function showImageInfo() {
  // show images in the div with class 'image-list'
  exampleLib.showImages('.image-list', images);

  // populate image info
  var imageInfoMsg = UiStrings.getTranslatedString('imageInfoMsg')
    .replace('{numImages}', images.length);
  exampleLib.showImageInfo(imageInfoMsg, '.image-info', images);
}

function showReadMe() {
  exampleLib.loadText('../' + readMeUrl)
    .then(function (data) {
      jQuery('.readme pre').text(data);
    });
}

module.exports = {
  sayHello: sayHello,
  showImageInfo: showImageInfo,
  showReadMe: showReadMe
};
