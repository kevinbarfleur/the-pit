# The Pit — Agent Arena (MCP)

Le **Pilier C** du banc d'essai : exposer The Pit comme des **outils MCP** pour que des **agents LLM**
jouent de vraies parties (et rendent un retour qualitatif), et lancer des **swarms** de personas.

```
  agent LLM  ──MCP──▶  mcp/server.py (FastMCP)  ──▶  game_session.py  ──stdin/JSON──▶  tools/gamed/gamed.lua
   (Claude)                                            (subprocess)                      (rundriver -> moteur Lua)
```

Le moteur reste **100 % Lua** (source unique) : Python n'est qu'un pont. 1 partie = 1 daemon luajit
(isolation process -> parallélisme trivial pour les swarms).

## Installation

```sh
uv venv mcp/.venv --python 3.12
uv pip install --python mcp/.venv -r mcp/requirements.txt
```
Prérequis : `luajit` dans le PATH (déjà utilisé par les tests/sims du projet).

## Faire jouer un agent (interactif, stdio)

Brancher le serveur dans **Claude Code** :
```sh
claude mcp add the-pit -- /ABSOLUTE/PATH/the-pit/mcp/.venv/bin/python /ABSOLUTE/PATH/the-pit/mcp/server.py
```
Puis, dans une session : « Joue une partie de The Pit : `new_game(42)`, vise 10 victoires, puis raconte. »
L'agent dispose de 12 outils (tout le cliquable joueur) : `new_game, get_state, describe_unit, list_pool,
buy, sell, reroll, level_up, move, reshape, start_combat, pick_relic`.

## Lancer un swarm de personas

```sh
# valide le harnais SANS API (agents scriptes) :
./mcp/.venv/bin/python mcp/swarm.py --smoke --n 5

# vrais agents LLM (personas) -> rapports qualitatifs :
ANTHROPIC_API_KEY=sk-... ./mcp/.venv/bin/python mcp/swarm.py --n 8 --model claude-haiku-4-5-20251001
```
Rapports structurés -> `runs/agentreports/*.json` (`won`, `fun_rating`, `narrative`, `key_decisions`,
`frustrations`, `wishlist`). Personas (= taxonomie des politiques scriptées, version qualitative) :
`the_economist`, `the_zealot` (poison), `the_turtle` (tank), `the_adaptive`, `the_gambler`.

## Protocole du daemon (debug)

`luajit tools/gamed/gamed.lua`, puis des lignes sur stdin (réponse = 1 ligne JSON) :
```
ping
new 42 diamant
describe spore_tick
buy 1 1
state
fight
quit
```

## Tests

```sh
./mcp/.venv/bin/python -m pytest mcp/tests -q   # spawn le vrai daemon + joue des parties scriptees
```

## Fichiers

| Fichier | Rôle |
|---|---|
| `tools/gamed/gamed.lua` | daemon : REPL ligne->JSON -> `src/lab/rundriver` (RENDER-tainted, headless) |
| `tools/gamed/json.lua` | encodeur JSON minimal (sortie du daemon) |
| `mcp/game_session.py` | pont : spawn le daemon + transport (pur Python, sans FastMCP) |
| `mcp/server.py` | serveur FastMCP : 12 outils, délègue à GameSession |
| `mcp/personas.py` | préambule de règles + 5 personas + schéma de rapport |
| `mcp/swarm.py` | runner : N agents (live SDK Anthropic / `--smoke` scripté) -> rapports |
| `mcp/tests/` | pytest du pont |
