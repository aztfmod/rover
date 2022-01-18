ARG versionRover=${versionRover}
FROM ${versionRover}

ARG AGENT_KEYVAULT_NAME
ARG AGENT_KEYVAULT_SECRET
ARG AGENT_NAME
ARG AGENT_TOKEN
ARG AGENT_URL
ARG LABELS
ARG MSI_ID
ARG REGISTER_PAUSED=false
ARG TARGETARCH
ARG TARGETOS
ARG USERNAME
ARG WORK_FOLDER

ENV AGENT_KEYVAULT_NAME=${AGENT_KEYVAULT_NAME} \
    AGENT_KEYVAULT_SECRET=${AGENT_KEYVAULT_SECRET} \
    AGENT_NAME=${AGENT_NAME} \
    AGENT_TOKEN=${AGENT_TOKEN} \
    AGENT_URL=${AGENT_URL} \
    DEBIAN_FRONTEND=noninteractive \
    LABELS=${LABELS} \
    MSI_ID=${MSI_ID} \
    REGISTER_PAUSED=${REGISTER_PAUSED} \
    ROVER_RUNNER=true \
    TARGETARCH=${TARGETARCH} \
    TARGETOS=${TARGETOS} \
    USERNAME=${USERNAME} \
    WORK_FOLDER=${WORK_FOLDER}

CMD ["/bin/bash"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./agents/gitlab/gitlab.sh .

RUN echo "Installing Gitlab runner ..." && \
    sudo curl -L --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-${TARGETOS}-${TARGETARCH}" 2>&1 ; \
    sudo chmod +x /usr/local/bin/gitlab-runner && \
    sudo gitlab-runner install --user=${USERNAME} --working-directory=/home/${USERNAME}/agent && \
    sudo chmod +x ./gitlab.sh

ENTRYPOINT ["./gitlab.sh"]