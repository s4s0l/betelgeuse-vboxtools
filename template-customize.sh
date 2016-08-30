#!/bin/bash
. $(dirname $0)/lib/init.sh

echo "** Detecting ip address of Template VM ${TEMPLATE_NAME}."
IP_ADDRESS=$(get-ip ${TEMPLATE_NAME})
echo "** Detected ip address of Template VM as ${IP_ADDRESS}."
echo "** Setting up ssh keys for guest machine"
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "** No id_rsa.pub will generate one";
    ssh-keygen -t rsa -b 2048
fi

GUEST_MACHINE=${TEMPLATE_USERNAME}@${IP_ADDRESS}

echo "** Copying keys, you will be asked for password for user $TEMPLATE_USERNAME in guest system if keys where not already properly copied..."
ssh-copy-id ${GUEST_MACHINE}

echo "** Making sudo not ask for password [to make automation more friendly]"

sudo-script ${TEMPLATE_USERNAME} ${IP_ADDRESS} ${DIR}/lib/template_sudo_nopasswd.guestsh

echo "** Making ubuntu get IP address in host-only network"

sudo-script ${TEMPLATE_USERNAME} ${IP_ADDRESS} ${DIR}/lib/template_add_second_interface.guestsh

ssh -oStrictHostKeyChecking=no ${GUEST_MACHINE} sudo reboot