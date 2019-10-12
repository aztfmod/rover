#!/bin/bash

git_mode=$1

echo ""
echo "setup the development environment"
repos=$(curl https://api.github.com/orgs/aztfmod/repos)

function setup_folder {
    folder=$1
    if [ -d ${folder} ]; then
        echo "${folder} folder exists"
    else
        mkdir ${folder}
        echo "${folder} folder created"
    fi
}

function clone {
    folder=$1
    git_clone_mode=$2
    name=$3
    ssh_url=$4
    clone_url=$5
    
    if [ ! -z $name ]; then
        echo "cloning $name"
        # Check if the folder already exist
        if [ ! -d "${folder}${name}" ]; then
            echo "cloning ${name} into ${folder}${name}"

            if [ ${git_clone_mode} == "gitssh" ]; then
                git clone $ssh_url ${folder}${name}
            else
                git clone $clone_url ${folder}${name}
            fi
        else
            echo "already cloned"
        fi
    fi
}

# Cloning modules
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/terraform-azurerm-caf-")) | "\(.name) \(.ssh_url) \(.clone_url)"')

setup_folder "../modules"
echo ${repos_to_clone} | while read -d '" "' line; do
        clone "../modules/" ${git_mode} ${line}
done 

# Cloning landingzone_template
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/landingzone_template")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
        clone "../" ${git_mode} ${line}
done 

# Cloning landingzones
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/landingzones")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
        clone "../" ${git_mode} ${line}
done 

# Cloning level0
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/level0")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
        clone "../" ${git_mode} ${line}
done 
