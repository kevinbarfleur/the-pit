import { useContext } from 'react'
import { EffectsContext } from '../components/pixi/EffectsProvider'
import type { EffectsEngine } from '../pixi/EffectsEngine'

export function useEffects(): EffectsEngine | null {
  return useContext(EffectsContext)
}
