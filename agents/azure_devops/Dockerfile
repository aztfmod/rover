FROM rover_rover:latest

ARG VSTS_AGENT_INPUT_URL
ARG VSTS_AGENT_INPUT_POOL
ARG VSTS_AGENT_INPUT_TOKEN
ARG VSTS_AGENT_INPUT_AGENT
ARG VSTS_AGENT_INPUT_SECRET
ARG VSTS_AGENT_KEYVAULT_NAME
ARG VSTS_AGENT_INPUT_AUTH="pat"
ARG SUBSCRIPTION_ID
ARG SECRET_NAME
ARG AGENT_KEYVAULT_NAME
ARG MSI_ID
ARG USERNAME

ENV DEBIAN_FRONTEND=noninteractive \
    ROVER_RUNNER=true \
    VSTS_AGENT_INPUT_URL=${VSTS_AGENT_INPUT_URL} \
    VSTS_AGENT_INPUT_AUTH=${VSTS_AGENT_INPUT_AUTH} \
    VSTS_AGENT_INPUT_POOL=${VSTS_AGENT_INPUT_POOL} \
    VSTS_AGENT_INPUT_AGENT=${VSTS_AGENT_INPUT_AGENT} \
    VSTS_AGENT_INPUT_TOKEN=${VSTS_AGENT_INPUT_TOKEN} \
    VSTS_AGENT_KEYVAULT_NAME=${VSTS_AGENT_KEYVAULT_NAME} \
    VSTS_AGENT_INPUT_SECRET=${VSTS_AGENT_INPUT_SECRET} \
    SUBSCRIPTION_ID=${SUBSCRIPTION_ID} \
    SECRET_NAME=${SECRET_NAME} \
    AGENT_KEYVAULT_NAME=${AGENT_KEYVAULT_NAME} \
    MSI_ID=${MSI_ID} \
    USERNAME=${USERNAME}

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

COPY ./azure_devops/azdo.sh .

RUN AGENTRELEASE="$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")')" && \
    AGENTURL="https://vstsagentpackage.azureedge.net/agent/${AGENTRELEASE}/vsts-agent-linux-x64-${AGENTRELEASE}.tar.gz" && \
    echo "Release "${AGENTRELEASE}" appears to be latest" && \
    echo "Downloading..." && \
    curl -s ${AGENTURL} -o agent_package.tar.gz && \
    tar zxvf agent_package.tar.gz && \
    sudo ./bin/installdependencies.sh && \
    echo "dependencies installed" && \
    sudo chmod +x ./azdo.sh

CMD /bin/bash -c ./azdo.sh