# Security Guide

This document outlines security best practices, configurations, and considerations when using the Azure Terraform SRE Rover.

## 📋 Table of Contents

- [Security Overview](#security-overview)
- [Authentication & Authorization](#authentication--authorization)
- [Container Security](#container-security)
- [Network Security](#network-security)
- [State File Security](#state-file-security)
- [Secret Management](#secret-management)
- [Security Scanning](#security-scanning)
- [Compliance & Governance](#compliance--governance)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)

## Security Overview

Rover implements defense-in-depth security principles across multiple layers:

- **🛡️ Container Security**: Hardened container images with minimal attack surface
- **🔐 Identity & Access**: Azure AD integration with RBAC enforcement
- **🔒 Encryption**: End-to-end encryption for data in transit and at rest
- **🔍 Monitoring**: Comprehensive logging and security event monitoring
- **📋 Compliance**: Built-in compliance scanning and policy enforcement
- **🚨 Detection**: Real-time threat detection and automated response

## Authentication & Authorization

### Azure Active Directory Integration

#### Service Principal Authentication (Recommended for CI/CD)

```bash
# Create dedicated service principal
az ad sp create-for-rbac \
  --name "rover-production-sp" \
  --role "Contributor" \
  --scopes "/subscriptions/{subscription-id}" \
  --sdk-auth

# Set environment variables (in CI/CD)
export ARM_CLIENT_ID="service-principal-client-id"
export ARM_CLIENT_SECRET="service-principal-secret"
export ARM_SUBSCRIPTION_ID="target-subscription-id"
export ARM_TENANT_ID="azure-tenant-id"
```

**Security Best Practices:**
- Use separate service principals per environment
- Apply principle of least privilege
- Rotate secrets regularly (90 days maximum)
- Monitor service principal usage

#### Managed Identity Authentication (Recommended for Azure-hosted)

```bash
# Enable system-assigned managed identity
az vm identity assign --name myVM --resource-group myRG

# Configure rover to use managed identity
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID="target-subscription-id"
```

**Benefits:**
- No credential management required
- Automatic credential rotation
- Azure-native authentication
- Reduced secret sprawl

#### Interactive Authentication (Development Only)

```bash
# Device code flow for development
az login --use-device-code

# Verify authentication
az account show
```

**Security Considerations:**
- Only use for local development
- Never use in automated pipelines
- Ensure proper session management

### Role-Based Access Control (RBAC)

#### Minimum Required Permissions

```json
{
  "Name": "Rover Terraform Operator",
  "Description": "Minimum permissions for Rover operations",
  "Actions": [
    "*/read",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.KeyVault/vaults/*",
    "Microsoft.Network/*",
    "Microsoft.Compute/*"
  ],
  "NotActions": [
    "Microsoft.Authorization/*/Delete",
    "Microsoft.Authorization/*/Write",
    "Microsoft.Authorization/elevateAccess/Action"
  ],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscription-id}"
  ]
}
```

#### Environment-Specific Roles

```bash
# Development environment - broader permissions
az role assignment create \
  --assignee {service-principal-id} \
  --role "Contributor" \
  --scope "/subscriptions/{dev-subscription-id}"

# Production environment - restricted permissions  
az role assignment create \
  --assignee {service-principal-id} \
  --role "Rover Production Operator" \
  --scope "/subscriptions/{prod-subscription-id}"
```

## Container Security

### Image Security

#### Vulnerability Scanning

```bash
# Scan rover image for vulnerabilities
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/tmp \
  aquasec/trivy image aztfmod/rover:latest

# Scan with specific severity
trivy image --severity HIGH,CRITICAL aztfmod/rover:latest
```

#### Image Signing and Verification

```bash
# Verify image signatures (when available)
docker trust inspect aztfmod/rover:latest

# Use specific digest for reproducible builds
docker pull aztfmod/rover@sha256:abc123...
```

### Runtime Security

#### Non-Root Execution

```dockerfile
# Rover runs as non-root user by default
USER vscode
WORKDIR /home/vscode
```

#### Resource Limits

```bash
# Run with resource constraints
docker run -it --rm \
  --memory=2g \
  --cpus=1.5 \
  --ulimit nofile=1024:1024 \
  aztfmod/rover:latest
```

#### Read-Only Root Filesystem

```bash
# Run with read-only root filesystem
docker run -it --rm \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /var/tmp \
  -v rover-home:/home/vscode \
  aztfmod/rover:latest
```

### Secrets Management in Containers

```bash
# Use Docker secrets (Swarm mode)
echo "secret-value" | docker secret create azure-client-secret -

# Mount secret in container
docker service create \
  --secret azure-client-secret \
  --env ARM_CLIENT_SECRET_FILE=/run/secrets/azure-client-secret \
  aztfmod/rover:latest

# Use external secret management
docker run -it --rm \
  -v vault-secrets:/vault/secrets:ro \
  aztfmod/rover:latest
```

## Network Security

### Network Isolation

#### Private Container Networks

```bash
# Create isolated network
docker network create \
  --driver bridge \
  --subnet=172.20.0.0/16 \
  --ip-range=172.20.240.0/20 \
  rover-network

# Run rover in isolated network
docker run -it --rm \
  --network rover-network \
  aztfmod/rover:latest
```

#### Azure Private Endpoints

```bash
# Configure private endpoint access
export ARM_USE_PRIVATE_LINK=true
export ARM_PRIVATE_ENDPOINT_SUBNET_ID="/subscriptions/.../subnets/private-endpoints"
```

### Firewall Configuration

#### Outbound Rules

```bash
# Required Azure endpoints
https://management.azure.com        # Azure Resource Manager
https://login.microsoftonline.com   # Azure AD authentication
https://graph.microsoft.com         # Microsoft Graph
https://storage.azure.com           # Azure Storage
https://vault.azure.net             # Azure Key Vault

# Terraform endpoints
https://registry.terraform.io       # Terraform Registry
https://releases.hashicorp.com      # HashiCorp releases
https://checkpoint-api.hashicorp.com # Terraform checkpoint

# Container registry
https://registry-1.docker.io        # Docker Hub
https://auth.docker.io              # Docker authentication
```

#### Network Security Groups

```hcl
# NSG rules for rover agents
resource "azurerm_network_security_rule" "rover_outbound" {
  name                       = "RoverOutbound"
  priority                   = 100
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_ranges    = ["443", "80"]
  source_address_prefix      = "*"
  destination_address_prefixes = [
    "AzureCloud",
    "Internet"
  ]
  resource_group_name         = azurerm_resource_group.rover.name
  network_security_group_name = azurerm_network_security_group.rover.name
}
```

## State File Security

### Encryption at Rest

```hcl
# Terraform backend with encryption
terraform {
  backend "azurerm" {
    resource_group_name      = "rg-terraform-state"
    storage_account_name     = "stterraformstate"
    container_name           = "tfstate"
    key                      = "prod.terraform.tfstate"
    
    # Security configurations
    use_azuread_auth        = true
    use_msi                 = true
    snapshot                = true
  }
}
```

#### Storage Account Security

```bash
# Create secure storage account
az storage account create \
  --name stterraformstate \
  --resource-group rg-terraform-state \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false
```

### Access Control

#### Storage Account RBAC

```bash
# Grant rover service principal storage access
az role assignment create \
  --assignee {rover-sp-id} \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/{sub-id}/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/stterraformstate"
```

#### Container-Level Permissions

```bash
# Create container with specific permissions
az storage container create \
  --name tfstate \
  --account-name stterraformstate \
  --public-access off \
  --metadata environment=production team=platform
```

### State File Encryption

#### Client-Side Encryption

```bash
# Enable client-side encryption
export TF_STATE_ENCRYPTION_KEY="base64-encoded-key"

# Use Azure Key Vault for key management
export ARM_CLIENT_CERTIFICATE_PATH="/path/to/certificate.pfx"
export ARM_CLIENT_CERTIFICATE_PASSWORD="certificate-password"
```

## Secret Management

### Azure Key Vault Integration

#### Store Terraform Variables

```hcl
# Retrieve secrets from Key Vault
data "azurerm_key_vault" "main" {
  name                = "kv-terraform-secrets"
  resource_group_name = "rg-security"
}

data "azurerm_key_vault_secret" "database_password" {
  name         = "database-password"
  key_vault_id = data.azurerm_key_vault.main.id
}

# Use in resources
resource "azurerm_mssql_server" "main" {
  administrator_login_password = data.azurerm_key_vault_secret.database_password.value
}
```

#### Runtime Secret Injection

```bash
# Retrieve secrets at runtime
export DATABASE_PASSWORD=$(az keyvault secret show \
  --vault-name kv-terraform-secrets \
  --name database-password \
  --query value -o tsv)

# Use with rover
rover -lz ./landingzone -a apply \
  -var "database_password=${DATABASE_PASSWORD}"
```

### Secret Scanning

#### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json
```

#### CI/CD Secret Detection

```bash
# GitLeaks scanning
docker run --rm -v $(pwd):/code \
  zricethezav/gitleaks:latest \
  detect --source /code --verbose
```

## Security Scanning

### Static Analysis

#### Terraform Security Scanning

```bash
# TFLint configuration
cat > .tflint.hcl << EOF
plugin "azurerm" {
    enabled = true
    version = "0.20.0"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "azurerm_*" {
  enabled = true
}
EOF

# Run TFLint
tflint --config .tflint.hcl
```

#### Policy as Code

```bash
# Terrascan scanning
terrascan scan -t terraform \
  --policy-type azure \
  --severity high \
  --output json

# Custom policy checks
checkov -f main.tf \
  --framework terraform \
  --check CKV_AZURE_*
```

### Dynamic Analysis

#### Runtime Security Monitoring

```bash
# Container runtime security
docker run -d \
  --name rover-monitor \
  --pid host \
  --security-opt apparmor:unconfined \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /sys/kernel/debug:/sys/kernel/debug \
  falcosecurity/falco
```

### Vulnerability Management

#### Continuous Scanning

```yaml
# GitHub Actions security workflow
name: Security Scan
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'aztfmod/rover:latest'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

## Compliance & Governance

### Policy Enforcement

#### Azure Policy Integration

```hcl
# Azure Policy for rover compliance
resource "azurerm_policy_definition" "rover_compliance" {
  name         = "rover-security-compliance"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Rover Security Compliance"

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Storage/storageAccounts"
      },
      {
        "field": "tags['managed-by']",
        "equals": "rover"
      }
    ]
  },
  "then": {
    "effect": "audit",
    "details": {
      "type": "Microsoft.Storage/storageAccounts",
      "existenceCondition": {
        "allOf": [
          {
            "field": "Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly",
            "equals": "true"
          },
          {
            "field": "Microsoft.Storage/storageAccounts/minimumTlsVersion",
            "equals": "TLS1_2"
          }
        ]
      }
    }
  }
}
POLICY_RULE
}
```

#### Terraform Compliance Checks

```bash
# Compliance scanning with rover
rover ci -ct compliance -sc /tf/config/symphony.yml

# Custom compliance checks
compliance_check() {
    local tf_file=$1
    
    # Check for required tags
    if ! grep -q 'tags.*=.*{' "$tf_file"; then
        echo "ERROR: Missing required tags in $tf_file"
        return 1
    fi
    
    # Check for encryption settings
    if ! grep -q 'encryption' "$tf_file"; then
        echo "WARNING: No encryption configuration found in $tf_file"
    fi
    
    return 0
}
```

### Audit Logging

#### Azure Activity Logs

```bash
# Enable Azure Activity Logs
az monitor log-analytics workspace create \
  --resource-group rg-monitoring \
  --workspace-name la-rover-audit

# Configure diagnostic settings
az monitor diagnostic-settings create \
  --name rover-audit \
  --resource /subscriptions/{subscription-id} \
  --workspace /subscriptions/{subscription-id}/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/la-rover-audit \
  --logs '[{"category":"Administrative","enabled":true},{"category":"Security","enabled":true}]'
```

#### Container Audit Logging

```bash
# Configure Docker daemon logging
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "audit-logs": {
    "level": "info",
    "path": "/var/log/docker-audit.log"
  }
}
EOF
```

## Incident Response

### Security Incident Procedures

#### Detection and Alerting

```bash
# Set up security alerts
az monitor metrics alert create \
  --name "Rover-Unauthorized-Access" \
  --resource-group rg-monitoring \
  --scopes /subscriptions/{subscription-id} \
  --condition "count 'location' eq 'Global' FailedCount gt 5" \
  --description "Multiple failed authentication attempts detected"
```

#### Incident Response Playbook

1. **Detection**
   - Monitor Azure Activity Logs
   - Review container audit logs
   - Check security scan results

2. **Containment**
   ```bash
   # Immediately revoke compromised credentials
   az ad sp credential reset --name rover-production-sp
   
   # Stop running rover containers
   docker stop $(docker ps -q --filter ancestor=aztfmod/rover)
   
   # Block suspicious IP addresses
   az network nsg rule create \
     --resource-group rg-security \
     --nsg-name nsg-rover \
     --name BlockSuspiciousIP \
     --priority 100 \
     --source-address-prefixes {suspicious-ip} \
     --access Deny
   ```

3. **Investigation**
   - Analyze audit logs
   - Review Terraform state changes
   - Check for unauthorized resource modifications

4. **Recovery**
   - Restore from known good state
   - Update security configurations
   - Implement additional controls

### Backup and Recovery

#### Terraform State Backup

```bash
# Automated state backup
backup_terraform_state() {
    local state_file=$1
    local backup_location=$2
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # Create backup
    az storage blob copy start \
      --source-container tfstate \
      --source-blob "$state_file" \
      --destination-container tfstate-backup \
      --destination-blob "${state_file}-${timestamp}" \
      --account-name stterraformstate
    
    echo "State backup created: ${state_file}-${timestamp}"
}
```

#### Disaster Recovery

```hcl
# Cross-region state replication
resource "azurerm_storage_account" "state_backup" {
  name                     = "stterraformstatedr"
  resource_group_name      = azurerm_resource_group.dr.name
  location                 = "West US 2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
  }
}
```

## Security Checklist

### Pre-Deployment Security Review

- [ ] **Authentication**
  - [ ] Service principal permissions reviewed
  - [ ] RBAC assignments follow least privilege
  - [ ] Managed identity enabled where possible
  
- [ ] **Container Security**
  - [ ] Using latest rover image
  - [ ] Vulnerability scan passed
  - [ ] Running as non-root user
  - [ ] Resource limits configured
  
- [ ] **Network Security**
  - [ ] Network isolation configured
  - [ ] Firewall rules reviewed
  - [ ] Private endpoints enabled
  
- [ ] **State Management**
  - [ ] Encryption at rest enabled
  - [ ] Access controls configured
  - [ ] Backup strategy implemented
  
- [ ] **Secret Management**
  - [ ] No hardcoded secrets
  - [ ] Key Vault integration configured
  - [ ] Secret rotation schedule defined

### Runtime Security Monitoring

- [ ] **Logging**
  - [ ] Azure Activity Logs enabled
  - [ ] Container audit logging configured
  - [ ] Security alerts configured
  
- [ ] **Monitoring**
  - [ ] Failed authentication alerts
  - [ ] Unusual resource access patterns
  - [ ] Container runtime anomalies
  
- [ ] **Compliance**
  - [ ] Policy compliance checked
  - [ ] Security scan results reviewed
  - [ ] Audit reports generated

### Post-Deployment Security Validation

- [ ] **Access Validation**
  - [ ] Authentication working correctly
  - [ ] Permissions verified
  - [ ] Unauthorized access blocked
  
- [ ] **Configuration Review**
  - [ ] Security settings applied
  - [ ] Encryption verified
  - [ ] Monitoring active
  
- [ ] **Documentation**
  - [ ] Security configuration documented
  - [ ] Incident response procedures updated
  - [ ] Security contacts verified

---

For security issues or vulnerabilities, please email: security@aztfmod.com

Next: [Troubleshooting Guide](TROUBLESHOOTING.md) | [Architecture Overview](ARCHITECTURE.md)