/*
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const {
  Wallets,
  Gateway,
  X509Identity
} = require('fabric-network');
const path = require('path');
const express = require('express');
const FabricCAServices = require('fabric-ca-client');
const fs = require('fs');
const app = express();
const port = process.env.PORT || 8080;
const CONN_FILE = process.env.CONN_FILE || 'conn1.json';

const ccpPath = path.resolve(__dirname, 'config', CONN_FILE);
const CHANNEL_NAME = process.env.CHANNEL_NAME || 'channel1';
const CHAINCODE_NAME = process.env.CHAINCODE_NAME || 'fabcar';
const REGISTRAR_ID = process.env.REGISTRAR_ID || 'admin';
const REGISTRAR_SECRET = process.env.REGISTRAR_SECRET || 'adminpw';
const IS_LOCALHOST = process.env.IS_LOCALHOST || false;

const ccpJSON = fs.readFileSync(ccpPath, 'utf8');
const ccp = JSON.parse(ccpJSON);
const MSP = ccp.client.organization;

let gateway;
let network;
let contract;

app.get('/invoke', async (req, res) => {
  try {

    // Submit the specified transaction.
    await contract.submitTransaction('CreateCar', 'CAR10001', 'Honda', 'Jazz', 'Black', 'Fred');
    console.log(`Transaction CAR10001 is submitted`);
    res.send(`Transaction CAR10001 is submitted`);

  } catch (error) {
    console.error(`Failed to submit transaction: ${error}`);
  }
});


const start = async () => {
  const walletPath = './wallet';
  const wallet = await Wallets.newFileSystemWallet(walletPath);
  console.log(`Wallet path: ${walletPath}`);

  const cas = Object.keys(ccp.certificateAuthorities);
  const caInfo = ccp.certificateAuthorities[cas[0]];
  const ca = new FabricCAServices(caInfo.url, {
    trustedRoots: caInfo.tlsCACerts.pem,
    verify: false
  }, caInfo.caName);

  const registrarExists = await wallet.get(REGISTRAR_ID);

  if (registrarExists) {
    console.log(`An identity for the registrar user ${REGISTRAR_ID} already exists in the wallet`);
  } else {
    // Enroll the admin user, and import the new identity into the wallet.
    const enrollment = await ca.enroll({ enrollmentID: REGISTRAR_ID, enrollmentSecret: REGISTRAR_SECRET });
    const x509Identity = {
        credentials: {
            certificate: enrollment.certificate,
            privateKey: enrollment.key.toBytes(),
        },
        mspId: MSP,
        type: 'X.509',
    };
    await wallet.put(REGISTRAR_ID, x509Identity);
    console.log(`Successfully enrolled registrar ${REGISTRAR_ID} and imported it into the wallet`);
  }

  const appUserExists = await wallet.get(REGISTRAR_ID);

  if (appUserExists) {
    console.log(`An identity for the appUser already exists in the wallet`);
  } else {
    console.log(`An identity for the appUser not exists in the wallet`);
  }
  console.log(`Connect Gateway...`);
  const gateway = new Gateway();
  console.log(`IS_LOCALHOST ${IS_LOCALHOST}`);
  await gateway.connect(ccp, { wallet, identity: 'appUser', discovery: { enabled: true, asLocalhost: IS_LOCALHOST } });

  network = await gateway.getNetwork(CHANNEL_NAME);
  contract = network.getContract(CHAINCODE_NAME);

  app.listen(port, async () => {
    console.log(`App listening on port ${port}!`);
  });
};

start();

process.on('SIGINT', async () => {
  console.log('Disconnecting from gateways..');
  await contract.gateway.disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('Disconnecting from gateways..');
  await contract.gateway.disconnect();
  process.exit(0);
});
