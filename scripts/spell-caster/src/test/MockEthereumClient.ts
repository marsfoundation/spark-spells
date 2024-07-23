import { spyOn } from 'bun:test'
import { type Address, type Hex } from 'viem'
import { IEthereumClient } from '../periphery/ethereum'

export function getMockEthereumClient(contracts: ContractsMap = {}): MockEthereumClient {
  const ethereumClient = new MockEthereumClient({ ...contracts }) // @note: deep copy to avoid mutation

  // @todo: automate by spying every function on the prototype
  spyOn(ethereumClient, 'getBytecode')
  spyOn(ethereumClient, 'setBytecode')
  spyOn(ethereumClient, 'sendTransaction')

  return ethereumClient
}

type ContractsMap = Record<Address, Hex | undefined>

class MockEthereumClient implements IEthereumClient {
  constructor(public readonly contracts = {} as ContractsMap) {}

  async setBytecode(args: { address: Address; bytecode: Hex }): Promise<void> {
    this.contracts[args.address] = args.bytecode
  }
  async getBytecode(args: { address: Address }): Promise<Hex | undefined> {
    return this.contracts[args.address]
  }

  async sendTransaction(_args: { to: Address; data: Hex }): Promise<void> {}
}
