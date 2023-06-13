# Spark Spells

To run a spell against a new tenderly fork, run the following command (using mainnet as an example):

```bash
source .env
source .env.mainnet
node tenderly.js --aclManager $ACL_MANAGER --executor $EXECUTOR --pauseProxy $PAUSE_PROXY --payload 0x41D7c79aE5Ecba7428283F66998DedFD84451e0e
```

All non-payload contracts will be constant across deployments, but this can run against different chains. It is recommended to persist in files the addresses to use.
