FROM docker-asr-release.dr.corp.adobe.com/asr/static_deployer_base:7.0

COPY build-artifacts build-artifacts

COPY dist dist
