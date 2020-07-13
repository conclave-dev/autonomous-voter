const Migrations = artifacts.require('Migrations');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;
  let deployMigrations;

  try {
    deployMigrations =
      overwrite || (await Migrations.deployed()).address === '0x0000000000000000000000000000000000000000';
  } catch (err) {
    console.error(err);
  }

  await deployer.deploy(Migrations, { overwrite: deployMigrations });
};
