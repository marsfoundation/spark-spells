import { solidFetch } from '../utils/solidFetch'

export interface CreateTenderlyForkArgs {
  name: string
  displayName?: string
  originChainId: number
  forkChainId: number
  blockNumber?: bigint
}

export interface CreateTenderlyVnetResult {
  rpcUrl: string
}

export class TenderlyVnetClient {
  constructor(private readonly opts: { apiKey: string; account: string; project: string }) {}

  async create({
    name,
    displayName,
    originChainId,
    forkChainId,
    blockNumber,
  }: CreateTenderlyForkArgs): Promise<CreateTenderlyVnetResult> {
    const response = await solidFetch(
      `https://api.tenderly.co/api/v1/account/${this.opts.account}/project/${this.opts.project}/vnets`,
      {
        method: 'post',
        headers: {
          'Content-Type': 'application/json',
          'X-Access-Key': this.opts.apiKey,
        },
        body: JSON.stringify({
          slug: name,
          display_name: displayName,
          fork_config: {
            network_id: originChainId,
            block_number: Number(blockNumber),
          },
          virtual_network_config: {
            chain_config: {
              chain_id: forkChainId,
            },
          },
          sync_state_config: {
            enabled: false,
            commitment_level: 'latest',
          },
          explorer_page_config: {
            enabled: false,
            verification_visibility: 'bytecode',
          },
        }),
      },
    )

    const data: any = await response.json()
    return { rpcUrl: data.rpcs[0].url }
  }
}
