import { $ } from 'bun'
import { Address } from 'viem'

export async function deployContract(contractName: string, rpc: string, from: Address): Promise<Address> {
  const result = await $`forge create --rpc-url ${rpc} --from ${from} ${contractName} --unlocked --json`.json()
  return result.deployedTo
}
