import { RoomStub } from './RoomStub'

export function TreasureRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Treasure"
      glyph="✦"
      blurb="gleaming. later: gold + scrap + a lure or two."
      accent="gild"
      onExit={onExit}
    />
  )
}
