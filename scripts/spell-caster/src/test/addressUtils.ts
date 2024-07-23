import assert from 'node:assert'
import { type Address, getAddress } from 'viem'
import { asciiToHex, randomHexString } from './hexUtils'

export function randomAddress(asciiPrefix = ''): Address {
  const hexPrefix = asciiToHex(asciiPrefix)
  const postfixLength = 40 - hexPrefix.length
  assert(postfixLength >= 0, `Prefix too long: ${asciiPrefix}`)
  const address = hexPrefix + randomHexString(postfixLength)

  return getAddress(`0x${address}`)
}
