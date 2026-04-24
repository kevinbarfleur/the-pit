import { RoomStub } from './RoomStub'

export function RestRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Rest"
      glyph="☩"
      blurb="a quiet moment. later: heal / upgrade / pray."
      onExit={onExit}
    />
  )
}
