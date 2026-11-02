import { describe, expect, it } from 'vitest'
import { decodeLocalDevelopmentToken } from './local-development-session'

const token = 'lumina-local-dev.' + 'a'.repeat(64)
const config = {
  NODE_ENV: 'development', LUMINA_LOCAL_DEV_AUTH: 'true',
  LUMINA_LOCAL_DEV_TOKEN: token,
  LUMINA_LOCAL_DEV_USER_ID: '6ae46e485754d729b3dbf613'
}
describe('local development session', () => {
  it('keeps standard credentials on the existing provider path', () => {
    expect(decodeLocalDevelopmentToken('standard-token', config)).toBeNull()
  })
  it('maps only the configured credential to the configured user without admin rights', () => {
    const identity = decodeLocalDevelopmentToken(token, config)
    expect(identity.uid).toBe(config.LUMINA_LOCAL_DEV_USER_ID)
    expect(identity.user_id).toBe(config.LUMINA_LOCAL_DEV_USER_ID)
    expect(identity.lumina_local_dev).toBe(true)
    expect(identity.admin).toBeUndefined()
    expect(identity.exp).toBeGreaterThan(identity.iat)
  })
  for (const mode of ['production', 'staging', 'test', undefined]) {
    it(`rejects local credentials outside development (${mode})`, () => {
      expect(() => decodeLocalDevelopmentToken(token, {...config, NODE_ENV:mode})).toThrow()
    })
  }
  it('requires explicit opt-in', () => {
    expect(() => decodeLocalDevelopmentToken(token, {...config,LUMINA_LOCAL_DEV_AUTH:'false'})).toThrow()
  })
  it('rejects wrong and truncated credentials', () => {
    expect(() => decodeLocalDevelopmentToken('lumina-local-dev.'+'b'.repeat(64),config)).toThrow()
    expect(() => decodeLocalDevelopmentToken('lumina-local-dev.x',config)).toThrow()
  })
  it('rejects missing or malformed configured credentials and identities', () => {
    expect(() => decodeLocalDevelopmentToken(token,{...config,LUMINA_LOCAL_DEV_TOKEN:''})).toThrow()
    expect(() => decodeLocalDevelopmentToken(token,{...config,LUMINA_LOCAL_DEV_USER_ID:'other-user'})).toThrow()
  })
})


describe('two-player development sessions', () => {
  const guest = { token: 'lumina-local-dev.' + 'b'.repeat(64),
    userId: '6ae46e485754d729b3dbf614', displayName: 'Lumina Guest', provision: true }
  const multi = { ...config, LUMINA_LOCAL_DEV_PLAYERS: JSON.stringify([guest]) }
  it('keeps owner and guest identities distinct', () => {
    expect(decodeLocalDevelopmentToken(token, multi).uid).toBe(config.LUMINA_LOCAL_DEV_USER_ID)
    const decoded = decodeLocalDevelopmentToken(guest.token, multi)
    expect(decoded.uid).toBe(guest.userId)
    expect(decoded.admin).toBeUndefined()
    expect(decoded.lumina_local_dev_provision).toBe(true)
    expect(decoded.lumina_local_dev_name).toBe('Lumina Guest')
    expect(decodeLocalDevelopmentToken(token, multi).lumina_local_dev_provision).toBe(false)
  })
  it('rejects malformed player registries', () => {
    for (const players of ['invalid', '{}', JSON.stringify([null]),
      JSON.stringify([{...guest, userId: 'not-an-id'}]),
      JSON.stringify([{...guest, token}]),
      JSON.stringify([{...guest, userId: config.LUMINA_LOCAL_DEV_USER_ID}]),
      JSON.stringify([{...guest, displayName: ''}]),
      JSON.stringify([{...guest, provision: 'true'}]),
      JSON.stringify(Array(8).fill(guest))]) {
      expect(() => decodeLocalDevelopmentToken(guest.token, {...multi, LUMINA_LOCAL_DEV_PLAYERS:players})).toThrow()
    }
  })
  it('rejects unknown credentials and disabled or hosted use', () => {
    expect(() => decodeLocalDevelopmentToken('lumina-local-dev.'+'c'.repeat(64),multi)).toThrow()
    expect(() => decodeLocalDevelopmentToken(guest.token,{...multi,NODE_ENV:'production'})).toThrow()
    expect(() => decodeLocalDevelopmentToken(guest.token,{...multi,LUMINA_LOCAL_DEV_AUTH:'false'})).toThrow()
  })
})
