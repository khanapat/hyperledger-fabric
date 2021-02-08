#!/bin/bash

source .env

CHANNEL_NAME=channel1

echo "Deleting blockchain deployments"
kubectl delete cm ordererorg-genesis -n blockchain
kubectl delete cm ${CHANNEL_NAME}-genesis -n blockchain

kubectl delete cm ${CHANNEL_NAME}-anchorpeer-org1 -n blockchain
kubectl delete cm ${CHANNEL_NAME}-anchorpeer-org2 -n blockchain

ORGS="ordererorg org1 org2"
for o in $ORGS
do
	if [ "$o" == "ordererorg" ]; then
		F="ordererOrganizations"
		G="orderers"
		C="orderer1 orderer2"
	else
		F="peerOrganizations"
		G="peers"
		C="peer1"
	fi

	org_folder=${GENERATED_FOLDER}/crypto-config/${F}/${o}
	kubectl delete secret ${o}-ca-crypto -n blockchain
	kubectl delete secret admin-${o}-crypto -n blockchain
	
	for c in $C
	do
		name=${o}-${c} 
		kubectl delete secret ${name}-ca-crypto -n blockchain

		kubectl delete secret ${name}-tlsca-crypto -n blockchain
	done
done

kubectl delete -f kube/ca -n blockchain
kubectl delete -f kube/orderer -n blockchain
kubectl delete -f kube/peer -n blockchain
kubectl delete -f kube/utility.yaml -n blockchain
kubectl delete -f kube/namespace.yaml

echo "All blockchain deployments & services & namespace have been removed"
