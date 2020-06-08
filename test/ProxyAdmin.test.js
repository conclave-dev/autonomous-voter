const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { expect, loader, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

const { VaultFactory } = contracts;

describe('ProxyAdmin', () => {
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
    console.log(this.vault.updateProxyAdmin);
    try {
      await this.vault.updateProxyAdmin(adminCreated.args[0], { from: primarySenderAddress });
    } catch (err) {
      console.log(err);
    }
  });

  describe('initialize(App _app, address _owner)', () => {
    it('should only allow the owner to upgrade', async () => {
      const proxyAdmin = await loader.truffle.fromArtifact('ProxyAdmin', await this.vault.proxyAdmin());

      await expect(
        proxyAdmin.upgradeProxy(this.vault.address, this.vault.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
      await expect(proxyAdmin.upgradeProxy(this.vault.address, this.vault.address)).to.be.fulfilled;
    });
  });
});
