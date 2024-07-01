export default function buildAppUrl({
  rpc,
  originChainId,
}: {
  rpc: string
  originChainId: number
}): string {
  return `https://spark-app-staging.vercel.app/?rpc=${rpc}&chainId=${originChainId}`
}
