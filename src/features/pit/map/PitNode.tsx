import { useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import { useHoverEffect } from '../../../hooks/useHoverEffect'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { PitNode as PitNodeModel, PitNodeState, PitNodeType } from '../../../game/pit/types'
import styles from './PitNode.module.css'

interface PitNodeProps {
  node: PitNodeModel
  state: PitNodeState
  canCommit: boolean
  style?: CSSProperties
}

/** Glyph drawn at the centre of a tile — identifies the node type at a glance. */
const TYPE_GLYPH: Record<PitNodeType, string> = {
  combat: '⚔',
  elite: '◆',
  boss: '◈',
  event: '~',
  shop: '⌂',
  rest: '☩',
  cache: '◇',
  treasure: '✦',
}

/** Hover-effect kind mapped from node type — reuses the shared EffectsEngine. */
const TYPE_HOVER: Record<PitNodeType, AttachKind> = {
  combat: 'pulse',
  elite: 'embers',
  boss: 'embers',
  event: 'sparkle',
  shop: 'ripple',
  rest: 'grass',
  cache: 'sparkle',
  treasure: 'embers',
}

/** Canonical colour per type — drives both hover effect tint and tile border. */
const TYPE_COLOR: Record<PitNodeType, number> = {
  combat: 0xd45a5a, // red
  elite: 0xb58b3a, // gild
  boss: 0xd45a5a, // crimson (slightly darker via state)
  event: 0x9a7bd4, // violet
  shop: 0x6ec3d4, // cyan
  rest: 0x9ae66e, // green
  cache: 0xd8cfb8, // bone
  treasure: 0xd4a147, // amber
}

/** CSS colour token mirror of TYPE_COLOR. Keep in sync manually — pixel
 *  sharpness matters more than DRY here. */
const TYPE_COLOR_CSS: Record<PitNodeType, string> = {
  combat: 'var(--color-pit-red)',
  elite: 'var(--color-pit-gild)',
  boss: 'var(--color-pit-red)',
  event: 'var(--color-pit-violet)',
  shop: 'var(--color-pit-cyan)',
  rest: 'var(--color-pit-green)',
  cache: 'var(--color-pit-bone)',
  treasure: 'var(--color-pit-amber)',
}

export function PitNode({ node, state, canCommit, style }: PitNodeProps) {
  const ref = useRef<HTMLButtonElement | null>(null)
  const engine = useEffects()
  const setHoveredId = usePitUiStore((s) => s.setHoveredId)
  const startZoomIn = usePitUiStore((s) => s.startZoomIn)

  // Bind the per-type hover effect unless the tile is locked/bypassed/current.
  const hoverEnabled =
    state !== 'locked' && state !== 'bypassed' && state !== 'current'
  useHoverEffect(
    ref,
    TYPE_HOVER[node.type],
    { color: TYPE_COLOR[node.type] },
    hoverEnabled,
  )

  const handleClick = () => {
    if (!canCommit) return
    const el = ref.current
    if (!el) return
    const r = el.getBoundingClientRect()

    // Commit burst at the tile centre — reuses the Button-style burst.
    if (engine) {
      engine.emitBurst({
        x: r.left + r.width / 2,
        y: r.top + r.height / 2,
        variant: node.type === 'rest' ? 'primary' : 'default',
      })
    }

    startZoomIn({
      nodeId: node.id,
      nodeType: node.type,
      rect: { x: r.left, y: r.top, width: r.width, height: r.height },
    })
  }

  return (
    <button
      ref={ref}
      type="button"
      className={styles.node}
      data-state={state}
      data-type={node.type}
      disabled={!canCommit}
      onMouseEnter={() => setHoveredId(node.id)}
      onMouseLeave={() => setHoveredId(null)}
      onFocus={() => setHoveredId(node.id)}
      onBlur={() => setHoveredId(null)}
      onClick={handleClick}
      style={{
        ...style,
        // Expose the type colour as a CSS var so the tile style can blend
        // it into the dithered background.
        ['--node-color' as string]: TYPE_COLOR_CSS[node.type],
      }}
      aria-label={`${node.type} at depth ${node.depth}`}
    >
      <span className={styles.glyph}>{TYPE_GLYPH[node.type]}</span>
      {node.type === 'boss' && <span className={styles.bossLabel}>BOSS</span>}
    </button>
  )
}
