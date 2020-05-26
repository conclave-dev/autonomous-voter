const isDev = process.env.NODE_ENV !== 'production';
const fork = isDev ? 'https://geth.celoist.com' : 'https://rpc.celoist.com';
const networkId = isDev ? 40120 : 40220;
const unlockedAccounts = isDev ? ['0x57c445eaea6b8782b75a50e2069fc209386541f1'] : [''];

module.exports = {
  node: {
    gas: 20000000,
    gasPrice: 100000000000,
    gasLimit: 20000000,
    allowUnlimitedContractSize: true,
    fork,
    hardfork: 'istanbul',
    network_id: networkId,
    unlocked_accounts: unlockedAccounts
  }
};
