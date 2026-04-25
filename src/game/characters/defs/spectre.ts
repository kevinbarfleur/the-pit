import type { CharacterDef } from '../types'
import { defaultIdle } from '../../../pixi/CharacterEngine'

/**
 * Floating, legless wraith. Has a tail in place of legs; arms drift
 * freely. Alpha pulses at idle. Hurt is overridden — the spectre
 * doesn't recoil, it briefly fades out instead.
 */
export const SPECTRE: CharacterDef = {
  name: 'SPECTRE',
  parts: {
    head: {
      grid: [
        ' KBBBBK ',
        'KBBBBBBK',
        'KBKbBBbK',
        'KBBBBBBK',
        'KBBBBBBK',
        ' KKKKKK ',
      ],
      pivot: { x: 4, y: 5 },
    },
    torso: {
      grid: [
        ' KBBBBBBK ',
        'KBBBBBBBBK',
        'KBbBBBBbBK',
        'KBBBBBBBBK',
        'KBbBBBBbBK',
        'KBBBBBBBBK',
        'KBBBBBBBBK',
        ' KKKKKKKK ',
      ],
      pivot: { x: 4, y: 7 },
    },
    armBack: {
      grid: ['KBK', 'KBK', 'KBK', 'KBK', 'KBK'],
      pivot: { x: 1, y: 0 },
    },
    armFront: {
      grid: ['KBK', 'KBK', 'KBK', 'KBK', 'KBK'],
      pivot: { x: 1, y: 0 },
    },
    tail: {
      grid: [
        ' KBBBK ',
        ' KBbBK ',
        ' KBBBK ',
        '  KBK  ',
        '  KBK  ',
        '  KKK  ',
      ],
      pivot: { x: 3, y: 0 },
    },
  },
  rig: [
    { part: 'tail', parent: null, at: [0, -6] },
    { part: 'armBack', parent: null, at: [-2, -12] },
    { part: 'torso', parent: null, at: [0, -6] },
    { part: 'head', parent: 'torso', at: [4, 0] },
    { part: 'armFront', parent: 'torso', at: [7, 1] },
  ],
  animations: {
    idle(char, t) {
      const result = defaultIdle(char, t, 0)
      const parts = char.parts as Record<string, { rotation: number }>
      const ph = char.idlePhase
      if (parts.tail) parts.tail.rotation = Math.sin(t * 0.06 + ph) * 0.25
      if (parts.armFront)
        parts.armFront.rotation = Math.sin(t * 0.04 + ph) * 0.1
      if (parts.armBack)
        parts.armBack.rotation = Math.sin(t * 0.04 + ph + 1.5) * 0.1
      result.alpha = 0.72 + Math.sin(t * 0.04 + ph) * 0.12
      return result
    },
    hurt(char, _t, p) {
      const parts = char.parts as Record<string, { rotation: number }>
      const k = 1 - p
      if (parts.head) parts.head.rotation = Math.sin(p * Math.PI * 5) * 0.2 * k
      if (parts.torso)
        parts.torso.rotation = Math.sin(p * Math.PI * 5 + 1) * 0.1 * k
      if (parts.armFront)
        parts.armFront.rotation = Math.sin(p * Math.PI * 6) * 0.3 * k
      if (parts.armBack)
        parts.armBack.rotation = Math.sin(p * Math.PI * 6 + 2) * 0.3 * k
      if (parts.tail) parts.tail.rotation = Math.sin(p * Math.PI * 4) * 0.4 * k

      const rootDx = -6 * Math.pow(k, 2)
      const r = 0xaa
      const g = Math.floor(0xff - k * 0x44)
      const b = 0xff
      return {
        rootDx,
        rootDy: 0,
        tint: (r << 16) | (g << 8) | b,
        alpha: 0.4 + p * 0.5,
      }
    },
  },
}
