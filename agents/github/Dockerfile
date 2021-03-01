ARG versionRover=${versionRover}
FROM ${versionRover}

ARG versionGithubRunner
ARG AGENT_TOKEN
ARG URL
ARG LABELS
ARG MSI_ID
ARG WORK=_work
ARG AGENT_NAME
ARG USERNAME

ENV DEBIAN_FRONTEND=noninteractive \
    ROVER_RUNNER=true \
    versionGithubRunner=${versionGithubRunner} \
    AGENT_TOKEN=${AGENT_TOKEN} \
    URL=${URL} \
    LABELS=${LABELS} \
    MSI_ID=${MSI_ID} \
    WORK=${WORK} \
    AGENT_NAME=${AGENT_NAME} \
    USERNAME=${USERNAME}

CMD ["/bin/bash"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./github/github.sh .

RUN echo "Installing Github self-hosted runner ${versionGithubRunner}..." && \
    sudo curl -L -o ./github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-x64-${versionGithubRunner}.tar.gz 2>&1 && \
    sudo tar xzf ./github-runner.tar.gz && \
    sudo rm ./github-runner.tar.gz && \
    sudo chmod +x ./config.sh ./run.sh ./env.sh ./github.sh && \
    sudo chown -R ${USERNAME} ./

ENTRYPOINT ["./github.sh"]