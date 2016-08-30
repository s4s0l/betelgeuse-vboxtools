#!/bin/bash
. $(dirname $0)/lib/init.sh





VDI_NAME=${DISC_LOCATION}/${TEMPLATE_NAME}


create-host-only-network 0
create-default-machine ${TEMPLATE_NAME} 0
create-hd  ${VDI_NAME} 8000
attach-hd ${TEMPLATE_NAME} ${VDI_NAME}

mkdir -p ${ISO_LOCAL_LOCATION}
if [ ! -f ${ISO_LOCAL_LOCATION}/${ISO_NAME} ]; then
    wget -O ${ISO_LOCAL_LOCATION}/${ISO_NAME} ${ISO_REMOTE_LOCATION}
fi

attach-iso ${TEMPLATE_NAME} ${ISO_LOCAL_LOCATION}/${ISO_NAME}


VBoxManage startvm ${TEMPLATE_NAME}

cat ${DIR}/lib/after-template-install.txt

