#!/bin/bash

git_mode=$1

echo ""
echo "setup the development environment"

set -e
repos=$(curl https://api.github.com/orgs/aztfmod/repos)

setup_folder () {
    folder=$1
    if [ -d ${folder} ]; then
        echo "${folder} folder exists"
    else
        mkdir ${folder}
        echo "${folder} folder created"
    fi
}

clone () {

    name=$1
    ssh_url=$2
    clone_url=$3
    folder=$4
    git_clone_mode=$5

    echo ""
    echo "-----------------------------------------------"
    echo "name:            '${name}'"
    echo "ssh_url:         '${ssh_url}'"
    echo "clone_url:       '${clone_url}'"
    echo "folder:          '${folder}'"
    echo "git_clone_mode:  '${git_clone_mode}'"
    
    if [ ! -z $name ]; then
        echo "cloning $name"
        # Check if the folder already exist
        if [ ! -d "${folder}${name}" ]; then
            echo "cloning with ${git_clone_mode} - ${name} into ${folder}${name}"

            if [ ${git_clone_mode} == "gitssh" ]; then
                git clone $ssh_url ${folder}${name}
            else
                git clone $clone_url ${folder}${name}
            fi
        else
            echo "already cloned with ${git_clone_mode}"
        fi
    fi
}

# Cloning modules
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/terraform-azurerm-caf-")) | "\(.name) \(.ssh_url) \(.clone_url)"')

setup_folder "../modules"
echo ${repos_to_clone} | while read -d '" "' line; do
    if [ ! -z "${line}" ]; then
        clone ${line} "../modules/" ${git_mode}
    fi
done 

# Cloning landingzone_template
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/landingzone_template")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
    if [ ! -z "${line}" ]; then
        clone ${line} "../" ${git_mode}
    fi
done 

# Cloning landingzones
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/landingzones")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
    if [ ! -z "${line}" ]; then
        clone ${line} "../" ${git_mode}
    fi
done 

# Cloning level0
repos_to_clone=$(echo $repos | jq '.[] | select(.full_name | contains("aztfmod/level0")) | "\(.name) \(.ssh_url) \(.clone_url)"')

echo ${repos_to_clone} | while read -d '" "' line; do
    if [ ! -z "${line}" ]; then
        clone ${line} "../" ${git_mode}
    fi
done 
