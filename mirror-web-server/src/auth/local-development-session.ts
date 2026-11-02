import { timingSafeEqual } from 'crypto'
import { DecodedIdToken } from 'firebase-admin/lib/auth/token-verifier'

type DevelopmentPlayer = { token: string; userId: string; displayName?: string; provision?: boolean }
const tokenPattern = /^lumina-local-dev\.[0-9a-f]{64}$/
const idPattern = /^[0-9a-f]{24}$/

/** Explicit development-only identities; normal profile and Space permissions still apply. */
export function decodeLocalDevelopmentToken(
  token: string,
  env: NodeJS.ProcessEnv = process.env
): DecodedIdToken | null {
  if (!token?.startsWith('lumina-local-dev.')) return null
  if (env.NODE_ENV !== 'development' || env.LUMINA_LOCAL_DEV_AUTH !== 'true') {
    throw new Error('Local development access is disabled')
  }
  const players: DevelopmentPlayer[] = [{
    token: env.LUMINA_LOCAL_DEV_TOKEN || '', userId: env.LUMINA_LOCAL_DEV_USER_ID || ''
  }]
  if (env.LUMINA_LOCAL_DEV_PLAYERS) {
    let additional: unknown
    try { additional = JSON.parse(env.LUMINA_LOCAL_DEV_PLAYERS) } catch {
      throw new Error('Invalid development player configuration')
    }
    if (!Array.isArray(additional) || additional.length > 7) {
      throw new Error('Invalid development player configuration')
    }
    players.push(...additional)
  }
  const seenTokens = new Set<string>()
  const seenIds = new Set<string>()
  for (const player of players) {
    if (!player || typeof player.token !== 'string' || typeof player.userId !== 'string' ||
        !tokenPattern.test(player.token) || !idPattern.test(player.userId) ||
        seenTokens.has(player.token) || seenIds.has(player.userId) ||
        (player.provision !== undefined && typeof player.provision !== 'boolean') ||
        (player.provision === true && (typeof player.displayName !== 'string' ||
          player.displayName.trim().length < 1 || player.displayName.length > 40))) {
      throw new Error('Invalid development player configuration')
    }
    seenTokens.add(player.token); seenIds.add(player.userId)
  }
  if (!tokenPattern.test(token)) throw new Error('Invalid local development credential')
  const supplied = Buffer.from(token)
  const player = players.find(p => timingSafeEqual(supplied, Buffer.from(p.token)))
  if (!player) throw new Error('Invalid local development credential')
  const uid = player.userId
  const now = Math.floor(Date.now() / 1000)
  return {
    uid, sub: uid, user_id: uid,
    aud: 'lumina-local-development', iss: 'lumina-local-development',
    auth_time: now, iat: now, exp: now + 3600,
    firebase: { identities: {}, sign_in_provider: 'custom' },
    lumina_local_dev: true,
    lumina_local_dev_provision: player.provision === true,
    lumina_local_dev_name: player.displayName || ''
  }
}
