# Rover Architecture

This document describes the architecture and design of the Azure Terraform SRE Rover project.

## Table of Contents

- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [Core Components](#core-components)
- [Data Flow](#data-flow)
- [State Management](#state-management)
- [CI/CD Integration](#cicd-integration)
- [Docker Container Architecture](#docker-container-architecture)
- [Extension Points](#extension-points)

## Overview

Rover is an enterprise-grade orchestration platform for Terraform deployments on Azure. It provides:

1. **Containerized Development Environment** - Consistent tooling across all platforms
2. **State Management** - Azure Storage and Terraform Cloud backend support
3. **CI/CD Integration** - Seamless integration with multiple CI/CD platforms
4. **Terraform Wrapper** - Enhanced Terraform execution with logging and error handling

### Design Principles

- **Ubiquity**: Run anywhere - local development, cloud pipelines, different CI/CD platforms
- **Consistency**: Same experience and tooling across all environments
- **Modularity**: Loosely coupled components with clear interfaces
- **Reliability**: Robust error handling, retry logic, and state management
- **Traceability**: Comprehensive logging with JUnit report generation

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Rover Container                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  rover.sh (Main Entry)               │   │
│  │              Command Parsing & Routing               │   │
│  └──────────────────┬──────────────────────────────────┘   │
│                     │                                        │
│         ┌───────────┴───────────┬───────────────────┐      │
│         ▼                       ▼                    ▼      │
│  ┌─────────────┐        ┌─────────────┐    ┌─────────────┐│
│  │   CI/CD     │        │ Landingzone │    │  Workspace  ││
│  │  Workflows  │        │   Deploy    │    │   Mgmt      ││
│  └──────┬──────┘        └──────┬──────┘    └──────┬──────┘│
│         │                      │                    │       │
│  ┌──────▼───────────────────────▼────────────────▼──────┐ │
│  │            Core Library Functions                     │ │
│  │  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌─────────┐ │ │
│  │  │Terraform │ │  Logger  │ │  Azure  │ │  State  │ │ │
│  │  │ Wrapper  │ │          │ │   Auth  │ │   Mgmt  │ │ │
│  │  └──────────┘ └──────────┘ └─────────┘ └─────────┘ │ │
│  └────────────────────────────────────────────────────┘ │ │
│                     │                                      │
└─────────────────────┼──────────────────────────────────────┘
                      │
          ┌───────────┴────────────┐
          ▼                        ▼
   ┌─────────────┐         ┌──────────────┐
   │Azure Storage│         │Terraform Cloud│
   │  (State)    │         │   (State)     │
   └─────────────┘         └──────────────┘
```

## Core Components

### 1. Main Entry Point (`rover.sh`)

**Purpose**: Primary orchestrator that initializes the environment and routes commands.

**Responsibilities**:
- Parse command-line parameters
- Source all required libraries and modules
- Set up environment variables and defaults
- Verify Azure session and permissions
- Route to appropriate command handlers

**Key Functions**:
- Command parsing and validation
- Environment initialization
- Error trap setup
- Module checkout and version verification

### 2. Command Handlers

#### Landingzone/Launchpad (`rover.sh`)
Handles infrastructure deployment operations.

**Operations**:
- `plan` - Preview infrastructure changes
- `apply` - Apply infrastructure changes
- `destroy` - Destroy infrastructure
- `state` - State file operations

**Features**:
- Multi-level deployments (level0-level4)
- State composition from lower levels
- Variable folder support
- Backend configuration

#### CI Workflow (`ci.sh`)
Executes continuous integration checks.

**Features**:
- YAML-based task configuration (symphony.yml)
- Pluggable CI tools (tflint, terraform validate, etc.)
- Parallel execution support
- JUnit report generation

**Components**:
- Symphony YAML parser (`symphony_yaml.sh`)
- Task executor (`task.sh`)
- CI task definitions (`scripts/ci_tasks/`)

#### CD Workflow (`cd.sh`)
Manages continuous deployment pipelines.

**Features**:
- Environment-based deployments
- Automated state management
- Integration with CI tools
- Deployment validation

### 3. Core Libraries (`scripts/lib/`)

#### Terraform Wrapper (`terraform.sh`)
Wraps Terraform execution with enhanced capabilities.

**Features**:
- Automatic retry on transient failures
- Comprehensive logging
- Plan file management
- State locking and verification
- Integration with both Azure and TFC backends

**Key Functions**:
```bash
terraform_apply()        # Apply with retry logic
terraform_destroy()      # Destroy with confirmation
terraform_plan_with_target() # Targeted planning
deploy_landingzone()     # Full deployment workflow
```

#### Logger (`logger.sh`)
Structured logging and reporting system.

**Features**:
- Multiple log levels (FATAL, ERROR, WARN, INFO, DEBUG, VERBOSE)
- File and console output
- JUnit XML report generation
- Timestamped log files
- Color-coded console output

**Log Levels**:
- `FATAL` - Critical errors that stop execution
- `ERROR` - Errors requiring attention
- `WARN` - Warning conditions
- `INFO` - Informational messages
- `DEBUG` - Detailed debugging information
- `VERBOSE` - Maximum verbosity

#### Azure Authentication (`azure_ad.sh`)
Handles Azure authentication and authorization.

**Features**:
- Interactive login support
- Service Principal authentication
- Managed Identity support
- Key Vault secret retrieval
- Role assignment validation

**Key Functions**:
```bash
verify_azure_session()              # Check active session
login_as_sp_from_keyvault_secrets() # SP from Key Vault
display_login_instructions()         # User guidance
```

#### Bootstrap (`bootstrap.sh`)
Initial environment setup and validation.

**Features**:
- Module checkout from Git
- Version verification
- Rover version management
- Workspace setup

#### Parameter Parser (`parse_parameters.sh`)
Robust command-line argument parsing.

**Features**:
- Flag parsing with validation
- Environment variable mapping
- Default value handling
- Error reporting for invalid parameters

### 4. State Management (`tfstate.sh`, `remote.sh`)

**Purpose**: Manage Terraform state files across different backend types.

#### Backends Supported

**Azure Storage (azurerm)**:
- State stored in Azure Storage Account
- Automatic container and blob creation
- State locking via blob lease
- Level-based organization

**Terraform Cloud/Enterprise (remote)**:
- Workspace-based state storage
- Remote execution support (local mode only currently)
- Organization and hostname configuration
- Token-based authentication

**Key Functions**:
```bash
tfstate_configure()      # Configure backend
terraform_init()         # Initialize with backend
initialize_state()       # Setup state storage
get_storage_id()        # Retrieve state storage details
```

### 5. Utility Functions (`functions.sh`)

Common utilities used across the codebase.

**Key Functions**:
```bash
error()                  # Error handling and exit
execute_with_backoff()   # Retry logic with exponential backoff
parameter_value()        # Parameter validation
process_actions()        # Action processing pipeline
clean_up_variables()     # Cleanup on exit
```

## Data Flow

### Typical Deployment Flow

```
1. User Command
   └─> rover -lz ./landingzone -a apply -env prod -level level2
       
2. Parameter Parsing (parse_parameters.sh)
   └─> Extract and validate: landingzone path, action, environment, level
       
3. Environment Setup (rover.sh)
   ├─> Initialize logger
   ├─> Set environment variables
   ├─> Setup TF_DATA_DIR
   └─> Verify Azure session
       
4. State Management (tfstate.sh)
   ├─> Configure backend (azurerm or remote)
   ├─> Initialize state storage
   └─> Setup state composition from lower levels
       
5. Terraform Execution (lib/terraform.sh)
   ├─> Terraform init with backend
   ├─> Terraform plan (if requested)
   ├─> Terraform apply (if requested)
   └─> Log all output
       
6. Cleanup & Reporting
   ├─> Generate JUnit report
   ├─> Save logs
   └─> Cleanup temporary files
```

### CI/CD Flow

```
1. CI Command
   └─> rover ci -sc symphony.yml -b /tf/caf -env demo
       
2. Symphony File Parsing (symphony_yaml.sh)
   └─> Load configuration tasks
       
3. Task Execution (task.sh, ci.sh)
   ├─> For each task:
   │   ├─> Load task configuration
   │   ├─> Execute tool (tflint, validate, etc.)
   │   └─> Capture results
   └─> Aggregate results
       
4. Report Generation (logger.sh)
   └─> Generate JUnit XML with pass/fail status
```

## State Management

### State File Organization

#### Azure Storage Backend

```
Storage Account: <configured_account>
├── Container: <level>-<environment>
│   ├── Blob: <workspace>.tfstate
│   └── State Lock: Lease on blob
```

**Example**:
```
tfstate123abc
├── level2-production
│   ├── networking-hub.tfstate
│   ├── networking-spoke1.tfstate
│   └── networking-spoke2.tfstate
```

#### State Composition

Rover supports reading state from lower levels for composition:

```
Level 4 (Applications)
  └─> Reads from Level 3 (Compute)
      └─> Reads from Level 2 (Networking)
          └─> Reads from Level 1 (Security)
              └─> Reads from Level 0 (Launchpad)
```

### State Locking

- **Azure Storage**: Uses blob lease mechanism
- **Terraform Cloud**: Built-in workspace locking
- **Local**: Lock file in `.terraform` directory

## CI/CD Integration

### Platform Agents

Rover provides pre-built agents for multiple CI/CD platforms:

1. **GitHub Actions** (`agents/github/`)
   - Self-hosted runner
   - GitHub-specific environment setup
   - Action workflow integration

2. **Azure DevOps** (`agents/azure_devops/`)
   - Pipeline agent
   - Azure DevOps specific tooling
   - Pipeline task integration

3. **GitLab** (`agents/gitlab/`)
   - GitLab Runner
   - CI/CD pipeline integration

4. **Terraform Cloud** (`agents/tfc/`)
   - TFC Agent
   - Remote execution support

### Agent Architecture

```
Base Rover Image (Ubuntu 22.04)
├── Terraform
├── Azure CLI
├── Git
└── Rover Scripts

        ↓ Extends

Platform-Specific Agent
├── Base Rover Image
├── Platform Runner/Agent Software
└── Platform-Specific Scripts
```

## Docker Container Architecture

### Base Image (Dockerfile)

**Base**: Ubuntu 22.04

**Installed Tools**:
- Terraform (multiple versions supported)
- Azure CLI
- kubectl
- jq, yq
- Python 3
- Git
- ShellCheck
- Pre-commit hooks

**User Setup**:
- Non-root user: `vscode`
- Home directory: `/home/vscode`
- Working directory: `/tf/caf`

**Volumes**:
- `/tf/caf` - Landing zones and configurations
- `/home/vscode/.terraform.logs` - Log files
- `/home/vscode/.azure` - Azure credentials
- `/home/vscode/.ssh` - SSH keys

**Entry Points**:
- Interactive: `/bin/bash`
- Rover command: `rover`

## Extension Points

### Adding New CI Tools

1. Create task configuration in `scripts/ci_tasks/<tool>.yaml`
2. Define task parameters:
   ```yaml
   tool_name: mytool
   command: mytool check
   args: --config .mytoolrc
   working_directory: ${base_dir}
   ```
3. Add to symphony.yml:
   ```yaml
   tasks:
     - name: mytool
       enabled: true
   ```

### Adding New Backends

1. Implement in `tfstate.sh`:
   ```bash
   case "${backend_type}" in
       mybackend)
           tfstate_configure_mybackend
           terraform_init_mybackend
           ;;
   esac
   ```

2. Add backend template in `scripts/backend.mybackend.tf`

3. Update documentation

### Custom Agent Creation

1. Create Dockerfile extending base rover image:
   ```dockerfile
   FROM aztfmod/rover:latest
   # Install platform-specific agent
   # Configure agent
   ```

2. Add platform-specific scripts in `agents/<platform>/`

3. Build and publish agent image

## Security Considerations

### Credential Management

- **Service Principals**: Stored in Azure Key Vault
- **Terraform Cloud Tokens**: Stored in `~/.terraform.d/credentials.tfrc.json`
- **Azure Credentials**: Cached by Azure CLI in `~/.azure`

### State File Security

- Azure Storage: Encryption at rest enabled
- Access control via RBAC
- Network access restrictions supported
- State locking prevents concurrent modifications

### Container Security

- Non-root user by default
- Minimal base image (Ubuntu)
- Regular security updates
- No secrets baked into image

## Performance Considerations

### Caching

- **Terraform Providers**: Cached in `TF_PLUGIN_CACHE_DIR`
- **Terraform Modules**: Cached in `.terraform/modules`
- **Azure CLI tokens**: Cached for session duration

### Parallel Execution

- Multiple CI tasks can run in parallel
- State locking prevents concurrent state modifications
- Separate workspaces enable parallel deployments

### Retry Logic

- Exponential backoff for transient failures
- Configurable retry attempts (default: 5)
- Timeout between retries (default: 20s, doubles each attempt)

## Error Handling

### Error Propagation

```
Error Detected
  └─> error() function called
      ├─> Log error with context
      ├─> Generate JUnit report (if applicable)
      ├─> Cancel Terraform Cloud run (if remote)
      ├─> Cleanup variables
      └─> Exit with error code
```

### Exit Codes

- `0` - Success
- `1` - Generic error
- `2` - Misuse of shell command
- `3xxx` - Rover-specific errors
  - `3001` - Backend type not supported
  - `3002` - Backend initialization failed

## Logging and Observability

### Log Files

- Location: `~/.terraform.logs/`
- Format: `<timestamp>-<command>.log`
- Rotation: None (manual cleanup required)

### JUnit Reports

- Generated for CI/CD runs
- Location: Configurable
- Format: JUnit XML
- Integration: Most CI/CD platforms

### Debug Mode

Enable with `-d` or `--debug` flag:
- Sets `TF_LOG=DEBUG`
- Increases rover verbosity
- Displays all commands executed

## Future Enhancements

Potential areas for extension:

1. **Multi-cloud Support**: Extend beyond Azure
2. **State Backend Plugins**: Plugin architecture for backends
3. **Enhanced Composition**: Cross-backend state reading
4. **Metrics and Monitoring**: Prometheus/Grafana integration
5. **Policy as Code**: OPA/Sentinel integration
6. **Cost Estimation**: Pre-apply cost analysis

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [Azure CAF](https://aka.ms/caf/terraform)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [ShellCheck](https://www.shellcheck.net/)
