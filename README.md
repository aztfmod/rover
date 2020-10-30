![](https://github.com/aztfmod/rover/workflows/master/badge.svg)
![](https://github.com/aztfmod/rover/workflows/.github/workflows/ci-branches.yml/badge.svg)
[![VScodespaces](https://img.shields.io/endpoint?url=https%3A%2F%2Faka.ms%2Fvso-badge)](https://online.visualstudio.com/environments/new?name=rover=aztfmod/rover)
[![Gitter](https://badges.gitter.im/aztfmod/community.svg)](https://gitter.im/aztfmod/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

# Cloud Adoption Framework for Azure - Landing zones on Terraform - Rover

Microsoft Cloud Adoption Framework for Azure provides you with guidance and best practices to adopt Azure.

The **Azure CAF rover** is a Docker container in charge of the deployment of the landing zones in your Azure environment. 

It is acting as a **sandbox toolchain** development environment to avoid impacting the local machine but more importantly to make sure that all contributors in the GitOps teams are using a **consistent set of tools** and version.

The Azure CAF rover is the same container regardless you are using Windows, Linux or macOS. On the local GitOps machine you need to install Visual Studio Code. The Azure CAF rover is executed locally in a container.

<img src="https://code.visualstudio.com/assets/docs/remote/containers/architecture-containers.png" width="75%">

You can learn more about the Visual Studio Code Remote on this [link](https://code.visualstudio.com/docs/remote/remote-overview).

## Pre-requisites

The Visual Studio Code system requirements describe the steps to follow to get your GitOps development environment ready -> [link](https://code.visualstudio.com/docs/remote/containers#_system-requirements)

* **Windows**: Docker Desktop 2.0+ on Windows 10 Pro/Enterprise with Linux Container mode
* **macOS**: Docker Desktop 2.0+
* **Linux**: Docker CE/EE 18.06+ and Docker Compose 1.24+

The Azure CAF rover is a Centos:7 base image and is hosted on the Docker Hub.
https://hub.docker.com/r/aztfmod/rover/tags?page=1&ordering=last_updated

Install
* Visual Studio Code version 1.41+ - [link](https://code.visualstudio.com/Download)
* Install Visual Studio Code Extension - Remote Development - [link](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

## Repositories

| Repo                                                                                              | Description                                                |
|---------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| [caf-terraform-landingzones](https://github.com/azure/caf-terraform-landingzones)                 | landing zones repo with sample and core documentations     |
| [rover](https://github.com/aztfmod/rover) (You are here!)                                         | devops toolset for operating landing zones                 |
| [azure_caf_provider](https://github.com/aztfmod/terraform-provider-azurecaf)                      | custom provider for naming conventions                     |
| [modules](https://registry.terraform.io/modules/aztfmod)                                          | set of curated modules available in the Terraform registry |

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
