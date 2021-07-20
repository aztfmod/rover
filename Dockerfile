###########################################################
# base tools and dependencies
###########################################################
FROM ubuntu:21.04 as base

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
    PATH="${PATH}:/opt/mssql-tools/bin:/home/vscode/.local/lib/shellspec/bin:/home/vscode/go/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache" \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /tf/rover
COPY ./.pip_to_patch_latest .
COPY ./scripts/.kubectl_aliases .
COPY ./scripts/zsh-autosuggestions.zsh .


    # installation common tools
RUN apt-get update && \
    apt-get install -y \
    curl \
    ca-certificates \
    apt-transport-https \
    gettext \
    software-properties-common \
    unzip \
    zip \
    make \
    sudo \
    locales \
    vim \
    gpg \
    apt-utils \
    gpg-agent && \
    #
    # Create USERNAME
    #
    echo "Creating ${USERNAME} user..." && \
    groupadd docker && \
    useradd --uid $USER_UID -m -G docker ${USERNAME} && \
    #
    # Set the locale
    locale-gen en_US.UTF-8


    #
    # ############### APT Repositories ###################
    #
    # Add Microsoft key
    #
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg && \
    #
    # Add Microsoft repository
    #
    curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/msprod.list && \
    curl https://packages.microsoft.com/config/ubuntu/21.04/prod.list >> /etc/apt/sources.list.d/msprod.list && \
    #
    # Add Docker repository
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu hirsute stable" > /etc/apt/sources.list.d/docker.list && \
    #
    # Add Terraform repository
    #
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=amd64] https://apt.releases.hashicorp.com hirsute main" > /etc/apt/sources.list.d/hashicorp.list && \
    #
    # Kubernetes repo
    #
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg |  gpg --dearmor > /etc/apt/trusted.gpg.d/kubernetes-archive-keyring.gpg && \
    echo "deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list && \
    #
    apt-get update

    #
    # ################# Install binary clients ###################
    #
    #
    # Install Docker-Compose - required to rebuild the rover
    #
RUN echo "Installing docker-compose ${versionDockerCompose}..." && \
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
    curl -sSL -o /tmp/terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v${versionTerraformDocs}-linux-amd64.tar.gz && \
    tar -zxf /tmp/terraform-docs.tar.gz --directory=/usr/bin && \
    chmod +x /usr/bin/terraform-docs && \
    #
    # Install baash completions for git
    #
    echo "Installing bash completions for git" && \
    mkdir -p /etc/bash_completion.d/ && \
    curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o /etc/bash_completion.d/git-completion.bash && \
    #
    # kubectl node shell
    #
    curl -L0 -o /usr/local/bin/kubectl-node_shell https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell && \
    chmod +x /usr/local/bin/kubectl-node_shell

    #
    # ################# Install PIP clients ###################
    #
RUN apt-get install -y python3-pip && \
    #
    # Install pre-commit
    #
    echo "Installing pre-commit ..." && \
    pip3 install pre-commit && \
    #
    # Install yq
    #
    echo "Installing yq ..." && \
    pip3 install yq && \
    #
    # Install Azure-cli
    #
    pip3 install azure-cli==${versionAzureCli}  && \
    #
    # Install checkov
    #
    echo "Installing Checkov ${versionCheckov} ..." && \
    pip3 install checkov==${versionCheckov} && \
    #
    # Install pywinrm
    #
    pip3 install pywinrm && \
    #
    # Clean-up
    #
    pip3 cache purge
    #
    # ################ Install apt packages ##################
    #
RUN ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    mssql-tools=${versionMssqlTools}-1
    #
RUN apt-get install -y --no-install-recommends \
    kubectl=${versionKubectl}-00

RUN apt-get install -y --no-install-recommends \
    packer=${versionPacker}

# RUN apt-get install -y --no-install-recommends \
#     vault

RUN apt-get install -y --no-install-recommends \
    docker-ce-cli

RUN apt-get install -y --no-install-recommends \
    golang

RUN apt-get install -y --no-install-recommends \
    git=${versionGit}

RUN apt-get install -y --no-install-recommends \
    ansible=${versionAnsible}

RUN apt-get install -y --no-install-recommends \
    openssh-server

RUN apt-get install -y --no-install-recommends \
    fonts-powerline

RUN apt-get install -y --no-install-recommends \
    jq=${versionJq}

RUN apt-get install -y --no-install-recommends \
    powershell && \
    pwsh -Command Install-Module -name Az.DesktopVirtualization -Force && \
    pwsh -Command Install-Module -name Az.Resources -Force

    #
    # Patch
    # to regenerate the list - pip3 list --outdated --format=columns |tail -n +3|cut -d" " -f1 > pip_to_patch_latest
    #
    # for i in  $(cat .pip_to_patch_latest); do pip3 install $i --upgrade; done && \
    # apt-get upgrade -y && \
    # Clean-up
    #
    # apt-get remove -y \
    # apt-utils && \
    # apt-get autoremove -y && \
    # rm -f /tmp/*.zip && rm -f /tmp/*.gz && \
    # rm -rf /var/lib/apt/lists/*

    #
    # Create USERNAME home folder structure
    #
RUN mkdir -p /tf/caf \
    /tf/rover \
    /tf/logs \
    /home/${USERNAME}/.ansible \
    /home/${USERNAME}/.azure \
    /home/${USERNAME}/.gnupg \
    /home/${USERNAME}/.packer.d \
    /home/${USERNAME}/.ssh \
    /home/${USERNAME}/.ssh-localhost \
    /home/${USERNAME}/.terraform.logs \
    /home/${USERNAME}/.terraform.cache \
    /home/${USERNAME}/.terraform.cache/tfstates \
    /home/${USERNAME}/.vscode-server \
    /home/${USERNAME}/.vscode-server-insiders && \
    chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} /tf/rover /tf/caf /tf/logs && \
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
    echo "PROMPT_COMMAND=\"${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r\"" >> "/home/${USERNAME}/.bashrc" && \
    echo "[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases" >>  "/home/${USERNAME}/.bashrc" && \
    echo "alias watch=\"watch \"" >> "/home/${USERNAME}/.bashrc"



COPY ./scripts/rover.sh .
COPY ./scripts/tfstate_azurerm.sh .
COPY ./scripts/functions.sh .
COPY ./scripts/banner.sh .
COPY ./scripts/clone.sh .
COPY ./scripts/walkthrough.sh .
COPY ./scripts/sshd.sh .
COPY ./scripts/backend.hcl.tf .
COPY ./scripts/ci.sh .
COPY ./scripts/cd.sh .
COPY ./scripts/task.sh .
COPY ./scripts/symphony_yaml.sh .
COPY ./scripts/test_runner.sh .
COPY ./scripts/ci_tasks/* ./ci_tasks/
COPY ./scripts/lib/* ./lib/
#
# Switch to non-root ${USERNAME} context
#

USER ${USERNAME}

COPY .devcontainer/.zshrc $HOME
COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

#
# ssh server for Azure ACI
#
RUN ssh-keygen -q -N "" -t ecdsa -b 521 -f /home/${USERNAME}/.ssh/ssh_host_ecdsa_key && \
    sudo apt-get update && \
    sudo apt-get install -y \
    zsh && \
    #
    # Install Oh My Zsh
    #
    # chsh -s /bin/zsh ${USERNAME} && \
    sudo runuser -l ${USERNAME} -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    chmod 700 -R /home/${USERNAME}/.oh-my-zsh && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.zshrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.bashrc && \
    echo "[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases" >>  /home/${USERNAME}/.zshrc && \
    echo "source /tf/rover/zsh-autosuggestions.zsh" >>  /home/${USERNAME}/.zshrc && \
    echo "alias watch=\"watch \"" >> /home/${USERNAME}/.zshrc


FROM base

ARG versionTerraform
ARG versionVault
ARG USERNAME=vscode
ARG versionRover
ARG versionTflintazrs

ENV versionRover=${versionRover} \
    versionVault=${versionVault} \
    versionTerraform=${versionTerraform} \
    versionTflintazrs=${versionTflintazrs}
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

RUN echo "Installing Vault ${versionVault}..." && \
    curl -sSL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_linux_amd64.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/vault.zip && \
    sudo chmod +x /usr/bin/vault && \
    sudo setcap cap_ipc_lock=-ep /usr/bin/vault && \
    rm /tmp/vault.zip

RUN echo "Installing Tflint Ruleset ${versionTflintazrs} for Azure..." && \
    curl -sSL -o /tmp/tflint-ruleset-azurerm.zip https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/download/v${versionTflintazrs}/tflint-ruleset-azurerm_linux_amd64.zip 2>&1 && \
    mkdir -p /home/${USERNAME}/.tflint.d/plugins  && \
    mkdir -p /home/${USERNAME}/.tflint.d/config  && \
    echo "plugin \"azurerm\" {" > /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "    enabled = true" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "}" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    sudo unzip -d /home/${USERNAME}/.tflint.d/plugins /tmp/tflint-ruleset-azurerm.zip && \
    rm /tmp/tflint-ruleset-azurerm.zip

RUN echo "Installing shellspec..." && \
    curl -fsSL https://git.io/shellspec | sh -s -- --yes


RUN echo "Installing caflint..." && \
    go install github.com/aztfmod/caflint@latest


