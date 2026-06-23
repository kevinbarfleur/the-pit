# Round 01 — Synthèse (SYNTHETISEUR)

> **Rôle** : acter le round 1 du roadmap-lab. Intègre **de façon critique** les 6 critiques de
> lentille (`rounds/r01-*.md`) contre `ROADMAP-draft.md` v1. **Débat, pas addition** : j'adopte
> les critiques valides et sourcées, je rejette les faibles (en disant pourquoi), je consigne les
> VRAIS litiges pour le round 2. La roadmap intégrée vit dans `ROADMAP-draft.md` (réécrit).
>
> **Garde-fous** : lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers : async
> snapshots / sim déterministe seedée / DA grimdark / pixel art procédural. 32 invariants préservés.
>
> **Inputs** : `BRIEF.md`, `ROADMAP-draft.md` (v1), `00-state.md`, `rounds/r01-{progression-economy,
> ranked-competitive, relics, retention-addiction, synergies-effects, units-power}.md`. **Vérifs
> code menées par le synthétiseur** (lecture seule) : `arena.lua:243-262`, `ops.lua:22/31/278`,
> `relics.lua` (21 ids, familles d'amplis, absence de `swarm_logic`).

---

## 0. Méta-verdict du round

Les 6 lentilles **convergent fortement** sur un point que le brouillon avait sous-estimé : **le
contenu n'est pas "correct, à polir en P3" — il a des trous structurels (identité d'unités, choc,
couverture reliques) qui CASSENT les systèmes construits par-dessus (synergies de type, ranked).**
Trois lentilles indépendantes (units-power, synergies, relics) réclament la **même chose** : un
**audit d'identité/complétude AVANT de coder les systèmes de type** — sinon on amplifie des
décisions sans distinction (« 2 burn = +20 % » sur 3 unités burn interchangeables = seuil
numérique, pas décision). C'est le **changement #1 de la roadmap**.

Le **désaccord le plus tranché** est sur le ranked : la lentille ranked **démonte la grille de
score du brouillon** (`+3/+2/+1/0/−1`) comme une copie des bugs Bazaar S1+S2 inadaptée à notre
rythme (2-3 runs/sem vs 3+/jour), et **démonte les floors** (double système LP/MMR caché,
anti-lisibilité — fatal pour un jeu déjà cryptique). Deux corrections **fortes et sourcées** que
j'adopte.

**Un VRAI litige nouveau et non tranché** émerge : faut-il **ancrer les synergies de type dans
l'adjacence** (compteur de voisins-du-type, signature The Pit) ou rester sur un **compteur global**
(plus lisible) ? Les lentilles synergies (pour adjacence) et retention/units (prudence lisibilité)
ne s'accordent pas. → Litige #D, round 2.

---

## 1. CE QUI CHANGE DANS LA ROADMAP (et pourquoi)

### 1.1 ADOPTÉ — Insérer un chantier P0.5 « Audit identité & complétude du contenu » AVANT les types

**Source** : units-power §2.1/§2.5/P-A (lecture directe `units.lua`), synergies §2.2/§2.3, relics §2.1.
**Convergence de 3 lentilles indépendantes** = signal le plus fort du round.

- **Preuve nouvelle (code lu par 2 lentilles)** : units-power cite `units.lua` lignes 58-120 :
  `emberling (dps=6,dur=150)` vs `pyre_tender (dps=10,dur=180)` = même décision de build (« poser
  1 brûlure »), distinction = échelon de puissance, pas de niche. Idem bleed rang-2 : `razorkin
  (dps=2,slow=20%)` vs `gash_fiend (dps=3,slow=20%)` = quasi-doublon. C'est de la **variation
  paramétrique**, pas de la **variation de niche**.
- **Pourquoi ça casse P1 (types)** : un palier « 2 burn → +20 % » atteint avec n'importe quelle
  paire de burn interchangeables est un **seuil numérique sans décision identitaire** (units-power
  §2.5). StS GDC 2019 Giovannetti : « la 1re erreur est trop de cartes qui font la même chose avec
  des nombres différents » (gamedeveloper.com). Balatro = 150 Jokers mémorisés par *règle modifiée*,
  pas par stats (Rolling Stone, LocalThunk 2024).
- **Coût** : pur design data + doc, **0 ligne de code, 0 invariant** (units-power P-A). Donc
  *bon marché ET débloquant* — exactement le profil d'un P0.

**Décision** : nouveau **P0.5** (audit identité, livrable = tableau dans `docs/roadmap-lab/`) entre
P0 (lisibilité) et P1 (types). Ne décale pas P0 (RENDER, parallèle).

### 1.2 ADOPTÉ — Décider l'axe de design du CHOC avant tout « ladder 5/3/2 »

**Source** : synergies §2.1/Q1/P1-A, units-power §2.3/P-B. **2 lentilles**, argument mécaniste
identique et **non réfuté**.

- **Mécanisme** : le choc est le **seul axe dont le payoff dépend d'un événement non contrôlé**
  (être frappé *après* la pose, sur *cette* unité précise). Les 4 autres DoT tickent
  inconditionnellement. Sur ciblage déterministe (colonne avant ciblée en 1er) + combats courts,
  une unité choquée en front **meurt avant de décharger** → perte sèche. PoE a identifié ce
  pattern (ailments « on-hit/crit-only » trop volatils, pathofexile.fandom.com/wiki/Damage_over_time).
- **Pourquoi le brouillon a tort de proposer « +contenu »** : ajouter 11 unités à un axe cassé
  dilue le pool sans créer un archétype viable (Balatro : LocalThunk re-design la *condition*, pas
  le *nombre*). Le brouillon **évite** la question d'axe — les deux lentilles l'imposent.
- **Pas une violation de décision** : la décision §8 (4 familles DoT à axes distincts) est intacte ;
  le choc est la **5e** famille, déjà actée comme « condensateur » (00-state.md §3.1). On ne
  re-débat pas son existence, on tranche son **profil-cible** (carry arrière vs mini-dégât à la pose).

**Décision** : **P-choc** (décision d'axe + sim ciblée `choc+tank` sur anneau/ligne) devient un
prérequis *bloquant le ladder*, *non-bloquant pour P0/types*. Test opérationnel proposé par
synergies §Q1 : « taux de décharge *après* mort de la cible » dans le fuzz ; si > 30 %, axe cassé.

### 1.3 ADOPTÉ (REMPLACE §4.2) — Grille de score ranked SANS pénalité

**Source** : ranked §2.1/P1. **Désaccord fort, sourcé, et il corrige une analogie paresseuse que
le brouillon avait laissé passer** (ironie : le brouillon se voulait anti-analogie-paresseuse).

- **Preuve nouvelle** : la grille `+3/+2/+1/0/−1` du brouillon **copie la grille Bazaar S2**, qui
  est elle-même un *patch* d'une grille S1 boguée. Elle hérite du **pire des deux** : le `−1` à
  <4 wins **pousse au safe-play** (biais S1 : sécuriser 4 wins), et **pas de bonus** 4-6 wins
  (pas d'incitation à viser l'ascension). steamcommunity.com (Bazaar) documente l'abus par
  défaite intentionnelle. **Le « pourquoi » psychologique ne transfère pas** : Bazaar = 60-90
  runs/saison ; The Pit = 10-15 runs/saison → **un seul −1 efface une semaine de progrès**.
- **Remplacement adopté** [PH, à sim] : `Ascension 10v = +4` · `chute 8-9v = +2` · `chute 6-7v =
  +1` · `chute 0-5v = 0` (jamais de pénalité). La **pression vient du matchmaking** (dur de rester
  haut) et des saisons, pas de la grille. Compatible « égalisateurs, pas gates » (00-state.md §0).
- **Renforce** : `STREAK_CAP=3` dans `state.lua` montre déjà que le design valorise la régularité
  courte, pas l'accumulation — la grille sans-pénalité est cohérente.

### 1.4 ADOPTÉ (REMPLACE §4.3 floors) — Règle asymétrique de perte max, lisible, à la place des floors

**Source** : ranked §2.2/P3. **Désaccord fort et spécifiquement pertinent à NOTRE risque produit.**

- **Preuve nouvelle** : les floors TFT créent un **double système LP-visible / MMR-caché**
  documenté comme source de confusion #1 (immortalboost.com, boosteria.org : « players feel
  confused… the system makes its biggest decisions using MMR »). The Pit est **solo dev + DA
  grimdark cryptique + reliques rendues lisibles par décision #7** : empiler un MMR fantôme
  **double la charge cognitive** sur un jeu dont la lisibilité est *déjà* l'axe de risque (Artifact
  mort d'opacité, postmortems §4.4).
- **Remplacement adopté** : pas de floor rigide ; **règle asymétrique lisible** : « on ne peut pas
  perdre plus d'1 tier par saison ». MMR interne jamais resetté ; rating visible −20 % au reset
  (pas zéro). Habillable grimdark : « Le Puits vous a retenu — vous ne tombez pas plus bas. »
- **Cadence saisons** : **6-8 sem.** (pas 4 comme Bazaar) — 4 sem. = 10-15 runs = arc illisible ;
  6-8 = 15-25 runs = narration de progression. **Adopté** (ranked §P3).

### 1.5 ADOPTÉ (ENRICHIT §4.4) — Matchmaking par (bucket, wins_at_capture) + fallback descendant

**Source** : ranked §2.3/P2 (+ retention §Q5 indépendamment). Le brouillon avait la **bonne idée**
(`rank_bucket`) mais **sous-spécifiée**.

- **Preuve** : (A) avec un petit pool, `floor(rating/500)` = tout le monde au bucket 0 → filtrage
  nul (Bazaar a eu ce bug au lancement, steamcommunity.com). Fallback **descendant** requis
  (bucket−1, jamais +1), IA en dernier filet (`serveComp`, garanti). (B) Le bucket **ne capte pas
  le stade de run** : un build à 3 wins affronte un ghost figé à 10 wins → frustration. → ajouter
  `wins_at_capture` au snapshot, matcher à ±2 wins. Bazaar matche par (rank, day_record) — même
  principe.
- **Convergence indépendante** : retention §Q5 propose *exactement* le même mécanisme pour la
  variance early (« filtrer les ghosts round 1-3 à des tiers/wins bas »). Les deux lentilles se
  rejoignent → mécanisme robuste.
- **Format snapshot** : `+2 champs (rank_bucket, wins_at_capture)`. Aucun invariant #18-21 touché
  (ils portent sur les reliques). **Zone sans test** (00-state.md §8) → test round-trip + fallback
  à ajouter AVANT le code.

### 1.6 ADOPTÉ (SÉPARE de §5) — Score de la Daily DISTINCT du ranked

**Source** : ranked §P5, retention §2.3 (convergence partielle). Le brouillon disait « même score
que §4.2 » → **erreur**.

- **Pourquoi** : si daily = score ranked, le joueur optimise le *même* comportement dans les deux
  → la daily n'est plus un contenu à part. La daily doit récompenser **l'efficience** (leaderboard
  éphémère), pas le binaire win/loss. Proposition ranked §P5 [PH] :
  `daily = wins × (10 − lives_lost) × (1 + ⌊xp_spent/GOLD_PER_ROUND⌋)`.
- **Garde-fou retention §2.3** : ce **n'est pas** le « score de composition pré-combat » (rejeté,
  cf. §2.3 ci-dessous) — c'est un score *post-run*, calculé sur le résultat déterministe (RENDER,
  hors SIM, invariant #2 garantit la reproductibilité). Distinction nette, adoptée.

### 1.7 ADOPTÉ — Pity-tracker VISIBLE pour la 3e copie (pas un pity « optionnel après sim »)

**Source** : retention §2.1/Prop-A, progression-economy §2.2/§3.2 (freeze) — **convergence sur le
problème** (le hunt de 3e copie est trop long), divergence sur le remède.

- **Preuve nouvelle (maths, 2 lentilles)** : retention calcule le hunt médian d'un rang-3 en T3 ≈
  **12 rerolls** (`ln(0.5)/ln(0.945)`), soit ~2× le seuil « 5 » que le brouillon posait **sans
  source**. progression-economy calcule un rang-2 spécifique ≈ **6.5 %/boutique** → ~9 rounds pour
  3 copies. Les deux convergent : **le pool de 83 rend le hunt de duplicata frustrant.**
- **Remède adopté (retention)** : un **pity-tracker visible** (cote affichée qui monte : +5 %/reroll
  au-delà du 8e sans voir l'unité, cappé ×2) — source **goal-gradient** (Nunes & Drèze 2006 ;
  Springer 2020 sur le near-miss) : un signal de « presque » transforme la frustration en
  anticipation ; **sans signal, c'est de la frustration plate**. C'est une **condition**, pas une
  option « à réévaluer ».
- **Le freeze (progression-economy §3.2)** = remède *alternatif/complémentaire*. → **Litige #E** :
  pity-tracker vs freeze vs les deux ? (cf. §3). Les deux sont déterministes, RENDER+state, 0
  invariant SIM, mais le **freeze touche la distribution** → adapter le test de cotes (00-state.md
  §6) AVANT.

### 1.8 ADOPTÉ — Garantie d'offre reliques = PERTINENCE de build, pas « tier A/B »

**Source** : progression-economy §2.3/§3.3, relics §2.3 — **2 lentilles, même critique, sur la
même phrase du brouillon (§6.4).**

- **Preuve** : « ≥1 relique tier A/B » rate la cible — une relique A (`+15 % HP équipe`) est inutile
  pour un squishie-carry ; `kings_bowl (+20 % poison)` pour un build bleed pur est une poubelle
  **quel que soit son tier**. TFT : les *dead choices* viennent du **désalignement offre/build**,
  pas de la rareté (Riot Gizmos & Gadgets). HS:BG garantit « ≤2 coût » *parce que* ses bas-coûts
  sont universels — **nos reliques A ne le sont pas** (relics §2.3 : `aegis` inutile en rush).
- **Remplacement adopté** : « ≥1 des 3 reliques a son type-cible (affliction/archétype) présent sur
  le plateau courant ». Déterministe (plateau figé au seed du round), appliqué AVANT le Fisher-Yates.
- **Garde-fou invariant #3** : « même seed+wins → même offre » devient « même seed+wins+**compo** →
  même offre » (reformulation correcte pour le replay). **Modifier le test #3 AVANT le code**
  (relics §P2 le signale aussi). C'est un *vrai* changement d'invariant, pas cosmétique → tracé.

### 1.9 ADOPTÉ (REMONTE de P3→P1.5) — Passe de complétude reliques (archétypes non couverts)

**Source** : relics §2.1/P0 (lecture directe `relics.lua`, **vérifiée par le synthétiseur**).

- **Preuve nouvelle (code confirmé)** : j'ai vérifié `relics.lua` — **`swarm_logic` (wide) est
  absent des 21** (grep = 0), et **aucune relique-B (`relic_affliction_inc`) ne couvre le choc**
  (familles présentes = poison/burn/bleed/rot seulement). Donc : archétype **wide non adressé**,
  **shield-pur non adressé**, **choc sans amplificateur mid-tier** (seul `forked_tongue` tier 4 en
  late). relics-design.md §5 liste `swarm_logic` comme prévu mais non livré.
- **Pourquoi pas P3** : une offre 1-parmi-3 dont aucune relique ne *shape* le build courant est une
  *dead choice* (tft.md §V5). Construire un **ranked** (qui doit mesurer le skill de build) sur des
  offres creuses = mesurer la chance, pas le skill. **La propre logique de séquencement du brouillon
  se retourne** : si « enrichir le contenu avant le ranked » justifie les types en P1, ça justifie
  *a fortiori* combler les trous reliques. **Adopté en P1.5** (data-only, gated → golden inchangé).

### 1.10 ADOPTÉ (REMPLACE l'option « unités T5 lockées ») — Méta-progression = Codex de connaissance, jamais de puissance

**Source** : retention §2.2/Prop-B. **Tranche une contradiction interne du brouillon.**

- **Preuve** : le brouillon flotte entre « Grimoire = codex de connaissance » (bon) et « unités T5
  lockées à débloquer » (Balatro §7.8 — repris dans §10). Ces deux modèles sont **opposés**. 10
  unités T5 lockées = **12 % du pool T5 manquant** = nuit à la diversité des builds T5 ET viole
  « égalisateurs, pas gates » (00-state.md §0). Kammonen 2023 (theseus.fi) : les unlocks de
  *contenu* déplacent la satisfaction *hors* du run.
- **Décision** : **rejeter les unités lockées** (analogie paresseuse Balatro non transférable :
  chez Balatro les Jokers lockés sont des *outils*, le pool reste suffisant sans eux ; chez nous
  ils gateraient des *archétypes*). **Monter le Codex des synergies découvertes** (§10 du brouillon)
  en chantier réel : tracker les 12 interactions de `tests/synergies.lua` → badge grimdark. RENDER
  + écoute du bus, écrit dans `grimoire.lua` (hors SIM), **0 invariant**.

### 1.11 ADOPTÉ (PRÉCISION) — Bonus de complétion de run (anti-abandon), MAIS faible

**Source** : progression-economy §2.5/§3.4. **Mais attention à l'interaction avec la grille
sans-pénalité de ranked (§1.3).**

- **Preuve** : la grille de score crée une **incitation perverse à concéder tôt** (jeter une mauvaise
  run pour limiter le delta), problème réel du loss-streak intentionnel (tft.md §4.7). Remède :
  `COMPLETION_BONUS` pour tout run mené à sa fin naturelle (analogue clé garantie HS Arena).
- **Synthèse critique** : avec la grille **sans-pénalité** que j'ai adoptée (§1.3), l'incitation à
  concéder est **déjà fortement réduite** (chute 0-5v = 0, pas de perte à limiter). Le
  `COMPLETION_BONUS` devient un **petit + de confort** (décourage l'abandon UI), pas un correctif
  structurel. → adopté **petit** ([PH] +1, à ne pas empiler sur une grille qui n'a plus de −1) ;
  priorité abaissée. Évite le double-remède.

### 1.12 ADOPTÉ (REMPLACE) — « Dernier Souffle » = sauvetage AVEC DETTE, pas bonus de consolation

**Source** : retention §2.6/Prop-D. Affine une idée « à l'étude » du brouillon (§10).

- **Preuve** : le « Dernier Souffle » version brouillon (1-parmi-3 bonus à 0 vie) **convertit les 5
  vies d'un axe de pression en checkpoints** — réduit la tension dramatique (le « one more run » de
  SAP marche *parce que* la mort est nette). Remède : sauvetage **coûteux** (−1 niveau d'équipe, ou
  relique désactivée 1 combat), façon Ascender's Bane (StS A10) : « Tu as survécu. Le Puits a pris
  son dû. » Crée une *situation de jeu* (jouer affaibli), pas une bouée. **Reste « à l'étude »**
  (risque non nul), mais reformulé.

### 1.13 ADOPTÉ (correction de source) — Goal-gradient, pas Amabile & Kramer, pour les paliers de type

**Source** : retention §2.4. Correction d'attribution **valide et utile pour la rigueur du lab**.

- Amabile & Kramer 2011 (HBR) = motivation de *travailleurs sur projets longs porteurs de sens* ;
  l'extension à « activer un palier de type » est analogique non vérifiée. La source correcte du
  « 3/4 du palier visible accélère l'effort » est la **goal-gradient hypothesis** (Hull 1932 ; Nunes
  & Drèze 2006, *Endowed Progress Effect*) — **directement** vérifiable (TFT a calibré ses seuils sur
  ce comportement). **Adopté** : la roadmap cite désormais goal-gradient pour le compteur « Burn 3/4 ».

---

## 2. CRITIQUES REJETÉES (ou rétrogradées) — avec le POURQUOI

### 2.1 REJETÉ pour l'instant — « Fenêtre de verrouillage XP en early » (progression-economy §3.1)

- **Claim** : en tier-1 (boutique 100 % rang-1), BUY_XP n'a pas de coût d'opportunité → rush XP par
  défaut → courbe cassée ; remède = désactiver/renchérir BUY_XP rounds 1-2.
- **Pourquoi rétrogradé** : l'analyse du *problème* est **juste et bien vue** (je la conserve comme
  cible de sim). Mais le *remède* (verrouillage early) **ajoute une règle conditionnelle** (« BUY_XP
  indisponible R1-2 ») qui alourdit la gestion — contraire à la boussole « simplicité de gestion »
  (00-state.md §0). La lentille **reconnaît elle-même** une alternative plus propre (XP passive nulle
  R1-2) ET admet (§Q1) que la tension pourrait suffire **dès tier-2 sans verrou**. **Verdict** :
  pas de nouvelle règle tant que la sim n'a pas *prouvé* le rush-sans-coût. → **devient une cible de
  la passe d'équilibrage P3** (mesurer « tier moyen R3 : rush vs passif »), pas un chantier. La
  charge de la preuve est sur la sim, pas sur une règle ajoutée a priori.

### 2.2 REJETÉ — Synergies de type ancrées dans l'adjacence comme DÉCISION ACTÉE (synergies §3/P1-C)

- **Claim** : le compteur de palier de type doit se calculer sur les **voisins du même type**
  (arêtes du sigil), pas le total du plateau — couple placement+composition, signature The Pit.
- **Pourquoi PAS adopté comme acté (mais gardé comme litige fort)** : l'idée est **séduisante et
  thématiquement juste**, MAIS **3 autres lentilles tirent vers la lisibilité simple** : units-power
  (§Q2 : « simple global vs riche adjacence, à débattre »), retention (toute sa thèse = ne pas
  écraser la lisibilité), et la synergies-lens elle-même **pose la question ouverte** (§Q2) sans la
  trancher. Ancrer le palier dans l'adjacence **superpose deux systèmes spatiaux** (adjacence-aura
  + adjacence-type) sur un compteur que le joueur doit lire en un coup d'œil. Risque : illisible.
  De plus units-power §Q2 note que le palier 2 sur START_SLOTS=3 (67 % du board) interagit déjà mal
  avec l'adjacence. **Verdict** : **Litige #D ouvert** (cf. §3) — à trancher round 2 avec un critère
  opérationnel (lisibilité ≤8 mots + sim de richesse décisionnelle), **pas** à graver maintenant.
  Défaut prudent **proposé** : **compteur global** en v0.9 (lisible), adjacence-type comme *évolution*
  v0.11 si la sim montre que le global produit du « stack sans pensée positionnelle ».

### 2.3 REJETÉ (confirme le brouillon) — « Score de composition estimé » pré-combat (retention §2.3)

- Le brouillon avait *déjà* rejeté le score Chips×Mult (§9). La lentille retention **confirme et
  renforce** le rejet d'une variante (DPS estimé affiché) : trompeur dans un système asymétrique
  (ignore le ciblage déterministe + le tank qui encaisse), induit l'optimisation statique d'un
  nombre (LocalThunk cache le score pré-main *exprès*, GMTK 2024). **Adopté le remplacement** :
  **carte de risque visuelle** (gradient d'exposition par colonne + nombre d'arêtes actives/slot) —
  rend l'exploration *lisible* sans la réduire à une note. Ceci **renforce P0** (lisibilité), je
  l'y intègre (§2.2 de la roadmap).

### 2.4 REJETÉ comme priorité — « Rating par sigil/archétype » (Litige #C du brouillon)

- **Tranché par la lentille ranked** (§2.4), je **ferme le Litige #C** : **rating global unique**.
  Preuve : Backpack Battles = rating global, pas par classe (estnn.com) ; Hades Heat-par-arme est un
  *solo roguelite*, comparaison invalide. Avec 2-3 runs/sem, **5 ratings = 5-10 sem. pour un seul
  rating significatif** = ranked inexploitable. L'incitation à varier les sigils vient de la **daily**
  (seed du jour favorise un archétype) et de la méta, pas du rating fragmenté. **Litige #C : CLOS.**

### 2.5 REJETÉ comme bloquant — « plagueAmp hors-cap = exploit » (relics §2.5, units-power §Q5)

- **Vérifié dans le code par le synthétiseur** : `arena.lua:252` applique `amount = floor(amount ×
  (1+plagueAmp))` **après** et **hors** du clamp `DOT_CAP_MULT=3` (`ops.lua:31`). Donc oui,
  techniquement `plagueAmp` (un `more`) **contourne le cap des `increased`**. **MAIS** : (a) c'est
  **+25 % sur une valeur déjà cappée**, pas un emballement multiplicatif libre ; (b) c'est **gated
  dur** sur « cible sous ≥2 familles d'affliction » (`afflictionCount>=2`) ; (c) un `more` *doit*
  s'appliquer hors du cap des `increased` — c'est le comportement **voulu** de la couche stats
  (`(base+Σflat)(1+Σinc)·Π(1+more)`, 00-state.md §3). **Verdict** : **pas un exploit, pas bloquant.**
  La *bonne* observation des deux lentilles (le double-comptage type×relique×aura) est **réelle mais
  bornée** (synergies §1.4 le démontre : 3 sources d'inc → ~+90 % → `8×1.9=15.2 < cap 24`). →
  **devient un drapeau de sim** (mesurer le headroom mono-build vs généraliste, lift de co-occurrence)
  dans P3, **pas** un chantier de refonte. Le `plagueAmp`-hors-cap est **documenté** comme intentionnel
  (à re-vérifier seulement si la sim montre un combo cassé).

### 2.6 REJETÉ comme acté — « Poison 4 = weaken sur la cadence » & autres twists (synergies §2.2/P1-B)

- **Claim valide** : les twists de palier 4 du brouillon sont **asymétriques** (burn 4 = propagation
  AoE = fort ; poison 4 = « +1 stack cap » = chiffre opaque et faible). Critère adopté : chaque twist
  = **1 règle modifiée, ≤8 mots, puissance comparable** (lift ±0.05 en sim). **Ça, je l'adopte comme
  PRINCIPE.**
- **Pourquoi pas les valeurs précises** : les twists *spécifiques* proposés (poison 4 = weaken-cadence,
  rot 4 = amputation sur HP final, bleed 4 = double si rot…) sont des **propositions de design data**
  à valider en sim, **pas** des décisions — et certains créent des **interactions inter-familles**
  (bleed 4 dépend de rot) qui doublent la complexité de test. **Verdict** : le **principe** entre dans
  la roadmap (§3 types) ; les **valeurs** restent [PH] explicitement ouvertes (round 2 lentille
  synergies + sim). Ne pas graver une table de twists au round 1.

### 2.7 REJETÉ — Séparer le canal des reliques F (runOp) MAINTENANT (relics §2.4/P1)

- **Claim** : les reliques F (`black_summons`, `carrion_ledger`, `beggars_lantern`) sont
  économiques (pick-auto), diluent les offres de build ; StS les met dans un slot shop séparé.
- **Pourquoi différé (pas rejeté sur le fond)** : l'analyse est **correcte**, mais le **canal naturel
  existe déjà dans la roadmap** : le **marchand /3 combats** (00-state.md §7, non codé). Créer un
  *deuxième* mécanisme de séparation dans `rollRelicChoices` en attendant = dette jetable. **Verdict** :
  acter que **les runOp migrent vers le marchand** quand il est codé (P1.5/P3), et que l'offre
  1-parmi-3 se concentre sur A-E. Pas de bricolage intermédiaire. Tracé comme **décision de design**,
  implémentation alignée sur le marchand.

---

## 3. LITIGES OUVERTS (pour le round 2 — VRAIS désaccords non tranchés)

| # | Litige | Camp A | Camp B | Critère de résolution proposé |
|---|--------|--------|--------|-------------------------------|
| **#A** | Ordre P1 (types) vs P2 (ranked) | Brouillon + retention partielle : contenu d'abord (ranked sur contenu mince = méta solvée 1 sem.) | ranked §Q1 : daily AVANT ranked permanent peut suffire à la rétention early ; types pas forcément avant | retention §2.5 reformule : « **rotation vs stagnation** », pas « contenu vs ranked » → sim « compo dominante par sigil » : si 5 sigils = 5 métas, ranked peut venir avant types |
| **#B** | Double-comptage inc% (types × reliques B × auras) | borné par cap ×3 (synergies §1.4, **confirmé code**) | la compression du headroom mono-vs-généraliste reste à mesurer (units §Q5) | sim **lift de co-occurrence** sur builds mono-type committés AVANT de figer les valeurs [PH] de palier. **plagueAmp hors-cap = drapeau, pas refonte** (§2.5) |
| **#D** *(NOUVEAU)* | Compteur de type **global** vs **adjacence-type** | synergies §3/P1-C : adjacence = signature, couple placement+compo | units/retention : global = lisible ; superposer 2 systèmes spatiaux = illisible | round 2 : critère **lisibilité ≤8 mots** + sim « stack-sans-pensée » (global) vs « richesse décisionnelle » (adjacence). Défaut prudent : **global v0.9 → adjacence v0.11 si sim le justifie** |
| **#E** *(NOUVEAU)* | Remède au hunt de 3e copie : **pity-tracker** vs **freeze** vs les deux | retention : pity-tracker visible (goal-gradient) | progression-economy : freeze avec coût en slot (SAP/HS:BG) | les deux sont déterministes, RENDER+state ; **freeze touche la distribution → adapter test cotes**. round 2 : sim « hunt médian » d'abord (§P3), puis choisir le remède le moins coûteux qui passe sous le seuil |
| **#F** *(NOUVEAU)* | 6e type non-DoT : 1 type « Taunt » / 2 types « Carapace+Brute » / aucun | units §2.4 opt.1 (Taunt seul) ou opt.3 (aucun) | synergies §2.3 opt.B (Sentinel = axe *trigger* on_attacked, pas rôle) | round 2 : trancher par **axe mécanique commun** (un type doit faire *une* chose). Convergence units+synergies = **rejeter le fourre-tout tank/shield/bruiser** ; choix entre Taunt-seul / Sentinel-trigger / rien |
| **#A2** | Fate event / « Dernier Souffle » : exister ? et à quel coût | brouillon : 1-parmi-3 à 0 vie ; ranked §Q5 : à 1 vie restante | retention §2.6 : sauvetage **avec dette** (−1 niv.) sinon dilue la tension des 5 vies | round 2 : ne pas trancher avant que la grille de score + le filet SAP existant soient figés (interaction) |

**Litiges CLOS ce round** : #C (rating par sigil → **global**, §2.4). Le **double-comptage
plagueAmp** est rétrogradé de « exploit » à « drapeau de sim » (§2.5).

---

## 4. PREUVES NOUVELLES APPORTÉES CE ROUND (ce qu'on sait de plus qu'au brouillon)

1. **Code lu (units-power)** : redondance paramétrique confirmée dans `units.lua` (emberling≈
   pyre_tender ; razorkin≈gash_fiend) → l'audit identité n'est pas hypothétique.
2. **Code vérifié (synthétiseur)** : `swarm_logic` **absent** des 21 reliques (grep=0) ; **aucune
   relique-B pour le choc** (familles = poison/burn/bleed/rot) ; `plagueAmp` appliqué **hors cap**
   `DOT_CAP_MULT` (`arena.lua:252` vs `ops.lua:31`) — mais c'est un `more` gaté, comportement voulu.
3. **Maths de hunt (2 lentilles convergentes)** : 3e copie rang-3 en T3 ≈ **12 rerolls** (retention) ;
   rang-2 spécifique ≈ **6.5 %/boutique** → ~9 rounds (progression-economy). → le pool de 83 **exige**
   un correctif de duplication (pity ou freeze).
4. **Grille de score = patch Bazaar S2** (ranked) : la grille du brouillon hérite des bugs S1
   (safe-play) + S2 (lose intentionnel), inadaptée à 10-15 runs/saison.
5. **Floors = double système LP/MMR** documenté comme confusion #1 (ranked, immortalboost/boosteria)
   → incompatible avec notre contrainte de lisibilité.
6. **Source corrigée** : paliers de type = **goal-gradient** (Nunes & Drèze 2006), pas Amabile &
   Kramer 2011 (retention §2.4).
7. **Choc = seul axe à payoff non-contrôlé** (synergies+units) : argument mécaniste (PoE
   on-hit-only) qui **transforme « +contenu » en « décider l'axe d'abord »**.

---

## 5. IMPACT SUR LE SÉQUENÇAGE (résumé du diff roadmap)

```
AVANT (v1) :  P0 lisibilité → P1 types → P2 ranked → P2bis daily → P3 équilibrage+pool+reliques-qualité → P4 sigils+saisons → v1.0 backend
APRÈS (v2) :  P0 lisibilité(+carte de risque) → P0.5 AUDIT IDENTITÉ+CHOC-axe(data,0 code) →
              P1 types(compteur GLOBAL par défaut, twists=1-règle, sources corrigées) →
              P1.5 COMPLÉTUDE RELIQUES(wide/shield/choc-amp ; runOp→marchand) →
              P2 ranked(grille SANS pénalité, PAS de floor, (bucket,wins_at_capture)) +
              P2bis daily(score EFFICIENCE distinct) + Codex synergies(connaissance) + pity/freeze →
              P3 équilibrage(rush-XP, double-comptage, plagueAmp-flag, slot-decline) →
              P4 sigils+saisons(6-8 sem., perte-max lisible) → v1.0 backend
```

**Gains mesurables vs v1** : +2 chantiers de contenu placés *avant* les systèmes qui en dépendent
(dérisquage) ; 4 mécaniques ranked corrigées avec source (grille, floors, matchmaking, daily-score) ;
3 litiges nouveaux **nommés** (#D/#E/#F) + 1 clos (#C) ; 7 sources/chiffres ajoutés ; 1 invariant
(#3) explicitement marqué « à modifier AVANT le code ».

---

*Synthèse du round 1 actée le 2026-06-23. Lecture seule du repo (vérifs code citées). N'édite que
sous `docs/roadmap-lab/`. Piliers respectés. Litiges #A/#B/#D/#E/#F/#A2 ouverts pour round 2 ;
#C clos. La roadmap intégrée v2 est dans `ROADMAP-draft.md`.*
