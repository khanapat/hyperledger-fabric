#!/bin/bash

source .env

CHANNEL_NAME=channel1

echo "Deleting blockchain deployments"
kubectl delete cm ordererorg-genesis -n dscf
kubectl delete cm ${CHANNEL_NAME}-genesis -n dscf

kubectl delete cm ${CHANNEL_NAME}-anchorpeer-org1 -n dscf

ORGS="ordererorg org1"
for o in $ORGS
do
	if [ "$o" == "ordererorg" ]; then
		F="ordererOrganizations"
		G="orderers"
		C="orderer1 orderer2 orderer3"
	else
		F="peerOrganizations"
		G="peers"
		C="peer1"
	fi

	org_folder=${GENERATED_FOLDER}/crypto-config/${F}/${o}
	kubectl delete secret ${o}-ca-crypto -n dscf
	kubectl delete secret admin-${o}-crypto -n dscf
	
	for c in $C
	do
		name=${o}-${c} 
		kubectl delete secret ${name}-ca-crypto -n dscf

		kubectl delete secret ${name}-tlsca-crypto -n dscf
	done
done

kubectl delete -f kube/ca -n dscf
kubectl delete -f kube/orderer -n dscf
kubectl delete -f kube/peer -n dscf
kubectl delete -f kube/utility.yaml -n dscf
# kubectl delete -f kube/namespace.yaml

echo "All blockchain deployments & services & namespace have been removed"
