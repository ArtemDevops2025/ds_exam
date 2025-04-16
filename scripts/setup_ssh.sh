#!/bin/bash

mkdir -p ~/.ssh
echo "$SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/$SSH_KEY_NAME.pem
chmod 600 ~/.ssh/$SSH_KEY_NAME.pem
echo -e "Host \$MASTER_IP\n\tStrictHostKeyChecking no\n" > ~/.ssh/config