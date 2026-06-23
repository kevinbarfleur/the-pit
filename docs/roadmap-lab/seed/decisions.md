# The Pit — Décisions verrouillées (seed pour le lab)

> Document de synthèse à usage interne : résume ce qui est ACTE et POURQUOI, pour que les
> rounds du lab ne re-debattent pas l'acquis. Sources primaires citees. Lecture seule du repo.
> Perimetre : CLAUDE.md + docs/research/{gd-research-result, progression-economy-prd,
> relics-design, effects-dot-families, combat-model-decision}.md

---

## 1. Piliers architecturaux (non renegociables)

### 1.1 Multijoueur asynchrone par snapshots ("ghosts")

**Acte.** On n'affronte JAMAIS un joueur en direct. On stocke des snapshots figees de builds
reels (unites + positions + sigil actif) servis a d'autres joueurs selon progression/rang/version.
Cold-start garanti par des equipes IA.

- Zéro netcode temps réel. Jouable hors-ligne.
- Snapshot = JSON sérialisable : `src/net/snapshot.lua` + `snapstore.lua` en place (v0.8).
- Le combat se rejoue cote client a partir du snapshot + seed. Meme seed → bataille identique.
- Source : gd-research-result.md §1.7 ; SAP Wikipedia « Players battle against either other
  players' teams, or AI-generated teams, if there are no players at that turn ».

**Pourquoi verrouille :** c'est le takeaway architectural #1. Toute discussion de "vrai PvP
temps reel" est hors budget et hors portee d'un solo dev (consensus forums LÖVE documenté).

### 1.2 Simulation déterministe seedée

**Acte.** Pas de `math.random` global en combat. Un `love.math.newRandomGenerator` injecte
son RNG via `opts.seed`/`opts.rng`. Meme seed → bataille identique (snapshots, replays,
golden-logs). Boucle a pas de temps fixe (`love.run` surchargee, accumulateur).

- Tout ordre de simulation en array + `ipairs`, jamais `pairs`.
- Firewall SIM/RENDER : `src/combat/arena.lua` est SIM pure (zero `love.graphics`).
- RNG en combat uniquement pour les `condition = {kind="chance"}` des ops d'effets.
- Source : CLAUDE.md §4 ; engine-architecture.md.

**Pourquoi verrouille :** condition necessaire des snapshots async. Rejouabilite, fairness,
absence de plainte "c'est truqué".

### 1.3 DA grimdark cryptique + pixel art procédural

**Acte.** Univers Cthulhu × Path of Exile × Dark Souls. Tous les visuels generés
proceduralement (grilles + palette, zero asset dessine). Style low-fi sale/sanglant.

- `src/gen/primgen.lua` : 16 archetypes exclusifs/5 familles, anatomie ancree, vrais
  squelettes. 100% du roster (v0.8).
- Rendu pixel-perfect : monde → canvas virtuel 320×180 → blit en scale entier ×4, letterbox.
- Source : CLAUDE.md §2 (vision), docs/pixel-art/.

**Pourquoi verrouille :** differenciateur artistique. "Sale, sanglant, cryptique" structure
toute l'experience (lecon Balatro/LocalThunk : le theme et le verbe choisi structurent
tout — gd-research-result.md §2.6).

---

## 2. Plateau et combat (mécaniques coeur)

### 2.1 Plateau-graphe 3×3 (9 slots), adjacence orthogonale, aretes explicites

**Acte.** Plateau = graphe : `cases` (positions de rendu) + `aretes` (qui est adjacent a qui),
defini en data, pas en code. Adjacence orthogonale uniquement (pas de diagonales — en
8-connexite le centre touche tout, ce qui tue le puzzle).

```lua
Shape = {
  cases  = { {x=0,y=0}, … },  -- rendu
  aretes = { {1,2}, {2,5}, … } -- synergies
}
```

- Centre (4 voisins) = case carry. Bords 3, coins 2. Hierarchie de cases lisible.
- Chaque slot : position de rendu (ciblage front/back) independant des aretes (synergies).
- Source : gd-research-result.md §1.3 ; `src/board/shapes.lua` en place.

**Ce qui est REJETE :** rangee lineaire unique (trop pauvre), grille 2D Tetris Backpack (trop
couteux a coder/equilibrer en V1), diagonales (neutralise le puzzle).

### 2.2 Grille mutable par sigils (5 formes)

**Acte.** Des sigils redessinent la topologie du plateau en GARDANT 9 slots constants. On
echange une topologie contre une autre, jamais de la puissance brute.

| Forme | Archetype |
|---|---|
| Carre | equilibre generique |
| Croix | mono-carry extreme (centre 4 voisins, branches isolees) |
| Anneau | chaine/propagation en boucle fermee |
| Diamant | go-wide, essaim |
| Ligne | conduit front-to-back |

- Ne pas egalisier les aretes de toutes les formes. Chaque forme a un archetype qui l'adore.
- Geometrie non-euclidienne = motif lovecraftien mecanique (R'lyeh, gd-research-result.md §2.5).
- `depth = maxCol - cell.x` : l'exposition front/back est portee par le sigil (la forme EST
  aussi le champ de bataille).
- Source : gd-research-result.md §1.3-1.4 ; combat-model-decision.md §1.

**Seuil de changement :** si une forme domine ou est ignoree, reequilibrer par l'archetype
qu'elle sert, pas en egalisant ses aretes.

### 2.3 Combat : cooldowns auto-resolus, vie par entite, mort par-combat

**Acte (2026-06, combat-model-decision.md §1).**

- **Vie PAR ENTITE, mort par-combat.** Les unites ont des PV et meurent en combat. Mais le
  build renait chaque tour. L'identite de build est protegee au niveau RUN (5 vies /
  10 victoires), pas au combat.
- **Cooldowns 1-12 s, petits nombres, Fatigue ~17 s** pour forcer une fin.
- **Zero RNG en combat** : RNG dans la construction (shop, drops), determinisme dans la
  resolution (combat). Meme seed → meme resultat.

**Ce qui est REJETE :** vie globale (Bazaar/Backpack). Raisons : fiction (monstres immortels
sonne faux en grimdark) ; supprime l'axe d'exposition front/back (signature) ; avantage
d'equilibrage annule par le harnais de simulation.

Source : combat-model-decision.md §1-2.

### 2.4 Ciblage 100% deterministe, zero de

**Acte.** Regle de ciblage implemeee dans `arena.lua:chooseTarget` :

```
1. minDepth = depth le plus bas parmi les ennemis vivants  (colonne AVANT)
2. candidats = ennemis vivants a depth == minDepth
3. si un candidat a taunt -> candidats = {taunteurs}       (override dur)
4. cible = max aggro parmi candidats
   tie-break : row min (haut->bas), puis slot              (zero de)
```

- Colonne avant → taunt → aggro la plus haute → tie-break haut→bas.
- Remplace l'ancien `nearestEnemy` euclidien (dette resolue en v0.4).
- Aggro = stat cablee mais INERTE (toutes egales a 0 pour l'instant). Architecture (taunt +
  aggro) existe ; on tune les valeurs quand les plateaux se remplissent.
- Source : combat-model-decision.md §4-6.

**Pourquoi verrouille :** SAP (100% deterministe front-vs-front) = zero plainte de focus.
Convertit "le de m'a nique" en "j'aurais du counter-placer" (yomi, skill). Async-verifiable.

---

## 3. Progression et economie

### 3.1 Boucle de run (structure)

**Acte.** 10 victoires avant ~5 defaites. Vie rendue au tour 3 si perte precoce (filet SAP).
Plateau persistant entre rounds (`host.finishCombat`). Etat de run SIM pur, seede (`src/run/state.lua`).

- Seed de combat tire du RNG du run → replay au niveau run entier.
- Source : gd-research-result.md §1.7 ; SAP Wikipedia.

### 3.2 Economie de boutique (modele XP TFT-style — DESIGN VERROUILLE 2026-06-23)

**Acte (progression-economy-prd.md §3, post-playtest).**

Boutique a **niveau 1→5** et **barre d'XP** vers le suivant. XP de deux facons :
- **Passive** : +~1 XP/round (garantit l'evolution meme sans investir, ~tier 3 en fin de partie).
- **Achetee** : bouton BUY XP (~4 XP pour ~4 or, ratio 1:1 — acceleration).

**Odds-gating (pas slot-gating) :** 5 offres toujours, monter le tier change la distribution.

| Tier | rank 1 | rank 2 | rank 3 | rank 4 | rank 5 |
|---|---|---|---|---|---|
| 1 | 100 | – | – | – | – |
| 2 | 70 | 30 | – | – | – |
| 3 | 44 | 34 | 20 | 2 | – |
| 4 | 25 | 30 | 30 | 13 | 2 |
| 5 | 15 | 20 | 30 | 25 | 10 |

(PLACEHOLDER — calibrer via `tools/sim.lua`.)

**Ce qui est REJETE :** boutique payee HS (= "payer pour monter") → piege identifie au playtest.

Source : progression-economy-prd.md §3 ; TFT XP blitz.gg/tft/guides/gold.

### 3.3 Re-tier du roster par complexite (New World Order)

**Acte.** La complexite vit dans les hauts rangs. Les communes sont des stat-sticks grokables.
`rank` = source de verite des cotes (pas `cost`). `cost = rank` (1:1).

| Rang | Profil cible |
|---|---|
| 1 | stat-sticks : tape ou tape + micro-statut (1 dps). Zero op neuf. ~12 unites |
| 2 | enabler mono-DoT simple (1 affliction, pas de twist). ~23 unites |
| 3 | enabler + 1 petit modificateur. ~18 unites |
| 4 | T2 twists, auras, tanks, choc avance. ~20 unites |
| 5 | T3 transforms / regles d'equipe. ~10 unites |

- Loi de puissance des doublons : rank-1 lvl-3 rivale en stats brutes rank-3/4 lvl-1 (mais
  sans l'effet). `LEVEL_MULT = {1.0, 1.8, 3.0}` (deja en place).
- Garde-fou : aucune relique ne doit faire qu'un rank-1 surclasse le *role* d'un rank-5
  (lecon Riot Dragonlands).
- Source : progression-economy-prd.md §4 ; MTG New World Order via gamedeveloper.com ;
  Riot dev blogs teamfighttactics.leagueoflegends.com/news/dev/.

### 3.4 Slots : grants times (inchanges)

Grants times (`SLOT_GRANT_ROUNDS`, accept = +1 / decline = +or) CONSERVES. Le niveau de
boutique (cotes) est un axe separe de la capacite (slots). L'ancien piege "slots via or" reste
rejete.

Source : progression-economy-prd.md §3.5.

### 3.5 Duplicatas : 3 copies → niveau (max 3, cascade)

**Acte (v0.8).** `build.lua:checkMerges` : 3 copies (meme id+niveau) → niveau+1 auto a la
pose, cascade, cap 3. Stats ET auras scalent (`LEVEL_MULT {1,1.8,3}`). Niveau 1 = identite
(golden-safe). Pips dores (UI).

Seuls liens avec progression : loi de puissance §3.3 + recompense level-up §4.3.

---

## 4. Systeme de reliques (pilier #2 — REVISE 2026-06)

### 4.1 Pivot : cryptique → lisible

**Acte (relics-design.md §1).** On PASSE du modele cryptique a deduire (leurres +
identification) au modele LISIBLE (effet affiche clairement). On garde l'ambiance (nom
evocateur + flavor) et la collection (Grimoire). On retire l'enigme (leurres/observation).

**Raison user :** "pas fan des leurres, trop complique pour pas grand-chose."

Modele reference : Slay the Spire (nom + effet clair avec chiffre + flavor d'ambiance).

### 4.2 Garde-fous (non-negociables)

1. **Lisible.** Effet affiche en ~2 s. Pas de leurres, pas d'identification.
2. **Aucune relique ne handicape la suite de la partie.** Intra-combat + buffs de stats au
   build uniquement. Rien de persistant cross-combat sur les unites.
3. **Egalisateur, pas portail.** Incline un matchup, jamais un gate a 100%.
4. **Chaque relique a un foyer** (un build nomable qui la veut).
5. **Team-wide.** S'applique a toute la compo.
6. **Deterministe.** Zero RNG en combat introduit par une relique.

Source : relics-design.md §1.

### 4.3 Acquisition (cadence revisee — progression-economy-prd.md §5)

- **Marchand tous les 3 combats (victoire OU defaite)** : ~5-6 visites/run (vs 3 avant).
- **Recompense level-up bornee : 1 relique/round max** (drapeau `relicFromLevelThisRound`).
  Boucle un trio de doublons en round = 1 relique seulement (anti-exploit acheter→fusionner→revendre).
- **Offres tierees par avancee de run** : early (combats 1-4) → reliques tier 1-2 universelles ;
  tard → tier 3-4 conditionnelles/build-definers.
- Choix **1-parmi-3** conserve. Decline → +or (pattern accept/decline des grants de slot).
- Source : progression-economy-prd.md §5 ; Hades (miguelmarinheiro.com) ; Backpack Battles
  wiki (rareté par round).

### 4.4 Taxonomie (vagues livrées)

- **A — Stats plates** (universelles) : +PV, +% atk, -% dégâts. Vague 1.
- **B — Amplis conditionnels** : +% affliction (poison/burn/bleed/rot), +% par famille.
  Cœur build-shaping. Vague 1.
- **C — Paliers / payoffs** : si 4+ partagent affliction → perce soins (Hollow Choir) ;
  ≤3 unites → +% (Famine's Math, tall) ; snowball au kill (Feeding Frenzy). Vague 2.
- **D — Défensives / tech** : survie 1 PV 1x/combat, invuln 0,5 s d'ouverture. Vague 3.
- **E — Transformatives** : choc rebondit, burn sans decroissance, poison sans cap. Vague 4.
- **F — Globales / evenements** : rally a la mort, explosion du 1er mort. Vague 4.
- **G — Topologie / sigils** : DIFFERE (chantier dedie, le plus signature ET le plus cher).

Pool complet 18 reliques (vagues 1-4) livre en adfc01e.

### 4.5 Grimoire

Repense de codex de deduction en **vitrine des reliques rencontrees + leur lore**. `Grimoire.learn(id)`
au grant (plus a l'identification). Persistant cross-run (meta). Source : relics-design.md §2.

---

## 5. Système d'effets (familles DoT)

### 5.1 Moteur d'effets (ouvert/ferme)

**Acte.** Effet = donnee `{trigger, op, params, condition?, target?}`. Ajouter une relique/
effet = enregistrer un op + une ligne de data, jamais editer la boucle de combat.

- `src/effects/engine.lua` : registre d'ops, `run(porteur, trigger, ctx)`.
- Bus d'evenements DETERMINISTE (array + ipairs, `src/core/bus.lua`).
- Trigger `on_death` : broadcast differe, hors-reentranceonce.
- Source : engine-architecture.md (CLAUDE.md §4).

### 5.2 Quatre familles DoT — axes distincts

**Acte (effects-dot-families.md §B).** Chaque famille a un axe de stacking distinct (principe
PoE/Last Epoch/Grim Dawn/Diablo 4 : un axe par famille = identite distincte sans regle nouvelle).

| Famille | Axe | Signature | Ignore bouclier |
|---|---|---|---|
| **Brulure** (Burn) | Intensite + decroissance | Decroit auto ; se propage aux voisins a la mort | Non |
| **Saignement** (Bleed) | Intensite + conditionnel | Ralentit la vitesse d'attaque ; burst quand la cible agit | Oui |
| **Poison** (Venom) | Nombre (N stacks ind.) | Malus sur la VALEUR des capacites de la cible | Oui |
| **Pourriture** (Rot) | Duree / accumulation | DPS croit ; ampute les PV max | Oui |

Sources primaires confrontees :
- Burn : PoE Ignite (poewiki.net/wiki/Ignite) — 1 instance la plus forte, duree fixe.
- Bleed : PoE Bleed (poewiki.net/wiki/Bleeding) — +140% si cible bouge → transpose a « si agit ».
- Poison : PoE Poison (poewiki.net/wiki/Poison) + Last Epoch ailments
  (lastepochtools.com/guide/section/ailment_duration_and_effectiveness) — N stacks ind., no refresh.
- Rot : Diablo 4 DoT (ezg.com/blog/diablo-4-season-13-...) inverse (rendements croissants).

**Deux familles supplementaires (livrees)** : choc et regeneration. 6 familles au total.

### 5.3 Contraintes moteur (non-negociables)

- Tick a pas fixe seede. Accumulation entiere (jamais de float inflige → golden-log stable).
- `u.dots = {burn, bleed, poison=[], rot, choc}` + regen.
- Ordre fixe deterministe dans `tickDots`. Stacks poison = array itere par ipairs.
- Cap de stacks poison (PLACEHOLDER 8) → anti-explosion.
- Bouclier : burn seule ne l'ignore pas (feu attaque l'enveloppe).
- Source : effects-dot-families.md §A.

### 5.4 Etat d'avancement (v0.6-v0.8)

- **4 familles DoT completes** : burn/bleed/poison/rot, chacune a 5 T1/3 T2/2 T3.
- **Auras build-resolues** (graphe du sigil), propagation en combat (contagion/mort = proximite
  du champ de bataille Arena:neighborsOf).
- **47 unites livrees** en vagues (enablers → auras → twists → transforms), toutes gatees →
  golden inchange (843214188).
- **12 synergies testees** (`tests/synergies.lua`).

---

## 6. Ce qui reste ouvert (pas re-debattre — juste implementer)

| Sujet | Statut | Ref |
|---|---|---|
| XP boutique (UI + state) | A implémenter (Lots 2-3) | progression-economy-prd.md §3.3-3.4 |
| Marchand /3 combats (OU defaite) | A implémenter (Lot 4) | progression-economy-prd.md §5.1 |
| Recompense level-up bornee | A implémenter (Lot 5) | progression-economy-prd.md §5.2 |
| Reliques ±niveau boutique | A implémenter (Lot 6) | progression-economy-prd.md §3.4 |
| Passe d'equil. auto-iteree | Lot 7 (apres data) | progression-economy-prd.md §8 |
| Passifs de ligne (facade/arriere) | Differe | combat-model-decision.md §6 |
| Contres de taunt (AoE/strip/furtivite) | Differe | combat-model-decision.md §6 |
| Ladder choc (5/3/2) | Differe | CLAUDE.md §7 |
| Reliques G (topologie/sigils) | Differe (chantier dedie) | relics-design.md §4 |
| UI reliques (infobulle 3 candidats + ecran Grimoire) | A faire | CLAUDE.md §7 |
| Effets aura/relique dans snapshot | V1 = effets de base seuls | CLAUDE.md §7 |
| 6e famille « Ordre » | A faire (gen creatures) | CLAUDE.md §7 |

---

## 7. Decisions definitives (ce qu'on ne re-discute JAMAIS)

1. **Asynchrone par snapshots.** Jamais de PvP temps reel.
2. **Sim deterministe seedee.** Firewall SIM/RENDER inviolable.
3. **DA grimdark + pixel art procedural.** Zero asset dessine.
4. **Plateau-graphe 3×3, aretes explicites, 5 sigils.** Ni rangee lineaire, ni Tetris.
5. **Vie par entite (mort par-combat, build persiste).** Vie globale rejetee.
6. **Ciblage deterministe** : colonne → taunt → aggro → tie-break. Zero de.
7. **Reliques LISIBLES** (pivot definitif 2026-06). Les leurres/identification sont retires.
8. **4 familles DoT a axes distincts.** Pas une 5e famille par analogie — toujours valider
   l'axe de stacking (source primaire) avant de proposer.
9. **Economie XP TFT-style** (passive + achetable). Boutique payee rejetee au playtest.
10. **`cost = rank`.** Le prix EST le rang. Complexite vit dans les hauts rangs.
