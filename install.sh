#!/bin/bash

if [ ! -z "${AZURE_HTTP_USER_AGENT+x}" ]; then
    echo "The Azure CAF Rover is not yet supported from the Azure Cloud Shell [coming soon]"
fi

res=$(which git)
if [ ! $? == 0 ]; then
    >&2 echo -e "You must install git to install the Azure CAF rover"
    exit 1
fi

# Create the base folder structure
folder="${HOME}/git/github.com/aztfmod"
mkdir -p ${folder}
cd git && cd github.com && cd aztfmod


# Clone the rover
git clone https://github.com/aztfmod/rover.git
cd rover

# check the pre-requisites
./scripts/pre_requisites.sh

alias rover=$(pwd)/rover.sh

echo ""
echo "The Azure CAF Rover has been installed sucessfully."
echo ""
echo "As a next steps you need to do:"
echo " - build the rover with the public landingzones (just type 'make')"
echo " - login to the Azure subscription 'rover login [optional_subscription_id] [optional_tenantname.onmicrosoft.com_or_tenantguid]'"
echo " - initialise the launchpad by running 'rover'"
echo " - your are now set to deploy your landingzones. Refer to the readme for more details on those steps"
echo ""


