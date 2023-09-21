#!/usr/bin/env bash
set -e

trap "kill 0" EXIT

spell_path_or_address=$1
spell_executor=$2
anvil_fork_url=$3
anvil_fork_block_number=$4
port=${5-8545}
anvil_priv_key=${6-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}

rpc_url=http://localhost:$port

if [[ -n $anvil_fork_block_number ]]; then
    extra_params="--fork-block-number $anvil_fork_block_number"
else
    extra_params=""
fi

anvil --fork-url $anvil_fork_url --port ${port} $extra_params &

sleep 3

if [[ $spell_path_or_address == 0x* && ${#spell_path_or_address} -eq 42 ]]; then
    spell_addr=$spell_path_or_address
else
    forge build
    spell_addr=$(forge create $spell_path_or_address --private-key $anvil_priv_key --rpc-url $rpc_url | grep "Deployed to:" | awk '{print $3}')
fi

cd "$(dirname "$0")"
sh ./cast-spell.sh $anvil_priv_key $spell_addr $spell_executor $rpc_url

wait

