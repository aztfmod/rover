#!/bin/bash
set -Eeo pipefail

# Generate unique ssh keys , if needed
if [ ! -f /home/vscode/.ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -b 4096 -f /home/vscode/.ssh/ssh_host_rsa_key -N ''
fi

sudo /usr/sbin/sshd -f /home/vscode/.ssh/sshd_config -D -e