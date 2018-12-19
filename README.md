# cdnexample

This is a starter project for onboarding to the CI/CD pipeline for static content.

## Artifactory Authentication ##
You must have an Artifactory username and API key to build this project.
Your Artifactory username is your LDAP username.
Your Artifactory API key can be obtained by following [these instructions](https://wiki.corp.adobe.com/x/O5EdRQ#APIKeys-UserAccounts).

Your username and API key must be exported via your `.profile` or `.bash_profile` in order to build with IntelliJ IDEA or via the command line:
```
export ARTIFACTORY_USER=<Artifactory username>
export ARTIFACTORY_API_TOKEN=<Artifactory API key>
```

## Clone the project and create a new repository
First, decide on your service name. If your CDN project is paired with an existing microservice, use the same name. The name should be in the form `servicename`, without camel case, underscores or dashes, with the exception of some of the original services which might already be using dashes. Throughout this document we will refer to this name as `<servicename>`.
```
$ git clone git@git.corp.adobe.com:EchoSign/cdnexample.git <servicename>-cdn
Cloning into '<servicename>-cdn'...
remote: Counting objects: 435, done.
remote: Total 435 (delta 0), reused 0 (delta 0), pack-reused 434
Receiving objects: 100% (435/435), 56.03 KiB | 0 bytes/s, done.
Resolving deltas: 100% (201/201), done.
$ cd <servicename>-cdn/
$ rm -rf .git
$ git init
Initialized empty Git repository in /Users/shickey/Workspaces/<servicename>-cdn/.git/
```

Now push your project to a new git repo with the name `<servicename>-cdn`.

## Build the project
1. Install dependencies:
    ```
    $ cd <servicename>-cdn
    $ npm install
    ```

2. Build the project. To build the project in release mode (javascript is minified):
    ```
    $ npm run build

    > cdnexample@0.1.0 build /Users/emanfu/dev/cdnexample
    > grunt build

    Running "clean:build" (clean) task
    >> 12 paths cleaned.

    Running "copy:top_level" (copy) task
    Copied 1 file

    Running "copy:assets" (copy) task
    Created 2 directories, copied 4 files

    Running "webpack:build" (webpack) task
                  Asset       Size  Chunks             Chunk Names
       __VERSION__/0.js   89 bytes       0  [emitted]  js/nls/root/ui-strings
       __VERSION__/1.js  102 bytes       1  [emitted]  js/nls/fr_FR/ui-strings
    __VERSION__/main.js     115 kB       2  [emitted]  main

    Done.

    ```
    To build the project in development mode (javascript is not minified):
    ```
    $ npm run builddev
    ```

Building the project creates a `dist` directory containing all of the assets in your project. This directory reflects what will be uploaded to S3 when it is built and deployed by the static pipeline. When deployed:

* Assets directly under `dist` are your top-level assets and are deployed with a very short cache age (1 minute).
* Assets under `dist/__VERSION__` are deployed with a new unique folder name on each deployment. They are given
  a longer cache age (1 day).

You can control what files go where via `Gruntfile.js`

## Preview Website Locally
Under `<servicename>-cdn` folder:
```
$ npm run start

> cdnexample@0.1.0 start /Users/emanfu/dev/cdnexample
> webpack-dev-server

Hash: 2e984ba7a2882764d29f
Version: webpack 2.2.1
Time: 928ms

... (lines omitted)
Project is running at https://secure.local.echocdn.com:9000/
webpack output is served from /
Content not from webpack is served from /Users/emanfu/dev/cdnexample/dist


```

Then point any browser to https://secure.local.echocdn.com:9000/ to see the web page. Please note that if you have echosign local server configured in your machine, you probably already have the host name entry secure.local.echocdn.com in your `/etc/hosts` file. If your browser complains that the host's DNS address cannot be resolved, you will have to add the following line into your `/etc/hosts` file:
```
127.0.0.1 secure.local.echocdn.com
```


## Working with Paths
All paths used in your source files must be relative. How your project is deployed might change over time (example `https://static.echocdn.com/<yourservice>` vs. `https://<youservice>.echocdn.com`) and this means you can never assume the positioning of your content with respect to the root.

As mentioned earlier in this document, assets under `dist/__VERSION` are deployed with a new unique folder name on each deployment. You are free to use the string `__VERSION__` as a placeholder for this unique name in your source files. During deployment, this string is replaced in all source files (with extensions `*.htm`, `*.html`, `*.css`, `*.js`, `*.json` with the correct folder name.

## Modify Build-Related Files
The template project uses [Webpack 2](https://webpack.js.org/) and [Grunt](https://gruntjs.com/) for code packaging and build management. The project will be built in the deployment pipeline by executing `build.sh`. You will most likely need to modify `webpack.config.js` and `Gruntfile.js` for your own need.

You can use as many webpack features as you want, or even use your own code management/packaging solution like Require.js, or build tool like Gulp or even Makefile, but whatever you use to build your project, please make sure:

 1. Modify `build.sh` to use your own build system.
 2. Your top-level files, which will have short cache age, must be placed directly under `/dist`, and the asset files that need to have long cache age should be placed in `/dist/__VERSION__`. This will ensure your files will be pushed to the S3 bucket correctly with the desired caching policy.

### `Gruntfile.js`
The template project use Grunt as our build system. The asset files other than javascript are copied to the right locations with Grunt tasks defined in `Gruntfile.js`. Please take a look at the file and make necessary changes if your project is not structured like this template project.

### `webpack.config.js`
This project doesn't use much of the webpack features. The primary features used is javascript code bundling, which combines all your app's and 3rd-party javascript files into one minified javascript file, and the webpack dev server for serving the static content locally.

Based on your application structure, you will need to determine which javascript file is your **entry-point** file, from which you will reference other javascript files, which reference yet another javascript files. All the files in the reference tree will be combined together into a single `main.js` file.
```javascript
var path = require('path');

module.exports = {
  entry: {
    // depending on what your project's entry point javascript file is,
    // you will need to moodify the following line.
    main: './js/app.js'
  },
  output: {
    filename: '__VERSION__/[name].js',
    path: path.resolve(__dirname, 'dist')
  },
  devtool  : 'inline-source-map',
  devServer: {
    contentBase: path.join(__dirname, "dist"),
    port: 9000,
    publicPath: '/'
  }
};
```

Therefore, in your HTML file (if you have one), you just need to reference `main.js` instead of every single javascript files:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Static Assets Hello World</title>
  <base href="__VERSION__/">
  ...
  <script src="main.js"></script>
</head>
<body>
...(lines omitted)
```

In your application's javascript file, always use `require(otherFile)` or `import "module/lib/file"` to reference another jsvscript file like this:
```javascript
var lib = require('./lib.js');
var jQuery = require('jquery');
var UiStrings = require('./nls/ui-strings');
```

## Modify `deploy.config` File
The `deploy.config` file is for the developers to specify some deployment settings and should be created in the root level of the repo.  The content of the file is lines of `<config_name>=<value>` pairs. The static pipeline features you can configure through `deploy.config` are described in the document [Static Pipeline Features](https://wiki.corp.adobe.com/display/ES/Static+Pipeline+Features).

In this sample project, we are trying to demonstrate as many static pipeline features as possible, but your project might not need those features. It is recommended to start with a clean `deploy.config` and add the properties for the features your project really needs.

If you copied this sample project, please delete the copied `deploy.config` file, then rename `deploy.config.template` as `deploy.config`. You can then inspect the content of the file to enable the features you need by specifying proper values to those deployment properties.

## Localization Support
Localization is handled by the code and json bundles located under js/nls folder. You need to follow these steps for localizing your project:

 1. Place strings that needs to be localized into js/nls/root/ui-strings.json file (this file corresponds to en_US locale), that provides simple key = value format.
 2. To load localized strings, you need to use js/nls/ui-strings.js module, for example, assuming you know what locale you need to load, at the main entry of your app add the following code:
 ```javascript
 
   // import the module
   var UiStrings = require('./nls/ui-strings');
   // load locale specific translations, 'lang' variable can 
   UiStrings.loadTranslations(lang).then(function() {
        // can start using UiStrings.getTranslatedString('key') method now
   });
 ```
 3. Now you can similarly use this ui-strings.js method in other modules, assuming that above code is executed and the promise returned from loadTranslations() is resovled:
  ```javascript
    // import the module
    var UiStrings = require('./nls/ui-strings');

    // get translated string
    var translatedMessage = UiStrings.getTranslatedString('MESSAGE1');
  ```
 4. If you are using index.html with base tag (as provided in this cdnexample project) you also need to adjsut webpack public path to account for the fact that base tag would confuse webpack code splititng mechanism and will try use double '__VERSION__/__VERSION__/' path. So somewhere at the root of your app add the following line (if you don't use html/base tag this step can be skipped, TBD - test it):

  ```javascript

    __webpack_public_path__ = '../';
  ```
 5. On-board your project with localization team:
    *   contact Rob Jaworski <jaworski@adobe.com> and John Nguyen <jonguyen@adobe.com> and provide the following info
    *   What git/branch needs to be monitoring?  - Most likely you want to use Master branch if following CI/CD process
    *   How changes should be pushed back (direct checkin or a pull request)?  - Most likely you want to use a pull request method.
    *   You also will need to grant write access of your github to "walf" utility account (and to Jon Nguyen)
    
 Note that usual timeline for localization to come back is about week (They usually send out the strings for translation every Friday's night and get the translation back by the following Wednesday's morning).
 
 
  This project is based on the localization solution stated in the following Wiki page, but not that the Wiki page uses ES5: [Localization for UI plugins](https://wiki.corp.adobe.com/display/ES/Localization+for+UI+plugins).
  __NOTE:__ Due to a bug in `karma-webpack`, The lazy loading of string bundles is not working in Karma when using `karma-webpack` greater than `2.0.3`. Currently we have to exactly pin to `karma-webpack@2.0.3` to get the unit test work.

## HTTPS Support
### Disable/Enable HTTPS Support
By default, this sample project support HTTPS when you run the server locally. You can see the following settings for `devServer` in `webpack.config.js`:
```javascript
  ...
  devServer: {
    contentBase: path.join(__dirname, "dist"),
    port: 9000,
    publicPath: '/',

    // comment out the following 3 lines if you don't want HTTPS support
    https: true,
    key: fs.readFileSync("key.pem"),
    cert: fs.readFileSync('cert.pem')
  }
```

if you don't want the HTTPS suuport, simply comment out the 3 properties: `https`, `key`, and `cert`.

### Update SSL Certificate
The project uses the same certificate used by the local echosign server. If you find the certificate included in the repo has been out dated, you can update the certificate from the keystore used by the local echosign server with the following steps, assuming the certificate stored in the local echosign server has not expired.

1. Run the following command right under the project root folder:
    ```
    $ keytool -v -importkeystore -srckeystore <echosign_project_root>/src/echosign/etc/tomcat_ssl_keystore -srcalias tomcat -destkeystore local.p12 -deststoretype PKCS12
    Enter destination keystore password:
    Re-enter new password:
    Enter source keystore password:
    [Storing local.p12]
    ```
    When you are asked the destination keystore password, you can use any password you want, please be sure to remember it since you will need it later. The source keystore password is `changeit`.

2. Run the following command to export the private key file. You'll need to enter the password you typed for the destination keystore.
    ```
    $ openssl pkcs12 -in local.p12 -nocerts -nodes -out key.pem
    Enter Import Password:
    MAC verified OK
    ```

3. Run the following command to export the certificate file. You'll need to enter the password you typed for the destination keystore.
    ```
    $ openssl pkcs12 -in local.p12  -nokeys -out cert.pem
    Enter Import Password:
    MAC verified OK
    ```

4. Now you have the new `key.pem` and `cert.pem` files. You can delete the `local.p12` file.

## Unit Test Support
### Frameworks Being Used
The project use the following frameworks for unit tests:

* [Karma](https://karma-runner.github.io/1.0/index.html): A test runner which spawns a web server that executes source code against test code for each of the browsers connected, like Chrome, FireFox, Safari, IE, etc, or headless browser like PhantomJS.

* [Mocha](http://mochajs.org/):  A feature-rich JavaScript test framework supporting asynchronous testing and running on Node.js and in the browser.

* [Chai](): A BDD / TDD assertion library for node and the browser that can be delightfully paired with any javascript testing framework.

* [PhantomJS](): A headless WebKit scriptable with a JavaScript API. It has fast and native support for various web standards: DOM handling, CSS selector, JSON, Canvas, and SVG.

### Adding Unit Test Support to Your Project
1. If you started your project by cloning cdnexample after the unit test support was added, you should already have the needed packages installed. Otherwise, you will need to install the following modules:
    ```
    $ npm install --save-dev babel-polyfill \
    chai \
    grunt-karma \
    karma
    karma-chrome-launcher \
    karma-mocha \
    karma-mocha-reporter \
    karma-phantomjs-launcher \
    karma-safari-launcher \
    karma-sourcemap-loader \
    karma-webpack \
    mocha \
    phantomjs-prebuilt
    ```

2. Copy `karma.conf.js` file to your project if you don't have one and modify it to your needs. Please reference the [Karma configuration document](https://karma-runner.github.io/1.0/config/configuration-file.html) for the settings suitable to your project.

3. Copy `webpack-test.config.js` file to your project if you don't have one and modify it to your needs. Please note that the `entry` property is not needed since Karma will automatically insert your test files as entries.

4. If you copied cdnexample, remove the existing test scripts under the `test` folder. Add your own test scripts there, or into any folde you want, but you'll need to modify the entries under the `files` and `preprocessors` properties in `karma.conf.js` file to match your test folder name.

5. Modify your Gruntfile.js based on the changes shown in [this git diff](https://git.corp.adobe.com/EchoSign/cdnexample/commit/d468c4810cd8454acedc025a4a125ad5b35ec8a7#diff-35b4a816e0441e6a375cd925af50752c).

6. Add/Modify the following entry under the `scripts` section in your `package.json` file:
    ```
    "scripts": {
        ...
        "test": "grunt test"
      },
    ```

7. Now you are ready to run your unit tests with the command `npm run test`. Here is a sample run for cdnexample:
    ```
    $ npm run test

    > cdnexample@0.1.0 test /Users/emanfu/dev/cdnexample
    > grunt test

    Running "karma:unit" (karma) task

    START:
    Hash: e0bdc8cc97632b01d813
    Version: webpack 2.2.1
    Time: 39ms
    webpack: Compiled successfully.
    webpack: Compiling...
    webpack: wait until bundle finished:
     ... (omitted)

    03 04 2017 17:28:26.725:INFO [karma]: Karma v1.5.0 server started at http://0.0.0.0:9876/
    03 04 2017 17:28:26.726:INFO [launcher]: Launching browser PhantomJS with unlimited concurrency
    03 04 2017 17:28:26.756:INFO [launcher]: Starting browser PhantomJS
    03 04 2017 17:28:27.332:INFO [PhantomJS 2.1.1 (Mac OS X 0.0.0)]: Connected on socket k183IM33M2-EX8fgAAAA with id 41261321
      App Library Functions
        ✔ sets hello-world message
        ✔ shows image info
      Localized String Loader
        ✔ loads en_US strings
        ✔ loads fr_FR strings

    Finished in 0.02 secs / 0.006 secs @ 17:28:27 GMT-0700 (PDT)

    SUMMARY:
    ✔ 4 tests completed

    Done.
    ```

### Run Unit Tests in CI/CD Process
If you copied `cdnexample` after the unit test support was added, your unit tests will run when a PR is created (make-ci job) and in the Build step when you depoy your project in Moonbeam. If your project was created before the unit test support was created, please copy the latest `Dockerfile.build` file into your project to replace the old one.

### Some Notes about Debugging Your Tests

* Your can configure Karma to have a single-run of your tests, or ask it to watch any changes of your test files and automatically re-run the tests again. You can also specify that the tests should run in what browsers (including PhantomJS). In `karma.conf.js` file in this project, we use the variable `debugging` (default to `false`) to control the settings related to the above features:

    - `autoWatch`: When it is `true`, Karma will watch your files and re-run your tests if any changes are detected. In this project, when `debugging` is `true`, `autoWatch` is `true`.

    - `singleRun`: When it is `true`, Karma will only run your tests once and exit. In this project, if `debugging` is `true`, `singleRun` is `false`. **Please note it only makes sense that `autoWatch` and `singleRun` has opposite values.** If `autoWatch` and `singleRun` are both `true`, `autoWatch` does not have any effect. If `autoWatch` and `singleRun` are both `false`, your tests won't even run once (I was burnt by this strange behavior, and it costed me a lot of time to figure out why my tests wouldn't run.).

    - `browsers`: Array of strings identifying the browsers in which the tests should run. In this project, when `debugging` is `true`, `Chrome` is used; otherwise `PhantomJS` is used.

* When `autoWatch` is `true` and `singleRun` is `false`, and you run the command `npm run test`, the browser(s) you specify will be laucnhed and your tests will be executed in each of them. To debug your test code, click the Debug button, which will open a new tab with the debug context html and your test scripts loaded into the page. You can then use your favorite dev tools for that browser to debug your code. Simply refresh that page and your test code is re-executed.

## Linting Support
The project use [ESLint](http://eslint.org/) as our javascript code linter. If you copied cdnexample after the linting support was added, you just need to adjust the ESLint configuration to fit your needs. Otherwise, please follow the steps below to add linting support your project:

1. Follow the [Getting Started Guide for ESLint](http://eslint.org/docs/user-guide/getting-started) to install eslint and setup your ESLint configuration file.

2. Install `eslint-loader`:
    ```
    $ npm install --save-dev eslint-loader
    ```

3. Add the following entry into `module.rules` in your `webpack.config.js`:
    ```
    module: {
        rules: [
          {
            test: /\.js$/,
            enforce: 'pre',

            loader: 'eslint-loader',
            options: {
              emitWarning: true,
              failOnWarning: false,
              failOnError: true
            }
          }
        ]
      },
    ```

4. Now everytime when you run `npm run build`, ESLint will lint your files and fail the build if there is any linting error based on the rules in the ESLint configuration file.




## Owners file: ## 
Moonbeam PR approval is restricted to a selection of individuals, using the .owners file present in the repo root. What we WANT to be able to do is add restrictions for ALL files in the repo with a simple expression (like \*\*/\*). Unfortunately, the tooling doesn't currently work that way for dot files. As such, we can approximate what we want with the following rules:

1. \* - applicable to all files in the repo root, except those starting with dot.
2. .\* - applicable to all dot files in the repo root.
3. \*\*/\* - applicable to all nested files, except those starting with dot, or in any hierarchy containing a folder starting with dot.
4. \*\*/.\* - applicable to all nested dot files, except those in any hierarchy containing a folder starting with dot.

This currently covers everything in a typical all-static project. However, it would not cover, for example, the addition of files inside a new folder hierarchy containing a folder starting with dot.

https://wiki.corp.adobe.com/display/ethos/Moonbeam+Owner%27s+File+Configuration
