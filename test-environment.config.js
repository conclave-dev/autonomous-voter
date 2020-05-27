module.exports = {
  setupProvider: (baseProvider) => {
    // Set provider host to locally-running ganache instance
    // This allows us to make RPC calls for testing purposes
    baseProvider.host = 'http://localhost:8545';

    return baseProvider;
  }
};
