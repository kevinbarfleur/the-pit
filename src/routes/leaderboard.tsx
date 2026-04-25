import { createFileRoute } from '@tanstack/react-router'
import { AppShell } from '../components/layout/AppShell'
import { TabStub } from '../components/layout/TabStub'

export const Route = createFileRoute('/leaderboard')({
  component: LeaderboardRoute,
})

function LeaderboardRoute() {
  return (
    <AppShell active="L">
      <TabStub
        title="leaderboard"
        glyph="◆"
        blurb="tiered standings — surface, shaft, caverns, abyss, deeppit. your nearby cohort and percentile ranking. unlocked at your first boss kill."
        unlockHint="ships with PRD-11"
      />
    </AppShell>
  )
}
