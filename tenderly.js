const axios = require('axios');
const dotenv = require('dotenv');
const ethers = require('ethers');

dotenv.config();

const { ETHERSCAN_API_KEY, TENDERLY_USER, TENDERLY_PROJECT, TENDERLY_ACCESS_KEY } = process.env;

// Get the command-line arguments
const args = process.argv.slice(2);

// Function to process the flagged parameters
function processFlags() {
  const flags = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith('--')) {
      // Remove the leading '--' from the flag name
      const flag = arg.slice(2);

      // Check if the flag has a value
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        // Assign the value to the flag
        flags[flag] = args[i + 1];
        i++; // Skip the next argument
      } else {
        // Flag is present without a value
        flags[flag] = true;
      }
    }
  }

  return flags;
}

const getContractName = async (payload) => {
  try {
    const response = await axios.get(
      `https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${payload}&apikey=${ETHERSCAN_API_KEY}`
    );

    return response.data.result[0].ContractName;
  } catch (error) {
    console.error('Error:', error);
  }
}

async function mainnetFork(payload) {
  return await axios.post(
    `https://api.tenderly.co/api/v1/account/${TENDERLY_USER}/project/${TENDERLY_PROJECT}/fork`,
    {
      network_id: '1',
      chain_config: {
        chain_id: 11,
        shanghai_time: 1677557088,
      },
      alias: await getContractName(payload),
    },
    {
      headers: {
        'X-Access-Key': TENDERLY_ACCESS_KEY,
      },
    }
  );
}

const runSpell = async (flaggedParams) => {
  const { aclManager, executor, payload, pauseProxy } = flaggedParams;

  const fork = await mainnetFork(payload);

  const forkId = fork.data.simulation_fork.id;
  const rpcUrl = `https://rpc.tenderly.co/fork/${forkId}`;

  const forkUrl = `https://dashboard.tenderly.co/${TENDERLY_USER}/${TENDERLY_PROJECT}/fork/${forkId}`

  console.log("Fork URL:", forkUrl);

  const forkProvider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const pauseProxySigner = forkProvider.getSigner(pauseProxy);

  // TODO: This can be removed after the next spell
  await pauseProxySigner.sendTransaction({
    from: pauseProxy,
    to: aclManager,
    data: AclManagerAbi.encodeFunctionData('addPoolAdmin', [executor]),
  });

  await pauseProxySigner.sendTransaction({
    from: pauseProxy,
    to: executor,
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

const AclManagerAbi = new ethers.utils.Interface(["function addPoolAdmin(address admin)"]);

runSpell(processFlags());
