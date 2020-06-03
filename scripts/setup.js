const { exec } = require('child_process');
const cliCmd = './node_modules/.bin/oz';

const makeExecCallback = (callback) => (err, stderr) => {
  if (err) {
    throw err;
  } else if (stderr) {
    throw new Error(stderr);
  }

  callback();
};

const publishProject = () => exec(`${cliCmd} publish -n development --no-interactive`);

const addVault = () =>
  exec(`${cliCmd} add --all --push development --no-interactive`, makeExecCallback(publishProject));

const initProject = () => exec(`${cliCmd} init autonomous-voter --no-interactive`, makeExecCallback(addVault));

initProject();
