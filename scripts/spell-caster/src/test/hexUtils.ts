import assert from 'node:assert'
import type { Hex } from 'viem'

export function hexStringToHex(input: string): Hex {
  return `0x${input}` as any
}

export function randomHexString(length: number): string {
  const hexChars = '0123456789abcdef'
  let hexString = ''
  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * hexChars.length)
    hexString += hexChars[randomIndex]
  }
  return hexString
}

/**
 * Best effort to represent ascii string as hex string. Keep in mind that multiple ascii string can map to the same hex string.
 * Example: sos => 505
 */
export function asciiToHex(input: string) {
  const charMap: { [c: string]: string | undefined } = {
    a: 'a',
    b: 'b',
    c: 'c',
    d: 'd',
    e: 'e',
    f: 'f',
    g: '6',
    h: '6',
    i: '1',
    j: '1',
    k: '1',
    l: '1',
    m: '6',
    n: '6',
    o: '0',
    p: '6',
    q: '9',
    r: '2',
    s: '5',
    t: '7',
    u: '6',
    v: '7',
    w: '7',
    x: '9',
    y: '7',
    z: '2',
    '0': '0',
    '1': '1',
    '2': '2',
    '3': '3',
    '4': '4',
    '5': '5',
    '6': '6',
    '7': '7',
    '8': '8',
    '9': '9',
    '-': '0',
  }

  return input
    .split('')
    .map((char) => {
      const hex = charMap[char.toLowerCase()]
      assert(hex, `Invalid character: ${char}`)
      return hex
    })
    .join('')
}
