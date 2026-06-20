# The Pit — Décision : modèle de combat (vie, mort, ciblage, aggro)

> Décision actée **2026-06** après 4 recherches parallèles sourcées (Règle d'or : sources
> primaires + Exa, citées). Tranche une question structurelle : **vie par entité (les unités
> meurent) vs vie globale du joueur (entités immortelles)**, et la mécanique de ciblage/aggro.
> Document de décision ; l'archi moteur qui l'implémente vit dans `engine-architecture.md`.

---

## 1. La décision (verrouillée)

**Vie PAR ENTITÉ + ciblage 100% déterministe + exposition portée par le sigil + aggro câblée mais
inerte.** Concrètement :

1. **Vie par entité, mort par-combat.** Les unités ont des PV et meurent. Mais la mort est
   **par combat** : le build renaît chaque tour. L'**identité de build est protégée au niveau RUN**
   (5 vies / 10 victoires / vie rendue tour 3 — déjà au blueprint), **pas** au combat.
2. **Ciblage déterministe, zéro dé** (respecte l'invariant replay, cf. [[feedback-deterministic-replayable-combat]]) :
   `colonne avant (depth) → override taunt → aggro la plus haute → tie-break haut→bas (row) → slot`.
3. **L'exposition est portée par le sigil** : `depth = maxCol - cell.x` → chaque forme a son profil
   d'exposition. « La forme EST le graphe de synergies » devient « la forme EST aussi le champ de
   bataille ». Les deux axes de placement (synergie d'adjacence × exposition) **fusionnent en une
   seule décision** (choisir le sigil + y placer).
4. **Aggro = stat câblée mais INERTE** (toutes égales à 0). L'architecture (taunt + aggro dans la
   règle) existe dès maintenant ; on **n'équilibre les valeurs que quand les plateaux se remplissent**
   (9 slots) et que le placement seul ne suffit plus à protéger une carry.

**Rejeté : la vie globale (Bazaar/Backpack).** Raisons : (a) la **fiction** — « monstres immortels »
sonne faux pour des créatures qui descendent Le Puits (la fiction dicte la structure : objets→vie
globale, créatures→vie par entité) ; (b) elle **supprime l'axe d'exposition** (front/back, qui-tanke,
case-carry) qui est une de nos signatures ; (c) son seul vrai avantage — la facilité d'équilibrage —
est **déjà neutralisé par notre harnais de simulation**. On ne la code même pas pour l'A/B : on la
bâtirait pour la jeter.

---

## 2. La question & les 3 options

La valeur d'un autobattler vient de la profondeur. Deux familles réelles :
- **Vie par entité** (SAP, TFT, HS Battlegrounds) : unités avec PV, mort, système de ciblage.
- **Vie globale** (Backpack Battles, The Bazaar) : entités-objets immortelles qui tirent sur la
  barre de vie globale de l'adversaire. Pas de ciblage, pas de mort.

| Critère | A — Vie globale | B — Vie par entité + focus déterministe | **C — B + exposition-sigil (RETENU)** |
|---|---|---|---|
| Coût d'implémentation | **supprimer** `damage/alive/mort` (déjà codés) | **déjà construit**, reste à durcir le ciblage | B + `depth` dérivé de la forme (quasi gratuit) |
| Difficulté d'équilibrage | la plus basse *en théorie* | la plus haute *en théorie* (double axe) | moyenne — **mais on a le harnais de sim** → empirique |
| Profondeur | 1 axe (adjacence) | 2 axes (synergie × exposition) | 2 axes **fusionnés en 1 décision** |
| Frustration RNG | nulle, mais counterplay faible | **nulle** si déterministe | idem |
| Fiction (grimdark) | « immortels » sonne faux | « les monstres tombent » | idem |
| Async / replay | trivial | déjà garanti (seedé, testé) | idem |

**L'asymétrie qui tranche** : le seul avantage net de A (facilité d'équilibrage) est annulé par le
harnais. Les avantages de B/C (profondeur, counterplay, thème, signature spatiale) sont **structurels** :
une sim ne te donne pas un 2ᵉ axe, tu l'as ou pas. Et **on EST déjà en B** (`arena.lua` a hp/alive/mort).

---

## 3. Pourquoi le déterministe tue la peur du « focus RNG »

Peur initiale : « si l'adversaire focus ma carry, tout mon build s'effondre ». Réponses sourcées :
- La rage dans TFT/Underlords vient **uniquement des effets qui BYPASSENT la position** (assassins qui
  sautent l'arrière, snipes aléatoires), **jamais** du ciblage de proximité de base. HS Battlegrounds
  (défenseur **aléatoire**) = procès permanent en « c'est truqué ». **SAP** (100% déterministe
  front-vs-front) = **zéro** plainte de focus.
- Donc **front/back déterministe convertit « le dé m'a niqué » en « j'aurais dû scouter et
  contre-placer »** = du skill (yomi), pas du hasard. *Engagement data : aucun effet bypass-position
  sans contre positionnel.*
- La mort par-combat (pas permanente) fait qu'un mauvais matchup coûte **une vie sur cinq**, jamais le
  build (modèle SAP/TFT : le plateau persiste).

---

## 4. La règle de ciblage (implémentée — `arena.lua:chooseTarget`)

```
chooseTarget(attaquant a) :
  1. minDepth = depth le plus bas parmi les ennemis vivants     # colonne AVANT
     (depth = maxCol - cell.x ; dérivé de la forme du sigil)
  2. candidats = ennemis vivants à depth == minDepth            # on avance qu'une fois la colonne vidée
  3. si un candidat a taunt -> candidats = {taunteurs}           # override DUR (rare, via reliques)
  4. cible = max aggro parmi candidats                           # tri DOUX
     tie-break : row min (haut->bas), puis slot                  # ordre fixe, zéro dé
```
**Fonction pure de l'état → mirror-safe, rejouable à l'octet.** `depth` vient de la géométrie de la
forme (carré = 3 colonnes de 3 ; ligne = 9 en file ; croix/diamant = profils étalés) : **le sigil
porte l'exposition gratuitement**.

---

## 5. L'aggro à deux couches (modèle MMO/tactics)

- **Couche douce = la stat `aggro`** (déterministe : aggro la plus haute ciblée). C'est le **dial
  quotidien** et le **pont** : les synergies d'adjacence / reliques / sigils peuvent la modifier
  (un porte-étendard donne +aggro à ses voisins ; une carry furtive en −aggro à l'arrière) → les
  deux axes de placement deviennent **un seul système interconnecté**. Précédents : Honkai Star Rail
  (stat aggro + taunt override), Xenoblade 3 (accessoires +aggro), VisuStella (Provoke+Taunt+Aggro).
- **Couche dure = le flag `taunt`** (override « doit me cibler »). **Rare et conditionnel** (relique,
  archétype de sigil), jamais une stat de base sur chaque tank. Modèle Hearthstone Taunt / Darkest
  Dungeon Guard (restriction de cible), **pas** le « match-top+1 » MMO (pas de compteur de menace live).
- **Décision** : taunt **re-trie DANS la colonne** atteignable, il ne **casse pas** l'ordre front/back
  (préserve l'invariant async). Un vrai « saut de ligne » serait une relique rare (façon assassin TFT).

**Principe d'équilibrage d'or** : l'aggro **redistribue *qui* encaisse, jamais *combien* au total**
(même esprit que « échanger une topologie, pas de la puissance »). Contres à livrer dès le jour 1 :
AoE/colonne qui ignore le guard, relique qui strip l'aggro, furtivité. Pièges à éviter (sondés par le
harnais) : mur max-aggro indéboulonnable, aggro-taxe obligatoire, aggro inerte (combats trop courts).

---

## 6. Déjà codé (v0.4) vs différé

**Fait & validé** : `chooseTarget` déterministe (colonne→taunt→aggro→tie-break) remplace l'ancien
`nearestEnemy` euclidien ; `depth`/`row`/`aggro`/`taunt` threadés dans les specs ; exposition dérivée
de la forme ; **test des 4 couches** (`tests/headless.lua`) ; golden rebaseliné ; 216 combats fuzz +
invariants OK ; sim d'équilibrage saine (σ 0,042, entropie 0,999) ; boot LÖVE OK.

**Différé (YAGNI, l'archi est prête)** : valeurs d'aggro non nulles + archétype tank ; reliques de
taunt ; passifs de ligne (façade = armure / arrière = attaque) ; relique rare « saut de ligne » ;
contres (AoE/strip/furtivité). À brancher quand les plateaux se remplissent et que le placement seul
ne protège plus les carries.

---

## 7. Sources clés (par les 4 agents, via Exa)

- **Vie globale** : Backpack Battles (https://backpackbattles.wiki.gg/wiki/Game_Mechanics ,
  https://backpackbattles.wiki.gg/wiki/Weapon) ; The Bazaar (https://thebazaar.wiki.gg/wiki/Poison ,
  https://mobalytics.gg/the-bazaar/guides/keywords-and-terms) ; anti-stall Fatigue/Sandstorm.
- **Vie par entité + ciblage** : SAP (https://superautopets.wiki.gg/wiki/The_Basics — front-vs-front
  déterministe, mort par-combat, 5 vies/10 trophées) ; TFT positioning + NPE assassins
  (https://tft.ninja/guides/positioning/basics) ; HS Battlegrounds défenseur aléatoire = distrust.
- **Décision** : « on est déjà en B » (audit `arena.lua`) ; sigil-exposition ; identité au run-layer
  (https://en.wikipedia.org/wiki/Super_Auto_Pets) ; déterminisme = yomi pas RNG.
- **Aggro/threat** : tables de menace WoW/FFXIV/EQ ; Hearthstone Taunt (hard) ; Darkest Dungeon
  Mark(soft)/Guard(hard) (https://darkestdungeon.fandom.com/wiki/Guard) ; aggro-stat précédents :
  Honkai Star Rail (https://honkai-star-rail.fandom.com/wiki/Aggro), Xenoblade 3
  (https://www.xenoserieswiki.org/wiki/Aggro_(XC3)), VisuStella (https://yanfly.moe/wiki/Aggro_Control_System_VisuStella_MZ).

Voir aussi : `engine-architecture.md`, `gd-research-result.md`.
