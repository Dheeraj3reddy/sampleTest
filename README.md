# cdnexample

This is a starter project for onboarding to the CI/CD pipeline for static content.

### Clone the project and create a new repository
First, decide on your service name. If your CDN project is paired with an existing microservice, use the same name.
The name should be in the form `servicename`, without camel case, underscores or dashes, with the exception of some of
the original services which might already be using dashes.
```
$ git clone git@git.corp.adobe.com:EchoSign/cdnexample.git <servicename>-cdn
Cloning into '<servicename>-cdn'...
remote: Counting objects: 435, done.
remote: Total 435 (delta 0), reused 0 (delta 0), pack-reused 434
Receiving objects: 100% (435/435), 56.03 KiB | 0 bytes/s, done.
Resolving deltas: 100% (201/201), done.
$ cd yourservicename-cdn/
$ rm -rf .git
$ git init
Initialized empty Git repository in /Users/shickey/Workspaces/<servicename>-cdn/.git/
```

Now push your project to git.

### Build the project
1. Install all dependencies:
    ```
    $ cd <servicename>-cdn
    $ npm install
    ```

3. Build the project:
    ```
    $ npm run build

    > cdnexample@1.0.0 build /Users/emanfu/dev/<servicename>-cdn
    > webpack

    > Replacing "main.js" with ""assets/main-88851569af523a5d8d0e.js"" in index.html
    > Replacing "main.css" with ""assets/main-88851569af523a5d8d0e.css"" in index.html
    > Replacing "vendor.js" with ""assets/vendor-a8180f14003db6ee1ab9.js"" in index.html
    > Replacing "manifest.js" with ""assets/manifest-0789f024bbcd91ba658b.js"" in index.html
    Hash: 66666756698933ba47b1
    Version: webpack 2.2.1
    Time: 1129ms
                                                            Asset       Size  Chunks                    Chunk Names
           ./assets/Bethoven-5fd10b131af61686e7b41422da332043.png    52.2 kB          [emitted]
    ./assets/obama-signature-d189f34de68b39bd6994b33cb21ddb41.jpg    35.3 kB          [emitted]

    (lines omitted)

    ```

Building the project creates a `dist` directory containing all of the assets in your project. This directory reflects
what will be uploaded to S3 when you have onboarded to the deployment pipeline.

* The files `./dist/*` are supposed to have very short cache age.
* The files `./dist/assets/*` are supposed to have long cache age.


### Preview Website Locally
Under `cdnexample` folder:
```
emanfu-osx:cdnexample emanfu$ npm run start

> cdnexample@1.0.0 start /Users/emanfu/dev/cdnexample
> webpack-dev-server

Project is running at http://localhost:9000/
webpack output is served from /
(lines omitted)
```

Then point any browser to http://localhost:9000 to see the web page.

