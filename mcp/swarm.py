"""swarm.py — lance des SWARMS d'agents LLM (personas) qui jouent de vraies parties et rendent un rapport.

Chaque agent = une GameSession (un daemon luajit isole) + une boucle tool-use (SDK Anthropic). Les memes
outils que le serveur MCP, dispatchies vers GameSession. Mode --smoke : agent SCRIPTE (sans API, sans cout)
pour valider le harnais de bout en bout. Mode live : un agent Claude joue selon son persona.

Usage :
  ./.venv/bin/python mcp/swarm.py --smoke --n 5         # valide le harnais (aucune API)
  ANTHROPIC_API_KEY=... ./.venv/bin/python mcp/swarm.py --n 8 --model claude-haiku-4-5-20251001
Rapports -> runs/agentreports/*.json
"""
from __future__ import annotations

import argparse
import json
import sys
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from game_session import GameSession  # noqa: E402
from personas import PERSONAS, REPORT_TOOL, system_for  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MODEL = "claude-haiku-4-5-20251001"

# ── Schemas d'outils (format Anthropic) : tout le cliquable joueur + submit_report ──
def _obj(props=None, required=None):
    return {"type": "object", "properties": props or {}, **({"required": required} if required else {})}


TOOLS = [
    {"name": "get_state", "description": "Full current state (round, gold, lives, wins, slots, pendingSlotGrant, sigil, shop, board).", "input_schema": _obj()},
    {"name": "describe_unit", "description": "Mechanical sheet for a unit id (type, archetype, stats, effects).", "input_schema": _obj({"unit_id": {"type": "string"}}, ["unit_id"])},
    {"name": "list_pool", "description": "Full roster of buyable units with their sheets.", "input_schema": _obj()},
    {"name": "buy", "description": "Buy shop offer shop_index (1-5) onto board slot (1-9, unlocked & empty).", "input_schema": _obj({"shop_index": {"type": "integer"}, "slot": {"type": "integer"}}, ["shop_index", "slot"])},
    {"name": "sell", "description": "Sell the unit on a board slot for a refund.", "input_schema": _obj({"slot": {"type": "integer"}}, ["slot"])},
    {"name": "reroll", "description": "Re-roll the shop (costs gold).", "input_schema": _obj()},
    {"name": "accept_slot_grant", "description": "Accept the pending board-slot grant (free): +1 slot on `cell` (1-9) or best central cell if 0. Going wide.", "input_schema": _obj({"cell": {"type": "integer"}})},
    {"name": "decline_slot_grant", "description": "Decline the pending slot grant for gold instead (forgo the slot = going 'tall', fewer stronger units).", "input_schema": _obj()},
    {"name": "move", "description": "Move/swap a unit between two slots (changes adjacency).", "input_schema": _obj({"src_slot": {"type": "integer"}, "dst_slot": {"type": "integer"}}, ["src_slot", "dst_slot"])},
    {"name": "reshape", "description": "Change board shape (carre/croix/anneau/diamant/ligne).", "input_schema": _obj({"sigil": {"type": "string"}}, ["sigil"])},
    {"name": "start_combat", "description": "Fight this round's opponent; auto-resolves. Returns result + new state.", "input_schema": _obj()},
    {"name": "pick_relic", "description": "Pick relic choice (1-based) from a pending 1-of-3 offer.", "input_schema": _obj({"choice": {"type": "integer"}}, ["choice"])},
    REPORT_TOOL,
]


def dispatch(g: GameSession, name: str, inp: dict):
    if name == "get_state":
        return g.state()
    if name == "describe_unit":
        return g.describe_unit(inp["unit_id"])
    if name == "list_pool":
        return g.pool()
    if name == "buy":
        return g.buy(inp["shop_index"], inp.get("slot"))
    if name == "sell":
        return g.sell(inp["slot"])
    if name == "reroll":
        return g.reroll()
    if name == "accept_slot_grant":
        return g.accept_grant(inp.get("cell") or None)
    if name == "decline_slot_grant":
        return g.decline_grant()
    if name == "move":
        return g.move(inp["src_slot"], inp["dst_slot"])
    if name == "reshape":
        return g.reshape(inp["sigil"])
    if name == "start_combat":
        return g.fight()
    if name == "pick_relic":
        return g.pick_relic(inp["choice"])
    raise ValueError(f"unknown tool {name}")


def _outcome(state: dict) -> dict:
    return {"wins": state.get("wins", 0), "losses": state.get("losses", 0),
            "rounds": state.get("round", 0), "result": state.get("over")}


# ── Agent LLM (live) : boucle tool-use jusqu'au rapport ou fin de partie ──
def run_agent_live(persona: str, seed: int, client, model: str, max_turns: int = 80) -> dict:
    g = GameSession()
    try:
        init = g.new_game(seed)
        system = system_for(persona)
        messages = [{"role": "user", "content":
                     f"New run started (seed {seed}). Initial state:\n{json.dumps(init)}\n"
                     "Play to 10 wins in your persona's style. Use tools every turn. "
                     "When the run is over (state.over is win/lose), call submit_report."}]
        report, last_state = None, init
        for _ in range(max_turns):
            resp = client.messages.create(model=model, max_tokens=1500, system=system, tools=TOOLS, messages=messages)
            messages.append({"role": "assistant", "content": resp.content})
            results, stop = [], False
            for block in resp.content:
                if getattr(block, "type", None) != "tool_use":
                    continue
                if block.name == "submit_report":
                    report, stop = block.input, True
                    results.append({"type": "tool_result", "tool_use_id": block.id, "content": "Report received. Thank you."})
                else:
                    try:
                        out = dispatch(g, block.name, block.input)
                        if isinstance(out, dict) and out.get("state"):
                            last_state = out["state"]
                        elif block.name == "get_state":
                            last_state = out
                    except Exception as e:  # jamais crasher la partie sur une action invalide
                        out = {"error": str(e)}
                    results.append({"type": "tool_result", "tool_use_id": block.id, "content": json.dumps(out)})
            if results:
                messages.append({"role": "user", "content": results})
            if stop:
                break
            if resp.stop_reason != "tool_use":
                messages.append({"role": "user", "content": "Keep playing with tools, or submit_report if the run is over."})
        return {"persona": persona, "seed": seed, "model": model, "report": report, "outcome": _outcome(last_state)}
    finally:
        g.close()


# ── Agent SCRIPTE (smoke) : greedy fill, sans API -> valide le harnais (session + dispatch + rapport) ──
def run_agent_smoke(persona: str, seed: int, max_rounds: int = 40) -> dict:
    g = GameSession()
    try:
        state = g.new_game(seed)
        rounds = 0
        while rounds < max_rounds:
            state = dispatch(g, "get_state", {})
            if state.get("pendingSlotGrant"):  # greedy = va wide : accepte chaque slot offert (case centrale)
                state = dispatch(g, "accept_slot_grant", {"cell": 0}).get("state", state)
            for i, o in enumerate(state["shop"], start=1):
                if not o.get("sold") and state["gold"] >= o["cost"]:
                    r = dispatch(g, "buy", {"shop_index": i, "slot": None})
                    state = r.get("state", state)
            fr = dispatch(g, "start_combat", {})
            rounds += 1
            if fr.get("relicChoices"):
                dispatch(g, "pick_relic", {"choice": 1})
            state = fr.get("state", state)
            if fr.get("over"):
                break
        won = state.get("wins", 0) >= 10
        report = {"won": won, "fun_rating": 3, "final_archetype": "mixed",
                  "narrative": f"[smoke] greedy run ended {state.get('wins')}-{state.get('losses')} in {rounds} rounds.",
                  "key_decisions": [], "frustrations": [], "wishlist": []}
        return {"persona": persona, "seed": seed, "model": "smoke", "report": report, "outcome": _outcome(state)}
    finally:
        g.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="Swarm de personas qui play-testent The Pit.")
    ap.add_argument("--n", type=int, default=3, help="nombre d'agents")
    ap.add_argument("--seed", type=int, default=1000, help="seed de base (chaque agent: seed+i)")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--smoke", action="store_true", help="agents scriptes (sans API)")
    args = ap.parse_args()

    names = list(PERSONAS.keys())
    jobs = [(names[i % len(names)], args.seed + i) for i in range(args.n)]

    client = None
    if not args.smoke:
        import anthropic  # uniquement en mode live
        client = anthropic.Anthropic()  # ANTHROPIC_API_KEY depuis l'env

    results = []
    for persona, seed in jobs:
        try:
            r = run_agent_smoke(persona, seed) if args.smoke else run_agent_live(persona, seed, client, args.model)
        except Exception as e:
            traceback.print_exc()
            r = {"persona": persona, "seed": seed, "error": str(e)}
        results.append(r)
        rep = r.get("report") or {}
        print(f"  {persona:<14} seed={seed} -> {r.get('outcome', {}).get('result', r.get('error'))}"
              f"  fun={rep.get('fun_rating', '-')}")

    outdir = REPO_ROOT / "runs" / "agentreports"
    outdir.mkdir(parents=True, exist_ok=True)
    for r in results:
        (outdir / f"{r['persona']}_{r['seed']}.json").write_text(json.dumps(r, indent=2))

    reports = [r["report"] for r in results if r.get("report")]
    won = sum(1 for rep in reports if rep.get("won"))
    funs = [rep["fun_rating"] for rep in reports if "fun_rating" in rep]
    print(f"\nswarm: {len(results)} agents, {won} ascensions"
          + (f", fun moyen {sum(funs) / len(funs):.1f}/5" if funs else "")
          + f" -> runs/agentreports/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
