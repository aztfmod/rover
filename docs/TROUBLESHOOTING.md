# Rover Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using Rover.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Authentication Issues](#authentication-issues)
- [State Management Issues](#state-management-issues)
- [Terraform Execution Issues](#terraform-execution-issues)
- [CI/CD Issues](#cicd-issues)
- [Docker Issues](#docker-issues)
- [Performance Issues](#performance-issues)
- [Debugging Tips](#debugging-tips)

## Installation Issues

### Docker Image Won't Pull

**Problem**: Unable to pull the rover image from Docker Hub

```bash
Error: manifest for aztfmod/rover:latest not found
```

**Solution**:
1. Check your internet connection
2. Verify the tag exists: https://hub.docker.com/r/aztfmod/rover/tags
3. Try pulling a specific version:
   ```bash
   docker pull aztfmod/rover:1.5.0-2303.0110
   ```
4. Check Docker Hub status: https://status.docker.com/

### ShellSpec Not Found

**Problem**: Tests fail with "shellspec: command not found"

**Solution**:
1. Install ShellSpec:
   ```bash
   curl -fsSL https://git.io/shellspec | sh
   ```
2. Add to PATH:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```
3. Verify installation:
   ```bash
   shellspec --version
   ```

## Authentication Issues

### Azure Login Fails

**Problem**: `rover login` fails with authentication error

```bash
Error: AADSTS50020: User account from identity provider does not exist in tenant
```

**Solution**:
1. Verify tenant ID:
   ```bash
   rover login --tenant <your-tenant-id>
   ```
2. Check if you have access to the subscription:
   ```bash
   az account list
   ```
3. Try browser-based login:
   ```bash
   az login --use-device-code
   ```
4. Clear cached credentials:
   ```bash
   rm -rf ~/.azure
   rover login
   ```

### Service Principal Authentication Fails

**Problem**: SP authentication fails with permission errors

**Solution**:
1. Verify SP credentials:
   ```bash
   az login --service-principal \
     --username $ARM_CLIENT_ID \
     --password $ARM_CLIENT_SECRET \
     --tenant $ARM_TENANT_ID
   ```
2. Check SP has required permissions:
   - Contributor or Owner on subscription
   - Access to Key Vault (if using Key Vault for secrets)
3. Verify environment variables are set:
   ```bash
   echo $ARM_CLIENT_ID
   echo $ARM_TENANT_ID
   # Don't echo the secret!
   ```

### Token Expired

**Problem**: Operations fail with token expiration error

```bash
Error: The access token expiry UTC time is '2024-01-01 12:00:00'
```

**Solution**:
1. Re-authenticate:
   ```bash
   rover logout
   rover login
   ```
2. For long-running operations, use a Service Principal instead of interactive login

## State Management Issues

### State File Not Found

**Problem**: Terraform can't find the state file

```bash
Error: Failed to get existing workspaces: storage: service returned error: StatusCode=404
```

**Solution**:
1. Verify state storage exists:
   ```bash
   az storage account show --name <storage-account> --resource-group <rg>
   ```
2. Check container exists:
   ```bash
   az storage container show \
     --name <level>-<environment> \
     --account-name <storage-account>
   ```
3. Verify permissions on storage account:
   ```bash
   az role assignment list \
     --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<sa>
   ```
4. Initialize the launchpad first if this is a new deployment

### State Lock Timeout

**Problem**: State is locked and can't acquire lock

```bash
Error: Error acquiring the state lock: state locked
```

**Solution**:
1. Wait for the other operation to complete
2. Check if there's a stuck lock:
   ```bash
   az storage blob show \
     --container-name <container> \
     --name <statefile>.tfstate \
     --account-name <storage-account>
   ```
3. Force unlock (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```
4. If blob is leased, break the lease:
   ```bash
   az storage blob lease break \
     --container-name <container> \
     --blob-name <statefile>.tfstate \
     --account-name <storage-account>
   ```

### State Drift Detected

**Problem**: Terraform detects resources have been modified outside of Terraform

**Solution**:
1. Review the drift:
   ```bash
   rover -lz <path> -a plan
   ```
2. Import manually changed resources:
   ```bash
   terraform import <resource-type>.<name> <azure-resource-id>
   ```
3. Refresh state:
   ```bash
   terraform refresh
   ```
4. Consider using `prevent_destroy` lifecycle rules for critical resources

## Terraform Execution Issues

### Terraform Init Fails

**Problem**: Initialization fails with provider download errors

```bash
Error: Failed to install provider
```

**Solution**:
1. Check internet connectivity
2. Clear plugin cache:
   ```bash
   rm -rf ~/.terraform.d/plugin-cache
   rm -rf .terraform
   ```
3. Set plugin cache directory:
   ```bash
   export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
   mkdir -p $TF_PLUGIN_CACHE_DIR
   ```
4. Try with a specific provider version:
   ```hcl
   terraform {
     required_providers {
       azurerm = {
         source  = "hashicorp/azurerm"
         version = "= 3.50.0"
       }
     }
   }
   ```

### Plan Shows Unexpected Changes

**Problem**: Terraform plan shows changes that shouldn't be there

**Solution**:
1. Check for version mismatches:
   ```bash
   terraform version
   ```
2. Review provider versions in state vs. configuration
3. Use `-refresh=false` to see changes without refreshing:
   ```bash
   rover -lz <path> -a plan -refresh=false
   ```
4. Check for externally modified resources
5. Review any lifecycle rules (ignore_changes, create_before_destroy)

### Apply Fails with Timeout

**Problem**: `terraform apply` times out

```bash
Error: timeout while waiting for state to become 'Succeeded'
```

**Solution**:
1. Increase timeout in provider configuration:
   ```hcl
   provider "azurerm" {
     features {}
     
     timeout = "60m"
   }
   ```
2. Check Azure service health: https://status.azure.com/
3. Try applying in smaller batches using `-target`:
   ```bash
   rover -lz <path> -a apply -target=<resource>
   ```
4. Check for resource quotas or limits in Azure

### Provider Rate Limiting

**Problem**: Operations fail with rate limit errors

```bash
Error: Error making API request: StatusCode=429
```

**Solution**:
1. Enable retry with backoff (rover does this automatically)
2. Increase delay between retries:
   ```bash
   export TIMEOUT=30
   export ATTEMPTS=10
   ```
3. Reduce parallelism:
   ```bash
   terraform apply -parallelism=5
   ```
4. Split deployment into smaller chunks

## CI/CD Issues

### Symphony YAML Not Found

**Problem**: CI workflow fails to find symphony.yml

```bash
Error: Invalid path, symphony.yml file not found
```

**Solution**:
1. Verify file exists:
   ```bash
   ls -la symphony.yml
   ```
2. Provide absolute path:
   ```bash
   rover ci -sc /full/path/to/symphony.yml -b /tf/caf
   ```
3. Check file permissions:
   ```bash
   chmod 644 symphony.yml
   ```

### CI Task Fails

**Problem**: Specific CI task fails during validation

**Solution**:
1. Run task manually to see full error:
   ```bash
   rover ci -ct <task-name> -sc symphony.yml -b /tf/caf -d
   ```
2. Check task configuration in `scripts/ci_tasks/<task>.yaml`
3. Verify required tools are installed:
   ```bash
   which tflint terraform-docs
   ```
4. Review task logs in `~/.terraform.logs/`

### JUnit Report Not Generated

**Problem**: CI reports are not being generated

**Solution**:
1. Ensure `LOG_TO_FILE` is set to true:
   ```bash
   export LOG_TO_FILE=true
   ```
2. Check log folder exists and is writable:
   ```bash
   ls -la ~/.terraform.logs/
   ```
3. Verify logger is initialized:
   ```bash
   export log_folder_path=~/.terraform.logs
   ```

## Docker Issues

### Container Exits Immediately

**Problem**: Rover container exits right after starting

**Solution**:
1. Run with interactive terminal:
   ```bash
   docker run -it aztfmod/rover:latest /bin/bash
   ```
2. Check container logs:
   ```bash
   docker logs <container-id>
   ```
3. Verify entry point:
   ```bash
   docker inspect aztfmod/rover:latest | grep Entrypoint
   ```

### Volume Mount Issues

**Problem**: Files not visible in container or permission errors

**Solution**:
1. Use absolute paths for volume mounts:
   ```bash
   docker run -v /absolute/path:/tf/caf aztfmod/rover
   ```
2. Check mount permissions:
   ```bash
   docker run -it -v $(pwd):/tf/caf aztfmod/rover ls -la /tf/caf
   ```
3. On Windows, enable file sharing in Docker Desktop settings
4. On Linux, check SELinux context:
   ```bash
   ls -Z /path/to/mount
   ```

### Out of Disk Space

**Problem**: Container operations fail with disk space errors

**Solution**:
1. Check Docker disk usage:
   ```bash
   docker system df
   ```
2. Clean up unused resources:
   ```bash
   docker system prune -a
   docker volume prune
   ```
3. Increase Docker disk allocation (Docker Desktop settings)

## Performance Issues

### Slow Terraform Operations

**Problem**: Terraform operations take too long

**Solution**:
1. Enable provider plugin caching:
   ```bash
   export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
   ```
2. Reduce parallelism if hitting rate limits:
   ```bash
   terraform apply -parallelism=5
   ```
3. Use targeted applies for specific resources:
   ```bash
   rover -lz <path> -a apply -target=<resource>
   ```
4. Consider splitting large deployments into multiple landing zones

### High Memory Usage

**Problem**: Rover container uses excessive memory

**Solution**:
1. Limit container memory:
   ```bash
   docker run -m 2g aztfmod/rover
   ```
2. Clear Terraform plugin cache periodically
3. Use smaller landing zones
4. Disable debug logging:
   ```bash
   unset TF_LOG
   ```

## Debugging Tips

### Enable Debug Mode

Enable verbose logging to see detailed execution:

```bash
rover -lz <path> -a plan -d
# or
rover -lz <path> -a plan --log-severity DEBUG
```

### Check Terraform Logs

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
rover -lz <path> -a plan
cat terraform.log
```

### View Rover Logs

```bash
ls -la ~/.terraform.logs/
cat ~/.terraform.logs/<latest-log-file>
```

### Test Azure Connectivity

```bash
# Check Azure session
az account show

# Test Azure API access
az group list

# Check storage account access
az storage container list --account-name <storage-account>
```

### Validate Terraform Configuration

```bash
cd <landingzone-path>
terraform init
terraform validate
terraform fmt -check
```

### Run in Isolation

Test with minimal configuration:

```bash
# Create minimal test case
mkdir -p /tmp/test-lz
cat > /tmp/test-lz/main.tf << 'EOF'
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test" {
  name     = "rg-test"
  location = "eastus"
}
EOF

# Test with rover
rover -lz /tmp/test-lz -a plan
```

### Check Environment Variables

```bash
# View all rover-related environment variables
env | grep -E "TF_|ARM_|ROVER_" | sort

# Check specific critical variables
echo "Backend type: $gitops_terraform_backend_type"
echo "Environment: $TF_VAR_environment"
echo "Level: $TF_VAR_level"
echo "Workspace: $TF_VAR_workspace"
```

### Verify File Permissions

```bash
# Check script permissions
ls -la scripts/*.sh

# Make scripts executable if needed
chmod +x scripts/*.sh
```

## Getting More Help

If you can't resolve your issue:

1. **Check existing issues**: https://github.com/aztfmod/rover/issues
2. **Open a new issue**: Include:
   - Rover version: `docker inspect aztfmod/rover | grep version`
   - Error messages (full output)
   - Steps to reproduce
   - Environment details (OS, Docker version)
3. **Join the community**: https://gitter.im/aztfmod/community
4. **Email support**: tf-landingzones at microsoft dot com

## Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 1 | Generic error | Check error message and logs |
| 2 | Misuse of shell command | Review command syntax |
| 3001 | Backend type not supported | Use 'azurerm' or 'remote' |
| 3002 | Backend initialization failed | Check backend configuration |

## Additional Resources

- [Rover Documentation](https://aka.ms/caf/terraform)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Docker Documentation](https://docs.docker.com/)
- [ShellSpec Documentation](https://github.com/shellspec/shellspec)
