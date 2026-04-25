import type { CharacterDef } from '../types'

/**
 * Heavily armoured templar — war hammer in the front hand, smaller back
 * arm tucked across the body like a shield. Defensive resting pose: the
 * hammer sits raised in a high guard rather than swinging at the hip,
 * so the silhouette reads as "ready" instead of "idle".
 */
export const TEMPLAR: CharacterDef = {
  name: 'TEMPLIER',
  parts: {
    head: {
      grid: [
        ' KKKKKK ',
        'KIIYTYII',
        'KIIIIIII',
        'KIaaaaaI',
        'KIaKKaaI',
        'KIIIIIII',
        ' KKKKKK ',
      ],
      pivot: { x: 4, y: 6 },
    },
    torso: {
      grid: [
        ' KKKKKKK ',
        'KIIYTYIIK',
        'KIIYYYIIK',
        'KIYTTTYIK',
        'KIYYYYYIK',
        'KIIIIIIIK',
        'KIaIaIaIK',
        ' KKKKKKK ',
      ],
      pivot: { x: 4, y: 7 },
    },
    armFront: {
      grid: ['KIK', 'KIK', 'KIK', 'KIK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armBack: {
      grid: ['KIK', 'KIK', 'KIK', 'KIK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        ' KK  ',
        ' KL  ',
        ' KL  ',
        ' KK  ',
        'KKKKK',
        'KIYTI',
        'KIYTI',
        'KKKKK',
      ],
      pivot: { x: 1, y: 0 },
    },
    legs: {
      grid: [
        'KIIK KIIK',
        'KIIK KIIK',
        'KIIK KIIK',
        'KnIK KIaK',
        'KKKK KKKK',
      ],
      pivot: { x: 4, y: 0 },
    },
  },
  rig: [
    { part: 'legs', parent: null, at: [0, -5] },
    { part: 'armBack', parent: null, at: [-3, -11] },
    { part: 'torso', parent: null, at: [0, -5] },
    { part: 'armFront', parent: 'torso', at: [7, 2] },
    { part: 'head', parent: 'torso', at: [4, 0] },
    { part: 'weapon', parent: 'armFront', at: [1, 6] },
  ],
  idlePose: { armFront: -1.4, armBack: 0.5, weapon: -Math.PI / 2 },
}
