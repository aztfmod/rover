#!/bin/bash

docker run -it -v ${HOME}/.azure:/root/.azure -v ${HOME}/.terraform.d:/root/.terraform.d rover $@