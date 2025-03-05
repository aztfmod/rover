###########################################################
# base tools and dependencies
###########################################################
FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-c"]

# Build arguments
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG TF_PLUGIN_CACHE_DIR=/tf/cache

# Version arguments
ARG versionDockerCompose
ARG versionGolang
ARG versionKubectl
ARG versionKubelogin
ARG versionPacker
ARG versionPowershell
ARG versionTerraformDocs
ARG versionVault
ARG versionAnsible
ARG versionTerrascan
ARG versionTfupdate
ARG extensionsAzureCli

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Set user environment variables
ENV USERNAME=${USERNAME} \
    USER_UID=${USER_UID} \
    USER_GID=${USER_GID} \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin:/opt/mssql-tools/bin:/home/${USERNAME}/.local/lib/shellspec/bin:/home/${USERNAME}/go/bin \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR=/tf/cache \
    TF_REGISTRY_DISCOVERY_RETRY=5 \
    TF_REGISTRY_CLIENT_TIMEOUT=15 \
    ARM_USE_MSGRAPH=true

# Configure locales first
RUN apt-get update && \
    apt-get install -y --no-install-recommends locales tzdata && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US:en

WORKDIR /tf/rover
COPY ./scripts/.kubectl_aliases .
COPY ./scripts/zsh-autosuggestions.zsh .

# Install common tools
# Remove duplicate ARG/ENV declarations

# Install base packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        bsdmainutils \
        ca-certificates \
        curl \
        gpg \
        gpg-agent && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
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
        dnsutils \
        net-tools \
        iputils-ping \
        traceroute \
        python3-dev \
        python3-pip \
        rsync \
        software-properties-common \
        sudo \
        unzip \
        vim \
        wget \
        zsh \
        zip && \
    #
    # Create user and group
    groupadd docker && \
    useradd --uid 1000 -m -G docker vscode && \
    #
    # ############### APT Repositories ###################
    #
    # Add Microsoft key
    #
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    #
    # Add Microsoft repository
    #
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/microsoft.list && \
    #
    # Add Docker repository
    #
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list && \
    #
    # Kubernetes repo
    #
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null &&\
    #
    # Github shell
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
    echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&\
    #
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce-cli \
        kubectl \
        gh \
        gosu \
        openvpn \
        network-manager-openvpn \
        strongswan \
        strongswan-pki \
        libstrongswan-extra-plugins \
        libtss2-tcti-tabrmd0 \
        openssh-client && \
    #
    # Install Docker Compose - required to rebuild the rover and dynamic terminal in VSCode
    #
    echo "Installing docker compose ${versionDockerCompose}..." && \
    mkdir -p /usr/libexec/docker/cli-plugins/ && \
    ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-${ARCH} && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
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
    ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x86_64" || echo "arm64") && \
    curl -sSL -o terrascan.tar.gz https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_${ARCH}.tar.gz && \
    tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    install terrascan /usr/local/bin && rm terrascan && \
    #
    # Install tfupdate
    #
    echo "Installing tfupdate v${versionTfupdate} ..." && \
    curl -sSL -o tfupdate.tar.gz https://github.com/minamijoyo/tfupdate/releases/download/v${versionTfupdate}/tfupdate_${versionTfupdate}_${TARGETOS}_${TARGETARCH}.tar.gz && \
    tar -xf tfupdate.tar.gz tfupdate && rm tfupdate.tar.gz && \
    install tfupdate /usr/local/bin && rm tfupdate && \
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
    ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-${ARCH}.tar.gz && \
    mkdir -p /opt/microsoft/powershell/7 && \
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
    rm /tmp/packer.zip && \
    #
    # Kubelogin
    #
    echo "Installing Kubelogin ${versionKubelogin}..." && \
    curl -sSL -o /tmp/kubelogin.zip https://github.com/Azure/kubelogin/releases/download/v${versionKubelogin}/kubelogin-${TARGETOS}-${TARGETARCH}.zip 2>&1 && \
    unzip -d /usr/bin /tmp/kubelogin.zip && \
    mv /usr/bin/bin/linux_${TARGETARCH}/kubelogin /usr/bin/kubelogin && \
    rm -rf /usr/bin/bin && \
    chmod +x /usr/bin/kubelogin && \
    # Hashicorp Vault
    #
    echo "Installing Vault ${versionVault}..." && \
    curl -sSL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_${TARGETOS}_${TARGETARCH}.zip 2>&1 && \
    unzip -o -d /usr/bin /tmp/vault.zip && \
    chmod +x /usr/bin/vault && \
    setcap cap_ipc_lock=-ep /usr/bin/vault && \
    rm /tmp/vault.zip && \
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
    echo "Installing Ansible 2.16.2 ..." && \
    pip3 install ansible-core==2.16.2 && \
    #
    #
    # ################ Install apt packages ##################
    # For amd64 only - as no arm64 version packages available per:  https://packages.microsoft.com/ubuntu/20.04/prod/pool/main/m/mssql-tools/
    if [ "${TARGETARCH}" = "amd64" ]; then \
        ACCEPT_EULA=Y apt-get install -y --no-install-recommends unixodbc mssql-tools; \
    else \
        echo "mssql-tools skipped as not running on arm64"; \
    fi && \
    echo "Installing latest shellspec..." && \
    curl -fsSL https://git.io/shellspec | sh -s -- --yes && \
    #
    # Golang
    #
    echo "Installing Golang ${versionGolang}..." && \
    curl -sSL -o /tmp/golang.tar.gz https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz && \
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
    echo "PROMPT_COMMAND='history -a; history -c; history -r'" >> "/home/${USERNAME}/.bashrc" && \
    echo '[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases' >>  "/home/${USERNAME}/.bashrc" && \
    echo 'alias watch="watch "' >> "/home/${USERNAME}/.bashrc" && \
    #
    # Clean-up
    #
    apt-get remove -y \
        gcc \
        python3-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    find / -type d -name __pycache__ -exec rm -r {} + 2>/dev/null || true && \
    find / -type f -name '*.py[cod]' -delete 2>/dev/null || true
#
# Switch to non-root ${USERNAME} context
#

COPY .devcontainer/.zshrc /home/${USERNAME}/
COPY ./scripts/sshd_config /home/${USERNAME}/.ssh/sshd_config

# Use a pre-built base image that includes essential packages
FROM mcr.microsoft.com/vscode/devcontainers/base:ubuntu-22.04 AS config-base

# Set up environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Set up user environment
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# Configure shell files and aliases
RUN mkdir -p /home/${USERNAME}/.ssh && \
    touch /home/${USERNAME}/.ssh/sshd_config && \
    touch /home/${USERNAME}/.zshrc && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh && \
    chmod 700 /home/${USERNAME}/.ssh && \
    chmod 644 /home/${USERNAME}/.zshrc && \
    chmod 600 /home/${USERNAME}/.ssh/sshd_config && \
    chmod 700 -R /home/${USERNAME}/.oh-my-zsh && \
    { \
        echo "DISABLE_UNTRACKED_FILES_DIRTY=\"true\""; \
        echo "alias rover=/tf/rover/rover.sh"; \
        echo "alias t=/usr/bin/terraform"; \
        echo "alias k=/usr/bin/kubectl"; \
        echo "cd /tf/caf || true"; \
        echo "[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases"; \
        echo "source /tf/rover/zsh-autosuggestions.zsh"; \
        echo "alias watch=\"watch \""; \
    } >> /home/${USERNAME}/.zshrc && \
    { \
        echo "alias rover=/tf/rover/rover.sh"; \
        echo "alias t=/usr/bin/terraform"; \
        echo "alias k=/usr/bin/kubectl"; \
        echo "cd /tf/caf || true"; \
    } >> /home/${USERNAME}/.bashrc

FROM config-base

ARG versionTerraform \
    USERNAME=vscode \
    versionRover

ENV versionRover=${versionRover} \
    versionTerraform=${versionTerraform}
#
# Install Terraform
#
# Keeping this method to support alpha build installations

# Create required directories
RUN mkdir -p /tf/rover && \
    mkdir -p "/home/${USERNAME}/.terraform.cache/plugin-cache" && \
    chown -R ${USERNAME}:${USERNAME} /tf && \
    chown -R ${USERNAME}:${USERNAME} "/home/${USERNAME}/.terraform.cache"

# Install Terraform
ARG TARGETOS
ARG TARGETARCH
ARG versionTerraform
ARG versionRover

RUN echo "Installing Terraform ${versionTerraform}..." && \
    curl -sSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_${TARGETOS}_${TARGETARCH}.zip" && \
    unzip -o -d /usr/bin /tmp/terraform.zip && \
    chmod +x /usr/bin/terraform && \
    rm /tmp/terraform.zip && \
    echo "${versionRover}" > /tf/rover/version.txt

# Install Azure CLI and extensions (with architecture-specific handling)
ARG extensionsAzureCli
ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
        az config set core.login_experience_v2=false && \
        az extension add --name resource-graph --system; \
    else \
        echo "Skipping Azure CLI installation for ${TARGETARCH} due to QEMU limitations"; \
    fi

# Create script directories and set permissions
RUN mkdir -p /tf/rover/scripts && \
    chown -R ${USERNAME}:${USERNAME} /tf/rover

# Copy rover scripts
COPY --chown=${USERNAME}:${USERNAME} \
    ./scripts/rover.sh \
    ./scripts/tfstate.sh \
    ./scripts/functions.sh \
    ./scripts/remote.sh \
    ./scripts/parse_command.sh \
    ./scripts/banner.sh \
    ./scripts/clone.sh \
    ./scripts/walkthrough.sh \
    ./scripts/sshd.sh \
    ./scripts/backend.hcl.tf \
    ./scripts/backend.azurerm.tf \
    ./scripts/task.sh \
    ./scripts/test_runner.sh \
    /tf/rover/scripts/
COPY ./scripts/ci_tasks/* ./ci_tasks/
COPY ./scripts/lib/* ./lib/
COPY ./scripts/tfcloud/* ./tfcloud/
