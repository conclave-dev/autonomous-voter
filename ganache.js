const ganacheCore = require('ganache-core');

const networkId = 40120; // mainnet
const fork = 'https://baklava.celoist.com'; // baklava node rpc
const port = 8545;
const host = 'localhost';
const callback = () => null;

const ganacheServer = ganacheCore.server({
  network_id: networkId,
  fork,
  hardfork: 'istanbul',
  total_accounts: 3,
  gasLimit: 20000000,
  gasPrice: 100000000000,
  default_balance_ether: 200000000,
  mnemonic: 'concert load couple harbor equip island argue ramp clarify fence smart topic'
});

ganacheServer.listen(port, host, callback);
