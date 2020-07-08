const Migrations = artifacts.require('Migrations');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;
  const deployMigrations =
    overwrite || (await Migrations.deployed()).address === '0x0000000000000000000000000000000000000000';

  await deployer.deploy(Migrations, { overwrite: deployMigrations });
};
