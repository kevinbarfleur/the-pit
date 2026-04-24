import type { PitRun } from '../../../hooks/usePitRun'
import type { PitNode, PitNodeType } from '../../../game/pit/types'
import { usePitUiStore } from '../../../stores/pitUiStore'
import { PixelFrame, Panel, Pill } from '../../../components/ui'
import styles from './NodeDetailPanel.module.css'

interface NodeDetailPanelProps {
  run: PitRun
}

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

/**
 * Right-side hover-detail panel. Shows a gilded frame with threat + reward
 * + torch cost for whichever node the cursor is on. When no node is
 * hovered, shows the run's context (current depth, deepest reached).
 */
export function NodeDetailPanel({ run }: NodeDetailPanelProps) {
  const hoveredId = usePitUiStore((s) => s.hoveredId)
  const hovered = hoveredId ? run.window.byId.get(hoveredId) ?? null : null

  return (
    <aside className={styles.panel} data-pit-chrome>
      {hovered ? <HoveredView node={hovered} run={run} /> : <NoHoverView run={run} />}
    </aside>
  )
}

function HoveredView({ node, run }: { node: PitNode; run: PitRun }) {
  const state = run.nodeState(node)
  const canCommit = run.canCommit(node)
  const reward = run.rewardScaleFor(node)
  return (
    <PixelFrame tone={node.type === 'boss' || node.type === 'elite' ? 'gild' : undefined}
      title={TYPE_LABEL[node.type]}
      right={`D${String(node.depth).padStart(3, '0')}`}
    >
      <div className={styles.blurb}>{TYPE_BLURB[node.type]}</div>
      <div className={styles.stats}>
        <StatRow label="threat" value={`${(node.threat / 100).toFixed(0)} bp·d`} />
        <StatRow label="state" value={<Pill tone={pillToneForState(state)}>{state}</Pill>} />
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
  )
}

function NoHoverView({ run }: { run: PitRun }) {
  return (
    <PixelFrame title="The Pit" right="run">
      <div className={styles.blurb}>hover a tile</div>
      <div className={styles.stats}>
        <StatRow label="depth" value={`D${String(run.currentDepth).padStart(3, '0')}`} />
        <StatRow
          label="deepest"
          value={`D${String(run.state.deepestDepth).padStart(3, '0')}`}
        />
        <StatRow label="path" value={`${run.state.path.length} nodes`} />
      </div>
      <Panel>
        <div className={styles.legendLabel}>legend</div>
        <div className={styles.legend}>
          ⚔ combat · ◆ elite · ◈ boss
          <br />
          ~ event · ⌂ shop · ☩ rest
          <br />
          ◇ cache · ✦ treasure
        </div>
      </Panel>
    </PixelFrame>
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
