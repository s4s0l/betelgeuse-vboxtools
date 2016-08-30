#!/bin/bash
set -e
. $(dirname $0)/lib/init.sh

if [ -z ${1} ]; then
    echo "Usage $0 GROUP_NUMBER"
    exit 1
fi



ALL_MACHINES=$(get-vms-in-group-ext ${1} all)

# convert to array because ssh consumes input and while read stops after 1st iteration,
# so i don't know how to loop only once
MACHINES=()
while read -r line; do
   MACHINES+=($line)
done <<< "$ALL_MACHINES"



for MACHINE in "${MACHINES[@]}"; do
    start-and-wait-for-it ${MACHINE}

done


