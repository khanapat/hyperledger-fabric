#!/bin/bash

set -e
source .env

CHANNEL_NAME=channel1

echo ""
echo "=> CREATE_NAMESPACE"
kubectl apply -f kube/namespace.yaml
kubectl get secret default-jp-icr-io -n default -o yaml | sed 's/default/blockchain/g' | kubectl create -n blockchain -f -
kubectl patch -n blockchain serviceaccount/default -p '{"imagePullSecrets":[{"name": "blockchain-jp-icr-io"}]}'

echo "=> CREATE_BLOCKCHAIN: Creating ConfigMap and Secret"
kubectl create cm ordererorg-genesis --from-file=genesis.block=${GENERATED_FOLDER}/configtx/orderer.block -n blockchain
kubectl create cm ${CHANNEL_NAME}-genesis --from-file=${CHANNEL_NAME}.block=${GENERATED_FOLDER}/configtx/${CHANNEL_NAME}.tx -n blockchain

kubectl create cm ${CHANNEL_NAME}-anchorpeer-org1 --from-file=Org1MSPanchors.tx=${GENERATED_FOLDER}/configtx/Org1MSPanchors.tx -n blockchain
kubectl create cm ${CHANNEL_NAME}-anchorpeer-org2 --from-file=Org2MSPanchors.tx=${GENERATED_FOLDER}/configtx/Org2MSPanchors.tx -n blockchain

ORGS="ordererorg org1 org2"
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
	kubectl create secret generic ${o}-ca-crypto \
		--from-file=cert.pem=${org_folder}/ca/${o}ca-cert.pem \
		--from-file=key=${org_folder}/ca/key.pem -n blockchain 
	
	kubectl create secret generic admin-${o}-crypto \
			--from-file=admincert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=cacert.pem=${org_folder}/users/Admin@${o}/msp/cacerts/${o}ca-cert.pem \
			--from-file=key=${org_folder}/users/Admin@${o}/msp/keystore/key.pem \
			--from-file=cert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=tlscacert.pem=${org_folder}/users/Admin@${o}/msp/tlscacerts/tls${o}ca-cert.pem -n blockchain 
	
	for c in $C
	do
		name=${o}-${c} 
		kubectl create secret generic ${name}-ca-crypto \
			--from-file=admincert.pem=${org_folder}/users/Admin@${o}/msp/signcerts/Admin@${o}-cert.pem \
			--from-file=cacert.pem=${org_folder}/${G}/${name}/msp/cacerts/${o}ca-cert.pem \
			--from-file=key=${org_folder}/${G}/${name}/msp/keystore/key.pem \
			--from-file=cert.pem=${org_folder}/${G}/${name}/msp/signcerts/${name}-cert.pem \
			--from-file=tlscacert.pem=${org_folder}/${G}/${name}/msp/tlscacerts/tls${o}ca-cert.pem -n blockchain 

		kubectl create secret generic ${name}-tlsca-crypto \
			--from-file=ca.crt=${org_folder}/${G}/${name}/tls/ca.crt \
			--from-file=server.crt=${org_folder}/${G}/${name}/tls/server.crt \
			--from-file=server.key=${org_folder}/${G}/${name}/tls/server.key -n blockchain 
	done
done

echo ""
echo "=> CREATE_BLOCKCHAIN: Creating Utility Pod"
kubectl apply -f kube/utility.yaml
kubectl wait --for=condition=Ready pod/utility-pod  -n blockchain --timeout=300s

echo ""
echo "=> CREATE_BLOCKCHAIN: Creating CA, Orderer and Peers"
kubectl apply -f kube/peer
kubectl apply -f kube/ca
kubectl apply -f kube/orderer

echo ""
echo "=> CREATE_BLOCKCHAIN: Checking if all deployments are ready"
kubectl wait --for=condition=Ready pod -l app=blockchain --timeout=300s -n blockchain

echo ""
echo "=> CREATE_BLOCKCHAIN: Waiting for 30 seconds for RAFT leader to be elected"
sleep 30

kubectl exec utility-pod -n blockchain \
 -- sh -c 'peer channel create -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} -f /data/${CHANNEL_NAME}.block'
sleep 2

echo ""
echo "=> CREATE_BLOCKCHAIN: Join Channel on Org1 Peer1"
kubectl exec utility-pod -n blockchain \
 -- sh -c 'peer channel fetch config -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} && peer channel join -b ${CHANNEL_NAME}_config.block'

echo ""
echo "=> CREATE_BLOCKCHAIN: Join Channel on Org2 Peer1"
kubectl exec utility-pod -n blockchain -- sh -c 'CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt CORE_PEER_ADDRESS=org2-peer1:7051 peer channel join -b ${CHANNEL_NAME}_config.block'

echo ""
echo "=> CREATE_BLOCKCHAIN: Update Anchor Peer for Org1MSP"
kubectl exec utility-pod -n blockchain \
 -- sh -c 'peer channel update -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} -f /anchorpeers/org1/Org1MSPanchors.tx'

echo ""
echo "=> CREATE_BLOCKCHAIN: Update Anchor Peer for Org2MSP"
kubectl exec utility-pod -n blockchain \
 -- sh -c 'CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt CORE_PEER_ADDRESS=org2-peer1:7051 peer channel update -o ${ORDERER_URL} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA_TLS} -f /anchorpeers/org2/Org2MSPanchors.tx'

echo "Done!!"