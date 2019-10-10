ARG versionAzureCli

FROM alpine as base

RUN apk add git

WORKDIR /tf

COPY . .
RUN git clone https://github.com/aztfmod/landingzones.git /tf/landingzones
RUN git clone https://github.com/aztfmod/level0.git /tf/level0


FROM mcr.microsoft.com/azure-cli:${versionAzureCli} AS final

ARG versionTerraform

WORKDIR /tf
COPY --from=base /tf .

RUN apk update \
    && apk add bash jq unzip

RUN echo "Installing terraform..." \
    && curl -LO https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip \
    && unzip -d /usr/local/bin terraform_${versionTerraform}_linux_amd64.zip \
    && rm terraform_${versionTerraform}_linux_amd64.zip

ENTRYPOINT [ "./launchpad.sh" ]