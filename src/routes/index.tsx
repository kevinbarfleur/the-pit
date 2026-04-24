import { useRef, useState } from 'react'
import { createFileRoute } from '@tanstack/react-router'
import { useAttachedEffect } from '../hooks/useAttachedEffect'
import styles from './index.module.css'

export const Route = createFileRoute('/')({
  component: TitlePage,
})

const PIT_ASCII = String.raw`
 ████████╗ ██╗  ██╗ ███████╗    ██████╗  ██╗ ████████╗
 ╚══██╔══╝ ██║  ██║ ██╔════╝    ██╔══██╗ ██║ ╚══██╔══╝
    ██║    ███████║ █████╗      ██████╔╝ ██║    ██║
    ██║    ██╔══██║ ██╔══╝      ██╔═══╝  ██║    ██║
    ██║    ██║  ██║ ███████╗    ██║      ██║    ██║
    ╚═╝    ╚═╝  ╚═╝ ╚══════╝    ╚═╝      ╚═╝    ╚═╝
    ▓▒      ▓▒  ▓▒   ▓▒          ▓▒      ▓▒     ▓▒
    ▓▒      ▒    ▒   ▓▒          ▓▒       ▒     ▓▒
    ▓▒      ▒        ▓▒          ▓▒       ▒     ▓▒
    ▒       ░        ▒                    ░      ▒
    ▒                                             ░
    ░
`

const MENU_ITEMS = [
  { key: 'new', label: 'new run', dim: false, meta: '' },
  { key: 'continue', label: 'continue', dim: true, meta: 'D012 torch 3/5' },
  { key: 'leaderboards', label: 'leaderboards', dim: true, meta: '' },
  { key: 'settings', label: 'settings', dim: true, meta: '' },
] as const

function TitlePage() {
  const [selected, setSelected] = useState<string>('new')
  const wordmarkRef = useRef<HTMLPreElement | null>(null)

  // Real Pixi drops falling from the wordmark's glyphs. Continuous.
  useAttachedEffect(wordmarkRef, 'drips')

  return (
    <main className={styles.page}>
      <div className={styles.body}>
        <pre ref={wordmarkRef} className={styles.wordmark}>
          {PIT_ASCII}
        </pre>
        <div className={styles.tagline}>"every descent writes your economy"</div>
        <div className={styles.menu}>
          {MENU_ITEMS.map((it) => (
            <button
              key={it.key}
              type="button"
              className={`${styles.item} ${selected === it.key ? styles.sel : ''}`.trim()}
              onClick={() => setSelected(it.key)}
            >
              {it.label}
              {it.meta ? <> · {it.meta}</> : null}
            </button>
          ))}
        </div>
      </div>
    </main>
  )
}
