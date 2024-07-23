import { describe, expect, test } from 'bun:test'
import { randomAddress } from './addressUtils'

describe(randomAddress.name, () => {
  test('generates a random address', () => {
    const address = randomAddress()
    expect(address).toMatch(/^0x[0-9a-fA-F]{40}$/)
  })

  test('generates a random address with prefix', () => {
    const address = randomAddress('alice')
    expect(address.toLowerCase()).toMatch(/^0xa11ce[0-9a-f]{35}$/)
  })
})
