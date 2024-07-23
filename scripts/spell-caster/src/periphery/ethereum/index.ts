import type { Address, Hex } from 'viem'

export interface IEthereumClient {
  setBytecode(args: { address: Address; bytecode: Hex | undefined }): Promise<void>
  getBytecode(args: { address: Address }): Promise<Hex | undefined>

  sendTransaction(args: { to: Address; data: Hex }): Promise<void>
}

export { EthereumClient } from './EthereumClient'
