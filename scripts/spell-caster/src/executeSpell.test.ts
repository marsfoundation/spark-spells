import { describe, expect, test } from 'bun:test'
import type { NetworkConfig } from './config'
import { executeSpell } from './executeSpell'
import { getMockEthereumClient } from './test/MockEthereumClient'
import { randomAddress } from './test/addressUtils'
import { asciiToHex, hexStringToHex } from './test/hexUtils'

describe(executeSpell.name, () => {
  test('replaces the code of the executor with a code of a spell', async () => {
    const spellAddress = randomAddress('spell')
    const network: NetworkConfig = {
      name: 'mainnet',
      chainId: 1,
      sparkSpellExecutor: randomAddress('executor'),
    }
    const contracts = { [spellAddress]: hexStringToHex(asciiToHex('spell-bytecode')) }
    const ethereumClient = getMockEthereumClient(contracts)

    await executeSpell({ spellAddress, network, ethereumClient })

    expect(ethereumClient.setBytecode).toHaveBeenCalledWith({
      address: network.sparkSpellExecutor,
      bytecode: contracts[spellAddress],
    })
  })

  test('restores the code of the executor when done', async () => {
    const spellAddress = randomAddress('spell')
    const network: NetworkConfig = {
      name: 'mainnet',
      chainId: 1,
      sparkSpellExecutor: randomAddress('executor'),
    }
    const contracts = {
      [spellAddress]: hexStringToHex(asciiToHex('spell-bytecode')),
      [network.sparkSpellExecutor]: hexStringToHex(asciiToHex('executor-bytecode')),
    }
    const ethereumClient = getMockEthereumClient(contracts)

    await executeSpell({ spellAddress, network, ethereumClient })

    expect(await ethereumClient.getBytecode({ address: network.sparkSpellExecutor })).toBe(
      contracts[network.sparkSpellExecutor]!,
    )
  })

  test('executes a spell', async () => {
    const spellAddress = randomAddress('spell')
    const network: NetworkConfig = {
      name: 'mainnet',
      chainId: 1,
      sparkSpellExecutor: randomAddress('executor'),
    }
    const contracts = { [spellAddress]: hexStringToHex(asciiToHex('spell-bytecode')) }
    const ethereumClient = getMockEthereumClient(contracts)

    await executeSpell({ spellAddress, network, ethereumClient })

    expect(ethereumClient.sendTransaction).toHaveBeenCalledWith({
      to: network.sparkSpellExecutor,
      data: expect.stringMatching('0x'),
    })
  })

  test('throws if spell not deployed', async () => {
    const spellAddress = randomAddress('spell')
    const network: NetworkConfig = {
      name: 'mainnet',
      chainId: 1,
      sparkSpellExecutor: randomAddress('executor'),
    }
    const contracts = { [spellAddress]: undefined }
    const ethereumClient = getMockEthereumClient(contracts)

    expect(async () => await executeSpell({ spellAddress, network, ethereumClient })).toThrowError('Spell not deployed')
  })
})
