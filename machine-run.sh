#!/bin/bash
SILENT_MODE=true
. $(dirname $0)/lib/init.sh

if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
    echo "Usage: machine-run MACHINE_NAME COMMAND ARGS..."
    exit 1
fi

MACHINE_NAME=$1
PATH_TO_SCRIPT=$2
ARGS=$3

IP_ADDRESS=$(get-ip ${MACHINE_NAME})
ssh -oStrictHostKeyChecking=no ${TEMPLATE_USERNAME}@${IP_ADDRESS} sudo ${*:2}


