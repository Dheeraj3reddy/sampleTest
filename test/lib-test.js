/**
 * Created by emanfu on 4/1/17.
 */
/* eslint-env mocha */
/* global require, describe */

var UiStrings = require('../js/nls/ui-strings'),
    lib = require('../js/lib'),
    jQuery = require('jquery'),
    _ = require('underscore');

describe('App Library Functions', () => {
  beforeAll(() => {
    return UiStrings.loadTranslations('en_US');
  });

  it('sets hello-world message', () => {
    lib.sayHello();
    expect(jQuery('.title').html()).toBe(UiStrings.getTranslatedString('helloWorldMsg'));
  });

  it('shows image info', () => {
    var numImages, listItems, imageElements;
    lib.showImageInfo();

    // number of images should be 2
    numImages = jQuery('.image-info > div > span').html();
    expect(numImages).toBe('2');

    // we should have 2 list items whose values matching the images' src attributes.
    listItems = jQuery('.image-info > ul li');
    imageElements = jQuery('.sample-image img');
    expect(listItems.length).toBe(imageElements.length);
    _.each(listItems, function (item, index) {
      var imageLink = jQuery(imageElements[index]).attr('src');
      expect(item.innerHTML).toBe(imageLink);
    });
  })
});
