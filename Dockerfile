FROM centos:7 as rover_version

ARG versionRover

RUN echo ${versionRover} > version.txt


# There is no latest git package for centos 7. So building it from source using docker multi-stage builds
# also speed-up sub-sequent builds


###########################################################
# base tools and dependencies
###########################################################
FROM centos:7 as base

RUN yum makecache && \
    yum -y install \
        libtirpc \
        python3 \
        python3-libs \
        python3-pip \
        python3-setuptools \
        unzip \
        bzip2 \
        make \
        openssh-clients \
        openssl \
        man \
        perl \
        which && \
    yum clean all

###########################################################
# Getting latest version of terraform-docs
###########################################################
FROM golang:1.15.6 as terraform-docs

ARG versionTerraformDocs
ENV versionTerraformDocs=${versionTerraformDocs}

RUN GO111MODULE="on" go get github.com/terraform-docs/terraform-docs@${versionTerraformDocs}

###########################################################
# Getting latest version of tfsec
###########################################################
FROM golang:1.15.6 as tfsec

# to force the docker cache to invalidate when there is a new version
RUN env GO111MODULE=on go get -u github.com/tfsec/tfsec/cmd/tfsec

###########################################################
# CAF rover image
###########################################################
FROM base

# Arguments set during docker-compose build -b --build from .env file
ARG versionTerraform
ARG versionAzureCli
ARG versionKubectl
ARG versionTflint
ARG versionGit
ARG versionJq
ARG versionDockerCompose
ARG versionTfsec
ARG versionAnsible
ARG versionPacker
ARG versionTerraformCloudAgent
ARG versionCheckov

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG SSH_PASSWD

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionTerraform=${versionTerraform} \
    versionAzureCli=${versionAzureCli} \
    versionKubectl=${versionKubectl} \
    versionTflint=${versionTflint} \
    versionJq=${versionJq} \
    versionGit=${versionGit} \
    versionDockerCompose=${versionDockerCompose} \
    versionTfsec=${versionTfsec} \
    versionAnsible=${versionAnsible} \
    versionPacker=${versionPacker} \
    versionTerraformCloudAgent=${versionTerraformCloudAgent} \
    versionCheckov=${versionCheckov} \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache"

RUN yum -y install \
        make \
        zlib-devel \
        curl-devel \
        gettext \
        bzip2 \
        gcc \
        unzip \
        sudo \
        yum-utils \
        openssh-server && \
    yum clean all && \
    #
    # Install git from source code
    #
    echo "Installing git ${versionGit}..." && \
    curl -sSL -o /tmp/git.tar.gz https://www.kernel.org/pub/software/scm/git/git-${versionGit}.tar.gz && \
    tar xvf /tmp/git.tar.gz -C /tmp && \
    cd /tmp/git-${versionGit} && \
    ./configure --exec-prefix="/usr/local" && \
    make -j && \
    make install && \
    #
    # Install Docker CE CLI.
    #
    yum-config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo && \
    yum -y install docker-ce-cli && \
    touch /var/run/docker.sock && \
    chmod 666 /var/run/docker.sock && \
    #
    # Create USERNAME
    #
    echo "Creating ${USERNAME} user..." && \
    useradd --uid $USER_UID -m -G docker ${USERNAME} && \
    #
    # Install Terraform
    #
    echo "Installing Terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/bin /tmp/terraform.zip && \
    chmod +x /usr/bin/terraform && \
    mkdir -p /home/${USERNAME}/.terraform.cache/plugin-cache && \
    #
    # Install Terraform Cloud Agents
    #
    echo "Installing Terraform Cloud Agents ${versionTerraformCloudAgent}..." && \
    curl -sSL -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTerraformCloudAgent}/tfc-agent_${versionTerraformCloudAgent}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/bin /tmp/tfc-agent.zip && \
    chmod +x /usr/bin/tfc-agent && \
    chmod +x /usr/bin/tfc-agent-core && \
    #
    # Install Packer
    #
    echo "Installing Packer ${versionPacker}..." && \
    curl -sSL -o /tmp/packer.zip https://releases.hashicorp.com/packer/${versionPacker}/packer_${versionPacker}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/local/bin /tmp/packer.zip && \
    chmod +x /usr/local/bin/packer && \
    #
    # Install Docker-Compose - required to rebuild the rover from the rover ;)
    #
    echo "Installing docker-compose ${versionDockerCompose}..." && \
    curl -L -o /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${versionDockerCompose}/docker-compose-Linux-x86_64" && \
    chmod +x /usr/bin/docker-compose && \
    #
    # Install Azure-cli
    #
    echo "Installing azure-cli ${versionAzureCli}..." && \
    rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    sh -c 'echo -e "[azure-cli] \n\
name=Azure CLI \n\
baseurl=https://packages.microsoft.com/yumrepos/azure-cli \n\
enabled=1 \n\
gpgcheck=1 \n\
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo' && \
    cat /etc/yum.repos.d/azure-cli.repo && \
    yum -y install azure-cli-${versionAzureCli} && \
    #
    # Install kubectl
    #
    echo "Installing kubectl ${versionKubectl}..." && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${versionKubectl}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    #
    # Install Helm
    #
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    #
    # Install jq
    #
    echo "Installing jq ${versionJq}..." && \
    curl -L -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-${versionJq}/jq-linux64 && \
    chmod +x /usr/bin/jq && \
    #
    # Install tflint
    #
    echo "Installing tflint ..." && \
    curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/${versionTflint}/tflint_linux_amd64.zip && \
    unzip -d /usr/bin /tmp/tflint.zip && \
    chmod +x /usr/bin/tflint && \
    #
    # Install Ansible
    #
    echo "Installing Ansible ${versionAnsible}..." && \
    pip3 install --no-cache-dir ansible==${versionAnsible} && \
    #
    # Install pre-commit
    #
    echo "Installing pre-commit ..." && \
    pip3 install --no-cache-dir pre-commit && \
    #
    # Install yq
    #
    echo "Installing yq ..." && \
    pip3 install --no-cache-dir yq && \
    #
    # Install checkov
    #
    echo "Installing Checkov ${versionCheckov} ..." && \
    pip3 install --no-cache-dir checkov==${versionCheckov} && \
    #
    # Clean-up
    rm -f /tmp/*.zip && rm -f /tmp/*.gz && \
    rm -rfd /tmp/git-${versionGit} && \
    #
    # Create USERNAME home folder structure
    #
    mkdir -p /tf/caf \
        /tf/rover \
        /home/${USERNAME}/.ansible \
        /home/${USERNAME}/.azure \
        /home/${USERNAME}/.gnupg \
        /home/${USERNAME}/.packer.d \
        /home/${USERNAME}/.ssh \
        /home/${USERNAME}/.ssh-localhost \
        /home/${USERNAME}/.terraform.cache \
        /home/${USERNAME}/.terraform.cache/tfstates \
        /home/${USERNAME}/.vscode-server \
        /home/${USERNAME}/.vscode-server-insiders && \
    chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} /tf/rover /tf/caf && \
    chmod 777 -R /home/${USERNAME} /tf/caf /tf/rover && \
    chmod 700 /home/${USERNAME}/.ssh && \
    echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \

    SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" && \
    echo $SNIPPET >> "/root/.bashrc" && \
    # [Optional] If you have a non-root user
    mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R $USERNAME /commandhistory && \
    echo $SNIPPET >> "/home/$USERNAME/.bashrc"

# Add additional components
COPY --from=tfsec /go/bin/tfsec /bin/
COPY --from=terraform-docs /go/bin/terraform-docs /bin/

WORKDIR /tf/rover
COPY ./scripts/rover.sh .
COPY ./scripts/functions.sh .
COPY ./scripts/banner.sh .
COPY ./scripts/clone.sh .
COPY ./scripts/sshd.sh .
COPY ./scripts/tfc.sh .
COPY ./scripts/backend.hcl.tf .
COPY --from=rover_version version.txt /tf/rover/version.txt

#
# Switch to ${USERNAME} context
#

USER ${USERNAME}


COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.bashrc && \
    # chmod +x /tf/rover/sshd.sh && \
    #
    # ssh server for Azure ACI
    #
    ssh-keygen -q -N "" -t ecdsa -b 521 -f /home/${USERNAME}/.ssh/ssh_host_ecdsa_key



EXPOSE 22
CMD  ["/tf/rover/sshd.sh"]
