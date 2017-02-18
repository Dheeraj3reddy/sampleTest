# cdnexample

This is an example project for CI/CD pipeline for static assets.

## Dev Setup

### Build the project
1. Clone the project to your local folder.
2. Install all dependencies.
    ```
    $ cd cdnexample
    $ npm install
    ```
3. Build the project:
    ```
    $ npm run build

    > cdnexample@1.0.0 build /Users/emanfu/dev/cdnexample
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

After the project is successfully built, a `dist` directory will be created for all the files to be uploaded to S3.

* The files `./dist/*` are supposed to have very short cache age.
* The files `./dist/assets/*` are supposed to have long cache age.


### Preview Website Locally
Under `cdnexample` folder:
```
$ npm run start

> cdnexample@1.0.0 start /Users/emanfu/dev/cdnexample
> cd dist; serve


   ┌───────────────────────────────────────────────────┐
   │                                                   │
   │   Serving!                                        │
   │                                                   │
   │   - Local:            http://localhost:3000       │
   │   - On Your Network:  http://172.31.98.244:3000   │
   │                                                   │
   │                                                   │
   │                                                   │
   └───────────────────────────────────────────────────┘

```

Then point any browser to http://localhost:3000 to see the web page.

