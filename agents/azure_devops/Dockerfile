ARG versionRover=${versionRover}
FROM ${versionRover}

ARG AGENT_KEYVAULT_NAME
ARG MSI_ID
ARG SECRET_NAME
ARG SUBSCRIPTION_ID
ARG TARGETARCH
ARG TARGETOS
ARG USERNAME
ARG versionAzdo
ARG VSTS_AGENT_INPUT_AGENT
ARG VSTS_AGENT_INPUT_AUTH="pat"
ARG VSTS_AGENT_INPUT_POOL
ARG VSTS_AGENT_INPUT_SECRET
ARG VSTS_AGENT_INPUT_TOKEN
ARG VSTS_AGENT_INPUT_URL
ARG VSTS_AGENT_KEYVAULT_NAME
ARG versionNode="20"

ENV AGENT_KEYVAULT_NAME=${AGENT_KEYVAULT_NAME} \
    DEBIAN_FRONTEND=noninteractive \
    MSI_ID=${MSI_ID} \
    ROVER_RUNNER=true \
    SECRET_NAME=${SECRET_NAME} \
    SUBSCRIPTION_ID=${SUBSCRIPTION_ID} \
    TARGETARCH=${TARGETARCH} \
    TARGETOS=${TARGETOS} \
    USERNAME=${USERNAME} \
    versionAzdo=${versionAzdo} \
    versionNode=${versionNode} \
    VSTS_AGENT_INPUT_AGENT=${VSTS_AGENT_INPUT_AGENT} \
    VSTS_AGENT_INPUT_AUTH=${VSTS_AGENT_INPUT_AUTH} \
    VSTS_AGENT_INPUT_POOL=${VSTS_AGENT_INPUT_POOL} \
    VSTS_AGENT_INPUT_SECRET=${VSTS_AGENT_INPUT_SECRET} \
    VSTS_AGENT_INPUT_TOKEN=${VSTS_AGENT_INPUT_TOKEN} \
    VSTS_AGENT_INPUT_URL=${VSTS_AGENT_INPUT_URL} \
    VSTS_AGENT_KEYVAULT_NAME=${VSTS_AGENT_KEYVAULT_NAME}
    # https://github.com/microsoft/azure-pipelines-agent/issues/3599#issuecomment-1083564092

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./agents/azure_devops/azdo.sh .

RUN echo "versionRover=${versionRover}" && \
    echo "CAF Rover Agent for Azure Devops" && \
    latestAzdo="$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')" && \
    echo "Info - Release "${latestAzdo}" appears to be latest" && \
    #
    echo "Downloading Azure devops agent version ${versionAzdo} for architecture ${TARGETARCH}..." && \
    #
    if [ ${TARGETARCH} == "amd64" ]; then \
        AGENTURL="https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-x64-${versionAzdo}.tar.gz" ; \
    else  \
        AGENTURL="https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-arm64-${versionAzdo}.tar.gz" ; \
    fi \
    && curl -s ${AGENTURL} -o /tmp/agent_package.tar.gz && \
    tar zxvf /tmp/agent_package.tar.gz && \
    sudo chmod +x ./azdo.sh && \
    #
    # Cleanup
    #
    rm -rf /tmp/* && \
    #
    # install node # https://github.com/microsoft/azure-pipelines-agent/pull/4240
    #
    curl -sL https://deb.nodesource.com/setup_${versionNode}.x | sudo -E bash - && \
    sudo apt-get install -y nodejs && \
    node --version

CMD /bin/bash -c ./azdo.sh