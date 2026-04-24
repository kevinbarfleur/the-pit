import { RoomStub } from './RoomStub'

export function ShopRoom({ onExit }: { onExit: () => void }) {
  return (
    <RoomStub
      title="Shop"
      glyph="⌂"
      blurb="the merchant waits. later: inventory grid + price tags."
      onExit={onExit}
    />
  )
}
