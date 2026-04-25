import type { CharacterDef } from '../types'

/**
 * Ranger archer. Holds a curved bow vertical in the front hand; back
 * hand draws the (invisible) string near the cheek. Custom `attack` is
 * a draw-aim-release sequence rather than a swing — the bow stays
 * still, only the back arm pulls back and snaps forward.
 */
export const ARCHER: CharacterDef = {
  name: 'ARCHER',
  parts: {
    head: {
      grid: [
        '  KKKK  ',
        ' KGGGGK ',
        'KGgGGgGK',
        'KGKpKpGK',
        'KGpPpPGK',
        ' KppppK ',
        '  KKKK  ',
      ],
      pivot: { x: 4, y: 6 },
    },
    torso: {
      grid: [
        ' KKKKKK ',
        'KGgGGgGK',
        'KGGNNGGK',
        'KGNNNNGK',
        'KGGGGGGK',
        'KGgggggK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armBack: {
      grid: ['KGK', 'KGK', 'KGK', 'KGK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KGK', 'KGK', 'KGK', 'KGK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        '  KK ',
        ' KLLK',
        'KL  L',
        'KL  K',
        'KL  L',
        'KL  L',
        'KL  K',
        'KL  L',
        ' KLLK',
        '  KK ',
      ],
      pivot: { x: 2, y: 5 },
    },
    legs: {
      grid: [
        'KGGK KGGK',
        'KGGK KGGK',
        'KLLK KLLK',
        'KnLK KnLK',
        'KKKK KKKK',
      ],
      pivot: { x: 4, y: 0 },
    },
  },
  rig: [
    { part: 'legs', parent: null, at: [0, -5] },
    { part: 'armBack', parent: null, at: [-2, -10] },
    { part: 'torso', parent: null, at: [0, -5] },
    { part: 'head', parent: 'torso', at: [3, 0] },
    { part: 'armFront', parent: 'torso', at: [6, 1] },
    { part: 'weapon', parent: 'armFront', at: [1, 6] },
  ],
  idlePose: { armFront: -Math.PI / 2, armBack: -2.5, weapon: 0 },
  animations: {
    attack(char, _t, p) {
      const parts = char.parts as Record<string, { rotation: number }>
      const idlePose = char.def.idlePose ?? {}
      const armFrontBase = idlePose.armFront ?? -Math.PI / 2
      const armBackBase = idlePose.armBack ?? -2.5
      const weaponBase = idlePose.weapon ?? 0

      let armBackRot = armBackBase
      let rootDx = 0

      if (p < 0.5) {
        const q = p / 0.5
        armBackRot = armBackBase - q * 0.4
        if (q > 0.7) armBackRot += Math.sin(q * 30) * 0.02
      } else if (p < 0.65) {
        const q = (p - 0.5) / 0.15
        const eased = q * (2 - q)
        armBackRot = armBackBase - 0.4 + eased * 0.4
        rootDx = -eased * 2
      } else {
        const q = (p - 0.65) / 0.35
        armBackRot = armBackBase
        rootDx = -2 + q * 2
      }

      if (parts.armFront) parts.armFront.rotation = armFrontBase
      if (parts.armBack) parts.armBack.rotation = armBackRot
      if (parts.weapon) parts.weapon.rotation = weaponBase
      return { rootDx, rootDy: 0, tint: 0xffffff }
    },
  },
}
