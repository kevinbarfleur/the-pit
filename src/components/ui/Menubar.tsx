import styles from './Menubar.module.css'

export interface MenubarItem {
  key: string
  label: string
}

interface MenubarProps {
  items: MenubarItem[]
  active?: string
  onSelect?: (key: string) => void
}

export function Menubar({ items, active, onSelect }: MenubarProps) {
  return (
    <nav className={styles.menubar} aria-label="Primary">
      {items.map((it) => (
        <div
          key={it.key}
          className={`${styles.item} ${it.key === active ? styles.active : ''}`}
          onClick={() => onSelect?.(it.key)}
        >
          <span className={styles.kbd}>[{it.key}]</span> {it.label}
        </div>
      ))}
    </nav>
  )
}
