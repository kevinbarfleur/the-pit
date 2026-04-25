import type { CharacterDef } from '../types'

/**
 * The canonical character — every standard slot present, no animation
 * overrides. Holds an axe perpendicular to the arm at rest (ready to
 * strike). Used as the reference rig for all engine defaults.
 */
export const MARAUDER: CharacterDef = {
  name: 'MARAUDER',
  parts: {
    head: {
      grid: [
        ' KKKKKK ',
        'KIRrRrIK',
        'KIRRrRIK',
        'KIIIIIIK',
        'KIaKKaIK',
        'KIIIIIIK',
        'KdPPPPdK',
        ' KKKKKK ',
      ],
      pivot: { x: 4, y: 7 },
    },
    torso: {
      grid: [
        '  KKKK  ',
        ' KIIIIK ',
        'KIYYYYIK',
        'KIYIIYIK',
        'KIIIIIIK',
        'KILLLLIK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armBack: {
      grid: ['KIK', 'KIK', 'KIK', 'KIK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KIK', 'KIK', 'KIK', 'KIK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        '  KK ',
        '  KL ',
        '  KL ',
        ' KKKK',
        'KIIIK',
        'KIIIK',
        ' KKK ',
      ],
      pivot: { x: 2, y: 0 },
    },
    legs: {
      grid: [
        'KIIK KIIK',
        'KLLK KLLK',
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
  idlePose: { armFront: 0, weapon: -Math.PI / 2 },
}
