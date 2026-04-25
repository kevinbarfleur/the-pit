import { createFileRoute } from '@tanstack/react-router'
import { Bestiary } from '../../features/characters/Bestiary'

export const Route = createFileRoute('/kit/characters')({
  component: Bestiary,
})
