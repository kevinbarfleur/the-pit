# Spec draft — Écrans BUILD (haut + centre) & COMBAT

> **Date** : 2026-06-24
> **But** : donner au **designer** un inventaire **trié et croisé** de tout ce qui est *affichable* —
> ce que le **code expose déjà**, ce que la **concurrence** affiche, et la **pertinence** de chaque
> élément. Le designer **triera** et fera une proposition de maquette. **Ce n'est PAS une maquette.**
> **Périmètre** : le **haut** et le **centre** du Build (la *bottom-bar / boutique* vient d'être
> redesignée → hors périmètre, référencée seulement), et l'**écran de Combat** (aujourd'hui WIP/alpha).
> **Méthode** : 3 inventaires — (A) état affichable du moteur de combat, (B) état affichable du build,
> (C) panorama UI des concurrents (sources en Annexe). Tout est **code-grounded** (noms de champs exacts).

---

## Légende de statut
| | Signification |
|---|---|
| ✅ | **Déjà rendu** à l'écran (existe, visible) |
| 🟡 | **Donnée présente dans le code, peu/pas affichée** → gain facile (câblage UI) |
| 🔴 | **À créer** (donnée ou feature absente) |
| ❌ | **Non applicable** à notre modèle (async par fantômes) |

---

## 0. Cadrage — 4 constats pour le designer

1. **Le combat a déjà ses primitives.** Barres de vie gravées (3 tons) avec **segments d'afflictions
   = dégâts à venir** (`dps × remaining`), **nombres flottants colorés par cause**, **VFX d'afflictions**
   (flammes/sang/bulles/spores/étincelles), **Chronicle/journal**, **mort dramatique**, et un **bus
   d'événements riche** (`damage`, `spread`, `shield_cast`, `reflect`, `amped`, `death`). Le « on voit
   rien » tient à la **composition / hiérarchie / cadrage**, pas à des features manquantes.
2. **Le plus gros trou côté combat = l'écran de RÉSUMÉ post-combat.** Les données existent déjà
   (`killLog`, `_computeSummary {win, cause, n, firstLoss}`, stats `sim.lua` : dégâts par cause, TTK) —
   elles ne sont **pas surfacées** comme un écran de fin. C'est le levier #1 pour « se diriger vers
   l'écran final ».
3. **Côté build, le haut/centre sont déjà bien peuplés.** Les vrais gains sont de **surfacer le
   latent** : les **bonus d'aura chiffrés** (« qui buffe qui, de combien »), le **rôle aggro/taunt**,
   et un **scouting du ghost** adverse.
4. **Adaptations async (notre singularité).** Plusieurs standards concurrents **ne s'appliquent pas** :
   pas de **classement 8 joueurs**, pas de **PV-élimination** classique (on a **vies + victoires**), et
   le **scouting** vise un **ghost figé** servi, pas un humain en direct.

---

# ÉCRAN DE COMBAT

## 1. Sur l'unité / le champ de bataille

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Barre de vie** (3 tons) | `u.hp / u.maxHp` · `healthbar.lua` | Tous (TFT crante /300 PV) | Lecture #1 du combat | ✅ |
| **Bouclier** (bande cyan) | `u.shield / u.maxShield` | TFT, HSBG (divine shield), Wildfrost (block) | distinct des PV | ✅ |
| **Segments d'afflictions** sur la barre = mort programmée | `u.dots.*` (`dps×remaining`) | *Rare — différenciateur* | montre la mort à venir | ✅ |
| **Icônes d'afflictions + stacks** | `dots.poison[#]`, `dots.shock.stacks`, burn/bleed/rot | TFT, HSBG, Wildfrost (pastilles chiffrées) | lisibilité des statuts | ✅ icônes · 🟡 chiffre de stacks à confirmer |
| **Jauge de cadence** (prochaine frappe) | `u.atkTimer / u.cd` | Wildfrost (Counter chiffré), Backpack (stamina) | **en auto-combat, savoir QUI agit quand est central** | 🟡 donnée existe, pas de jauge |
| **Slow / Haste** (tempo modifié) | `u.atkSlow`, `u.haste` | statuts TFT | feedback de tempo | 🟡 |
| **Niveau / étoile d'unité** (en combat) | `u.level` (du spec) | TFT, Underlords (étoiles), HSBG (golden) | rang visible pendant le combat | 🟡 (pips en build ✅) |
| **Aggro / Taunt** (qui tank) | `u.aggro`, `u.taunt` | HSBG (taunt) | **explique le ciblage** | 🔴 pas affiché |
| **Ciblage / focus** (qui frappe qui) | `u.target` | rare (porté par l'orientation) | clarté du déroulé | 🟡 target connu, pas de halo/ligne |
| **Nombres flottants par cause** | event `damage {hp, cause}` | TFT, HSBG, Underlords, Mecha | impact ressenti | ✅ (couleur par cause) |
| **Crit / frappe spéciale** | *(n'existe pas — Vague B « agnostiques »)* | Backpack (×2) | — | 🔴 mécanique absente |
| **VFX d'afflictions** (flammes/sang/bulles/spores/choc) | `affliction_fx.lua` | — | ambiance + lecture | ✅ |
| **Décharge de choc** (radiale) | event `damage cause="shock"` / `spread` | — | moment fort | ✅ |
| **Bouclier casté / reflect / contagion** | events `shield_cast`, `reflect`, `spread` | — | feedback de synergie | ✅ |
| **Amped** (affliction renforcée par aura) | event `amped {unit, family}` | — | montre l'ampli | ✅ |
| **Mort dramatique** (flash slot + burst sang + fondu) | event `death` | Tous | climax | ✅ |

## 2. HUD global du combat

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Décompte des vivants par camp** | `left/right` counts (`arena:update`) | implicite partout | score instantané du combat | 🟡 calculé, pas en HUD |
| **Bandeau résultat** (victoire/défaite) | `arena.over`, `arena.win`, `overAge` | Tous | conclusion | ✅ |
| **Jauge de Fatigue / enrage** | `FATIGUE_START=1020`, base/ramp | Mecha (timer), TFT/HSBG (durée bornée) | montre l'usure imminente (anti-stalemate visible) | 🔴 pas affiché |
| **Panneau de synergies actives** | *(pas de « traits » ; familles + afflictions)* | TFT (Traits), Underlords (Alliances) | montre les synergies qui tournent | 🔴 à créer (option) |
| **Contrôles spectateur** (vitesse ×2 / skip) | boucle pas-fixe (`main.lua`) | la plupart laissent jouer | confort / runs rapides | 🔴 à créer (option) |

## 3. Journal de combat (Chronicle)

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Timeline d'événements** (strike / affliction / spread / shield / death) | `chronicle.lua` (modèle riche : tick, kind, acteurs, montants, agrégation DoT, indentation conséquences) | SAP (ordre d'attaque), Wildfrost (counters) | **comprendre POURQUOI on a gagné/perdu** | ✅ modèle + panneau (P1) · 🟡 timeline scrub + ralenti (P2/P3) à venir |
| **Kill-feed** | `killLog {victim, killer, cause, tick}` | peu de jeux | lecture rapide des morts | 🟡 latent |

## 4. ⭐ Écran de RÉSUMÉ post-combat (le levier #1)

> Toutes ces données existent déjà ; il manque l'**écran qui les compose**. C'est ce qui transforme la
> fin « WIP » en **écran final**.

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Résultat + cause dominante narrative** (« Tes créatures ont succombé au ROT ») | `combat.lua:_computeSummary {win, cause, n, firstLoss}` + i18n | TFT/HSBG (écran de dégâts) | clôture émotionnelle/grimdark | 🟡 calculé + texte i18n, **écran dédié à composer** |
| **Dégâts par cause** (DoT vs frappe) et **par camp** | `sim.lua` / `eventlog.lua` (dmg by cause) | — | bilan lisible du « comment » | 🟡 data en sim, à câbler en live |
| **TTK / durée du combat** | `arena.t` (tick) | Mecha | rythme | 🟡 |
| **MVP / première perte** | `killLog`, `firstLoss` | TFT (MVP-ish) | attache aux unités | 🟡 |
| **« Dégâts au joueur »** (vies perdues) | delta `run.lives` | TFT/HSBG/Underlords (calcul de dégâts) | conséquence sur le run | 🟡 mapping vies↔survivants à définir |

---

# ÉCRAN DE BUILD — HAUT (bannière de run)

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Or courant** | `run.gold` | Tous (SAP 10/round) | ressource #1 | ✅ (HUD haut-centre) |
| **Vies restantes** | `run.lives / START_LIVES` | Underlords/TFT (100), Backpack (25), HSBG (40) | survie | ✅ (orbe bas-gauche) |
| **Victoires / objectif** (n/10) | `run.wins / WIN_TARGET` | *(objectif d'ascension propre au jeu)* | progression du run | ✅ |
| **Round / tour** | `run.round` | Tous | repère temporel | ✅ |
| **Slots ouverts / max** (3→9) | `run.slots / MAX_SLOTS` | Underlords (taille=niveau) | capacité | ✅ |
| **Streak** (win/loss ≥2) | `run.winStreak / lossStreak` | Underlords/TFT (streak→or) | momentum éco | ✅ (≥2) |
| **Sigil actif + archétype** | `board.shape` · `shape.<name>.label/archetype` | *(signature du jeu)* | identité de build | ✅ (au-dessus du plateau) |
| **Reliques équipées** | `run.relics[i]` (icônes bakées) | Storybook (treasures), Wildfrost (charms), Mecha (tech) | état du build | ✅ (rangée haut-gauche) |
| **Cotes boutique par tier** | `run.ODDS` (tooltip survol XP) | TFT, HSBG (odds par tier) | décision de reroll | ✅ (en tooltip) |
| **Scouting du ghost adverse** | snapshot servi (`build:startCombat`) | TFT (scout), Mecha (preview) | anticipation du prochain combat | 🔴 à créer (preview du ghost) |
| **Classement multi (8 joueurs)** | — | TFT/HSBG/Underlords | — | ❌ non applicable (async) |
| **Banque / intérêts** | *(or fixe/round, pas de banque)* | TFT/Underlords (intérêts) | — | ❌ par design (éco SAP-like) |

---

# ÉCRAN DE BUILD — CENTRE (le plateau-graphe)

| Élément | Source code | Concurrents | Pertinence | Statut |
|---|---|---|---|---|
| **Plateau 9 slots** (6 états : locked/empty/hover/neighbor/drop/selected) | `board.slots`, atome `Slot` | la grille de tous | cœur de l'écran | ✅ |
| **Pip de type** (flesh/order/bone/arcane/abyss) | `Units.type` · `type.<key>` | TFT (couleurs classes/origines) | lecture de compo | ✅ |
| **Pips de niveau** (1–3 duplicatas) | `slotRig.level` | TFT/Underlords (étoiles) | progression unité | ✅ |
| **Nom de l'unité** (sous la case) | `unit.<id>.name` | Tous | identification | ✅ |
| **Rig animé vivant** | Critter / rig baké | Tous | vie de l'écran | ✅ |
| **Arêtes d'adjacence** (qui buffe qui) | `board.adj`, `shape.edges` (rouge idle / or actif / or vif voisins occupés) | Backpack (adjacence implicite), TFT (hexes) | **LE différenciateur** (la forme = le graphe) | ✅ topologie |
| **Bonus d'aura CHIFFRÉS** (« +50 % poison aux voisins », « +14 bouclier ») | `buildComp` bake : `shield/burnInc/poisonInc/rotGrowth/grantBleed` | TFT (effets de traits chiffrés) | **rend la synergie *lisible*, pas juste topologique** | 🔴 calculé, **pas tracé** |
| **Carte de risque** (voile sang front/back) | `depth` | *(propre)* | exposition au combat | ✅ |
| **Banc / réserve** (4 slots) | `bench` (BENCH_SIZE) | Underlords (bench 8), SAP | stockage | ✅ |
| **Infobulle MonsterCard** (HP/DMG/CD, passif nom+desc, chips afflictions, rareté) | `MonsterCard.draw` + `units` + i18n | SAP/Storybook/TFT (tooltip) | détail de décision | ✅ |
| **Valeur de vente** | drag hors-plateau = vente | SAP/TFT (sell value affichée) | éco | 🟡 vente OK, valeur à afficher |
| **Badge aggro / taunt** (rôle tank) | `Units.aggro`, `Units.taunt` | HSBG (taunt) | **rôle de l'unité** (qui encaisse) | 🔴 latent |
| **Famille / thème** | `Units.family` | TFT (origine) | identité + future synergie de type | 🔴 latent |
| **Cadence lisible** (cd → « lent/rapide ») | `Units.cd` (frames) | — | la stat `cd` brute est peu parlante | 🟡 affichée en frames, à humaniser |

---

## 5. Tableau transversal — « ça existe, ce n'est pas montré » (gains faciles)

Le designer voudra peut-être piocher en priorité ici (donnée **déjà calculée**, juste à surfacer) :

- **Combat** : jauge de **cadence/qui-agit-quand** (`atkTimer/cd`) · **aggro/taunt** · **niveau/étoile**
  en combat · **décompte des vivants** en HUD · **jauge de Fatigue** · **écran de résumé** (cause/TTK/
  dégâts par cause/MVP) · **kill-feed**.
- **Build** : **bonus d'aura chiffrés** (qui buffe qui, *de combien*) · **badge aggro/taunt** ·
  **famille** · **valeur de vente** · **cadence humanisée** · **scouting du ghost**.

## 6. Pistes de priorité (non prescriptives — le designer tranche)

- **Doit** (transforme le WIP en écran final) : barres de vie + afflictions **bien composées/hiérarchisées**
  (existe → cadrage) · **écran de résumé post-combat** · **jauge de cadence** (lisibilité de l'auto-combat).
- **Devrait** : surfacer **aggro/taunt** + **bonus d'aura chiffrés** (rend la signature *plateau-graphe*
  enfin lisible) · **scouting du ghost** · décompte des vivants en HUD.
- **Pourrait** : panneau de synergies en combat · contrôles spectateur (×2/skip) · jauge de Fatigue ·
  kill-feed détaillé (au-delà du Chronicle).
- **Plus tard / dépend d'autres chantiers** : crit (Vague B des effets agnostiques) · aura du
  **Commandant** + **Murmures** (cf. docs de design dédiés) · timeline scrub + ralenti (Chronicle P2/P3).

---

## Annexe A — Sources (panorama concurrents)
- TFT : [Wikipedia](https://en.wikipedia.org/wiki/Teamfight_Tactics) · [Health (LoL Wiki)](https://leagueoflegends.fandom.com/wiki/Health_(Teamfight_Tactics)) · [Champion/star levels (LoL Wiki)](https://leagueoflegends.fandom.com/wiki/Champion_(Teamfight_Tactics)) · [Player damage (TFT Ninja)](https://tft.ninja/guides/game-mechanics/player-damage-calculation)
- Hearthstone Battlegrounds : [Wiki (Fandom)](https://hearthstone.fandom.com/wiki/Battlegrounds) · [Tavern Tier](https://hearthstone.wiki.gg/wiki/Battlegrounds/Tavern_Tier) · [Odds (HearthPwn)](https://www.hearthpwn.com/forums/hearthstone-game-modes/battlegrounds/239915-battlegrounds-probabilities-updates) · [Damage cap](https://us.forums.blizzard.com/en/hearthstone/t/battleground-damage-cap/69815)
- Super Auto Pets : [The Basics (wiki.gg)](https://superautopets.wiki.gg/wiki/The_Basics) · [Mechanics (a327ex)](https://a327ex.com/posts/super_auto_pets_mechanics)
- Backpack Battles : [Game Mechanics (wiki.gg)](https://backpackbattles.wiki.gg/wiki/Game_Mechanics)
- Mechabellum : [HUD/reinforcement (Steam)](https://steamcommunity.com/app/669330/discussions/0/600787986327625610/)
- Dota Underlords : [How to play (wiki)](https://dotaunderlords.fandom.com/wiki/How_to_play_guide_for_Dota_Underlords)
- Storybook Brawl : [Gameplay](https://storybook-brawl.fandom.com/wiki/Gameplay) · [Character](https://storybook-brawl.fandom.com/wiki/Character)
- Wildfrost : [Counter](https://wildfrostwiki.com/Counter) · [Charms](https://wildfrostwiki.com/Charms)

## Annexe B — Refs code clés
- **Combat** : `src/combat/arena.lua` (état unité `makeUnit` ; events `bus:emit` : spawned/attack/hit/
  damage/death/shield_cast/reflect/spread/amped/affliction_applied ; fin `over/win/overAge` ; Fatigue) ·
  `src/render/arena_draw.lua` (rigs, nombres flottants, VFX) · `src/render/healthbar.lua` ·
  `src/render/affliction_fx.lua` · `src/render/chronicle.lua` (modèle journal) · `src/scenes/combat.lua`
  (`killLog`, `_computeSummary`) · `tools/sim.lua` + `tools/eventlog.lua` (dégâts par cause, TTK).
- **Build** : `src/run/state.lua` (gold/lives/wins/round/slots/streak/shopTier/shopXp/ODDS/coûts) ·
  `src/scenes/build.lua` (plateau, infobulles `MonsterCard`, surlignage d'arêtes `nbset`, auras bake
  `buildComp`) · `src/board/board.lua` + `src/board/shapes.lua` (slots, `adj`, `edges`, sigils) ·
  `src/data/units.lua` (hp/dmg/cd/aggro/taunt/type/rank/cost/family/effects) · `src/data/relics.lua` ·
  `src/core/grimoire.lua` · i18n : `unit.<id>.name/passive_name/passive_desc`, `type.<key>`,
  `shape.<name>.label/archetype`, `relic.<id>.*`, `tier.<rank>.name`.
