/**
 * Created by anlau on 10/13/21.
 */
/* global require, describe */

const UiStrings = require('../js/nls/ui-strings');
const app = require('../js/app');

describe('test app', () => {
    test('loads translations', () => {
        const spy = jest.spyOn(UiStrings, 'loadTranslations');
        app.startApp('en_US');
        expect(spy).toHaveBeenCalled();
        expect(spy).toHaveBeenCalledWith('en_US');
    });
});