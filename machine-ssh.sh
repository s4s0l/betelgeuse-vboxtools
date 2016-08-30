#!/bin/bash
. $(dirname $0)/lib/init.sh

if [ -z ${1} ]; then
    echo "Usage $0 MACHINE_NAME"
    exit 1
fi

TEMPLATE_USERNAME=guestadmin
IP_ADDRESS=$(get-ip $1)
ssh -t ${TEMPLATE_USERNAME}@${IP_ADDRESS}