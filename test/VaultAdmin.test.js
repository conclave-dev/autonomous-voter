const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { expect, loader, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

const { VaultFactory } = contracts;

describe('VaultAdmin', () => {
  before(async () => {
    const { logs } = await VaultFactory.createInstance(
      encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
      {
        from: primarySenderAddress,
        value: new BigNumber('1e17')
      }
    );
    const [instanceCreated, adminCreated] = logs;

    this.vault = loader.truffle.fromArtifact('Vault', instanceCreated.args[0]);

    await this.vault.updateVaultAdmin(adminCreated.args[0]);
  });

  describe('initialize(App _app, address _owner)', () => {
    it('should only allow the owner to upgrade', async () => {
      const vaultAdmin = await loader.truffle.fromArtifact('VaultAdmin', await this.vault.vaultAdmin());

      await expect(
        vaultAdmin.upgradeVault(this.vault.address, this.vault.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
      await expect(vaultAdmin.upgradeVault(this.vault.address, this.vault.address)).to.be.fulfilled;
    });
  });
});
