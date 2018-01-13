/**
 * Created by emanfu on 4/1/17.
 */
/* eslint-env mocha */
/* global require, describe */

var expect = require('chai').expect,
  UiStrings = require('../js/nls/ui-strings'),
  lib = require('../js/lib'),
  jQuery = require('jquery'),
  _ = require('underscore');

describe('App Library Functions', function() {
  before(function () {
    return UiStrings.loadTranslations('en_US');
  });

  it('sets hello-world message', function() {
    lib.sayHello();
    expect(jQuery('.title').html()).to.equal(UiStrings.getTranslatedString('helloWorldMsg'));
  });

  it('shows image info', function () {
    var numImages, listItems, imageElements;
    lib.showImageInfo();

    // number of images should be 2
    numImages = jQuery('.image-info > div > span').html();
    expect(numImages).to.equal('2');

    // we should have 2 list items whose values matching the images' src attributes.
    listItems = jQuery('.image-info > ul li');
    imageElements = jQuery('.sample-image img');
    expect(listItems.length).to.equal(imageElements.length);
    _.each(listItems, function (item, index) {
      var imageLink = jQuery(imageElements[index]).attr('src');
      expect(item.innerHTML).to.equal(imageLink);
    });
  })
});
