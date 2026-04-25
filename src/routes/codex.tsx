import { createFileRoute } from '@tanstack/react-router'
import { AppShell } from '../components/layout/AppShell'
import { TabStub } from '../components/layout/TabStub'

export const Route = createFileRoute('/codex')({
  component: CodexRoute,
})

function CodexRoute() {
  return (
    <AppShell active="X">
      <TabStub
        title="codex"
        glyph="❡"
        blurb="bestiary, lore drops, and the descent journal. entries fill in as you encounter creatures, rooms, and events down the pit."
        unlockHint="ships post-PRD-08"
      />
    </AppShell>
  )
}
