#!/bin/bash

set -e
./scripts/pre_requisites.sh

# For make local it is required to run "make setup_dev_gitssh" or "make setup_dev_githttp"
if [ $1 == "local" ] || [ $1 == "private" ]; then
    pwd
    if [ -d "../level0" ]; then
        echo "development environment already setup"
    else
        echo "You need to run first 'make setup_dev_gitssh' or 'make setup_dev_githttp'. Check the README.md"
        exit 1
    fi
fi

echo "loading landingzones from $1"
echo ""


tag=$(date +"%g%m.%d%H")

# Build the rover base image
docker-compose build
docker tag rover_rover aztfmod/rover:$tag
docker tag rover_rover aztfmod/rover:latest

# build the rover
# docker push aztfmod/rover:$tag
# docker push aztfmod/rover:latest
