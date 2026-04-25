import { createFileRoute } from '@tanstack/react-router'
import { AppShell } from '../components/layout/AppShell'
import { TabStub } from '../components/layout/TabStub'

export const Route = createFileRoute('/passives')({
  component: PassivesRoute,
})

function PassivesRoute() {
  return (
    <AppShell active="P">
      <TabStub
        title="passives"
        glyph="✦"
        blurb="permanent upgrades bought with scrap. four trees: descent, body, focus, fortune. unlocked once you've cleared your first node."
        unlockHint="ships post-PRD-04"
      />
    </AppShell>
  )
}
