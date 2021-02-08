#!/bin/bash

set -e
source .env

UPGRADE=false
SEQUENCE=1
export CHANNEL_NAME="channel1"
export CHAINCODE_NAME="fabcar"
export CHAINCODE_VERSION=1
#Path to the source code inside $GOPATH/src folder
export CHAINCODE_FOLDER="fabcar"
export CHAINCODE_INIT_STRING="{\"Args\":[]}"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -u|--upgrade)
		UPGRADE=true
    if [ -z "$2" ]
      then
        echo "No version specified. Specify version using --upgrade <version> e.g. --upgrade 2"
        exit 1
    fi
    CHAINCODE_VERSION="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ "$UPGRADE" == "true" ]
  then
    echo ""
    echo "=> RUN_CHAINCODE: Checking for current sequence of $CHAINCODE_NAME"
    kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer lifecycle chaincode querycommitted -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} --output json | jq -r .sequence > /tmp/current_sequence.txt && cat /tmp/current_sequence.txt"
    kubectl exec utility-pod -n blockchain -- sh -c 'SEQ=$(cat /tmp/current_sequence.txt) && NEXT_SEQ=`expr "$SEQ" + 1` && echo $NEXT_SEQ > /tmp/next_sequence.txt'
    rm -f next_sequence.txt
    kubectl cp utility-pod:/tmp/next_sequence.txt next_sequence.txt -n blockchain
    SEQUENCE=$(cat next_sequence.txt)
fi

echo "=> RUN_CHAINCODE: Channel: $CHANNEL_NAME -- Name: $CHAINCODE_NAME -- Version: $CHAINCODE_VERSION -- Sequence -- $SEQUENCE"

echo ""
echo "=> RUN_CHAINCODE: Copying $CHAINCODE_NAME"
kubectl exec utility-pod -n blockchain -- sh -c "mkdir -p /go/src/$CHAINCODE_FOLDER"

# comment this line if chaincode is in real $GOPATH
export GOPATH=${ROOT_FOLDER}/chaincode

kubectl cp $GOPATH/src/$CHAINCODE_FOLDER utility-pod:/go/src -n blockchain
kubectl exec utility-pod -n blockchain -- sh -c "ls -lah /go/src/$CHAINCODE_FOLDER"

echo ""
echo "=> RUN_CHAINCODE: Install dependencies for $CHAINCODE_NAME"
kubectl exec utility-pod -n blockchain -- sh -c "cd /go/src/$CHAINCODE_FOLDER && go mod vendor"

echo ""
echo "=> RUN_CHAINCODE: Package ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
kubectl exec utility-pod -n blockchain -- \
 sh -c "peer lifecycle chaincode package /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION} --lang golang -p ${CHAINCODE_FOLDER}/"

echo ""
echo "=> RUN_CHAINCODE: Install ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on org1-peer1"
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ADDRESS=org1-peer1:7051 CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org1/peers/org1-peer1/tls/ca.crt CORE_PEER_TLS_ENABLED=true peer lifecycle chaincode install /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz"

# echo ""
# echo "=> RUN_CHAINCODE: Install ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on org2-peer1"
# kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_ADDRESS=org2-peer1:7051 CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt CORE_PEER_TLS_ENABLED=true CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp peer lifecycle chaincode install /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz"

echo ""
echo "=> RUN_CHAINCODE: Query ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on org1-peer1"
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_ADDRESS=org1-peer1:7051 CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org1/peers/org1-peer1/tls/ca.crt CORE_PEER_TLS_ENABLED=true rm -f /tmp/pid.txt && peer lifecycle chaincode queryinstalled -O json | jq -r '.installed_chaincodes[] | select(.label | contains(\"${CHAINCODE_NAME}_${CHAINCODE_VERSION}\")) | .package_id' > /tmp/pid.txt && cat /tmp/pid.txt"

rm -f pid.txt
kubectl cp utility-pod:/tmp/pid.txt pid.txt -n blockchain
PID=$(cat pid.txt)

echo ""
echo "=> RUN_CHAINCODE: Approve ${CHAINCODE_NAME}_${CHAINCODE_VERSION} for Org1MSP"
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer lifecycle chaincode approveformyorg -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --package-id $PID --sequence $SEQUENCE"

# echo ""
# echo "=> RUN_CHAINCODE: Approve ${CHAINCODE_NAME}_${CHAINCODE_VERSION} for Org2MSP"
# kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp CORE_PEER_ADDRESS=org2-peer1:7051 CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt CORE_PEER_TLS_ENABLED=true peer lifecycle chaincode approveformyorg -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --package-id $PID --sequence $SEQUENCE"

echo ""
echo "=> RUN_CHAINCODE: Check ${CHAINCODE_NAME}_${CHAINCODE_VERSION} commit readiness"
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer lifecycle chaincode checkcommitreadiness -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --sequence $SEQUENCE --output json"

echo ""
echo "=> RUN_CHAINCODE: Commit ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer lifecycle chaincode commit --peerAddresses org1-peer1:7051 --tlsRootCertFiles /crypto/org1/peers/org1-peer1/tls/ca.crt -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --sequence $SEQUENCE"

echo ""
echo "=> RUN_CHAINCODE: Query committed chaincode"
sleep 5
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer lifecycle chaincode querycommitted -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} --output json"

echo ""
echo "=> RUN_CHAINCODE: Invoking ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer chaincode invoke --peerAddresses org1-peer1:7051 --tlsRootCertFiles /crypto/org1/peers/org1-peer1/tls/ca.crt --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -c '{\"function\":\"initLedger\",\"Args\":[]}'"

echo ""
echo "=> RUN_CHAINCODE: Querying ${CHAINCODE_NAME}:${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n blockchain -- sh -c "CORE_PEER_LOCALMSPID=Org1MSP CORE_PEER_MSPCONFIGPATH=/crypto/org1/users/Admin@org1/msp peer chaincode query -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -c '{\"function\":\"queryCar\",\"Args\":[\"CAR1\"]}'"