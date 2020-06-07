// Thanks @ critesjosh
// https://docs.celo.org/developer-guide/start/hello-contract-remote-node
const { newKit } = require('@celo/contractkit');
const { rpcAPI } = require('./config');

const { web3 } = newKit(rpcAPI);

module.exports = {
  networks: {
    alfajores: {
      provider: web3.currentProvider, // CeloProvider
      network_id: 44786,
      gas: 20000000,
      gasPrice: 100000000000,
      from: '0x876b74eDac7b5ecad82Ac3bf446c8E1503FEF37d'
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
