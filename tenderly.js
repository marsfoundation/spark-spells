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
    },
    {
      headers: {
        'X-Access-Key': TENDERLY_ACCESS_KEY,
      },
    }
  );
}


const runSpell = async () => {
  console.time('Fork Creation');
  const fork = await mainnetFork();
  console.timeEnd('Fork Creation');

  const forkId = fork.data.simulation_fork.id;
  const rpcUrl = `https://rpc.tenderly.co/fork/${forkId}`;
  // const rpcUrl = 'https://rpc.tenderly.co/fork/###-###-###-###';
  console.log('Fork URL\n\t' + rpcUrl);

  const forkProvider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
  const EXECUTOR = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

  const pauseProxySigner = forkProvider.getSigner(PAUSE_PROXY)

  // -------- This code doesn't work -----------

  // const ownerAddress = '0xdc6bdc37b2714ee601734cf55a05625c9e512461';

  // await pauseProxySigner.sendTransaction({
  //   from: PAUSE_PROXY,
  //   // to: EXECUTOR,
  //   to: "0x6b175474e89094c44da98b954eedeac495271d0f",
  //   data: DaiAbi.encodeFunctionData('mint', [
  //     ethers.utils.hexZeroPad(ownerAddress.toLowerCase(), 20),
  //     ethers.utils.parseEther('1.0'),
  //   ]),
  //   gasLimit: 800000,
  // });

  // -------- This code doesn't work -----------

  // This is from the example code and works
  const [minterAddress, ownerAddress, spenderAddress, receiverAddress] =
    await forkProvider.listAccounts();

  const [minterSigner, ownerSigner, spenderSigner] = [
    forkProvider.getSigner(minterAddress),
    forkProvider.getSigner(ownerAddress),
    forkProvider.getSigner(spenderAddress),
    forkProvider.getSigner(receiverAddress),
  ];

  await minterSigner.sendTransaction({
    from: minterAddress,
    to: '0x6b175474e89094c44da98b954eedeac495271d0f',
    data: DaiAbi.encodeFunctionData('mint', [
      ethers.utils.hexZeroPad(ownerAddress.toLowerCase(), 20),
      ethers.utils.parseEther('1.0'),
    ]),
    gasLimit: 800000,
  });
};

const DaiAbi = new ethers.utils.Interface([
  {
    constant: false,
    inputs: [
      { internalType: 'address', name: 'usr', type: 'address' },
      { internalType: 'uint256', name: 'wad', type: 'uint256' },
    ],
    name: 'mint',
    outputs: [],
    payable: false,
    stateMutability: 'nonpayable',
    type: 'function',
  },
]);

runSpell();
