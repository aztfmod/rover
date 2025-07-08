# Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using the Azure Terraform SRE Rover.

## 📋 Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Authentication Issues](#authentication-issues)
- [Container Issues](#container-issues)
- [Terraform Issues](#terraform-issues)
- [Azure Connectivity Issues](#azure-connectivity-issues)
- [State Management Issues](#state-management-issues)
- [Performance Issues](#performance-issues)
- [CI/CD Issues](#ci-cd-issues)
- [Getting Help](#getting-help)

## Quick Diagnostics

### Environment Check Script

Run this comprehensive diagnostic script to identify common issues:

```bash
#!/bin/bash
# rover-diagnostics.sh

echo "🔍 Rover Diagnostics Report"
echo "=========================="
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo "User: $(whoami)"
echo ""

# Check Docker
echo "📦 Docker Status:"
if command -v docker &> /dev/null; then
    echo "✅ Docker installed: $(docker --version)"
    if docker info &> /dev/null; then
        echo "✅ Docker daemon running"
        echo "   Images: $(docker images --format "table {{.Repository}}:{{.Tag}}" | grep rover | head -3)"
    else
        echo "❌ Docker daemon not accessible"
        echo "   Try: sudo systemctl start docker"
    fi
else
    echo "❌ Docker not installed"
fi
echo ""

# Check Azure CLI
echo "☁️ Azure CLI Status:"
if command -v az &> /dev/null; then
    echo "✅ Azure CLI installed: $(az --version | head -1)"
    if az account show &> /dev/null; then
        echo "✅ Authenticated to Azure"
        echo "   Subscription: $(az account show --query name -o tsv)"
        echo "   Tenant: $(az account show --query tenantId -o tsv)"
    else
        echo "❌ Not authenticated to Azure"
        echo "   Try: az login"
    fi
else
    echo "❌ Azure CLI not available"
fi
echo ""

# Check Rover
echo "🚀 Rover Status:"
if docker images | grep -q rover; then
    echo "✅ Rover images available:"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep rover
    
    # Test rover execution
    if docker run --rm aztfmod/rover:latest rover --version &> /dev/null; then
        echo "✅ Rover executable working"
    else
        echo "❌ Rover execution failed"
    fi
else
    echo "❌ No rover images found"
    echo "   Try: docker pull aztfmod/rover:latest"
fi
echo ""

# Check network connectivity
echo "🌐 Network Connectivity:"
endpoints=(
    "management.azure.com"
    "login.microsoftonline.com" 
    "registry.terraform.io"
    "registry-1.docker.io"
)

for endpoint in "${endpoints[@]}"; do
    if curl -s --max-time 5 "https://$endpoint" &> /dev/null; then
        echo "✅ $endpoint reachable"
    else
        echo "❌ $endpoint unreachable"
    fi
done
echo ""

# Check environment variables
echo "🔧 Environment Variables:"
env_vars=(
    "ARM_SUBSCRIPTION_ID"
    "ARM_TENANT_ID"
    "ARM_CLIENT_ID"
    "TF_VAR_environment"
)

for var in "${env_vars[@]}"; do
    if [ -n "${!var}" ]; then
        echo "✅ $var set (length: ${#!var})"
    else
        echo "⚠️ $var not set"
    fi
done

echo ""
echo "📋 Summary:"
echo "Run this script regularly to catch issues early."
echo "For help: https://github.com/aztfmod/rover/blob/main/docs/TROUBLESHOOTING.md"
```

Save and run: `chmod +x rover-diagnostics.sh && ./rover-diagnostics.sh`

## Authentication Issues

### Issue: "Error: building AzureRM Client: obtain subscription() from Azure CLI"

**Symptoms:**
```
Error: building AzureRM Client: obtain subscription() from Azure CLI: parsing json result from the Azure CLI
```

**Solutions:**

1. **Re-authenticate to Azure:**
   ```bash
   az logout
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **Check subscription access:**
   ```bash
   az account list --output table
   az account show
   ```

3. **For service principal authentication:**
   ```bash
   # Verify service principal credentials
   az login --service-principal \
     --username $ARM_CLIENT_ID \
     --password $ARM_CLIENT_SECRET \
     --tenant $ARM_TENANT_ID
   
   # Test access
   az account show
   ```

### Issue: "Error: Insufficient privileges to complete the operation"

**Cause:** Service principal lacks required permissions.

**Solutions:**

1. **Check current permissions:**
   ```bash
   az role assignment list --assignee $ARM_CLIENT_ID --output table
   ```

2. **Grant required permissions:**
   ```bash
   # Minimum permissions for rover
   az role assignment create \
     --assignee $ARM_CLIENT_ID \
     --role "Contributor" \
     --scope "/subscriptions/$ARM_SUBSCRIPTION_ID"
   ```

3. **For specific resource groups:**
   ```bash
   az role assignment create \
     --assignee $ARM_CLIENT_ID \
     --role "Contributor" \
     --scope "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/my-rg"
   ```

### Issue: "Error: Token has expired"

**Solutions:**

1. **Refresh authentication:**
   ```bash
   az account get-access-token --query accessToken --output tsv
   az login --use-device-code  # If interactive login needed
   ```

2. **For long-running processes:**
   ```bash
   # Use managed identity
   export ARM_USE_MSI=true
   export ARM_SUBSCRIPTION_ID="your-subscription-id"
   ```

## Container Issues

### Issue: "Docker: permission denied"

**Symptoms:**
```
docker: Got permission denied while trying to connect to the Docker daemon socket
```

**Solutions:**

1. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker  # Or log out and back in
   ```

2. **Start Docker daemon:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

3. **For WSL2 users:**
   ```bash
   # Ensure Docker Desktop is running on Windows
   # Check WSL integration in Docker Desktop settings
   ```

### Issue: "Image pull failed"

**Symptoms:**
```
Error response from daemon: pull access denied for aztfmod/rover
```

**Solutions:**

1. **Check network connectivity:**
   ```bash
   curl -I https://registry-1.docker.io/v2/
   ```

2. **Try alternative registry:**
   ```bash
   docker pull ghcr.io/aztfmod/rover:latest
   ```

3. **Use corporate proxy:**
   ```bash
   # Configure Docker proxy
   sudo mkdir -p /etc/systemd/system/docker.service.d
   sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
   [Service]
   Environment="HTTP_PROXY=http://proxy.company.com:8080"
   Environment="HTTPS_PROXY=http://proxy.company.com:8080"
   Environment="NO_PROXY=localhost,127.0.0.1"
   EOF
   
   sudo systemctl daemon-reload
   sudo systemctl restart docker
   ```

### Issue: "Container runs but rover command not found"

**Symptoms:**
```
bash: rover: command not found
```

**Solutions:**

1. **Check container entrypoint:**
   ```bash
   docker run --rm aztfmod/rover:latest which rover
   docker run --rm aztfmod/rover:latest ls -la /usr/local/bin/
   ```

2. **Run with correct working directory:**
   ```bash
   docker run -it --rm -w /tf/rover aztfmod/rover:latest bash
   ```

3. **Source rover environment:**
   ```bash
   # Inside container
   source /usr/local/bin/rover
   ```

## Terraform Issues

### Issue: "Error: Failed to load plugin schemas"

**Symptoms:**
```
Error: Failed to load plugin schemas
Plugin reinitialization required. Please run "terraform init"
```

**Solutions:**

1. **Run terraform init:**
   ```bash
   rover -lz /path/to/landingzone -a init
   ```

2. **Clear terraform cache:**
   ```bash
   rm -rf .terraform/
   rm .terraform.lock.hcl
   rover -lz /path/to/landingzone -a init
   ```

3. **Update provider constraints:**
   ```hcl
   terraform {
     required_providers {
       azurerm = {
         source  = "hashicorp/azurerm"
         version = "~> 3.0"
       }
     }
   }
   ```

### Issue: "Error: Backend configuration changed"

**Symptoms:**
```
Error: Backend configuration changed
A change in the backend configuration has been detected
```

**Solutions:**

1. **Reconfigure backend:**
   ```bash
   rover -lz /path/to/landingzone -a init -reconfigure
   ```

2. **Migrate state:**
   ```bash
   terraform init -migrate-state
   ```

3. **Check backend configuration:**
   ```bash
   # Verify backend.tf settings
   cat backend.tf
   ```

### Issue: "Error: Error acquiring the state lock"

**Symptoms:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        abc123...
  Operation: OperationTypePlan
  Who:       user@example.com
```

**Solutions:**

1. **Force unlock (use with caution):**
   ```bash
   terraform force-unlock abc123
   ```

2. **Wait for lock to expire:**
   ```bash
   # Locks typically expire after 20 minutes
   sleep 1200
   ```

3. **Check for running processes:**
   ```bash
   ps aux | grep terraform
   docker ps | grep rover
   ```

## Azure Connectivity Issues

### Issue: "Error: Error retrieving available locations"

**Symptoms:**
```
Error: Error retrieving available locations for resource provider
```

**Solutions:**

1. **Register resource providers:**
   ```bash
   az provider register --namespace Microsoft.Resources
   az provider register --namespace Microsoft.Storage
   az provider register --namespace Microsoft.Network
   ```

2. **Check provider status:**
   ```bash
   az provider list --query "[?registrationState=='NotRegistered']" --output table
   ```

3. **Verify subscription access:**
   ```bash
   az account list-locations --output table
   ```

### Issue: "Error: insufficient quota"

**Symptoms:**
```
Error: creating Resource Group: resources.GroupsClient#CreateOrUpdate: 
Failure responding to request: StatusCode=409 -- Original Error: 
autorest/azure: Service returned an error. Status=409 Code="QuotaExceeded"
```

**Solutions:**

1. **Check current usage:**
   ```bash
   az vm list-usage --location eastus --output table
   ```

2. **Request quota increase:**
   ```bash
   az support tickets create \
     --ticket-name "Quota Increase Request" \
     --description "Need increased quota for rover deployments" \
     --severity minimal \
     --support-plan-type basic
   ```

3. **Use different regions:**
   ```bash
   # Check quota in other regions
   az vm list-usage --location westus2 --output table
   ```

## State Management Issues

### Issue: "Error: Failed to get existing workspaces"

**Symptoms:**
```
Error: Failed to get existing workspaces: storage: service returned error: 
StatusCode=403, ErrorCode=Forbidden
```

**Solutions:**

1. **Check storage account permissions:**
   ```bash
   az role assignment list \
     --scope "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/stterraformstate" \
     --assignee $ARM_CLIENT_ID
   ```

2. **Grant required permissions:**
   ```bash
   az role assignment create \
     --assignee $ARM_CLIENT_ID \
     --role "Storage Blob Data Contributor" \
     --scope "/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/stterraformstate"
   ```

3. **Enable Azure AD authentication:**
   ```bash
   export ARM_USE_AZUREAD=true
   export ARM_STORAGE_USE_AZUREAD=true
   ```

### Issue: "Error: container does not exist"

**Symptoms:**
```
Error: container "tfstate" in storage account "stterraformstate" does not exist
```

**Solutions:**

1. **Create storage container:**
   ```bash
   az storage container create \
     --name tfstate \
     --account-name stterraformstate \
     --auth-mode key
   ```

2. **Verify container access:**
   ```bash
   az storage container show \
     --name tfstate \
     --account-name stterraformstate
   ```

## Performance Issues

### Issue: "Terraform operations are slow"

**Symptoms:**
- Long initialization times
- Slow plan/apply operations
- Container performance issues

**Solutions:**

1. **Increase container resources:**
   ```bash
   docker run -it --rm \
     --memory=4g \
     --cpus=2.0 \
     -v $(pwd):/tf/caf \
     aztfmod/rover:latest
   ```

2. **Use terraform provider caching:**
   ```bash
   export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
   mkdir -p $TF_PLUGIN_CACHE_DIR
   ```

3. **Optimize terraform configuration:**
   ```hcl
   # Parallel resource creation
   terraform {
     parallelism = 10
   }
   ```

### Issue: "Large terraform state files"

**Solutions:**

1. **Split large configurations:**
   ```bash
   # Use separate state files for different layers
   rover -lz level0 -a apply
   rover -lz level1 -a apply  
   rover -lz level2 -a apply
   ```

2. **Use terraform remote state:**
   ```hcl
   data "terraform_remote_state" "foundation" {
     backend = "azurerm"
     config = {
       resource_group_name  = "rg-terraform-state"
       storage_account_name = "stterraformstate"
       container_name       = "tfstate"
       key                  = "foundation.terraform.tfstate"
     }
   }
   ```

## CI/CD Issues

### Issue: "GitHub Actions runner out of disk space"

**Symptoms:**
```
Error: No space left on device
```

**Solutions:**

1. **Clean up runner:**
   ```bash
   # In GitHub Actions workflow
   - name: Free Disk Space
     run: |
       sudo rm -rf /opt/hostedtoolcache
       sudo rm -rf /usr/share/dotnet
       sudo rm -rf /opt/ghc
       docker system prune -a -f
   ```

2. **Use self-hosted runners:**
   ```yaml
   jobs:
     deploy:
       runs-on: self-hosted
       container: aztfmod/rover:latest
   ```

### Issue: "Azure DevOps agent timeout"

**Solutions:**

1. **Increase timeout:**
   ```yaml
   jobs:
   - job: TerraformDeploy
     timeoutInMinutes: 60
     steps:
     - task: AzureCLI@2
       timeoutInMinutes: 45
   ```

2. **Split into multiple jobs:**
   ```yaml
   - job: TerraformPlan
   - job: TerraformApply
     dependsOn: TerraformPlan
   ```

## Getting Help

### Log Collection

**Collect comprehensive logs for support:**

```bash
#!/bin/bash
# collect-rover-logs.sh

LOG_DIR="rover-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

echo "Collecting rover diagnostic information..."

# System information
uname -a > "$LOG_DIR/system-info.txt"
docker --version >> "$LOG_DIR/system-info.txt"
docker info >> "$LOG_DIR/system-info.txt" 2>&1

# Rover information
docker run --rm aztfmod/rover:latest rover --version > "$LOG_DIR/rover-version.txt" 2>&1

# Azure information
az --version > "$LOG_DIR/azure-info.txt" 2>&1
az account show >> "$LOG_DIR/azure-info.txt" 2>&1

# Container logs
docker logs $(docker ps -q --filter ancestor=aztfmod/rover) > "$LOG_DIR/container-logs.txt" 2>&1

# Terraform logs (if available)
if [ -f .terraform/terraform.tfstate ]; then
    cp .terraform/terraform.tfstate "$LOG_DIR/"
fi

# Environment variables (sanitized)
env | grep -E "^(ARM_|TF_|AZURE_)" | sed 's/=.*/=***/' > "$LOG_DIR/env-vars.txt"

echo "Logs collected in: $LOG_DIR"
echo "Please provide this directory when seeking support."
```

### Community Resources

- **🐛 Bug Reports**: [GitHub Issues](https://github.com/aztfmod/rover/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/aztfmod/rover/discussions)
- **💬 Real-time Chat**: [Gitter Community](https://gitter.im/aztfmod/community)
- **📧 Direct Support**: tf-landingzones@microsoft.com

### Issue Reporting Template

When reporting issues, please include:

```markdown
## Issue Description
Brief description of the problem

## Environment Information
- OS: [e.g., Ubuntu 20.04, Windows 11, macOS 12]
- Docker Version: [e.g., 20.10.17]
- Rover Version: [e.g., 1.3.0]
- Azure CLI Version: [e.g., 2.40.0]

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What you expected to happen

## Actual Behavior
What actually happened

## Error Messages
```
Copy and paste any error messages here
```

## Diagnostic Information
```
Paste output from rover-diagnostics.sh here
```

## Additional Context
Any other relevant information
```

### Escalation Path

1. **Community Support** (GitHub Issues/Discussions)
2. **Documentation** (Check troubleshooting guides)
3. **Direct Support** (tf-landingzones@microsoft.com)
4. **Microsoft Support** (For enterprise customers)

---

**Remember**: Most issues can be resolved by checking authentication, permissions, and network connectivity. When in doubt, run the diagnostic script and check the logs!

Next: [Performance Tuning](PERFORMANCE.md) | [FAQ](FAQ.md)