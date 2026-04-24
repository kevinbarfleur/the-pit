import { RoomStub } from './RoomStub'

export function EventRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Event"
      glyph="~"
      blurb="something speaks in the dark. later: choice prompts + outcomes."
      onExit={onExit}
    />
  )
}
