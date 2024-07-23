interface BuildAppUrlArgs {
  rpc: string
  originChainId: number
}

export function buildAppUrl({ rpc, originChainId }: BuildAppUrlArgs): string {
  return `https://spark-app-staging.vercel.app/?rpc=${rpc}&chainId=${originChainId}`
}
