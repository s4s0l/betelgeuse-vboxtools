#!/bin/bash
. $(dirname $0)/lib/init.sh

remove-all-dhcp-servers
remove-all-host-only-network
remove-all-machines
