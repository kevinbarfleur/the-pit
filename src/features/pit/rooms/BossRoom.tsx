import { RoomStub } from './RoomStub'

export function BossRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Boss"
      glyph="◈"
      blurb="the floor-keeper regards you. later: phases + meter + big reward."
      accent="danger"
      onExit={onExit}
    />
  )
}
