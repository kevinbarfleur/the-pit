import { createFileRoute } from '@tanstack/react-router'
import { AppShell } from '../components/layout/AppShell'
import { TabStub } from '../components/layout/TabStub'

export const Route = createFileRoute('/cards')({
  component: CardsRoute,
})

function CardsRoute() {
  return (
    <AppShell active="C">
      <TabStub
        title="cards"
        glyph="◇"
        blurb="your inventory, equipped loadout, and fuse / disenchant flow live here. drops earned in the pit will populate this list."
        unlockHint="ships with PRD-07"
      />
    </AppShell>
  )
}
