import type { PitNodeType } from '../../../game/pit/types'
import { BossRoom } from './BossRoom'
import { CacheRoom } from './CacheRoom'
import { CombatRoom } from './CombatRoom'
import { EliteRoom } from './EliteRoom'
import { EventRoom } from './EventRoom'
import { RestRoom } from './RestRoom'
import { ShopRoom } from './ShopRoom'
import { TreasureRoom } from './TreasureRoom'

/**
 * Dispatch to the per-type room component. Kept dead simple — each type
 * has a dedicated file so filling in the real gameplay later is just
 * expanding the matching stub without touching the scene plumbing.
 */
export function RoomForType({
  type,
  onExit,
}: {
  type: PitNodeType
  onExit: () => void
}) {
  switch (type) {
    case 'combat':
      return <CombatRoom onExit={onExit} />
    case 'elite':
      return <EliteRoom onExit={onExit} />
    case 'boss':
      return <BossRoom onExit={onExit} />
    case 'event':
      return <EventRoom onExit={onExit} />
    case 'shop':
      return <ShopRoom onExit={onExit} />
    case 'rest':
      return <RestRoom onExit={onExit} />
    case 'cache':
      return <CacheRoom onExit={onExit} />
    case 'treasure':
      return <TreasureRoom onExit={onExit} />
  }
}
