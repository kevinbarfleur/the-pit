import { action, internalAction, internalMutation } from '../_generated/server'
import { internal } from '../_generated/api'
import { v } from 'convex/values'
import { requireEnv } from '../_env'

/**
 * Twitch OAuth authorization URL builder.
 *
 * The flow:
 *  1. Client calls `getAuthUrl()` → action stores a CSRF nonce
 *     (`oauthStates`) with a 10-minute TTL and returns the full Twitch
 *     authorize URL.
 *  2. Client `window.location = authUrl`.
 *  3. Twitch redirects to `<convex-site>/auth/twitch/callback?code=&state=`
 *     (HTTP action defined in `convex/http.ts`), which:
 *       - validates the state against `oauthStates`,
 *       - exchanges the code for tokens,
 *       - fetches the Twitch user,
 *       - calls `players.findOrCreateFromTwitch`,
 *       - creates a `sessions` row,
 *       - 302-redirects the browser to `<frontend>/auth/complete?token=...`.
 *  4. The `/auth/complete` page stores the token in localStorage and
 *     navigates to `/pit`.
 *
 * Required Convex env vars (set with `convex env set <KEY> <VAL>`):
 *  - `TWITCH_CLIENT_ID`
 *  - `TWITCH_CLIENT_SECRET`
 *  - `FRONTEND_URL`     (e.g. http://localhost:5173 in dev)
 *
 * Note: `process.env.CONVEX_SITE_URL` is set automatically by Convex.
 */

const SCOPES = ['openid'] as const
const STATE_TTL_MS = 10 * 60_000
const SESSION_TTL_MS = 30 * 24 * 60 * 60_000

function randomToken(byteLen = 32): string {
  const bytes = new Uint8Array(byteLen)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
}

async function sha256Hex(input: string): Promise<string> {
  const buf = new TextEncoder().encode(input)
  const digest = await crypto.subtle.digest('SHA-256', buf)
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, '0'),
  ).join('')
}

export const getAuthUrl = action({
  args: {},
  handler: async (ctx): Promise<{ authUrl: string }> => {
    const clientId = requireEnv('TWITCH_CLIENT_ID')
    const siteUrl = requireEnv('CONVEX_SITE_URL')
    const state = randomToken(16)

    await ctx.runMutation(internal.auth.twitch.persistOauthState, {
      state,
      expiresAt: Date.now() + STATE_TTL_MS,
    })

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: `${siteUrl}/auth/twitch/callback`,
      response_type: 'code',
      scope: SCOPES.join(' '),
      state,
      force_verify: 'false',
    })

    return { authUrl: `https://id.twitch.tv/oauth2/authorize?${params}` }
  },
})

export const persistOauthState = internalMutation({
  args: { state: v.string(), expiresAt: v.number() },
  handler: async (ctx, { state, expiresAt }) => {
    await ctx.db.insert('oauthStates', { state, expiresAt })
  },
})

export const consumeOauthState = internalMutation({
  args: { state: v.string() },
  handler: async (ctx, { state }) => {
    const row = await ctx.db
      .query('oauthStates')
      .withIndex('by_state', (q) => q.eq('state', state))
      .unique()
    if (!row) return false
    await ctx.db.delete(row._id)
    if (row.expiresAt < Date.now()) return false
    return true
  },
})

export const completeOauthLogin = internalAction({
  args: { code: v.string(), state: v.string() },
  handler: async (
    ctx,
    { code, state },
  ): Promise<{ ok: true; sessionToken: string } | { ok: false; reason: string }> => {
    const stateOk = await ctx.runMutation(internal.auth.twitch.consumeOauthState, {
      state,
    })
    if (!stateOk) return { ok: false, reason: 'invalid-state' }

    const clientId = requireEnv('TWITCH_CLIENT_ID')
    const clientSecret = requireEnv('TWITCH_CLIENT_SECRET')
    const siteUrl = requireEnv('CONVEX_SITE_URL')

    const tokenRes = await fetch('https://id.twitch.tv/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        grant_type: 'authorization_code',
        redirect_uri: `${siteUrl}/auth/twitch/callback`,
      }),
    })
    if (!tokenRes.ok) {
      return { ok: false, reason: `token-exchange-${tokenRes.status}` }
    }
    const tokenData = (await tokenRes.json()) as {
      access_token: string
      refresh_token: string
      expires_in: number
    }

    const userRes = await fetch('https://api.twitch.tv/helix/users', {
      headers: {
        Authorization: `Bearer ${tokenData.access_token}`,
        'Client-Id': clientId,
      },
    })
    if (!userRes.ok) {
      return { ok: false, reason: `user-fetch-${userRes.status}` }
    }
    const userData = (await userRes.json()) as {
      data: Array<{
        id: string
        display_name: string
        profile_image_url?: string
      }>
    }
    const user = userData.data[0]
    if (!user) return { ok: false, reason: 'user-empty' }

    const playerId = await ctx.runMutation(
      internal.players.findOrCreateFromTwitch,
      {
        twitchUserId: user.id,
        twitchDisplayName: user.display_name,
        twitchAvatarUrl: user.profile_image_url,
      },
    )

    const sessionToken = randomToken(32)
    const sessionTokenHash = await sha256Hex(sessionToken)
    const now = Date.now()
    await ctx.runMutation(internal.auth.twitch.persistSession, {
      playerId,
      sessionTokenHash,
      twitchAccessToken: tokenData.access_token,
      twitchRefreshToken: tokenData.refresh_token,
      twitchTokenExpiresAt: now + tokenData.expires_in * 1000,
      expiresAt: now + SESSION_TTL_MS,
      createdAt: now,
    })

    return { ok: true, sessionToken }
  },
})

export const persistSession = internalMutation({
  args: {
    playerId: v.id('players'),
    sessionTokenHash: v.string(),
    twitchAccessToken: v.string(),
    twitchRefreshToken: v.string(),
    twitchTokenExpiresAt: v.number(),
    expiresAt: v.number(),
    createdAt: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert('sessions', args)
  },
})
