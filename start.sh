#!/bin/bash

set -e
source .env

DOCUMENT_CHANNEL=document
VERIFIER_CHANNEL=document-verifier
PUBLICKEY_CHANNEL=public-key
NAMESPACES=dscf

echo
echo "##########################################################"
echo "################### CREATE NAMESPACE #####################"
echo "##########################################################"
echo "=> Creating Namespace"
NAMESPACES_STATUS=$(kubectl get ns | grep ${NAMESPACES} | awk '{print $2}')
if [ "${NAMESPACES_STATUS}" == "Active" ]; then
	echo "Namespace has already existed."
else
	echo "Creating Namespace ${NAMESPACES}"
	kubectl create ns ${NAMESPACES}
fi

# # kubectl apply -f kube/namespace.yaml
# # kubectl get secret default-jp-icr-io -n default -o yaml | sed 's/default/blockchain/g' | kubectl create -n dscf -f -
# # kubectl patch -n dscf serviceaccount/default -p '{"imagePullSecrets":[{"name": "blockchain-jp-icr-io"}]}'

echo
echo "##########################################################"
echo "################### CREATE BLOCKCHAIN ####################"
echo "##########################################################"
echo "=> Creating ConfigMap and Secret"
# orderer.block
kubectl create cm ordererorg-genesis --from-file=genesis.block=${GENERATED_FOLDER}/configtx/orderer.block -n ${NAMESPACES}
# channel
kubectl create cm ${DOCUMENT_CHANNEL}-genesis --from-file=${DOCUMENT_CHANNEL}.block=${GENERATED_FOLDER}/configtx/${DOCUMENT_CHANNEL}.tx -n ${NAMESPACES}
kubectl create cm ${VERIFIER_CHANNEL}-genesis --from-file=${VERIFIER_CHANNEL}.block=${GENERATED_FOLDER}/configtx/${VERIFIER_CHANNEL}.tx -n ${NAMESPACES}
kubectl create cm ${PUBLICKEY_CHANNEL}-genesis --from-file=${PUBLICKEY_CHANNEL}.block=${GENERATED_FOLDER}/configtx/${PUBLICKEY_CHANNEL}.tx -n ${NAMESPACES}
# anchorpeer
kubectl create cm ${DOCUMENT_CHANNEL}-anchorpeer-ktborg --from-file=KTBOrgDocumentMSPanchors.tx=${GENERATED_FOLDER}/configtx/KTBOrgDocumentMSPanchors.tx -n ${NAMESPACES}
kubectl create cm ${VERIFIER_CHANNEL}-anchorpeer-ktborg --from-file=KTBOrgVerifierMSPanchors.tx=${GENERATED_FOLDER}/configtx/KTBOrgVerifierMSPanchors.tx -n ${NAMESPACES}
kubectl create cm ${PUBLICKEY_CHANNEL}-anchorpeer-ktborg --from-file=KTBOrgPublicKeyMSPanchors.tx=${GENERATED_FOLDER}/configtx/KTBOrgPublicKeyMSPanchors.tx -n ${NAMESPACES}

ORGS="ordererorg ktborg"
for o in $ORGS
do
	if [ "$o" == "ordererorg" ]; then
		F="ordererOrganizations"
		G="orderers"
		C="orderer1 orderer2 orderer3"
	else
		F="peerOrganizations"
		G="peers"
		C="peer1 peer2"
	fi

	org_folder=${GENERATED_FOLDER}/crypto-config/${F}/${o}
	kubectl create secret generic ${o}-ca-crypto \
		--from-file=cert.pem=${org_folder}/ca/${o}ca-cert.pem \
		--from-file=key=${org_folder}/ca/key.pem -n ${NAMESPACES}
	
	kubectl create secret generic admin-${o}-crypto \
			--from-file=admincert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=cacert.pem=${org_folder}/users/Admin@${o}/msp/cacerts/${o}ca-cert.pem \
			--from-file=key=${org_folder}/users/Admin@${o}/msp/keystore/key.pem \
			--from-file=cert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=tlscacert.pem=${org_folder}/users/Admin@${o}/msp/tlscacerts/tls${o}ca-cert.pem -n ${NAMESPACES}
	
	for c in $C
	do
		name=${o}-${c}
		kubectl create secret generic ${name}-ca-crypto \
			--from-file=admincert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=cacert.pem=${org_folder}/${G}/${name}/msp/cacerts/${o}ca-cert.pem \
			--from-file=key=${org_folder}/${G}/${name}/msp/keystore/key.pem \
			--from-file=cert.pem=${org_folder}/${G}/${name}/msp/signcerts/${name}-cert.pem \
			--from-file=tlscacert.pem=${org_folder}/${G}/${name}/msp/tlscacerts/tls${o}ca-cert.pem -n ${NAMESPACES} 

		kubectl create secret generic ${name}-tlsca-crypto \
			--from-file=ca.crt=${org_folder}/${G}/${name}/tls/ca.crt \
			--from-file=server.crt=${org_folder}/${G}/${name}/tls/server.crt \
			--from-file=server.key=${org_folder}/${G}/${name}/tls/server.key -n ${NAMESPACES} 
	done
done

echo
echo "=> Creating Utility Pod"
kubectl apply -f kube/utility.yaml
kubectl wait --for=condition=Ready pod/utility-pod  -n dscf --timeout=300s

# echo ""
# echo "=> CREATE_BLOCKCHAIN: Creating CA, Orderer and Peers"
# kubectl apply -f kube/peer
# kubectl apply -f kube/ca
# kubectl apply -f kube/orderer

# echo ""
# echo "=> CREATE_BLOCKCHAIN: Checking if all deployments are ready"
# kubectl wait --for=condition=Ready pod -l app=blockchain --timeout=300s -n dscf

# echo ""
# echo "=> CREATE_BLOCKCHAIN: Waiting for 30 seconds for RAFT leader to be elected"
# sleep 30

# kubectl exec utility-pod -n dscf \
#  -- sh -c 'peer channel create -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} -f /data/${CHANNEL_NAME}.block'
# sleep 2

# echo ""
# echo "=> CREATE_BLOCKCHAIN: Join Channel on Org1 Peer1"
# kubectl exec utility-pod -n dscf \
#  -- sh -c 'peer channel fetch config -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} && peer channel join -b ${CHANNEL_NAME}_config.block'

# echo ""
# echo "=> CREATE_BLOCKCHAIN: Update Anchor Peer for Org1MSP"
# kubectl exec utility-pod -n dscf \
#  -- sh -c 'peer channel update -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} -f /anchorpeers/org1/Org1MSPanchors.tx'

# echo "Done!!"