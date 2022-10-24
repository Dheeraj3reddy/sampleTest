FROM docker-asr-release.dr.corp.adobe.com/asr/static_deployer_base:7.0.0

RUN apt-get update && apt-get install -y zip ca-certificates apt-transport-https lsb-release gnupg
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
RUN AZ_REPO=$(lsb_release -cs) && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-get update && apt-get install -y --allow-downgrades azure-cli=2.28.0-1~focal

COPY build-artifacts build-artifacts

COPY dist dist
