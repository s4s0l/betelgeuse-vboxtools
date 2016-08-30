#!/bin/bash
SILENT_MODE=true
. $(dirname $0)/lib/init.sh

if [[ ( -z ${1} ) || ( -z ${2} ) || ( -z ${3} ) ]]; then
    echo "Usage: group-exec GROUP_NUMBER MACHINE_INDICATOR PATH_TO_SCRIPT ARGS..."
    echo "Where MACHINE_INDICATOR can be 'all' (all machines) or comma separated list of machine numbers"
    exit 1
fi

GROUP_NUMBER=$1
MACHINE_INDICATOR=$2
PATH_TO_SCRIPT=$3
ALL_MACHINES=$(get-vms-in-group-ext ${GROUP_NUMBER} ${MACHINE_INDICATOR})

# convert to array because ssh consumes input and while read stops after 1st iteration,
# so i don't know how to loop only once
MACHINES=()
while read -r line; do
   MACHINES+=($line)
done <<< "$ALL_MACHINES"



for MACHINE in "${MACHINES[@]}"; do
    echo "==${MACHINE}=="
    VBOXCOMMANDS=${*:4}
    VBOXCOMMANDS=${VBOXCOMMANDS//_M_/${MACHINE}}
    VBOXCOMMANDS=${VBOXCOMMANDS//_I_/$(get-ip ${MACHINE})}
    MACHINE_NUMBER=$(echo ${MACHINE} | grep -o "[0-9]\+\$")
    VBOXCOMMANDS=${VBOXCOMMANDS//_N_/${MACHINE_NUMBER}}
    ${DIR}/machine-exec.sh ${MACHINE} ${PATH_TO_SCRIPT} ${VBOXCOMMANDS}
done





