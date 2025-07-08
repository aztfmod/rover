# Frequently Asked Questions (FAQ)

This document answers common questions about using the Azure Terraform SRE Rover.

## 📋 Table of Contents

- [General Questions](#general-questions)
- [Installation & Setup](#installation--setup)
- [Authentication & Permissions](#authentication--permissions)
- [Terraform Operations](#terraform-operations)
- [State Management](#state-management)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## General Questions

### What is Rover?

Rover is a containerized toolset for managing enterprise Terraform deployments on Microsoft Azure. It provides:
- Consistent development environment across platforms
- Automated Terraform state management
- Built-in security scanning and compliance
- CI/CD integration for popular platforms
- Enterprise-grade features for Azure infrastructure

### Why use Rover instead of Terraform directly?

Rover provides several advantages over using Terraform directly:
- **Consistency**: Same environment across all developers and CI/CD pipelines
- **State Management**: Automated Azure Storage backend configuration
- **Security**: Built-in security scanning with TFLint, Terrascan, and others
- **Toolchain**: Pre-installed tools (Azure CLI, kubectl, Helm, etc.)
- **Best Practices**: Cloud Adoption Framework (CAF) patterns built-in
- **Enterprise Features**: RBAC, audit logging, policy enforcement

### Is Rover only for Azure?

While Rover is optimized for Azure deployments, it can be used with other cloud providers since it includes standard Terraform. However, the Azure-specific features (state management, authentication, etc.) are designed for Azure.

### What's the difference between Rover and Terraform Cloud?

Rover is an open-source, self-hosted solution focused on Azure, while Terraform Cloud is HashiCorp's managed service. Key differences:

| Feature | Rover | Terraform Cloud |
|---------|-------|-----------------|
| Hosting | Self-hosted | Managed service |
| Cost | Free (open source) | Paid tiers |
| Azure Integration | Deep integration | Basic support |
| State Storage | Azure Storage | Terraform Cloud |
| Security Scanning | Built-in | Add-ons required |

## Installation & Setup

### How do I install Rover?

The easiest way is using Docker:

```bash
# Pull latest image
docker pull aztfmod/rover:latest

# Run interactively
docker run -it --rm aztfmod/rover:latest bash
```

For detailed installation options, see [Installation Guide](INSTALLATION.md).

### Can I run Rover on Windows?

Yes! Rover supports Windows through:
- **Docker Desktop** with WSL2 backend
- **GitHub Codespaces** for cloud development
- **VS Code Dev Containers** for consistent environment

### Do I need Docker to use Rover?

Yes, Docker is required as Rover is designed as a containerized solution. This ensures consistency across different environments and platforms.

### How do I update Rover?

```bash
# Pull latest version
docker pull aztfmod/rover:latest

# Or specific version
docker pull aztfmod/rover:1.3.0
```

For production use, pin to specific versions rather than using `latest`.

## Authentication & Permissions

### How do I authenticate with Azure?

Rover supports multiple authentication methods:

**Interactive (Development):**
```bash
rover login
```

**Service Principal (CI/CD):**
```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

**Managed Identity (Azure-hosted):**
```bash
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

### What Azure permissions does Rover need?

Minimum permissions depend on your deployment:
- **Contributor** role for most deployments
- **Storage Blob Data Contributor** for state management
- **Key Vault** permissions for secret access
- Custom roles for specific scenarios

See [Security Guide](SECURITY.md) for detailed permission requirements.

### Can I use multiple Azure subscriptions?

Yes, you can target different subscriptions by:
- Setting `ARM_SUBSCRIPTION_ID` environment variable
- Using `az account set --subscription` command
- Configuring different service principals per subscription

### How do I manage secrets securely?

Rover integrates with Azure Key Vault:

```bash
# Store secrets in Key Vault
az keyvault secret set --vault-name MyVault --name db-password --value "secret123"

# Use in Terraform
data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.main.id
}
```

## Terraform Operations

### How do I deploy a landing zone?

```bash
# Basic deployment
rover -lz /path/to/landingzone -a apply -env production

# Launchpad deployment (state management)
rover -lz /path/to/launchpad -a apply -env production --launchpad

# With custom variables
rover -lz /path/to/landingzone -a apply -env production --var-folder ./configs/prod
```

### What's the difference between levels (level0, level1, etc.)?

Levels represent the deployment hierarchy in the Cloud Adoption Framework:
- **Level 0**: Foundation (identity, networking, state management)
- **Level 1**: Shared services (security, monitoring, connectivity)
- **Level 2**: Application landing zones (workload-specific platforms)
- **Level 3**: Applications and workloads

### Can I use custom Terraform configurations?

Yes! Rover works with any Terraform configuration. The level system is optional and mainly provides organization for CAF patterns.

### How do I pass variables to Terraform?

Multiple ways:
```bash
# Environment variables
export TF_VAR_environment="production"
export TF_VAR_location="East US"

# Variable files
rover -lz ./landingzone -a apply --var-folder ./configs/production

# Direct variables
terraform apply -var="location=East US"
```

## State Management

### Where is my Terraform state stored?

Rover automatically configures Azure Storage backend:
- **Storage Account**: Created in specified resource group
- **Container**: `tfstate`
- **Key**: Based on environment/level/workspace pattern
- **Encryption**: AES-256 at rest, HTTPS in transit

### How do I manage multiple environments?

Use environment-specific workspaces and state files:

```bash
# Development environment
rover -lz ./landingzone -a apply -env development

# Production environment  
rover -lz ./landingzone -a apply -env production
```

Each environment gets its own state file path.

### Can I migrate existing Terraform state to Rover?

Yes, you can migrate existing state:

```bash
# Initialize with new backend
terraform init -migrate-state

# Or manually copy state file to Azure Storage
az storage blob upload --account-name storage --container-name tfstate --file terraform.tfstate --name myapp.tfstate
```

### How do I backup state files?

Rover automatically creates backups:
- **Versioning**: Enabled on Azure Storage
- **Cross-region replication**: Configure with GRS/RA-GRS
- **Automated backups**: Daily snapshots to backup container

## CI/CD Integration

### Which CI/CD platforms does Rover support?

Rover provides pre-built agents for:
- **GitHub Actions** (github runner)
- **Azure DevOps** (Azure Pipelines agent)
- **GitLab CI** (GitLab runner)
- **Terraform Cloud** (custom agents)

### How do I set up GitHub Actions with Rover?

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
    
    - name: Deploy
      run: |
        rover -lz ./landingzones/app -a apply -env production
```

### Can I use Rover in my existing pipelines?

Yes! You can use Rover as a container in existing pipelines:

```bash
# In any CI/CD system
docker run --rm \
  -v $(pwd):/tf/caf \
  -e ARM_CLIENT_ID="$ARM_CLIENT_ID" \
  -e ARM_CLIENT_SECRET="$ARM_CLIENT_SECRET" \
  -e ARM_SUBSCRIPTION_ID="$ARM_SUBSCRIPTION_ID" \
  -e ARM_TENANT_ID="$ARM_TENANT_ID" \
  aztfmod/rover:latest \
  rover -lz /tf/caf/landingzone -a apply -env production
```

### How do I run CI/CD tests?

Use rover's built-in CI capabilities:

```bash
# Run all CI tasks
rover ci -sc ./symphony.yml

# Run specific task
rover ci -ct tflint -sc ./symphony.yml

# Run with custom configuration
rover ci -sc ./configs/ci.yml -b ./terraform
```

## Troubleshooting

### Rover command not found

**Solution**: Ensure you're running inside the rover container:
```bash
docker run -it --rm aztfmod/rover:latest bash
rover --version
```

### Authentication failures

**Check**:
1. Azure CLI login: `az account show`
2. Service principal credentials: Verify `ARM_*` environment variables
3. Subscription access: `az account list`
4. Permissions: Check RBAC assignments

### Terraform state lock errors

**Solutions**:
1. Wait for lock to expire (20 minutes)
2. Force unlock: `terraform force-unlock <lock-id>`
3. Check for running processes: `ps aux | grep terraform`

### Performance issues

**Optimizations**:
1. Increase container resources: `--memory=4g --cpus=2`
2. Use provider cache: `export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"`
3. Enable parallelism: `export TF_CLI_ARGS_plan="-parallelism=10"`

For more detailed troubleshooting, see [Troubleshooting Guide](TROUBLESHOOTING.md).

## Advanced Usage

### Can I customize the Rover image?

Yes, you can extend the base image:

```dockerfile
FROM aztfmod/rover:latest

# Add custom tools
RUN apt-get update && apt-get install -y custom-tool

# Add custom scripts
COPY scripts/ /usr/local/bin/

# Set custom entrypoint
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### How do I integrate with corporate proxies?

Configure Docker daemon with proxy settings:

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.company.com:8080",
      "httpsProxy": "http://proxy.company.com:8080",
      "noProxy": "localhost,127.0.0.1,.company.com"
    }
  }
}
```

### Can I use Rover for multi-cloud deployments?

While optimized for Azure, Rover can deploy to other clouds:
- Install additional provider CLIs in custom image
- Configure appropriate authentication for each cloud
- Use separate state backends per cloud provider

### How do I contribute to Rover?

1. Read [Contributing Guide](CONTRIBUTING.md)
2. Fork the repository
3. Create feature branch
4. Submit pull request
5. Follow code review process

### Where can I get help?

- **Documentation**: [GitHub repository docs](https://github.com/aztfmod/rover/docs)
- **Issues**: [GitHub Issues](https://github.com/aztfmod/rover/issues)
- **Discussions**: [GitHub Discussions](https://github.com/aztfmod/rover/discussions)
- **Chat**: [Gitter Community](https://gitter.im/aztfmod/community)
- **Email**: tf-landingzones@microsoft.com

---

**Didn't find your question?** Open a [GitHub Discussion](https://github.com/aztfmod/rover/discussions) or create an [issue](https://github.com/aztfmod/rover/issues) for documentation improvements.