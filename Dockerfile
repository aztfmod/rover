###########################################################
# base tools and dependencies
###########################################################
FROM --platform=${TARGETPLATFORM} ubuntu:20.04 as base

SHELL ["/bin/bash", "-c"]

# Arguments set during docker-compose build -b --build from .env file

ARG versionVault \
    versionKubectl \
    versionDockerCompose \
    versionPowershell \
    versionPacker \
    versionGolang \
    versionTerraformDocs \
    extensionsAzureCli \
    SSH_PASSWD \
    TARGETARCH \
    TARGETOS

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG TARGETOS

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionVault=${versionVault} \
    versionGolang=${versionGolang} \
    versionKubectl=${versionKubectl} \
    versionDockerCompose=${versionDockerCompose} \
    versionTerraformDocs=${versionTerraformDocs} \
    versionPacker=${versionPacker} \
    versionPowershell=${versionPowershell} \
    extensionsAzureCli=${extensionsAzureCli} \
    PATH="${PATH}:/opt/mssql-tools/bin:/home/vscode/.local/lib/shellspec/bin:/home/vscode/go/bin:/usr/local/go/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/home/${USERNAME}/.terraform.cache/plugin-cache" \
    TF_REGISTRY_DISCOVERY_RETRY=5 \
    TF_REGISTRY_CLIENT_TIMEOUT=15 \
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
    git \
    gettext \
    software-properties-common \
    unzip \
    zip \
    less \
    make \
    sudo \
    locales \
    wget \
    vim \
    gpg \
    apt-utils \
    gpg-agent \
    bsdmainutils && \
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
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg && \
    #
    # Add Microsoft repository
    #
    # curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/msprod.list && \
    sudo apt-add-repository https://packages.microsoft.com/ubuntu/20.04/prod && \
    # sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list)" && \
    # curl https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list > /etc/apt/sources.list.d/mssql-server-2019.list && \
    # echo "deb [arch=${TARGETARCH}] https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2019.list focal main" > /etc/apt/sources.list.d/msprod.list && \
    # curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list >> /etc/apt/sources.list.d/msprod.list && \
    #
    # Add Docker repository
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg && \
    echo "deb [arch=${TARGETARCH}] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list && \
    #
    # Add Terraform repository
    #
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=${TARGETARCH}] https://apt.releases.hashicorp.com focal main" > /etc/apt/sources.list.d/hashicorp.list && \
    #
    # Kubernetes repo
    #
    # curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg |  gpg --dearmor > /etc/apt/trusted.gpg.d/kubernetes-archive-keyring.gpg && \
    curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    # echo "deb [arch=${TARGETARCH}] https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list && \
    # #
    apt-get update && \
    apt-get clean

    #
    # ################# Install binary clients ###################
    #
    #
    # Install Docker-Compose - required to rebuild the rover
    #
RUN echo "Installing docker-compose ${versionDockerCompose}..." && \
    curl -L -o /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${versionDockerCompose}/docker-compose-${TARGETOS}-x86_64" && \
    chmod +x /usr/bin/docker-compose && \
    #
    # Install Helm
    #
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    #
    # Install tflint
    #
    echo "Installing latest tflint ..." && \
    curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/latest/download/tflint_${TARGETOS}_${TARGETARCH}.zip && \
    unzip -d /usr/bin /tmp/tflint.zip && \
    chmod +x /usr/bin/tflint && \
    #
    # Install tfsec
    #
    echo "Installing latest tfsec ..." && \
    curl -sSL -o /bin/tfsec https://github.com/tfsec/tfsec/releases/latest/download/tfsec-${TARGETOS}-${TARGETARCH} && \
    chmod +x /bin/tfsec && \
    #
    # Install terraform docs
    #
    echo "Installing terraform docs ${versionTerraformDocs}..." && \
    curl -sSL -o /tmp/terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v${versionTerraformDocs}-${TARGETOS}-${TARGETARCH}.tar.gz && \
    tar -zxf /tmp/terraform-docs.tar.gz --directory=/usr/bin && \
    chmod +x /usr/bin/terraform-docs && \
    #
    # Install bash completions for git
    #
    echo "Installing bash completions for git" && \
    mkdir -p /etc/bash_completion.d/ && \
    curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o /etc/bash_completion.d/git-completion.bash && \
    #
    # Install PowerShell via alternate method as apt not working for arm64
    # https://docs.microsoft.com/en-us/powershell/scripting/install/install-other-linux?view=powershell-7.2#binary-archives
    #
    echo "Installing PowerShell ${versionPowershell}..." && \
    if [ ${TARGETARCH} == "amd64" ]; then curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-x64.tar.gz ; \
    else curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-${TARGETARCH}.tar.gz ; \
    fi  && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    echo "Installing PowerShell modules..." && \
    pwsh -Command Install-Module -name Az.DesktopVirtualization -Force && \
    pwsh -Command Install-Module -name Az.Resources -Force && \
    #
    # kubectl node shell
    #
    curl -L0 -o /usr/local/bin/kubectl-node_shell https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell && \
    chmod +x /usr/local/bin/kubectl-node_shell
    #
    # Hashicorp Vault
    #
RUN echo "Installing Vault ${versionVault}..." && \
    curl -sSL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    unzip -d /usr/bin /tmp/vault.zip && \
    chmod +x /usr/bin/vault && \
    setcap cap_ipc_lock=-ep /usr/bin/vault && \
    rm /tmp/vault.zip
    #
    # ################# Install PIP clients ###################
    #
RUN apt-get install -y python3-pip && \
    #
    # Install pre-commit
    #
    echo "Installing latest pre-commit ..." && \
    pip3 install pre-commit && \
    #
    # Install yq
    #
    echo "Installing latest yq ..." && \
    pip3 install yq && \
    #
    # Install Azure-cli
    #
    echo "Installing latest Azure CLI ..." && \
    pip3 install azure-cli  && \
    az config set extension.use_dynamic_install=yes_without_prompt && \
    #
    # Install checkov
    #
    echo "Installing latest Checkov ..." && \
    pip3 install checkov && \
    #
    # Install pywinrm
    #
    echo "Installing latest pywinrm ..." && \
    pip3 install pywinrm

    #
    # ################ Install apt packages ##################
    # For amd64 only - as no arm64 version packages available per:  https://packages.microsoft.com/ubuntu/20.04/prod/pool/main/m/mssql-tools/
RUN if [ ${TARGETARCH} == "amd64" ]; then \
        echo ACCEPT_EULA=Y apt-get install -y --no-install-recommends unixodbc mssql-tools; \
    else \
        echo "mssql-tools skipped as not running on amd64"; \
    fi

RUN apt-get install -y --no-install-recommends \
    kubectl \
    packer \
    docker-ce-cli \
    git \
    ansible \
    openssh-server \
    fonts-powerline \
    jq

RUN echo "Installing latest shellspec..." && \
    curl -fsSL https://git.io/shellspec | sh -s -- --yes

RUN echo "Installing Golang ${versionGolang}..." && \
    curl -sSL -o /tmp/golang.tar.gz https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz  2>&1 && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    export PATH=$PATH:/usr/local/go/bin && \
    go version

RUN echo "Installing caflint..." && \
    go version && \
    go install github.com/aztfmod/caflint@latest

RUN echo "Installing latest Tflint Ruleset for Azure..." && \
    curl -sSL -o /tmp/tflint-ruleset-azurerm.zip https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/latest/download/tflint-ruleset-azurerm_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    mkdir -p /home/${USERNAME}/.tflint.d/plugins  && \
    mkdir -p /home/${USERNAME}/.tflint.d/config  && \
    echo "plugin \"azurerm\" {" > /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "    enabled = true" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "}" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    unzip -d /home/${USERNAME}/.tflint.d/plugins /tmp/tflint-ruleset-azurerm.zip && \
    rm /tmp/tflint-ruleset-azurerm.zip

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



COPY ./scripts/rover.sh ./scripts/tfstate.sh ./scripts/functions.sh ./scripts/parse_command.sh ./scripts/banner.sh ./scripts/clone.sh ./scripts/walkthrough.sh ./scripts/sshd.sh ./scripts/backend.hcl.tf ./scripts/backend.azurerm.tf ./scripts/ci.sh ./scripts/cd.sh ./scripts/task.sh ./scripts/symphony_yaml.sh ./scripts/test_runner.sh ./
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

ARG versionTerraform \
    USERNAME=vscode \
    versionRover

ENV versionRover=${versionRover} \
    versionTerraform=${versionTerraform}
#
# Install Terraform
#
# Keeping this method to support alpha build installations
RUN echo "Installing Terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/terraform.zip && \
    sudo chmod +x /usr/bin/terraform && \
    mkdir -p /home/${USERNAME}/.terraform.cache/plugin-cache && \
    rm /tmp/terraform.zip && \
    #
    echo ${versionRover} > /tf/rover/version.txt

