#!/bin/bash

set -e
./scripts/pre_requisites.sh

tag=$(date +"%g%m.%d%H")

echo "Creating version ${tag}"

# Build the rover base image
docker-compose build

docker tag rover_rover aztfmod/rover:$tag
docker tag rover_rover aztfmod/rover:latest

docker push aztfmod/rover:$tag
docker push aztfmod/rover:latest

# tag the git branch and push
git tag $tag master
git push --follow-tags