![](https://github.com/aztfmod/rover/workflows/master/badge.svg)
![](https://github.com/aztfmod/rover/workflows/.github/workflows/ci-branches.yml/badge.svg)
[![Gitter](https://badges.gitter.im/aztfmod/community.svg)](https://gitter.im/aztfmod/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

# Cloud Adoption Framework for Azure - Landing zones on Terraform - Rover

Microsoft Cloud Adoption Framework for Azure provides you with guidance and best practices to adopt Azure.

The CAF **rover** is helping you managing your enterprise Terraform deployments on Microsoft Azure and is composed of two parts:

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
- [Adding runner (agent) for the following platforms](https://hub.docker.com/r/aztfmod/rover-agent/tags?page=1&ordering=last_updated)
  - Azure DevOps
  - GitHub Actions
  - Gitlab
  - Terraform Cloud/Terraform Enterprise

### Getting starter with CAF Terraform landing zones

Get your Cloud Adoption Framework Terraform landing zones project starter here:  [caf-terraform-landingzones-starter](https://github.com/azure/caf-terraform-landingzones-starter)


[![asciicast](https://asciinema.org/a/413478.svg)](https://asciinema.org/a/413478)

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
