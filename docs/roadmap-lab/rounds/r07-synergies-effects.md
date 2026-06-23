# Round 07 — Critique adversariale : Lentille synergies-effects

> **Lentille** : synergies d'adjacence et par TYPE, 5 familles DoT, boucliers, auras,
> interactions, hiérarchie poison > tank > choc.
>
> **Statut** : Round 7/10 — challenge du brouillon v7 (`ROADMAP-draft.md`) et de la
> synthèse `round-06.md`. Lit les fichiers du repo en lecture seule, mène des recherches
> web sourcées, et challenge les propositions en accord ou désaccord **avec justification
> mécaniste**.
>
> **Inputs lus** :
> - `BRIEF.md`, `ROADMAP-draft.md` v7, `00-state.md`, `round-06.md`
> - `rounds/r06-synergies-effects.md` (critique précédente, même lentille)
> - `src/effects/ops.lua`, `src/combat/arena.lua`, `src/data/units.lua` (lecture code, références)
> - `docs/research/effects-synergy-tiers.md` (template T1/T2/T3)
>
> **Recherches web menées** :
> - a327ex.com — status effect stacking design (scaling sensitivity matrix DoT)
> - fortressofdoors.com — conservation of PotencyDuration, stacking algorithm
> - teamfighttactics.leagueoflegends.com — Inkborn Fables learnings (vertical traits)
> - TFT Magic n' Mayhem learnings (champion augments, condition d'activation)
> - poewiki.net/wiki/Shock + poe2wiki.net/wiki/Shocked (mécanique précise)
> - lastepoch.fandom.com/wiki/Poison + onlyfarms.gg/wiki/last-epoch (stacking illimité LE)
> - devforum.roblox.com + irsen/devlog (systèmes de stacking status effects 2024)
> - seeingthechessboard.com — combos roguelite celebration 2024 (drafted vs constructed)
> - mobilegamereport.com — Super Auto Pets composition synergies depth 2026
>
> **Garde-fous** : lecture seule du repo + web ; écriture uniquement sous
> `docs/roadmap-lab/`. Piliers async/déterministe/grimdark/procédural respectés.
> Ne modifie ni le code, ni les tests.

---

## 0. Angle d'attaque de ce round

Le round 6 a tranché deux litiges majeurs (#D global pur, #W burn intentionnel) et
ajouté 3 tests inter-famille comme précondition P1. Ce round attaque ce qui reste
**fragile, sous-traité ou non-étayé** dans le brouillon v7 du point de vue
synergies-effects :

1. **La hiérarchie poison > choc est traitée comme un problème à résoudre par deux
   métriques (`--poison-frac`, `--no-weaken`), mais ces deux axes ne capturent pas un
   troisième axe structurel : la quantité brute de poseurs.** Poison est la seule famille
   avec 15 unités (00-state §2.1 : burn ~13, bleed ~13, poison ~15, rot ~11, choc 11).
   La sim `--poison-frac` mesure la propagation ; `--no-weaken` isole le weaken. Mais
   si 15 unités poison remplissent le pool vs 11 choc, le joueur verra poison plus
   souvent en boutique même toutes choses égales — et les 3 tests inter-famille
   n'adressent pas ce déséquilibre de représentation.

2. **Le twist bleed-4 = `bleedPierceShield` souffre d'un problème de scaling non
   documenté que la littérature DoT (a327ex.com) met en évidence : le bleed a un
   `BLEED_DPS_CAP = 12` (`ops.lua:28`) distinct du `DOT_CAP_MULT = 3` des autres
   familles. Si le twist retire 1 pt de bouclier par tick, et que le bouclier ennemi
   est reconstruit par `shield_aura` entre les ticks, la mécanique pourrait être
   quasi-inerte en pratique — exactement comme `sacred_shield invulnT=30` (30 ticks).
   Ce bug latent n'est PAS couvert par les 3 tests inter-famille proposés.**

3. **Le tableau de saturation d'inc par famille (précondition P1) présenté en §5.2
   suppose implicitement que `base_dps médian` est stable. Mais le DPS-frappe du
   choc est ZÉRO au palier de base** (choc = condensateur, 0 dégât à la pose,
   décharge seule) — ce qui rend la formule `seuil_inc_saturé = (cap/base_min) − 1`
   **incalculable** pour le choc, ou infini, ou 0. Le tableau a un cas dégénéré non
   signalé.

4. **L'axe rot = counter des tanks via amputation des PV max est adopté (colonne I :
   rot → tanks/taunt) mais son écosystème de counters est orphelin.** Le brouillon note
   « rot sans payoff-late » (§4.8) mais ne connecte pas le problème à l'absence de
   relique rot qui CIBLE les tanks. Une relique rot tier-4 est différée à P1.5b, mais
   rien n'assure qu'elle renforce l'axe amputation-PV-max. Ce trou est mesurable et
   actionnable maintenant.

5. **Le choc axe D (amplifie la famille du poseur) a un problème de timing non adressé
   que la critique r05 avait signalé et que le round 6 n'a pas résolu : l'amplification
   ne se déclenche qu'après le bake du choc dans `tickDots`. En early (rounds 1-3,
   plateau de 3 unités), le joueur aura rarement un poseur choc ET des unités de sa
   famille adjacentes avec du DoT actif AVANT la décharge — ce qui rend l'apex choc
   faiblement utile en early sans être VISIBLEMENT faible.** Le signal UI manquant
   n'explique pas cette latence structurelle early.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi ancré dans NOS contraintes

### 1.1 Compteur de type GLOBAL PUR (#D clos round 6) — ACCORD COMPLET

La décision est correcte et irréversible pour NOS contraintes. La source TFT Inkborn
Fables learnings (teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-tft-inkborn-fables-learnings,
relu ce round) ajoute un angle indépendant de TFT Galaxies (cité en r06) :

> « big vertical traits MUST have primary stars, which usually means selfish amounts of
> power to the champs within the trait. »

Ce n'est pas la même leçon que la dead-zone (Galaxies), c'est la leçon de
**lisibilité de la valeur** : quand Ghostly/Heavenly nécessitaient Zyra/Senna comme
carrys (non-Ghostly), les unités DANS le trait (Morgana, Kayn) semblaient faibles.
Notre transposition : si le palier 4 exigeait une condition d'adjacence, une unité de
la famille en slot non-adjacent « semblerait faible » même à count=4, parce que le
joueur perçoit que le trait n'est pas « pour elle ». Le global pur résout : count=4 =
chaque unité compte, sans exception de placement.

**Nos contraintes renforcent encore la décision** : on joue sur une grille de 9 slots
avec `START_SLOTS=3` — en early, atteindre le palier 4 tout en maintenant une paire
adjacente est un puzzle à 2 axes qui dépasse la capacité cognitive d'un plateau de 3
unités. Le global pur est le seul design qui reste lisible à `slots=3`.

### 1.2 Burn-vuln-bouclier = intentionnel (#W clos round 6) — ACCORD COMPLET

Le système rock-paper-scissors tient à nos contraintes. Précision que r06 n'a pas
documentée : **PoE1 Ignite vs PoE2 Ignite** divergent exactement sur ce point — PoE1
Ignite ignorait la résistance au feu (plus aucun shield méta) et a dû être tuné
violemment plusieurs fois (pathofexile.com forums, archive 3.28). Notre approche
(burn absorbé par bouclier = coût de la propagation, twist burn-4 = `burnIgnoreShield`
comme keystone optionnel) est mécanistement plus saine que la « mécanique qui
s'ignore elle-même ».

**Conséquence sur nos piliers (non dite en r06)** : le sistema burn>carries, tank>burn
est un système de **counterplay VÉRIFIABLE DANS LES SNAPSHOTS** — si un joueur ghosts
son build burn contre un joueur taunt, la défaite est **attributable** (le ghost
adverse avait un tank, c'est visible post-combat dans la métadonnée snapshot `{shape,
units}`). C'est une symétrie parfaite avec le ciblage déterministe (décision §6 :
« j'aurais dû counter-placer »).

### 1.3 3 tests inter-famille AVANT P1 — ACCORD FORT + COMPLÉMENTS

Les 3 tests (§5.2 roadmap v7 : aura+palier, shield+bleed-4, choc-D+aura) sont
nécessaires. Deux précisions importantes qui manquent dans la spec :

**Q1 (nommage des teamFlags) est critique à trancher avant l'implémentation.** La
distinction `poisonIncTeam` (palier-2) vs `poisonNoCap` (festering T3) doit être
documentée dans le registre d'ops (`src/effects/ops.lua`) AVANT d'écrire les tests —
sinon le test 1 du round 6 (aura + palier poison-2 → cap ×3) risque de tester le
mauvais flag. Source : engine-architecture.md §8 (registre ouvert/fermé — un op =
une entrée, pas une redéfinition).

**Le test 2 (`shield_aura` + `bleedPierceShield`) est insuffisant tel que spécifié
— voir §2.1 ci-dessous.**

### 1.4 Tableau de saturation d'inc par famille (précondition P1) — ACCORD SUR LE PRINCIPE, DÉSACCORD SUR LA COMPLÉTUDE

L'idée est correcte et la formule `seuil_inc_saturé = (cap/base_min) − 1` est
calculable pour burn/bleed/poison/rot. L'accord est ferme pour ces 4 familles.
Le désaccord porte sur le cas choc — voir §2.2.

### 1.5 Signal UI obligatoire (choc-D, bleed-4 bascule) — ACCORD FORT

La roadmap v7 pose 2 besoins de signal UI : l'amplification choc-D (§3.4) et la
bascule d'identité bleed-4 (§5.2). Les deux sont corrects et nécessaires. Le Roguelike
Celebration 2024 (seeingthechessboard.com, relu ce round) documente exactement ce
besoin sous le concept « drafted mullet » : dans un système 3-pick-1, la lisibilité
des synergies disponibles (et à venir) détermine si le joueur peut combiner ou subit
le hasard. Sans signal UI sur la bascule bleed-4, le joueur ne « combine » pas — il
subit une règle surprise.

---

## 2. DÉSACCORDS — ce qui est faible, faux ou non-étayé

### 2.1 DÉSACCORD FORT : Le twist bleed-4 = `bleedPierceShield` (1 pt bouclier/tick) est potentiellement quasi-inerte contre les builds shield-aura — non testé

**Ce que la roadmap v7 dit** (§5.2) : `grant_team {bleedPierceShield}` — chaque tick
bleed retire 1 point de bouclier. « Counter-bouclier lent et prévisible (1 pt/tick →
n'invalide pas les tanks). »

**Le problème non documenté** :

Les unités `shield_aura` bakent leur bouclier à `combat_start`. Le bouclier est
l'enveloppe : quand elle est épuisée, les hits suivants touchent les PV. Mais la
roadmap ne spécifie pas **si le `shield_aura` se reconstruit par tick ou est une
valeur statique baked**.

Si le bouclier est **statique (baked once à combat_start)** — ce que le pattern
`shield_aura` suggère (`trigger="combat_start"`) — alors `bleedPierceShield` de 1
pt/tick est un drain progressif valide.

**Mais si un voisin pose un bouclier récurrent** (`shield_caster` = périodique,
5 unités dans le pool) ou si un palier de type futur ajoute de la regen de bouclier,
le drain de 1 pt/tick peut être entièrement absorbé. La question est : **quel est le
DPS de drain de bouclier vs le taux de régénération de bouclier adverse le plus courant
?**

**Source (a327ex.com/logs/ebb-status-effect-system-design, relu ce round)** — la
Scaling Sensitivity Matrix pour bleed :

> Bleed : Knockback synergy (strong), Raw stats (weak). Cap stacks.

a327ex identifie que bleed est SENSIBLE aux synergies contextuelles (knockback dans
son cas, counter dans le nôtre) et FAIBLE sur les stats brutes. Si `bleedPierceShield`
retire 1 pt/tick mais que `shield_caster` régénère 8 pts tous les ~60 ticks (valeur
arbitraire, non sourcée dans le code actuel), la mécanique est quasi-nulle en pratique.

**Le chiffre ``invulnT=30` = 0,5 s` (code-vérifié round 6) est exactement ce schéma** :
une valeur non simulée qui s'avère quasi-inerte. `bleedPierceShield` risque le même
destin sans une CONFIG-BD (Build Défense) dédiée.

**Recommandation** :
1. Avant P1, **grep `shield_caster` dans `units.lua` et `ops.lua`** pour identifier
   le montant de bouclier régénéré et sa cadence.
2. Ajouter au **test 2 des 3 inter-famille** une version avec un `shield_caster` voisin
   actif (pas seulement un `shield_aura` statique) : vérifier que `bleedPierceShield`
   drain le bouclier **net** > 0 sur une durée de combat standard.
3. Si le drain net < bouclier régénéré → **augmenter à 2 pts/tick** ou changer l'axe
   vers un seuil de stacks bleed (ex. « à 5 stacks bleed, consume les stacks pour vider
   50 % du bouclier courant » — burst au lieu de drain) pour garantir l'efficacité.

**Priorité** : MOYENNE. Pas bloquante pour P1 si le test est ajouté, MAIS le test
actuel spécifié en §5.2 (`shield_aura` seul) est insuffisant.

### 2.2 DÉSACCORD MOYEN : Le tableau de saturation d'inc par famille a un cas dégénéré non signalé pour le choc

**Ce que la roadmap v7 dit** (§5.2 garde-fou twist #3) : le tableau note, par famille,
`base_dps médian`, `cap output`, `seuil_inc_saturé = (cap/base_min) − 1`.

**Le problème** :

Le choc est un **condensateur à 0 dégât à la pose** (00-state §3.1 : « 0 dégât à la
pose ; décharge au prochain coup, ignore bouclier »). Son `base_dps` au sens tick n'est
pas un DPS — c'est un **burst différé**. La formule `seuil_inc_saturé = (cap/base_min)
− 1` suppose que `base_min > 0`. Pour le choc :

- `base_dps tick = 0` (pas de tick de choc — c'est une décharge au hit, pas un DoT)
- Le cap n'est pas `DOT_CAP_MULT=3` (qui s'applique aux DoT) mais `SHOCK_STACK_CAP=8`
  (caps les stacks) — deux axes de cap incompatibles.
- La formule `(cap/base_min) − 1` = `(N/0) − 1` = **infini** ou crash selon
  l'implémentation du tableau.

**Ce n'est pas un détail** : si le tableau est produit par un agent sans cette précision,
le choc sera soit ignoré (colonne vide = non calculable), soit mal calculé (DPS de
frappe du choc ≠ DPS de décharge). Et la spec du palier choc-4 (le twist) serait fixée
sur un budget d'inc sans rapport avec la décharge réelle.

**Source de design** : le burst condensateur (a327ex.com, relu) est un « Counter »
mechanic — il se déclenche sur un événement, pas sur une durée. La formule de
saturation est conçue pour les ticks ; pour les counters, la métrique correcte est
`P(décharge par combat) × magnitude_décharge_max`.

**Recommandation** :

Dans le tableau de saturation (§5.2 précondition P1), ajouter une **ligne dédiée
choc hors-formule** :

```
| Choc | N/A (pas de DPS-tick ; burst différé) | SHOCK_STACK_CAP=8 |
| Métrique correcte : burst_DPS_eq = (stacks × ampli × dps_famille) / cd_moyen_cible |
| Voir §3.1a roadmap v7. |
```

**Et noter explicitement** que le palier choc-4 (si un twist est prévu) ne peut pas
être balancé par `increased_output` (le choc n'a pas d'output direct) — il doit
modifier le nombre de stacks (`shockStackBonus`) ou la magnitude de l'ampli
(`shockAmpMult`) ou la condition de décharge (`shockOnAnyDoT` vs `dot_family`
seulement).

**Priorité** : HAUTE — précondition du tableau de saturation, bloque la spec du palier
choc.

### 2.3 DÉSACCORD MOYEN : La mesure `--poison-frac` + `--no-weaken` ne capte pas le déséquilibre de représentation du pool

**Ce que la roadmap v7 dit** (§3.5) : deux mesures `--poison-frac` (propagation) et
`--no-weaken` (weaken) pour diagnostiquer les causes structurelles de poison > choc.

**Le trou** :

Poison a 15 unités dans le pool, choc a 11 (00-state §2.1). Dans un SHOP_SIZE=5 avec
des cotes uniformes par rang, la **probabilité d'apparition de poison en boutique est
~36 % plus élevée que choc** (15/11 − 1 ≈ 0.36, en supposant même distribution de
rang). Ce déséquilibre de représentation n'est pas mesuré par `--poison-frac` (qui
simule des builds construits, pas des offres de boutique).

**Source (Super Auto Pets, mobilegamereport.com 2026, relu)** :

> « The power ceiling of any given composition is determined by how cleanly the triggers
> chain, not by raw stat totals. »

Mais le point implicite est que la chaîne commence par la **visibilité en boutique** :
si poison est vu plus souvent, le joueur construit plus naturellement poison. Dans un
pool LOCAL (SHOP_SIZE=5, pas de concurrence inter-joueurs pour les unités), la
représentation de boutique est le **vecteur d'entrée** de la méta.

**Conséquence chiffrée** :

Pool rang-2 : 23 unités. Si poison-rang-2 = ~7 unités et choc-rang-2 = ~3 unités (à
confirmer dans `units.lua`), P(voir poison-rang-2 en T2) ≈ `7/23 × 5` ≈ 1,52/round
vs P(voir choc-rang-2) ≈ `3/23 × 5` ≈ 0,65/round. Le joueur voit du poison 2,3×
plus souvent que du choc en T2 — **mécanistement antérieur** à toute propagation ou
weaken.

**Recommandation** :

Ajouter une **3e mesure P0.5** : `--pool-repr` (représentation du pool par famille,
par rang) — compter le rapport unités/famille/rang et le comparer à `SHOP_SIZE`. Si
le ratio `max_famille/min_famille` par rang > 1.5 → recommander un rééquilibrage du
pool (retrait de `U.pool` de quelques enablers DoT redondants, déjà prévu en col B
§3.1) **AVANT de tuner les valeurs de puissance**.

**Priorité** : HAUTE — sans cette mesure, `--poison-frac` et `--no-weaken` peuvent
identifier et résoudre les causes de puissance tout en laissant la cause de
représentation activer la dominance. La roadmap corrigerait l'arbre et pas les racines.

### 2.4 DÉSACCORD FAIBLE MAIS PRÉCIS : Le rot comme counter des tanks est orphelin de mécanique d'exposition

**Ce que la roadmap v7 dit** (col I, §3.1) : « rot → tanks/taunt (l'amputation PV max
contourne le HP brut ; le tank meurt avant que les carries soient atteintes) ». Et
(§4.8) : « rot sans payoff-late ❌ pas de payoff-late ». Relique rot tier-4 différée
à P1.5b.

**La tension non documentée** :

L'amputation des PV max (rot) est un counter des tanks **UNIQUEMENT si le rot atteint
les tanks**. Mais le ciblage déterministe (décision §6) cible la colonne avant
(`depth = minDepth`) → **le tank est EN FRONT, le rot est posé par des unités EN
FRONT aussi (qui ciblent le front adverse)**. Le rot touche BIEN les tanks — mais
**uniquement si notre front attaque le front adverse** (colonne vs colonne).

Le problème est subtil : si l'adversaire a un sigil qui met ses tanks en front AND
en PROFONDEUR (ex. sigil ligne — les tanks sont à `depth=0` sur 2 colonnes), notre rot
peut toucher plusieurs tanks correctement. Mais si le sigil adverse met ses carries
en front (sigil croix, carry central) et les tanks en flanc, le rot cible les carries
(front), pas les tanks (flanc).

→ **Le rot est un counter des tanks SEULEMENT quand les tanks sont en front adverse.**
Ce n'est pas garanti par le ciblage déterministe.

**Ce qui manque** : la colonne I (§3.1) devrait noter cette condition. Et la relique
rot tier-4 (P1.5b) devrait idéalement avoir un axe qui fonctionne INDÉPENDAMMENT du
placement ennemi — par exemple : « le rot ampute les PV max de la cible la plus haute
PV max » (pas juste la cible front), ce qui renforcerait la synérgie rot-tank sans
dépendre du sigil adverse.

**Source** : combat-model-decision.md §4 (ciblage déterministe documenté) + 00-state
§3.3 (`depth = maxCol - cell.x`, dérivé du sigil). La condition de placement est
**non testée dans `tests/synergies.lua`** (zone sans test — 00-state §8).

**Priorité** : FAIBLE. Documentation (ajout note col I). La relique rot tier-4 devrait
intégrer cette contrainte dans sa spec.

### 2.5 DÉSACCORD FAIBLE : La latence structurelle du choc en early (rounds 1-3) est non-adressée

**Ce que la roadmap v7 dit** (§3.4-bis) : CONFIG-PC pour `plague_communion`. Et
(§3.1a) : choc jaugé en `burst_DPS_eq` = condensateur. Le signal UI est obligatoire.

**Le trou** :

En early (rounds 1-3, `slots=3-5`), un build choc se compose de :
- 1-2 poseurs choc
- 1-2 unités de la `dot_family` ciblée (burn ou bleed ou etc.)
- La cible adverse doit avoir du DoT actif AU MOMENT de la décharge

Avec 3 slots, le joueur a peu d'unités de la bonne famille. Le DoT adverse sur la
cible est incertain (les adversaires IA des rounds 1-3 sont simples). La décharge
choc amplifie un tick DoT **qui peut ne pas exister encore** si la cible meurt vite
ou n't pas de DoT actif.

**Conséquence** : en early, le choc axe D produit du DPS proche de 0 pas parce que
la puissance est mal calibrée, mais parce que la **condition de déclenchement n'est
pas remplie structurellement** (pas assez de DoT actif sur les cibles). Le joueur
perçoit le choc comme faible en early, et quitte l'archétype avant le mid-game où il
deviendrait bon.

**Ce qui manque** : la sim CONFIG-PC (§3.9) qui teste `plague_communion` fait cela
pour P0.5 — mais aucune config analogue n'existe pour le choc en early (rounds 1-3,
slot=3). La `--poison-frac` mesure la propagation ; le choc n'a pas de mesure de sa
condition de déclenchement par phase de run.

**Recommandation** : ajouter une **CONFIG-CE (Choc Early)** dans la matrice sim
(§3.4-bis) : `{1 choc + 1 burn-poseur + 1 rang-1 stat-stick} vs build IA round-2` —
mesurer le `burst_DPS_eq` réel et comparer au `burst_DPS_eq` théorique du §3.1a.
Si l'écart > 40 % → documenter une règle de rampe (ex. : le choc en early doit avoir
un **fallback de dégâts directs** si aucun DoT actif sur la cible — 1 unité choc
avec un dégât de frappe non-nul même sans DoT).

**Priorité** : FAIBLE. Diagnostic de tuning (P3 level), mais le signaler avant P1
évite de graver un design d'apex choc que le sim contredira.

---

## 3. PROPOSITIONS PRIORISÉES

### P1 — Compléter le test 2 inter-famille (shield_aura + bleedPierceShield) avec un shield_caster actif [PRIORITÉ HAUTE, précondition P1]

**Quoi** : dans la spec des 3 tests inter-famille (§5.2 roadmap v7, ajouter à
`tests/synergies.lua`), remplacer le test 2 :

**Spec actuelle** :
> (2) `shield_aura` (voisin) + twist bleed-4 `bleedPierceShield` → le tick retire 1 pt
> ET l'aura se reconstruit

**Spec étendue** :
> (2a) `shield_aura` (voisin) statique + twist bleed-4 `bleedPierceShield` : le tick
> retire 1 pt ET l'aura ne se reconstruit PAS pendant le combat (guard : `shield_aura`
> est baked à `combat_start`, pas régénéré en cours de combat → drain progressif
> validé).
> (2b) `shield_caster` (voisin) actif + twist bleed-4 `bleedPierceShield` : mesurer
> le **bouclier NET** après N ticks (drain - régénération). Si bouclier NET < 0 → la
> mécanique est inerte contre les builds avec `shield_caster` → augmenter à 2 pts/tick
> OU changer l'axe.

**Pourquoi** : le test (2a) seul confirme que la mécanique fonctionne contre les
boucliers statiques. Mais les 5 unités `shield_caster` dans le pool (00-state §3.1)
sont exactement le contexte où `bleedPierceShield` doit fonctionner — sinon le twist
ne counter pas les builds défensifs, il ne counter que les `shield_aura` qui ne se
régénèrent pas. Ce serait un twist quasi-inerte en pratique (exact même schéma que
`sacred_shield invulnT=30`).

**Coût** : 1 test additionnel (~15 lignes), seed connue, 0 code moteur. Fait
**pendant** la mise en œuvre du lot inter-famille, pas après.

**Source** : 00-state §3.1 (boucliers périodiques = 5 unités) ; r06 §0 (méthode
grep-avant-d'affirmer : le synthétiseur a découvert `invulnT=30` en 1 grep). Le même
réflexe doit s'appliquer au taux de régénération de `shield_caster`.

### P2 — Ajouter une note dégénérée choc dans le tableau de saturation d'inc par famille [PRIORITÉ HAUTE, précondition P1]

**Quoi** : dans le tableau de saturation (§5.2 précondition P1), ajouter avant la
production du tableau :

```
EXCEPTION CHOC : pas de DPS-tick. Ne pas appliquer la formule
seuil_inc_saturé = (cap/base_min) − 1 au choc.
Métrique choc = burst_DPS_eq (§3.1a).
Cap choc = SHOCK_STACK_CAP=8 (stacks), pas DOT_CAP_MULT=3.
Le palier choc-4 (twist) doit modifier un des 3 axes :
  - shockStackBonus (nb de stacks posés par hit)
  - shockAmpMult (magnitude de l'ampli par famille du poseur)
  - shockTrigger (condition de décharge — ex. any_dot vs dot_family_seulement)
Le paramètre `more` (§5.2 garde-fou twist #3) ne s'applique pas directement.
```

**Pourquoi** : sans cette note, un agent ou l'user remplissant le tableau peut calculer
un `seuil_inc_saturé` infini pour le choc et conclure « le choc n'est pas à risque
de saturation » — ce qui est vrai mais pour la mauvaise raison, et ne guide pas la
spec du twist choc-4.

**Coût** : doc pur, 0 code, 5-10 lignes dans le tableau.

### P3 — Ajouter `--pool-repr` comme 3e mesure P0.5 (représentation du pool par famille) [PRIORITÉ HAUTE, AVANT `--poison-frac`]

**Quoi** : dans la matrice sim P0.5 (§3.5 roadmap v7), ajouter AVANT `--poison-frac` :

```
--pool-repr : pour chaque rang × famille, compter le ratio (unités/famille/rang) /
(unités_totales/rang). Alarme si max_famille/min_famille > 1.5 sur un rang.
```

Si l'alarme se déclenche (probable pour rang-2, poison vs choc), corriger le pool
(col B §3.1 : retrait de `U.pool` d'enablers redondants) **avant de lancer
`--poison-frac`**. Sinon `--poison-frac` mesure la puissance d'un poison déjà
sur-représenté ET sur-puissant — les deux leviers se confondent dans le win%.

**Pourquoi** :
- L'audit 10-col col (B) identifie déjà les candidats pool-A (enablers POOL vs NICHE).
  `--pool-repr` est la **validation quantitative** de ce diagnostic qualitatif.
- La sim `--poison-frac` isole la propagation, `--no-weaken` isole le weaken — mais
  les deux supposent un pool représentatif. Si poison a 15 unités vs choc 11, le pool
  n'est pas représentatif. Sans `--pool-repr` en précédition, on ajuste la puissance
  et pas la représentation.

**Coût** : ~10 lignes dans `tools/sim.lua` (comptage par `dot_family` + rang + format
du rapport). Fait **avant** les configs `--poison-frac` / `--no-weaken`.

**Source** : mobilegamereport.com 2026 (SAP profondeur = triggers chains + boutique
vision) ; 00-state §2.1 (poison ~15, choc 11 — écart documenté mais non mesuré
quantitativement pour le pool).

### P4 — Ajouter CONFIG-CE (Choc Early) dans la matrice sim P0.5 [PRIORITÉ BASSE, doc sim]

**Quoi** : dans §3.4-bis (CONFIG-PC), ajouter une CONFIG-CE :

```
CONFIG-CE (Choc Early — latence early)
Composition : {1 choc poseur (galvanizer T1) + 1 burn-poseur (ash_moth T1) + 1
  stat-stick T1} vs rencontre IA round-2 (encounters.lua).
N = 30, seed 20260620.
Mesurer : burst_DPS_eq réel (ampli activée sur combien de ticks ?) vs burst_DPS_eq
  théorique (§3.1a).
Alarme : écart > 40 % → documenter une règle de rampe pour l'unité choc en early
  (fallback dégât direct non-nul si 0 tick DoT actif sur la cible).
```

**Priorité basse** : c'est un diagnostic de tuning (P3 level), pas une correction
P0.5. Mais signalé maintenant pour éviter d'aggraver le biais dans la spec du twist
choc-4.

### P5 — Documenter la condition de placement dans la colonne I (rot vs tanks) [PRIORITÉ BASSE, doc P0.5]

**Quoi** : dans la colonne I de l'audit (§3.1), sous « rot → tanks/taunt », ajouter :

```
CONDITION : le rot countère les tanks UNIQUEMENT si les tanks adverses sont
en front (depth=minDepth). Si le sigil adverse met les carries en front et les
tanks en flanc, le rot cible les carries. La relique rot tier-4 (P1.5b) doit
fonctionner INDÉPENDAMMENT du placement adverse si l'archétype rot-tank est
voulu comme une réponse fiable aux tanks.
Candidat twist rot-4 : amputation des PV max de la cible à PV_max le plus élevé
(pas la cible front) → rend le counter rot-tank placement-indépendant.
```

---

## 4. QUESTIONS OUVERTES

### Q1 : Le `shield_caster` régénère-t-il un montant fixe ou un montant scalant avec le niveau de l'unité ?

Si le montant de bouclier régénéré par `shield_caster` scale avec le niveau (via
`LEVEL_MULT={1.0,1.8,3.0}`), un niveau-3 de `shield_caster` régénère 3× le bouclier
d'un niveau-1. Le drain de `bleedPierceShield` (1 pt/tick, non scalant par définition
d'une règle `grant_team`) serait entièrement absorbé par un `shield_caster` niveau-3.
→ Requiert un grep de `ops.lua` sur l'op `shield_caster` avant de finaliser la spec
de `bleedPierceShield`.

### Q2 : Combien d'unités choc sont-elles actuellement dans `U.pool` par rang ?

00-state §2.1 note 11 unités choc total, mais ne donne pas la répartition par rang.
Si la majorité des unités choc sont rang-3 ou rang-4, la représentation choc en T1-T2
est encore plus faible — ce qui renforce l'argument `--pool-repr` (§3.P3) et explique
la latence early (§2.5) par un problème de **visibilité early**, pas de puissance.

### Q3 : Le palier bleed-4 (`bleedPierceShield`) doit-il s'appliquer à TOUS les ticks bleed ou seulement au tick de la plus haute instance ?

Last Epoch (lastepoch.fandom.com, relu) distingue les instances de poison par source.
Notre bleed a un `BLEED_DPS_CAP=12` distinct du cap général. Si `bleedPierceShield`
s'applique à TOUS les ticks de toutes les instances bleed simultanées, le drain de
bouclier peut être bien plus élevé que « 1 pt/tick » suggéré — il serait
`(nb_stacks_bleed_actifs × 1 pt)/tick`. À clarifier dans la spec avant P1.

### Q4 : Les synergies de type (paliers 2 et 4) s'appliquent-elles aux unités dont `dot_family` est `nil` (tanks, stat-sticks) ?

La colonne D (`dot_family` inférée) laisse `nil` pour les tanks et stat-sticks purs.
Si le palier-2 burn donne +20 % aux effets burn de l'équipe, est-ce que les unités
`dot_family=nil` contribuent au count du palier ? (Elles ne devraient pas, mais la
spec de `grant_team` dans `teamFlags` doit l'exclure explicitement.) Ce cas-limite
est une **zone sans test** (00-state §8).

---

## 5. CE QUI N'EST PAS UN DÉSACCORD

- **12 synergies de base + les 3 nouvelles tests inter-famille** : plancher sain, accord.
- **`DOT_CAP_MULT=3` anti-snowball** : correct et non-challengé.
- **Architecture `grant_team` / `teamFlags` pour les paliers de type** : accord technique
  fort. L'ordre de résolution `combat_start` (teamFlags APRÈS bake des auras) est le
  point critique à tester (tests 1 et 3 du lot inter-famille).
- **`afflictionCount` C2 (compter uniquement les DoT actifs, pas `wither_bloom`)** :
  correction code-vérifiée round 5, maintenue. Non re-challengée.
- **Seuils 2/4 sur 9 slots** : accord fort, confirmé TFT Inkborn Fables (vertical
  traits must have primary carries within the trait).
- **Axe rot = amputation PV max** : correct mécanistement (contourne le HP brut des
  tanks). La nuance de condition de placement (§2.4) est doc, pas un challeng de
  l'axe lui-même.

---

## 6. Tableau de synthèse hiérarchisé

| Critique | Sévérité | Impact roadmap | Action recommandée | Priorité |
|---|---|---|---|---|
| `bleedPierceShield` potentiellement inerte vs `shield_caster` (non testé) | **FORTE** | Twist bleed-4 quasi-inerte en pratique → P1 grave un bug latent | Étendre test 2 inter-famille à inclure `shield_caster` actif | précondition P1 (HAUTE) |
| Cas dégénéré choc dans le tableau de saturation d'inc (base_min=0) | **FORTE** | Spec du palier choc-4 bâtie sur un calcul infini → twist non-spécifiable | Ajouter note exception choc dans le tableau de saturation | précondition P1 (HAUTE) |
| Déséquilibre de représentation pool (poison 15 vs choc 11) non mesuré | **MOYENNE** | `--poison-frac` corrige la puissance mais pas la sur-représentation | Ajouter `--pool-repr` comme 3e mesure AVANT `--poison-frac` | P0.5 (HAUTE) |
| Latence structurelle choc en early non diagnostiquée | **FAIBLE** | L'apex choc perçu faible en early → abandon avant le mid-game | CONFIG-CE dans la matrice sim | P3 / doc (BASSE) |
| Condition de placement rot-counter-tank non documentée | **FAIBLE** | Relique rot tier-4 (P1.5b) mal spécifiée si ignore la condition | Note doc dans col I + spec relique rot-4 | P1.5b / doc (BASSE) |

---

## 7. Index des sources

**Web vérifié ce round :**

- a327ex.com — Status Effect stacking, Scaling Sensitivity Matrix (DoT design) :
  [a327ex.com/logs/ebb-status-effect-system-design](https://a327ex.com/logs/ebb-status-effect-system-design)
- fortressofdoors.com — Conservation of PotencyDuration, stacking algorithm classique :
  [fortressofdoors.com/a-status-effect-stacking-algorithm/](https://www.fortressofdoors.com/a-status-effect-stacking-algorithm/)
- TFT Inkborn Fables learnings — vertical traits must have primary stars, Ghostly/Heavenly :
  [teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-tft-inkborn-fables-learnings/](https://teamfighttactics.leagueoflegends.com/en-au/news/dev/dev-tft-inkborn-fables-learnings/)
- TFT Magic n' Mayhem learnings — Champion Augments, condition d'activation :
  [teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-magic-n-mayhem-learnings/](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-magic-n-mayhem-learnings/)
- PoE2 Wiki Shock — magnitude indépendante des durées multiples, seul le plus fort s'applique :
  [poe2wiki.net/wiki/Shocked](https://www.poe2wiki.net/wiki/Shocked)
- Last Epoch Poison — instances indépendantes, résistance -5%/stack, no hard cap :
  [lastepoch.fandom.com/wiki/Poison](https://lastepoch.fandom.com/wiki/Poison)
  [onlyfarms.gg/wiki/last-epoch/poison-stacks-limit-guide](https://onlyfarms.gg/wiki/last-epoch/poison-stacks-limit-guide)
- Roguelike Celebration 2024 — Drafted mullet, synergy signaling, 3-pick-1 :
  [seeingthechessboard.com/life-liberty-and-the-pursuit-of-comboness-talk-roguelike-celebration-2024/](https://seeingthechessboard.com/life-liberty-and-the-pursuit-of-comboness-talk-roguelike-celebration-2024/)
- Super Auto Pets depth analysis — shop sequencing, composition synergies, triggers :
  [mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026](https://www.mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026)
- Irsen devlog — stacking status effects 2024, refreshing vs stacking, per-instance :
  [datchannin.itch.io/irsen/devlog/1473783/devblog-7-combat-effects](https://datchannin.itch.io/irsen/devlog/1473783/devblog-7-combat-effects)

**Sources internes (références actives, lecture seule) :**

- `00-state.md` §2.1 (roster 83 unités, répartition par famille) ; §3.1 (familles DoT,
  caps, boucliers) ; §3.3 (ciblage déterministe, depth) ; §8 (zones sans test)
- `ROADMAP-draft.md` v7 §3.1/§3.4/§3.5/§5.2 (audit 10-col, saturation, inter-famille)
- `round-06.md` §1.1-1.3 (#D, #W, tests inter-famille) ; §4 (litiges ouverts)
- `rounds/r06-synergies-effects.md` §2.3/§2.4 (bleed-4 tension, synergies adjacentes)
- `src/effects/ops.lua` (DOT_CAP_MULT=3, BLEED_DPS_CAP=12) — lu via 00-state
- `src/combat/arena.lua` (SHOCK_STACK_CAP=8, FATIGUE_START=1020) — lu via 00-state

**Sources rounds précédents conservées :**

- r06-synergies-effects.md §1.5 (bleed-4 tension documentée par ce round même)
- r05-synergies-effects.md §2.4 (gap tests inter-famille, origine de la correction)
- r04-synergies-effects.md §2.1 (axe D choc dans tickDots, pas hit())

---

## 8. Récapitulatif des demandes de modification de specs

| Item | Position ce round | Priorité | Où dans la roadmap |
|---|---|---|---|
| Étendre test 2 inter-famille (shield_caster actif) | **REQUIERT MODIFICATION** du lot de tests § 5.2 | HAUTE | précondition P1 |
| Ajouter note exception choc dans tableau de saturation | **REQUIERT ADDITION** doc §5.2 | HAUTE | précondition P1 |
| Ajouter `--pool-repr` avant `--poison-frac` | **REQUIERT ADDITION** §3.5 | HAUTE | P0.5 |
| CONFIG-CE latence choc early | option dans §3.4-bis | BASSE | P3 / doc |
| Note condition placement rot-tank dans col I | doc §3.1 | BASSE | P0.5 doc |

**Aucun litige nouveau ouvert ce round** — les désaccords §2.1/§2.2/§2.3 sont des
compléments de spec (tests, formules, mesures), pas des inversions de décision.
Les décisions #D et #W restent closes.

---

*Round 07 rédigé le 2026-06-23. Lecture seule du repo. N'édite que sous
`docs/roadmap-lab/`. Piliers respectés. 32 invariants préservés. Pas de litiges
inversés — compléments de spec critiques (test 2 étendu, cas dégénéré choc, mesure
de représentation). Recherches web sourcées : a327ex, TFT Inkborn/Magic Mayhem, PoE2,
Last Epoch, Roguelike Celebration 2024, SAP. Aucune modification du code ou des tests.*
