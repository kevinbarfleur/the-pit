import { RoomStub } from './RoomStub'

export function CombatRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Combat"
      glyph="⚔"
      blurb="a lesser grind. later: real arena + intents + meter."
      accent="danger"
      onExit={onExit}
    />
  )
}
