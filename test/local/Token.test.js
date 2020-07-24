const { assert } = require('./setup');
const { tokenName, tokenSymbol, tokenSupply, tokenDecimal } = require('../../config');

describe('Token', function () {
  describe('State', function () {
    it('should have a valid token name', async function () {
      return assert.equal(await this.token.name(), tokenName);
    });

    it('should have a valid token symbol', async function () {
      return assert.equal(await this.token.symbol(), tokenSymbol);
    });

    it('should have a valid total supply', async function () {
      return assert.equal(await this.token.totalSupply(), tokenSupply);
    });

    it('should have a valid token decimal', async function () {
      return assert.equal(await this.token.decimals(), tokenDecimal);
    });

    it('should have all the tokens initially owned by the token contract', async function () {
      return assert.equal(await this.token.balanceOf(this.token.address), tokenSupply);
    });
  });
});
