# F2. Twitch Auth and Identity - P0

## Sources
- Convex Developer Hub, Authentication: https://docs.convex.dev/auth
- Convex Auth, OAuth providers: https://labs.convex.dev/auth/config/oauth
- Auth.js Twitch provider: https://authjs.dev/reference/core/providers/twitch
- Twitch Developers, OAuth token flows: https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/
- Twitch Developers, scopes: https://dev.twitch.tv/docs/authentication/scopes/

## Findings
- Convex supports authentication through providers that issue OpenID Connect-compatible JWTs. Convex Auth itself uses Auth.js provider configs and officially documents GitHub, Google, and Apple, while also saying other Auth.js providers can be tried without the same support guarantee.
- Auth.js has a Twitch provider, but its docs note that it assumes Twitch behaves as an OpenID Connect provider. This is a spike risk: it may work as-is, but the team should not discover provider incompatibility during gameplay implementation.
- Twitch's authorization code flow is the correct default for this app because the app has a server/backend and can keep a client secret server-side. The implicit flow is less appropriate because it is meant for clients without a server.
- Scope minimization is straightforward for V1. Public identity can be retrieved with very limited access; email requires `user:read:email`. Chat, whispers, channel, moderation, and broadcast scopes should be excluded from MVP.
- Identity should be stored as a stable Twitch user ID, not a display name. Display names can change; leaderboard and account linking should key off provider ID.

## Recommendation for The Pit
- Run a Twitch auth spike before gameplay coding reaches leaderboards.
- Preferred path:
  - Use Convex Auth with the Auth.js Twitch provider.
  - Configure callback URL using the Convex HTTP Actions URL pattern documented by Convex Auth.
  - Store environment variables in Convex backend env.
  - Request no chat/broadcast scopes. Add `user:read:email` only if email is needed for account recovery or support.
- Persist user identity:
  - `provider: 'twitch'`
  - `providerUserId`
  - `login`
  - `displayName`
  - `profileImageUrl`
  - `email` optional
  - `lastLoginAt`
  - `linkedAnonymousSaveId` optional
- Fallback path if Auth.js Twitch fails in Convex Auth:
  - Implement manual OAuth authorization code flow in an HTTP action.
  - Exchange code server-side with Twitch.
  - Validate access token per Twitch guidance.
  - Fetch Twitch user profile.
  - Mint the app's own Convex-compatible session/JWT or use Convex custom auth configuration.
- MVP identity scopes:
  - Required: identity only.
  - Optional: `user:read:email`.
  - Explicitly not in MVP: chat, whispers, channel subscriptions, moderation, ads, stream controls.
- Security details:
  - Always use `state` for CSRF protection.
  - Never expose client secret to the browser.
  - Store refresh tokens encrypted or avoid storing long-lived tokens until Twitch API calls beyond login are required.
