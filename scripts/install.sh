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

cp ./.dockerignore ../

# Build the rover base image
docker build $(./scripts/buildargs.sh ./version.cat) -t caf_rover_base \
    -f ./docker/base.Dockerfile ../

# build the rover
docker build -t caf_rover \
    -f ./docker/$1.Dockerfile ../


echo ""
echo "rover loaded with github landingzones"
echo "execute:"
echo "rover"