"""game_session.py — pont Python <-> daemon luajit (tools/gamed/gamed.lua).

Une GameSession = UN processus daemon = UNE partie (isolation process -> parallelisme trivial pour les
swarms). On ecrit des lignes de commande sur stdin, on lit une ligne JSON par reponse. Pur Python
(subprocess + json) : testable SANS FastMCP. Le moteur de jeu reste 100% Lua (source unique de verite).
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent


class GameError(RuntimeError):
    pass


class GameSession:
    """Pilote une partie via le daemon luajit. Chaque action renvoie un dict (l'etat est inclus)."""

    def __init__(self, luajit: str = "luajit", timeout: float = 30.0) -> None:
        self.timeout = timeout
        self.proc = subprocess.Popen(
            [luajit, "tools/gamed/gamed.lua"],
            cwd=str(REPO_ROOT),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        # verifie que le daemon repond (charge mock_love + le rundriver)
        if self._cmd("ping").get("ok") is not True:
            raise GameError("le daemon n'a pas repondu a ping")

    # ── transport ──
    def _cmd(self, line: str) -> dict[str, Any]:
        if self.proc.poll() is not None:
            raise GameError(f"daemon termine (code {self.proc.returncode})")
        assert self.proc.stdin and self.proc.stdout
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        out = self.proc.stdout.readline()
        if not out:
            err = self.proc.stderr.read() if self.proc.stderr else ""
            raise GameError(f"aucune reponse du daemon (cmd={line!r}); stderr={err[:500]}")
        try:
            return json.loads(out)
        except json.JSONDecodeError as e:
            raise GameError(f"JSON invalide du daemon: {e}; ligne={out[:200]!r}") from e

    # ── lecture ──
    def new_game(self, seed: int, sigil: Optional[str] = None, relics_known: bool = False) -> dict:
        parts = ["new", str(int(seed))]
        if sigil:
            parts.append(sigil)
            parts.append("1" if relics_known else "0")
        return self._cmd(" ".join(parts))

    def state(self) -> dict:
        return self._cmd("state")

    def describe_unit(self, unit_id: str) -> dict:
        return self._cmd(f"describe {unit_id}")

    def pool(self) -> dict:
        return self._cmd("pool")

    # ── actions (chacune renvoie {ok|..., state}) ──
    def buy(self, shop_index: int, slot: Optional[int] = None) -> dict:
        return self._cmd(f"buy {int(shop_index)}" + (f" {int(slot)}" if slot is not None else ""))

    def sell(self, slot: int) -> dict:
        return self._cmd(f"sell {int(slot)}")

    def reroll(self) -> dict:
        return self._cmd("reroll")

    def level_up(self) -> dict:
        return self._cmd("level")

    def move(self, src: int, dst: int) -> dict:
        return self._cmd(f"move {int(src)} {int(dst)}")

    def reshape(self, sigil: str) -> dict:
        return self._cmd(f"reshape {sigil}")

    def fight(self) -> dict:
        return self._cmd("fight")

    def pick_relic(self, choice: int) -> dict:
        return self._cmd(f"pickrelic {int(choice)}")

    # ── cycle de vie ──
    def close(self) -> None:
        if self.proc.poll() is None:
            try:
                assert self.proc.stdin
                self.proc.stdin.write("quit\n")
                self.proc.stdin.flush()
            except Exception:
                pass
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()

    def __enter__(self) -> "GameSession":
        return self

    def __exit__(self, *exc: Any) -> None:
        self.close()
