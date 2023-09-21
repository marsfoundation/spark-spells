# Spark Spells

Install: `npm install .`

To run a spell against a new tenderly fork, run the following command (using mainnet as an example):

```bash
make execute-payload-mainnet payload=0x41D7c79aE5Ecba7428283F66998DedFD84451e0e
```

All non-payload contracts will be constant across deployments, but this can run against different chains. It is recommended to persist in files the addresses to use.

### Spell simulator

To run a spell against a new anvil fork, run the following command 
```bash
sh scripts/fork-and-cast-spell.sh <spellPathOrAddress> <spellExecutor> <forkUrl> <forkBlockNumber> <port>
```

Where 
```<forkBlockNumber>``` is optional with latest as default
```<port>``` is optional with 8545 as default

Example for SparkGnosis_20230927 proposal

```bash
sh scripts/fork-and-cast-spell.sh src/proposals/20230927/SparkGnosis_20230927.sol:SparkGnosis_20230927 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A https://rpc.ankr.com/gnosis 30031699
```

or using already deployed spell address

```bash
sh scripts/fork-and-cast-spell.sh 0x1472B7d120ab62D60f60e1D804B3858361c3C475 0xc4218C1127cB24a0D6c1e7D25dc34e10f2625f5A https://rpc.ankr.com/gnosis 30031699
```
