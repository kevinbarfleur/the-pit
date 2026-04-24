import { RoomStub } from './RoomStub'

export function CacheRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Cache"
      glyph="◇"
      blurb="sealed. later: key logic + odds + loot reveal."
      onExit={onExit}
    />
  )
}
