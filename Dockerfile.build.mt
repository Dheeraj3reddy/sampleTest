FROM docker-asr-release.dr.corp.adobe.com/asr/static_builder_node_v14:4.9.0

RUN apt-get update && apt-get install -y libpng-dev
