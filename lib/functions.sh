#!/usr/bin/env bash
set -e
DIR=$(dirname $0)

function echoerr() { cat <<< "ERROR: $@" 1>&2; }

function echolog() {
    if [ -z ${SILENT_MODE} ]; then
        cat <<< "** $@" 1>&1;
    fi
}

function get-ip(){
    if [ -z ${1} ]; then
        echo "Usage get-ip(TEMPLATE_NAME)"
        exit 1
    fi
    [[ $(VBoxManage guestproperty enumerate ${1} | grep /Net/1/V4/IP) =~ (value: ([0-9.]+),) || true ]];
    IP_ADDRESS=${BASH_REMATCH[2]};
    if [ -z ${IP_ADDRESS} ]; then
        echo "Unable to detect ip address of machine ${1}!"
        exit 1
    fi
    echo ${IP_ADDRESS}
    return 0
}

function sudo-script() {
    if [[ ( -z ${1} ) || ( -z ${2} ) || ( -z ${3} ) ]]; then
            echo "Usage run-command REMOTE_USERNAME IP_ADDRESS SCRIPT_FILE ARGS}"
            exit 1
    fi
    TEMPLATE_USERNAME=$1
    IP_ADDRESS=$2
    SCRIPT_FILE=$3
    ARGS=$4
    GUEST_MACHINE=${TEMPLATE_USERNAME}@${IP_ADDRESS}
    SCRIPT_NAME=$(basename "$SCRIPT_FILE")
    ssh -oStrictHostKeyChecking=no ${GUEST_MACHINE} mkdir -p /home/${TEMPLATE_USERNAME}/.guest_scripts
    scp -oStrictHostKeyChecking=no ${SCRIPT_FILE} ${GUEST_MACHINE}:/home/${TEMPLATE_USERNAME}/.guest_scripts/${SCRIPT_NAME} 1>/dev/null
    ssh -oStrictHostKeyChecking=no -q -t ${GUEST_MACHINE} "chmod +x /home/${TEMPLATE_USERNAME}/.guest_scripts/${SCRIPT_NAME} ; sudo /home/${TEMPLATE_USERNAME}/.guest_scripts/${SCRIPT_NAME} ${ARGS}"
}


function create-default-machine(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
        echo "Usage create-default-machine MACHINE_NAME HOST_ONLY_NETWORK_NUMBER"
        exit 1
    fi
    MACHINE_NAME=$1
    HOST_ONLY_NETWORK_NUMBER=$2

    VBoxManage createvm \
        --name ${MACHINE_NAME} \
        --register

    VBoxManage modifyvm ${MACHINE_NAME} \
        --ostype Ubuntu_64 \
        --groups "/Group_${HOST_ONLY_NETWORK_NUMBER}" \
        --memory 512 \
        --acpi on \
        --ioapic on \
        --bioslogofadein off \
        --bioslogofadeout off \
        --rtcuseutc on \
        --hwvirtex on \
        --cpus 1 \
        --bioslogodisplaytime 0 \
        --vram 12 \
        --nic1 nat \
        --nictype1 82540EM \
        --nic2 hostonly \
        --nictype2 82540EM \
        --hostonlyadapter2 vboxnet${HOST_ONLY_NETWORK_NUMBER}

    VBoxManage storagectl ${MACHINE_NAME} \
        --name "IDE 1" \
        --add ide \
        --controller PIIX4 \
        --hostiocache on

    VBoxManage storagectl ${MACHINE_NAME} \
        --name "SATA 1" \
        --add sata \
        --controller IntelAHCI \
        --hostiocache on \
        --portcount 1

}

function create-hd(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
            echo "Usage: create-hd PATH SIZE"
            exit 1
    fi
    HD_PATH=$1
    HD_SIZE=$2
    VBoxManage createhd \
        --filename ${HD_PATH} \
        --size ${HD_SIZE} \
        --format VDI \
        --variant Standard
}

function clone-hd(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
            echo "Usage: clone-hd FROM TO"
            exit 1
    fi
    HD_FROM=$1
    HD_TO=$2
    VBoxManage clonemedium  disk ${HD_FROM}.vdi ${HD_TO}.vdi \
        --format VDI \
        --variant Standard
}


function attach-hd(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
            echo "Usage: attach-hd MACHINE_NAME HD_PATH"
            exit 1
    fi
    MACHINE_NAME=$1
    HD_PATH=$2
    VBoxManage storageattach ${MACHINE_NAME} \
        --storagectl "SATA 1" \
        --type hdd \
        --port 0 \
        --device 0 \
        --medium ${HD_PATH}.vdi
}

function attach-iso(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
            echo "Usage: attach-iso MACHINE_NAME ISO_PATH"
            exit 1
    fi
    MACHINE_NAME=$1
    ISO_PATH=$2
    VBoxManage storageattach ${MACHINE_NAME} \
        --storagectl "IDE 1" \
        --type dvddrive \
        --port 0 \
        --device 0 \
        --medium ${ISO_PATH}
}

function create-host-only-network(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: create-host-only-network NETWORK_NUMBER"
            exit 1
    fi
    NETWORK_NUMBER=$1
    if [ "${NETWORK_NUMBER}" -ge 10 ]; then
        echo "Host only IF number too high"
        exit 1;
    fi

    for i in $(seq 0 ${NETWORK_NUMBER}); do
        EXIST=$(VBoxManage list hostonlyifs | grep -E "Name:\s+vboxnet${i}" || true)
        if [[ -z ${EXIST} ]]; then
            echolog "Host only interface ${i} does not exist, will need to create one"
            VBoxManage hostonlyif create
        fi
    done

    VBoxManage hostonlyif ipconfig vboxnet${NETWORK_NUMBER} --ip 10.10.${NETWORK_NUMBER}.254 --netmask 255.255.255.0
    add-dhcp-for-network ${NETWORK_NUMBER}


}


function add-dhcp-for-network(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: add-dhcp-for-network NETWORK_NUMBER"
            exit 1
    fi
    NETWORK_NUMBER=$1
    EXISTS=$( VBoxManage list dhcpservers | grep HostInterfaceNetworking-vboxnet${NETWORK_NUMBER} || true)
    if [[ -z ${EXISTS} ]]; then
        echolog "Creating dhcp server HostInterfaceNetworking-vboxnet${NETWORK_NUMBER} configuration.."
        VBoxManage dhcpserver add --ifname vboxnet${NETWORK_NUMBER} \
                --ip 10.10.${NETWORK_NUMBER}.253 \
                --netmask 255.255.255.0 \
                --lowerip 10.10.${NETWORK_NUMBER}.100 \
                --upperip 10.10.${NETWORK_NUMBER}.150 \
                --enable
    else
        echolog "Modifying dhcp server HostInterfaceNetworking-vboxnet${NETWORK_NUMBER} configuration.."
        VBoxManage dhcpserver modify --ifname vboxnet${NETWORK_NUMBER} \
                --ip 10.10.${NETWORK_NUMBER}.253 \
                --netmask 255.255.255.0 \
                --lowerip 10.10.${NETWORK_NUMBER}.100 \
                --upperip 10.0.${NETWORK_NUMBER}.252 \
                --enable
    fi

}


function remove-all-host-only-network(){
    VBoxManage list hostonlyifs | grep -E "Name:\s+vboxnet[0-9]+" | grep -oE "vboxnet[0-9]+" | while read x; do
        echolog "Deleting interface $x"
        VBoxManage hostonlyif remove $x
    done
}

function remove-all-dhcp-servers(){
    VBoxManage list dhcpservers | grep NetworkName: | grep -oE "[-A-Za-z]*vboxnet[0-9]+"| while read x; do
        echolog "Deleting dhcpserver $x"
        VBoxManage dhcpserver remove --netname ${x}
    done
}

function remove-all-machines(){
   VBoxManage list vms | while read x; do
        [[ "$x" =~ \"([^\"]+)\".* ]]
        remove-machine ${BASH_REMATCH[1]};
   done
}

function remove-machine(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: remove-machine MACHINE_NAME"
            exit 1
    fi
    MACHINE_NAME=$1
    IS_RUNNING=$( VBoxManage list runningvms | grep ${MACHINE_NAME} || true)
    if [[ ! -z "${IS_RUNNING}" ]]; then
        VBoxManage controlvm "${MACHINE_NAME}" poweroff
    fi
    VBoxManage unregistervm ${MACHINE_NAME} --delete

}
function remove-group(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: remove-group GROUP_NUMBER"
            exit 1
    fi
    GROUP_NUMBER=$1
    get-vms-in-group "/Group_${GROUP_NUMBER}" | while read x; do
          remove-machine ${x}
    done
}
function get-group(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: get-group TEMPLATE_NAME"
            exit 1
    fi
    TEMPLATE_NAME=$1
    VBoxManage list vms -l | grep -E -a1 "(Name:[\s ]+${TEMPLATE_NAME})" | tail -n1 | cut -b18\-
}

function get-vms-in-group(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: get-vms-in-group GROUP_NAME"
            exit 1
    fi
    GROUP_NAME=$1
    VBoxManage list vms -l | grep -B1 -E  "(Groups:[\s ]+${GROUP_NAME})"  | grep "Name:" | cut -b18-
}

function start-and-wait-for-it(){
    if [[ ( -z ${1} ) ]]; then
            echo "Usage: start-and-wait-for-it MACHINE_NAME"
            exit 1
    fi
    MACHINE_NAME=$1

    STARTED=$(VBoxManage list runningvms | grep ${MACHINE_NAME} || true)
    if [ -z "${STARTED}" ]; then
        VBoxManage startvm ${MACHINE_NAME}
    fi
    ITERATOR=0;
    MAX_ATTEMPTS=100
    printf "Waiting for ${MACHINE_NAME}"
    while [ $ITERATOR -le $MAX_ATTEMPTS ]; do
        ITERATOR=$[ITERATOR + 1]
        printf "."
        IP_ADDRESS=$(VBoxManage guestproperty enumerate ${MACHINE_NAME} | grep /Net/1/V4/IP || echo "WAIT")
        if [ "$IP_ADDRESS" != "WAIT" ]; then
            [[ $(VBoxManage guestproperty enumerate ${1} | grep /Net/1/V4/IP) =~ (value: ([0-9.]+),) || true ]];
            IP_ADDRESS=${BASH_REMATCH[2]};
            ITERATOR=1000
        fi;
        if [ "$ITERATOR" == "$MAX_ATTEMPTS" ]; then
                echoerr "Timed out"
                exit 1
            fi
        sleep 1s
    done
    ping -c 1 -t 60 ${IP_ADDRESS} &> /dev/null && echo "ok." || echo "FAILED!"
}


function validate-positive-int(){
    TO_VALIDATE=$1
    MSG=$2
    if ! [[ "$TO_VALIDATE" =~ ^[0-9]+$ ]] ; then
       echoerr "$MSG is not a number" >&2; exit 1
    fi

    if [ "${TO_VALIDATE}" -le 0 ]; then
            echoerr "$MSG number must be >= 1"
            exit 1;
    fi

}

function get-vms-in-group-ext(){
    if [[ ( -z ${1} ) || ( -z ${2} ) ]]; then
            echo "Usage: get-vms-in-group-ext GROUP_NUMBER MACHINE_INDICATOR"
            exit 1
    fi
    GROUP_NUMBER=$1
    MACHINE_INDICATOR=$2
    if [ "$MACHINE_INDICATOR" == "all" ]; then
        get-vms-in-group /Group_${GROUP_NUMBER}
    else
        arrIN=(${MACHINE_INDICATOR//,/ })
        for x in "${arrIN[@]}"; do
            echo "${GROUP_NUMBER}_Machine_${x}"
        done
    fi

}

