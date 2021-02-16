#!/bin/bash

set -e
source .env

UPGRADE=false
SEQUENCE=1

DOCUMENT_CHANNEL=document
VERIFIER_CHANNEL=document-verifier
PUBLICKEY_CHANNEL=public-key
NAMESPACES=dscf

export CHANNEL_NAME="document"
export CHAINCODE_NAME="fabcar"
export CHAINCODE_VERSION=1
#Path to the source code inside $GOPATH/src folder
export CHAINCODE_FOLDER="fabcar"
export CHAINCODE_INIT_STRING="{\"Args\":[]}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
      -u | --upgrade)
        UPGRADE=true
        if [ -z "$2" ]; then
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

# if [ "${UPGRADE}" == "true" ]; then
#   echo ""
#   echo "=> RUN_CHAINCODE: Checking for current sequence of ${CHAINCODE_NAME}"
#   kubectl exec utility-pod -n ${NAMESPACES} \
#    -- sh -c 'CORE_PEER_LOCALMSPID=KTBOrgMSP
#    CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
#    peer lifecycle chaincode querycommitted -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} --output json | jq -r .sequence > /tmp/current_sequence.txt && cat /tmp/current_sequence.txt'
#   kubectl exec utility-pod -n ${NAMESPACES} -- sh -c 'SEQ=$(cat /tmp/current_sequence.txt) && NEXT_SEQ=`expr "$SEQ" + 1` && echo $NEXT_SEQ > /tmp/next_sequence.txt'
#   rm -f next_sequence.txt
#   kubectl cp utility-pod:/tmp/next_sequence.txt next_sequence.txt -n ${NAMESPACES}
#   SEQUENCE=$(cat next_sequence.txt)
# fi

echo "=> RUN_CHAINCODE: Channel: ${CHANNEL_NAME} -- Name: ${CHAINCODE_NAME} -- Version: ${CHAINCODE_VERSION} -- Sequence -- ${SEQUENCE}"

echo
echo "=> RUN_CHAINCODE: Copying ${CHAINCODE_NAME}"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "mkdir -p /go/src/${CHAINCODE_FOLDER}"

# comment this line if chaincode is in real $GOPATH
export GOPATH=${ROOT_FOLDER}/chaincode

kubectl cp ${GOPATH}/src/${CHAINCODE_FOLDER} utility-pod:/go/src -n ${NAMESPACES}
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "ls -lah /go/src/${CHAINCODE_FOLDER}"

# need to go mod vendor before move to k8s (no internet)
# echo
# echo "=> RUN_CHAINCODE: Install dependencies for ${CHAINCODE_NAME}"
# kubectl exec utility-pod -n ${NAMESPACES} \
#   -- sh -c "cd /go/src/${CHAINCODE_FOLDER} && go mod vendor"

echo
echo "=> RUN_CHAINCODE: Package ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "peer lifecycle chaincode package /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION} --lang golang -p ${CHAINCODE_FOLDER}/"

echo
echo "=> RUN_CHAINCODE: Add cert registry in dind ktborg-peer1"
kubectl exec $(kubectl get pod -n ${NAMESPACES} | grep ktborg-peer1 | awk '{print $1}') -c dind -n ${NAMESPACES} \
 -- sh -c "mkdir -p /etc/docker/certs.d/kcskbcnd93.kcs:5000/ && cd /etc/docker/certs.d/kcskbcnd93.kcs:5000/ && cat << EOF > domain.crt
-----BEGIN CERTIFICATE-----
MIIFqTCCA5GgAwIBAgIJAP1hEipElFajMA0GCSqGSIb3DQEBCwUAMGoxCzAJBgNV
BAYTAlRIMRAwDgYDVQQIDAdCYW5na29rMRAwDgYDVQQHDAdCYW5nc3VlMQ4wDAYD
VQQKDAVLVEJDUzEOMAwGA1UECwwFS1RCQ1MxFzAVBgNVBAMMDmtjc2tiY25kOTMu
a2NzMCAXDTIwMDkwODA5NDYwNFoYDzMwMjAwMTEwMDk0NjA0WjBqMQswCQYDVQQG
EwJUSDEQMA4GA1UECAwHQmFuZ2tvazEQMA4GA1UEBwwHQmFuZ3N1ZTEOMAwGA1UE
CgwFS1RCQ1MxDjAMBgNVBAsMBUtUQkNTMRcwFQYDVQQDDA5rY3NrYmNuZDkzLmtj
czCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMvfRL83jTUIljchfHev
xc1KP0klENNkGPbeP5XEq59Fiik5ERIIQI4zIrnUGyclvqJyJ0jEqyAsAvVzSZ9M
m35zrlOyXQoCRq8ZFWD2H2IFQU0vPU976xQHnoVEYozaCpKDTolk8y4m67Q2Q1mq
P+FBlkUC4bm81ln/fB8LMZlFkdGvA/P6fEC2GMwmYEMYgK0mN2TO2YIMggXmhtxT
fhTCQCkuC1quMY7jANq8hW9CKJ7pr4YJ02UPwbZIE9kF604r1Nxee2fvMcTBOOy9
DfEKhCLQleEctC+9fDZvkuHTIwEbTVUd/Cd7ovYO/MHP0LgA3rEbZAf7nHx4kUrb
Af1HenbN1Co3QVh+q9ILrlA00co6ZygRUP906KCjKN1aW0Tgevse7f3jIn4p5baW
NRFYXk8OGWBL/FB2yxni80ZEE7w5jUb6OgPeoe9KdIWY6xivajI9hixvhcQTGJfS
nhUxwRE6S4PKaTzcJmvC93thUfO5f1clTfNLoY9kJj+xq4A4XyetjLficLcx3a89
YClO9bTjGCCdT6kCjPIjvUeGKnnG6Z/3qMdU659/xa461fnZE4wjBRRAgaM7tvs5
3a+CBUrLI0mGiwLw/uI64P9NUXDEoYv7cUY8ISWCZQaeNpvJxp795ro+vwNit6bz
S8edVNCwtB9waibHgaIOkYXbAgMBAAGjUDBOMB0GA1UdDgQWBBRXNRZws/6hHCB4
w9jYnmE7ZG96kDAfBgNVHSMEGDAWgBRXNRZws/6hHCB4w9jYnmE7ZG96kDAMBgNV
HRMEBTADAQH/MA0GCSqGSIb3DQEBCwUAA4ICAQCzBbXQ02+JESv5lAPl9qHuGAEY
LfXEfyv7qdRWQ/XPPQhFMfCS70/1o6tNKcj7lO6LBHI7PVC0LPHMoLDObVtkGl11
NRl3klxxZB179GE/xUSMGZW2aeZLEAGd199lKRJf7vfMN8ypqCjqn9RrVA7P15H5
5ihtNW0Df8b645Ib3vqu66sPr1OSM2ggopXVEfFFsIKOsGgFQhH3ufaywtGmI3vY
n865DOQ5O1YAHiphCk3OmFlDzwmYj3syfBFISzOX5iu9roXZeQJZWhcZwTMs8X43
Ld6+h4T5c327GlfWk85UIv5ehjX1Dk32lX+ip/gYAubn/Ik3bkYBAX5bRjLlurm6
iFvw4y7Rn5P+Pz4SEBHYVCh6+71sMBvRGK67SGEWlJF8Ni6BTGCa07w4iHtTpnCp
sdBq0t1IS4wwlzexNrURCKOpFnDabrykYflZdlZkt/Jq9hITwJzWhOAheU6ud0Vt
tQj7GpcZpwQJUPQaEhLCLLPcTOCdbAavTzffWfxucS9S2iWCn8l7Y8nMUJAMLRQP
FgrLaa6j5plG/rvR4F/tWr515dNG/oRK9B6jO1Z//gfcfDy2M2Aixmjfoby7+Zk4
atO916rxsHacZZzQFXtR3fWt8XPW2jJvIU1zsL5hOIzZ3uKLCAIU95/xU8ckSsHP
zkTRcSaNjscGxeAwOw==
-----END CERTIFICATE-----
EOF"

echo
echo "=> RUN_CHAINCODE: Add cert registry in dind ktborg-peer2"
kubectl exec $(kubectl get pod -n ${NAMESPACES} | grep ktborg-peer2 | awk '{print $1}') -c dind -n ${NAMESPACES} \
 -- sh -c "mkdir -p /etc/docker/certs.d/kcskbcnd93.kcs:5000/ && cd /etc/docker/certs.d/kcskbcnd93.kcs:5000/ && cat << EOF > domain.crt
-----BEGIN CERTIFICATE-----
MIIFqTCCA5GgAwIBAgIJAP1hEipElFajMA0GCSqGSIb3DQEBCwUAMGoxCzAJBgNV
BAYTAlRIMRAwDgYDVQQIDAdCYW5na29rMRAwDgYDVQQHDAdCYW5nc3VlMQ4wDAYD
VQQKDAVLVEJDUzEOMAwGA1UECwwFS1RCQ1MxFzAVBgNVBAMMDmtjc2tiY25kOTMu
a2NzMCAXDTIwMDkwODA5NDYwNFoYDzMwMjAwMTEwMDk0NjA0WjBqMQswCQYDVQQG
EwJUSDEQMA4GA1UECAwHQmFuZ2tvazEQMA4GA1UEBwwHQmFuZ3N1ZTEOMAwGA1UE
CgwFS1RCQ1MxDjAMBgNVBAsMBUtUQkNTMRcwFQYDVQQDDA5rY3NrYmNuZDkzLmtj
czCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMvfRL83jTUIljchfHev
xc1KP0klENNkGPbeP5XEq59Fiik5ERIIQI4zIrnUGyclvqJyJ0jEqyAsAvVzSZ9M
m35zrlOyXQoCRq8ZFWD2H2IFQU0vPU976xQHnoVEYozaCpKDTolk8y4m67Q2Q1mq
P+FBlkUC4bm81ln/fB8LMZlFkdGvA/P6fEC2GMwmYEMYgK0mN2TO2YIMggXmhtxT
fhTCQCkuC1quMY7jANq8hW9CKJ7pr4YJ02UPwbZIE9kF604r1Nxee2fvMcTBOOy9
DfEKhCLQleEctC+9fDZvkuHTIwEbTVUd/Cd7ovYO/MHP0LgA3rEbZAf7nHx4kUrb
Af1HenbN1Co3QVh+q9ILrlA00co6ZygRUP906KCjKN1aW0Tgevse7f3jIn4p5baW
NRFYXk8OGWBL/FB2yxni80ZEE7w5jUb6OgPeoe9KdIWY6xivajI9hixvhcQTGJfS
nhUxwRE6S4PKaTzcJmvC93thUfO5f1clTfNLoY9kJj+xq4A4XyetjLficLcx3a89
YClO9bTjGCCdT6kCjPIjvUeGKnnG6Z/3qMdU659/xa461fnZE4wjBRRAgaM7tvs5
3a+CBUrLI0mGiwLw/uI64P9NUXDEoYv7cUY8ISWCZQaeNpvJxp795ro+vwNit6bz
S8edVNCwtB9waibHgaIOkYXbAgMBAAGjUDBOMB0GA1UdDgQWBBRXNRZws/6hHCB4
w9jYnmE7ZG96kDAfBgNVHSMEGDAWgBRXNRZws/6hHCB4w9jYnmE7ZG96kDAMBgNV
HRMEBTADAQH/MA0GCSqGSIb3DQEBCwUAA4ICAQCzBbXQ02+JESv5lAPl9qHuGAEY
LfXEfyv7qdRWQ/XPPQhFMfCS70/1o6tNKcj7lO6LBHI7PVC0LPHMoLDObVtkGl11
NRl3klxxZB179GE/xUSMGZW2aeZLEAGd199lKRJf7vfMN8ypqCjqn9RrVA7P15H5
5ihtNW0Df8b645Ib3vqu66sPr1OSM2ggopXVEfFFsIKOsGgFQhH3ufaywtGmI3vY
n865DOQ5O1YAHiphCk3OmFlDzwmYj3syfBFISzOX5iu9roXZeQJZWhcZwTMs8X43
Ld6+h4T5c327GlfWk85UIv5ehjX1Dk32lX+ip/gYAubn/Ik3bkYBAX5bRjLlurm6
iFvw4y7Rn5P+Pz4SEBHYVCh6+71sMBvRGK67SGEWlJF8Ni6BTGCa07w4iHtTpnCp
sdBq0t1IS4wwlzexNrURCKOpFnDabrykYflZdlZkt/Jq9hITwJzWhOAheU6ud0Vt
tQj7GpcZpwQJUPQaEhLCLLPcTOCdbAavTzffWfxucS9S2iWCn8l7Y8nMUJAMLRQP
FgrLaa6j5plG/rvR4F/tWr515dNG/oRK9B6jO1Z//gfcfDy2M2Aixmjfoby7+Zk4
atO916rxsHacZZzQFXtR3fWt8XPW2jJvIU1zsL5hOIzZ3uKLCAIU95/xU8ckSsHP
zkTRcSaNjscGxeAwOw==
-----END CERTIFICATE-----
EOF"

echo
echo "=> RUN_CHAINCODE: Install ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on ktborg-peer1"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_ADDRESS=ktborg-peer1:7051
  CORE_PEER_TLS_ROOTCERT_FILE=/crypto/ktborg/peers/ktborg-peer1/tls/ca.crt
  CORE_PEER_TLS_ENABLED=true
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer lifecycle chaincode install /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz"

# # echo
# # echo "=> RUN_CHAINCODE: Install ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on Org2-peer1"
# # kubectl exec utility-pod -n ${NAMESPACES} \
# #   -- sh -c "CORE_PEER_LOCALMSPID=Org2MSP
# #   CORE_PEER_ADDRESS=org2-peer1:7051
# #   CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt
# #   CORE_PEER_TLS_ENABLED=true
# #   CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp
# #   peer lifecycle chaincode install /tmp/${CHAINCODE_NAME}_${CHAINCODE_VERSION}.tar.gz"

echo
echo "=> RUN_CHAINCODE: Query ${CHAINCODE_NAME}_${CHAINCODE_VERSION} on ktborg-peer1"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_ADDRESS=ktborg-peer1:7051
  CORE_PEER_TLS_ROOTCERT_FILE=/crypto/ktborg/peers/ktborg-peer1/tls/ca.crt
  CORE_PEER_TLS_ENABLED=true
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  rm -f /tmp/pid.txt && peer lifecycle chaincode queryinstalled -O json | jq -r '.installed_chaincodes[] | select(.label | contains(\"${CHAINCODE_NAME}_${CHAINCODE_VERSION}\")) | .package_id' > /tmp/pid.txt && cat /tmp/pid.txt"

rm -f pid.txt
kubectl cp utility-pod:/tmp/pid.txt pid.txt -n ${NAMESPACES}
PID=$(cat pid.txt)

echo
echo "=> RUN_CHAINCODE: Approve ${CHAINCODE_NAME}_${CHAINCODE_VERSION} for KTBOrgMSP"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer lifecycle chaincode approveformyorg -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --package-id ${PID} --sequence ${SEQUENCE}"

# echo ""
# echo "=> RUN_CHAINCODE: Approve ${CHAINCODE_NAME}_${CHAINCODE_VERSION} for Org2MSP"
# kubectl exec utility-pod -n ${NAMESPACES} -- sh -c "CORE_PEER_LOCALMSPID=Org2MSP CORE_PEER_MSPCONFIGPATH=/crypto/org2/users/Admin@org2/msp CORE_PEER_ADDRESS=org2-peer1:7051 CORE_PEER_TLS_ROOTCERT_FILE=/crypto/org2/peers/org2-peer1/tls/ca.crt CORE_PEER_TLS_ENABLED=true peer lifecycle chaincode approveformyorg -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --package-id $PID --sequence $SEQUENCE"

echo
echo "=> RUN_CHAINCODE: Check ${CHAINCODE_NAME}_${CHAINCODE_VERSION} commit readiness"
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer lifecycle chaincode checkcommitreadiness -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --sequence ${SEQUENCE} --output json"

echo
echo "=> RUN_CHAINCODE: Commit ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer lifecycle chaincode commit --peerAddresses ktborg-peer1:7051 --tlsRootCertFiles /crypto/ktborg/peers/ktborg-peer1/tls/ca.crt -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -v ${CHAINCODE_VERSION} --channel-config-policy /Channel/Application/Endorsement --sequence ${SEQUENCE}"

echo
echo "=> RUN_CHAINCODE: Query committed chaincode"
sleep 5
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer lifecycle chaincode querycommitted -o ordererorg-orderer1:7050 --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} --output json"

echo
echo "=> RUN_CHAINCODE: Invoking ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer chaincode invoke --peerAddresses ktborg-peer1:7051 --tlsRootCertFiles /crypto/ktborg/peers/ktborg-peer1/tls/ca.crt --tls --cafile /crypto/ordererorg/orderers/ordererorg-orderer1/tls/ca.crt -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -c '{\"function\":\"initLedger\",\"Args\":[]}'"

echo
echo "=> RUN_CHAINCODE: Querying ${CHAINCODE_NAME}:${CHAINCODE_VERSION}"
sleep 5
kubectl exec utility-pod -n ${NAMESPACES} \
  -- sh -c "CORE_PEER_LOCALMSPID=KTBOrgMSP
  CORE_PEER_MSPCONFIGPATH=/crypto/ktborg/users/Admin@ktborg/msp
  peer chaincode query -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -c '{\"function\":\"queryCar\",\"Args\":[\"CAR1\"]}'"