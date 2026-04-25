import { PixelFrame } from '../ui/PixelFrame'
import styles from './TabStub.module.css'

/**
 * Placeholder content for tabs that exist in the navigation but whose
 * full PRD ships later (cards/passives/codex/leaderboard V1 stubs).
 *
 * Visually consistent with `RoomStub` so users get a coherent "this
 * is here, not built yet" signal across pit rooms and topbar tabs.
 */
interface TabStubProps {
  title: string
  glyph: string
  blurb: string
  unlockHint?: string
}

export function TabStub({ title, glyph, blurb, unlockHint }: TabStubProps) {
  return (
    <div className={styles.tabStub}>
      <div className={styles.frame}>
        <PixelFrame title={title} right="soon">
          <div className={styles.body}>
            <div className={styles.glyph}>{glyph}</div>
            <div className={styles.blurb}>{blurb}</div>
            {unlockHint ? <div className={styles.unlock}>{unlockHint}</div> : null}
          </div>
        </PixelFrame>
      </div>
    </div>
  )
}
