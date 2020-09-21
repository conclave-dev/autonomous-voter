const ganacheCore = require('ganache-core');
const { alfajoresRpcAPI, alfajoresNetworkID } = require('./config');

const port = 8545;
const host = 'localhost';
const callback = () => null;

const ganacheServer = ganacheCore.server({
  network_id: alfajoresNetworkID,
  fork: alfajoresRpcAPI,
  hardfork: 'istanbul',
  total_accounts: 3,
  gasLimit: 20000000,
  gasPrice: 100000000000,
  default_balance_ether: 200000000,
  mnemonic: 'concert load couple harbor equip island argue ramp clarify fence smart topic'
});

ganacheServer.listen(port, host, callback);
