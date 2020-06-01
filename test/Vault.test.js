const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');
const {
  defaultTx,
  expect,
  kit,
  DEFAULT_SENDER_ADDRESS,
  ZERO_ADDRESS,
  SECONDARY_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  INITIAL_DEPOSIT_AMOUNT
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
      it('should initialize with a Registry contract and owner address', async function () {
        const Vault = await BaseAdminUpgradeabilityProxy.at(this.vault.address);
        const isAdmin = await Vault.admin.call(defaultTx);

        await expect(Vault.admin.call({ from: SECONDARY_ADDRESS })).to.be.rejectedWith(Error);
        expect(isAdmin.toLowerCase()).to.equal(DEFAULT_SENDER_ADDRESS);
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
        expect((await this.vault.getUnmanagedGold()).toString()).to.equal(INITIAL_DEPOSIT_AMOUNT);
      });
    });
  });
});
