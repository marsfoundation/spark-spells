const axios = require('axios');
const dotenv = require('dotenv');
const ethers = require('ethers');

dotenv.config({ path: `.env.${process.env.NODE_ENV}` });

const {
  ETHERSCAN_API_KEY,
  TENDERLY_USER,
  TENDERLY_PROJECT,
  TENDERLY_ACCESS_KEY,
  EXECUTOR,
  PAUSE_PROXY,
} = process.env;

const payload = process.argv[2];

const getContractName = async (_payload) => {
  try {
    const response = await axios.get(
      `https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${_payload}&apikey=${ETHERSCAN_API_KEY}`
    );

    return response.data.result[0].ContractName;
  } catch (error) {
    console.error('Error:', error);
  }
}

async function mainnetFork(_payload) {
  return await axios.post(
    `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`,
    {
      network_id: '1',
      chain_config: {
        chain_id: 11,
        shanghai_time: 1677557088,
      },
      alias: await getContractName(_payload),
    },
    {
      headers: {
        'X-Access-Key': TENDERLY_ACCESS_KEY,
      },
    }
  );
}

const runSpell = async () => {
  const fork = await mainnetFork(payload);

  const forkId = fork.data.simulation_fork.id;
  const rpcUrl = `https://rpc.tenderly.co/fork/${forkId}`;

  const forkUrl = `https://dashboard.tenderly.co/${TENDERLY_USER}/${TENDERLY_PROJECT}/fork/${forkId}`

  console.log("Fork URL:", forkUrl);

  const forkProvider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const pauseProxySigner = forkProvider.getSigner(PAUSE_PROXY);

  await pauseProxySigner.sendTransaction({
    from: PAUSE_PROXY,
    to: EXECUTOR,
    data: ExecutorAbi.encodeFunctionData('exec', [
      ethers.utils.hexZeroPad(payload.toLowerCase(), 20),
      PayloadAbi.encodeFunctionData('execute', [])
    ]),
  });
};

const ExecutorAbi = new ethers.utils.Interface([
  "function exec(address target, bytes calldata args)"
]);

const PayloadAbi = new ethers.utils.Interface(["function execute()"]);

runSpell();
