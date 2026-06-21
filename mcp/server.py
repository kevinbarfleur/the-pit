"""server.py — serveur MCP (FastMCP) exposant The Pit comme des OUTILS jouables par un agent LLM.

Tout ce qu'un joueur peut faire (acheter, placer, reroll, vendre, monter de niveau, deplacer, reshaper,
combattre) devient un outil MCP. Un agent (Claude Code / Desktop / SDK) s'y connecte et JOUE une vraie
partie. Transport stdio par defaut (un agent par processus = isolation ; pour des swarms, on lance N
processus). Mince : chaque outil delegue a GameSession (-> daemon luajit -> moteur Lua, source unique).

Lancement (stdio) :  ./.venv/bin/python mcp/server.py
Wiring Claude Code  :  cf. mcp/README.md
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from mcp.server.fastmcp import FastMCP  # noqa: E402
from game_session import GameSession  # noqa: E402

mcp = FastMCP("the-pit")
_session: dict[str, GameSession | None] = {"game": None}


def _g() -> GameSession:
    g = _session["game"]
    if g is None:
        raise RuntimeError("No game in progress. Call new_game(seed) first.")
    return g


@mcp.tool()
def new_game(seed: int, sigil: str = "") -> dict:
    """Start a fresh roguelite run, deterministic from `seed`. Optional `sigil` sets the starting board
    shape (carre/croix/anneau/diamant/ligne). You descend The Pit: build a team of monsters on a 9-slot
    graph-board, fight escalating opponents. Reach 10 wins to ascend; lose 5 lives and you fall.
    Returns the initial state (gold, lives, the 5-card shop, the board)."""
    if _session["game"]:
        _session["game"].close()
    g = GameSession()
    _session["game"] = g
    return g.new_game(seed, sigil or None)


@mcp.tool()
def get_state() -> dict:
    """Full current state: round, gold, lives, wins, slots (capacity), pendingSlotGrant (a slot offer awaits
    accept/decline), active sigil, the 5-card shop (id/cost/sold), and the 9 board slots (unlocked + occupant id/level)."""
    return _g().state()


@mcp.tool()
def describe_unit(unit_id: str) -> dict:
    """Mechanical sheet for a unit id: type, archetype (poison/burn/bleed/rot/shock/tank/bruiser), cost,
    hp, dmg, cooldown, aggro, taunt, and its effect ops. Use it to judge shop offers and synergies."""
    return _g().describe_unit(unit_id)


@mcp.tool()
def list_pool() -> dict:
    """The full roster of buyable units with their mechanical sheets (everything the shop can offer)."""
    return _g().pool()


@mcp.tool()
def buy(shop_index: int, slot: int) -> dict:
    """Buy shop offer `shop_index` (1-5) and place it on board `slot` (1-9, must be unlocked AND empty).
    Cost is deducted only on a valid placement. Three copies of the same unit+level auto-merge into one of
    the next level (stronger). Tip: place aura units next to matching damage-dealers. Returns {ok, bought, state}."""
    return _g().buy(shop_index, slot)


@mcp.tool()
def sell(slot: int) -> dict:
    """Sell the unit on board `slot` for a partial gold refund and free the slot. Returns {ok, state}."""
    return _g().sell(slot)


@mcp.tool()
def reroll() -> dict:
    """Pay (cheap) to re-roll the shop into 5 new random offers. Returns {ok, state}."""
    return _g().reroll()


@mcp.tool()
def accept_slot_grant(cell: int = 0) -> dict:
    """Accept the pending board-slot grant (free, offered on a schedule rounds 2-7): +1 slot, opened on
    `cell` (1-9) or, if 0/omitted, the best central empty cell. Going wide = more units. Slots are NOT
    bought with gold anymore. Only valid when state.pendingSlotGrant is true. Returns {ok, state}."""
    return _g().accept_grant(cell or None)


@mcp.tool()
def decline_slot_grant() -> dict:
    """Decline the pending board-slot grant for gold instead (you forgo that slot permanently = going
    'tall': fewer but stronger/denser units). Only valid when state.pendingSlotGrant is true. Returns {ok, state}."""
    return _g().decline_grant()


@mcp.tool()
def move(src_slot: int, dst_slot: int) -> dict:
    """Move (or swap) a unit from `src_slot` to `dst_slot`. Re-arranging changes adjacency, which drives
    aura synergies and front/back targeting exposure. Returns {ok, state}."""
    return _g().move(src_slot, dst_slot)


@mcp.tool()
def reshape(sigil: str) -> dict:
    """Change the board topology to `sigil` (carre=square/croix=cross/anneau=ring/diamant=diamond/
    ligne=line). Units keep their slots; the adjacency graph (synergies + exposure) changes. Each shape
    favours a different archetype. Returns {ok, state}."""
    return _g().reshape(sigil)


@mcp.tool()
def start_combat() -> dict:
    """Fight this round's opponent with your current board. It auto-resolves (you are a spectator).
    Returns {result:{win, decided, ticks, hpFrac}, state}. On a 3-win milestone, `relicChoices` carries a
    1-of-3 relic offer -> call pick_relic next. If `over` is "win"/"lose", the run has ended."""
    return _g().fight()


@mcp.tool()
def pick_relic(choice: int) -> dict:
    """Choose relic `choice` (1-based) from a pending 1-of-3 offer (after a milestone win). Relics are
    cryptic: their true effect reveals through play. Returns {picked, state}."""
    return _g().pick_relic(choice)


if __name__ == "__main__":
    mcp.run()  # stdio
