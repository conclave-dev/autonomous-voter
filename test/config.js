require('dotenv').config();

const chai = require('chai');
const BigNumber = require('bignumber.js');
const { newKit } = require('@celo/contractkit');

chai.use(require('chai-as-promised'));

const expect = chai.expect;
const kit = newKit('http://localhost:8545');
const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS } = process.env;
const REGISTRY_CONTRACT_ADDRESS = '0x000000000000000000000000000000000000ce10';
const TOKEN_BASE_MULTIPLIER = new BigNumber('1e18');

module.exports = {
  expect,
  kit,
  APP_CONTRACT_ADDRESS,
  DEFAULT_SENDER_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  TOKEN_BASE_MULTIPLIER
};
