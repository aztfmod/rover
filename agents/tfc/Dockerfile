ARG versionRover=${versionRover}
FROM ${versionRover}

ARG versionTfc
ARG TFC_AGENT_TOKEN
ARG TFC_AGENT_NAME
ARG USERNAME
ARG TFC_ADDRESS
ARG TFC_AGENT_AUTO_UPDATE
ARG TFC_AGENT_DATA_DIR

ENV DEBIAN_FRONTEND=noninteractive \
    ROVER_RUNNER=true \
    versionTerraformCloudAgent=${versionTfc} \
    TFC_AGENT_TOKEN=${TFC_AGENT_TOKEN} \
    TFC_AGENT_NAME=${TFC_AGENT_NAME} \
    TFC_ADDRESS=${TFC_ADDRESS:-https://app.terraform.io} \
    TFC_AGENT_AUTO_UPDATE=${TFC_AGENT_AUTO_UPDATE:-disabled} \
    TFC_AGENT_SINGLE=${TFC_AGENT_SINGLE:-false} \
    TFC_AGENT_DATA_DIR=${TFC_AGENT_DATA_DIR:-/home/vscode/agent/.tfc-agent} \
    TFC_AGENT_LOG_JSON=false \
    TFC_AGENT_LOG_LEVEL=info \
    USERNAME=${USERNAME:-vscode}

CMD ["/bin/bash"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

RUN echo "Installing Terraform Cloud Agents ${versionTfc}..." && \
    sudo curl -L -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTerraformCloudAgent}/tfc-agent_${versionTerraformCloudAgent}_linux_amd64.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/tfc-agent.zip && \
    sudo chmod +x /usr/bin/tfc-agent && \
    sudo chmod +x /usr/bin/tfc-agent-core

ENTRYPOINT ["/usr/bin/tfc-agent"]