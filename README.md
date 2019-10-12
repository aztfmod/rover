## Introduction
The rover is a docker container in charge of the deployment of the landing zones in your Azure environment.

You have to load the rover with some landingzones to be able to deploy them.

The rover load the landingzones from github or directly from your local folder if you are building/modifying a new one on your local machine. Start loading the rover with the github landingzones as it will be the quickest way to start.

When fully loaded the rover will deploy the landingzones from the launchpad you have installed. 

## Pre-requisites
* To use the rover you need to have docker engine running on your local machine
* For Windows users make sure docker is running in Linux mode
* Visual Studio Code
* Azure cli must be installed on your local machine and connected to the default subscription you want to deploy the landingzones

> For a better experience on Windows 10 it is recommended using the wsl2 and the Visual Studio Code insider build

## Create a base folder to host the rover

```bash
folder="~/git/github.com/aztfmod"
alias baseFolder="cd ~/git/github.com/aztfmod"
mkdir -p ${folder}
baseFolder
```

## Clone the rover

You have to clone the git repository first on your local machine.

```bash
git clone https://github.com/aztfmod/rover.git
```

## Load the rover with landingzones

### Load the rover with the latest public landingzones

Execute the following command from the local shell. Make sure docker engine is running.

For Linux, macos or Windows wsl / wsl2
```bash
make
```
Go to the next section to install the launchpad

### Load the rover with your local landingzones

To load the rover with the local landingzones you need to prepare your environment with the level0 launchpad and landingzones 
```bash
# Go back to the base folder
# ~/git/github.com/aztfmod
baseFolder

# Clone the level0 launchpads
git clone https://github.com/aztfmod/level0.git

# Clone the public landingzones
git clone https://github.com/aztfmod/landingzones.git

# Go to the rover folder and load the rover with the local copies
cd rover
make local
```

> Everytime you update the local versions of the landingzones you need to re-execute the command 'make local' and then use the rover to deploy the modifications

## Install the launchpad
A launchpad is required by the rover to coordinate the initial and sub-sequent deployments of the landingzones.

At the moment the public launchpad is using Terraform open source edition.

To initialize the launchpad execute the following commands.

```bash
# go to the rover subfolder
# Verify the current Azure subscription
az account show

# Install the launchpad
./rover.sh
```
> The initial installation of the launchpad take between 5 to 10 minutes and occurs small costs.

If you re-execute the rover.sh with no parameters it will display the coordinates of the launchpad and the landingzones that can be deployed

![install_launchpad](/images/install_launchpad.png)

## Deploy the virtual datacenter level1
```bash
# Display the resources that are going to be deployed
./rover.sh landingzones/landingzone_vdc_level1 plan

# Deploy the resources
./rover.sh landingzones/landingzone_vdc_level1 apply

```

### Something you want, something not working?
Open an issue list to report any issues and missing features.

### Error codes
Error code returned by the bash (echo $?)
Code | Description 
--- | ---
 0 | Operation completed successfully 
2 | Not connected to Azure subscription. You need to logout / login and set the default subscription
10 | Launchpad is installed but no landingzone and action arguments have been set
11 | Landingzone argument set without an action
12 | Landingzone folder does not exist in the rover

### Limitations

* You cannot run the rover from the Azure cloud shell at the moment.
* You cannot run the rover from Powershell on Windows