#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
export PATH=${PWD}/bin:${PATH}
export FABRIC_CFG_PATH=${PWD}

CHANNEL_NAME=channel1
GENERATED_FOLDER=generated

set -e

if ! [ -x "$(command -v configtxgen)" ]; then
  echo 'Error: configtxgen is not installed.' >&2
  exit 1
fi

# create the GENERATED_FOLDER
if [ -d ${GENERATED_FOLDER} ]; then 

    # ask to confirm to clear it 
    read -p "Folder ${GENERATED_FOLDER} exists. Clear ? (Y to continue): " S_CONTINUE
    if [[ "${S_CONTINUE:-Y}" =~ ^[Yy]$ ]]; then

        # remove previous crypto material and config transactions
        rm -fr ${GENERATED_FOLDER}
        mkdir -p ${GENERATED_FOLDER}/configtx
    else 
        exit 1
    fi
else
    # create the folder
    mkdir -p ${GENERATED_FOLDER}
    mkdir -p ${GENERATED_FOLDER}/configtx
fi

# generate crypto material
echo
echo "##########################################################"
echo "############## GENERATE CRYPTO & ARTIFACTS ###############"
echo "##########################################################"
cryptogen generate --config=./crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

# Rename key files to key.pem
echo
echo "##########################################################"
echo "################### CHANGE CA KEY NAME ###################"
echo "##########################################################"
for file in $(find crypto-config/ -iname *_sk)
do
    dir=$(dirname $file)
    mv ${dir}/*_sk ${dir}/key.pem
    echo "${dir}/key.pem"
done

# # IBP requires an admin certificate in MSP definition despite of NodeOU
# echo "Inserting admin certificate in MSP definition"
# cp crypto-config/ordererOrganizations/ordererorg/users/Admin@ordererorg/msp/signcerts/Admin@ordererorg-cert.pem \
#  crypto-config/ordererOrganizations/ordererorg/msp/admincerts

# cp crypto-config/peerOrganizations/org1/users/Admin@org1/msp/signcerts/Admin@org1-cert.pem \
#  crypto-config/peerOrganizations/org1/msp/admincerts

# # cp crypto-config/peerOrganizations/org2/users/Admin@org2/msp/signcerts/Admin@org2-cert.pem \
# #  crypto-config/peerOrganizations/org2/msp/admincerts

# configtxgen -profile OrdererGenesis -outputBlock orderer.block -channelID testchainid
# configtxgen -profile Channel -outputCreateChannelTx ${CHANNEL_NAME}.tx -channelID ${CHANNEL_NAME}

# generate genesis block for orderer
echo
echo "##########################################################"
echo "################# GENERATE GENESIS BLOCK #################"
echo "##########################################################"
configtxgen -profile OrdererGenesis -outputBlock ./${GENERATED_FOLDER}/configtx/orderer.block -channelID testchainid
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# # generate channel configuration transaction
# configtxgen -profile Channel -outputCreateChannelTx ./${GENERATED_FOLDER}/configtx/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME

# configtxgen -profile Channel \
#     -outputAnchorPeersUpdate ./${GENERATED_FOLDER}/configtx/Org1MSPanchors.tx \
#     -channelID $CHANNEL_NAME -asOrg Org1MSP

# # configtxgen -profile Channel \
# #     -outputAnchorPeersUpdate ./${GENERATED_FOLDER}/configtx/Org2MSPanchors.tx \
# #     -channelID $CHANNEL_NAME -asOrg Org2MSP

# mv crypto-config ./${GENERATED_FOLDER}/

# rm -f .env

# echo "GENERATED_FOLDER=${GENERATED_FOLDER}" >> .env
# echo "COMPOSE_PROJECT_NAME=net" >> .env
# echo "ROOT_FOLDER=$(PWD)" >> .env