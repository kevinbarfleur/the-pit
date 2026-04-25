import type { CharacterDef } from '../types'

/**
 * Horned demon. No weapon — both arms end in claws. The default attack
 * still reads correctly because the front "claw" arm swings exactly
 * like an armed limb; we just skip the `weapon` rig slot. Idle pose
 * keeps the arms hanging instead of perpendicular (no blade to
 * stabilise).
 */
export const DEMON: CharacterDef = {
  name: 'DÉMON',
  parts: {
    head: {
      grid: [
        'KK     KK',
        'KDK   KDK',
        'KDDK KDDK',
        'KDDDDDDDD',
        'KDoTKToDK',
        'KDDoooDDK',
        'KdoTToodK',
        'KDDoooDDK',
        ' KKKKKKK ',
      ],
      pivot: { x: 4, y: 8 },
    },
    torso: {
      grid: [
        ' KKKKKK ',
        'KDDrrDDK',
        'KDrrrrDK',
        'KDoooooK',
        'KDDDDDDK',
        'KDoooDDK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armFront: {
      grid: ['KDK', 'KDK', 'KDK', 'KDK', 'KKK', 'KoK', 'KoK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armBack: {
      grid: ['KDK', 'KDK', 'KDK', 'KDK', 'KKK', 'KoK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    legs: {
      grid: [
        'KDDK KDDK',
        'KDDK KDDK',
        'KDoK KDoK',
        'KooK KooK',
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
  ],
  idlePose: { armFront: 0, armBack: 0 },
}
