const BigNumber = require('bignumber.js');
const { expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('ProxyAdmin', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();

    await (await contracts.VaultFactory.deployed()).createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    const vaults = await this.archive.getVaultOwner(primarySenderAddress);
    this.vault = await contracts.Vault.at(vaults[vaults.length - 1]);
  });

  describe('initialize(App _app, address _owner)', () => {
    it('should only allow the owner to upgrade', async () => {
      const proxyAdmin = await contracts.ProxyAdmin.at(await this.vault.proxyAdmin());

      await expect(
        proxyAdmin.upgradeProxy(this.vault.address, this.vault.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
      await expect(proxyAdmin.upgradeProxy(this.vault.address, this.vault.address)).to.be.fulfilled;
    });
  });
});
