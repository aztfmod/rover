# Rover CLI Usage Guide

This comprehensive guide covers all rover commands, options, and usage patterns for managing Azure Terraform deployments.

## 📋 Table of Contents

- [Quick Reference](#quick-reference)
- [Core Commands](#core-commands)
- [Command Line Options](#command-line-options)
- [Authentication Commands](#authentication-commands)
- [Landing Zone Management](#landing-zone-management)
- [Workspace Management](#workspace-management)
- [CI/CD Commands](#cicd-commands)
- [Configuration Management](#configuration-management)
- [Advanced Usage](#advanced-usage)
- [Examples](#examples)

## Quick Reference

### Basic Syntax

```bash
rover [COMMAND] [OPTIONS]
```

### Most Common Commands

```bash
# Login to Azure
rover login

# Deploy a landing zone
rover -lz /path/to/landingzone -a apply -env production

# Run Terraform plan
rover -lz /path/to/landingzone -a plan -env development

# Destroy infrastructure  
rover -lz /path/to/landingzone -a destroy -env development

# Run CI/CD pipeline
rover ci -sc /path/to/symphony.yml
```

## Core Commands

### Authentication Commands

#### `login`
Start interactive Azure authentication process.

```bash
# Interactive login
rover login

# Login to specific tenant
rover login [tenant-id]

# Login to specific subscription
rover login [tenant-id] [subscription-id]
```

**Options:**
- `tenant-id` (optional): Azure Active Directory tenant ID
- `subscription-id` (optional): Target Azure subscription ID

**Examples:**
```bash
# Basic login
rover login

# Login to specific tenant
rover login 12345678-1234-1234-1234-123456789012

# Login to specific tenant and subscription
rover login 12345678-1234-1234-1234-123456789012 87654321-4321-4321-4321-210987654321
```

#### `logout`
Clear Azure authentication information.

```bash
rover logout
```

### Landing Zone Commands

#### Basic Terraform Operations

```bash
# Terraform plan
rover -lz <path> -a plan [options]

# Terraform apply  
rover -lz <path> -a apply [options]

# Terraform destroy
rover -lz <path> -a destroy [options]

# Terraform init
rover -lz <path> -a init [options]

# Terraform validate
rover -lz <path> -a validate [options]
```

#### Landing Zone Discovery

```bash
# List available landing zones
rover landingzone list

# List landing zones with details
rover landingzone list --detailed
```

### Workspace Management

#### `workspace list`
Display available Terraform workspaces.

```bash
rover workspace list
```

#### `workspace create`
Create a new Terraform workspace.

```bash
rover workspace create <workspace-name>
```

#### `workspace delete`
Delete an existing Terraform workspace.

```bash
rover workspace delete <workspace-name>
```

### CI/CD Commands

#### `ci`
Execute continuous integration workflow.

```bash
# Run all CI tasks
rover ci -sc /path/to/symphony.yml

# Run specific CI task
rover ci -ct <task-name> -sc /path/to/symphony.yml

# Run with base directory
rover ci -sc /path/to/symphony.yml -b /base/directory
```

#### `cd`
Execute continuous deployment workflow.

```bash
rover cd -sc /path/to/symphony.yml [options]
```

## Command Line Options

### Core Options

| Option | Short | Long | Description | Example |
|--------|-------|------|-------------|---------|
| Landing Zone | `-lz` | `--landingzone` | Path to landing zone | `-lz ./landingzones/launchpad` |
| Action | `-a` | `--action` | Terraform action | `-a apply` |
| Environment | `-env` | `--environment` | Environment name | `-env production` |
| Level | `-l` | `--level` | Landing zone level | `-l level0` |
| Debug | `-d` | `--debug` | Enable debug logging | `-d` |

### State Management Options

| Option | Description | Example |
|--------|-------------|---------|
| `--tfstate` | State file name | `--tfstate myapp.tfstate` |
| `--launchpad` | Mark as launchpad deployment | `--launchpad` |
| `--var-folder` | Variables folder path | `--var-folder ./configs` |

### Azure Cloud Options

| Option | Short | Long | Description | Values |
|--------|-------|------|-------------|---------|
| Cloud | `-c` | `--cloud` | Azure cloud environment | `AzurePublic`, `AzureUSGovernment`, `AzureChinaCloud`, `AzureGermanCloud` |

### Logging Options

| Option | Description | Values |
|--------|-------------|---------|
| `--log-severity` | Log verbosity level | `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `VERBOSE` |

### CI/CD Options

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Symphony Config | `-sc` | `--symphony-config` | Path to symphony.yml |
| CI Task Name | `-ct` | `--ci-task-name` | Specific CI task to run |
| Base Directory | `-b` | `--base-dir` | Base directory for symphony.yml paths |

## Authentication Commands

### Interactive Authentication

```bash
# Standard login flow
rover login

# Login with specific tenant
rover login 12345678-1234-1234-1234-123456789012

# Login with device code (for CI/CD)
az login --use-device-code
```

### Service Principal Authentication

```bash
# Set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Rover will automatically use service principal
rover -lz ./landingzone -a apply
```

### Managed Identity Authentication

```bash
# Enable managed identity
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Use with rover
rover -lz ./landingzone -a apply
```

## Landing Zone Management

### Landing Zone Structure

```
landingzones/
├── level0/
│   ├── launchpad/
│   ├── networking/
│   └── identity/
├── level1/
│   ├── shared-services/
│   └── connectivity/
├── level2/
│   ├── corp-apps/
│   └── online-apps/
└── level3/
    ├── data-platform/
    └── analytics/
```

### Deployment Patterns

#### 1. Foundation Deployment (Level 0)

```bash
# Deploy launchpad (state management)
rover -lz ./landingzones/level0/launchpad \
      -a apply \
      -env production \
      -level level0 \
      --launchpad

# Deploy platform networking
rover -lz ./landingzones/level0/networking \
      -a apply \
      -env production \
      -level level0
```

#### 2. Shared Services (Level 1)

```bash
# Deploy shared services
rover -lz ./landingzones/level1/shared-services \
      -a apply \
      -env production \
      -level level1
```

#### 3. Application Landing Zones (Level 2)

```bash
# Deploy corporate connected applications
rover -lz ./landingzones/level2/corp-apps \
      -a apply \
      -env production \
      -level level2
```

#### 4. Application Resources (Level 3)

```bash
# Deploy application-specific resources
rover -lz ./landingzones/level3/web-app \
      -a apply \
      -env production \
      -level level3
```

### Variable Management

#### Using Variable Folders

```bash
# Structure
configs/
├── development/
│   ├── level0/
│   │   └── launchpad.tfvars
│   └── level1/
├── production/
│   ├── level0/
│   └── level1/

# Usage
rover -lz ./landingzones/level0/launchpad \
      -a apply \
      -env production \
      -level level0 \
      --var-folder ./configs/production/level0
```

#### Environment Variables

```bash
# Set Terraform variables
export TF_VAR_environment="production"
export TF_VAR_location="East US"
export TF_VAR_project_name="myproject"

# Use with rover
rover -lz ./landingzone -a apply
```

## Workspace Management

### Workspace Operations

```bash
# List workspaces
rover workspace list

# Create new workspace
rover workspace create feature-branch-123

# Select workspace (via environment variable)
export TF_VAR_workspace="feature-branch-123"
rover -lz ./landingzone -a plan

# Delete workspace
rover workspace delete feature-branch-123
```

### Workspace Patterns

#### Environment-based Workspaces

```bash
# Development workspace
export TF_VAR_workspace="development"
rover -lz ./landingzone -a apply -env development

# Production workspace  
export TF_VAR_workspace="production"
rover -lz ./landingzone -a apply -env production
```

#### Feature Branch Workspaces

```bash
# Create workspace for feature
BRANCH_NAME=$(git branch --show-current)
rover workspace create "feature-${BRANCH_NAME}"

# Deploy to feature workspace
export TF_VAR_workspace="feature-${BRANCH_NAME}"
rover -lz ./landingzone -a apply -env development
```

## CI/CD Commands

### Symphony Configuration

#### Basic Symphony.yml

```yaml
# symphony.yml
version: "1.0"
environments:
  development:
    base_folder: "/tf/caf"
    terraform_folder: "landingzones"
    
tasks:
  - name: "validate"
    command: "terraform validate"
    
  - name: "tflint"
    command: "tflint --config .tflint.hcl"
    
  - name: "terrascan"
    command: "terrascan scan -t terraform"
```

#### Running CI Tasks

```bash
# Run all CI tasks
rover ci -sc ./symphony.yml -b /tf/caf

# Run specific task
rover ci -ct tflint -sc ./symphony.yml -b /tf/caf

# Run with debug output
rover ci -sc ./symphony.yml -b /tf/caf -d
```

### Advanced CI/CD Patterns

#### Multi-Environment Pipeline

```bash
#!/bin/bash
# deploy-pipeline.sh

environments=("development" "staging" "production")

for env in "${environments[@]}"; do
    echo "Deploying to $env..."
    
    # Run CI checks
    rover ci -sc ./symphony.yml -b /tf/caf
    
    # Deploy if CI passes
    if [ $? -eq 0 ]; then
        rover -lz ./landingzones/level0/launchpad \
              -a apply \
              -env $env \
              -level level0 \
              --var-folder ./configs/$env
    fi
done
```

## Configuration Management

### Environment Configuration

#### Directory Structure

```
configs/
├── global/
│   ├── tags.tfvars
│   └── naming.tfvars
├── development/
│   ├── main.tfvars
│   └── networking.tfvars
├── staging/
│   ├── main.tfvars
│   └── networking.tfvars
└── production/
    ├── main.tfvars
    └── networking.tfvars
```

#### Usage with Rover

```bash
# Use environment-specific configuration
rover -lz ./landingzones/networking \
      -a apply \
      -env production \
      --var-folder ./configs/production

# Combine global and environment configs
rover -lz ./landingzones/networking \
      -a apply \
      -env production \
      --var-folder ./configs/global \
      --var-folder ./configs/production
```

### State Configuration

#### Backend Configuration

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "level0/launchpad.terraform.tfstate"
  }
}
```

#### Custom State Names

```bash
# Use custom state file name
rover -lz ./landingzone \
      -a apply \
      --tfstate "custom-app.tfstate"
```

## Advanced Usage

### Debugging and Troubleshooting

```bash
# Enable debug logging
rover -lz ./landingzone -a plan -d

# Set log severity
rover -lz ./landingzone -a plan --log-severity DEBUG

# Terraform debugging
export TF_LOG=DEBUG
rover -lz ./landingzone -a plan
```

### Performance Optimization

```bash
# Increase parallelism
export TF_CLI_ARGS_plan="-parallelism=10"
export TF_CLI_ARGS_apply="-parallelism=10"

# Use provider cache
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p $TF_PLUGIN_CACHE_DIR
```

### Custom Hooks

#### Pre/Post Deployment Hooks

```bash
# pre-deploy.sh
#!/bin/bash
echo "Running pre-deployment checks..."
az account show
terraform version

# Use with rover
./pre-deploy.sh && \
rover -lz ./landingzone -a apply && \
./post-deploy.sh
```

## Examples

### Basic Examples

#### 1. Simple Landing Zone Deployment

```bash
# Clone landing zones
git clone https://github.com/Azure/caf-terraform-landingzones.git /tf/caf

# Deploy launchpad
rover -lz /tf/caf/landingzones/caf_launchpad \
      -a apply \
      -env demo \
      --launchpad
```

#### 2. Multi-Level Deployment

```bash
# Level 0: Foundation
rover -lz /tf/caf/landingzones/caf_foundations \
      -a apply \
      -env production \
      -level level0

# Level 1: Shared Services  
rover -lz /tf/caf/landingzones/caf_shared_services \
      -a apply \
      -env production \
      -level level1

# Level 2: Application Landing Zone
rover -lz /tf/caf/landingzones/caf_web_application \
      -a apply \
      -env production \
      -level level2
```

### CI/CD Integration Examples

#### GitHub Actions

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    container: aztfmod/rover:latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Azure Login
      run: |
        az login --service-principal \
          --username ${{ secrets.AZURE_CLIENT_ID }} \
          --password ${{ secrets.AZURE_CLIENT_SECRET }} \
          --tenant ${{ secrets.AZURE_TENANT_ID }}
    
    - name: Run CI
      run: |
        rover ci -sc ./symphony.yml -b ./
    
    - name: Deploy Landing Zone
      run: |
        rover -lz ./landingzones/launchpad \
              -a apply \
              -env production \
              --launchpad
```

#### Azure DevOps

```yaml
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
    azureSubscription: 'Production Service Connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      rover ci -sc ./symphony.yml -b ./
      rover -lz ./landingzones/launchpad -a apply -env production --launchpad
```

### Complex Deployment Scenarios

#### Blue-Green Deployment

```bash
#!/bin/bash
# blue-green-deploy.sh

ENVIRONMENT=$1
COLOR=$2  # blue or green

# Deploy to staging slot
rover -lz ./landingzones/web-app \
      -a apply \
      -env ${ENVIRONMENT} \
      --tfstate "webapp-${COLOR}.tfstate" \
      --var-folder ./configs/${ENVIRONMENT}

# Run health checks
./health-check.sh ${COLOR}

# Switch traffic if healthy
if [ $? -eq 0 ]; then
    echo "Switching traffic to ${COLOR}"
    # Update DNS or load balancer configuration
fi
```

#### Multi-Region Deployment

```bash
#!/bin/bash
# multi-region-deploy.sh

REGIONS=("eastus" "westus2" "northeurope")
ENVIRONMENT=$1

for region in "${REGIONS[@]}"; do
    echo "Deploying to $region..."
    
    export TF_VAR_location=$region
    export TF_VAR_region_suffix=${region//-/}
    
    rover -lz ./landingzones/regional-app \
          -a apply \
          -env $ENVIRONMENT \
          --tfstate "app-${region}.tfstate" \
          --var-folder ./configs/$ENVIRONMENT
done
```

---

For detailed CI/CD configuration examples, see [Continuous Integration Guide](CONTINOUS_INTEGRATION.md).

For troubleshooting common issues, see [Troubleshooting Guide](TROUBLESHOOTING.md).

Next: [Architecture Overview](ARCHITECTURE.md) | [Security Guide](SECURITY.md)
