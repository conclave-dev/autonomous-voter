#!/bin/bash

[ ! -d "node_modules/" ] && npm install

[ ! -d "node_modules/celo-monorepo" ] && git clone --single-branch --branch baklava https://github.com/celo-org/celo-monorepo node_modules/celo-monorepo/

node ./scripts/setup.js
