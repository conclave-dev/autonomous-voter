// Use Celo ganache fork instead of OpenZeppelin's
const ganache = require('@celo/ganache-core');

const baklavaServer = ganache.server({
  gas: 20000000,
  gasLimit: 20000000,
  gasPrice: 100000000000,
  network_id: 40120,
  fork: 'https://geth.celoist.com',
  default_balance_ether: 200000000,
  mnemonic: 'concert load couple harbor equip island argue ramp clarify fence smart topic',
  from: '0x5409ed021d9299bf6814279a6a1411a7e866a631',
  total_accounts: 1
});

baklavaServer.listen(8545, (err, baklava) => {
  if (err) {
    throw err;
  }

  console.log(baklava);
});
