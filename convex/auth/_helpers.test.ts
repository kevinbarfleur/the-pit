import { describe, expect, it } from 'vitest'
import { sha256Hex, randomToken, makeSeed } from './_helpers'

describe('sha256Hex', () => {
  it('hashes the empty string to the canonical SHA-256 digest', async () => {
    expect(await sha256Hex('')).toBe(
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    )
  })

  it('hashes "abc" to the canonical SHA-256 digest', async () => {
    expect(await sha256Hex('abc')).toBe(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    )
  })

  it('is deterministic across calls', async () => {
    const a = await sha256Hex('the descender')
    const b = await sha256Hex('the descender')
    expect(a).toBe(b)
  })

  it('returns 64 lowercase hex chars', async () => {
    const out = await sha256Hex('whatever')
    expect(out).toMatch(/^[0-9a-f]{64}$/)
  })
})

describe('randomToken', () => {
  it('returns 64 hex chars by default (32 bytes)', () => {
    expect(randomToken()).toMatch(/^[0-9a-f]{64}$/)
  })

  it('respects byteLen argument', () => {
    expect(randomToken(16)).toMatch(/^[0-9a-f]{32}$/)
    expect(randomToken(8)).toMatch(/^[0-9a-f]{16}$/)
  })

  it('returns distinct tokens across calls', () => {
    const a = randomToken()
    const b = randomToken()
    expect(a).not.toBe(b)
  })
})

describe('makeSeed', () => {
  it('produces 12 hex chars', async () => {
    expect(await makeSeed('123456')).toMatch(/^[0-9a-f]{12}$/)
  })

  it('is stable per Twitch user id', async () => {
    const a = await makeSeed('twitch-user-42')
    const b = await makeSeed('twitch-user-42')
    expect(a).toBe(b)
  })

  it('differs across Twitch user ids', async () => {
    const a = await makeSeed('1')
    const b = await makeSeed('2')
    expect(a).not.toBe(b)
  })

  it('is namespaced (different namespace would diverge)', async () => {
    // Sanity: makeSeed prefixes "thepit:seed:" before hashing, so a
    // raw sha256 of the id alone produces a different value.
    const namespaced = await makeSeed('999')
    const raw = (await sha256Hex('999')).slice(0, 12)
    expect(namespaced).not.toBe(raw)
  })
})
