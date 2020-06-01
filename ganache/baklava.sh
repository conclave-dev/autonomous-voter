#!/bin/bash

export FORK="https://geth.celoist.com"
export MNEMONIC="concert load couple harbor equip island argue ramp clarify fence smart topic"
export NETWORK_ID="40120"
export GAS_LIMIT="20000000"
export UNLOCK_PRIMARY="0x5409ed021d9299bf6814279a6a1411a7e866a631"
export UNLOCK_SECONDARY="0x48fF477891eCcd5177Ec8d66210EC2308fAc6eD6"

ganache-cli --fork $FORK --networkId $NETWORK_ID --gasLimit $GAS_LIMIT \
--accounts 2 --mnemonic $MNEMONIC --unlock $UNLOCK_PRIMARY --unlock $UNLOCK_SECONDARY
