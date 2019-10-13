#!/bin/bash

set -e
./scripts/pre_requisites.sh

echo "loading landingzones from $1"
echo ""

docker build $(./scripts/buildargs.sh ./version.cat) -t caf_rover \
    -f ./docker/$1.Dockerfile ../

echo ""
echo "rover loaded with github landingzones"
echo "run ./rover.sh"