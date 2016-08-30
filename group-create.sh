#!/bin/bash
. $(dirname $0)/lib/init.sh

if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
    echo "Usage: group-create GROUP_NUMBER NUMBER_OF_HOSTS"
    exit 1
fi

GROUP_NUMBER=$1
NUMBER_OF_HOSTS=$2

validate-positive-int ${GROUP_NUMBER} "GROUP_NUMBER"
validate-positive-int ${NUMBER_OF_HOSTS} "NUMBER_OF_HOSTS"

HOSTS_TO_CREATE=0


ALL_IN_GROUP=$( get-vms-in-group /Group_${GROUP_NUMBER} )
if [[ -z ${ALL_IN_GROUP} ]]; then
    HOSTS_TO_CREATE=${NUMBER_OF_HOSTS}
else
    ALL_IN_GROUP=$( echo "$ALL_IN_GROUP" | wc -l )
    HOSTS_TO_CREATE=$(($NUMBER_OF_HOSTS - $ALL_IN_GROUP))
    if [ "${HOSTS_TO_CREATE}" -le "0" ]; then
        echo "** Group already contains $ALL_IN_GROUP, no machines will be created"
        exit 1
    fi
    echo "** group already exists, it has ${ALL_IN_GROUP} machines so ${HOSTS_TO_CREATE} will be created"
fi


for i in $(seq 1 ${HOSTS_TO_CREATE}); do
    ${DIR}/machine-create.sh ${GROUP_NUMBER}
done