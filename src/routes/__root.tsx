import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import type { QueryClient } from '@tanstack/react-query'
import type { ConvexReactClient } from 'convex/react'
import { EffectsProvider } from '../components/pixi/EffectsProvider'
import { ChainsProvider } from '../components/pixi/ChainsProvider'

interface RouterContext {
  queryClient: QueryClient
  convex: ConvexReactClient
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
})

function RootLayout() {
  return (
    <EffectsProvider>
      <ChainsProvider>
        <Outlet />
        {import.meta.env.DEV && (
          <>
            <TanStackRouterDevtools position="bottom-right" />
            <ReactQueryDevtools initialIsOpen={false} />
          </>
        )}
      </ChainsProvider>
    </EffectsProvider>
  )
}
