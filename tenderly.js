const axios = require('axios');
const dotenv = require('dotenv');
const ethers = require('ethers');

dotenv.config();

const { ETHERSCAN_API_KEY, TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY } = process.env;

const PAYLOAD = "0x41D7c79aE5Ecba7428283F66998DedFD84451e0e";  // Fill in with newest payload address

const getContractName = async () => {
  try {
    const response = await axios.get(
      `https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${PAYLOAD}&apikey=${ETHERSCAN_API_KEY}`
    );

    return response.data.result[0].ContractName;
  } catch (error) {
    console.error('Error:', error);
  }
}

async function mainnetFork() {
  return await axios.post(
    `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`,
    {
      network_id: '1',
      chain_config: {
        chain_id: 11,
        shanghai_time: 1677557088,
      },
      alias: await getContractName(),
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

  const forkProvider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const EXECUTOR    = "0x3300f198988e4C9C63F75dF86De36421f06af8c4";
  const ACL_MANAGER = "0xdA135Cd78A086025BcdC87B038a1C462032b510C"
  const PAUSE_PROXY = "0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB";

  const pauseProxySigner = forkProvider.getSigner(PAUSE_PROXY);

  // TODO: This can be removed after the next spell
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
