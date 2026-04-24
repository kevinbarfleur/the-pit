import type { PitRun } from '../../../hooks/usePitRun'
import { IslandNode } from './IslandNode'
import styles from './NodeMap.module.css'

interface NodeMapProps {
  run: PitRun
  minDepth: number
  maxDepth: number
  rowHeight: number
}

/**
 * Absolute-positioned layer that places every `PitNode` within the shaft
 * according to `(depth, column)`. Columns map to fixed horizontal anchors
 * (25% / 50% / 75% of the shaft width) so a node at column 1 sits at the
 * exact horizontal centre regardless of its row's width. This keeps the
 * visual lineage clear across narrowing rows (→ boss).
 */
export function NodeMap({ run, minDepth, maxDepth, rowHeight }: NodeMapProps) {
  const rows: number[] = []
  for (let d = minDepth; d <= maxDepth; d++) rows.push(d)

  return (
    <div className={styles.layer}>
      {rows.map((depth) => {
        const row = run.window.byDepth.get(depth)
        if (!row) return null
        return (
          <div
            key={depth}
            className={styles.row}
            style={{ top: depth * rowHeight, height: rowHeight }}
          >
            {row.map((node) => (
              <IslandNode
                key={node.id}
                node={node}
                state={run.nodeState(node)}
                canCommit={run.canCommit(node)}
                style={{
                  left: `${columnToPercent(node.column)}%`,
                }}
              />
            ))}
          </div>
        )
      })}
    </div>
  )
}

function columnToPercent(column: number): number {
  // Lanes are deliberately packed toward the centre of the shaft: 32%,
  // 50%, 68% rather than 17/50/83. Short horizontal distance between
  // adjacent columns keeps every downlink chain nearly vertical, which
  // is the only way chains read as pulled/taut rather than slanting
  // across the map and visually crossing one another.
  const laneCenters = [32, 50, 68]
  return laneCenters[column] ?? 50
}
