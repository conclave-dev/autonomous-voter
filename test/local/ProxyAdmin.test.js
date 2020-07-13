const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('ProxyAdmin', function () {
  before(async function () {
    // Create a vault instance for proxy admin tests
    await this.vaultFactory.createInstance(this.packageName, 'Vault', this.registryContractAddress, {
      value: new BigNumber('1e17')
    });

    this.testVaultInstance = await this.contracts.Vault.at(
      (await this.archive.getVaultsByOwner(this.primarySender)).pop()
    );
    this.testProxyAdmin = await this.contracts.ProxyAdmin.at(await this.testVaultInstance.proxyAdmin());
  });

  describe('State', function () {
    it('should have owner set', async function () {
      return assert.equal(await this.proxyAdmin.owner(), this.primarySender);
    });

    it('should have app set', async function () {
      return assert.equal(await this.proxyAdmin.app(), this.app.address);
    });
  });

  describe('Methods ✅', function () {
    it('should allow the owner to upgrade the proxy with a valid implementation', async function () {
      await this.testProxyAdmin.upgradeProxyImplementation(this.testVaultInstance.address, this.vault.address);

      return assert.isFulfilled(this.testVaultInstance.deposit({ value: 1 }));
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow the owner to upgrade the proxy with an invalid implementation', async function () {
      // Setting the implementation to a vault instance will cause many vault-specific txs to revert
      await this.testProxyAdmin.upgradeProxyImplementation(this.testVaultInstance.address, this.vaultInstance.address);

      return assert.isRejected(this.testVaultInstance.deposit({ value: 1 }));
    });
  });
});
