const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('ProxyAdmin', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();

    const { logs } = await (await contracts.VaultFactory.deployed()).createInstance(
      encodeCall(
        'initializeVault',
        ['address', 'address', 'address'],
        [registryContractAddress, this.archive.address, primarySenderAddress]),
      {
        value: new BigNumber('1e17')
      }
    );
    const [instanceCreated, adminCreated] = logs;

    this.vault = await contracts.Vault.at(instanceCreated.args[0]);

    await this.vault.updateProxyAdmin(adminCreated.args[0]);
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
