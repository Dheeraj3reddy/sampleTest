/**
 * Module that handles lazy loading translated strings as json object and provide helper method to return translated string
 * for a given key.
 *
 * Performs two functions:
 *  - at compile/bundle time, generate lazy-loadable chunks for each locale.
 *  - at run time, provides loadTranslations() method that lazy load locale and helper method to get translated string by key
 */

/* global require, module */

var Promise = require('es6-promise').Promise;

// Module level variable that stores translations (as key/value object)
var loadedTranslations = null;

/**
 * Loads translations based on the locale and stores it as loadedTranslations variable, that later can be used
 * via getTranslatedString() method.
 * @param {String} locale to be loaded
 * @returns {Promise} the promise that is resolved when translated file is loaded and getTranslatedString can be used.
 */
function loadTranslations(locale) {
  var loc = (locale === 'en_US') ? 'root' : locale;
  return new Promise(function (resolve) {
    var bundle = require('./' + loc + '/ui-strings.json');
    var resolveBundle = function (jsonBundle) {
      loadedTranslations = jsonBundle;
      resolve(jsonBundle);
    };

    if (typeof bundle === 'function') {
      bundle(function (jsonBundle) {
        resolveBundle(jsonBundle);
      });
    } else {
      resolveBundle(bundle);
    }
  });
}

/**
 * Returns translated string for a given key
 * @param {String} key that identifies translated string
 * @returns {String} translated string
 */
function getTranslatedString(key) {
  if (loadedTranslations) {
    return loadedTranslations[key];
  }
}

module.exports = {
  loadTranslations: loadTranslations,
  getTranslatedString: getTranslatedString
};
