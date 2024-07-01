import assert from 'node:assert'
import { zeroAddress } from 'viem'
import { getViemClient } from './blockchain/ViemClient'
import { getConfig } from './config'
import { executeSpell } from './executeSpell'
import { createTenderlyVNet, getRandomChainId } from './tenderly'
import buildAppUrl from './utils/buildAppUrl'
import { deployContract } from './utils/forge'
import { getChainIdFromSpellName } from './utils/getChainIdFromSpellName'

const deployer = zeroAddress

async function main(spellName?: string) {
  assert(spellName, 'Pass spell name as an argument ex. SparkEthereum_20240627')

  const config = getConfig()
  const originChainId = getChainIdFromSpellName(spellName)
  const chain = config.chains[originChainId]
  assert(chain, `Chain not found for chainId: ${originChainId}`)
  const forkChainId = getRandomChainId()

  const rpc = await createTenderlyVNet({
    account: config.tenderly.account,
    apiKey: config.tenderly.apiKey,
    project: config.tenderly.project,
    originChainId: originChainId,
    forkChainId,
  })
  const client = getViemClient(rpc, forkChainId, deployer)

  const spellAddress = await deployContract(spellName, rpc, deployer)

  await executeSpell({ spellAddress, chain, client })

  console.log(`Staging URL: ${buildAppUrl({ rpc, originChainId })}`)
}

const arg1 = process.argv[2]

await main(arg1)
