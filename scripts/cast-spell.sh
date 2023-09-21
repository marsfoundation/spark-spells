#!/usr/bin/env bash
set -e

anvil_priv_key=$1 
spell_addr=$2
spell_executor=$3
rpc_url=$4

user_address=$(cast wallet address --private-key $anvil_priv_key)

echo "Replacing code of spell (${spell_addr:0:7}) with executor (${spell_executor:0:7})..."
code=$(cast rpc eth_getCode $spell_addr latest --rpc-url $rpc_url)
cast rpc anvil_setCode $spell_executor $code --rpc-url $rpc_url
cast send --private-key $anvil_priv_key $spell_executor --rpc-url $rpc_url --from $user_address "execute()"

