FROM docker-asr-release.dr.corp.adobe.com/asr/static_builder_nodejs_v16:1.0.0

RUN apt-get update && apt-get install -y libpng-dev
