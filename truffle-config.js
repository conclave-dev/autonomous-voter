// Thanks @ critesjosh
// https://docs.celo.org/developer-guide/start/hello-contract-remote-node
const { newKit } = require('@celo/contractkit');
const { alfajoresRpcAPI, localRpcAPI } = require('./config');

const {
  web3: {
    _provider: { existingProvider: alfajoresProvider }
  }
} = newKit(alfajoresRpcAPI);
const {
  web3: {
    _provider: { existingProvider: localProvider }
  }
} = newKit(localRpcAPI);

module.exports = {
  networks: {
    alfajores: {
      provider: alfajoresProvider, // CeloProvider
      network_id: 44786,
      gas: 20000000,
      gasPrice: 100000000000,
      from: '0x742e41440C70dFf2C78388B4a2C432A7A6cA08cf'
    },
    local: {
      provider: localProvider, // CeloProvider
      network_id: '*',
      gas: 20000000,
      gasPrice: 100000000000,
      from: '0x5409ED021D9299bf6814279A6A1411A7e866A631'
    }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 60000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '^0.5.17' // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    }
  }
};
