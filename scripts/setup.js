const fs = require('fs');
const { exec } = require('child_process');
const cliCmd = './node_modules/.bin/oz';
const {
  networks: { development }
} = require('../networks');

const DEFAULT_SENDER_ADDRESS = '0x5409ed021d9299bf6814279a6a1411a7e866a631';

const setTestEnvironmentVars = () => {
  const { app } = JSON.parse(fs.readFileSync(`.openzeppelin/dev-${development.networkId}.json`).toString());
  const appContractAddress = `APP_CONTRACT_ADDRESS=${app.address}`;
  const defaultSenderAddress = `DEFAULT_SENDER_ADDRESS=${DEFAULT_SENDER_ADDRESS}`;

  return fs.writeFileSync('.env', `${appContractAddress}\n${defaultSenderAddress}`);
};

const makeExecCallback = (callback) => (err, stderr) => {
  if (err) {
    throw err;
  } else if (stderr) {
    throw new Error(stderr);
  }

  callback();
};

const publishProject = () =>
  exec(
    `${cliCmd} publish -n development -f ${DEFAULT_SENDER_ADDRESS} --no-interactive`,
    makeExecCallback(setTestEnvironmentVars)
  );

const addVault = () =>
  exec(`${cliCmd} add --all --push development --no-interactive`, makeExecCallback(publishProject));

const initProject = () => exec(`${cliCmd} init autonomous-voter --no-interactive`, makeExecCallback(addVault));

initProject();
