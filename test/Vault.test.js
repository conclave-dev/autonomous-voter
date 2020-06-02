const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const {
  defaultTx,
  APP_CONTRACT_ADDRESS,
  expect,
  kit,
  DEFAULT_SENDER_ADDRESS,
  ZERO_ADDRESS,
  SECONDARY_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  DEPOSIT_AMOUNT
} = require('./setup');

const BaseAdminUpgradeabilityProxy = contract.fromArtifact('BaseAdminUpgradeabilityProxy');

describe('Vault', function () {
  describe('Factory', function () {
    describe('Initialize', function () {
      it('should initialize with an App address', async function () {
        expect(typeof this.vaultFactory.address).to.equal('string');
        expect(this.vaultFactory.address.length).to.equal(42);
        expect(this.vaultFactory.address).to.not.equal(ZERO_ADDRESS);
      });

      it('should not create a vault instance with insufficient initial deposit', async function () {
        const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);
        const depositAmount = '0';

        await expect(
          this.vaultFactory.createInstance(vaultInitializeCall, {
            from: DEFAULT_SENDER_ADDRESS,
            value: depositAmount
          })
        ).to.be.rejectedWith(
          'Returned error: VM Exception while processing transaction: revert Insufficient funds for initial deposit -- Reason given: Insufficient funds for initial deposit.'
        );
      });
    });
  });

  describe('Instance', function () {
    describe('Initialize', function () {
      it('should initialize with a Registry contract and admin address', async function () {
        const Vault = await BaseAdminUpgradeabilityProxy.at(this.vault.address);
        const isAdmin = await Vault.admin.call({ from: APP_CONTRACT_ADDRESS });

        await expect(Vault.admin.call(defaultTx)).to.be.rejectedWith(Error);
        expect(isAdmin).to.equal(APP_CONTRACT_ADDRESS);
      });

      it('should have a registered Celo account', async function () {
        const accounts = await kit.contracts.getAccounts();
        expect(await accounts.isAccount(this.vault.address)).to.equal(true);
      });

      it('should have the owner address whitelisted as an admin', async function () {
        expect(await this.vault.isWhitelistAdmin(SECONDARY_ADDRESS)).to.equal(false);
        expect(await this.vault.isWhitelistAdmin(DEFAULT_SENDER_ADDRESS)).to.equal(true);
      });

      it('should have an initial deposit', async function () {
        expect((await this.vault.unmanagedGold()).toString()).to.equal(DEPOSIT_AMOUNT);
      });
    });

    describe('Deposit', function () {
      it('should be able to deposit using owner account', async function () {
        const deposit = new BigNumber(DEPOSIT_AMOUNT);
        const totalDeposit = new BigNumber(DEPOSIT_AMOUNT).plus(deposit).toString();

        await this.vault.deposit({
          from: DEFAULT_SENDER_ADDRESS,
          value: deposit.toString()
        });
        expect((await this.vault.unmanagedGold()).toString()).to.equal(totalDeposit);
      });

      it('should not be able to deposit using non-owner account', async function () {
        await expect(
          this.vault.deposit({
            from: SECONDARY_ADDRESS,
            value: DEPOSIT_AMOUNT
          })
        ).to.be.rejectedWith(
          'Returned error: VM Exception while processing transaction: revert WhitelistAdminRole: caller does not have the WhitelistAdmin role -- Reason given: WhitelistAdminRole: caller does not have the WhitelistAdmin role.'
        );
      });
    });
  });
});
