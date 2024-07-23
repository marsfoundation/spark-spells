import assert from 'node:assert'
import { type Address, encodeFunctionData } from 'viem'
import type { NetworkConfig } from './config'
import type { IEthereumClient } from './periphery/ethereum'

interface ExecuteSpellArgs {
  spellAddress: Address
  network: NetworkConfig
  ethereumClient: IEthereumClient
}

export async function executeSpell({ spellAddress, network, ethereumClient }: ExecuteSpellArgs): Promise<void> {
  const originalSpellExecutorBytecode = await ethereumClient.getBytecode({
    address: network.sparkSpellExecutor,
  })

  const spellBytecode = await ethereumClient.getBytecode({
    address: spellAddress,
  })
  assert(spellBytecode, `Spell not deployed (address=${spellAddress})`)
  await ethereumClient.setBytecode({
    address: network.sparkSpellExecutor,
    bytecode: spellBytecode,
  })

  await ethereumClient.sendTransaction({
    to: network.sparkSpellExecutor,
    data: encodeFunctionData({
      abi: [
        {
          inputs: [],
          name: 'execute',
          outputs: [],
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ],
      functionName: 'execute',
    }),
  })

  await ethereumClient.setBytecode({
    address: network.sparkSpellExecutor,
    bytecode: originalSpellExecutorBytecode,
  })
}
