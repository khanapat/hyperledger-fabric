/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Gateway, Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');

async function main() {
    try {
        // load the network configuration
        const ccpPath = path.resolve(__dirname, '..', 'connection-org1.json');
        let ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

        // Create a new file system based wallet for managing identities.
        const walletPath = path.join(__dirname, 'wallet');
        const wallet = await Wallets.newFileSystemWallet(walletPath);
        console.log(`Wallet path: ${walletPath}`);

        // Check to see if we've already enrolled the user.
        const identity = await wallet.get('appUser');
        if (!identity) {
            console.log('An identity for the user "appUser" does not exist in the wallet');
            console.log('Run the registerUser.js application before retrying');
            return;
        }

        // Create a new gateway for connecting to our peer node.
        const gateway = new Gateway();
        await gateway.connect(ccp, { wallet, identity: 'appUser',discovery: { enabled: true, asLocalhost: false } });

        // Get the network (channel) our contract is deployed to.
        const network = await gateway.getNetwork('channel1');

        // Get the contract from the network.
        const contract = network.getContract('fabcar');

        // Submit the specified transaction. (several example transactions are listed below)
        // createAsset creates an asset with ID asset1, color yellow, owner Dave, size 5 and appraizedValue of 130 requires 6 arguments.
        //      ex: ('createAsset', 'asset1', 'yellow', 'Dave', 5, 1300)
        // transferAsset transfers an asset with ID asset1 to new owner Tom - requires 2 arguments.
        //      ex: ('transferAsset', 'asset1', 'Tom')
        await contract.submitTransaction('CreateCar', 'CAR10001', 'Honda', 'Jazz', 'Black', 'Fred');
        console.log('Transaction has been submitted');

        const result = await contract.evaluateTransaction('QueryCar', 'CAR10001');
        console.log(`Transaction has been evaluated, result is: ${result.toString()}`);

        // Disconnect from the gateway.
        await gateway.disconnect();

    } catch (error) {
        console.error(`Failed to submit transaction: ${error}`);
        process.exit(1);
    }
}

main();
