import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Mutant crab — sideways body, no head/legs. Twin pincers (`armFront`
 * and `armBack`) snap in counter-time during idle, then both lunge
 * forward together on attack. The carapace is the only "torso"; eyes
 * are baked into the top of its grid.
 *
 * Custom attack overrides the engine default because there's no weapon
 * arc — the strike is a simultaneous claw clamp instead of a swing.
 */
export const CRAB: CharacterDef = {
  name: 'CRABE MUT.',
  parts: {
    torso: {
      grid: [
        '  KMK     KMK   ',
        '  KMTK   KTMK   ',
        '  KMMK   KMMK   ',
        '   KMK   KMK    ',
        '    KKK KKK     ',
        '                ',
        ' KOOOOOOOOOOK   ',
        'KOMMmmMMmmMMOK  ',
        'KOMMOmmmmOMMOK  ',
        'KOmMOOOOOOMmOK  ',
        ' KOMMmmmmMMOK   ',
        '  KKKKKKKKKK    ',
      ],
      pivot: { x: 8, y: 11 },
    },
    armBack: {
      grid: [' KK ', 'KOOK', 'KOmK', 'KOOK', ' KK ', ' KK ', ' KK '],
      pivot: { x: 1, y: 6 },
    },
    armFront: {
      grid: [' KK ', 'KOOK', 'KOmK', 'KOOK', ' KK ', ' KK ', ' KK '],
      pivot: { x: 1, y: 6 },
    },
  },
  rig: [
    { part: 'armBack', parent: null, at: [-6, -2] },
    { part: 'torso', parent: null, at: [0, 0] },
    { part: 'armFront', parent: null, at: [6, -2] },
  ],
  idlePose: { armFront: 0.3, armBack: -0.3 },
  animations: {
    idle(char, t) {
      const result = defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      if (parts.armFront) {
        parts.armFront.rotation = 0.3 + Math.sin(t * 0.08 + ph) * 0.15
      }
      if (parts.armBack) {
        parts.armBack.rotation = -0.3 + Math.sin(t * 0.08 + ph + 1.2) * 0.15
      }
      result.rootDx = Math.round(Math.sin(t * 0.03 + ph) * 2)
      return result
    },
    attack(char, _t, p) {
      const parts = char.parts as Record<string, { rotation: number }>
      let frontRot = 0.3
      let backRot = -0.3
      let rootDx = 0
      if (p < 0.3) {
        const q = p / 0.3
        frontRot = 0.3 + q * 0.6
        backRot = -0.3 - q * 0.6
      } else if (p < 0.5) {
        const q = (p - 0.3) / 0.2
        const eased = q * (2 - q)
        frontRot = 0.9 - eased * 1.5
        backRot = -0.9 + eased * 1.5
        rootDx = eased * 4
      } else {
        const q = (p - 0.5) / 0.5
        frontRot = -0.6 + q * 0.9
        backRot = 0.6 - q * 0.9
        rootDx = 4 - q * 4
      }
      if (parts.armFront) parts.armFront.rotation = frontRot
      if (parts.armBack) parts.armBack.rotation = backRot
      return { rootDx, rootDy: 0, tint: 0xffffff }
    },
  },
}
