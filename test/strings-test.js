/**
 * Created by emanfu on 3/27/17.
 */
/* eslint-env mocha */
/* global require, describe */

var expect = require('chai').expect;
var UiStrings = require('../js/nls/ui-strings');

describe('Localized String Loader', function() {
  it('loads en_US strings', function () {
    return UiStrings.loadTranslations('en_US')
      .then(function() {
        expect(UiStrings.getTranslatedString('helloWorldMsg'))
          .to.equal('Hello World, Static Assets!');
      });
  });

  it('loads fr_FR strings', function () {
    return UiStrings.loadTranslations('fr_FR')
      .then(function() {
        expect(UiStrings.getTranslatedString('helloWorldMsg'))
          .to.equal('Bonjour tout le monde, actifs statiques!');
      });
  });
});
