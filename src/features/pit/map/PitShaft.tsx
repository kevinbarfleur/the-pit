import styles from './PitShaft.module.css'

/**
 * Decorative walls + haze background for the shaft. Purely visual — no
 * interaction, no game state. Sits behind the depth gauge and chains, in
 * the central column's z-stack. V1 is CSS-only (repeating gradient + a
 * couple of pseudo-element overlays); can be promoted to Pixi later for
 * animated bricks without changing the component API.
 */
export function PitShaft() {
  return <div className={styles.shaft} aria-hidden="true" data-pit-chrome />
}
