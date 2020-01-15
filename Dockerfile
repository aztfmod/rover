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
        man \
        ansible \
        which && \
    yum -y update


###########################################################
# CAF rover image
###########################################################
FROM base

# Arguments set during docker-compose build -b --build from .env file
ARG versionTerraform
ARG versionAzureCli
ARG versionTflint
ARG versionGit
ARG versionJq
ARG versionDockerCompose
ARG versionLaunchpadOpensource

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV versionTerraform=${versionTerraform} \
    versionAzureCli=${versionAzureCli} \
    versionTflint=${versionTflint} \
    versionJq=${versionJq} \
    versionGit=${versionGit} \
    versionDockerCompose=${versionDockerCompose} \
    versionLaunchpadOpensource=${versionLaunchpadOpensource} \
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
    echo "Installing git ${versionGit}..." && \
    curl -sSL -o /tmp/git.tar.gz https://www.kernel.org/pub/software/scm/git/git-${versionGit}.tar.gz && \
    tar xvf /tmp/git.tar.gz -C /tmp && \
    cd /tmp/git-${versionGit} && \
    ./configure && make && make install && \
    # Install Docker CE CLI.
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
    yum -y install docker-ce-cli && \
    #
    # Install Terraform
    echo "Installing terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip 2>&1 && \
    unzip -d /usr/local/bin /tmp/terraform.zip && \
    #
    # Install Docker-Compose - required to rebuild the rover from the rover ;)
    echo "Installing docker-compose ${versionDockerCompose}..." && \
    curl -sSL -o /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${versionDockerCompose}/docker-compose-Linux-x86_64" && \
    chmod +x /usr/bin/docker-compose && \
    #
    # Install Azure-cli
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
    echo "Installing jq ${versionJq}..." && \
    curl -sSL -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-${versionJq}/jq-linux64 && \
    chmod +x /usr/local/bin/jq && \
    #
    # echo "Installing graphviz ..." && \
    # yum -y install graphviz && \
    # && echo "Installing tflint ..." \
    # && curl -sSL -o /tmp/tflint.zip https://github.com/wata727/tflint/releases/download/v${versionTflint}/tflint_linux_amd64.zip \
    # && unzip -d /usr/local/bin /tmp/tflint.zip \
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

WORKDIR /tf/rover

COPY ./scripts/rover.sh .
COPY ./scripts/launchpad.sh .
COPY ./scripts/functions.sh .

# to force the docker cache to invalidate when there is a new version
ADD https://api.github.com/repos/aztfmod/level0/git/refs/heads/${versionLaunchpadOpensource} version.json
RUN echo "cloning the launchpads version ${versionLaunchpadOpensource}" && \
    mkdir -p /tf/launchpads && \
    git clone https://github.com/aztfmod/level0.git /tf/launchpads --branch ${versionLaunchpadOpensource} && \
    chown -R ${USERNAME}:1000 /tf/launchpads && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias launchpad=/tf/rover/launchpad.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/local/bin/terraform" >> /home/${USERNAME}/.bashrc



USER ${USERNAME}
