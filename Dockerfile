###########################################################
# base tools and dependencies
###########################################################
FROM ubuntu:20.04 as base

SHELL ["/bin/bash", "-c"]

# Arguments set during docker-compose build -b --build from .env file

ARG versionAzureCli
ARG versionKubectl
ARG versionTflint
ARG versionGit
ARG versionJq
ARG versionDockerCompose
ARG versionTfsec
ARG versionAnsible
ARG versionPacker
ARG versionCheckov
ARG versionMssqlTools
ARG versionTerraformDocs
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG SSH_PASSWD

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionAzureCli=${versionAzureCli} \
    versionKubectl=${versionKubectl} \
    versionTflint=${versionTflint} \
    versionJq=${versionJq} \
    versionGit=${versionGit} \
    versionDockerCompose=${versionDockerCompose} \
    versionTfsec=${versionTfsec} \
    versionAnsible=${versionAnsible} \
    versionPacker=${versionPacker} \
    versionCheckov=${versionCheckov} \
    versionMssqlTools=${versionMssqlTools} \
    versionTerraformDocs=${versionTerraformDocs} \
    PATH="${PATH}:/opt/mssql-tools/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache" \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /tf/rover
COPY ./.pip_to_patch_latest .

# installation tools
RUN apt-get update && \
    apt-get install -y \
    apt-utils \
    curl \
    gettext \
    python3-pip \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    unzip \
    sudo \
    locales \
    vim \
    gpg \
    gpg-agent && \
    # ############### APT Repositories ###################
    #
    # Add Azure repository
    #
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null && \
    #
    # Add Azure CLI apt repository
    #
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ focal main"  | \
    tee /etc/apt/sources.list.d/azure-cli.list && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/msprod.list && \
    #
    # Add Docker repository
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" && \
    #
    # Add Terraform repository
    #
    curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com focal main" && \
    #
    # Kubernetes repo
    #
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    #
    apt-get update -y && \
    apt-get upgrade -y && \
    #
    # Create USERNAME
    #
    echo "Creating ${USERNAME} user..." && \
    groupadd docker && \
    useradd --uid $USER_UID -m -G docker ${USERNAME} && \
    #
    # Set the locale
    locale-gen en_US.UTF-8 && \
    #
    # ################# Install clients ###################
    #
    #
    # Install Docker-Compose - required to rebuild the rover from the rover ;)
    #
    echo "Installing docker-compose ${versionDockerCompose}..." && \
    curl -L -o /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${versionDockerCompose}/docker-compose-Linux-x86_64" && \
    chmod +x /usr/bin/docker-compose && \
    #
    # Install Helm
    #
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    #
    # Install tflint
    #
    echo "Installing tflint ${versionTflint}..." && \
    curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/download/v${versionTflint}/tflint_linux_amd64.zip && \
    unzip -d /usr/bin /tmp/tflint.zip && \
    chmod +x /usr/bin/tflint && \
    #
    # Install tfsec
    #
    echo "Installing tfsec ${versionTfsec} ..." && \
    curl -sSL -o /bin/tfsec https://github.com/tfsec/tfsec/releases/download/v${versionTfsec}/tfsec-linux-amd64 && \
    chmod +x /bin/tfsec && \
    #
    # Install terraform docs
    #
    echo "Installing terraform docs ${versionTerraformDocs}..." && \
    curl -sSL -o /bin/terraform-docs https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v0.11.1-linux-amd64 && \
    chmod +x /bin/terraform-docs && \
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
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
        azure-cli=${versionAzureCli}-1~focal \
        mssql-tools=${versionMssqlTools}-1 \
        kubectl=${versionKubectl}-00 \
        packer=${versionPacker} \
        docker-ce-cli \
        git=1:${versionGit}-1ubuntu3 \
        ansible=${versionAnsible}+dfsg-1 \
        openssh-server \
        fonts-powerline \
        jq=${versionJq}-1ubuntu0.20.04.1 && \
    #
    # Patch
    # to regenerate the list - pip3 list --outdated --format=columns |tail -n +3|cut -d" " -f1 > pip_to_patch_latest
    #
    for i in  $(cat ./.pip_to_patch_latest); do pip3 install $i --upgrade; done && \
    #
    # Clean-up
    #
    apt-get remove -y \
        apt-utils \
        python3-pip && \
    apt-get autoremove -y && \
    rm -f /tmp/*.zip && rm -f /tmp/*.gz && \
    rm -rf /var/lib/apt/lists/* && \
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
    # for non-root user
    mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME} /commandhistory && \
    echo "set -o history" >> "/home/${USERNAME}/.bashrc" && \
    echo "export HISTCONTROL=ignoredups:erasedups"  >> "/home/${USERNAME}/.bashrc" && \
    echo "PROMPT_COMMAND=\"${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r\"" >> "/home/${USERNAME}/.bashrc"


COPY ./scripts/rover.sh .
COPY ./scripts/tfstate_azurerm.sh .
COPY ./scripts/functions.sh .
COPY ./scripts/banner.sh .
COPY ./scripts/clone.sh .
COPY ./scripts/sshd.sh .
COPY ./scripts/backend.hcl.tf .

#
# Switch to non-root ${USERNAME} context
#

USER ${USERNAME}

COPY .devcontainer/.zshrc $HOME
COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

RUN echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.zshrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.bashrc && \
    #
    # ssh server for Azure ACI
    #
    ssh-keygen -q -N "" -t ecdsa -b 521 -f /home/${USERNAME}/.ssh/ssh_host_ecdsa_key && \
    sudo apt-get update && \
    sudo apt-get install -y \
        zsh && \
    #
    # Install Oh My Zsh
    #
    # chsh -s /bin/zsh ${USERNAME} && \
    sudo runuser -l ${USERNAME} -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    chmod 700 -R /home/${USERNAME}/.oh-my-zsh


from base

ARG versionTerraform
ARG USERNAME=vscode
ARG versionRover

ENV versionRover=${versionRover} \
    versionTerraform=${versionTerraform}

    #
    # Install Terraform
    #
    # Keeping this method to support alpha build installations
RUN echo "Installing Terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_linux_amd64.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/terraform.zip && \
    sudo chmod +x /usr/bin/terraform && \
    mkdir -p /home/${USERNAME}/.terraform.cache/plugin-cache && \
    rm /tmp/terraform.zip && \
    #
    echo ${versionRover} > /tf/rover/version.txt