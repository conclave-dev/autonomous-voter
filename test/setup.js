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

const Vault = loader.truffle.fromArtifact('Vault', '0x2e99Be3b0162Ad3b5740327e85e16E9ee3d1856e');
const VaultFactory = loader.truffle.fromArtifact('VaultFactory', '0xB0F2462850A4DedCc129C118d0d57fD204A49d2f');
const App = loader.truffle.fromArtifact('App', '0x8a049301180abb94F53d984f9a017Cb3A5B2CC80');
const Archive = loader.truffle.fromArtifact('Archive', '0x90D22168Aee3392F2FDfD0C66eF10F1d6ffCb7b8');

module.exports = {
  expect,
  assert,
  loader,
  contracts: {
    Vault,
    VaultFactory,
    App,
    Archive
  },
  kit: newKit(rpcAPI)
};
