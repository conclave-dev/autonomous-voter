module.exports = {
  setupProvider: (baseProvider) => {
    baseProvider.host = 'http://localhost:8545';
    return baseProvider;
  }
};
