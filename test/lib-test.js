/**
 * Created by emanfu on 4/1/17.
 */
/* global require, describe */

const UiStrings = require('../js/nls/ui-strings');
const lib = require('../js/lib');
const jQuery = require('jquery');
const _ = require('underscore');
const testHtml = require('../index.html');

describe('App Library Functions', () => {
  beforeAll(() => {
    jQuery(document.body).html(testHtml);
    return UiStrings.loadTranslations('en_US');
  });

  it('sets hello-world message', () => {
    lib.sayHello();
    expect(jQuery('.title').html()).toBe(UiStrings.getTranslatedString('helloWorldMsg'));
  });

  it('shows image info', () => {
    lib.showImageInfo();

    // number of images should be 2
    const numImages = jQuery('.image-info > div > span').html();
    expect(numImages).toBe('2');

    // we should have 2 list items whose values matching the images' src attributes.
    const listItems = jQuery('.image-info > ul li');
    const imageElements = jQuery('.sample-image img');
    expect(listItems.length).toBe(imageElements.length);
    _.each(listItems, function (item, index) {
      var imageLink = jQuery(imageElements[index]).attr('src');
      expect(imageLink).toContain(item.innerHTML);
    });
  })
});
