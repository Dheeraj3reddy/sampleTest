# cdnexample

This is a starter project for onboarding to the CI/CD pipeline for static content.

### Clone the project and create a new repository
First, decide on your service name. If your CDN project is paired with an existing microservice, use the same name.
The name should be in the form `servicename`, without camel case, underscores or dashes, with the exception of some of
the original services which might already be using dashes. Throughout this document we will refer to this name as
&lt;servicename&gt;.
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

### Build the project
1. Install dependencies:
    ```
    $ cd <servicename>-cdn
    $ npm install
    ```

3. Build the project:
    ```
    $ npm run build

    > <servicename>-cdn@1.0.0 build /Users/shickey/Workspaces/<servicename>-cdn
    > grunt build

    Running "clean:build" (clean) task
    >> 0 paths cleaned.

    Running "copy:top_level" (copy) task
    Copied 1 file

    Running "copy:assets" (copy) task
    Created 2 directories, copied 4 files

    Running "webpack:build" (webpack) task                                                          Version: webpack 2.2.1
                  Asset       Size  Chunks             Chunk Names
       __VERSION__/0.js   89 bytes       0  [emitted]  js/nls/root/ui-strings
       __VERSION__/1.js  102 bytes       1  [emitted]  js/nls/fr_FR/ui-strings
    __VERSION__/main.js     115 kB       2  [emitted]  main

    Done.

    ```

Building the project creates a `dist` directory containing all of the assets in your project. This directory reflects
what will be uploaded to S3 when it is built and deployed by the static pipeline.

* Assets directly under ./dist are your top-level assets and are deployed with a very short cache age (1 minute).
* Assets under ./dist/__VERSION__ are deployed via a new folder with unique hash ID on each deployment. They are given
  a longer cache age (1 day).

### Preview Website Locally
Under `<servicename>-cdn` folder:
```
$ npm run start

> <servicename>-cdn@1.0.0 start /Users/shickey/Workspaces/<servicename>-cdn
> webpack-dev-server

Project is running at http://localhost:9000/
webpack output is served from /

```

Then point any browser to http://localhost:9000 to see the web page.

