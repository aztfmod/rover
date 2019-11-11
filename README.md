## Introduction
The **Azure CAF rover** is a Docker container in charge of the deployment of the landing zones in your Azure environment. It is acting as a **sandbox toolchain** development environment to avoid impacting the local machine but more importantly to make sure that all contributors in the GitOps teams are using a **consistent set of tools** and version. 

The Azure CAF rover is the same container regarless you are using Windows, Linux or macOS. On the local GitOps machine you need to install Visual Studio Code. The Azure CAF rover is executed locally in a container.

![Azure_CAF_Rover_Container](https://code.visualstudio.com/assets/docs/remote/containers/architecture-containers.png)

You can learn more about the Visual Studio Code Remote on this [link](https://code.visualstudio.com/docs/remote/remote-overview).



## Pre-requisites
The Visual Studio Code system requirements describe the steps to follow to get your GitOps development environment ready -> [link](https://code.visualstudio.com/docs/remote/containers#_system-requirements)
* **Windows**: Docker Desktop 2.0+ on Windows 10 Pro/Enterprise in Linux Container mode
* **macOS**: Docker Desktop 2.0+
* **Linux**: Docker CE/EE 18.06+ and Docker Compose 1.24+

The Azure CAF rover is a Centos:7 base image and is hosted on the Docker Hub.
https://hub.docker.com/r/aztfmod/rover/tags?page=1

Install
* Visual Studio Code version 1.40+ - [link](https://code.visualstudio.com/Download)
* Install Visual Studio Code Extension - Remote Development - [link](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

## Create a GitHub respository based on the rover template

Go to the Azure CAF rover remote container template https://github.com/aztfmod/rover-remote-container

You install the Azure CAF rover by adding the following folder and files:

Click on the templace button:
![template](./images/template.png)

Set a name to the repository
![repository](./images/first.png)

Wait for the repository to be created
![wait](./images/wait.png)

Clone the repository using SSH - copy the url
![clone](./images/clone.png)

From a console execute the git clone command
![git_clone](./images/clone_local.png)

Open the cloned repository with Visual Studio Code
![code_open](./images/code_open.png)

Visual Studio Code opens
![vscode_opens](./images/vscode_opens.png)

| Note: the bottom left green button shows the Visual Studio Remote Development extension has been installed

Click on the button "Reopen in Container"
![reopen_container](./images/vscode_reopen_container.png)

While Visual Studio Code reopens your project and load the Azure CAF rover you will see the following icon
![vscode_opening](./images/vscode_opening_remote.png)

| Note: The first time it will take longer as the full docker image has to be downloaded.

When successfuly loaded you will see Visual Studio Code opened with the following look and feel
![vscode_opened](./images/vscode_opened.png)

It is recommeded you leverage the workspace in order to drive more consistancy across different operating systems
![vscode_container_ws](./images/vscode_container_ws.png)

## Login the rover to Azure
Open a new terminal from the menu Terminal..New Terminal

Run **Rover login**
![rover_login](./images/rover_login.png)

Note: If you have more than one subscription or Azure AD Tenant you can use the command: 
```bash
# Login to your Azure subscription
rover login [subscription_guid] [tenantname.onmicrosoft.com or tenant_guid]
# Verify the current Azure subscription
az account show
```

Authenticate with your credential
![authenticate](./images/rover_login1.png)

Note: Copy the code and open the device login to set your username and password

![logged](./images/rover_logged.png)

## Initialize the Level0 launchpad



## Deploy the Cloud Adoption Framework foundations landing zone: 
```bash
# Display the resources that are going to be deployed
rover /tf/landingzones/landingzone_caf_foundations plan

# Deploy the resources
rover /tf/landingzones/landingzone_caf_foundations apply

```


### Something you want, something not working?
Open an issue list to report any issues and missing features.

### Want to build or extend the landingzones or blueprints?

To load the rover with the local landing zones you need to prepare your environment with the level0 launchpad and landing zones 
```bash
# Go back to the base folder
# ~/git/github.com/aztfmod
baseFolder
cd rover

make setup_dev_githttp

# or use make setup_dev_gitssh if you have an ssh key mapped  to your github account

make local
```

> Everytime you update the local versions of the landing zones you need to re-execute the command 'make local' and then use the rover to deploy the modifications

> You can also refresh the git repositories with the latest version by calling 'make setup_dev_githttp' or 'make setup_dev_gitssh'

## Troubleshooting
### Error codes
Error code returned by the bash (echo $?)

| Code | Description | 
|--- |--- |
| 0 | Operation completed successfully 
|2 | Not connected to Azure subscription. You need to logout / login and set the default subscription 
|10 | Launchpad is installed but no landingzone and action arguments have been set 
|11 | Landingzone argument set without an action 
|12 | Landingzone folder does not exist in the rover 

### Purging Docker cache
You can purge Docker cache running the following command:
```bash
docker system prune -a
```

### Limitations

* You cannot run the rover from the Azure Cloud Shell (including the Windows Terminal Azure Cloud Shell) at the moment.

