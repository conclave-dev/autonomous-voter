#!/bin/bash

export FORK="https://geth.celoist.com"
export MNEMONIC="concert load couple harbor equip island argue ramp clarify fence smart topic"
export NETWORK_ID="40120"
export GAS_LIMIT="20000000"
export UNLOCK_PRIMARY="0x5409ed021d9299bf6814279a6a1411a7e866a631"
export UNLOCK_SECONDARY="0x57c445eaea6b8782b75a50e2069fc209386541f1"

ganache-cli --fork $FORK --mnemonic $MNEMONIC --networkId $NETWORK_ID --gasLimit $GAS_LIMIT --unlock $UNLOCK_PRIMARY --unlock $UNLOCK_SECONDARY
