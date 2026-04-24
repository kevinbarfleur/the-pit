import { useContext } from 'react'
import { ChainsContext } from '../components/pixi/ChainsProvider'
import type { ChainsEngine } from '../pixi/ChainsEngine'

export function useChains(): ChainsEngine | null {
  return useContext(ChainsContext)
}
