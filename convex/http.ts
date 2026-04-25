import { httpRouter } from 'convex/server'
import { httpAction } from './_generated/server'
import { internal } from './_generated/api'
import { getEnv } from './_env'

const http = httpRouter()

/**
 * Twitch OAuth callback. Twitch redirects here with `?code=&state=` after
 * the user consents. We hand off to `completeOauthLogin` (internal action)
 * which exchanges the code, fetches the user, and creates a session.
 *
 * On success we 302 to `<FRONTEND_URL>/auth/complete?token=<sessionToken>`.
 * On failure we redirect to `<FRONTEND_URL>/auth?error=<reason>`.
 */
http.route({
  path: '/auth/twitch/callback',
  method: 'GET',
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url)
    const code = url.searchParams.get('code')
    const state = url.searchParams.get('state')
    const error = url.searchParams.get('error')
    const frontendUrl = getEnv('FRONTEND_URL') ?? ''

    if (error) {
      return Response.redirect(
        `${frontendUrl}/auth?error=${encodeURIComponent(error)}`,
        302,
      )
    }
    if (!code || !state) {
      return Response.redirect(`${frontendUrl}/auth?error=missing-params`, 302)
    }

    const result = await ctx.runAction(
      internal.auth.twitch.completeOauthLogin,
      { code, state },
    )
    if (!result.ok) {
      return Response.redirect(
        `${frontendUrl}/auth?error=${encodeURIComponent(result.reason)}`,
        302,
      )
    }
    return Response.redirect(
      `${frontendUrl}/auth/complete?token=${encodeURIComponent(result.sessionToken)}`,
      302,
    )
  }),
})

export default http
