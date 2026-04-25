import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Iconic outstretched-arms zombie — both arms held nearly horizontal
 * forward at rest. Idle override adds an asymmetric sway and a heavy
 * head dodder so the silhouette reads as un-dead even when motionless.
 * Default attack works because the front arm still swings from the
 * stretched pose down to the strike plane.
 */
export const ZOMBIE: CharacterDef = {
  name: 'ZOMBIE',
  parts: {
    head: {
      grid: [
        ' KEEEEK ',
        'KEeEEEeK',
        'KEKHKeEK',
        'KEHRREeK',
        'KEKKKEEK',
        'KEeEEeEK',
        ' KESSSK ',
        '  KKKK  ',
      ],
      pivot: { x: 4, y: 7 },
    },
    torso: {
      grid: [
        ' KEEEEK ',
        'KEEdEEEK',
        'KEeEEEeK',
        'KEEEEEEK',
        'KEeEEEeK',
        'KEEEEEEK',
        ' KKKKKK ',
      ],
      pivot: { x: 3, y: 6 },
    },
    armBack: {
      grid: ['KEK', 'KEK', 'KEK', 'KeK', 'KKK', 'KEK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KEK', 'KEK', 'KEK', 'KeK', 'KKK', 'KEK', 'KKK'],
      pivot: { x: 1, y: 0 },
    },
    legs: {
      grid: [
        'KEEK KEEK',
        'KEEK KEEK',
        'KEeK KeEK',
        'KEKK KKEK',
        'KKK   KKK',
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
  idlePose: { armFront: -1.4, armBack: -1.6 },
  animations: {
    idle(char, t) {
      const result = defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      if (parts.torso) {
        parts.torso.rotation = Math.sin(t * 0.025 + ph) * 0.08
      }
      if (parts.head) {
        parts.head.rotation = Math.sin(t * 0.025 + ph + 0.5) * 0.1
      }
      return result
    },
  },
}
