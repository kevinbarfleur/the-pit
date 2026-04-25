import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Legless caster — robe touches the floor. Carries a skull-tipped staff
 * held vertical by default. Idle override layers a slow lateral robe
 * sway and a subtle staff vibration on top of the engine default.
 */
export const WITCH: CharacterDef = {
  name: 'SORCIÈRE',
  parts: {
    head: {
      grid: [
        '     KK    ',
        '    KvvK   ',
        '   KvVvVK  ',
        '  KvVHRVvK ',
        ' KvVVVVVvK ',
        'KKvVVVvKKK ',
        '  KPPPPK   ',
        ' KPCKpKCK  ',
        ' KPPPPPPK  ',
        ' KdddddK   ',
        '  KKKKK    ',
      ],
      pivot: { x: 4, y: 10 },
    },
    torso: {
      grid: [
        '  KKKKKK  ',
        ' KXVVVVXK ',
        'KXVVVVVVXK',
        'KXVvvvvVXK',
        'KXVVVVVVXK',
        'KXvVvVvVXK',
        'KXVVVVVVXK',
        'KXxxxxxxXK',
        ' KXxxxxXK ',
        ' KKKKKKKK ',
      ],
      pivot: { x: 4, y: 9 },
    },
    armBack: {
      grid: ['KXK', 'KXK', 'KXK', 'KVK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KXK', 'KXK', 'KXK', 'KVK', 'KKK', 'KPK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    weapon: {
      grid: [
        '  KK ',
        '  KL ',
        '  KK ',
        ' KSSK',
        'KSSSK',
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
  idlePose: { armFront: 0, weapon: -Math.PI },
  animations: {
    idle(char, t) {
      defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      if (parts.weapon) {
        parts.weapon.rotation += Math.sin(t * 0.06 + ph) * 0.04
      }
      if (parts.torso) {
        parts.torso.rotation = Math.sin(t * 0.03 + ph) * 0.015
      }
      return {
        rootDx: 0,
        rootDy: Math.round(Math.sin(t * 0.04 + ph) * 1),
        tint: 0xffffff,
      }
    },
  },
}
