#!/bin/bash

docker run -it --rm -v ${HOME}/.azure:/root/.azure -v ${HOME}/.terraform.d:/root/.terraform.d caf_rover $@