import { RoomStub } from './RoomStub'

export function EliteRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Elite"
      glyph="◆"
      blurb="named and vicious. later: scripted pattern + guaranteed T2+ drop."
      accent="gild"
      onExit={onExit}
    />
  )
}
