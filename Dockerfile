###########################################################
# base tools and dependencies
###########################################################
FROM --platform=${TARGETPLATFORM} ubuntu:22.04 as base

SHELL ["/bin/bash", "-c"]

# Arguments set during docker-compose build -b --build from .env file

ARG versionVault \
    versionKubectl \
    versionKubelogin \
    versionDockerCompose \
    versionPowershell \
    versionPacker \
    versionGolang \
    versionTerraformDocs \
    versionAnsible \
    versionTerrascan \
    extensionsAzureCli \
    SSH_PASSWD \
    TARGETARCH \
    TARGETOS

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV SSH_PASSWD=${SSH_PASSWD} \
    USERNAME=${USERNAME} \
    versionVault=${versionVault} \
    versionGolang=${versionGolang} \
    versionKubectl=${versionKubectl} \
    versionKubelogin=${versionKubelogin} \
    versionDockerCompose=${versionDockerCompose} \
    versionTerraformDocs=${versionTerraformDocs} \
    versionPacker=${versionPacker} \
    versionPowershell=${versionPowershell} \
    versionAnsible=${versionAnsible} \
    extensionsAzureCli=${extensionsAzureCli} \
    versionTerrascan=${versionTerrascan} \
    PATH="${PATH}:/opt/mssql-tools/bin:/home/vscode/.local/lib/shellspec/bin:/home/vscode/go/bin:/usr/local/go/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="/tf/cache" \
    TF_REGISTRY_DISCOVERY_RETRY=5 \
    TF_REGISTRY_CLIENT_TIMEOUT=15 \
    ARM_USE_MSGRAPH=true \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

WORKDIR /tf/rover
COPY ./scripts/.kubectl_aliases .
COPY ./scripts/zsh-autosuggestions.zsh .

    # installation common tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    bsdmainutils \
    ca-certificates \
    curl \
    fonts-powerline \
    gcc \
    gettext \
    git \
    gpg \
    gpg-agent \
    jq \
    less \
    locales \
    make \
    # Networking tools
    dnsutils net-tools iputils-ping traceroute \
    python3-dev \
    python3-pip \
    rsync \
    # openvpn client and ipsec tools to generate certificates
    openvpn network-manager-openvpn strongswan strongswan-pki libstrongswan-extra-plugins libtss2-tcti-tabrmd0 openssh-client \
    #
    software-properties-common \
    sudo \
    unzip \
    vim \
    wget \
    zip && \
    #
    # Create USERNAME
    #
    echo "Creating ${USERNAME} user..." && \
    groupadd docker && \
    useradd --uid $USER_UID -m -G docker ${USERNAME}  && \
    #
    # Set the locale
    locale-gen en_US.UTF-8 && \
    #
    # ############### APT Repositories ###################
    #
    # Add Microsoft key
    #
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg && \
    #
    # Add Microsoft repository
    #
    sudo apt-add-repository https://packages.microsoft.com/ubuntu/22.04/prod && \
    #
    # Add Docker repository
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg && \
    echo "deb [arch=${TARGETARCH}] https://download.docker.com/linux/ubuntu focal stable" > /etc/apt/sources.list.d/docker.list && \
    #
    # Kubernetes repo
    #
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    #
    # Github shell
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&\
    #
    apt-get update && \
    apt-get install -y --no-install-recommends \
    docker-ce-cli \
    kubectl \
    gh && \
    #
    # Install Docker Compose - required to rebuild the rover and dynamic terminal in VSCode
    #
    echo "Installing docker compose ${versionDockerCompose}..." && \
    mkdir -p /usr/libexec/docker/cli-plugins/ && \
    if [ ${TARGETARCH} == "amd64" ]; then \
        curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-x86_64 ; \
    else  \
        curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-aarch64 ; \
    fi  \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
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
    # Install terrascan
    #
    echo "Installing terrascan v${versionTerrascan} ..." && \
    if [ ${TARGETARCH} == "amd64" ]; then \
        curl -sSL -o terrascan.tar.gz https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_x86_64.tar.gz ; \
    else \
        curl -sSL -o terrascan.tar.gz https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_${TARGETARCH}.tar.gz ; \
    fi  \
    && tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    install terrascan /usr/local/bin && rm terrascan && \
    #
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
    fi \
    && mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    # echo "Installing PowerShell modules..." && \
    # pwsh -Command Install-Module -name Az.DesktopVirtualization -Force && \
    # pwsh -Command Install-Module -name Az.Resources -Force && \
    #
    # kubectl node shell
    #
    curl -L0 -o /usr/local/bin/kubectl-node_shell https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell && \
    chmod +x /usr/local/bin/kubectl-node_shell && \
    #
    # Hashicorp Packer
    #
    echo "Installing Packer ${versionPacker}..." && \
    curl -sSL -o /tmp/packer.zip https://releases.hashicorp.com/packer/${versionPacker}/packer_${versionPacker}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    unzip -d /usr/bin /tmp/packer.zip && \
    chmod +x /usr/bin/packer && \
    #
    # Kubelogin
    #
    echo "Installing Kubelogin ${versionKubelogin}..." && \
    curl -sSL -o /tmp/kubelogin.zip https://github.com/Azure/kubelogin/releases/download/v${versionKubelogin}/kubelogin-${TARGETOS}-${TARGETARCH}.zip 2>&1 && \
    unzip -d /usr/ /tmp/kubelogin.zip && \
    if [ ${TARGETARCH} == "amd64" ]; then \
        chmod +x /usr/bin/linux_amd64/kubelogin ; \
    else \
        chmod +x /usr/bin/linux_arm64/kubelogin ; \
    fi  && \
    # Hashicorp Vault
    #
    echo "Installing Vault ${versionVault}..." && \
    curl -sSL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    unzip -d /usr/bin /tmp/vault.zip && \
    chmod +x /usr/bin/vault && \
    setcap cap_ipc_lock=-ep /usr/bin/vault && \
    #
    # ################# Install PIP clients ###################
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
    az extension add --name ${extensionsAzureCli} --system && \
    az extension add --name containerapp --system && \
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
    pip3 install pywinrm && \
    #
    #
    # Install Ansible
    #
    echo "Installing Ansible ${versionAnsible} ..." && \
    pip3 install ansible-core==${versionAnsible} && \
    #
    #
    # ################ Install apt packages ##################
    # For amd64 only - as no arm64 version packages available per:  https://packages.microsoft.com/ubuntu/20.04/prod/pool/main/m/mssql-tools/
    if [ ${TARGETARCH} == "amd64" ]; then \
        echo ACCEPT_EULA=Y apt-get install -y --no-install-recommends unixodbc mssql-tools; \
    else \
        echo "mssql-tools skipped as not running on amr64"; \
    fi \
    #
    && echo "Installing latest shellspec..." && \
    curl -fsSL https://git.io/shellspec | sh -s -- --yes && \
    #
    # Golang
    #
    echo "Installing Golang ${versionGolang}..." && \
    curl -sSL -o /tmp/golang.tar.gz https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz  2>&1 && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    export PATH=$PATH:/usr/local/go/bin && \
    go version && \
    #
    echo "Installing latest Tflint Ruleset for Azure" && \
    curl -sSL -o /tmp/tflint-ruleset-azurerm.zip https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/latest/download/tflint-ruleset-azurerm_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    mkdir -p /home/${USERNAME}/.tflint.d/plugins  && \
    mkdir -p /home/${USERNAME}/.tflint.d/config  && \
    echo "plugin \"azurerm\" {" > /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "    enabled = true" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    echo "}" >> /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
    unzip -d /home/${USERNAME}/.tflint.d/plugins /tmp/tflint-ruleset-azurerm.zip && \
    #
    # Change ownership on the plugin cache directory
    mkdir /tf/cache && \
    chown -R ${USERNAME}:${USERNAME} ${TF_PLUGIN_CACHE_DIR} && \
    #
    # Create USERNAME home folder structure
    #
    mkdir -p /tf/caf \
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
    echo "alias watch=\"watch \"" >> "/home/${USERNAME}/.bashrc" && \
    #
    # Clean-up
    #
    apt-get remove -y \
        gcc \
        python3-dev \
        apt-utils && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    find . | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf



#
# Switch to non-root ${USERNAME} context
#

USER ${USERNAME}

COPY .devcontainer/.zshrc $HOME
COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

#
# ssh server for Azure ACI
#
RUN sudo apt-get update && \
    sudo apt-get install -y \
    zsh && \
    #
    # Install Oh My Zsh
    #
    sudo runuser -l ${USERNAME} -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' && \
    chmod 700 -R /home/${USERNAME}/.oh-my-zsh && \
    echo "DISABLE_UNTRACKED_FILES_DIRTY=\"true\"" >> /home/${USERNAME}/.zshrc && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.bashrc && \
    echo "alias rover=/tf/rover/rover.sh" >> /home/${USERNAME}/.zshrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.bashrc && \
    echo "alias t=/usr/bin/terraform" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.zshrc && \
    echo "alias k=/usr/bin/kubectl" >> /home/${USERNAME}/.bashrc && \
    echo "cd /tf/caf || true" >> /home/${USERNAME}/.bashrc && \
    echo "cd /tf/caf || true" >> /home/${USERNAME}/.zshrc && \
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
RUN echo  "Set rover version to ${versionRover}..." && echo "Installing Terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    sudo unzip -d /usr/bin /tmp/terraform.zip && \
    sudo chmod +x /usr/bin/terraform && \
    mkdir -p /home/${USERNAME}/.terraform.cache/plugin-cache && \
    rm /tmp/terraform.zip && \
    #
    echo  "Set rover version to ${versionRover}..." && \
    echo "${versionRover}" > /tf/rover/version.txt


COPY ./scripts/rover.sh ./scripts/tfstate.sh ./scripts/functions.sh ./scripts/remote.sh ./scripts/parse_command.sh ./scripts/banner.sh ./scripts/clone.sh ./scripts/walkthrough.sh ./scripts/sshd.sh ./scripts/backend.hcl.tf ./scripts/backend.azurerm.tf ./scripts/ci.sh ./scripts/cd.sh ./scripts/task.sh ./scripts/symphony_yaml.sh ./scripts/test_runner.sh ./
COPY ./scripts/ci_tasks/* ./ci_tasks/
COPY ./scripts/lib/* ./lib/
COPY ./scripts/tfcloud/* ./tfcloud/