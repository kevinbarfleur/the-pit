"""test_bridge.py — tests du pont Python <-> daemon luajit (le coeur du Pilier C).

Spawn le vrai daemon (luajit tools/gamed/gamed.lua) et joue des parties scriptees via les outils :
prouve que tout le cliquable joueur est pilotable, que les refus sont propres, et qu'une run conclut.
Lancement :  ./.venv/bin/python -m pytest mcp/tests -q
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from game_session import GameSession  # noqa: E402


def test_ping_and_new_game():
    with GameSession() as g:
        s = g.new_game(123)
        assert s["round"] == 1 and s["gold"] > 0 and s["slots"] == 3
        assert len(s["board"]) == 9 and len(s["shop"]) == 5


def test_describe_and_pool():
    with GameSession() as g:
        g.new_game(1)
        d = g.describe_unit("spore_tick")
        assert d["archetype"] == "poison" and "poison" in d["effects"]
        p = g.pool()
        assert len(p["units"]) > 30


def test_buy_place_fight():
    with GameSession() as g:
        st = g.new_game(7)
        bought = 0
        for i, o in enumerate(st["shop"], start=1):
            if not o["sold"] and st["gold"] >= o["cost"]:
                r = g.buy(i)  # case vide auto
                if r["ok"]:
                    bought += 1
                    st = r["state"]
        assert bought >= 1
        fr = g.fight()
        assert "result" in fr and isinstance(fr["result"]["win"], bool)
        assert "state" in fr


def test_full_scripted_run_terminates():
    with GameSession() as g:
        st = g.new_game(777)
        over = None
        for _ in range(40):
            st = g.state()
            for i, o in enumerate(st["shop"], start=1):
                if not o["sold"] and st["gold"] >= o["cost"]:
                    st = g.buy(i).get("state", st)
            if st["level"] < 7 and st["gold"] >= 5:
                st = g.level_up().get("state", st)
            fr = g.fight()
            if fr.get("relicChoices"):
                g.pick_relic(1)
            st = fr.get("state", st)
            if fr.get("over"):
                over = fr["over"]
                break
        assert over in ("win", "lose")


def test_invalid_actions_are_clean():
    with GameSession() as g:
        g.new_game(1)
        assert g.buy(1, 99)["ok"] is False  # slot verrouille
        assert g.reshape("nope")["ok"] is False  # sigil inconnu
        assert g.describe_unit("nope").get("error")  # unite inconnue


def test_reshape_and_move():
    with GameSession() as g:
        g.new_game(5)
        assert g.reshape("ligne")["ok"] is True
        assert g.state()["sigil"] == "ligne"
        # achete 2 unites puis deplace
        st = g.state()
        slots = []
        for i, o in enumerate(st["shop"], start=1):
            if not o["sold"] and st["gold"] >= o["cost"]:
                r = g.buy(i)
                if r["ok"]:
                    st = r["state"]
        occupied = [b["slot"] for b in st["board"] if b.get("id")]
        if len(occupied) >= 1:
            src = occupied[0]
            empty = next((b["slot"] for b in st["board"] if b["unlocked"] and not b.get("id")), None)
            if empty:
                assert g.move(src, empty)["ok"] is True
