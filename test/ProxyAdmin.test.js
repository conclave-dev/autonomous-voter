const BigNumber = require('bignumber.js');
const { expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('ProxyAdmin', function () {
  before(async function () {
    this.vaultFactory.createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    const vaults = await this.archive.getVaultsByOwner(primarySenderAddress);

    this.vaultInstance = await contracts.Vault.at(vaults[vaults.length - 1]);
    this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
  });

  describe('initialize(App _app, address _owner)', function () {
    it('should only allow the owner to upgrade', function () {
      return expect(this.proxyAdmin.upgradeProxy(this.vaultInstance.address, this.vaultInstance.address)).to.be
        .fulfilled;
    });

    it('should not allow an unknown account to upgrade', function () {
      return expect(
        this.proxyAdmin.upgradeProxy(this.vaultInstance.address, this.vaultInstance.address, {
          from: secondarySenderAddress
        })
      ).to.be.rejectedWith(Error);
    });
  });
});
