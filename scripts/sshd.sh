#!/bin/bash
set -Eeo pipefail


echo "user ${USERNAME}"
echo "password ${SSH_PASSWD}"

# Generate unique ssh keys , if needed
if [ ! -f /home/vscode/.ssh/ssh_host_ecdsa_key ]; then
    ssh-keygen -t ecdsa -b 521 -f /home/vscode/.ssh/ssh_host_ecdsa_key -N ''
fi

echo "${USERNAME}:${SSH_PASSWD}" | sudo chpasswd

sudo /usr/sbin/sshd -f /home/vscode/.ssh/sshd_config -D -e