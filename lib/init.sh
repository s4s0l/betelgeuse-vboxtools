#!/usr/bin/env bash
set -e
DIR=$(dirname $0)
. ${DIR}/lib/functions.sh




VBOXTOOLSHOME=~/.betelgeuse
. ${DIR}/lib/default-settings.sh
if [ ! -f ${VBOXTOOLSHOME}/settings.sh ]; then
    echolog "$VBOXTOOLSHOME/settings.sh does not exists, using defaults only"
    echolog "You can create $VBOXTOOLSHOME/settings.sh and override settings from ${DIR}/lib/default-settings.sh"
else
    echolog "${VBOXTOOLSHOME}/settings.sh exists, using it, check if is compatible with ${DIR}/lib/default-settings.sh"
    . ${VBOXTOOLSHOME}/settings.sh
fi

