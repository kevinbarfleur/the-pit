"""play.py — REJOUE un seed + une suite d'actions et imprime un etat COMPACT. Permet a un agent (humain
ou LLM) de jouer une partie REACTIVEMENT a travers des appels successifs : la partie etant deterministe
(seed + actions), on rejoue la liste accumulee a chaque tour pour voir l'etat, puis on etend la liste.

Actions : buy:I[:SLOT]  reroll  level  reshape:SIGIL  sell:SLOT  move:FROM:TO  pickrelic:N  fight
Usage   : ./.venv/bin/python mcp/play.py SEED [action ...]
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from game_session import GameSession  # noqa: E402


def main() -> int:
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 42
    actions = sys.argv[2:]
    log = []
    with GameSession() as g:
        g.new_game(seed)
        for a in actions:
            p = a.split(":")
            cmd = p[0]
            if cmd == "buy":
                r = g.buy(int(p[1]), int(p[2]) if len(p) > 2 else None)
                if not r.get("ok"):
                    log.append(f"  (! buy {':'.join(p[1:])} refuse)")
            elif cmd == "reroll":
                g.reroll()
            elif cmd == "accept":  # accepte le grant de slot ; accept:CELL pour choisir la case
                cell = int(p[1]) if len(p) > 1 else None
                if not g.accept_grant(cell).get("ok"):
                    log.append("  (! accept refuse : pas d'offre de slot en attente)")
            elif cmd == "decline":  # refuse le grant de slot -> +or (jeu 'tall')
                if not g.decline_grant().get("ok"):
                    log.append("  (! decline refuse : pas d'offre)")
            elif cmd == "reshape":
                g.reshape(p[1])
            elif cmd == "sell":
                g.sell(int(p[1]))
            elif cmd == "move":
                g.move(int(p[1]), int(p[2]))
            elif cmd == "pickrelic":
                g.pick_relic(int(p[1]))
            elif cmd == "fight":
                r = g.fight()
                res = r.get("result", {})
                rd = r.get("state", {}).get("round", "?")
                log.append(f"FIGHT (round end): {'WIN ' if res.get('win') else 'LOSS'} vs {res.get('enemyKey')}"
                           f"  ({res.get('ticks')}t, hp left {res.get('hpFrac', {}).get('left', 0):.1f}"
                           f" vs {res.get('hpFrac', {}).get('right', 0):.1f})")
                if r.get("relicChoices"):
                    g.pick_relic(1)  # reliques cryptiques (effet inconnu) -> auto-pick #1 par defaut
                    log.append(f"  >> RELIC: auto-pick {r['relicChoices'][0]} (parmi {r['relicChoices']})")
                if r.get("over"):
                    log.append(f"  >> RUN OVER: {r['over'].upper()}")
                    break  # run terminee -> on ignore les actions restantes (blind-batch propre)
            else:
                log.append(f"  (! action inconnue: {a})")

        st = g.state()
        shop = "  ".join(f"[{i + 1}] {o['id']}({o['cost']}g){'-SOLD' if o['sold'] else ''}"
                         for i, o in enumerate(st["shop"]))
        board = "  ".join(f"{b['slot']}={b['id']}{'*' + str(b['level']) if b.get('level', 1) > 1 else ''}"
                          for b in st["board"] if b.get("id"))
        empty = [b["slot"] for b in st["board"] if b["unlocked"] and not b.get("id")]
        locked = [b["slot"] for b in st["board"] if not b["unlocked"]]

    print("\n".join(log))
    print(f"--- ROUND {st['round']} | gold {st['gold']} | lives {st['lives']} | wins {st['wins']}/10"
          f" | slots {st['slots']}/9 | sigil {st['sigil']}"
          + ("  >> SLOT GRANT pending (accept[:cell] / decline)" if st.get('pendingSlotGrant') else "")
          + (f" | streak W{st['winStreak']}/L{st['lossStreak']}" if (st['winStreak'] or st['lossStreak']) else ""))
    print(f"SHOP:  {shop}")
    print(f"BOARD: {board if board else '(empty)'}")
    print(f"empty unlocked slots: {empty}   locked: {locked}")
    if st.get("pendingRelics"):
        print(f"PENDING RELIC CHOICE: {st['pendingRelics']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
