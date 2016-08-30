#!/bin/bash
. $(dirname $0)/lib/init.sh

if [[ ( -z ${1} ) ]]; then
    echo "Usage: delete-group GROUP_NUMBER"
    exit 1
fi

GROUP_NUMBER=$1

remove-group ${GROUP_NUMBER}

