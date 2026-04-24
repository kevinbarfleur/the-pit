import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
  component: IndexPage,
})

function IndexPage() {
  return (
    <main className="min-h-dvh p-6 md:p-10">
      <pre className="text-[11px] md:text-xs leading-tight text-pit-green opacity-80 mb-8 select-none">
{`┌─────────────────────────────────────────────────────────────┐
│                                                             │
│    T H E   P I T                                            │
│    ─────────────                                            │
│    an idle delve into darkness.                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘`}
      </pre>
      <div className="space-y-1 text-sm text-pit-bone">
        <p><span className="text-pit-dim">$</span> ./the-pit init</p>
        <p className="text-pit-dim">&gt; booting runtime...</p>
        <p className="text-pit-dim">&gt; connecting to convex... <span className="text-pit-green">ok</span></p>
        <p className="text-pit-dim">&gt; awaiting twitch auth...</p>
        <p className="text-pit-dim">&gt; status: <span className="text-pit-amber">scaffolding in progress</span></p>
      </div>
    </main>
  )
}
