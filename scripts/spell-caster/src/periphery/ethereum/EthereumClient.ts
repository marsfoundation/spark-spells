import type { Address, Hex } from 'viem'
import type { IEthereumClient } from '.'
import { getViemClient } from './ViemClient'

export class EthereumClient implements IEthereumClient {
  client: ReturnType<typeof getViemClient>
  constructor(rpc: string, forkChainId: number, defaultAccount: Address) {
    this.client = getViemClient(rpc, forkChainId, defaultAccount)
  }

  async setBytecode(args: { address: Address; bytecode: Hex | undefined }): Promise<void> {
    return await this.client.setCode({
      address: args.address,
      bytecode: args.bytecode ?? '0x',
    })
  }

  async getBytecode(args: { address: Address }): Promise<Hex | undefined> {
    const bytecode = await this.client.getCode({ address: args.address })
    if (bytecode === '0x') {
      return undefined
    }

    return bytecode
  }

  async sendTransaction(args: { to: Address; data: Hex }): Promise<void> {
    await this.client.sendTransaction({
      to: args.to,
      data: args.data,
    })
  }
}
