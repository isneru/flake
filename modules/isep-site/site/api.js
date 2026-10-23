export const api = async (route, init = {}) => {
  let response
  try {
    response = await fetch(`/.edit/api/${route}`, { ...init, headers: { "Content-Type": "application/json" } })
  } catch {
    throw new Error("Could not reach the server. Reload the page to sign in again.")
  }
  const body = await response.json().catch(() => ({ error: response.statusText }))
  if (!response.ok) throw new Error(body.error)
  return body
}
