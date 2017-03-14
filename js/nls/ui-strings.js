/*global require */

var Promise = require('es6-promise').Promise;

var loadedBundle = null;

function getTranslatedString (key) {
    return loadedBundle[key];
}

function loadLanguage(locale) {
    var loc  = (locale === "en_US") ? "root"  : locale;
    return new Promise(function(resolve) {
        require('bundle-loader?lazy&name=[path][name]!../nls/' + loc + '/ui-strings.json')(function(jsonBundle) {
            loadedBundle = jsonBundle;
            resolve(jsonBundle);
        });
    });
}

module.exports = {
    loadLanguage: loadLanguage,
    getTranslatedString: getTranslatedString
};
