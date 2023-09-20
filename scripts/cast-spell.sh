#!/usr/bin/env bash
set -e

anvil_priv_key=$1 
spell_addr=$2
spell_executor=$3

echo "Replacing code of spell (${spell_addr:0:7}) with executor (${spell_executor:0:7})..."
code=$(cast rpc eth_getCode $spell_addr latest)
cast rpc anvil_setCode $spell_executor $code
cast send --private-key $anvil_priv_key $spell_executor "execute()"