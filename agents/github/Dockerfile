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
    ROVER_RUNNER=true \
    TARGETARCH=${TARGETARCH} \
    TARGETOS=${TARGETOS} \
    URL=${URL} \
    USERNAME=${USERNAME} \
    versionGithubRunner=${versionGithubRunner} \
    WORK=${WORK}

CMD ["/bin/zsh"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./agents/github/github.sh .

RUN echo "Installing Github self-hosted runner ${versionGithubRunner}..." && \
    if [ ${TARGETARCH} == "amd64" ]; then \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-x64-${versionGithubRunner}-noruntime-noexternals.tar.gz 2>&1 && \
    else  \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-arm64-${versionGithubRunner}-noruntime-noexternals.tar.gz 2>&1 && \
    fi \
    && sudo tar xzf /tmp/github-runner.tar.gz && \
    sudo rm /tmp/github-runner.tar.gz && \
    sudo chmod +x ./config.sh ./run.sh ./env.sh ./github.sh && \
    sudo chown -R ${USERNAME} ./

ENTRYPOINT ["./github.sh"]