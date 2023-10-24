ARG versionRover=${versionRover}
FROM ${versionRover}

ARG AGENT_NAME
ARG AGENT_TOKEN
ARG LABELS
ARG MSI_ID
ARG TARGETARCH
ARG TARGETOS
ARG URL
ARG USERNAME
ARG versionGithubRunner
ARG WORK=_work

ENV AGENT_NAME=${AGENT_NAME} \
    AGENT_TOKEN=${AGENT_TOKEN} \
    DEBIAN_FRONTEND=noninteractive \
    LABELS=${LABELS} \
    MSI_ID=${MSI_ID} \
    PATH="${PATH}:/home/${USERNAME}/.dotnet" \
    ROVER_RUNNER=true \
    TARGETARCH=${TARGETARCH} \
    TARGETOS=${TARGETOS} \
    URL=${URL} \
    USERNAME=${USERNAME} \
    versionGithubRunner=${versionGithubRunner} \
    WORK=${WORK}

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./agents/github/github.sh .

RUN echo "Installing Github self-hosted runner ${versionGithubRunner}..." && \
    if [[ "${TARGETARCH}" == "amd64" ]]; then \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-x64-${versionGithubRunner}.tar.gz 2>&1 ; \
    else  \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-arm64-${versionGithubRunner}.tar.gz 2>&1 ; \
    fi \
    && sudo tar xzf /tmp/github-runner.tar.gz && \
    sudo chmod +x ./config.sh ./run.sh ./env.sh ./github.sh && \
    sudo chown -R ${USERNAME} ./ && \
    #
    # Install dotnet core 6.0.x
    curl -sSL -o /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh && \
    sudo chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh -c 6.0 --runtime dotnet -Verbose && \
    #
    sudo apt-get update && \
    sudo apt-get install -y jq && \
    #
    sudo pip3 uninstall -y yq && \
    LATEST_YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r ".tag_name") && \
    sudo wget "https://github.com/mikefarah/yq/releases/download/$LATEST_YQ_VERSION/yq_linux_amd64" -O /usr/bin/yq && \
    sudo chmod +x /usr/bin/yq && \
    #
    jq --version && \
    yq --version && \
    rm -rf /tmp/*

ENTRYPOINT ["./github.sh"]