const axios = require('axios');
const dotenv = require('dotenv');
const ethers = require('ethers');

dotenv.config();

// assuming environment variables TENDERLY_USER, TENDERLY_PROJECT and TENDERLY_ACCESS_KEY are set
// https://docs.tenderly.co/other/platform-access/how-to-find-the-project-slug-username-and-organization-name
// https://docs.tenderly.co/other/platform-access/how-to-generate-api-access-tokens
const { TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY } = process.env;

async function mainnetFork() {
  return await axios.post(
    `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`,
    {
      network_id: '1',
      chain_config: {
        chain_id: 11,
        shanghai_time: 1677557088,
      },
      name: "Mainnet Fork" + Date.now(),
    },
    {
      headers: {
        'X-Access-Key': TENDERLY_ACCESS_KEY,
      },
    }
  );
}


const runSpell = async () => {
  const fork = await mainnetFork();

  const forkId = fork.data.simulation_fork.id;
  const rpcUrl = `https://rpc.tenderly.co/fork/${forkId}`;

  console.log('Fork URL\n\t' + rpcUrl);

  const forkProvider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const EXECUTOR    = "0x3300f198988e4C9C63F75dF86De36421f06af8c4";
  const ACL_MANAGER = "0xdA135Cd78A086025BcdC87B038a1C462032b510C"
  const PAUSE_PROXY = "0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB";
  const PAYLOAD     = "0x41D7c79aE5Ecba7428283F66998DedFD84451e0e";  // TODO: Maybe Deploy as part of this script

  const pauseProxySigner = forkProvider.getSigner(PAUSE_PROXY);

  await pauseProxySigner.sendTransaction({
    from: PAUSE_PROXY,
    to: ACL_MANAGER,
    data: AclManagerAbi.encodeFunctionData('addPoolAdmin', [EXECUTOR]),
  });

  await pauseProxySigner.sendTransaction({
    from: PAUSE_PROXY,
    to: EXECUTOR,
    data: ExecutorAbi.encodeFunctionData('exec', [
      ethers.utils.hexZeroPad(PAYLOAD.toLowerCase(), 20),
      PayloadAbi.encodeFunctionData('execute', [])
    ]),
  });
};

const ExecutorAbi = new ethers.utils.Interface([
  "function exec(address target, bytes calldata args)"
]);

const PayloadAbi = new ethers.utils.Interface(["function execute()"]);

const AclManagerAbi = new ethers.utils.Interface(["function addPoolAdmin(address admin)"]);

runSpell();
