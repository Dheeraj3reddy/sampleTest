/**
 * Created by emanfu on 2/16/17.
 */

var lib = require('./lib.js');
var jQuery = require('jquery');
var UiStrings = require('./nls/ui-strings');

// Need to setup path at runtime, otherwise by default /__VERSION__/__VERSIOM__/1.js will be used,
// because we use base href='__VERSION__' I suspect
__webpack_public_path__ = "/";

jQuery(document).ready(function() {
    jQuery('.language-selector').change(function() {
        var lang = jQuery('.language-selector').val();
        startApp(lang);
    })

    startApp('en_US');
});

function startApp(lang) {
    // loadLanguage need to be called only once (once languate is selected)
    UiStrings.loadLanguage(lang).then(function() {
        lib.sayHello();
        lib.showImageInfo();
    });
}


