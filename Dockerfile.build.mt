FROM docker-asr-release.dr.corp.adobe.com/asr/static_builder_node_v12:4.2

RUN apt-get update && apt-get install -y libpng-dev
