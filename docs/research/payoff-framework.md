# Payoff framework

Status: active short note. The old detailed plan was removed.

Payoffs are allowed to be strong, but they must be bounded.

Examples:

- spread and propagation need caps and source attribution;
- shield engines need value/cooldown/reflect limits;
- multicast must respect `MULTICAST_MAX`;
- percent-HP or execute mechanics must not become one-shot shortcuts;
- level-3 clutch mechanics should create a plan, not invalidate higher-rank
  units by raw stat inflation.

Current code/tests:

- `src/effects/ops.lua`
- `src/combat/arena.lua`
- `tests/payoff.lua`
- `tests/synergies.lua`
- `src/lab/coherence.lua`

Validation:

```sh
luajit tests/payoff.lua
luajit tests/synergies.lua
luajit tests/coherence.lua
```
