import type { CharacterDef } from '../types'

/**
 * Hooded bandit with a short dagger held reverse-grip. Furtive pose:
 * front arm slightly raised, blade horizontal forward — ready to lunge,
 * never resting like an axe. No animation overrides; engine defaults
 * carry the swing.
 */
export const BANDIT: CharacterDef = {
  name: 'BANDIT',
  parts: {
    head: {
      grid: [
        ' KKKKKK ',
        'KaaaaaaK',
        'KaaaaaaK',
        'KaXKpKpX',
        'KaXpPpPX',
        ' KppppK ',
        '  KppK  ',
        '  KKKK  ',
      ],
      pivot: { x: 4, y: 7 },
    },
    torso: {
      grid: [
        '  KKKK  ',
        ' KLLLLK ',
        'KLnnLLnK',
        'KLnnnnLK',
        'KLLLLLLK',
        'KLnnnnLK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armBack: {
      grid: ['KLK', 'KLK', 'KLK', 'KLK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KLK', 'KLK', 'KLK', 'KLK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        ' KK ',
        'KLLK',
        'KKKK',
        ' KIK',
        ' KIK',
        ' KIK',
        ' KK ',
      ],
      pivot: { x: 2, y: 0 },
    },
    legs: {
      grid: [
        'KLLK KLLK',
        'KLLK KLLK',
        'KnLK KnLK',
        'KnKK KKnK',
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
  idlePose: { armFront: -0.3, weapon: -Math.PI / 2 },
}
