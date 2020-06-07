#!/bin/bash

export PROTOCOL_BRANCH=""

[ ! -d "node_modules/" ] && npm install

if [ -z ${1+x} ]; then
  PROTOCOL_BRANCH="master"
else
  PROTOCOL_BRANCH="$1"
fi

[ ! -d "node_modules/celo-monorepo" ] && \
echo "=== Cloning https://github.com/celo-org/celo-monorepo/tree/$PROTOCOL_BRANCH to node_modules/ ===" && \
git clone --single-branch --branch $PROTOCOL_BRANCH https://github.com/celo-org/celo-monorepo node_modules/celo-monorepo/

echo "Done"
