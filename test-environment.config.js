module.exports = {
  setupProvider: (baseProvider) => {
    // Set provider host to locally-running ganache instance
    // This allows us to make RPC calls for testing purposes
    baseProvider.host = 'http://50.17.60.161:8546';

    return baseProvider;
  }
};
