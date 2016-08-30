#!/bin/bash
SILENT_MODE=true
. $(dirname $0)/lib/init.sh

if [[ ( -z ${1} ) || ( -z ${2} ) || ( -z ${3} ) ]]; then
    echo "Usage: group-run GROUP_NUMBER MACHINE_INDICATOR COMMAND ARGS..."
    echo "Where MACHINE_INDICATOR can be 'all' (all machines) or comma separated list of machine numbers"
    echo "In Command andargs _M_ will be substituted for machine name, _I_ for IP, _N_ for machine number"
    exit 1
fi

GROUP_NUMBER=$1
MACHINE_INDICATOR=$2
ALL_MACHINES=$(get-vms-in-group-ext ${GROUP_NUMBER} ${MACHINE_INDICATOR})

# convert to array because ssh consumes input and while read stops after 1st iteration,
# so i don't know how to loop only once
MACHINES=()
while read -r line; do
   MACHINES+=($line)
done <<< "$ALL_MACHINES"



for MACHINE in "${MACHINES[@]}"; do
    echo "==${MACHINE}=="
    VBOXCOMMANDS=${*:3}
    VBOXCOMMANDS=${VBOXCOMMANDS//_M_/${MACHINE}}
    VBOXCOMMANDS=${VBOXCOMMANDS//_I_/$(get-ip ${MACHINE})}
    MACHINE_NUMBER=$(echo ${MACHINE} | grep -o "[0-9]\+\$")
    VBOXCOMMANDS=${VBOXCOMMANDS//_N_/${MACHINE_NUMBER}}
    ${DIR}/machine-run.sh ${MACHINE} ${VBOXCOMMANDS}
done





