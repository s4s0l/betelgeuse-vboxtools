#!/bin/bash
. $(dirname $0)/lib/init.sh



if [[ ( -z ${1} ) ]]; then
    echo "Usage: create-machine GROUP_NUMBER"
    exit 1
fi

GROUP_NUMBER=$1
validate-positive-int ${GROUP_NUMBER} "GROUP_NUMBER"

MACHINE_NUMBER=1

ALL_IN_GROUP=$( get-vms-in-group /Group_${GROUP_NUMBER} )
if [[ -z ${ALL_IN_GROUP} ]]; then
    echo "** group does not exist will be created, Machine number will be 1"
    MACHINE_NUMBER=1
    create-host-only-network ${GROUP_NUMBER}
else
    ALL_IN_GROUP=$( echo "$ALL_IN_GROUP" | sort -n -t _ -k 3 | tail -n1 | cut -d_ -f3 )
    MACHINE_NUMBER=$(($ALL_IN_GROUP+1))
    echo "** group already exists, New machine number will be ${MACHINE_NUMBER}"
fi


MACHINE_NAME="${GROUP_NUMBER}_Machine_${MACHINE_NUMBER}"

create-default-machine ${MACHINE_NAME} ${GROUP_NUMBER}


IS_RUNNING=$( VBoxManage list runningvms | grep ${TEMPLATE_NAME} || true)
if [[ ! -z "${IS_RUNNING}" ]]; then
    VBoxManage controlvm "${TEMPLATE_NAME}" poweroff
fi

clone-hd ${DISC_LOCATION}/${TEMPLATE_NAME} ${DISC_LOCATION}/${MACHINE_NAME}
attach-hd ${MACHINE_NAME} ${DISC_LOCATION}/${MACHINE_NAME}



start-and-wait-for-it ${MACHINE_NAME}



IP_ADDRESS=$(get-ip ${MACHINE_NAME})
echo "** Temporary ip address for new machine is ${IP_ADDRESS}"




sudo-script ${TEMPLATE_USERNAME} ${IP_ADDRESS} ${DIR}/lib/machine_host_name.guestsh ${MACHINE_NAME}
sudo-script ${TEMPLATE_USERNAME} ${IP_ADDRESS} ${DIR}/lib/machine_set_static_ip.guestsh "10.10.${GROUP_NUMBER}.${MACHINE_NUMBER} 255.255.255.0 10.10.${GROUP_NUMBER}.254"
#ssh -oStrictHostKeyChecking=no ${TEMPLATE_USERNAME}@${IP_ADDRESS} sudo reboot || true
VBoxManage controlvm ${MACHINE_NAME} poweroff
start-and-wait-for-it ${MACHINE_NAME}

echo "** Machine ${MACHINE_NAME} created successfully in group ${GROUP_NUMBER}, IP: 10.10.${GROUP_NUMBER}.${MACHINE_NUMBER}"