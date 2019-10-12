#!/bin/bash

echo ""
echo "setup the development environment"

if [ -d ../modules ]; then
    echo "modules folder exists"
else
    mkdir ../modules
    echo "modules folder created"
fi

repos=$(curl https://api.github.com/orgs/aztfmod/repos)

repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/terraform-azurerm-caf-")) | "\(.name) \(.ssh_url) \(.clone_url)"')

function clone_ssh {
    name=$1
    ssh_url=$2
    clone_url=$3
    
    if [ ! -z $name ]; then
        echo "cloning $name"
        # Check if the folder already exist
        if [ ! -d "../modules/${name}" ]; then
            echo "cloning ${name} into ../modules/${name}"
            git clone $ssh_url ../modules/${name}
        else
            echo "already cloned"
        fi
    fi
}

echo ${repos_to_clone} | while read -d '" "' line; do
    clone_ssh ${line}
done 



