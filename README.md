# cdnexample

This is a starter project for onboarding to the CI/CD pipeline for static content.

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

Project is running at http://localhost:9000/
webpack output is served from /
Content not from webpack is served from /Users/emanfu/dev/cdnexample/dist
Hash: cbf2996748090aefe5b5
Version: webpack 2.2.1
Time: 933ms

```

Then point any browser to http://localhost:9000 to see the web page.

## Working with Paths
All paths used in your source files must be relative. How your project is deployed might change over time (example `https://static.echocdn.com/<yourservice>` vs. `https://<youservice>.echocdn.com`) and this means you can never assume the positioning of your content with respect to the root.

As mentioned earlier in this document, assets under `dist/__VERSION` are deployed with a new unique folder name on each deployment. You are free to use the string `__VERSION__` as a placeholder for this unique name in your source files. During deployment, this string is replaced in all source files (with extensions `*.htm`, `*.html`, `*.css`, `*.js`, `*.json` with the correct folder name. If you need to support additional extensions, you can add to the list in
`deploy-scripts/pre-process-dist.sh` but please reach out to Eman Fu or Shannon Hickey to also add to the template.

## Modify Build-Related Files
The template project use [Webpack 2](https://webpack.js.org/) and [Grunt](https://gruntjs.com/) for code packaging and build management. You will most likely need to modify `webpack.config.js` and `Gruntfile.js` for your own need.

You can use as many webpack features as you want, or even use your own code management/packaging solution like Require.js, or build tool like Gulp or even Makefile, but whatever you use to build your project, please make sure:

 1. Hook your build system up with npm and make sure your build will start with the command `npm run build`, since the docker files in this template project assume the project build is kicked off with `npm run build`.
 2. Your top-level files, which will have short cache age, has to be placed directly under `/dist`, and the asset files that need to have long cache age should be placed in `/dist/__VERSION__`. This will ensure your files will be pushed to the S3 bucket correctly with the desired caching policy.

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
