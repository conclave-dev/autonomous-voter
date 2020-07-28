// Thanks @ critesjosh
// https://docs.celo.org/developer-guide/start/hello-contract-remote-node
const { newKit } = require('@celo/contractkit');
const { alfajoresRpcAPI, alfajoresPrimaryAccount, localRpcAPI, localPrimaryAccount } = require('./config');

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
      network_id: 44787,
      gas: 10000000,
      gasPrice: 100000000000,
      from: alfajoresPrimaryAccount
    },
    local: {
      provider: localProvider, // CeloProvider
      network_id: '*',
      gas: 20000000,
      gasPrice: 100000000000,
      from: localPrimaryAccount
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
