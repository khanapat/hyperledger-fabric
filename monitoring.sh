#!/bin/bash

set -e
source .env

NAMESPACES=dscf
FUNCTION=create
MONITORING_PATH=${ROOT_FOLDER}/kube

Parse_Arguments() {
	while [ $# -gt 0 ]; do
		case $1 in
			-n | --namespaces)
				echo "Configured to setup a namespace"
				NAMESPACES=$2
				;;
			-i | --include-volumes)
				DELETE_VOLUMES=true
				;;
            -m | --monitoring)
                FUNCTION=$2
                ;;
		esac
		shift
	done
}

Create_Monitoring() {
    echo "##########################################################"
    echo "################# Creating Monitoring ####################"
    echo "##########################################################"

    echo "Running: ${MONITORING_PATH}/monitoring.yaml -n ${NAMESPACES}"
    kubectl create -f ${MONITORING_PATH}/monitoring.yaml -n ${NAMESPACES}

    GRAFANA_STATUS=$(kubectl get pods -n ${NAMESPACES} | grep grafana | awk '{print $3}')
    PROMETHEUS_STATUS=$(kubectl get pods -n ${NAMESPACES} | grep prometheus | awk '{print $3}')
    while [ "${GRAFANA_STATUS}" != "Running" ] || [ "${PROMETHEUS_STATUS}" != "Running" ]; do
        if [ "${GRAFANA_STATUS}" == "Error" ] || [ "${PROMETHEUS_STATUS}" == "Error" ]; then
            echo "There is an error in monitoring pod. Please check pod logs or describe."
            exit 1
        fi
        GRAFANA_STATUS=$(kubectl get pods -n ${NAMESPACES} | grep grafana | awk '{print $3}')
        PROMETHEUS_STATUS=$(kubectl get pods -n ${NAMESPACES} | grep prometheus | awk '{print $3}')
        echo "Waiting for CA to run. Grafana Status = ${GRAFANA_STATUS} & Prometheus Status = ${PROMETHEUS_STATUS}"
        sleep 1
    done
}

Delete_Monitoring() {
    echo "##########################################################"
    echo "################# Deleting Monitoring ####################"
    echo "##########################################################"

    echo "Running: ${MONITORING_PATH}/monitoring.yaml -n ${NAMESPACES}"
    kubectl delete -f ${MONITORING_PATH}/monitoring.yaml -n ${NAMESPACES}
}

Parse_Arguments $@

if [ ${FUNCTION} == "delete" ]; then
    Delete_Monitoring
else
    Create_Monitoring
fi