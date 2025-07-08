# Installation Guide

This guide provides comprehensive instructions for installing and setting up the Azure Terraform SRE Rover.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Docker Installation](#docker-installation)
- [Development Setup](#development-setup)
- [CI/CD Agent Setup](#cicd-agent-setup)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **Operating System**: Linux, macOS, or Windows with WSL2
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: At least 10GB free space
- **Network**: Internet access for downloading images and Azure connectivity

### Required Software

1. **Docker Desktop**
   - Version 20.10.0 or later
   - Docker Compose v2.0+ (included with Docker Desktop)

2. **Azure Access**
   - Valid Azure subscription
   - Appropriate permissions for resource creation
   - Azure CLI (optional, for local authentication)

### Optional Tools

- **Visual Studio Code** with Remote-Containers extension
- **Git** for cloning repositories
- **Azure CLI** for local development and testing

## Installation Methods

### Method 1: Docker Hub (Recommended)

The fastest way to get started with Rover:

```bash
# Pull the latest stable version
docker pull aztfmod/rover:latest

# Run rover interactively
docker run -it --rm aztfmod/rover:latest bash

# Verify installation
rover --version
```

### Method 2: Specific Version

For production use, pin to a specific version:

```bash
# Check available versions
# Visit: https://hub.docker.com/r/aztfmod/rover/tags

# Pull specific version
docker pull aztfmod/rover:1.3.0

# Run with version tag
docker run -it --rm aztfmod/rover:1.3.0 bash
```

### Method 3: Local Build

For development or customization:

```bash
# Clone the repository
git clone https://github.com/aztfmod/rover.git
cd rover

# Build local image
make local

# Run local build
docker run -it --rm rover-local:latest bash
```

## Docker Installation

### Linux Installation

```bash
# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up stable repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Verify installation
docker --version
```

### macOS Installation

```bash
# Install Docker Desktop from https://docs.docker.com/desktop/mac/install/
# Or using Homebrew
brew install --cask docker

# Start Docker Desktop and verify
docker --version
```

### Windows Installation

1. **Install WSL2**
   ```powershell
   # Run as Administrator
   wsl --install
   ```

2. **Install Docker Desktop**
   - Download from [Docker Desktop for Windows](https://docs.docker.com/desktop/windows/install/)
   - Ensure WSL2 backend is enabled

3. **Verify in WSL2**
   ```bash
   docker --version
   ```

## Development Setup

### VS Code Dev Container

For the best development experience:

1. **Install Prerequisites**
   ```bash
   # Install VS Code
   code --install-extension ms-vscode-remote.remote-containers
   ```

2. **Open Project**
   ```bash
   git clone https://github.com/aztfmod/rover.git
   cd rover
   code .
   ```

3. **Start Dev Container**
   - Command Palette (Ctrl+Shift+P)
   - Select "Remote-Containers: Reopen in Container"
   - Wait for container to build and start

4. **Verify Setup**
   ```bash
   # Inside VS Code terminal
   rover --version
   terraform --version
   az --version
   ```

### Local Development Build

```bash
# Clone repository
git clone https://github.com/aztfmod/rover.git
cd rover

# Build development image
make dev

# Run with volume mounts for development
docker run -it --rm \
  -v $(pwd):/tf/rover \
  -v ~/.azure:/home/vscode/.azure \
  rover-dev:latest bash
```

## CI/CD Agent Setup

### GitHub Actions

```yaml
# .github/workflows/terraform.yml
name: Terraform Deployment
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: aztfmod/rover:latest
    steps:
      - uses: actions/checkout@v3
      - name: Azure Login
        run: |
          az login --service-principal \
            --username ${{ secrets.AZURE_CLIENT_ID }} \
            --password ${{ secrets.AZURE_CLIENT_SECRET }} \
            --tenant ${{ secrets.AZURE_TENANT_ID }}
      - name: Deploy Landing Zone
        run: |
          rover -lz ./landingzones/launchpad -a apply -launchpad
```

### Azure DevOps

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

container: aztfmod/rover:latest

steps:
- task: AzureCLI@2
  displayName: 'Deploy with Rover'
  inputs:
    azureSubscription: '$(serviceConnection)'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      rover -lz ./landingzones/launchpad -a apply -launchpad
```

### GitLab CI

```yaml
# .gitlab-ci.yml
image: aztfmod/rover:latest

stages:
  - deploy

deploy_terraform:
  stage: deploy
  script:
    - az login --service-principal --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
    - rover -lz ./landingzones/launchpad -a apply -launchpad
  only:
    - main
```

## Configuration

### Azure Authentication

#### Service Principal (Recommended for CI/CD)

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "rover-sp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}

# Set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret" 
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

#### Interactive Login (Development)

```bash
# Login to Azure
az login

# Select subscription
az account set --subscription "your-subscription-id"

# Verify
az account show
```

### Rover Configuration

#### Environment Variables

```bash
# Core settings
export TF_VAR_environment="dev"
export TF_VAR_level="level0"
export TF_VAR_workspace="tfstate"

# Azure settings  
export ARM_USE_AZUREAD="true"
export ARM_STORAGE_USE_AZUREAD="true"

# Logging
export TF_LOG="INFO"
export debug_mode="true"
```

#### Configuration File

Create `~/.rover/config`:

```bash
# Default configuration
TF_VAR_environment=dev
TF_VAR_level=level0
TF_VAR_workspace=tfstate
ARM_USE_AZUREAD=true
debug_mode=false
```

### Storage Configuration

#### Terraform State Storage

```bash
# Create storage account for Terraform state
az group create --name rg-tfstate --location eastus

az storage account create \
  --name stterraformstate$(date +%s) \
  --resource-group rg-tfstate \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob

# Get storage account key
STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-tfstate \
  --account-name $STORAGE_ACCOUNT \
  --query '[0].value' -o tsv)

# Configure backend
export ARM_ACCESS_KEY=$STORAGE_KEY
```

## Verification

### Basic Verification

```bash
# Check rover version
rover --version

# Verify Azure connectivity
az account show

# Test Terraform
terraform version

# Check available tools
which git kubectl helm jq
```

### Comprehensive Test

```bash
# Run rover with dry-run
rover -lz /tf/rover/examples/basic -a plan

# Test CI tools
rover ci --help

# Verify state management
rover workspace list
```

### Smoke Test Script

Create `verify-installation.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 Rover Installation Verification"
echo "=================================="

# Check rover
echo "✅ Checking rover..."
rover --version

# Check Azure CLI
echo "✅ Checking Azure CLI..."
az version

# Check Terraform
echo "✅ Checking Terraform..."
terraform version

# Check authentication
echo "✅ Checking Azure authentication..."
az account show --query "name" -o tsv

# Check tools
echo "✅ Checking additional tools..."
git --version
kubectl version --client
helm version

echo ""
echo "🎉 All checks passed! Rover is ready to use."
```

Run verification:

```bash
chmod +x verify-installation.sh
./verify-installation.sh
```

## Troubleshooting

### Common Issues

#### Docker Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker
```

#### Container Image Pull Failures

```bash
# Check network connectivity
docker run --rm busybox ping -c 3 google.com

# Try different registry
docker pull ghcr.io/aztfmod/rover:latest

# Clear Docker cache
docker system prune -a
```

#### Azure Authentication Issues

```bash
# Clear Azure CLI cache
az account clear

# Re-authenticate
az login

# Verify subscription access
az account list --query "[].{Name:name,SubscriptionId:id,State:state}" --output table
```

#### Storage Account Access

```bash
# Check storage account permissions
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope /subscriptions/{subscription-id}/resourceGroups/{rg-name}

# Test storage connectivity
az storage container list --account-name {storage-account}
```

### Performance Issues

#### Slow Container Startup

```bash
# Use specific version instead of latest
docker pull aztfmod/rover:1.3.0

# Pre-pull images
docker pull aztfmod/rover:latest &
```

#### Network Timeouts

```bash
# Increase timeout settings
export ARM_CLIENT_TIMEOUT=300

# Use different Azure region
export ARM_ENVIRONMENT="AzurePublic"
```

### Getting Help

- **Documentation**: Check [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Issues**: Create GitHub issue with installation details
- **Community**: Join [Gitter chat](https://gitter.im/aztfmod/community)
- **Support**: Email tf-landingzones@microsoft.com

### Diagnostic Information

When reporting issues, include:

```bash
# System information
uname -a
docker --version
docker info

# Rover information  
rover --version
az --version
terraform version

# Network test
curl -I https://registry-1.docker.io/v2/

# Azure connectivity
az account show
```

---

Next Steps: [Usage Guide](USAGE.md) | [Architecture Overview](ARCHITECTURE.md)