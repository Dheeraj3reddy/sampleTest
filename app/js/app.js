/**
 * Created by emanfu on 2/16/17.
 */

require('../css/style.css');
require('../css/style2.css');

var lib = require('./lib.js');
var jQuery = require('jquery');

jQuery(document).ready(function() {
  lib.sayHello();
  lib.showImageInfo();
});


