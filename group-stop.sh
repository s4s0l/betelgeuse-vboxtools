#!/bin/bash
set -e
DIR=$(dirname $0)

if [ -z ${1} ]; then
    echo "Usage $0 GROUP_NUMBER"
    exit 1
fi

${DIR}/group-manage.sh $1 all controlvm _M_ acpipowerbutton