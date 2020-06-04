const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');
const { expect } = require('./setup');

const BaseAdminUpgradeabilityProxy = contract.fromArtifact('BaseAdminUpgradeabilityProxy');

describe('Vault', function () {
  describe('Factory', function () {
    describe('Initialize', function () {
      it('should initialize with an App address', async function () {
        expect(typeof this.vaultFactory.address).to.equal('string');
        expect(this.vaultFactory.address.length).to.equal(42);
        expect(this.vaultFactory.address).to.not.equal(this.address.zero);
      });

      it('should not create a vault instance with insufficient initial deposit', async function () {
        const vaultInitializeCall = encodeCall('initialize', ['address'], [this.address.registryContract]);
        const depositAmount = '0';

        await expect(
          this.vaultFactory.createInstance(vaultInitializeCall, {
            from: this.address.primary,
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
      it('should initialize with a Registry contract and a Vault admin', async function () {
        const Vault = await BaseAdminUpgradeabilityProxy.at(this.vault.address);
        expect(Vault.admin.call(this.defaultTx)).to.be.rejectedWith(Error);
      });

      it('should have a registered Celo account', async function () {
        const accounts = await this.kit.contracts.getAccounts();
        expect(await accounts.isAccount(this.vault.address)).to.equal(true);
      });

      it('should be setting the owner account as vault owner', async function () {
        expect(await this.vault.owner()).to.equal(this.address.primary);
      });

      it('should have an initial deposit', async function () {
        expect((await this.vault.unmanagedGold()).toString()).to.equal(this.defaultTxValue.toString());
      });
    });

    describe('Deposit', function () {
      it('should be able to deposit using owner account', async function () {
        const totalDeposit = this.defaultTxValue.plus(this.defaultTxValue).toString();

        await this.vault.deposit({
          from: this.address.primary,
          value: this.defaultTxValue.toString()
        });
        expect((await this.vault.unmanagedGold()).toString()).to.equal(totalDeposit);
      });

      it('should not be able to deposit using non-owner account', async function () {
        await expect(
          this.vault.deposit({
            from: this.address.secondary,
            value: this.defaultTxValue
          })
        ).to.be.rejectedWith(
          'Returned error: VM Exception while processing transaction: revert Ownable: caller is not the owner -- Reason given: Ownable: caller is not the owner.'
        );
      });
    });
  });

  describe('Admin', function () {
    describe('Initialize', function () {
      it('should have a vault-admin instance with valid address created for the user vault', async function () {
        const adminAddress = await this.vault.vaultAdmin.call(this.defaultTx);

        expect(typeof adminAddress).to.equal('string');
        expect(adminAddress.length).to.equal(42);
        expect(adminAddress).to.not.equal(this.address.zero);
      });

      it('should only allow access for vault upgrade to the vault owner', async function () {
        console.log(await this.vaultAdmin.owner());
        await expect(
          this.vaultAdmin.upgradeVault(this.vault.address, { from: this.address.secondary })
        ).to.be.rejectedWith('Returned error: VM Exception while processing transaction: revert');

        await expect(this.vaultAdmin.upgradeVault(this.vault.address, this.defaultTx)).to.be.fulfilled;
      });
    });
  });
});
