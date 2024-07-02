import assert from 'node:assert'

export function getRequiredEnv(key: string): string {
  const value = process.env[key]
  assert(value, `Missing required environment variable: ${key}`)
  return value
}
