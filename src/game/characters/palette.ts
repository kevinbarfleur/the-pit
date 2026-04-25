import type { Palette } from './types'

/**
 * Shared palette across the bestiary. Each key is a single character
 * used in part grids; spaces (and any unmapped char) render as
 * transparent. Tones are tuned for the dark gilded aesthetic of the
 * pit — desaturated bone, dried blood, tarnished gold.
 */
export const CHARACTER_PALETTE: Palette = {
  // Outline / shadow
  K: 0x05030a,
  F: 0x110a14,
  // Skin / bone
  I: 0x8a8278,
  i: 0x44403c,
  A: 0x6a605a,
  a: 0x342e36,
  // Flesh / tan
  P: 0xa68872,
  p: 0x6a4c3a,
  d: 0x301c10,
  // Blood / red
  R: 0x8a2c20,
  r: 0x4a1810,
  H: 0x240808,
  // Violet / arcane
  V: 0x4c2a5e,
  v: 0x281438,
  // Gold
  Y: 0x7e6428,
  y: 0x3e3010,
  T: 0xc4a04a,
  // Wood / brown
  L: 0x6c4a2a,
  l: 0x2c1808,
  N: 0x4a2c1a,
  n: 0x1e0e08,
  // Ice / steel
  C: 0x6890a0,
  c: 0x2c4858,
  // Cloth shadow
  X: 0x1c1620,
  x: 0x0c0810,
  // Bone (warm)
  S: 0xa89070,
  s: 0x60503c,
  // Spectre blue
  B: 0x90a8b8,
  b: 0x405468,
  // Demon red (deep)
  D: 0x6a1410,
  // Crab carapace orange
  O: 0x7a3818,
  o: 0x3c1808,
  // Zombie flesh (sallow green)
  E: 0x6e7c4a,
  e: 0x383e22,
  // Forest / archer green
  G: 0x4a5e30,
  g: 0x2a3a18,
  // Mutant magenta
  M: 0x7a3850,
  m: 0x3c1828,
}
