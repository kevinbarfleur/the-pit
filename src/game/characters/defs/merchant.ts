import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Hooded merchant. Legless (robe drags), holds a small coin pouch in
 * the front hand instead of a weapon. Idle override sways the pouch
 * slightly so it feels like dead weight at the end of the arm rather
 * than a held instrument.
 *
 * Designed to stand on a shop island — small footprint, neutral pose,
 * no aggressive motions.
 */
export const MERCHANT: CharacterDef = {
  name: 'MARCHAND',
  parts: {
    head: {
      grid: [
        '  KKKKK  ',
        ' KNNNNNK ',
        'KNLLLLLNK',
        'KNLPPPLNK',
        'KNLPaPLNK',
        'KNLPPPLNK',
        ' KLLLLLK ',
        '  KKKKK  ',
      ],
      pivot: { x: 4, y: 7 },
    },
    torso: {
      grid: [
        ' KKKKKKKK ',
        'KNLLLLLLNK',
        'KNLLLYLLNK',
        'KNLLLLLLNK',
        'KNLLNNLLNK',
        'KNLLLLLLNK',
        'KNLLLLLLNK',
        ' KKKKKKKK ',
      ],
      pivot: { x: 4, y: 7 },
    },
    armBack: {
      grid: ['KNK', 'KNK', 'KNK', 'KNK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KNK', 'KNK', 'KNK', 'KNK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        ' KKK ',
        'KYTYK',
        'KYYYK',
        'KYTYK',
        ' KKK ',
      ],
      pivot: { x: 2, y: 0 },
    },
  },
  rig: [
    { part: 'armBack', parent: null, at: [-2, -7] },
    { part: 'torso', parent: null, at: [0, 0] },
    { part: 'head', parent: 'torso', at: [4, 0] },
    { part: 'armFront', parent: 'torso', at: [7, 1] },
    { part: 'weapon', parent: 'armFront', at: [1, 6] },
  ],
  // Pouch dangles from the wrist — rotation 0 = straight down from pivot.
  idlePose: { armFront: 0, weapon: 0 },
  animations: {
    idle(char, t) {
      const result = defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      // Pouch sway — short pendulum, slower than the breath cycle.
      if (parts.weapon) {
        parts.weapon.rotation += Math.sin(t * 0.05 + ph) * 0.08
      }
      return result
    },
  },
}
