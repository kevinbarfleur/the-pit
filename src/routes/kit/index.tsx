import { createFileRoute, Link } from '@tanstack/react-router'
import {
  Bar,
  Button,
  Card,
  Divider,
  Footer,
  Heraldry,
  Input,
  Kbd,
  Menubar,
  Node,
  Panel,
  PanelTitle,
  PixelFrame,
  Pill,
  Ribbon,
  Row,
  SegBar,
  Tier,
  Topbar,
} from '../../components/ui'
import styles from './index.module.css'

export const Route = createFileRoute('/kit/')({
  component: KitIndex,
})

const PALETTE = [
  { token: '--color-pit-ink', hex: '#0a0a0a' },
  { token: '--color-pit-ink-2', hex: '#111111' },
  { token: '--color-pit-ink-3', hex: '#181818' },
  { token: '--color-pit-line', hex: '#2a2a2a' },
  { token: '--color-pit-line-bright', hex: '#3a3a3a' },
  { token: '--color-pit-dim', hex: '#6b6b6b' },
  { token: '--color-pit-bone', hex: '#d8cfb8' },
  { token: '--color-pit-bone-bright', hex: '#f2ecd9' },
  { token: '--color-pit-green', hex: '#9ae66e' },
  { token: '--color-pit-amber', hex: '#d4a147' },
  { token: '--color-pit-red', hex: '#d45a5a' },
  { token: '--color-pit-violet', hex: '#9a7bd4' },
  { token: '--color-pit-cyan', hex: '#6ec3d4' },
  { token: '--color-pit-gild', hex: '#b58b3a' },
] as const

function KitIndex() {
  return (
    <main className={styles.page}>
      <div className={styles.wrap}>
        <header className={styles.header}>
          <div className={styles.eyebrow}>the pit · design system</div>
          <h1 className={styles.title}>━━◆ /kit ◆━━</h1>
          <p className={styles.subtitle}>
            source of visual truth for the Pit — every primitive, every variant, every state.
          </p>
        </header>
        <nav className={styles.nav} aria-label="Kit">
          <Link to="/" className={styles.navLink}>
            ← title
          </Link>
          <Link to="/kit/camp" className={styles.navLink}>
            /kit/camp
          </Link>
          <Link to="/kit/delve" className={styles.navLink}>
            /kit/delve
          </Link>
          <Link to="/kit/combat" className={styles.navLink}>
            /kit/combat
          </Link>
        </nav>

        {/* TYPOGRAPHY */}
        <section className={styles.section}>
          <PixelFrame title="Typography" right="font roles">
            <div className={styles.gridLg}>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>display · VT323 · 28</span>
                <span style={{ fontFamily: 'var(--font-display)', fontSize: 28, color: 'var(--color-pit-bone-bright)', letterSpacing: '0.08em' }}>
                  THE PIT WARDEN
                </span>
              </div>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>panel title · VT323 · 14</span>
                <span style={{ fontFamily: 'var(--font-display)', fontSize: 14, color: 'var(--color-pit-gild)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>
                  upgrade graph
                </span>
              </div>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>body · JetBrains Mono · 12</span>
                <span style={{ fontFamily: 'var(--font-sans)', fontSize: 12 }}>
                  A coil of blackened rope hangs from a hook you don't see.
                </span>
              </div>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>meta · JBM · 10</span>
                <span style={{ fontFamily: 'var(--font-sans)', fontSize: 10, color: 'var(--color-pit-dim)', letterSpacing: '0.14em', textTransform: 'uppercase' }}>
                  [0:04] crit +22 → A
                </span>
              </div>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>annotation · Caveat</span>
                <span className={styles.caption}>kit-only · sketchy notes</span>
              </div>
              <div className={styles.typeSample}>
                <span className={styles.typeSampleLabel}>stat value (tabular)</span>
                <span style={{ fontVariantNumeric: 'tabular-nums', fontSize: 18, color: 'var(--color-pit-bone-bright)' }}>
                  4,200 / 10,000
                </span>
              </div>
            </div>
          </PixelFrame>
        </section>

        {/* PALETTE */}
        <section className={styles.section}>
          <PixelFrame title="Palette" right={`${PALETTE.length} tokens`}>
            <div className={styles.swatchRow}>
              {PALETTE.map((c) => (
                <div key={c.token} className={styles.swatch}>
                  <div className={styles.swatchBlock} style={{ background: c.hex }} />
                  <div className={styles.swatchLabel}>{c.token.replace('--color-pit-', '')}</div>
                  <div className={styles.swatchLabel} style={{ color: 'var(--color-pit-gild)' }}>
                    {c.hex}
                  </div>
                </div>
              ))}
            </div>
          </PixelFrame>
        </section>

        {/* BUTTONS */}
        <section className={styles.section}>
          <PixelFrame title="Buttons" right="variants · sizes · juicy">
            <div className={styles.row}>
              <Button variant="primary">▸ primary</Button>
              <Button>default</Button>
              <Button variant="danger">retreat</Button>
              <Button variant="ghost">ghost</Button>
            </div>
            <div className={styles.row} style={{ marginTop: 8 }}>
              <Button size="sm">sm</Button>
              <Button size="md">md</Button>
              <Button size="lg">lg</Button>
              <Button disabled>disabled</Button>
              <Button variant="primary" disabled>
                disabled primary
              </Button>
            </div>
            <div className={styles.context}>
              <span className={styles.contextLabel}>── juicy feedback ──</span>
              <p style={{ fontSize: 11, color: 'var(--color-pit-dim)', margin: 0 }}>
                Click to burst pixel particles. Layer is a global Pixi canvas, pool of 64 sprites.
              </p>
              <div className={styles.row}>
                <Button variant="primary" juicy>
                  ▸ descend
                </Button>
                <Button variant="danger" juicy>
                  retreat
                </Button>
                <Button juicy>default juicy</Button>
              </div>
            </div>
            <div className={styles.context}>
              <span className={styles.contextLabel}>── in context ──</span>
              <PixelFrame title="Purchase" right="3 offers">
                <Card
                  tier={2}
                  name="Ember Hook"
                  slot="mainhand"
                  desc="on hit: burn 1"
                  footer={
                    <>
                      <span className={styles.price}>45 gold</span>
                      <Button size="sm" variant="primary">
                        buy
                      </Button>
                    </>
                  }
                />
              </PixelFrame>
            </div>
          </PixelFrame>
        </section>

        {/* PILLS + TIERS */}
        <section className={styles.section}>
          <PixelFrame title="Pills & tiers">
            <div className={styles.row}>
              <Pill>neutral</Pill>
              <Pill tone="g">green</Pill>
              <Pill tone="a">amber</Pill>
              <Pill tone="r">red</Pill>
              <Pill tone="v">violet</Pill>
              <Pill tone="c">cyan</Pill>
            </div>
            <div className={styles.row} style={{ marginTop: 10 }}>
              <Pill tone="c" dot>
                D015
              </Pill>
              <Pill tone="a" dot>
                torch 3/5
              </Pill>
              <Pill tone="g" dot>
                hp 78/90
              </Pill>
              <Pill tone="v">shards 2</Pill>
            </div>
            <div className={styles.row} style={{ marginTop: 14 }}>
              <Tier t={0} />
              <Tier t={1} />
              <Tier t={2} />
              <Tier t={3} />
            </div>
          </PixelFrame>
        </section>

        {/* BARS */}
        <section className={styles.section}>
          <PixelFrame title="Bars & meters">
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 14 }}>
              <Bar kind="hp" pct={87} label={{ l: 'HP', v: '78 / 90' }} />
              <Bar kind="mtr" pct={42} label={{ l: 'Meter', v: '4,200 / 10,000' }} />
              <Bar kind="torch" pct={60} label={{ l: 'Torch', v: '3 / 5' }} />
              <Bar kind="enemy" pct={74} label={{ l: 'worm A', v: '37 / 50' }} />
            </div>
            <div className={styles.context}>
              <span className={styles.contextLabel}>── segmented ──</span>
              <div className={styles.row}>
                <div style={{ minWidth: 140 }}>
                  <span className={styles.statLabel}>TORCH CAPACITY</span>
                  <SegBar total={5} on={2} />
                </div>
                <div style={{ minWidth: 140 }}>
                  <span className={styles.statLabel}>FOCUS</span>
                  <SegBar total={4} on={2} kind="cyan" />
                </div>
                <div style={{ minWidth: 140 }}>
                  <span className={styles.statLabel}>SHARDS</span>
                  <SegBar total={3} on={1} kind="violet" />
                </div>
              </div>
            </div>
          </PixelFrame>
        </section>

        {/* CARDS */}
        <section className={styles.section}>
          <PixelFrame title="Cards">
            <div className={styles.gridLg}>
              <Card tier={3} name="Rust Dagger" slot="mainhand" desc="+2 ATK · +0.1 spd" />
              <Card tier={2} name="Ember Hook" slot="mainhand" desc="on hit: burn 1" tags="fire · hook" />
              <Card
                tier={1}
                name="Whisper Coil"
                slot="focus"
                desc="crit: pull target"
                tags="focus · shadow"
                flavor="caught on something that pulled back."
              />
              <Card
                tier={0}
                name="Warden's Ember"
                slot="focus"
                desc="boss kill: regrow 1 torch"
                rare
              />
              <Card
                tier={2}
                name="Bone Brooch"
                slot="charm"
                desc="+3 max hp"
                selected
                footer={
                  <>
                    <span className={styles.price}>45 gold</span>
                    <Button size="sm" variant="primary">
                      buy
                    </Button>
                  </>
                }
              />
              <Card tier="service" name="Remove card" desc="strike one card from your deck permanently." />
            </div>
          </PixelFrame>
        </section>

        {/* INPUTS */}
        <section className={styles.section}>
          <PixelFrame title="Inputs & keyboard">
            <div className={styles.row}>
              <Input placeholder="type here..." />
              <Input icon="⌕" placeholder="search" cursor cursorSize="small" defaultValue="ember" />
            </div>
            <div className={styles.row} style={{ marginTop: 10 }}>
              <Kbd>↵</Kbd>
              <Kbd>esc</Kbd>
              <Kbd>1</Kbd>
              <Kbd>hjkl</Kbd>
              <Kbd>⌘K</Kbd>
            </div>
          </PixelFrame>
        </section>

        {/* ROWS */}
        <section className={styles.section}>
          <PixelFrame title="List rows" right="bench · 33">
            <Row>
              <Tier t={2} /> <span style={{ flex: 1 }}>Ember Hook</span>
              <span className={styles.statLabel}>mainhand</span>
              <Pill tone="g">EQ</Pill>
            </Row>
            <Row selected>
              <Tier t={1} /> <span style={{ flex: 1 }}>Whisper Coil</span>
              <span className={styles.statLabel}>focus</span>
            </Row>
            <Row>
              <Tier t={3} /> <span style={{ flex: 1 }}>Rust Dagger</span>
              <span className={styles.statLabel}>mainhand</span>
            </Row>
            <Row>
              <Tier t={0} /> <span style={{ flex: 1 }}>Warden's Ember</span>
              <span className={styles.statLabel}>focus</span>
              <Pill tone="v">T0</Pill>
            </Row>
          </PixelFrame>
        </section>

        {/* FRAMES & ORNAMENTS */}
        <section className={styles.section}>
          <PixelFrame title="Frames & ornaments">
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 14 }}>
              <PixelFrame title="Default" right="tone: default">
                <p style={{ fontSize: 11, margin: 0 }}>standard runic frame with gild corners.</p>
              </PixelFrame>
              <PixelFrame tone="raised" title="Raised" right="tone: raised">
                <p style={{ fontSize: 11, margin: 0 }}>elevated for panels over panels.</p>
              </PixelFrame>
              <PixelFrame tone="gild" title="Gild" right="tone: gild">
                <p style={{ fontSize: 11, margin: 0 }}>gilded border for heroic moments.</p>
              </PixelFrame>
            </div>
            <div className={styles.context}>
              <span className={styles.contextLabel}>── ornaments ──</span>
              <Heraldry />
              <Ribbon>rite of passage</Ribbon>
              <PanelTitle right="34 total">pinned upgrades</PanelTitle>
              <Divider variant="dashed" />
              <Divider variant="single" />
              <Divider variant="double" />
            </div>
            <div className={styles.context}>
              <span className={styles.contextLabel}>── panel (lighter) ──</span>
              <Panel>
                <span className={styles.statLabel}>OWNED</span>
                <SegBar total={3} on={1} />
                <span className={styles.statLabel} style={{ marginTop: 8, display: 'block' }}>
                  COST · 2 pts next rank
                </span>
              </Panel>
            </div>
          </PixelFrame>
        </section>

        {/* MAP NODES */}
        <section className={styles.section}>
          <PixelFrame title="Map nodes">
            <div className={styles.row} style={{ gap: 14 }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
                <Node>⚔</Node>
                <span className={styles.statLabel}>combat</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
                <Node variant="now">◉</Node>
                <span className={styles.statLabel}>current</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
                <Node variant="elite">◆</Node>
                <span className={styles.statLabel}>elite</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
                <Node variant="locked">◇</Node>
                <span className={styles.statLabel}>locked</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
                <Node variant="boss">◈ THE PIT WARDEN</Node>
                <span className={styles.statLabel}>boss</span>
              </div>
            </div>
          </PixelFrame>
        </section>

        {/* NAV */}
        <section className={styles.section}>
          <PixelFrame title="Navigation chrome">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <Topbar title="camp · descender @aria" gold="124" scrap={38} shards={2} torch="5/5" />
              <Menubar
                active="D"
                items={[
                  { key: 'D', label: 'Delve' },
                  { key: 'P', label: 'Passives' },
                  { key: 'C', label: 'Cards' },
                  { key: 'S', label: 'Shop' },
                  { key: 'X', label: 'Codex' },
                  { key: 'L', label: 'Leaderboard' },
                ]}
              />
              <Footer
                items={[
                  { k: 'hjkl', l: 'navigate' },
                  { k: '↵', l: 'commit' },
                  { k: '/', l: 'search' },
                  { k: 'esc', l: 'back' },
                ]}
              />
            </div>
          </PixelFrame>
        </section>
      </div>
    </main>
  )
}
