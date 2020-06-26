const Migrations = artifacts.require('Migrations');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;

  await deployer.deploy(Migrations, { overwrite });
};
