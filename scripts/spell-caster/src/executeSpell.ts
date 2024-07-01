import assert from 'node:assert'
import { Address, encodeFunctionData } from 'viem'
import { getViemClient } from './blockchain/ViemClient'
import { ChainConfig } from './config'

export async function executeSpell({
  spellAddress,
  chain,
  client,
}: {
  spellAddress: Address
  chain: ChainConfig
  client: ReturnType<typeof getViemClient>
}) {
  const code = await client.getCode({ address: spellAddress })
  assert(code, `Spell not deployed (address=${spellAddress})`)
  await client.setCode({
    address: chain.sparkSpellExecutor,
    bytecode: code,
  })

  await client.sendTransaction({
    to: chain.sparkSpellExecutor,
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
}
