/**
 * Created by emanfu on 2/16/17.
 */
/* global require, __webpack_public_path__ */

// this is for supressing the eslint errors caused by setting __webpack_public_path__
/* eslint no-unused-vars: 0, no-global-assign: 0 */

var lib = require('./lib.js'),
  jQuery = require('jquery'),
  UiStrings = require('./ui-strings');

// Need to setup path at runtime, otherwise by default /__VERSION__/__VERSION__/nls/translations_xx.js will be used
// because webpack stores path to translated file in a form '__VERSION__/nls/translation_xx.js' plus example html uses
// <base href='__VERSION__'> so we end up with double __VERSION__/__VERSION__ path,
//
// Use relative '../' path to make sure it works locally and when deployed to CDN (that has format <url>/serviceName/...)
__webpack_public_path__ = '../';

jQuery(document).ready(function () {
  jQuery('.language-selector').change(function () {
    var lang = jQuery('.language-selector').val();
    startApp(lang);
  });

  startApp('en_US');
});

function startApp(lang) {
  // loadLanguage need to be called only once (once languate is selected)
  UiStrings.loadTranslations(lang).then(function () {
    lib.sayHello();
    lib.showImageInfo();
    lib.showReadMe();
  });
}


