#!/bin/bash

echo "Initializing Eth-Security-Toolbox"

docker pull trailofbits/eth-security-toolbox

echo "Starting analyzer using Slither"

docker run -it --name toolbox -d -v $(pwd):/share trailofbits/eth-security-toolbox

docker exec toolbox bash -t -c "solc-select 0.5.8 && cd /share && rm build/contracts/* && truffle compile --all && slither . --ignore-compile && exit 1"

docker rm toolbox -f
