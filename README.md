# Spark Spells

Install: `npm install .`

To run a spell against a new tenderly fork, run the following command (using mainnet as an example):

```bash
make execute-payload-mainnet payload=0x41D7c79aE5Ecba7428283F66998DedFD84451e0e
```

All non-payload contracts will be constant across deployments, but this can run against different chains. It is recommended to persist in files the addresses to use.
