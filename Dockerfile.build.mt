FROM docker-asr-release.dr.corp.adobe.com/asr/static_builder_node_v8:3.12.0

RUN apt-get update && apt-get install -y libpng-dev
