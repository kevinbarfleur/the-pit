import { createFileRoute } from '@tanstack/react-router'
import { PitScene } from '../features/pit/PitScene'

export const Route = createFileRoute('/pit')({
  component: PitScene,
})
