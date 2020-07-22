FROM centos:7 as rover_version

ARG versionRover

RUN echo ${versionRover} > version.txt


# There is no latest git package for centos 7. So building it from source using docker multi-stage builds
# also speed-up sub-sequent builds


###########################################################
# base tools and dependencies
###########################################################
FROM centos:7 as base

RUN yum makecache fast && \
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
        ansible \
        which && \
    yum -y update


###########################################################
# Getting latest version of terraform-docs
###########################################################
FROM golang:1.13 as terraform-docs

ARG versionTerraformDocs
ENV versionTerraformDocs=${versionTerraformDocs}

RUN GO111MODULE="on" go get github.com/segmentio/terraform-docs@${versionTerraformDocs}

###########################################################
# Getting latest version of tfsec
###########################################################
FROM golang:1.13 as tfsec

# to force the docker cache to invalidate when there is a new version
RUN env GO111MODULE=on go get -u github.com/liamg/tfsec/cmd/tfsec

###########################################################
# Getting latest version of Azure CAF Terraform provider
###########################################################
FROM golang:1.13 as azurecaf

ARG versionAzureCafTerraform
ENV versionAzureCafTerraform=${versionAzureCafTerraform}

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/tags/${versionAzureCafTerraform} version.json
RUN cd /tmp && \
    git clone https://github.com/aztfmod/terraform-provider-azurecaf.git && \
    cd terraform-provider-azurecaf && \
    go build -o terraform-provider-azurecaf

###########################################################
# Getting latest version of yaegashi/terraform-provider-msgraph
###########################################################
FROM golang:1.13 as msgraph

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/terraform-provider-azurecaf/git/ref/heads/master version.json
RUN cd /tmp && \
    git clone https://github.com/yaegashi/terraform-provider-msgraph.git && \
    cd terraform-provider-msgraph && \
    go build -o terraform-provider-msgraph



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
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache"
     
RUN yum -y install \
        make \
        zlib-devel \
        curl-devel \ 
        gettext \
        bzip2 \
        gcc \
        unzip && \
    #
    # Install git from source code
    #
    echo "Installing git ${versionGit}..." && \
    curl -sSL -o /tmp/git.tar.gz https://www.kernel.org/pub/software/scm/git/git-${versionGit}.tar.gz && \
    tar xvf /tmp/git.tar.gz -C /tmp && \
    cd /tmp/git-${versionGit} && \
    ./configure --exec-prefix="/usr" && \
    make -j && \
    make install && \
    #
    # Install Docker CE CLI.
    #
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    yum -y install docker-ce-cli && \
    touch /var/run/docker.sock && \
    chmod 666 /var/run/docker.sock && \
    #
    # Install Terraform
    #
    echo "Installing terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/bin /tmp/terraform.zip && \
    chmod +x /usr/bin/terraform && \
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
    # Install pre-commit
    #
    echo "Installing pre-commit ..." && \
    python3 -m pip install pre-commit && \ 
    #
    # Install tflint
    #
    echo "Installing tflint ..." && \
    curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/${versionTflint}/tflint_linux_amd64.zip && \
    unzip -d /usr/bin /tmp/tflint.zip && \
    chmod +x /usr/bin/tflint && \
    #
    # Clean-up
    rm -f /tmp/*.zip && rm -f /tmp/*.gz && \
    rm -rfd /tmp/git-${versionGit} && \
    # 
    echo "Creating ${USERNAME} user..." && \
    useradd --uid $USER_UID -m -G docker ${USERNAME} && \
    # sudo usermod -aG docker ${USERNAME} && \
    mkdir -p /home/${USERNAME}/.vscode-server /home/${USERNAME}/.vscode-server-insiders /home/${USERNAME}/.ssh /home/${USERNAME}/.ssh-localhost /home/${USERNAME}/.azure /home/${USERNAME}/.terraform.cache /home/${USERNAME}/.terraform.cache/tfstates && \
    chown ${USER_UID}:${USER_GID} /home/${USERNAME}/.vscode-server* /home/${USERNAME}/.ssh /home/${USERNAME}/.ssh-localhost /home/${USERNAME}/.azure /home/${USERNAME}/.terraform.cache /home/${USERNAME}/.terraform.cache/tfstates  && \
    yum install -y sudo && \
    echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# ssh server for Azure ACI
RUN yum install -y openssh-server && \
    rm -f /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_rsa_key /home/${USERNAME}/.ssh/ssh_host_ecdsa_key && \
    ssh-keygen -q -N "" -t ecdsa -b 521 -f /home/${USERNAME}/.ssh/ssh_host_ecdsa_key && \
    mkdir -p /home/${USERNAME}/.ssh

COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config


# Add Community terraform providers
COPY --from=azurecaf /tmp/terraform-provider-azurecaf/terraform-provider-azurecaf /bin/
COPY --from=msgraph /tmp/terraform-provider-msgraph/terraform-provider-msgraph /bin/
COPY --from=tfsec /go/bin/tfsec /bin/
COPY --from=terraform-docs /go/bin/terraform-docs /bin/

WORKDIR /tf/rover
COPY ./scripts/rover.sh .
COPY ./scripts/functions.sh .
COPY ./scripts/banner.sh .
COPY ./scripts/clone.sh .
COPY ./scripts/sshd.sh .
COPY --from=rover_version version.txt /tf/rover/version.txt

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    mkdir -p /tf/caf && \
    chown -R ${USERNAME}:1000 /tf/rover /tf/caf /home/${USERNAME}/.ssh && \
    chmod +x /tf/rover/sshd.sh

USER ${USERNAME}

EXPOSE 22
CMD  ["/tf/rover/sshd.sh"]