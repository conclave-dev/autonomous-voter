const { expect, assert } = require('chai').use(require('chai-as-promised'));
const { setupLoader } = require('@openzeppelin/contract-loader');
const { newKit } = require('@celo/contractkit');
const { primarySenderAddress, rpcAPI } = require('../config');

const loader = setupLoader({
  provider: rpcAPI,
  defaultSender: primarySenderAddress,
  defaultGas: '20000000',
  defaultGasPrice: '100000000000'
});

const Vault = loader.truffle.fromArtifact('Vault', '0x872688F0CD7a5d6093D085F0f15a9986cE80dF0E');
const VaultFactory = loader.truffle.fromArtifact('VaultFactory', '0x2cB6333633aCDA1bD1Fde9eE8b71553dAAC089BE');
const Strategy = loader.truffle.fromArtifact('Vault', '0xe26444af8d1662697cF81672ed38212B1F4EE79E');
const StrategyFactory = loader.truffle.fromArtifact('VaultFactory', '0x9307B271657064720952bDE4154C41EC5FCE646E');
const App = loader.truffle.fromArtifact('App', '0x996d015a2a89228973A2805C3865684DaEd6c0e1');
const Archive = loader.truffle.fromArtifact('Archive', '0x2623bD4fD733a10A865592C515e64771d56bC2f4');

module.exports = {
  expect,
  assert,
  loader,
  contracts: {
    Vault,
    VaultFactory,
    Strategy,
    StrategyFactory,
    App,
    Archive
  },
  kit: newKit(rpcAPI)
};
