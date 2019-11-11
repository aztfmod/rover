## Introduction
The rover is a Docker container in charge of the deployment of the landing zones in your Azure environment.

You have to load the rover with some landing zones to be able to deploy them.

The rover load the landing zones from Github or directly from your local folder if you are building/modifying a new one on your local machine. Start loading the rover with the Github landing zones as it will be the quickest way to start.

When fully loaded the rover will deploy the landing zones from the launchpad you have installed. 

## Pre-requisites
* To use the rover you need to have Docker engine running on your local machine
* For Windows users make sure Docker is running in Linux mode.
* Visual Studio Code
* Azure CLI must be installed on your local machine and connected to the default subscription you want to deploy the landingzones
* jq must be installed if you plan to clone a local copy of the landingzone factory
* git must be installed if you plan to clone local copy of the landing zones

> For a better experience on Windows 10 we recommended using:
>- Windows Subsystem for Linux v2 (https://docs.microsoft.com/en-us/windows/wsl/wsl2-install)
>- Chose Ubuntu 18.04 LTS 
>- Docker Technical Preview for WSL2 (https://docs.docker.com/docker-for-windows/wsl-tech-preview/)
>- (Optional) Visual Studio Code insider build 

## Install the Azure CAF Rover on your local machine

To install the rover you must have git already installed

```bash
wget -O - --no-cache https://raw.githubusercontent.com/aztfmod/rover/master/install.sh | bash
```


## Load the rover with landing zones

### Load the rover with the latest public landing zones

Execute the following command from the local shell. Make sure docker engine is running.

For Linux, MacOS or Windows WSL / WSL2
```bash
make
```
Go to the next section to install the launchpad


## Install the launchpad
A launchpad is required by the rover to coordinate the initial and sub-sequent deployments of the landing  zones.

At the moment the public launchpad is using Terraform open source edition.

To initialize the launchpad execute the following commands.

```bash
# go to the rover subfolder
# Login to your Azure subscription
rover login [subscription_guid] [tenantname.onmicrosoft.com or tenant_guid]
# Verify the current Azure subscription
az account show
# If your are not using the default subscription, specify it using az account set --subscription <put your subscription GUID>
# Install the launchpad
rover
```
> The initial installation of the launchpad take between 5 to 10 minutes and incurs minimal costs.

If you re-execute the rover.sh with no parameters it will display the coordinates of the launchpad and the landing zones that are available for deployment:

![install_launchpad](/images/install_launchpad.png)

## Deploy the Cloud Adoption Framework foundations landing zone: 
```bash
# Display the resources that are going to be deployed
rover landingzones/landingzone_caf_foundations plan

# Deploy the resources
rover landingzones/landingzone_caf_foundations apply

```

## Deploy the virtual datacenter level1
```bash
# Display the resources that are going to be deployed
rover landingzones/landingzone_vdc_level1 plan

# Deploy the resources
rover landingzones/landingzone_vdc_level1 apply

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
* You cannot run the rover from Powershell on Windows
