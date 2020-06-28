// Thanks @ critesjosh
// https://docs.celo.org/developer-guide/start/hello-contract-remote-node
const { newKit } = require('@celo/contractkit');
const { alfajoresRpcAPI, baklavaRpcAPI, localRpcAPI, defaultGas, defaultGasPrice } = require('./config');

const {
  web3: {
    _provider: { existingProvider: alfajoresProvider }
  }
} = newKit(alfajoresRpcAPI);
const {
  web3: {
    _provider: { existingProvider: baklavaProvider }
  }
} = newKit(baklavaRpcAPI);
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
      gas: defaultGas,
      gasPrice: defaultGasPrice,
      from: '0x876b74eDac7b5ecad82Ac3bf446c8E1503FEF37d'
    },
    baklava: {
      provider: baklavaProvider,
      network_id: 40120,
      gas: defaultGas,
      gasPrice: defaultGasPrice,
      from: '0xB950E83464D7BB84e7420e460DEEc2A7ced656aA'
    },
    local: {
      provider: localProvider, // CeloProvider
      network_id: '*',
      gas: defaultGas,
      gasPrice: defaultGasPrice,
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
