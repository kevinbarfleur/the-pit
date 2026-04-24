import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import {
  Bar,
  Button,
  Card,
  Footer,
  Heraldry,
  Input,
  Kbd,
  Menubar,
  Node,
  Panel,
  PanelTitle,
  Pill,
  PixelFrame,
  Ribbon,
  Row,
  SegBar,
  Tier,
  Topbar,
} from './index'
import { EffectsContext } from '../pixi/EffectsProvider'
import type { EffectsEngine } from '../../pixi/EffectsEngine'

function stubEngine(overrides: Partial<EffectsEngine> = {}): EffectsEngine {
  const base = {
    emitBurst: vi.fn(),
    emitShockwave: vi.fn(),
    emitDrip: vi.fn(),
    attach: vi.fn(() => () => {}),
    attachWithHandle: vi.fn(() => ({ id: 1, detach: () => {} })),
    setEnabled: vi.fn(),
    detach: vi.fn(),
  }
  return { ...base, ...overrides } as unknown as EffectsEngine
}

describe('layout primitives', () => {
  it('PixelFrame renders title + children + corners', () => {
    render(
      <PixelFrame title="Test" right="meta">
        <span>body</span>
      </PixelFrame>,
    )
    expect(screen.getByText('Test')).toBeInTheDocument()
    expect(screen.getByText('meta')).toBeInTheDocument()
    expect(screen.getByText('body')).toBeInTheDocument()
  })

  it('PixelFrame supports tones', () => {
    const { rerender } = render(<PixelFrame>x</PixelFrame>)
    rerender(<PixelFrame tone="raised">x</PixelFrame>)
    rerender(<PixelFrame tone="gild">x</PixelFrame>)
    expect(screen.getByText('x')).toBeInTheDocument()
  })

  it('Panel + Ribbon + Heraldry + PanelTitle render without error', () => {
    render(
      <div>
        <Panel>p</Panel>
        <PanelTitle>t</PanelTitle>
        <Ribbon>r</Ribbon>
        <Heraldry />
      </div>,
    )
    expect(screen.getByText('p')).toBeInTheDocument()
    expect(screen.getByText('t')).toBeInTheDocument()
    expect(screen.getByText('r')).toBeInTheDocument()
  })
})

describe('display primitives', () => {
  it('Kbd renders content', () => {
    render(<Kbd>esc</Kbd>)
    expect(screen.getByText('esc')).toBeInTheDocument()
  })

  it('Pill renders with all tones', () => {
    render(
      <div>
        <Pill>neutral</Pill>
        <Pill tone="g">g</Pill>
        <Pill tone="a">a</Pill>
        <Pill tone="r">r</Pill>
        <Pill tone="v">v</Pill>
        <Pill tone="c">c</Pill>
        <Pill tone="g" dot>
          with dot
        </Pill>
      </div>,
    )
    expect(screen.getByText('neutral')).toBeInTheDocument()
    expect(screen.getByText('with dot')).toBeInTheDocument()
  })

  it('Tier renders the correct glyph for each level', () => {
    const { rerender } = render(<Tier t={0} />)
    expect(screen.getByText('◈ T0')).toBeInTheDocument()
    rerender(<Tier t={1} />)
    expect(screen.getByText('◇ T1')).toBeInTheDocument()
    rerender(<Tier t={2} />)
    expect(screen.getByText('◆ T2')).toBeInTheDocument()
    rerender(<Tier t={3} />)
    expect(screen.getByText('○ T3')).toBeInTheDocument()
  })

  it('Bar clamps pct to [0, 100]', () => {
    const { container, rerender } = render(<Bar kind="hp" pct={150} />)
    const fill = container.querySelector('span[style*="width"]') as HTMLElement
    expect(fill.style.width).toBe('100%')

    rerender(<Bar kind="hp" pct={-50} />)
    const fill2 = container.querySelector('span[style*="width"]') as HTMLElement
    expect(fill2.style.width).toBe('0%')
  })

  it('SegBar lights the right number of segments', () => {
    const { container } = render(<SegBar total={5} on={3} />)
    const segments = container.querySelectorAll('span')
    expect(segments).toHaveLength(5)
  })
})

describe('interactive primitives', () => {
  it('Button renders variants + sizes', () => {
    const { rerender } = render(<Button>default</Button>)
    expect(screen.getByText('default')).toBeInTheDocument()
    rerender(<Button variant="primary">primary</Button>)
    rerender(<Button variant="danger">danger</Button>)
    rerender(<Button variant="ghost" size="lg">
      ghost lg
    </Button>)
    expect(screen.getByText('ghost lg')).toBeInTheDocument()
  })

  it('Button disabled attribute works', () => {
    render(<Button disabled>x</Button>)
    const btn = screen.getByText('x').closest('button') as HTMLButtonElement
    expect(btn).toBeDisabled()
  })

  it('Button juicy calls emitBurst with variant on pointerdown', () => {
    const engine = stubEngine()
    render(
      <EffectsContext.Provider value={engine}>
        <Button juicy variant="primary">
          descend
        </Button>
      </EffectsContext.Provider>,
    )
    const btn = screen.getByText('descend').closest('button') as HTMLButtonElement
    fireEvent.pointerDown(btn, { clientX: 42, clientY: 64 })
    expect(engine.emitBurst).toHaveBeenCalledTimes(1)
    expect(engine.emitBurst).toHaveBeenCalledWith({ x: 42, y: 64, variant: 'primary' })
  })

  it('Button without juicy does NOT call emitBurst', () => {
    const engine = stubEngine()
    render(
      <EffectsContext.Provider value={engine}>
        <Button>cold</Button>
      </EffectsContext.Provider>,
    )
    const btn = screen.getByText('cold').closest('button') as HTMLButtonElement
    fireEvent.pointerDown(btn, { clientX: 10, clientY: 20 })
    expect(engine.emitBurst).not.toHaveBeenCalled()
  })

  it('Button primary+juicy attaches a hover aura via the engine', () => {
    const engine = stubEngine()
    render(
      <EffectsContext.Provider value={engine}>
        <Button juicy variant="primary">
          descend
        </Button>
      </EffectsContext.Provider>,
    )
    expect(engine.attachWithHandle).toHaveBeenCalled()
  })

  it('Input renders with icon and cursor', () => {
    render(<Input icon="⌕" cursor placeholder="search" />)
    expect(screen.getByText('⌕')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('search')).toBeInTheDocument()
  })

  it('Row supports selected state', () => {
    const { container } = render(
      <div>
        <Row>plain</Row>
        <Row selected>active</Row>
      </div>,
    )
    const rows = container.querySelectorAll('div')
    // Selected row has an extra class applied
    expect(screen.getByText('active').className).not.toEqual(screen.getByText('plain').className)
    expect(rows.length).toBeGreaterThan(0)
  })

  it('Card renders all optional parts', () => {
    render(
      <Card
        tier={2}
        name="Ember Hook"
        slot="mainhand"
        desc="on hit: burn 1"
        tags="fire"
        flavor="it bites back."
        footer={<span>foot</span>}
      />,
    )
    expect(screen.getByText('Ember Hook')).toBeInTheDocument()
    expect(screen.getByText('mainhand')).toBeInTheDocument()
    expect(screen.getByText('on hit: burn 1')).toBeInTheDocument()
    expect(screen.getByText('fire')).toBeInTheDocument()
    expect(screen.getByText(/it bites back\./)).toBeInTheDocument()
    expect(screen.getByText('foot')).toBeInTheDocument()
  })
})

describe('nav primitives', () => {
  it('Topbar renders brand, title, and pills', () => {
    render(<Topbar title="camp" gold="124" scrap={38} torch="5/5" />)
    expect(screen.getByText('THE·PIT')).toBeInTheDocument()
    expect(screen.getByText('camp')).toBeInTheDocument()
    expect(screen.getByText(/gold/)).toBeInTheDocument()
    expect(screen.getByText(/scrap/)).toBeInTheDocument()
    expect(screen.getByText(/torch/)).toBeInTheDocument()
  })

  it('Menubar marks the active item', () => {
    const onSelect = vi.fn()
    render(
      <Menubar
        active="D"
        onSelect={onSelect}
        items={[
          { key: 'D', label: 'Delve' },
          { key: 'P', label: 'Passives' },
        ]}
      />,
    )
    expect(screen.getByText('Delve')).toBeInTheDocument()
    expect(screen.getByText('Passives')).toBeInTheDocument()
    fireEvent.click(screen.getByText('Passives'))
    expect(onSelect).toHaveBeenCalledWith('P')
  })

  it('Footer renders kbd/label pairs', () => {
    render(
      <Footer
        items={[
          { k: '↵', l: 'confirm' },
          { k: 'esc', l: 'back' },
        ]}
      />,
    )
    expect(screen.getByText('↵')).toBeInTheDocument()
    expect(screen.getByText('confirm')).toBeInTheDocument()
    expect(screen.getByText('esc')).toBeInTheDocument()
    expect(screen.getByText('back')).toBeInTheDocument()
  })

  it('Node renders all variants', () => {
    const { rerender } = render(<Node>⚔</Node>)
    expect(screen.getByText('⚔')).toBeInTheDocument()
    rerender(<Node variant="now">◉</Node>)
    rerender(<Node variant="elite">◆</Node>)
    rerender(<Node variant="boss">◈ BOSS</Node>)
    rerender(<Node variant="locked">◇</Node>)
    expect(screen.getByText('◇')).toBeInTheDocument()
  })
})
