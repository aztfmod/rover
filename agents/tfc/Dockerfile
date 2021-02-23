ARG versionRover=${versionRover}
FROM ${versionRover}

ARG versionTfc
ARG TFC_AGENT_TOKEN
ARG TFC_AGENT_NAME
ARG USERNAME

ENV DEBIAN_FRONTEND=noninteractive \
    ROVER_RUNNER=true \
    versionTerraformCloudAgent=${versionTfc} \
    TFC_AGENT_TOKEN=${TFC_AGENT_TOKEN} \
    TFC_AGENT_NAME=${TFC_AGENT_NAME} \
    USERNAME=${USERNAME}

CMD ["/bin/bash"]

RUN mkdir /home/${USERNAME}/agent

WORKDIR /home/${USERNAME}/agent

RUN echo "Installing Terraform Cloud Agents ${versionTfc}..." && \
    sudo curl -L -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTerraformCloudAgent}/tfc-agent_${versionTerraformCloudAgent}_linux_amd64.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/tfc-agent.zip && \
    sudo chmod +x /usr/bin/tfc-agent && \
    sudo chmod +x /usr/bin/tfc-agent-core


ENTRYPOINT ["/usr/bin/tfc-agent -single"]