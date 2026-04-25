import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Bone-rattling sword grunt. Same anatomy as Marauder but carries a
 * straight blade and a permanent jitter — every part wiggles on a
 * desynced sine, picked from the part's name to keep it deterministic
 * per character.
 */
export const SKELETON: CharacterDef = {
  name: 'SQUELETTE',
  parts: {
    head: {
      grid: [
        ' KKKKKKK ',
        'KSSSSSSSK',
        'KSKsSsKSK',
        'KSSSKSSSK',
        'KSsKsKsSK',
        'KsKsKsKsK',
        ' KKKKKKK ',
      ],
      pivot: { x: 4, y: 6 },
    },
    torso: {
      grid: [
        ' KKKKKK ',
        'KSSKKSSK',
        'KSKSSKSK',
        'KSSKKSSK',
        'KSKSSKSK',
        'KSSSSSSK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armBack: {
      grid: ['KSK', 'KSK', 'KSK', 'KSK', 'KSK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KSK', 'KSK', 'KSK', 'KSK', 'KSK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        '  K  ',
        ' KLK ',
        'KKKKK',
        ' KIK ',
        ' KIK ',
        ' KIK ',
        ' KIK ',
        '  K  ',
      ],
      pivot: { x: 2, y: 0 },
    },
    legs: {
      grid: ['KSK KSK', 'KSK KSK', 'KSK KSK', 'KSK KSK', 'KKK KKK'],
      pivot: { x: 3, y: 0 },
    },
  },
  rig: [
    { part: 'legs', parent: null, at: [0, -5] },
    { part: 'armBack', parent: null, at: [-2, -10] },
    { part: 'torso', parent: null, at: [0, -5] },
    { part: 'head', parent: 'torso', at: [3, 0] },
    { part: 'armFront', parent: 'torso', at: [6, 1] },
    { part: 'weapon', parent: 'armFront', at: [1, 5] },
  ],
  idlePose: { armFront: 0, weapon: -Math.PI / 2 },
  animations: {
    idle(char, t) {
      const result = defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      for (const [name, part] of Object.entries(parts)) {
        const f = name.charCodeAt(0) * 0.013
        part.rotation += Math.sin(t * 0.5 + f + ph) * 0.015
      }
      return result
    },
  },
}
