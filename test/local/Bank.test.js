const { assert } = require('./setup');
const { tokenName, tokenSymbol, tokenDecimal } = require('../../config');

describe('Bank', function () {
  describe('State', function () {
    it('should have a valid token name', async function () {
      return assert.equal(await this.bank.name(), tokenName);
    });

    it('should have a valid token symbol', async function () {
      return assert.equal(await this.bank.symbol(), tokenSymbol);
    });

    it('should have a valid initial total supply', async function () {
      return assert.equal(await this.bank.totalSupply(), 0);
    });

    it('should have a valid token decimal', async function () {
      return assert.equal(await this.bank.decimals(), tokenDecimal);
    });

    it('should have the correct initial balance for non-holders', async function () {
      return assert.equal(await this.bank.balanceOf(this.bank.address), 0);
    });
  });
});
