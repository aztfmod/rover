#!/bin/sh
config_path=$1
env -i GITHUB_WORKSPACE=$GITHUB_WORKSPACE /bin/bash -c "set -a && source ${config_path} && printenv" > /tmp/env_vars
while read -r env_var
do
    echo "$env_var" >> $GITHUB_ENV
done < /tmp/env_vars