const ganache = require('@celo/ganache-core');

const baklavaServer = ganache.server({
  gas: 20000000,
  gasLimit: 20000000,
  gasPrice: 100000000000,
  network_id: 40120,
  fork: 'https://geth.celoist.com',
  unlocked_accounts: ['0x57c445eaea6b8782b75a50e2069fc209386541f1']
});

baklavaServer.listen(8545, (err, baklava) => {
  if (err) {
    throw err;
  }

  console.log(baklava);
});
