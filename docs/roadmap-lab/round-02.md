# Round 02 — Synthèse (SYNTHETISEUR)

> **Rôle** : acter le round 2 du roadmap-lab. Intègre **de façon critique** les 6 critiques de
> lentille (`rounds/r02-*.md`) contre `ROADMAP-draft.md` v2 et la synthèse `round-01.md`. **Débat,
> pas addition** : j'adopte les critiques valides et sourcées, je rejette/tempère les faibles (en
> disant pourquoi), je consigne les VRAIS litiges pour le round 3. La roadmap intégrée vit dans
> `ROADMAP-draft.md` (réécrit en v3).
>
> **Garde-fous** : lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers : async
> snapshots / sim déterministe seedée / DA grimdark / pixel art procédural. 32 invariants préservés.
>
> **Inputs** : `BRIEF.md`, `ROADMAP-draft.md` (v2), `00-state.md`, `round-01.md`, les 6
> `rounds/r02-{progression-economy, ranked-competitive, relics, retention-addiction,
> synergies-effects, units-power}.md`. **Vérifs code menées par le synthétiseur ce round** (lecture
> seule, citées §4) : `units.lua` (champs `type`/`family`, ladder choc, U.pool/U.order),
> `arena.lua:330-388` (`dischargeShock` fait son propre dégât), `ops.lua:180-200` (op `shock` =
> 0 dégât à la pose), `relics.lua:26-29/51` (amplis = poison/burn/bleed/rot, **pas choc** ;
> `forked_tongue` seul levier choc tier 4 ; `swarm_logic`/`shockAmp` absents ; 21 reliques).

---

## 0. Méta-verdict du round

**Le round 2 est un round de VÉRIFICATION CODE qui démonte trois certitudes du brouillon v2 et
ouvre la décision de design la plus structurelle du lab à ce jour (l'axe du choc).** Là où le round
1 avait fait converger les lentilles sur « le contenu a des trous », le round 2 **descend dans le
code** et trouve que le brouillon **se trompe sur l'état réel du contenu** sur trois points
factuels (tous confirmés par le synthétiseur) :

1. **Le champ `type` est DÉJÀ pris** (visuel : flesh/bone/order/arcane/abyss), et `family` aussi
   (rendu procédural : insecte/annelide/spectre…). La phrase fondatrice de P1 (« type d'unité =
   famille mécanique ») **collisionne avec la data existante** : il n'existe **aucun** champ
   `dot_family`. *Deux lentilles indépendantes* (synergies §2.1, units §2.5) trouvent le même trou.
   → **P1 a un prérequis d'implémentation non nommé** : décider le porteur de la famille DoT.
2. **Le ladder choc est DÉJÀ codé** (9-10 unités, `units.lua:79-332`). Le brouillon le présente
   comme un chantier « à créer en P3 ». *Deux lentilles* (synergies §2.3, units §1.3) le corrigent.
   → P0.5 choc = **« décider l'axe + valider 9 unités existantes via sim »**, pas « créer 11 unités ».
3. **La complétude reliques n'est pas un confort mais une NÉCESSITÉ STATISTIQUE** : la lentille
   reliques chiffre (hypergéométrique) que l'archétype choc n'a **1 relique** → `P(aucune sur le
   run) ≈ 48 %`. Le critère « ≥2 reliques/archétype pour P<25 % » remplace l'argument qualitatif.

**Le VRAI litige nouveau et non tranché du round** : la lentille synergies propose un **axe C pour
le choc** — le choc cesse d'être un DoT-condensateur à dégât propre et devient un **amplificateur**
(stacks → la cible prend +N % des dégâts de la *prochaine source*, frappe OU tick DoT), calqué sur
PoE (Shock = *Non-Damaging Ailment*). Cet axe résout d'un coup la viabilité en ciblage déterministe
(la décharge profite à n'importe quelle source, même si l'unité choc est morte), la hiérarchie
(choc n'est plus concurrent de poison mais *les amplifie*), et donne une niche claire. **MAIS** il
n'est **pas data-only** (réécrit `dischargeShock`, rebaseline golden — confirmé en code) et il
**change la question du 6e type** (litige #F). → **Litige #G (NOUVEAU), à trancher round 3 par sim.**

**Le second axe fort du round** : *trois lentilles convergent* pour **corriger la formule daily**
(`×(1+xp_spent)` récompense l'**investissement**, pas l'efficience — un rush-XP est mieux noté
qu'un passif-pur identique en wins). Progression §2.4, ranked §2.4, retention §2.5. → remplacée par
un multiplicateur de **vitesse d'ascension**.

---

## 1. CE QUI CHANGE DANS LA ROADMAP (et pourquoi)

### 1.1 ADOPTÉ — P0.5 doit décider le PORTEUR de la famille DoT (`dot_family`) — précondition de P1, code-vérifiée

**Source** : synergies §2.1/P2 + units §2.5/P-C. **Convergence de 2 lentilles + vérif synthétiseur.**

- **Preuve code (synthétiseur)** : `grep 'type ='` → `flesh/bone/order/arcane/abyss` (axe visuel) ;
  `grep 'family ='` → `insecte/annelide/spectre/culte/…` (axe rendu procédural, vague v7 + rang-1) ;
  `grep 'dot_family'` → **0 résultat**. Donc « type = famille mécanique » (brouillon §4.1) est
  **faux dans la data** : `stormcaller` (choc) et `witch` (poison) ont tous deux `type="arcane"`.
  La famille DoT vit dans `effects[].op` (`op="poison"`…), pas en champ de premier niveau.
- **Pourquoi ça bloque P1** : le compteur de palier doit lire un champ stable. Inférer depuis
  `effects[1].op` **échoue sur les multi-effets** (`wither_bloom` = rot+bleed+poison ; `leech_thorn`
  = bleed+thorns ; `galvanizer` = bonus_first+shock). Sans règle, le palier serait atteignable
  trivialement par 1 unité multi-famille = décision vide (units §2.5).
- **Décision** : ajouter à P0.5 (data/doc, 0 code) **deux livrables** : (a) la décision du champ
  porteur — recommandation convergente **Option A : champ dédié `dot_family`** (nil pour les
  non-DoT ; rétro-compatible ; pas de collision) ; (b) la **règle de famille principale** pour les
  multi-effets : `dot_family = op du 1er effet DoT non-aura` (`wither_bloom→rot`, `leech_thorn→bleed`,
  `galvanizer→choc`). Documentée AVANT le code de P1 (units §P-C, tableau ~20 lignes).
- **Lien litige #F** : units-power note que ce choix **résout implicitement** #F — si seules les
  unités à `dot_family≠nil` comptent, les 11 unités shield/tank (units §Q4) « n'ont pas de type »
  = **option « aucun 6e type »** par défaut (à confirmer round 3).

### 1.2 ADOPTÉ — Reformuler P0.5-choc : « valider 9 unités EXISTANTES », pas « créer le ladder »

**Source** : synergies §2.3/P3 + units §1.3. **Convergence de 2 lentilles + vérif synthétiseur.**

- **Preuve code (synthétiseur)** : `units.lua` contient **stormcaller, live_wire, thunderhead,
  static_swarm, galvanizer, stormlord, dynamo_priest, arc_warden, storm_anchor, siphon_jelly** =
  **10 porteurs de choc**, avec archétypes distincts (cadence/dense/persistant/transfer/chain) et
  modificateurs (dynamo=transfer, arc=chain, storm_anchor=persist). **Le ladder choc N'EST PAS un
  chantier futur — il est livré et attend la décision d'axe.**
- **Conséquence roadmap** : la formulation du brouillon (§3.2 : « ne pas ajouter 11 unités à un axe
  non décidé ») est corrigée. Le chantier P0.5-choc devient : **(1) décider l'axe → (2) ajuster
  l'op/`dischargeShock` si nécessaire → (3) sim des 10 unités existantes → (4) rebaseline golden si
  le comportement choc change**. Le « ladder 5/3/2 » en P3 devient un **raffinement de paramètres**
  (et éventuellement 1-2 unités pivot), pas une création.
- **Preuve qu'un 2e axe coexiste déjà** : units §1.3 — `galvanizer (aggro=15)` a `bonus_first+shock` :
  il **se charge ET décharge en un combo autonome** (ne dépend pas de la survie de la cible). Donc
  l'axe « condensateur carry arrière » (A) et l'axe « bruiser auto-décharge » (galvanizer) sont
  **déjà tous deux dans le code**. La décision n'est peut-être pas « A xor B » mais **« quelle
  proportion A/B dans le ladder »** (units §Q5). → nourrit le litige #G (§3).

### 1.3 ADOPTÉ — Test opérationnel du choc CONTEXTUALISÉ (setup optimal), pas fuzz global

**Source** : units §2.2/P-B (+ synergies §2.3 même direction). **Critique valide d'un seuil non ancré.**

- **Le problème** : le brouillon (§3.2) mesure « taux de décharge après mort de la cible > 30 % »
  sur le **fuzz 250** (mélange aléatoire de sigils/placements). Or le taux de décharge perdue dépend
  de **3 variables indépendantes** (durée de combat via HP_MULT=2 ; tank en front ; sigil). Juger
  un archétype **conditionnel** (tank + ligne/anneau) sur un fuzz aléatoire = le mesurer dans son
  pire contexte (units §2.2). Analogie sourcée : MegaCrit évalue les cartes StS **par archétype**,
  pas en win-rate brut (GDC 2019, 18M runs — units §P-B).
- **Remplacement adopté** : la **matrice à 3 configurations** (units §P-B) avec seed fixe :
  - **Config A** (axe condensateur) : `gravewarden` (taunt, aggro=40) col 1 + 3 choc col 3, sigil
    **ligne**, N=50. → taux décharges perdues + win% vs poison build. *Axe A cassé si* >40 % perdues
    **ET** win% < moyenne−1σ **dans ce setup optimal**.
  - **Config B** (axe autonome) : `galvanizer` seul + stat-sticks, carré, N=50. → si win% >
    moyenne+0.5σ, l'axe B coexiste déjà.
  - **Config C** : choc pur, **anneau** (propagation), N=50. → win% vs défense pure.
- **Décision** : la sim peut conclure que **les deux axes coexistent** → nommer 2 sous-archétypes
  dans le ladder (≈ 5 condensateur arrière / 3 autonomes / 2 pivot) **sans décision binaire**. Ceci
  **interagit** avec l'axe C (§3, litige #G) : si C est retenu, A/B sont reformulés autour de
  l'amplification.

### 1.4 ADOPTÉ — Distinguer redondance de NICHE vs redondance de POOL dans l'audit P0.5

**Source** : units §2.1/P-A + §2.3. **La critique la plus opérationnellement utile du round.**

- **Le problème** : le brouillon (§3.1) prescrit « refonte data » comme **remède unique** à la
  redondance. units-power montre **deux problèmes distincts à remèdes opposés** :
  - **Type A — redondance de NICHE** (même op, même axe, stats ≤20 % d'écart) : ex. `razorkin
    (dps=2,slow=20%)` ≈ `gash_fiend (dps=3,slow=20%)`. Remède = **différencier l'axe** (trigger /
    condition distincte). Coût = params data.
  - **Type B — dilution de POOL** (niches en théorie distinctes, mais trop d'unités/famille/rang →
    le shop affiche N enablers interchangeables sur `SHOP_SIZE=5`). Remède = **retirer du pool
    boutique** (garder en roster pour encounters IA) ou fusionner. Coût = éditorial, **0 op**.
- **Preuve code chiffrée (units §2.3)** : **poison rang-2 = 6 enablers** (witch, rot_grub,
  chitin_drone, coil_viper, web_recluse, ink_horror — distingués par dps=1-3, dur=160-300) ; burn
  rang-2 = 5 ; bleed rang-2 = 5. La vague v7 (`units.lua:384-440`, 14 unités créées **pour les
  familles visuelles**) a gonflé le pool rang-2 sans niches de build. Ratio The Pit = **16.6/rang**
  vs **SAP 10/tier** (super-auto-pets §2.2 ; metatft pool-sizes 29/22/18/10/9).
- **Preuve code (synthétiseur)** : **`U.pool` et `U.order` sont DÉJÀ deux tables séparées**
  (`units.lua:453` vs `:488`), actuellement à contenu identique. Donc retirer du pool ≠ retirer du
  roster = **édition d'une table data déjà existante**, pas un refacto (confirme units §P-A).
- **Décision** : l'audit P0.5 §3.1 prend une **grille à 4 colonnes** (niche ≤10 mots / type de
  redondance A|B|Sain / remède / **`dot_family` inférée** [fusionne §1.1]). **Cible : ≤4 enablers
  par famille par rang dans `U.pool`** (pas `U.order`). Tout reste data/doc, 0 invariant.

### 1.5 ADOPTÉ — Critère de SUFFISANCE STATISTIQUE des reliques par archétype (≥2, P<25 %)

**Source** : relics §2.5/Prop-A. **Maths nouvelles + vérif synthétiseur des familles d'amplis.**

- **Preuve (relics, hypergéométrique)** : sur ~18 reliques late (F migrées), `P(aucune relique de
  l'archétype dominant sur 4 offres)` : burn (3 reliques) ≈ 10 % ✅ ; poison (3) ≈ 10 % ✅ ; bleed
  (2) ≈ 24 % ⚠️ ; rot (2) ≈ 24 % ⚠️ ; **choc (1 relique : `forked_tongue`) ≈ 48 %** ❌ ; **wide
  (0 : `swarm_logic` absent) = 100 %** ❌.
- **Vérif synthétiseur** : `relics.lua` confirme **`relic_affliction_inc` = poison/burn/bleed/rot
  uniquement** (lignes 26-29) ; **choc n'a que `forked_tongue` tier 4** (ligne 51) ; `swarm_logic`
  et `shock_conduit`/`shockAmp` = **absents**. Donc le calcul tient sur des faits.
- **Décision** : ajouter à P1.5 une **règle de complétude formelle** : « chaque archétype engagé
  (5 familles DoT + wide + shield) doit avoir **≥2 reliques pertinentes** dans le pool late, pour
  `P(aucune sur run) < 25 %` ». Ceci **prouve** que `swarm_logic` (wide) et un ampli choc mid-tier
  ne sont **pas optionnels** mais **nécessaires**. Le critère quantitatif **remplace** le critère
  qualitatif « archétypes non couverts » (relics §Q1 : un seul critère suffit). Mesure exacte via
  `tools/sim.lua` (relics §Prop-D, comptage reliques/archétype sur N runs).

### 1.6 ADOPTÉ — La condition d'activation distingue UNIVERSELLES (A) vs BUILD-DEFINING (B-E) ; conditionner TOUTES les E tier 4

**Source** : relics §2.1/§2.4/Prop-B. **Affine le §5.5 du brouillon (qui ne conditionnait que 2 reliques).**

- **Le problème** : le brouillon ne conditionnait que `plague_communion` et `second_breath`. relics
  §2.1 montre (lecture code) **6 reliques sans condition** dont **3 tier-4** quasi-universelles
  (`plague_communion` : « 2+ afflictions » = la norme sur 5 familles ; `second_breath` : survie 1 PV ;
  `forked_tongue` : actif même sans build choc). **Erreur conceptuelle du brouillon** : supposer
  qu'une tier-1 doit être build-defining. Modèle StS correct (relics §2.1) : **commun = universel
  (planchers) ; boss = build-defining via downside**.
- **Précision adoptée** : (a) les reliques **A (stats plates) restent délibérément universelles** —
  la garantie de pertinence (§1.7) ne s'applique **qu'aux B-E** (relics §2.2-A : sinon « type-cible
  présent » est trivialement vrai pour `carapace`/`aegis`/`whetstone`) ; (b) **conditionner TOUTES
  les E tier-4**, pas 2 : `plague_communion` → « ≥4 unités même affliction » (aligne sur paliers de
  type P1) ; `second_breath` → scope (≤4 unités ou front-row) ; **`forked_tongue` → « si ≥2 unités
  choc »** (manquait au brouillon).
- **Garde-fou (relics §2.4, valide)** : « scope conditionnel » est emprunté à StS **sans tester le
  mécanisme psychologique** — chez StS le *downside négatif* force le theming ; chez nous une
  condition NEUTRE (« inerte si absente ») n'incite pas à construire vers elle. → **Option scalante**
  retenue comme alternative à valider en sim : `plague_communion` = « +5 % dégâts équipe par allié
  de l'affliction majoritaire » (7 mots, ≤8 OK ; pas de dead-range 1-4 unités ; plus proche du
  compteur de type P1). À départager en sim (relics §Q2).

### 1.7 ADOPTÉ (raffiné) — Garantie de pertinence d'offre : sur B-E seulement + reformulation invariant #3 précisée

**Source** : relics §2.2 + progression §2.5. **Affine le §5.4 du brouillon.**

- **Reformulation (relics §2.2-A)** : « parmi les 3 offres, **si ≥1 est de catégorie B-E**, alors
  ≥1 de ces B-E a son type-cible présent sur le plateau ». Les A sont offertes librement (2 A + 1 B
  pertinente = offre valide). Évite le bug « pertinence triviale » des stats plates.
- **Invariant #3 (relics §2.2-B, précision technique)** : la garantie change la **signature** de
  `rollRelicChoices(n)` → `rollRelicChoices(n, compo)` (vérifié : la signature actuelle ne prend
  que `n`, `state.lua:339`). La compo doit être passée comme **donnée pure** (pas lue d'un état
  global — firewall). **Modifier `tests/relics.lua` #3 AVANT le code** (déjà marqué dans v2, mais
  la *nature du changement de signature* est désormais nommée).
- **Risque dégénéré (progression §2.5)** : au 1er marchand (round 3-4), le plateau est surtout du
  rang-1 de la famille la plus commune → la garantie **confirme** le joueur dans le 1er axe pris
  (boucle de renforcement précoce, runs early homogènes). **Mitigation** (progression §2.5) : au
  round ≤4, si la famille pertinente a ≥5 unités au rang-1, vérifier qu'une des 3 propose un type
  **non encore présent**. → **drapeau à mesurer** (distribution des builds day-1), pas un blocage.

### 1.8 ADOPTÉ — Scinder P1.5 en micro-lots découplés (P1.5a parallèle, P1.5b post-choc, P1.5c post-marchand)

**Source** : relics §2.6/Prop-C. **Correction de séquencement précise et bon marché.**

- **Le problème** : le brouillon met **tout** P1.5 après P1, alors que la garantie de pertinence
  reformulée + le conditionnement des E sont **data pure sans dépendance** (quelques heures) qu'on
  retarde injustement → dilution des offres pendant P0-P0.5 (relics §2.6).
- **Découpage adopté** :
  - **P1.5a** (data pure, **parallélisable avec P0/P0.5**) : garantie pertinence B-E + conditionner
    TOUTES les E tier-4 + documenter la règle ≥2 reliques/archétype. Délai : ~0.
  - **P1.5b** (**après P0.5** axe choc) : livrer `swarm_logic` (wide, gating ≥5 slots) + ampli choc
    mid-tier + shield-pur (si décidé archétype distinct, §Q4). **Dépend de l'axe choc.**
  - **P1.5c** (**après marchand /3 combats codé**) : runOp F → marchand.

### 1.9 ADOPTÉ (déclassé en vérif technique, pas blocage) — L'ampli choc n'est PAS « bloqué par la plomberie »

**Source** : relics §2.3/Prop-E. **Correction d'un sur-diagnostic du brouillon (§5.2).**

- **Preuve code (relics §2.3 + synthétiseur)** : le brouillon dit l'ampli choc « bloqué » car
  `relic_affliction_inc` cible un dps continu. Mais le patron **`grant_team` → `teamFlag` lu en
  combat** (utilisé par `plagueAmp`, et par 4 des 5 reliques E) **ne passe pas** par
  `relic_affliction_inc`. Un `shock_conduit` = `relic_add_effect{ grant_team{ shockAmp } }` + une
  lecture de `shockAmp` dans `dischargeShock`. **Vérification requise** : `dischargeShock`
  (`arena.lua:342`) lit-il `teamFlags` ? Si oui → data-only ; sinon → **+5 lignes dans un point
  isolé** (pas un refacto de boucle).
- **Décision** : retirer le label « bloqué par plomberie » ; remplacer par **« vérifier le point
  d'extension `dischargeShock`/`teamFlags` (30 min de lecture) avant de classer data-only vs +5 lignes »**
  (relics §Prop-E). **Note d'interaction avec litige #G** : si l'axe C (choc=amplificateur) est
  retenu, `dischargeShock` est de toute façon réécrit → l'ampli choc s'y greffe naturellement.

### 1.10 ADOPTÉ — Corriger la formule daily : VITESSE d'ascension, pas investissement XP (3 lentilles convergent)

**Source** : progression §2.4/§3.4 + ranked §2.4/P4 + retention §2.5. **Convergence forte de 3 lentilles.**

- **Le bug (progression §2.4, démo chiffrée)** : `daily = wins × (10−lives) × (1+⌊xp_spent/GOLD⌋)`.
  Un rush-XP (7 wins, 2 vies) = `7×8×2 = 112` ; un passif-pur **identique** = `7×8×1 = 56`. La
  formule **punit le passif** (la décision économiquement saine selon l'intention design) et
  récompense le rush-XP = **l'inverse de « l'efficience »**. C'est une mesure d'**investissement
  brut**, pas d'efficience.
- **Convergence** : ranked §2.4 ajoute que les 3 facteurs sont des proxys du *même* « bien jouer le
  run » → pas une **compétition à part** ; et la formule est **calculable a priori** (pas de
  surprise → pas de vrai leaderboard).
- **Remplacement adopté [PH, à sim]** (progression §3.4) : `daily = wins × (10−lives) × speed_mult`,
  avec `speed_mult` = 2.0 (ascension ≤10 rounds) / 1.5 (11-13) / 1.0 (14+) / **0 si chute**. Mesure
  l'efficience **naturellement** (vitesse de construction + propreté), affichable en 1 ligne
  (Snap/Brode, marvel-snap §7.3). `state.round` existe déjà (`state.lua:120`).
- **Nuances ouvertes (consignées, non gravées)** : (a) ranked §P4 pousse plus loin — **score
  binaire « ascensions du jour »** + ghosts **thématiques seedés** (tous burn aujourd'hui) pour une
  *vraie* épreuve différente. (b) progression §Q4 + retention §2.5 : un `speed_mult=0` pour les
  chutes 8-9 wins **punit les quasi-ascensions** ; un `0.5` partiel est défendable. → **Litige
  daily, round 3** (vitesse vs binaire-thématique ; chute propre = 0 ou 0.5 ?).

### 1.11 ADOPTÉ — High-roll NOMMÉ : « Moment du Run » au post-combat (nouveau chantier P0 rétention)

**Source** : retention §2.1/Prop-A. **Omission structurelle valide et bien sourcée que le round 1 n'a pas pointée.**

- **L'omission** : le brouillon traite la rétention via lisibilité/types/reliques/ranked mais **ne
  nomme nulle part le moment de puissance mémorable** comme pilier. La recherche (ejaw.net 2026 ;
  Roguelike Celebration 2024 « Comboness », Dotal ; medium Balatro VFX) documente le « good cheat »
  — *briser le jeu sans le détruire* — comme l'un des 2 vecteurs du replay compulsif. The Pit a le
  *rocket ship* (cascades DoT + propagation à la mort) mais **pas la photo du décollage** : le
  combo se produit dans une animation que le joueur regarde **passivement**.
- **Décision** : ajouter un **chantier P0 rétention** (RENDER, hors SIM) — au post-combat, lire le
  **bus JSONL** (`tools/eventlog.lua`, déjà structuré) pour identifier la **chaîne d'événements la
  plus longue en cascade** (`A tue B → on_death propage burn → burn tue C → …`) et l'afficher :
  « MOMENT DU RUN — CORRUPTION EN CHAÎNE (5 unités) » + flavor grimdark. Pas de moment si chaîne ≤2
  (anti-inflation). **Le déterminisme garantit l'exactitude** (invariants #1/#5). Test : la chaîne
  max correctement identifiée sur le golden (970156547). Se fait **pendant** que les types sont
  conçus (coût faible, impact « je dois retrouver ça »).

### 1.12 ADOPTÉ — Bootstrap du Codex : nommer/silhouetter les interactions inconnues (pas seulement récompenser après coup)

**Source** : retention §2.3/Prop-C. **Résout un problème que le round 1 avait vu (Q4) mais pas tranché.**

- **Le problème** : le Codex (adopté v2 §6.7) **récompense rétrospectivement** mais un joueur qui
  ignore que 12 interactions existent ne les cherche pas. The Pit **ne peut pas s'appuyer sur un
  wiki communautaire au lancement** (TBOI le peut — Kammonen 2023 ; Åslund 2026, his.diva-portal.org).
  → le Codex doit **auto-scaffolder la découverte**.
- **Décision (3 ajouts RENDER, 0 SIM)** : (a) **flash d'accroche** 2-3 s en combat à la 1re
  occurrence (« [DÉCOUVERTE] SANGUIN CORROSIF » pour bleed→rot) — nomme sans interrompre ; (b)
  écran de résultat « Synergies découvertes cette run : 2 » ; (c) onglet Grimoire : interactions
  inconnues en **silhouette** (« ??? — Saignement × Pourriture »), horizon d'exploration visible
  (cf. « Joker unknown » de Balatro). Écrit dans `grimoire.lua` (hors SIM), 0 invariant. S'intègre
  au Grimoire 2-onglets déjà prévu (the-pit-ui-da-layer).

### 1.13 ADOPTÉ (petit) — Score de saison PERSONNEL visible, distinct du ranked

**Source** : retention §2.4/Prop-D. **Comble un vide de feedback réel, mais à doser.**

- **Le problème (valide)** : la grille ranked `+4/+2/+1/0` donne **0 à toute la zone 0-5 victoires**
  → le joueur intermédiaire (4-5 wins réguliers) ne voit **aucune progression pendant des semaines**.
  La progression *visible même sur runs perdantes* est le moteur de rétention en zone intermédiaire
  (Polygon 2025 ; diva-portal 2021).
- **Décision** : un compteur **`season_wins += nb_wins_ce_run`** (toujours, victoire ou chute),
  affiché menu + fin de run (« 37 victoires cette saison »). Reset à la saison. RENDER + IO hors
  SIM, 0 invariant. **Garde-fou anti-redondance** : ne PAS empiler avec le `COMPLETION_BONUS` (v2
  §6.2) **et** le score de saison **et** le Codex — ce sont 3 sources de « feedback de progrès » ;
  garder `season_wins` (le plus simple) **comme remède principal du vide intermédiaire**, et
  reléguer `COMPLETION_BONUS` à « optionnel si la sim montre encore de l'abandon UI » (évite le
  triple-remède, cohérent avec round-01 §1.11).

### 1.14 ADOPTÉ (enrichissement, pas remplacement) — `build_cost_proxy` en COMPLÉMENT de `wins_at_capture`

**Source** : ranked §2.3/P3. **Bonne idée, mais ne remplace pas — enrichit.**

- **L'argument** : `wins_at_capture` ne capte pas la **qualité** du build à un stade (2 snapshots à
  5 wins, l'un fort/leveled, l'autre précaire). Proxy : `build_cost_proxy = Σ(rank × LEVEL_MULT[level])`
  (calculable en lecture seule des `snapshot.units`, déjà capturés).
- **Nuance critique (ranked §2.3 lui-même)** : en cold-start, filtrer sur `bucket AND wins±2 AND
  proxy±15` sur un pool de 200 → **risque de zéro résultat → fallback IA immédiat**. → adopter le
  proxy comme **critère ordonné AVANT le fallback descendant**, pas comme filtre dur empilé :
  `serve` ranked = (1) bucket + proxy±15 → (2) bucket + wins±2 → (3) bucket seul → (4) bucket−1 →
  (5) `serveComp`. Lecture seule, 0 invariant snapshot touché.

### 1.15 NOTÉ (sous le firewall) — `type`/`family`/`dot_family` : les 3 axes sont ORTHOGONAUX, c'est un atout DA

**Source** : synergies §1.4/§2.1 + units §2.5. Consigné comme **décision de design**, pas chantier.

- Le fait que `type` (visuel : flesh/bone/abyss…), `family` (rendu procédural : insecte/spectre…) et
  `dot_family` (mécanique : burn/poison…) soient **3 axes découplés** est exactement la « familles =
  THÈMES, 3 axes type/visuel/mécanique découplés » de la mémoire projet (the-pit-creature-visual-refonte,
  PHASE 2). **Ce n'est pas un bug à réconcilier — c'est l'architecture voulue.** P1 ajoute simplement
  le 3e axe explicite. À documenter comme tel pour ne pas « corriger » la séparation (cf. l'erreur
  symétrique du round 1 sur plagueAmp).

---

## 2. CRITIQUES REJETÉES OU TEMPÉRÉES — avec le POURQUOI

### 2.1 TEMPÉRÉ — Axe C du choc (amplificateur) : EXCELLENT mais PAS data-only → litige, pas adoption directe

- **Claim (synergies §1.1/§2.2/P1)** : reframer le choc comme **amplificateur du prochain hit reçu**
  (toutes sources), calqué sur PoE Shock = *Non-Damaging Ailment* (+20 % déf., max +50 % —
  poewiki.net/wiki/Shock vérifié). Résout viabilité déterministe + hiérarchie + niche.
- **Pourquoi je NE l'adopte PAS comme acté (mais le monte en litige #G fort)** : (a) **vérif code
  synthétiseur** : `dischargeShock` (`arena.lua:342-388`) fait **bien son propre dégât** (`burst =
  stacks × volt`, `cause="shock"`) ; le reframer = **réécrire `dischargeShock` + rebaseline golden**
  — synergies §P1 l'admet (« Golden devra être rebasé »). Ce **n'est donc pas** une décision data
  triviale comme l'audit P0.5. (b) Il **change le litige #F** : synergies §Q2 — si choc devient
  support, son palier de type « 4 choc → +X % ampli » a moins de sens. (c) Il interagit avec
  l'existence de `galvanizer` (auto-décharge) : si la décharge devient une amplification passive, le
  combo `bonus_first+shock` change de nature. **Verdict** : c'est la décision de design la plus
  structurelle ouverte par le round — elle mérite d'être **tranchée par sim** (les 3 configs §1.3 +
  un prototype mental de l'axe C), **pas gravée** sur la seule analogie PoE. → **Litige #G (§3).**

### 2.2 TEMPÉRÉ — Slot-decline « levier le plus risqué » : VRAI sous-analysé, mais reste un drapeau de sim, pas une crise

- **Claim (progression §2.3)** : `SLOT_DECLINE_GOLD=3` (+30 %/round) rend le refus **systématiquement
  optimal** pour les builds « tall » (cumul +18 or sur un run) → décision de style prise une fois,
  appliquée mécaniquement → casse tall-vs-wide.
- **Pourquoi tempéré (pas rejeté)** : l'analyse est **juste et bien vue** (SAP/TFT n'ont pas de
  refus-payant → c'est notre innovation non bornée). MAIS le **remède** est un **ajustement de
  constante** (réduire à 1-2, ou borner N refus/run) → **charge de la preuve sur la sim**, pas une
  nouvelle règle a priori (cohérent avec round-01 §2.1 sur le verrouillage XP). → **reste un drapeau
  P3** mais **promu PRÉCONDITION mesurée** : la sim « taux de refus optimal par round » (progression
  §3.5) doit tourner **avant de figer `SLOT_DECLINE_GOLD`**. Seuil : si « tout refuser » domine
  « tout accepter » de +5 % win-rate → baisser la constante.

### 2.3 REJETÉ (confirme le round 1) — Verrouillage XP early : le code prouve qu'il est inutile

- **progression §2.1 RENFORCE le rejet du round 1** : vérif code — `state.lua:195` impose que l'XP
  passive **ne démarre qu'au round 2** (`if self.round > 1`). Donc « rush dès le round 1 sans coût »
  (claim round 1) est **partiellement faux** : au round 1 il n'y a pas d'XP passive à « gaspiller » ;
  la tension existe mais sous forme **différente** (4 or = 4 rerolls / slots-1 sacrifiés). Le
  verrouillage est un **remède à un problème possiblement inexistant**. → reste une **cible de sim**
  (politique A « rush » vs B « passif » : delta tier R5 ≥ 1 **ET** win% +5 % → correctif justifié),
  **jamais une règle ajoutée a priori**. (progression §3.1 — confirmé.)

### 2.4 TEMPÉRÉ — Freeze : reste DÉCLASSÉ après audit pool + pity ; et « coût en slot » est une innovation non validée

- **progression §2.2 CONFIRME le déclassement v2** : le freeze SAP est **gratuit** (vérifié,
  superautopets.fandom.com) et résout le **timing** (« je veux cet item maintenant, pas assez d'or »),
  **pas la dilution** d'un pool de 83 (« je cherche depuis 9 rounds »). Le « freeze avec coût en
  slot » du round 1 = **innovation qu'aucun jeu de réf n'utilise** dans ce sens. → la vraie réponse
  à la dilution est **l'audit pool (§1.4) + pity-tracker** ; le freeze, s'il est testé, doit l'être
  **après**, et dans sa **forme la plus simple** (gratuit, **1 item/round** pour garder la pression).
  Reste **litige #E** (pity vs freeze vs les deux), mais la **dilution est désormais adressée en
  amont par §1.4** → le freeze pèse encore moins.

### 2.5 TEMPÉRÉ — Mesure de la stagnation méta : la critique est juste, mais « exclure 2 unités rang-5/run » est prématuré

- **Claim (retention §2.2/Prop-B)** : la sim « compo dominante par sigil » (proposée round 1 pour
  trancher #A) mesure la variance **intra-run** (1 sigil a-t-il un build universel ?), **pas** la
  **vitesse de résolution inter-runs** (combien de runs pour qu'un expert « solve » un sigil). Ajout :
  drapeau « vitesse de convergence méta/sigil » ; si convergence < 5-8 runs → variance forcée
  (exclure 2 rang-5/run, seedé).
- **Pourquoi j'adopte la MESURE mais pas le REMÈDE** : la distinction variance intra/inter-run est
  **valide et raffine le critère du litige #A** (je l'adopte, §3). MAIS « exclure 2 unités rang-5
  par run » est un **mécanisme de contenu** (réduit la diversité de build accessible, frôle « gate »)
  proposé **avant d'avoir la mesure**. Source de prudence : retention elle-même reconnaît que les
  reliques G (P4) + saisons sont le vrai vecteur anti-stagnation. → **adopté** : le drapeau
  `--meta-convergence` (retention §Prop-B) **devient le critère opérationnel du litige #A**
  (convergence < 8 runs pour ≥2 sigils → types d'abord). Le remède « exclusion rang-5 » reste **à
  l'étude** (litige #A enrichi), pas acté.

### 2.6 REJETÉ comme priorité — Boucliers périodiques « archétype non couvert » : vrai gap, mais P3, pas P1

- **Claim (synergies §2.5/§Q3)** : 5 porteurs de boucliers périodiques (`ward_weaver`…) existent
  (`units.lua:359-380`) ; le `strip_shield` `on_hit` ne contre pas un re-bouclier toutes les 4 s
  contre un attaquant lent (timing window non géré) ; les 12 contrats #22-32 ne couvrent pas
  bouclier-périodique × vitesse de frappe.
- **Pourquoi rétrogradé (pas rejeté)** : observation **juste et code-sourcée**, mais c'est un
  **problème d'équilibrage/counterplay de combat** (métrique de sim + éventuel op `pierce_shield`
  timing), pas un blocage de P1 (types) ni de P0.5 (audit). → **drapeau P3** (« métrique sim
  timing-shield » + question « strip impose-t-il un cooldown de recharge ? »). Lié à la dette connue
  « contres de taunt/strip différés » (00-state.md §7).

### 2.7 REJETÉ comme acté — Écrémage élite & cold-start IA : VRAIS problèmes, mais ouverts (litige ranked), pas tranchés

- **Claims valides (ranked §2.2/§2.5)** : (a) l'écrémage « +4 seulement si run propre en haut rang »
  est une **condition cachée** (anti-lisibilité, contredit l'argument anti-floor du round 1) →
  proposition de la **rendre explicite avant la run** (« Tu es en Forsaken — seule une ascension
  sans perte de vie donne +4 »). (b) Le **cold-start IA** est une menace : ranked vide → `serveComp`
  → ascensions faciles contre l'IA → `+4` fréquents → joueur **sur-ranké** → grille **sans pénalité**
  → il ne redescend pas → ranked humain pollué. Proposition : **flag `quality.human`** (run divisée
  par 2 si <80 % combats humains, **notifiée**).
- **Pourquoi je ne les grave PAS ce round** : tous deux dépendent de **données non encore posées**
  — (a) l'écrémage explicite est une **bonne idée à adopter en principe**, mais sa calibration (quels
  tiers, quel seuil de vies) dépend de la **hauteur des paliers** (litige #G-ranked, §3) ; (b) le
  flag `quality.human` exige un **seuil** (« >50 ghosts humains/tier » = hypothèse de travail
  non-mesurable hors launch — ranked §4.2). → **adopté en principe, consigné en litige ranked**
  (l'écrémage devient « explicite ou supprimé » ; `quality.human` = « à spécifier quand le pool
  est mesurable »). Pas de gravure prématurée.

### 2.8 TEMPÉRÉ — Twist burn 4 « pas de décroissance en front » = clone d'ash_maw : valide, intégré au principe existant

- **Claim (synergies §2.4)** : code — `ash_maw` (`units.lua:232`) pose déjà `grant_team{ burnNoDecay }`
  (équipe entière). Un twist burn 4 « no-decay en front » serait un **sous-cas du T3** → duplication
  (interdit par NWO/MTG, effects-synergy-tiers §3.1). Proposer un twist **orthogonal** (propagation
  en cours-de-vie à l'application, ou refresh-max au re-hit).
- **Pourquoi tempéré (intégré, pas « nouveau »)** : la critique est **juste et code-sourcée**, mais
  elle **renforce un principe déjà adopté round 1** (twists = [PH] **ouverts**, valeurs non gravées,
  §2.6 round-01). → j'ajoute un **garde-fou explicite** à la table des twists candidats P1 : « un
  twist de palier 4 ne doit **pas** être un sous-cas d'un T3 existant » (vérifier vs `ash_maw`,
  `wildfire_hound`, etc.). Les exemples concrets (propagation cours-de-vie / refresh-max) entrent
  comme candidats **à valider en sim**, pas gravés.

---

## 3. LITIGES OUVERTS (pour le round 3 — VRAIS désaccords non tranchés)

| # | Litige | Camp A | Camp B | Critère de résolution proposé |
|---|--------|--------|--------|-------------------------------|
| **#A** *(enrichi)* | Ordre P1 (types) vs P2 (ranked) — « rotation vs stagnation » | retention §2.2 : mesurer la **vitesse de convergence inter-runs**, pas seulement « compo dominante » ; ranked §4.1 : types AVANT remplit le pool ranked de snapshots **diversifiés** (anti cold-start) → **2 arguments pour types d'abord** | brouillon : si 5 sigils = 5 métas, ranked peut précéder | **Drapeau `--meta-convergence`** (retention §Prop-B) : `rang_convergence < 8 runs` pour **≥2 sigils** → types d'abord. **Le remède « exclure 2 rang-5/run » reste à l'étude**, pas acté |
| **#B** | Double-comptage inc% (types × reliques B × auras) | borné par cap ×3 (**confirmé code**) ; plagueAmp hors-cap = voulu (drapeau, pas refonte) | relics §Q5 : le **twist de palier 4** est une « règle modifiée », **pas un `increased`** → sa nature dans la couche stats n'est pas spécifiée ; combo 4-burn + twist + ember_heart + soot_acolyte ? | sim **lift de co-occurrence** sur builds mono-type committés AVANT de figer les valeurs. **+ spécifier la nature stats du twist** (more ? flag ? hors-cap ?) avant P1 |
| **#D** | Compteur de type **global** vs **adjacence-type** | synergies §3 (round 1) : adjacence = signature | units/retention : global = lisible | **Critère opérationnel (synergies §P4)** : sim — si `stddev(position des unités du type) > 2.0` (dispersion 3×3) **ET** win% > 0.55 pour compos à palier activé → adjacence-type justifiée. Sinon global. Défaut **global v0.10** ; bascule v0.12 |
| **#E** | Remède hunt 3e copie : pity-tracker vs freeze vs les deux | retention : pity visible (goal-gradient) | progression : freeze **gratuit, 1 item/round** (pas « coût en slot ») | **La dilution est désormais adressée en amont (§1.4 audit pool)** → le freeze pèse moins. Sim « hunt médian » d'abord (seuil p50 rang-2 en T2 > 5 rounds) ; choisir le moins coûteux **après** le nettoyage du pool |
| **#F** *(orienté)* | 6e type non-DoT : Taunt-seul / Sentinel / **aucun** | units §Q4 : 11 unités shield/tank existent → archétype non-négligeable | synergies §2.1-C + units §1.1 : si seules `dot_family≠nil` comptent → **« aucun » par défaut** ; retention/lisibilité | **Lié au choix `dot_family` (§1.1)** : « aucun 6e type » résout #F implicitement (shield/tank = enablers transversaux d'adjacence, sans palier). À **confirmer** round 3 ; **dépend de #G** (si choc devient support, l'axe « type » se réduit aux 4 DoT-dégât) |
| **#G** *(NOUVEAU, fort)* | **Axe du choc** : (A) condensateur dégât-propre arrière / (B) mini-dégât à la pose / **(C) amplificateur du prochain hit reçu** (PoE Shock = non-damaging) | synergies §1.1/§2.2 : **C** résout viabilité déterministe + hiérarchie + niche d'un coup ; PoE confirme l'identité « amplificateur » | brouillon/units : A et B (galvanizer prouve que A+auto-décharge coexistent déjà) | **NON data-only** (réécrit `dischargeShock`, **rebaseline golden** — confirmé code). Trancher round 3 par **sim des 3 configs (§1.3)** + prototype mental de C. **Interagit avec #F et #B** (si C : palier choc devient « 2 choc → l'ampli touche aussi les DoT tick ») |
| **#A2** | « Dernier Souffle » : exister ? 0 ou 1 vie ? bonus ou **dette** ? | retention §2.6 (round 1) : dette (−1 niveau) | ranked §4.4 : à 1 vie | Ne pas trancher avant la **grille de score + hauteur des paliers figées** (interaction). |
| **#H** *(NOUVEAU)* | **Daily** : `wins×(10−lives)×speed_mult` vs **score binaire « ascensions du jour » + ghosts thématiques** | progression §3.4 : speed_mult (efficience, 1 ligne) | ranked §P4 : binaire + thème seed = **vraie** épreuve distincte | Trancher round 3. **Sous-question** : chute 8-9 wins → `speed_mult=0` (progression) ou `0.5` (retention §2.5/progression §Q4, anti-punition des quasi-ascensions) ? |
| **#I-ranked** *(NOUVEAU)* | **Grille `+4/+2/+1/0` orpheline** : hauteur des paliers + grille **doivent être définies ENSEMBLE** ; écrémage élite **explicite ou supprimé** ; **cold-start IA** (flag `quality.human`) | ranked §2.1/§3-P1 : calibrer sur une vitesse-cible (**1 tier / saison 6-8 sem. à 2 runs/sem, 50 % ascension** → **~35 pts/tier**) ; écrémage affiché avant run ; `quality.human` /2 si <80 % humain | — | Script indépendant `tools/ladder_sim.lua` (100 joueurs fictifs × N saisons). `quality.human` = à spécifier quand le pool est mesurable. Toutes valeurs [PH] |

**Litiges CLOS** : #C (rating global unique, clos round 1) — **reconfirmé** par ranked §6
(Backpack = rating global, steamcommunity 2025).

---

## 4. PREUVES NOUVELLES APPORTÉES CE ROUND (ce qu'on sait de plus qu'au brouillon v2)

1. **Code vérifié (synthétiseur)** — `units.lua` : `type` = champ **visuel** (flesh/bone/order/
   arcane/abyss) ; `family` = champ **rendu procédural** (insecte/annelide/…) ; **`dot_family`
   ABSENT**. La phrase « type = famille mécanique » du brouillon est **fausse dans la data**. →
   §1.1, fonde le prérequis P1.
2. **Code vérifié (synthétiseur)** — ladder choc **DÉJÀ codé** : 10 porteurs (`stormcaller,
   live_wire, thunderhead, static_swarm, galvanizer, stormlord, dynamo_priest, arc_warden,
   storm_anchor, siphon_jelly`). Le brouillon le croyait « à créer ». → §1.2.
3. **Code vérifié (synthétiseur)** — `dischargeShock` (`arena.lua:342-388`) fait **son propre
   dégât** (`burst = stacks × volt`, cause="shock") ; l'op `shock` (`ops.lua:180`) fait **0 dégât à
   la pose**. → l'axe C (choc=amplificateur) **n'est PAS data-only** (rebaseline golden). Fonde
   litige #G.
4. **Code vérifié (synthétiseur)** — `relic_affliction_inc` = **poison/burn/bleed/rot** seulement
   (`relics.lua:26-29`) ; **choc = `forked_tongue` tier-4 SEUL** (ligne 51) ; `swarm_logic` /
   `shockAmp` / `shock_conduit` = **absents** ; **21 reliques** (le « 18 » de docs anciens est
   stale). → fonde §1.5.
5. **Code vérifié (synthétiseur)** — **`U.pool` et `U.order` sont déjà 2 tables séparées**
   (`units.lua:453` vs `:488`), contenu identique. → retirer du pool ≠ refacto (fonde §1.4).
6. **Maths nouvelles (relics, hypergéométrique)** — `P(aucune relique de l'archétype/run)` : choc
   ≈ 48 %, wide = 100 %, bleed/rot ≈ 24 %, burn/poison ≈ 10 %. → critère **≥2 reliques/archétype,
   P<25 %** (§1.5).
7. **Bug de formule daily démontré (3 lentilles)** — `×(1+xp_spent)` note un rush-XP **112** vs un
   passif-pur identique **56** → récompense l'investissement, pas l'efficience. → §1.10.
8. **Source corrigée/affermie** — PoE Shock = *Non-Damaging Ailment* (+20 %, max +50 % —
   poewiki.net/wiki/Shock, mobalytics PoE2) : fonde l'axe C (litige #G).
9. **Vérif empirique concurrence (ranked)** — Bazaar S2 patch 2.0 (mai 2025) score **par wins du
   run, sans pénalité, en brackets/rang** (bazaar-builds.net, screenrant) → **valide a posteriori**
   la grille `+4/+2/+1/0` (le round 1 avait démonté une *mauvaise* référence ; la direction reste
   bonne). Mais la grille reste **orpheline sans hauteur de paliers** (litige #I).
10. **`state.lua:195` vérifié** (progression) — XP passive démarre **round 2** → le « rush round 1 »
    du round 1 était partiellement faux ; verrouillage XP **inutile** (§2.3).

---

## 5. IMPACT SUR LE SÉQUENÇAGE (résumé du diff roadmap v2 → v3)

```
v2 :  P0 lisibilité(+carte risque) → P0.5 audit identité+choc-axe →
      P1 types(global) → P1.5 complétude reliques → P2 ranked(sans pénalité)+daily+Codex →
      P3 équilibrage+pool+reliques-qualité → P4 sigils+saisons → v1.0 backend

v3 :  P0 lisibilité(+carte risque) + [NOUVEAU] "MOMENT DU RUN" (high-roll nommé, RENDER) →
      P0.5 audit identité ENRICHI {colonne dot_family + redondance NICHE-vs-POOL + cible ≤4/pool} +
           choc-axe REFORMULÉ {valider 10 unités existantes, sim 3-configs, litige #G axe C} +
           décision PORTEUR dot_family + règle famille-principale →
      P1.5a [REMONTÉ, data pure, // P0/P0.5] {garantie pertinence B-E + conditionner TOUTES E tier4 +
            règle ≥2 reliques/archétype} →
      P1 types(global ; dot_family explicite ; twists≠sous-cas T3 ; nature-stats du twist spécifiée) →
      P1.5b [post-choc] {swarm_logic + ampli choc(verif dischargeShock) + shield-pur si #Q4} →
      P2 ranked(sans pénalité ; grille+paliers ENSEMBLE litige#I ; build_cost_proxy ordonné ;
         écrémage EXPLICITE ; flag quality.human cold-start) + daily(litige#H) +
         Codex BOOTSTRAPPÉ(silhouettes+flash) + season_wins perso →
      P1.5c [post-marchand] {runOp F → marchand} →
      P3 équilibrage(meta-convergence#A ; slot-decline mesuré AVANT figer ; hunt médian ;
         timing-shield ; reliques-qualité) →
      P4 sigils+saisons → v1.0 backend
```

**Gains mesurables vs v2** : **5 vérifs code décisives** (3 corrigent des erreurs factuelles du
brouillon : `type` pris, ladder choc existant, pool/order séparés) ; **1 critère statistique** de
complétude reliques (≥2/archétype) qui **prouve** que swarm_logic + ampli choc sont nécessaires ;
**3 lentilles** corrigent la formule daily ; **2 nouveaux chantiers** (high-roll « Moment du Run »,
Codex bootstrap) ancrent la rétention ; **P1.5 scindé** en 3 micro-lots (P1.5a remonté en parallèle) ;
**3 litiges nouveaux nommés** (#G axe choc, #H daily, #I grille-ranked) + #A/#F enrichis. **0
invariant violé** ; toute proposition touchant un test (#3 reliques, golden si axe C) **signale le
changement AVANT le code**.

---

*Synthèse du round 2 actée le 2026-06-23. Lecture seule du repo (vérifs code citées §4). N'édite
que sous `docs/roadmap-lab/`. Piliers respectés. Litiges #A/#B/#D/#E/#F/#G/#H/#I/#A2 ouverts pour
round 3 ; #C clos (reconfirmé). La roadmap intégrée v3 est dans `ROADMAP-draft.md`.*
