FROM docker-asr-release.dr.corp.adobe.com/asr/static_deployer_base:1.2.2-alpine

COPY build-artifacts build-artifacts

COPY dist dist
