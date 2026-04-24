import { PixelFrame, Button } from '../../../components/ui'
import styles from './RoomStub.module.css'

interface RoomStubProps {
  title: string
  glyph: string
  blurb: string
  accent?: 'gild' | 'danger' | undefined
  onExit: () => void
}

/**
 * V1 shell shared by every node room. Gets the player in and out of the
 * zoom flow cleanly while the actual per-type gameplay is built out. The
 * frame tone + glyph signals the type; no real logic runs yet.
 */
export function RoomStub({ title, glyph, blurb, accent, onExit }: RoomStubProps) {
  return (
    <PixelFrame
      tone={accent === 'gild' ? 'gild' : undefined}
      title={title}
      right="stub"
    >
      <div className={styles.stub}>
        <div className={styles.glyph} data-accent={accent ?? 'none'}>
          {glyph}
        </div>
        <div className={styles.blurb}>{blurb}</div>
        <div className={styles.actions}>
          <Button
            variant={accent === 'danger' ? 'danger' : 'default'}
            onClick={onExit}
            juicy
          >
            leave <span className={styles.kbd}>[esc]</span>
          </Button>
        </div>
      </div>
    </PixelFrame>
  )
}
