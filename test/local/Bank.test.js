const { assert } = require('./setup');
const { tokenName, tokenSymbol, tokenSupply, tokenDecimal } = require('../../config');

describe('Bank', function () {
  describe('State', function () {
    it('should have a valid token name', async function () {
      return assert.equal(await this.bank.name(), tokenName);
    });

    it('should have a valid token symbol', async function () {
      return assert.equal(await this.bank.symbol(), tokenSymbol);
    });

    it('should have a valid total supply', async function () {
      return assert.equal(await this.bank.totalSupply(), tokenSupply);
    });

    it('should have a valid token decimal', async function () {
      return assert.equal(await this.bank.decimals(), tokenDecimal);
    });

    it('should have all the tokens initially owned by the token contract', async function () {
      return assert.equal(await this.bank.balanceOf(this.bank.address), tokenSupply);
    });
  });
});
