import { createFileRoute } from '@tanstack/react-router'
import { PitScene } from '../features/pit/PitScene'
import { AppShell } from '../components/layout/AppShell'

export const Route = createFileRoute('/pit')({
  component: PitRoute,
})

function PitRoute() {
  return (
    <AppShell active="D">
      <PitScene />
    </AppShell>
  )
}
