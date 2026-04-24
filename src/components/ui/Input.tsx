import { forwardRef } from 'react'
import type { InputHTMLAttributes, ReactNode } from 'react'
import styles from './Input.module.css'

interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'size'> {
  icon?: ReactNode
  cursor?: boolean
  cursorSize?: 'default' | 'small'
  wrapperClassName?: string
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { icon, cursor, cursorSize = 'default', wrapperClassName, className, ...rest },
  ref,
) {
  return (
    <div className={`${styles.wrap} ${wrapperClassName ?? ''}`.trim()}>
      {icon !== undefined && (
        <span className={styles.icon} aria-hidden>
          {icon}
        </span>
      )}
      <input ref={ref} className={`${styles.field} ${className ?? ''}`.trim()} {...rest} />
      {cursor && (
        <span
          className={`${styles.cursor} ${cursorSize === 'small' ? styles.cursorSmall : ''}`}
          aria-hidden
        />
      )}
    </div>
  )
})
