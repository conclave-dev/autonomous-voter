const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('VaultAdmin', () => {
  before(async () => {
    const { logs } = await (await contracts.VaultFactory.deployed()).createInstance(
      encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
      {
        value: new BigNumber('1e17')
      }
    );
    const [instanceCreated, adminCreated] = logs;

    this.vault = await contracts.Vault.at(instanceCreated.args[0]);

    await this.vault.updateVaultAdmin(adminCreated.args[0]);
  });

  describe('initialize(App _app, address _owner)', () => {
    it('should only allow the owner to upgrade', async () => {
      const vaultAdmin = await contracts.VaultAdmin.at(await this.vault.vaultAdmin());

      await expect(
        vaultAdmin.upgradeVault(this.vault.address, this.vault.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
      await expect(vaultAdmin.upgradeVault(this.vault.address, this.vault.address)).to.be.fulfilled;
    });
  });
});
