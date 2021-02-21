ARG versionRover=${versionRover}
FROM ${versionRover}

ARG AGENT_TOKEN
ARG AGENT_KEYVAULT_NAME
ARG AGENT_KEYVAULT_SECRET
ARG AGENT_URL
ARG LABELS
ARG MSI_ID
ARG WORK_FOLDER
ARG AGENT_NAME
ARG REGISTER_PAUSED=false
ARG USERNAME

ENV DEBIAN_FRONTEND=noninteractive \
    ROVER_RUNNER=true \
    AGENT_TOKEN=${AGENT_TOKEN} \
    AGENT_KEYVAULT_NAME=${AGENT_KEYVAULT_NAME} \
    AGENT_KEYVAULT_SECRET=${AGENT_KEYVAULT_SECRET} \
    AGENT_URL=${AGENT_URL} \
    LABELS=${LABELS} \
    MSI_ID=${MSI_ID} \
    WORK_FOLDER=${WORK_FOLDER} \
    AGENT_NAME=${AGENT_NAME} \
    REGISTER_PAUSED=${REGISTER_PAUSED} \
    USERNAME=${USERNAME}

CMD ["/bin/bash"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./gitlab/gitlab.sh .

RUN echo "Installing Gitlab runner ..." && \
    sudo curl -L --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64" 2>&1 && \
    sudo chmod +x /usr/local/bin/gitlab-runner && \
    sudo gitlab-runner install --user=${USERNAME} --working-directory=/home/${USERNAME}/agent && \
    sudo chmod +x ./gitlab.sh

ENTRYPOINT ["./gitlab.sh"]