# A3 — Reliques d'économie (le levier « intérêts / bonus d'or » du créateur)

> Décision créateur : **zéro intérêt de base ; les reliques peuvent apporter intérêts OU bonus d'or.**
> L'éco de base = **SAP sans report** (or FRAIS chaque round, pas de banque). Donc « intérêt »
> n'existe QUE si une relique **introduit le report + l'intérêt** (sinon intérêt sur de l'or perdu = inutile).
> Tout reste **SIM-pur** (state.lua) ; golden inchangé (run-level, hors combat golden).

## Mécanisme (state.lua)
- Nouveau champ run : `self._pendingGold` (or différé au prochain round, ex. or-sur-victoire) ; init 0.
- Nouveau champ relique : `eco = { carryover?, interest?, interestCap?, perRound?, onWin?, sellFrac? }`.
- `RunState:ecoMods()` : scanne `self.relics` possédées -> agrège les champs `eco` (somme perRound/onWin ;
  max sellFrac ; OR carryover ; somme interest/cap). Retour table neutre si aucune relique éco.
- **`startRound()`** (après le calcul `GOLD_PER_ROUND + streakBonus`) :
  ```lua
  local eco = self:ecoMods()
  local held = self.gold                                  -- or de fin de round (AVANT reset)
  local kept = eco.carryover and held or 0
  local interest = eco.carryover and math.min(eco.interestCap or 0, math.floor(held * (eco.interest or 0))) or 0
  self.gold = GOLD_PER_ROUND + streakBonus(self) + kept + interest + (eco.perRound or 0) + (self._pendingGold or 0)
  self._pendingGold = 0
  ```
- **`resolve(win)`** : `if win and eco.onWin>0 then self._pendingGold = (self._pendingGold or 0) + eco.onWin end`.
- **`sellRefund(id)`** : `frac = max(SELL_REFUND_FRAC, ecoMods().sellFrac or 0)`.

## Reliques (relics.lua + en.lua + icône RelicGen + tests/relics count)
- **The Usurer's Ledger** (interest, marquee) — `eco={carryover=true, interest=0.2, interestCap=5}` —
  « Your gold now carries between rounds; gain +1 gold for every 5 you hold (up to +5). »
- **Tithe-Bowl** (or sur victoire) — `eco={onWin=2}` — « Win a combat: +2 gold next round. »
- **Pauper's Boon** (income plat) — `eco={perRound=3}` — « Gain +3 gold at the start of each round. »
- **Grave-Robber's Cut** (vente pleine) — `eco={sellFrac=1.0}` — « Selling a unit refunds its full cost. »

## Garde-fous / vérif
- Respecte #JJ : payoff ancré sur le CHOIX de relique (joueur), jamais l'adversaire. ✓
- Placeholders chiffrés -> **sim/playtest tuning** (intérêt 0.2/cap 5 = TFT-ish ; perRound 3 ; onWin 2).
- Tests : étendre `tests/run.lua` (interest/carryover/onWin/sellFrac) ; mettre à jour le COUNT dans
  `tests/relics.lua` + `tests/i18n.lua` (Relics.order grandit) ; icônes RelicGen (4 nouvelles).
- `sh tools/check.sh` vert + golden 970156547 inchangé (run-level, hors SIM golden).
