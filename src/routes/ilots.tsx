import { useState } from 'react'
import { createFileRoute, Link } from '@tanstack/react-router'
import { IslandPreview } from '../features/pit/map/IslandPreview'
import type { PitNodeType } from '../game/pit/types'
import styles from './ilots.module.css'

export const Route = createFileRoute('/ilots')({
  component: IslandsPreview,
})

interface PreviewEntry {
  type: PitNodeType
  idSeed: string
  label: string
  hoverEffect: string
  blurb: string
}

/**
 * Dev / design iteration surface for the Pit islands. Shows every
 * node type in a grid at a larger scale than the map, with its hover
 * effect permanently active, so we can polish the look in isolation
 * without clicking around the real map.
 *
 * Not reachable from the main navigation on purpose — open /ilots
 * directly.
 */
const PREVIEW_ENTRIES: PreviewEntry[] = [
  { type: 'combat', idSeed: 'ilot-preview:combat', label: 'Combat', hoverEffect: 'pulse', blurb: 'red pulse — lesser grind' },
  { type: 'elite', idSeed: 'ilot-preview:elite', label: 'Elite', hoverEffect: 'embers (gild)', blurb: 'gild embers — named threat' },
  { type: 'boss', idSeed: 'ilot-preview:boss', label: 'Boss', hoverEffect: 'embers (red)', blurb: 'crimson embers — floor-keeper' },
  { type: 'event', idSeed: 'ilot-preview:event', label: 'Event', hoverEffect: 'sparkle (violet)', blurb: 'violet sparkle — something speaks' },
  { type: 'shop', idSeed: 'ilot-preview:shop', label: 'Shop', hoverEffect: 'coins (gold orbit)', blurb: 'coins orbiting — merchant waits' },
  { type: 'rest', idSeed: 'ilot-preview:rest', label: 'Rest', hoverEffect: 'grass (green)', blurb: 'green grass — a quiet moment' },
  { type: 'cache', idSeed: 'ilot-preview:cache', label: 'Cache', hoverEffect: 'sparkle (bone)', blurb: 'bone sparkle — sealed chest' },
  { type: 'treasure', idSeed: 'ilot-preview:treasure', label: 'Treasure', hoverEffect: 'godray (gold)', blurb: 'divine rays + chest — gleaming' },
]

function IslandsPreview() {
  const [scale, setScale] = useState(4)
  const [alwaysOn, setAlwaysOn] = useState(true)
  const [seedSalt, setSeedSalt] = useState(0)

  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <Link to="/" className={styles.backLink}>← title</Link>
        <h1 className={styles.title}>Pit · Islands preview</h1>
        <span className={styles.subtitle}>
          iterate on silhouettes + hover effects · /ilots
        </span>
      </header>

      <section className={styles.controls}>
        <div className={styles.controlGroup}>
          <span className={styles.controlLabel}>scale</span>
          <div className={styles.scaleButtons}>
            {[2, 3, 4, 5, 6].map((s) => (
              <button
                key={s}
                type="button"
                className={`${styles.scaleBtn} ${s === scale ? styles.scaleBtnOn : ''}`}
                onClick={() => setScale(s)}
              >
                ×{s}
              </button>
            ))}
          </div>
        </div>

        <label className={styles.controlGroup}>
          <input
            type="checkbox"
            checked={alwaysOn}
            onChange={(e) => setAlwaysOn(e.currentTarget.checked)}
          />
          <span className={styles.controlLabel}>effects always on</span>
        </label>

        <button
          type="button"
          className={styles.seedBtn}
          onClick={() => setSeedSalt((v) => v + 1)}
        >
          reroll shapes
        </button>
      </section>

      <section className={styles.grid}>
        {PREVIEW_ENTRIES.map((entry) => (
          <div key={entry.type} className={styles.cell}>
            <div className={styles.slot}>
              <IslandPreview
                id={`${entry.idSeed}:${seedSalt}`}
                type={entry.type}
                scale={scale}
                effectAlwaysOn={alwaysOn}
              />
            </div>
            <div className={styles.cellFooter}>
              <span className={styles.cellType}>{entry.label}</span>
              <span className={styles.cellEffect}>{entry.hoverEffect}</span>
              <span className={styles.cellBlurb}>{entry.blurb}</span>
            </div>
          </div>
        ))}
      </section>

      <footer className={styles.footer}>
        <p>
          Each cell renders an <code>IslandPreview</code> with the same
          hover-effect binding used on the real map. The effect spawn
          zone (<code>capZone</code>) is invisible and scales with the
          preview — adjust blade height, count, or patch shape in
          <code> IslandPreview</code> to iterate the look.
        </p>
      </footer>
    </main>
  )
}
