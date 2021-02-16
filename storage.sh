#!/bin/bash

set -e
source .env

NAMESPACES=dscf
FUNCTION=create
STORAGE_PATH=${ROOT_FOLDER}/kube/storage
NODE="orderer1 orderer2 orderer3 ktborg-peer1-peer ktborg-peer2-peer ktborg-ca"

Parse_Arguments() {
	while [ $# -gt 0 ]; do
		case $1 in
			-n | --namespaces)
				echo "Configured to setup a namespace"
				NAMESPACES=$2
				;;
			-v | --volumes)
				FUNCTION=delete
				;;
		esac
		shift
	done
}

Create_Storage() {
    echo "##########################################################"
    echo "############### Creating Persistent Volumes ##############"
    echo "##########################################################"

    for n in ${NODE}
    do
        # pv
        kubectl create -f ${STORAGE_PATH}/${n}-storage-pv.yaml -n ${NAMESPACES}
        sleep 3
        # pvc
        kubectl create -f ${STORAGE_PATH}/${n}-storage-pvc.yaml -n ${NAMESPACES}
        sleep 3
        if [ "kubectl get pvc -n ${NAMESPACES} | grep ${n}-dscf-pvc | awk '{print $3}'" != "${n}-dscf-pv" ]; then
            echo "Success creating PV"
        else
            echo "Failed to create PV"
        fi
    done
}

Delete_Storage() {
    echo "##########################################################"
    echo "############### Deleting Persistent Volumes ##############"
    echo "##########################################################"

    for n in ${NODE}
    do
        # pvc
        kubectl delete -f ${STORAGE_PATH}/${n}-storage-pvc.yaml -n ${NAMESPACES}
        sleep 3
        # pv
        kubectl delete -f ${STORAGE_PATH}/${n}-storage-pv.yaml -n ${NAMESPACES}
        sleep 3
    done
}

Parse_Arguments $@

if [ ${FUNCTION} == "delete" ]; then
    Delete_Storage
else
    Create_Storage
fi


