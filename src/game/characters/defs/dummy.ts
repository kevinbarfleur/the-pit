import type { CharacterDef } from '../types'

/**
 * Pell — wooden training post with a painted target. Static idle (no
 * breathing). Reacts to hurt with a recoil + horizontal shake; attack
 * is a no-op. Used in the bestiary scene to anchor each warrior's
 * strike direction.
 */
export const DUMMY: CharacterDef = {
  name: 'PELL',
  parts: {
    body: {
      grid: [
        ' KKK ',
        'KIIIK',
        'KIIIK',
        'KIRIK',
        'KRRRK',
        'KRRRK',
        'KIRIK',
        'KIIIK',
        'KIIIK',
        'KIIIK',
        'KIIIK',
        'KIIIK',
        ' KKK ',
        'KLLLK',
        'KKKKK',
      ],
      pivot: { x: 2, y: 14 },
    },
  },
  rig: [{ part: 'body', parent: null, at: [0, 0] }],
  animations: {
    idle() {
      return { rootDx: 0, rootDy: 0, tint: 0xffffff }
    },
    attack() {
      return { rootDx: 0, rootDy: 0, tint: 0xffffff }
    },
    hurt(char, _t, p) {
      const k = 1 - p
      const recoil = -8 * Math.pow(k, 2)
      const shake = Math.sin(p * Math.PI * 9) * 2 * k
      const parts = char.parts as Record<string, { rotation: number }>
      if (parts.body) parts.body.rotation = -0.06 * k
      return { rootDx: recoil + shake, rootDy: 0, tint: 0xffffff }
    },
  },
}
