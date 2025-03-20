![](https://github.com/aztfmod/rover/workflows/master/badge.svg)
![](https://github.com/aztfmod/rover/workflows/roverlight-build/badge.svg)
![](https://github.com/aztfmod/rover/workflows/roverlight-security-scan/badge.svg)
[![Gitter](https://badges.gitter.im/aztfmod/community.svg)](https://gitter.im/aztfmod/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

# Azure Terraform SRE - Landing zones on Terraform - Rover

> :warning: This solution, offered by the Open-Source community, will no longer receive contributions from Microsoft. Customers are encouraged to transition to [Microsoft Azure Verified Modules](https://aka.ms/avm) for Microsoft support and updates.

Azure Terraform SRE provides you with guidance and best practices to adopt Azure.

The CAF **rover** is helping you managing your enterprise Terraform deployments on Microsoft Azure and is composed of two parts:

- **A docker container** (available in standard and light variants)
  - Standard: Full featured development environment with all tools
  - Light: Streamlined version focused on essential functionality
  - Both variants available on GitHub Container Registry
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
- [Adding runner (agent) for the following platforms](https://hub.docker.com/r/aztfmod/rover-agent/tags?page=1&ordering=last_updated)
  - Azure DevOps
  - GitHub Actions
  - Gitlab
  - Terraform Cloud/Terraform Enterprise

### Getting starter with CAF Terraform landing zones

If you are reading this, you are probably interested also in reading the doc as below:
:books: Read our [centralized documentation page](https://aka.ms/caf/terraform)

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
