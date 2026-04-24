import styles from './Heraldry.module.css'

const CREST = `     ╱◆╲
   ╔═╝◆╚═╗
  ┃▓░◈░▓┃
   ╚═╗◆╔═╝
     ╲◆╱
    ░▒▓▒░`

export function Heraldry() {
  return <pre className={styles.heraldry}>{CREST}</pre>
}
