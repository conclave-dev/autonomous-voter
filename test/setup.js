const { expect, assert } = require('chai').use(require('chai-as-promised'));
const { setupLoader } = require('@openzeppelin/contract-loader');
const { primarySenderAddress } = require('../config');

const loader = setupLoader({
  provider: 'http://3.230.69.118:8545',
  defaultSender: primarySenderAddress,
  defaultGas: '20000000',
  defaultGasPrice: '100000000000'
});

const Vault = loader.truffle.fromArtifact('Vault', '0x01cEd4440F66f91733faA2252743Af17B25F9753');
const VaultFactory = loader.truffle.fromArtifact('VaultFactory', '0x38d4df14e5Eff055128F2128c9B94Ec423558Ac6');
const App = loader.truffle.fromArtifact('App', '0x68E20cd7633268075BbEe4e1cd6Ce25D75aef0dd');
const Archive = loader.truffle.fromArtifact('Archive', '0xb88435460371c754dbAEceeDc32FFb726C266111');

module.exports = {
  expect,
  assert,
  loader,
  contracts: {
    Vault,
    VaultFactory,
    App,
    Archive
  }
};
