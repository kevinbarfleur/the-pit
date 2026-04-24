import { useMemo, useRef } from 'react'
import type { CSSProperties } from 'react'
import type { AttachKind } from '../../../pixi/EffectsEngine'
import { useEffects } from '../../../hooks/useEffects'
import { useHoverEffect } from '../../../hooks/useHoverEffect'
import { usePitUiStore } from '../../../stores/pitUiStore'
import type { PitNode as PitNodeModel, PitNodeState, PitNodeType } from '../../../game/pit/types'
import { computeIslandShape } from './IslandShape'
import styles from './IslandNode.module.css'

interface IslandNodeProps {
  node: PitNodeModel
  state: PitNodeState
  canCommit: boolean
  style?: CSSProperties
}

const SIZE_PX = 60

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

const TYPE_COLOR: Record<PitNodeType, number> = {
  combat: 0xd45a5a,
  elite: 0xb58b3a,
  boss: 0xd45a5a,
  event: 0x9a7bd4,
  shop: 0x6ec3d4,
  rest: 0x9ae66e,
  cache: 0xd8cfb8,
  treasure: 0xd4a147,
}

/**
 * A floating pixel-art island used as the clickable node on the Pit map.
 * Replaces the rectangular tile primitive.
 *
 * Visual anatomy:
 *   - Top cap    — an irregular circle clipped by a 14-vertex polygon.
 *                  Tinted by the node type and dithered with a 1px
 *                  pattern to sell the pixel-art feel.
 *   - Underside  — 3–5 dangling stalactites in a darker tint, positioned
 *                  deterministically from the node id so the island
 *                  always reads as the same chunk of earth.
 *   - Drop shadow— elliptical fuzz underneath to anchor the float.
 *   - Float bob  — step-keyframed Y translation with a per-id period +
 *                  delay, so nearby islands don't breathe in unison.
 *
 * Chain anchor attributes:
 *   - data-anchor-top / data-anchor-bottom expose the % offsets where
 *     incoming / outgoing chains should latch. The Pixi ChainsEngine
 *     reads these when it rebuilds its segment list.
 */
export function IslandNode({ node, state, canCommit, style }: IslandNodeProps) {
  const ref = useRef<HTMLButtonElement | null>(null)
  const engine = useEffects()
  const setHoveredId = usePitUiStore((s) => s.setHoveredId)
  const startZoomIn = usePitUiStore((s) => s.startZoomIn)

  const shape = useMemo(() => computeIslandShape(node.id, SIZE_PX), [node.id])

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

  const stalacticElements = shape.stalactites.map((s, i) => (
    <span
      key={i}
      className={styles.stalactite}
      style={{
        left: `${s.xPercent}%`,
        top: `${s.topOffset}px`,
        width: `${s.width}px`,
        height: `${s.height}px`,
        // Pointed tip via clip-path — trapezoid that narrows downward.
        clipPath: `polygon(0 0, 100% 0, 70% 100%, 30% 100%)`,
      }}
    />
  ))

  return (
    <button
      ref={ref}
      type="button"
      className={styles.island}
      data-state={state}
      data-type={node.type}
      data-island-id={node.id}
      data-anchor-top={shape.topAnchorPercent}
      data-anchor-bottom={shape.bottomAnchorPercent}
      disabled={!canCommit}
      onMouseEnter={() => setHoveredId(node.id)}
      onMouseLeave={() => setHoveredId(null)}
      onFocus={() => setHoveredId(node.id)}
      onBlur={() => setHoveredId(null)}
      onClick={handleClick}
      style={
        {
          ...style,
          width: `${SIZE_PX}px`,
          height: `${SIZE_PX + 24}px`,
          animationDuration: `${shape.floatPeriod}s`,
          animationDelay: `-${shape.floatDelay}s`,
          ['--island-float-period' as string]: `${shape.floatPeriod}s`,
        } as CSSProperties
      }
      aria-label={`${node.type} at depth ${node.depth}`}
    >
      <span className={styles.shadow} />
      <span
        className={styles.top}
        style={{ clipPath: shape.clipPath }}
        data-type={node.type}
      >
        <span className={styles.topHighlight} />
        <span className={styles.glyph}>{TYPE_GLYPH[node.type]}</span>
      </span>
      <span className={styles.underside}>{stalacticElements}</span>
    </button>
  )
}
