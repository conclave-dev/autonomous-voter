require('dotenv').config();

const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS } = process.env;

module.exports = {
  APP_CONTRACT_ADDRESS,
  DEFAULT_SENDER_ADDRESS
};
