import { http, Address, SetCodeParameters, createWalletClient, publicActions } from 'viem'
import { mainnet } from 'viem/chains'

export function getViemClient(rpc: string, forkChainId: number, defaultAccount: Address) {
  return createWalletClient({
    chain: { ...mainnet, id: forkChainId },
    transport: http(rpc),
    account: defaultAccount,
  })
    .extend(publicActions)
    .extend((client) => ({
      setCode: async ({ address, bytecode }: SetCodeParameters) => {
        await client.request({
          method: 'tenderly_setCode' as any,
          params: [address, bytecode],
        })
      },
    }))
}
