/**
 * Module that handles lazy loading translated strings as json object and provide helper method to return translated string
 * for a given key.
 *
 * Peforms two functions:
 *  - at compiel/bundle time, uses 'bundle-loader' to generate lazy-loadable chunks for each locale.
 *  - at run time, provides loadTranslations() method that lazy load locale and helper method to get translated string by key
 */

/* global require, module */

var Promise = require('es6-promise').Promise;

// Module level variable that stores translations (as key/value object)
var loadedTranslations = null;

var jQuery = require('jquery');

function loadStringsImpl(loc) {
  return new Promise(function (resolve, reject) {
    jQuery.ajax({
      url: 'nls/' + loc + '/ui-strings.json',
      method: 'GET',
      dataType: 'json'
    })
      .done(function (data) {
        loadedTranslations = data || {};
        resolve();
      })
      .fail(function (jqXHR) {
        //console.error('Failed to load strings for locale %s', locale);
        reject(jqXHR);
      });
  });
}

/**
 * Loads tranlsations based on the locale and stores it as loadedTranslations variable, that later can be used
 * via getTranslatedString() method.
 * @param {String} locale to be loaded
 * @returns {Promise} the promise that is resolved when translated file is loaded and getTranslatdString can be used.
 */
function loadTranslations(locale) {
  var loc = (locale === 'en_US') ? 'root' : locale;
  return loadStringsImpl(loc)
    .catch(function(jqXHR) {
      // if the error status is 404 Not Found, or 200 (empty file or file cannot be converted to JSON)
      // try to load the en-US strings.
      if (jqXHR.status == 404 || jqXHR.status == 200) {
        return loadStringsImpl('en_US');
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
