import type { PitRun } from '../../../hooks/usePitRun'
import type { PitNode, PitNodeType } from '../../../game/pit/types'
import { PixelFrame, Panel, Pill } from '../../../components/ui'
import styles from './NodePopover.module.css'

/**
 * Hover-triggered detail popover. Anchored above an `IslandNode`, it
 * mirrors the legacy right-side panel — type, threat, state pill,
 * reward scale, commit hint — but only appears while the cursor is on
 * the matching island. `pointer-events: none` ensures the popover
 * never re-triggers hover on itself, which would otherwise flicker
 * when the cursor crosses the popover's edge.
 */

const TYPE_LABEL: Record<PitNodeType, string> = {
  combat: 'Combat',
  elite: 'Elite',
  boss: 'Boss',
  event: 'Event',
  shop: 'Shop',
  rest: 'Rest',
  cache: 'Cache',
  treasure: 'Treasure',
}

const TYPE_BLURB: Record<PitNodeType, string> = {
  combat: 'a lesser grind',
  elite: 'a named threat — worth it',
  boss: 'the floor-keeper',
  event: 'something the Pit wants',
  shop: 'things to buy, things to pay for',
  rest: 'a chance to breathe',
  cache: 'sealed, probably ignored',
  treasure: 'gold, scraps, and bait',
}

interface NodePopoverProps {
  node: PitNode
  run: PitRun
}

export function NodePopover({ node, run }: NodePopoverProps) {
  const state = run.nodeState(node)
  const canCommit = run.canCommit(node)
  const reward = run.rewardScaleFor(node)
  return (
    <div className={styles.popover} role="presentation">
      <PixelFrame
        tone={node.type === 'boss' || node.type === 'elite' ? 'gild' : undefined}
        title={TYPE_LABEL[node.type]}
        right={`D${String(node.depth).padStart(3, '0')}`}
      >
        <div className={styles.blurb}>{TYPE_BLURB[node.type]}</div>
        <div className={styles.stats}>
          <StatRow label="threat" value={`${(node.threat / 100).toFixed(0)} bp·d`} />
          <StatRow
            label="state"
            value={<Pill tone={pillToneForState(state)}>{state}</Pill>}
          />
          <StatRow
            label="reward scale"
            value={`${(reward / 100).toFixed(0)}%`}
            muted={reward < 10000}
          />
        </div>
        <Panel>
          <div className={styles.legendLabel}>commit</div>
          <div className={styles.commitHint}>
            {canCommit ? (
              <span>
                click to enter — <kbd className={styles.kbd}>↵</kbd>
              </span>
            ) : (
              <span className={styles.locked}>unreachable from current position</span>
            )}
          </div>
        </Panel>
      </PixelFrame>
    </div>
  )
}

function StatRow({
  label,
  value,
  muted,
}: {
  label: string
  value: React.ReactNode
  muted?: boolean
}) {
  return (
    <div className={styles.row} data-muted={muted ? 'true' : 'false'}>
      <span className={styles.statLabel}>{label}</span>
      <span className={styles.statValue}>{value}</span>
    </div>
  )
}

function pillToneForState(state: ReturnType<PitRun['nodeState']>) {
  switch (state) {
    case 'current':
      return 'g'
    case 'cleared':
      return 'a'
    case 'cleared-exhausted':
      return undefined
    case 'locked':
    case 'bypassed':
      return undefined
    default:
      return 'c'
  }
}
