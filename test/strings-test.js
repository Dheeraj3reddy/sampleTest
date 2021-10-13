/**
 * Created by emanfu on 3/27/17.
 */
/* global require, describe */

var UiStrings = require('../js/nls/ui-strings');

describe('Localized String Loader', () => {
  test('loads en_US strings', () => {
    return UiStrings.loadTranslations('en_US')
      .then(function() {
        expect(UiStrings.getTranslatedString('helloWorldMsg')).toBe('Hello World, Static Assets!');
      });
  });

  it('loads fr_FR strings', () => {
    return UiStrings.loadTranslations('fr_FR')
      .then(function() {
        expect(UiStrings.getTranslatedString('helloWorldMsg')).toBe('Bonjour tout le monde, actifs statiques!');
      });
  });
});
