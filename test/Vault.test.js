const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts, kit } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Vault', () => {
  before(async () => {
    const { logs } = await (await contracts.VaultFactory.deployed()).createInstance(
      encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
      {
        value: new BigNumber('1e17')
      }
    );

    this.vault = await contracts.Vault.at(logs[0].args[0]);
  });

  describe('initializeVault(address registry, address owner)', () => {
    it('should initialize with an owner and register a Celo account', async () => {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vault.owner(), primarySenderAddress, 'Does not have owner set');
      assert.equal(await accounts.isAccount(this.vault.address), true, 'Not a registered Celo account');
    });
  });

  describe('deposit()', () => {
    it('should enable owners to make deposits', async () => {
      const deposits = new BigNumber(await this.vault.unmanagedGold());
      const newDeposit = 1;

      await this.vault.deposit({
        value: newDeposit
      });

      assert.equal(
        new BigNumber(await this.vault.unmanagedGold()).toFixed(0),
        deposits.plus(newDeposit).toFixed(0),
        'Deposits did not increase'
      );
    });

    it('should not be able to deposit from a non-owner account', async () => {
      await expect(
        this.vault.deposit({
          from: secondarySenderAddress,
          value: 1
        })
      ).to.be.rejectedWith(Error);
    });
  });
});
