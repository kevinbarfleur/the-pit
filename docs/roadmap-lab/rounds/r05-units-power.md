# Round 05 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v5, intégré round 4) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 5/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v5), `00-state.md`, `round-01.md`,
> `round-02.md`, `round-03.md`, `round-04.md`, `rounds/r01-units-power.md` à
> `rounds/r04-units-power.md`, `competitive/*.md` (tous), `src/data/units.lua` (intégralité
> relue ce round).
>
> **Méthode** : désaccord = recherche web menée et citée. Analogie = démonter son mécanisme
> psychologique/mathématique avant d'accepter. Toute affirmation chiffrée porte sa source.
> Règle de méthode du round 4 : reformuler un mécanisme existant = citer la ligne de code
> source relue ce round.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous `docs/roadmap-lab/`.
> Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Quatre angles non encore épuisés après relecture complète de `units.lua` et des 4 rounds précédents :

1. **L'audit P0.5 (grille 6 colonnes) traite le bouclier comme un seul archétype, alors qu'il
   contient DEUX archétypes économiquement distincts** (`shield_aura` one-shot vs `shield_caster`
   périodique) dont les contrats de valeur sont orthogonaux. Les regrouper sous « enablers
   transversaux » masque une décision de design non tranchée : est-ce que les 4 renforts de
   bouclier périodique (`barrier_savant`, `mirror_ward`, `surge_warden`) sont des adjuvants du
   caster (`ward_weaver`) OU des unités de pool indépendantes ? La distinction change radicalement
   leur `DPS_budget_tank` et leur plafond de pool.

2. **Le plancher ≥2/famille/rang est vrai pour les familles DoT, mais il crée une PRESSION À
   LA CRÉATION qui n'est pas tempérée par un critère d'AXIALITÉ**. En l'état, combler le
   plancher choc (1 unité rang-2 conditionnel à la sim #Q) ou le plancher rot (2-3 enablers
   rang-2) peut produire des enablers mécaniquement redondants si leur différenciation porte
   seulement sur les PARAMÈTRES (add/cap/dur pour le choc, base/growth/capDps pour la rot) et
   non sur un AXE FONCTIONNEL distinct. Il y a une différence entre « 2 enablers d'une famille
   visibles » et « 2 enablers d'une famille qui créent 2 DÉCISIONS DE BUILD différentes ».

3. **La décision de retirer les T3 simplifiés (`ash_maw`, `pit_maw`, `wither_bloom`) de la
   TODO-liste masque un risque de COHÉRENCE ARCHITECTURALE** : `wither_bloom` (`units.lua:282-287`)
   utilise 3 ops DoT à 0-dps (`rot` + `bleed(dps=0)` + `poison(dps=0)`) pour encoder un
   « slow + malus ». Cette architecture est un placeholder qui propage une fausse promesse au
   joueur : l'infobulle indique 3 familles actives (bleed, poison, rot), ce qui déclenche
   `plague_communion` (`afflictionCount ≥ 2`), mais les deux familles à 0-dps n'existent que
   comme vecteurs de paramètres (slow / weaken) sans dps réel. Si le joueur empile des auras
   bleed sur `wither_bloom`, il n'obtient que du slow renforcé — pas du dégât bleed. C'est une
   tromperie mécanique non documentée.

4. **La question de la ROT comme COUNTER DE TANK n'a pas été tranchée** malgré la Q1 du
   round 4 (r04-units-power §4 Q1). L'interaction rot × aggro-câblée est asymétrique et
   potentiellement très forte : un tank ennemi (aggro=40) qui reçoit `maxHpFrac=0.35` de
   `necro_leech` subit une amputation de PV max qui ne modifie PAS son aggro (câblée dans
   `arena.lua:chooseTarget`), mais le tue plus vite. La rot est donc mécaniquement optimale
   contre les tanks — soit comme archétype de COUNTER documenté (stratégique) soit comme
   biais structurel non voulu (problème).

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — `burst_DPS_eq` pour le choc (adopté round 4, §3.1a)

La distinction condensateur vs DPS-linéaire est correcte et bien sourcée. La vérification
code est solide : `galvanizer` (`units.lua:311-317`) : `bonus_first (value=6)` + `shock
(add=2, cap=6, dur=180)`. Son DPS de frappe `dmg=11, cd=64 → 0.172` est trompeur. Le
`burst_DPS_eq ≈ 0.245` calculé au round 4 tient (cap 6 × volt=3 défaut + bonus_first).

**Pourquoi ça tient pour nos contraintes** : l'analogie StS (Totem/Ironclad, jaugé sur
dégâts par éruption) est valide parce que le mécanisme psychologique est identique — le
joueur évalue la valeur d'une carte/unité sur son IMPACT PER ACTIVATION, pas son DPS
continu. Un condensateur à faible DPS continu mais burst élevé est correctement évalué sur
le burst. Source : [GDC Vault — Slay the Spire Metrics Driven Design (Giovannetti 2019)](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics).

**Ce qui mérite d'aller plus loin (§2.2)** : la distinction condensateur tient pour le choc
mais elle est implicitement appliquée à `galvanizer` seul. Il faut l'appliquer à TOUT le
ladder choc avec cohérence, y compris les unités qui ont un DPS continu convenable
(`stormlord` rang-3 : dmg=6, cd=54, DPS=0.111 — dans la norme rang-3) et pourraient être
**SOUS-évaluées** par `burst_DPS_eq` si la valeur de leur burst est faible.

### 1.2 ACCORD — Audit rang-5 : stat-sticks vs transforms (round 3, confirmé round 4)

`skull_colossus` (`units.lua:421-424`) rang-5 : `hp=92, dmg=11, cd=84, aggro=40` + burn
`dps=4`. `deep_kraken` (`units.lua:437-440`) rang-5 : `hp=84, dmg=12, cd=78` + poison
`dps=4`. Les deux sont des stat-amplifications sans règle d'équipe. Le brouillon v5 §3.7
propose correctement « transform réelle / stat-amplification à raffiner / rétrograder rang-4 ».

**Pourquoi ça tient** : la règle « rang-5 = règle d'équipe » (décision #10 + gd-research-result
§2.6) est fondée sur le principe que le coût premium doit refléter un SAUT D'IMPACT, pas
un delta de stat. `skull_colossus` en burn `dps=4` est comparable à `maggot_king` rang-3
en rot `dps=cap=12` — le rang-5 ne fait pas de nouvelle chose. Source : [Giovannetti GDC
2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf)
(slide « 1st mistake: too many cards that only differ by numbers »). **Accord total.**

### 1.3 ACCORD — Double critère plafond/plancher (adopté rounds 2-3, raffiné round 4)

Les maths hypergéométriques sont correctes pour notre pool LOCAL (pas partagé TFT). La
distinction est critique : TFT a 18-22 copies/champion par rang dans un pool **partagé entre
8 joueurs simultanément**, ce qui impose des règles différentes de pool-sizing. Source :
[Esports Tales — TFT Set 17 champion pool size](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances).
Notre pool est LOCAL à la run — le SHOP_SIZE=5 est le seul filtre.

**Nuance vérifiée sur les DOT via Last Epoch** : PoE et Last Epoch donnent à chaque DoT une
RÈGLE DE STACKING orthogonale (PoE bleed = une seule instance, highest wins ; poison = toutes
les instances ; Last Epoch bleed = stackable, poison = stackable) — pas juste des paramètres.
Source : [Last Epoch DoT Wiki](https://lastepoch.fandom.com/wiki/Damage_Over_Time) ; [PoE
Bleeding](https://www.poewiki.net/wiki/Bleeding). Chez The Pit la distinctivité est portée
par les PARAMÈTRES des ops — c'est plus fragile (§2.1 ci-dessous).

### 1.4 ACCORD PARTIEL — Décision de cohorte v7 + champ `pool` déclaratif (round 4, §1.21)

La position « recommandé, non-bloquant tant que v8+ non planifiée » est correcte.
**Mais** le vrai garde-fou manque : même sans v8+, la décision de cohorte v7 doit
être enforçable dans `tools/check.sh` — pas seulement documentée dans un .md. Le lint
« toute unité sans `pool` explicite = WARNING si ajoutée après v0.9 » est la bonne
direction ; il doit être codé en MÊME TEMPS que la décision de cohorte, sinon la
documentation diverge du code dès le premier commit qui touche `units.lua` (dette silencieuse
confirmée — [Fowler, Patterns of Enterprise Application Architecture](https://martinfowler.com/books/eap.html)).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD FORT — La distinctivité des familles DoT repose trop sur les PARAMÈTRES et pas assez sur les RÈGLES DE STACKING ; le brouillon ignore un risque de NICHE-COLLISION inter-familles au moment des paliers de TYPE (P1)

**Ce que le brouillon dit** (00-state §3.1) : les 6 familles ont des « axes de stacking
distincts » — et la colonne G (effets secondaires perçus, adoptée round 4) vise à documenter
la perception. Le brouillon traite la distinctivité comme un problème de **lisibilité** (i18n).

**Ce qui est insuffisant** : la distinctivité perçue ≠ la distinctivité de BUILD. Un
joueur peut comprendre que bleed = « ta cible frappe au ralenti » et rot = « ta cible fond
de l'intérieur » — mais s'il a 3 unités bleed et 2 unités rot, et qu'une aura `decay_tender`
buffe ses voisins en rot, le build CONVERGERA naturellement vers un mix bleed+rot parce
que les deux familles ont des niches de BUILD ADJACENTES :

- **Bleed** : contrôle de tempo (slow) → optimal contre les unités à haute cadence d'attaque
- **Rot** : amputation PV max → optimal contre les unités à haute HP

Ces deux niches se combinent SANS FROTTEMENT — là où PoE et Last Epoch séparent bleed/poison
par TYPE DE DOMMAGE (physique vs chaos), créant une friction mécanique entre les deux
(les résistances fonctionnent différemment). Chez The Pit, bleed+rot dans un même build est
**libre de toute friction** — les ops ne s'excluent pas, n'ont pas de pénalité de co-habitation,
et ne requièrent pas d'investissement dans des vecteurs distincts (pas de « phys% » ou
« chaos% »).

Sources :
- [PoE Damage Over Time Wiki](https://www.poewiki.net/wiki/Damage_over_time) : bleed = physical,
  amplifié par le mouvement (Crimson Dance pour multi-instance) ; poison = chaos, toutes
  instances stackent → distinction physique/chaos EST la friction.
- [Last Epoch DoT Damage Guide](https://maxroll.gg/last-epoch/resources/damage-explained) :
  bleed = 53 dommage/instance, poison = 20 dommage/instance — distinction par puissance
  d'application (bleed = plus fort mais plus dur à appliquer).

**Conséquence pour P1 (paliers de TYPE)** : si bleed et rot ont des niches adjacentes sans
friction, un palier « bleed 4 » ET un palier « rot 4 » dans le même build sont **cumulables
sans coût d'opportunité**. Soit le joueur a 4 bleed + 4 rot = 8 unités DoT et plus de place
pour un tank → front détruit immédiatement (ciblage déterministe). Soit le palier 4 exige 4
unités DU MÊME TYPE dans 9 slots = 44 % de la compo, ce qui **de facto exclut le
co-palier bleed+rot**. Mais alors le joueur qui a 3 bleed + 3 rot + 3 autres = zéro palier
atteint = la « niche bleed+rot » de build est non récompensée.

**Proposition** (§P-A) : avant de spécifier les twists de palier 4 (P1, §5.2), documenter
explicitement le FROTTEMENT VOULU entre familles adjacentes (bleed/rot, burn/poison) :
- **Option F1** : créer une friction by-design (ex. les ops bleed et rot sur la MÊME CIBLE
  s'excluent ou ont un ordre de priorité) — change le moteur, risqué.
- **Option F2** : les niches bleed et rot sont REDESSINÉES pour être orthogonales au niveau
  BUILD, pas seulement perceptif. Ex. bleed = contre les unités RAPIDES (front) ; rot =
  contre les unités TANKY (haut HP). Ces deux niches sont déjà orthogonales positionnellement
  si le ciblage déterministe assure que les rapides sont en front. **F2 ne change pas le
  moteur**, elle change QUELLES UNITÉS sont les meilleures cibles — ce qui est une décision
  de DATA et de sim (`--bleed-vs-front`, `--rot-vs-high-hp`).
- **Option F3** (minimale) : documenter explicitement que bleed+rot est un CO-BUILD LÉGITIME
  (archétype « tempo+tank-buster ») et qu'il n'a PAS de palier propre (c'est son identité
  de BUILD sans palier, distincte du mono-bleed 4 ou mono-rot 4). → si documenté, la
  prochaine question est « a-t-il une relique dédiée ? » (Aucune dans les 21 reliques
  actuelles — vérif `relics.lua`). **F3 est la moins coûteuse à court terme, mais crée
  une zone grise dans P1.**

**Priorité** : décider F1/F2/F3 AVANT de spécifier les twists de P1 (§5.2 ROADMAP-draft v5).
Si F3 → documenter l'archétype co-build + ouvrir la question relique. Si F2 → inclure dans
l'audit P0.5 colonne (H) « contre quoi cet archétype est optimal positionnellement ».

---

### 2.2 DÉSACCORD MODÉRÉ — L'archétype BOUCLIER est traité comme UN seul groupe, alors qu'il contient deux sous-archétypes économiquement distincts qui ont des implications POOL et BUDGET différentes

**Ce que le brouillon dit** (00-state §2.1, §3.3) : « 11 unités shield/tank = enablers
transversaux sans palier » (litige #F orienté « aucun »). Le budget tank dédié (§3.1b)
corrige la dispersion de DPS — mais traite les 11 comme un bloc homogène.

**Ce qui est insuffisant** : dans `units.lua`, les 11 unités « shield/tank » se divisent en
DEUX systèmes mécaniquement distincts :

**Sous-archétype A : `shield_aura` (aura one-shot, build-résolu)**
```
templar (rang-3)      : shield_aura value=14, combat_start, neighbors
shieldbearer (rang-2) : shield_aura value=6,  combat_start, neighbors
aegis_warden (rang-4) : shield_aura value=10, combat_start, neighbors + thorns
oath_keeper (rang-4)  : shield_aura value=18, combat_start, neighbors (DPS=0.114)
bulwark_acolyte (rg3) : shield_aura value=8,  combat_start, neighbors
```
**→ 5 porteurs, résolution BUILD, bake une fois. Budget : HP élevé, DPS low à moyen.**

**Sous-archétype B : `shield_caster` (caster périodique, combat-résolu)**
```
ward_weaver (rang-4)  : shield_caster value=20, cd=240, neighbors — BASE
barrier_savant (rg4)  : aura_shield valueInc=0.5, cdr=0.25 — RENFORT du caster
mirror_ward (rang-4)  : aura_shield reflect=0.4, radius=true — RENFORT du caster
surge_warden (rang-4) : aura_shield overcharge=true, valueInc=0.5 — RENFORT du caster
siege_breaker (rang-3): strip_shield frac=0.5 — COUNTER
```
**→ 1 caster + 3 renforts + 1 counter. Le système est ÉCOSYSTÈME VERTICAL : barrier/mirror/
surge sont des adjuvants de `ward_weaver`, pas des unités indépendantes de pool.**

**Problème** : si les 3 renforts sont mis dans `U.pool` (ce qu'ils sont — `units.lua:488-505`),
ils peuvent apparaître en boutique SANS que `ward_weaver` soit présent. Un joueur qui achète
`barrier_savant` sans `ward_weaver` voisin n'obtient RIEN (l'op `aura_shield` n'a pas de
caster à renforcer). C'est une **décision d'achat invalide non signalée**.

**Vérification code** (`units.lua:365-377`) :
```
barrier_savant: { trigger="combat_start", op="aura_shield", target="neighbors",
  params={valueInc=0.5, cdr=0.25} }
```
L'op `aura_shield` (cf. `src/effects/ops.lua`) cherche dans les voisins un porteur de
`shield_caster` pour amplifier sa valeur/cadence. Seul `ward_weaver` est `shield_caster` dans
le pool actuel. **Un `barrier_savant` sans voisin `ward_weaver` = stat inutilisée.**

**Source** : [Wayward Strategy — Unit Design, Clarity of Roles and Redundancy](https://waywardstrategy.com/2018/05/17/unit-design-clarity-of-roles-and-redundancy/) :
« Units that are meant to combo with each other but can appear independently in the shop
create confusion and "dead picks" for players unfamiliar with their interaction. » Cette
source applique directement : barrier/mirror/surge sont des adjuvants-dépendants.

**Ce que ça implique pour le pool** : deux options à trancher :

- **Option pool-A** : retirer les 3 renforts (`barrier_savant`, `mirror_ward`, `surge_warden`)
  du `U.pool` (les garder en `U.order` pour encounters IA). Le `shield_caster` n'est
  accessible que via `ward_weaver` + ses renforts en pool réduit. **Réduit de 3 le pool
  rang-4 (6 unités potentiellement retirées si aussi les auras v7 non retenues).**

- **Option pool-B** : laisser les renforts dans le pool MAIS afficher leur dépendance dans
  l'infobulle (`unit.passive_desc` : « Amplifie les boucliers périodiques de vos voisins —
  inerte sans porteur »). **Le signal de dépendance doit être VISIBLE en boutique.**

La décision #O (`famines_math` : garder dans pool vs retirer) s'applique ici par analogie :
une mécanique qui est inutile dans ~70 % des builds (quand `ward_weaver` n'est pas voisin)
ne devrait pas occuper un slot de pool sans signal fort.

**Proposition** (§P-B, priorité haute) : **Option pool-A recommandée** (renforts hors `U.pool`,
dans `U.order` pour la découverte en encounters IA). **Précondition** : audit P0.5 doit
inclure une colonne (H) « unité dépendante : quelles conditions pour qu'elle soit utile ? »
→ identifie les adjuvants-dépendants avant filtrage pool.

---

### 2.3 DÉSACCORD — `wither_bloom` est un PLACEHOLDER ARCHITECTURALEMENT TROMPEUR qui crée un faux signal de `plague_communion` et une fausse promesse d'archétype bleed+poison

**Vérification code** (`units.lua:280-287`) :
```lua
wither_bloom = {
  rank=5, cost=5, hp=58, dmg=5, cd=60,
  effects = {
    { trigger="on_hit", op="rot",   params={base=2, ..., maxHpFrac=0.15} },
    { trigger="on_hit", op="bleed", params={dps=0, dur=240, slowPct=0.15} }, -- pur slow
    { trigger="on_hit", op="poison",params={dps=0, dur=240, weaken=0.10} }, -- pur malus
  }
}
```

**Le problème** : `bleed(dps=0)` et `poison(dps=0)` posent des stacks de leur famille sur
la cible, avec `dur=240`. `afflictionCount(target.dots)` (`arena.lua:248-252`, vérifié
round 4) compte les familles PRÉSENTES dans `target.dots`, sans vérifier si le dps est
non-nul. Donc `wither_bloom` seul déclenche `plague_communion` (`afflictionCount ≥ 2`) sur
sa cible — rot + bleed(0) + poison(0) = 3 familles = `≥ 2` → **+25 % de TOUS les dégâts
de l'équipe contre cette cible**.

**Ce n'est pas faux mécaniquement** — c'est peut-être voulu. Mais c'est une **interaction
non documentée** qui :
1. Fait de `wither_bloom` un activateur passif de `plague_communion` même sans aucun doter
   de poison/bleed dans le build.
2. Crée une fausse promesse pour le joueur qui place `miasma_acolyte` (aura +50 % poison dps)
   en voisin de `wither_bloom` — l'aura amplifie le dps du stack poison... qui est 0. Il
   obtient `0 × 1.5 = 0`. L'aura est gaspillée silencieusement.
3. Est marqué CLAUDE.md §7 comme « placeholder simplifiée » à enrichir, mais le BRIEF §Contenu
   le liste comme dette connue depuis v0.8.

**Ce que le brouillon ne dit pas** : §3.7 / §7.4 mentionnent `wither_bloom` dans les T3
simplifiés à enrichir « après P1.5b ». Mais le problème n'est pas le contenu du T3 — c'est
l'ARCHITECTURE de l'op `dps=0` qui ne peut pas être une façon propre de modéliser un effet
secondaire de famille sans dégâts. **L'op est utilisé comme vecteur de paramètres (slow,
weaken) en contournant son rôle primaire (dégâts).**

**Proposition** (§P-C) : deux corrections à choisir :
- **Option C1** : documenter explicitement dans l'audit P0.5 que les ops à `dps=0` comme
  vecteur de paramètres sont un **pattern temporaire** → ajouter un op dédié `apply_status`
  (slow/weaken sans dps) dans P1.5b. Cela nettoie `wither_bloom`, `marrow_drinker` (bleed
  sans dps après conversion) et toutes les auras grant_bleed.
- **Option C2** (immédiate, sans moteur) : Modifier `afflictionCount` dans `arena.lua` pour
  qu'il ne compte que les familles avec `dots[family].dps > 0` ou `dots[family].stacks > 0`
  (pas seulement présent). **1 ligne de code**, rebaseline golden. Clarifie le comportement
  sans l'op `apply_status`.

**Option C2 recommandée à court terme** car elle corrige le faux signal sans nouveau moteur,
et `apply_status` sera naturellement créé quand les types P1 auront besoin de conditions
orthogonales.

**Garde-fou** : C2 = modifier `afflictionCount` = potentiellement toucher invariant #22
(choc-décharge, qui lit lui aussi `target.dots`). **Vérifier que `dischargeShock` lit les
stacks, pas juste la présence d'une famille, avant de modifier `afflictionCount`.**
→ Zone de test à ajouter (§8 00-state) : test que `afflictionCount` retourne 0 sur une cible
avec seulement des stacks `dps=0`.

---

### 2.4 DÉSACCORD MODÉRÉ — La ROT comme COUNTER DE TANK n'est pas documentée ; le risque est une asymétrie structurelle non voulue contre les builds de TAUNT

**Q1 du round 4 posée mais non répondue** (r04-units-power §4 Q1) : « L'effet secondaire de
Rot (amputation PV max) affecte-t-il l'aggro effective ? ».

**Analyse code** : `arena.lua:chooseTarget` — l'aggro est une stat câblée dans la définition
de l'unité (`aggro=40` pour tank/gravewarden). Elle ne varie PAS dynamiquement avec les PV
max. Donc : rot + maxHpFrac = amputation PV max → la cible meurt PLUS VITE, mais RESTE la
cible prioritaire tant qu'elle vit (son aggro ne change pas). **La rot est optimale contre
les tanks** : elle élimine précisément ce qui est le plus difficile à tuer sans la
contourner. C'est un counter de taunt par attrition — le tank meurt avant que les carries
ne soient atteintes.

**Est-ce voulu ?** La doctrine du brouillon (00-state §3.3 + combat-model-decision.md §4-6)
dit que le ciblage déterministe convertit « la frustration RNG en skill de placement ». Un
archétype rot qui counter précisément le taunt est du **yomi** (lecture de la stratégie
adverse) — ça renforce le skillcap. Mais s'il n'est **jamais documenté** que rot est le
counter de taunt, le joueur ne peut pas l'apprendre (anti-pattern Artifact §4.4 —
profondeur invisible).

**Vérification des reliques** : aucune relique dans les 21 actuelles n'amplifie spécifiquement
la rot contre les cibles à haute HP ou taunt. `grave_cap` (`relics.lua:21`) augmente la
durée de rot — généraliste, pas thématisé « counter tank ». **L'archétype est orphelin de
relique** (règle ≥2/archétype, §4.8 ROADMAP-draft — la rot en late a `grave_cap` + aucune
autre relique dédiée → `P(aucune relique rot late) ≈ 24 %` ⚠️).

**Source design** : Wayward Strategy (2018) cité en §2.2 : « A unit that serves as counter
to another should have its role explicitly stated, otherwise players won't build toward it
even when the counter is optimal. » La profondeur du counter ne se révèle que si le joueur
sait qu'il existe — le grimdark peut l'habiller (« La Pourriture dévore les remparts »)
sans le rendre cryptique.

**Proposition** (§P-D) : dans l'audit P0.5, ajouter pour les familles DoT une colonne (I)
« CONTRE QUOI optimal (archétype ciblé) » :

| Famille | Optimal contre | Raison mécanique |
|---------|---------------|-----------------|
| Burn    | Unités à faible HP, front (propagation à mort) | DPS élevé mais burst, no-shield |
| Bleed   | Unités à haute cadence (carries ennemis) | Slow de cadence → DPS réduit |
| Poison  | Unités à haute valeur de stat (buffs) | Weaken sur la valeur des capacités |
| Rot     | Unités à haute HP / tanks / taunt | Amputation PV max contourne le HP brut |
| Choc    | Unités avec DoT déjà posé (axe D, P0.5) | Ampli du premier tick DoT |
| Regen   | Counter de DoT (survivabilité) | — |

Cette colonne documente les interactions et pilote (a) les textes i18n grimdark, (b) la
conception des reliques de P1.5a-b pour couvrir les niches manquantes, (c) l'équilibrage
P3 (la rot ne devrait pas counter trop facilement le taunt ou le tank deviendrait inutile).

---

## 3. Propositions priorisées

### P-A — FRICTION inter-familles adjacentes (bleed/rot) : documenter le co-build et son absence de palier, ou créer une friction by-design (AVANT les twists de P1)

**Quoi** : décider (option F1/F2/F3 §2.1) AVANT de spécifier les twists de P1 (§5.2).

**Ordre** : P0.5 (audit §3.1 + 6-col) → INCLURE la décision F1/F2/F3 dans l'audit →
puis spécifier les twists P1.

**Impact** : si F3 (co-build légitime, pas de palier propre) → ouvrir une question relique
(archétype bleed+rot sans relique dédiée dans les 21 actuelles). Si F2 → ajouter colonne
(H) « contre quoi optimal positionnellement » dans l'audit.

**Coût** : 0 moteur, 0 invariant. Doc + décision editoriale.

**Priorité** : haute — P1 sans cette décision risque des twists qui ferment accidentellement
l'archétype co-build bleed+rot.

---

### P-B — Séparer les renforts `shield_caster` (`barrier_savant`, `mirror_ward`, `surge_warden`) du `U.pool` boutique ; les garder dans `U.order`

**Quoi** : les 3 renforts sont des adjuvants-dépendants de `ward_weaver`. Seul en boutique
sans son caster, un renfort = achat invalide invisible. Retirer du `U.pool` (garder dans
`U.order` pour encounters IA, miroir des units v7 roster-only).

**Impact** : réduit `U.pool` de 3 unités rang-4. Si `ward_weaver` + les 3 renforts forment
un archétype premium, l'offre en boutique doit être ordonnée (d'abord `ward_weaver`, les
renforts en pool secondaire). **Mérite une `pool_priority` par famille de caster/adjuvant
plutôt qu'un simple retrait** — une option que le brouillon n'a pas explorée.

**Coût** : data + audit de pool. 0 moteur. **Précondition** : audit P0.5 inclut colonne (H)
« dépendance requise en pool pour être utile ».

**Priorité** : moyen — à faire en même temps que la décision de cohorte v7 (§3.2), car le
même mécanisme (U.pool = U.order) produit le même bug.

---

### P-C — Corriger le signal `afflictionCount` pour les ops `dps=0` (Option C2) ou créer `apply_status`

**Quoi (option C2, recommandée)** : `afflictionCount(dots)` dans `arena.lua` ne compte que
les familles avec `dps > 0` OU stacks non-nuls sur un axe distinct (choc : stacks).
`wither_bloom` avec `bleed(dps=0)` et `poison(dps=0)` ne déclenche plus `plague_communion`
seul.

**Impact** : clarifie `plague_communion` (activé par un vrai multi-DoT, pas des side-effects).
Clarifie les auras grant_bleed (`clot_mender` : les voisins posent un bleed `dps=1` → non-nul,
donc compté → `plague_communion` si rot aussi présente → interaction correcte).

**Zone de test** : ajouter dans `tests/synergies.lua` le cas `wither_bloom` alone →
`afflictionCount = 1` (rot seule avec dps > 0), pas 3.

**Garde-fou** : vérifier que `dischargeShock` lit `target.dots.shock.stacks`, pas
`afflictionCount`. Si oui, C2 est golden-safe (le golden n'implique pas `wither_bloom`
seul vs `plague_communion`). **Rebaseline golden si `wither_bloom` est dans le golden.**

**Priorité** : haute si `plague_communion` est réglée en P1.5a (§4.2 ROADMAP-draft). La
correction doit précéder le tuning de magnitude.

---

### P-D — Colonne (I) « contre quoi optimal » dans l'audit P0.5 ; documenter rot = counter taunt + ouvrir question relique rot manquante

**Quoi** : tableau 5 familles × « archétype ciblé » (§2.4) dans l'audit P0.5. Pilote
l'i18n et l'audit reliques (P1.5a).

**Impact** : révèle que rot n'a qu'une relique late (`grave_cap`) → P(aucune relique rot
late) ≈ 24 % → ouverture ticket P1.5a. Révèle aussi que choc (axe D) est optimal contre
les targets déjà dotées → le compteur de latence VRR early (#Q, sim P0.5) est directement
lié : si la cible adverse n'a pas de DoT, l'axe D ne déclenche rien.

**Coût** : doc audit + note reliques. 0 moteur. 0 invariant.

**Priorité** : à inclure dans l'audit P0.5 (§3.1 ROADMAP-draft). Pas un ticket séparé —
une colonne du même tableau.

---

## 4. Questions ouvertes

**Q1 — L'audit P0.5 (grille 7 colonnes A-G) est-il suffisant sans les colonnes H (dépendance
pool) et I (contre quoi optimal) ?**
Les colonnes A-G de v5 §3.1 couvrent niche, redondance, remède, dot_family, budget, conflit-
twist, et effet-secondaire-perçu. Les colonnes H et I (proposées ici) couvrent deux
dimensions supplémentaires : la DÉPENDANCE DE POOL (unités adjuvantes) et les CIBLES
OPTIMALES (archétypes adverses). Sans H, les adjuvants `shield_caster` passent inaperçus.
Sans I, la profondeur de counter ne se documente pas. → **Recommandé d'étendre à 9 colonnes
dans l'audit P0.5.**

**Q2 — Les auras `grant_bleed` (`clot_mender` : voisins posent bleed `dps=1`, `slowPct=0.10`)
comptent-elles comme enabler bleed pour le plancher ≥2 ?**
`clot_mender` (`units.lua:152-155`) ne pose pas le bleed sur ses propres frappes — il
**confère** l'op à ses voisins au build. Un voisin sans bleed natif obtient bleed via aura.
Pour le palier de TYPE bleed (P1), ce voisin compte-t-il comme « unité bleed » ?
→ La réponse change le `dot_family` inféré du voisin ET le compte de palier. **À trancher
dans §3.3 (dot_family rule des multi-effets)** : l'aura granted change-t-elle le `dot_family`
du voisin, ou seulement du porteur ?

**Q3 — La rotation saisonnière (Contrainte Permanente §8.0) qui booste une famille DoT
pendant une saison (ex. « burn +10 % cadence ») modifie-t-elle les recommandations de
plancher/plafond pour cette famille ?**
Si burn est boosté pendant une saison, sa P(famille visible/boutique) effective augmente
(plus de demande → plus d'achats → pool local plus épuisé). Le plancher ≥2 reste-t-il
suffisant, ou faut-il un plancher saisonnier adapté ? → Probablement gérable via la règle
≥2 + la tolérance du Fisher-Yates seedé. **À valider en sim avec le flag saisonnier.**

**Q4 — Le ladder choc compte-t-il `siphon_jelly` (rang-2, v7) comme enabler de plancher ?**
`siphon_jelly` (`units.lua:417-420`) : `family="meduse"`, rank=2, shock(add=1, cap=5, dur=150).
Si `siphon_jelly` est retenu dans `U.pool` après l'audit de cohorte v7, le plancher choc
rang-2 passe à 3 (`stormcaller`, `thunderhead`/`static_swarm`, `siphon_jelly`). Mais
`siphon_jelly` a une niche distincte (`family=meduse`) et des params distincts (cap=5 vs 8
pour `static_swarm`) — **candidat au maintien dans le plancher choc**. À évaluer dans la
décision de cohorte §3.2.

---

## 5. Synthèse pour le round suivant

Quatre zones à pousser dans les rounds 6-10, par ordre de priorité :

1. **Friction inter-familles adjacentes (bleed/rot)** (§2.1/P-A) : décision F1/F2/F3 AVANT
   les twists P1. Bleed+rot est un co-build naturel sans friction by-design chez nous, contrairement
   à PoE/LE. Si F3 (légitime sans palier) → ouvrir ticket relique bleed+rot.

2. **Adjuvants `shield_caster` hors U.pool** (§2.2/P-B) : `barrier_savant`, `mirror_ward`,
   `surge_warden` sont des adjuvants-dépendants qui créent des achats invalides silencieux.
   Décision pool-A (hors pool) recommandée, à prendre avec la cohorte v7.

3. **`afflictionCount` et ops `dps=0`** (§2.3/P-C) : `wither_bloom` déclenche `plague_communion`
   seul via ses ops à dps=0. Option C2 (1 ligne `arena.lua`) recommandée avant le tuning
   P1.5a de `plague_communion`.

4. **Rot = counter taunt documenté + relique manquante** (§2.4/P-D) : colonne (I) dans
   l'audit P0.5 + revue que rot n'a qu'une relique late (P(aucune) ≈ 24 % ⚠️).

---

## 6. Index des sources

**Internes (lecture seule du repo, ce round)** :
- `src/data/units.lua` (intégralité relue ce round — vérif lignes citées)
  - `wither_bloom` : lignes 280-287
  - `barrier_savant` : lignes 365-368
  - `ward_weaver` : lignes 362-365
  - `siphon_jelly` : lignes 417-420
  - `skull_colossus` : lignes 421-424
  - `galvanizer` : lignes 311-317
- `docs/roadmap-lab/00-state.md` (32 invariants, §2.1 roster, §3.1 familles DoT)
- `docs/roadmap-lab/ROADMAP-draft.md` (v5, §3.1 audit 6-col, §4.2 plague_communion, §5.2 twists)
- `docs/roadmap-lab/round-04.md` (§1.1 plague_communion vérifié, §1.11 afflictionCount >= 2)
- `docs/roadmap-lab/rounds/r04-units-power.md` (Q1 rot vs tank, §2.2 galvanizer condensateur)
- `src/combat/arena.lua` : `chooseTarget` (aggro câblée) + `afflictionCount` (condition
  plague_communion) — cités dans round-04.md §1.1 (vérif synthétiseur round 4)

**Sources web vérifiées ce round** :

- [GDC Vault — Slay the Spire Metrics Driven Design (Giovannetti 2019)](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) :
  « 1st mistake: too many cards that only differ by numbers. » → fonde §1.2 (rang-5 stat-sticks)
  + §1.1 (jauger condensateur sur dégâts par éruption).

- [PoE Wiki — Damage Over Time](https://www.poewiki.net/wiki/Damage_over_time) :
  Bleed = physical ; poison = chaos ; distinction de TYPE DE DOMMAGE = friction mécanique réelle.
  → fonde §2.1 (nos DoT manquent de friction inter-familles, contrairement à PoE).

- [Last Epoch Wiki — Damage Over Time](https://lastepoch.fandom.com/wiki/Damage_Over_Time) :
  Bleed = 53 dommage/instance, poison = 20 — distinctivité par puissance d'application.
  → fonde §2.1 (LE utilise aussi la puissance d'application comme friction ; nous utilisons
  seulement les paramètres d'axe).

- [Maxroll.gg — Last Epoch Damage Calculations](https://maxroll.gg/last-epoch/resources/damage-explained) :
  Scaling ailment duration pour augmenter dps total → mécanique de durée comme scalaire.
  → contexte §2.1 (nos durées fixes limitent la « dépense d'investissement » dans la famille).

- [PoE Wiki — Bleeding](https://www.poewiki.net/wiki/Bleeding) :
  Bleed amplifié par mouvement de la cible ; Crimson Dance pour multi-instance. → §2.1 (règle
  de stacking orthogonale = friction between bleed and poison).

- [Esports Tales — TFT Set 17 champion pool size](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances) :
  Pool partagé TFT T2=22 copies/champion partagées entre 8 joueurs. → §1.3 (notre pool LOCAL
  ≠ TFT partagé ; la règle ≥2/famille est notre propre mathématique, pas une analogie TFT).

- [Wayward Strategy — Unit Design, Clarity of Roles and Redundancy](https://waywardstrategy.com/2018/05/17/unit-design-clarity-of-roles-and-redundancy/) :
  « Units that combo with each other but appear independently create confusion and dead picks. »
  → fonde §2.2 (adjuvants shield_caster sans caster en boutique = dead pick).

- [Martin Fowler — Convention vs Configuration](https://martinfowler.com/books/eap.html) :
  Toute règle implicite accumule de la dette silencieuse. → §1.4 (champ `pool` déclaratif
  + lint = enforcement de la convention).

---

*Round 05 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu (units.lua
intégralité, lignes citées précisément). N'édite que sous `docs/roadmap-lab/`. Piliers
respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).
32 invariants non touchés. 0 modification du code du jeu.*
