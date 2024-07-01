import fetchRetry from 'fetch-retry'

export const solidFetch = fetchRetry(fetch, {
  retries: 5,
  async retryOn(_attempt, error, response) {
    const retry = error !== null || !response?.ok
    if (retry) {
      const errorMsg = await response?.text()
      console.log('[solidFetch] Retrying error', { error, response, errorMsg })
    }

    return retry
  },
  retryDelay(attempt) {
    return 2 ** attempt * 150
  },
})
