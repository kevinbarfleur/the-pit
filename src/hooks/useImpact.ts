import { useContext } from 'react'
import { ImpactContext, type ImpactEmitter } from '../components/pixi/ImpactLayerProvider'

export function useImpact(): ImpactEmitter | null {
  return useContext(ImpactContext)
}
