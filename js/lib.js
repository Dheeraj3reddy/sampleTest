/**
 * Created by emanfu on 2/16/17.
 */

var jQuery = require('jquery');
var _ = require('underscore');

function sayHello() {
  jQuery('.title').html('Hello World, Static Assets!');
}

function showImageInfo() {
  var images = jQuery('.sample-image img');
  var info = '<div>We have ' + images.length + ' images:</div><ul>';
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