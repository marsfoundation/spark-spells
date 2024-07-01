import { gnosis, mainnet } from 'viem/chains'

export function getChainIdFromSpellName(spellName: string): number {
  const regex = /^Spark([a-zA-Z]+)_\d+$/

  // Apply the regular expression to the input string
  const match = spellName.match(regex)

  if (!match) {
    throw new Error(`Couldn't parse chain ID from spell name: ${spellName}. ex. SparkEthereum_20240627`)
  }

  const name = match[1]

  switch (name) {
    case 'Ethereum':
      return mainnet.id
    case 'Gnosis':
      return gnosis.id
    default:
      throw new Error(`Unknown chain name: ${name}`)
  }
}
