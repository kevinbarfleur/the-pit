import styles from './Menubar.module.css'

export interface MenubarItem {
  key: string
  label: string
  /** Render the item but absorb clicks (and grey it out). Used for
   *  features that exist in the navigation but aren't shipped yet. */
  dim?: boolean
}

interface MenubarProps {
  items: MenubarItem[]
  active?: string
  onSelect?: (key: string) => void
}

export function Menubar({ items, active, onSelect }: MenubarProps) {
  return (
    <nav className={styles.menubar} aria-label="Primary">
      {items.map((it) => {
        const className = [
          styles.item,
          it.key === active ? styles.active : '',
          it.dim ? styles.dim : '',
        ]
          .filter(Boolean)
          .join(' ')
        return (
          <div
            key={it.key}
            className={className}
            onClick={() => {
              if (it.dim) return
              onSelect?.(it.key)
            }}
            aria-disabled={it.dim || undefined}
          >
            <span className={styles.kbd}>[{it.key}]</span> {it.label}
            {it.dim && <span className={styles.soon}> · soon</span>}
          </div>
        )
      })}
    </nav>
  )
}
