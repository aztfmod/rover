![](https://github.com/aztfmod/rover/workflows/master/badge.svg)
![](https://github.com/aztfmod/rover/workflows/.github/workflows/ci-branches.yml/badge.svg)
[![Gitter](https://badges.gitter.im/aztfmod/community.svg)](https://gitter.im/aztfmod/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

# Azure Terraform SRE - Landing zones on Terraform - Rover

> :warning: This solution, offered by the Open-Source community, will no longer receive contributions from Microsoft. Customers are encouraged to transition to [Microsoft Azure Verified Modules](https://aka.ms/avm) for Microsoft support and updates.

## Overview

Azure Terraform SRE provides you with guidance and best practices to adopt Azure infrastructure-as-code using Terraform. The Cloud Adoption Framework (CAF) **rover** is a comprehensive toolset for managing enterprise-scale Terraform deployments on Microsoft Azure.

## What is Rover?

The CAF **rover** helps you manage your enterprise Terraform deployments on Microsoft Azure and is composed of two main components:

- **A docker container**
  - Allows consistent developer experience on PC, Mac, Linux, including the right tools, git hooks and DevOps tools.
  - Native integration with [Visual Studio Code](https://code.visualstudio.com/docs/remote/containers), [GitHub Codespaces](https://github.com/features/codespaces).
  - Contains the versioned toolset you need to apply landing zones.
  - Helps you switching components versions fast by separating the run environment and the configuration environment.
  - Ensure pipeline ubiquity and abstraction run the rover everywhere, whichever pipeline technology.

- **A Terraform wrapper**
  - Helps you store and retrieve Terraform state files on Azure storage account.
  - Facilitates the transition to CI/CD.
  - Enables seamless experience (state connection, execution traces, etc.) locally and inside pipelines.

The rover is available from the Docker Hub in form of:

- [Standalone edition](https://hub.docker.com/r/aztfmod/rover/tags?page=1&ordering=last_updated): to be used for landing zones engineering or pipelines.
- [Runner (agent) editions](https://hub.docker.com/r/aztfmod/rover-agent/tags?page=1&ordering=last_updated) for CI/CD platforms:
  - Azure DevOps
  - GitHub Actions
  - GitLab
  - Terraform Cloud/Terraform Enterprise

## Quick Start

### Prerequisites

- Docker installed on your system
- Azure CLI (if running outside container)
- Access to an Azure subscription

### Running Rover

```bash
# Pull the latest rover image
docker pull aztfmod/rover:latest

# Run rover interactively
docker run -it --rm aztfmod/rover:latest

# Login to Azure
rover login

# Deploy a landing zone
rover -lz /tf/caf/landingzones/launchpad -a plan -launchpad
```

## Key Features

- **🚀 Enterprise-ready**: Production-tested Terraform patterns and best practices
- **🐳 Containerized**: Consistent development environment across all platforms  
- **🔄 CI/CD Ready**: Native integration with popular DevOps platforms
- **📊 State Management**: Automated Terraform state file handling on Azure Storage
- **🛡️ Security**: Built-in security scanning and policy enforcement
- **📚 Comprehensive**: Complete toolchain including Terraform, Azure CLI, and supporting tools

## Documentation

- 📖 **[Installation Guide](docs/INSTALLATION.md)** - Detailed setup instructions
- 🚀 **[Usage Guide](docs/USAGE.md)** - Command reference and examples  
- 🏗️ **[Architecture](docs/ARCHITECTURE.md)** - System design and components
- 🤝 **[Contributing](CONTRIBUTING.md)** - Developer guidelines and setup
- 🔒 **[Security](docs/SECURITY.md)** - Security best practices
- 🐛 **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- ❓ **[FAQ](docs/FAQ.md)** - Frequently asked questions

### Getting Started with CAF Terraform Landing Zones

For comprehensive documentation on Cloud Adoption Framework patterns:
:books: **[Visit our centralized documentation](https://aka.ms/caf/terraform)**

## Community

Feel free to open an issue for feature or bug, or to submit a PR.

In case you have any question, you can reach out to tf-landingzones at microsoft dot com.

You can also reach us on [Gitter](https://gitter.im/aztfmod/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

## Code of conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
