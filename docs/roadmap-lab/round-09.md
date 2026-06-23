# Round 09 — Synthèse adversariale (9/10)

> **Méthode** : intégration critique des 6 lentilles `rounds/r09-*.md` contre le brouillon v9
> (`ROADMAP-draft.md`, intégré round 8). On **adopte** les critiques valides et sourcées, on
> **rejette/nuance** les faibles (avec raison mécaniste), on **consigne** les vrais litiges pour le
> round 10. C'est un débat, pas une addition. **3 claims de code/constantes revérifiés ce round par le
> synthétiseur** dans `00-state.md` (lu dans le code, session 2026-06-23) :
> 1. `00-state §4.1` : `GOLD_PER_ROUND=10`, `REROLL_COST=1`, **coût d'achat = rang** → le ratio
>    reroll/achat dérive **1:1 (T1) → 1:5 (T5)** (confirme progression §2.1).
> 2. `00-state §4.3` : **les cotes rang-3 sont à 0 % en T2** (table : T2 = R1 70 / R2 30 seulement) →
>    confirme que `engagement_rate_T2 = P(achat rang-3 en T2)` est **mécaniquement impossible**
>    (progression §2.3 = correct).
> 3. `00-state §4.1` : `XP_TO_LEVEL={2,5,8,12}` dans le code ; la roadmap teste `{2,5,10,18}` vs
>    `{2,5,10,20}` (§7.1) — le candidat de courbe est bien un **placeholder à trancher en sim**,
>    pas la valeur actuelle.
>
> **Garde-fou** : lecture seule du repo, écriture uniquement sous `docs/roadmap-lab/`. Piliers intacts
> (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural). 32 invariants
> préservés (toutes les adoptions sont RENDER / IO / data / doc / sim / config ou décision éditoriale).

---

## 0. Ce qui change ce round (résumé exécutif)

**Le round 9 est un round de CALIBRAGE et d'ALIGNEMENT PAYOFF↔STRATÉGIE.** Les rounds 4-7 ont chassé les
trous de contenu ; le round 8 a attaqué les hypothèses systémiques. Le round 9 fait deux choses neuves :
(a) il **recalibre des seuils qui étaient posés "au jugé"** en les ancrant sur la mécanique réelle lue
dans `00-state` (deux seuils d'alarme éco se révèlent **faux** — l'un trop bas, l'autre impossible) ; et
(b) il découvre une **classe de bug d'alignement** qui traverse 3 lentilles : des payoffs (relique
`plague_communion`, signal `CONTRE LA MORT`, badge MAÎTRE, choc axe D) qui se déclenchent sur la **mauvaise
cause** (la cible / l'exposition / la chance de shop / l'adversaire) au lieu de la **stratégie du joueur**
qu'ils sont censés récompenser. **La leçon de méthode tient une 5e fois** : 3 greps de constantes ce round
tranchent ou démolissent des seuils que 8 rounds avaient laissés passer.

**Le fil rouge inter-lentilles de R09 — l'ALIGNEMENT PAYOFF↔AGENCE :**
quatre lentilles indépendantes (reliques, rétention, synergies, ranked) convergent sur le **même défaut
structurel** : un effet "récompense" qui se déclenche sur une cause **non contrôlée par le joueur**
n'est pas une récompense de skill, c'est du bruit attributionnel.
- **Reliques §2.2** : `plague_communion` se déclenche sur les afflictions de la **cible adverse**, pas sur
  la composition du **joueur** → un build mono-famille avec contagion la déclenche, un build multi-famille
  restrictif ne la déclenche pas. En async, le flag profite au ghost selon ce que **l'adversaire** a subi.
- **Rétention §2.2** : le badge MAÎTRE se déclenche sur la **découverte** (avoir vu l'apex en boutique),
  pas sur la **victoire avec l'apex joué** → SDT-contenu (type 2) renommé SDT-compétence (type 3).
- **Rétention §2.1** : le signal `CONTRE LA MORT` attribue la survie au **Puits** (acteur externe) au lieu
  de la **décision de placement du joueur** → réduit l'agence perçue au lieu de la renforcer.
- **Synergies §2.3 + units §2.3** : le choc axe D se déclenche selon que **l'adversaire** a un DoT actif,
  hors contrôle du joueur → la hiérarchie choc < poison est d'abord un problème de **fiabilité de
  déclenchement**, pas de puissance.

**= un nouveau critère transversal adopté ce round (`#JJ`) : tout payoff de build doit être ancré sur une
cause CONTRÔLÉE PAR LE JOUEUR (composition / placement / décision), pas sur la cible, l'exposition ou
l'adversaire.** Ce critère ré-attaque le pilier async : en snapshots, "ce que l'adversaire a fait" n'est
pas reproductible côté joueur.

**14 adoptions majeures (toutes data/doc/sim/RENDER/config, 0 invariant) :**

1. **`plague_communion` mal aligné : se déclenche sur la CIBLE, pas sur la COMPO du joueur** (relics §2.2/
   Prop-A) → corriger en `dot_family_count ≥ 2` du build du joueur (lu au `combat_start`). ~5 lignes data,
   golden à grep avant. **Le payoff multi-affliction devient enfin le payoff RELIQUE des builds multi-types
   (interagit avec P1).** ⟹ ferme le bug d'alignement le plus net du round.
2. **Seuil d'alarme régime 1 `reroll_dominance_T1 > 0.25` est TROP BAS** (progression §2.3) — recalibré sur
   la mécanique : `P(voir cible rang-1/reroll) ≈ 42 %` → 3 rerolls = 80 % de certitude = 30 % du budget =
   **comportement sain**. → **nouveau seuil `> 0.45`** ET `achat_rang_1_T1 < 1.5` (les deux conditions).
3. **Seuil d'alarme régime 2 `engagement_rate_T2 = P(achat rang-3 en T2)` est MÉCANIQUEMENT IMPOSSIBLE**
   (progression §2.3, **code-vérifié synthé `00-state §4.3` : rang-3 à 0 % en T2**) → **redéfinir** :
   `P(2e achat même famille rang-2 en T2 vs 1er achat famille différente)` = la vraie décision d'engagement.
4. **`REROLL_COST=1` n'est PAS un placeholder neutre : son coût RELATIF dérive 1:1→1:5 de T1 à T5**
   (progression §2.1, **code-vérifié coût=rang**) → documenter l'INTENTION dans le tableau §7.0 AVANT la sim
   P3 (statique voulu vs scalant vs soft-cap), avec un signal d'alarme `reroll_T5 > 2.5× reroll_T1`.
5. **Signal de coût d'opportunité du SLOT-UNLOCK (symétrique à §2.5bis pour BUY_XP)** (progression §2.2) :
   le slot-decline `+3 or` se décide aveuglément (horizon différent non affiché). Ajouter une ligne
   contextuelle grimdark. ~1 h RENDER.
6. **Le rôle de la PASSIVE XP (levier mécanique [A] vs rituel de temps [B]) doit être DÉCLARÉ avant la 6e
   métrique** (progression §2.4) → documenter dans §7.0 ; détermine si `passive_vs_bought_ratio` est le bon
   KPI pour la passive (si [B], cible 15-25 % naturelle, ne pas "buffer" la passive si <20 %).
7. **Signal `CONTRE LA MORT` (§2.10) reformulé : attribution à l'AGENCE DU JOUEUR, pas au Puits** (retention
   §2.1/Prop-A) → "[NOM] A TENU — [TON PLACEMENT/TA SYNERGIE] L'A MAINTENU EN VIE" + ligne atmosphérique.
   0 coût supplémentaire. ⟹ corrige une faille d'attribution dans un système déterministe répété.
8. **§2.10 BLOQUÉ jusqu'à CONFIG-SURVIVAL : le seuil ≥75 % PV perdus est un placeholder non calibré PAR
   RÔLE** (retention §2.4/Prop-D) → mesurer `P(hp_ratio < 0.25 | victoire | rôle)` ; sinon le signal est
   banal pour les tanks (taunt fait son travail) et jamais déclenché pour les carries. ~15 lignes sim.
9. **Badge MAÎTRE reformulé : VICTOIRE AVEC L'APEX JOUÉ, pas DÉCOUVERTE** (retention §2.2/Prop-B) → SDT-
   compétence réel (skill use, arXiv 2502.07423) ; PRATICIEN = ≥1 run avec apex dans le build (même sans
   victoire). +1 bit/run dans `grimoire.lua`. ~1 h.
10. **Hiérarchie du one-more-run S1 explicitée : near-miss (§2.3) PRIMAIRE, identité (§2.4bis) SECONDAIRE**
    (retention §2.3/Prop-C) — sans communauté visible, le near-miss actionnable est le driver de restart ;
    l'identité l'amplifie mais ne l'initie pas. La dépendance est **unidirectionnelle** (§2.4bis ne compense
    pas une faiblesse de §2.3). Doc pur.
11. **Métrique `combat_effect_legibility` = PRÉCONDITION de #FF ET de §2.10** (synergies §2.1, **Q3 r08
    réintroduite**) : un tick peut déclencher 6-12 événements bus simultanés ; au-delà de 3-5, le joueur ne
    perçoit rien (NN/g). Mesurer avg/max events/tick ; règle de BATCHING + priorité d'affichage si > 4.
    ~10 lignes sim. ⟹ une profondeur invisible (#FF, relief) est une profondeur inexistante.
12. **Palier CHOC-4 jamais spécifié en 9 rounds = co-bloquant avec #GG** (synergies §2.2, units §2.3/P-B) :
    burn-4/bleed-4/rot-4 ont un candidat twist nommé, **choc-4 = vide**. Spécifier 2 candidats (Option A
    `shockChain arc` si axe A/B ; Option B `tickCount=2` si axe D) à co-trancher avec #GG. **#HH neuf.**
13. **CONFIG-CE2 : la hiérarchie choc < poison est d'abord un problème de FIABILITÉ de déclenchement (axe D
    conditionnel à l'adversaire), pas de puissance** (synergies §2.3, units §2.3) → mesurer
    `discharge_effective_ratio` par config adversaire ; alarme < 0.40 → corriger la fiabilité (unité auto-DoT
    OU axe A/B), pas la magnitude. ~20 lignes sim. ⟹ complète les 3 mesures P0.5 qui ne l'isolent pas.
14. **Collision d'identité famille burn de `skull_colossus` (carry burn + tank-carry + dominance DPS sur les
    T3 légitimes) = enrichir le remède #GG** (units §2.1, **DPS recalculés**) : 0.131 burn `on_hit` aggro=40
    domine `ash_maw`(0.100)/`plague_pyre`(0.107) → **inverse le contrat rang-5**. Niche exclusive proposée :
    "burn sacrificiel à la mort d'allié" (`on_death` allié, 0 moteur), retire aggro=40.

**9 adoptions de précision / métrique / doc (doc ou sim) :**
- **Critère `#JJ` ALIGNEMENT PAYOFF↔AGENCE** (transversal, §1.0 ci-dessus) : doc dans §10 (liste des
  garde-fous) + §4.11 (hiérarchie reliques).
- **Critère éditorial des COURONNEURS (reliques E doivent OUVRIR une dimension de décision)** (relics
  §2.1/Prop-B) : placement / inter-familles / condition de composition — sinon = SHAPER tier-2/3, pas E.
  S'applique aux E **futures** (P1.5b+), pas aux 4 existantes (documenter honnêtement leur statut partiel).
- **Reliques A (universelles) n'alimentent PAS l'identité de run — choix ACCEPTÉ à documenter** (relics
  §2.3/Prop-D) : ≥89 % des offres early contiennent une A (hypergéo) → le nom de build est un fallback
  jusqu'au round 2-3, c'est voulu (évite la re-découverte d'un "bug" qui n'en est pas un).
- **3 archétypes économiques des reliques F à documenter AVANT le marchand P1.5c** (relics §2.5/Prop-C) :
  `carrion_ledger`=rush-tier / `black_summons`=spike-mid / `beggars_lantern`=max-dup. Sinon le marchand
  les vend sans décision stratégique lisible.
- **`feeding_frenzy` est un AMPLIFICATEUR de build engagé, pas un ÉGALISATEUR de matchup** (relics §2.4) :
  `on_death` snowball = fort quand on gagne, silencieux quand on perd (Wayline : luxury vs enabler). Corriger
  la **classification** dans `relics-design.md §1` (≠ retirer la relique) + la pertinence d'offre la cible
  aux builds aggro ≥20.
- **Directionnalité de #FF (ordre fixe → asymétrie non documentée)** (synergies §2.4) : "feu aggrave
  pourriture" (directionnel, 0 moteur) vs symétrique (2 passes, ~5 lignes, rebaseline possible). À trancher
  AVANT d'écrire le test #FF. **#II neuf.**
- **Test 14 `aura_bakée × palier_teamFlag`** (synergies §2.5) : ~8-10 lignes, zone sans test §8 ; confirme
  l'additivité `increased` (`stats.lua:resolve`) ; interaction certaine de P1 (chaque famille a ≥1 aura).
- **Flag de compatibilité sigil pour les auras DoT rang-3/4 (col J actionnable)** (units §2.4/P-C) : calcul
  sur `shapes.lua` ; alimente le tooltip ET informe P1 (si un palier-4 prescrit une aura hostile au sigil
  naturel de l'archétype = problème de SPEC P1, pas d'unité). Toutes les auras r3 passent "≥3/5 sigils",
  mais l'incompatibilité bleed=ligne reste un piège.
- **Audit `burst_DPS_eq` de `galvanizer` CONDITIONNEL à l'axe D (#GG)** (units §2.3/P-B) : l'axe D change
  la valeur de `dynamo_priest` (transfer multi-cible) vs `galvanizer` (mono-cible) → ne pas figer avant #GG.

**5 ré-ancrages / corrections d'analogie :**
- **Plancher "≥2 enablers/rang-3" doit compter les POSEURS ACTIFS (on_hit), pas les auras** (units Q3) :
  sinon burn-r3 (`bellows_priest` + `soot_acolyte` aura) "passe" artificiellement alors que le désert est
  réel. ⟹ le désert rang-3 burn est confirmé sans ambiguïté.
- **`soot_acolyte` n'est pas un substitut à `bellows_priest`** (units §2.2) : aura = amplificateur du rang-2,
  pas un twist rang-3 (SAP : "each tier = a new mechanic"). Le désert burn ne se résout pas en "documenter
  l'aura comme alternative" → métrique `--burn-progression-gap` pour trancher voulu/trou.
- **"SAP Arena = notre réf ranked async" est une analogie paresseuse** (ranked §4.1) : SAP Arena (IA, casual,
  jamais de ranked) ≠ SAP async-versus / SAP v0.41+ ranked (saisons ajoutées APRÈS coup). Distinguer dans les
  annotations §6.1 : "SAP Arena = réf RUN-structure" vs "SAP v0.41+ = réf SAISONNIÈRE".
- **LoL LP comme ancrage de CALIBRAGE est invalide (comme TFT round 8)** (ranked §4.3) : rank inflation
  2023-2026 + hard reset Masters+ 2026 = LoL n'a pas de calibrage stable. §6.2 ne se fonde que sur "1
  tier/saison à 2-3 runs/sem" + `tools/ladder_sim.lua`.
- **Fresh Start (Milkman 2014) incomplet sans INCERTITUDE PARTAGÉE** (ranked §4.2, POE 2) : reset + nouvelles
  règles + incertitude collective. ⟹ pré-annoncer la Contrainte de Saison 24-48 h avant le reset (1 clé
  i18n `ranked.season_preview` + timing), pas l'accompagner.

**Litiges neufs / re-qualifiés / clos :**
- **#JJ (neuf, TRANSVERSAL)** : critère ALIGNEMENT PAYOFF↔AGENCE (cause contrôlée par le joueur). **ADOPTÉ
  comme garde-fou de design**, pas un litige ouvert — il ferme/réoriente `plague_communion`, badge MAÎTRE,
  §2.10, choc axe D.
- **#HH (neuf, synergies §2.2 + ranked §5.1)** : DEUX usages distincts proposés pour le même tag — (a)
  **palier choc-4** Option A (`shockChain arc`) vs Option B (`tickCount=2`) [synergies] ; (b) **Profondeur du
  Puits** per-run vs record-saison [ranked]. **Désambiguïsation requise** : on garde **#HH = palier choc-4**
  (co-bloquant #GG), et on renomme la 2e en **#KK (Profondeur du Puits)**.
- **#II (neuf, synergies §2.4)** : directionnalité de l'aggravation croisée #FF (asymétrique ordre-fixe vs
  symétrique 2 passes). Doc avant le test #FF.
- **#KK (neuf, ranked §5.1)** : Profondeur du Puits per-run vs record-saison → recommandation : **les deux**
  (per-run au score-screen, record-saison au pré-run).
- **#U RE-QUALIFIÉ (ranked §2.2)** : le critère de Contrainte de Saison "sous-représenté vs bas win-rate"
  est mal posé ; le vrai critère = **"axe RÉSOLU dans `seed/decisions.md` + plus grand écart
  potentiel/réel"**. **Prérequis bloquant** : choc NE PEUT PAS être ciblé tant que #GG n'est pas tranché.
  Fallback S1 = `bleedSlow2x` (bleed résolu, sous-représenté) ; fallback absolu = modificateur de sigil pur
  (`lineSlow2x`, indépendant des familles).
- **#EE-ranked CONFIRMÉ** (ranked §1.2, SAP v0.47 daily mode) : seed daily = combats seuls, shop libre.
- **Aucun litige clos par preuve concluante ce round** (#U seulement re-qualifié, pas tranché).

---

## 1. Adoptions — l'ALIGNEMENT PAYOFF↔AGENCE (le fil rouge de R09)

> Ce bloc regroupe les 4 critiques inter-lentilles qui partagent la même racine : un payoff de build ancré
> sur une cause non contrôlée par le joueur. **Adopté comme critère transversal `#JJ`.**

### 1.0 ADOPTÉ (garde-fou de design, transversal) — Critère `#JJ` ALIGNEMENT PAYOFF↔AGENCE

**Convergence de 4 lentilles** (reliques §2.2, rétention §2.1/§2.2, synergies §2.3, units §2.3). La formule
commune : un effet "récompense" qui s'active sur la **cible** (afflictions adverses), l'**exposition** (avoir
vu une unité), ou l'**adversaire** (sa composition) **n'est pas une récompense de skill** — c'est du bruit
attributionnel qui crée de la **fausse maîtrise** (rétention §2.2 : déception attributionnelle = driver de
churn).

**Pourquoi c'est valide ET nouveau** : 8 rounds ont posé les payoffs (relique multi-affliction, badge,
relief, axe choc) sans jamais vérifier **sur quelle cause** ils s'ancrent. C'est exactement le niveau
systémique attendu. **Spécifiquement pour nos contraintes async** : en snapshots, "ce que l'adversaire a
fait" n'est pas reproductible côté joueur (le ghost est figé, le joueur ne le choisit pas granulairement) →
un payoff ancré sur l'adversaire est **structurellement non-déterministe du point de vue de l'agence**, même
si la sim est déterministe. Sources : keithburgun.net/pick-1-of-3 (decision = orientation distincte sous
contrôle) ; arXiv 2502.07423 (skill use = exercice réel, pas reconnaissance) ; balatrowiki.org/w/Jokers
(conditions sous contrôle du joueur > contextuelles).

**Décision (doc, §10 + §4.11)** : ajouter à la liste des garde-fous de design :
```
#JJ — ALIGNEMENT PAYOFF↔AGENCE : tout payoff de build (relique, badge, signal, palier) doit s'ancrer sur
une cause CONTRÔLÉE PAR LE JOUEUR — composition du build (dot_family_count, copies, aggro), placement
(adjacence via sigil), ou décision (achat/level). JAMAIS sur la cible (afflictions adverses), l'exposition
(unité vue en boutique), ou la composition de l'adversaire (ghost). En async, l'ancrage adversaire est
non-reproductible du point de vue de l'agence du joueur.
```

### 1.1 ADOPTÉ (#JJ, PRIORITÉ 1, ~5 lignes data) — `plague_communion` se déclenche sur la CIBLE, pas sur la COMPO du joueur (relics §2.2/Prop-A)

**Critique (relics §2.2, `relics.lua:57-58` relu ligne à ligne)** : `plague_communion` (`plagueAmp=0.25`,
`teamFlag` posé à `combat_start`) s'active **si la CIBLE a 2+ afflictions actives** (condition réelle dans
`arena.lua:248-252`, `afflictionCount(target.dots) >= 2`, **code-vérifié round 8 par le synthétiseur**).
**Conséquence** : un build mono-famille (burn avec propagation T3) la déclenche ; un build multi-famille
restrictif (bleed pur sans contagion) ne la déclenche pas. En async, le flag profite au **ghost** selon ce
que **l'adversaire** subit — hors contrôle du joueur.

**Pourquoi c'est valide ET converge avec #JJ** : la roadmap (§4.2, §11) classe `plague_communion` comme
"payoff multi-affliction réel" — mais le payoff n'est PAS aligné sur la stratégie qu'il prétend récompenser.
C'est le bug d'alignement le plus net du round, et il **bloque l'interaction avec P1 (types)** : un build
4-poison (1 famille) et un build 1+1+1+1 (4 familles) déclenchent `plague_communion` identiquement si les
cibles ont 2+ afflictions → **la relique la plus transformative du pool est AVEUGLE au choix de familles**,
qui est la dimension build-defining #1 du jeu.

**Pourquoi le synthétiseur ADOPTE (et corrige une décision antérieure)** : la roadmap §4.2 a "GARDÉ TELLE
QUELLE" `plague_communion` (litige #J requalifié round 4), et §11 propose une variante "scalante sur le seuil
RÉEL de la cible". **Les deux maintiennent l'ancrage sur la CIBLE.** Le rejet round 3 de la "reformulation
scalante par famille majoritaire" était correct (trop complexe) — mais il ne valide pas l'original (relics
§2.2 note historique, juste). La correction Prop-A est **plus simple** que la variante §11 : `plagueAmp`
s'active si `build.dot_family_count >= 2` (du JOUEUR), lu au `combat_start`, info déjà disponible post-P0.5.

**Décision (#J RE-TRANCHÉ, ~5 lignes data, garde-fou golden)** :
```
plague_communion (#J FINAL) : plagueAmp=0.25 s'active si dot_family_count(BUILD JOUEUR) >= 2
  (nombre de familles DoT distinctes dans la compo, lu au combat_start). NON sur la cible.
  → devient LE payoff relique des builds multi-types (interagit avec P1 seuil 2/4).
  → PRÉREQUIS : dot_family posé sur chaque unité (P0.5, §3.3).
  → GARDE-FOU GOLDEN : grep le build golden (golden.lua:17, seed 970156547). Si le build a ≥2 familles
    DoT, le flag passe INACTIF→ACTIF → rebaseline EXPLICITE requise (invariant #5). Vérifier AVANT de coder.
  → Annule la variante §11 "scalante sur seuil cible" (maintenait l'ancrage cible).
```
**§4.2 + §11 corrigés. CONFIG-PC (§3.9, magnitude `plagueAmp` bloquante) reste valide** mais sa condition
d'activation change : mesurer l'activation sur `dot_family_count ≥ 2` du joueur, pas sur la cible.
Source : `relics.lua:57-58` ; keithburgun.net/pick-1-of-3 ; #JJ.

### 1.2 ADOPTÉ (#JJ, PRIORITÉ 1, 0 coût) — Signal `CONTRE LA MORT` reformulé vers l'AGENCE DU JOUEUR (retention §2.1/Prop-A)

**Critique (retention §2.1, arXiv 2603.26677 Ordeal Pleasure)** : le signal §2.10 ("[NOM] A TENU — LE PUITS
A FAILLI TE CONSUMER") attribue la survie au **Puits** (antagoniste externe). Or le plaisir d'ordeal dans les
Soulslike vient de la **reconstruction narrative interne** ("j'ai placé le tank en front → il a absorbé le
burst"), pas de la félicitation. Dans un système déterministe répété, le relief est en plus fragilisé : si le
joueur connaît son build, la survie limite est **prévisible** → confirmation, pas relief (la roadmap a
elle-même rejeté le "VRR négatif prévisible" §5.3 v9 — le même argument s'applique au relief prévisible).

**Pourquoi c'est valide MAIS le synthétiseur NUANCE la portée** : la reformulation est juste (attribuer à
l'agence, pas au Puits, converge avec #JJ). **Mais** la critique va trop loin en suggérant que §2.10 ne
"diversifie pas réellement le circuit" : la **différence de valence** (positif vs évitement) reste réelle et
mesurable — un signal de survie-limite, même prévisible sur un build connu, garde une valence distincte d'un
high-roll de boutique. Le round 8 (§5.3 retention r09) le confirme : poids hédonique 2 justifié. **On adopte
la reformulation, on REJETTE la dégradation de §2.10 au rang de "simple second Moment du Run".**

**Décision (P0 RENDER, 0 coût supplémentaire vs §2.10)** :
```
Format §2.10 (corrigé #JJ) :
  "[NOM_UNITÉ] A TENU — [TA SYNERGIE A×B / TON PLACEMENT] L'A MAINTENU EN VIE"
  + 1 ligne atmosphérique : "LE PUITS N'OBTIENT PAS CE QU'IL VEUT"
  Logique : si l'unité survivante est adjacente via une arête active du sigil → "TA SYNERGIE [A]×[B]" ;
            si carry isolé → "SON ISOLATION L'A PROTÉGÉ DES AFFLICTIONS".
  Le Puits reste l'antagoniste ; le JOUEUR reste l'agent.
```
**§2.10 enrichi.** Source : arXiv 2603.26677 ; PMC12412733 (SDT autonomie, causalité interne).

### 1.3 ADOPTÉ (#JJ, PRIORITÉ 1, ~15 lignes sim — BLOQUE le code §2.10) — CONFIG-SURVIVAL : calibrer le seuil par RÔLE (retention §2.4/Prop-D)

**Critique (retention §2.4)** : le seuil "≥75 % PV perdus" de §2.10 est un placeholder non calibré. Avec
`HP_MULT=2` (combats longs) et des familles aux ticks variables, un **tank** à 25 % PV est fréquent (taunt
fait son travail = banal, pas un miracle) ; un **carry** à 25 % PV est rarissime (jamais déclenché). Le seuil
brut inverse la signification émotionnelle par rôle. La Q_R8_1 posait la question sans réponse.

**Pourquoi c'est valide** : un signal VRR n'est efficace que s'il est **rare et significatif** ; un seuil qui
se déclenche systématiquement pour les tanks et jamais pour les carries détruit la rareté dans les deux sens.
C'est une précondition de calibrage, pas un tuning ultérieur.

**Décision (BLOQUER le code §2.10 jusqu'à CONFIG-SURVIVAL, ~15 lignes sim)** :
```
CONFIG-SURVIVAL : N=200, seed 20260620
  → pour chaque victoire, logger {unit_id, hp_remaining/maxHp, family, role}
  → P(hp_ratio < 0.25 | won | role) pour tank / bruiser / carry (role dérivé de aggro :
    aggro≥40 = tank, aggro≤8 = carry, reste = bruiser — lu dans units.lua)
  → décision :
    si P_tank > 0.4   → exclure role=="tank" du signal OU seuil tank < 10 % HP (le taunt rend 25 % banal)
    si P_carry < 0.05 → DA : signal exclusif tanks/bruisers OU seuil carry abaissé (20 % HP pour les frêles)
```
**§2.10 enrichi + §11 (CONFIG-SURVIVAL) ajoutée.** Croisé avec la règle de priorité (§4.4 ci-dessous : si
§2.10 ET le Moment du Run §2.4 se déclenchent au même combat → §2.4 principal, §2.10 secondaire).
Source : retention §2.4 ; précondition analogue P75 du Moment du Run (§2.4).

### 1.4 ADOPTÉ (#JJ, PRIORITÉ 2, ~1 h data+RENDER) — Badge MAÎTRE : VICTOIRE AVEC L'APEX JOUÉ, pas DÉCOUVERTE (retention §2.2/Prop-B)

**Critique (retention §2.2, arXiv 2502.07423 skill-use)** : le badge MAÎTRE (§6.7 : "2/2 apex découverts + ≥1
relique-E vue") se déclenche sur l'**exposition** (avoir vu l'apex en boutique au shopTier 5), pas sur
l'**utilisation victorieuse**. C'est du SDT-contenu (type 2) renommé SDT-compétence (type 3). Un joueur burn
peut "découvrir" `festering_lord` (apex poison) sans jamais le jouer → fausse maîtrise → déception
attributionnelle (perd contre bleed, attribue à "la difficulté" au lieu de son manque de maîtrise) = churn.

**Pourquoi c'est valide ET converge avec #JJ** : dans un jeu déterministe, la maîtrise SE MANIFESTE par le
résultat ; un badge qui ne filtre pas les victoires avec l'apex récompense la chance de shop, pas la
compétence. La reformulation ancre le badge sur une cause contrôlée (avoir joué + gagné), pas sur l'exposition.

**Décision (P2 RENDER ~1 h, +1 bit/run, 0 invariant SIM)** :
```
Badge MAÎTRE (corrigé #JJ) : ≥1 victoire de run avec ≥1 apex de la famille dans le build ACTIF au combat
  final (apex présent sur le plateau) + ≥1 relique-E de la famille acquise CE MÊME run.
Badge PRATICIEN : ≥1 run avec un apex de la famille dans le build (même sans victoire) = apprentissage actif.
Données : grimoire.lua stocke +1 bit/run {run_id, dot_family_dominant, apex_used:bool, won:bool}
  (snapshot.units capture déjà les unités du plateau + niveau, 00-state §5). ~5 lignes data.
Effet : taux d'atteinte plus faible mais SIGNIFIANT. Q_R8_2 se résout : PRATICIEN ~3 runs, MAÎTRE ~5 runs
  après un 1er succès (progression réelle, pas seuil abaissé).
```
**§6.7 corrigé.** Q_R9_1 (parité MAÎTRE poison vs choc — `P(run gagné avec apex)` par famille) liée à #GG/
CONFIG-CE : si `P_choc_maître ≪ P_poison_maître`, le badge choc est injuste → mesurer. Zone sans test → test
`apex_used==true` si l'apex figure dans `snapshot.units` du run gagné.
Source : arXiv 2502.07423 (skill use) ; IntechOpen 2025 (maîtrise type 3 manifestée mécaniquement).

---

## 2. Adoptions — Progression & économie (CALIBRAGE sur la mécanique réelle)

> Le round 9 corrige deux seuils d'alarme posés "au jugé" en les ancrant sur les constantes lues dans le code.
> C'est le travail de calibrage le plus précis depuis le début du lab.

### 2.1 ADOPTÉ (PRIORITÉ 1, doc §7.1) — Seuil régime 1 `reroll_dominance_T1 > 0.25` est TROP BAS (progression §2.3)

**Critique (progression §2.3, ancrée `00-state §4.1`)** : le seuil d'alarme `> 0.25` (issu de r08 §2.3)
n'est calibré sur aucune mécanique. Dérivation : budget 10g, rang-1 = 1g, reroll = 1g, `SHOP_SIZE=5`, pool
LOCAL ~12 rang-1 → `P(voir la cible rang-1/reroll) ≈ 5/12 ≈ 42 %` → **3 rerolls = `1−(1−0.42)³ ≈ 80 %` de
certitude = 30 % du budget = comportement SAIN de recherche efficiente.** Le seuil 0.25 (= 2.5 rerolls/10g)
signale comme problématique un comportement économiquement prudent.

**Pourquoi le synthétiseur ADOPTE** : c'est exactement le genre de seuil arbitraire qu'un round adversarial
doit recalibrer. La dérivation est ancrée sur les constantes lues (vérifié `00-state §4.1`). Le seuil corrigé
exige les DEUX conditions (sinon un build qui cherche ET n'achète pas = pool trop homogène, le vrai signal).

**Décision (doc §7.1, ~30 min)** : `reroll_dominance_T1 > 0.45` ET `achat_rang_1_T1 < 1.5` = alarme (pool T1
trop homogène). Mesuré sur la politique **`standard`** uniquement (pas `rush_XP`, qui sur-représente les
rerolls late — Q2 progression). **§7.1 régime 1 corrigé.**

### 2.2 ADOPTÉ (PRIORITÉ 1, doc §7.1 + ~20 lignes sim) — Seuil régime 2 `engagement_rate_T2 = P(achat rang-3 en T2)` est IMPOSSIBLE (progression §2.3)

**Critique (progression §2.3, code-vérifié synthé `00-state §4.3`)** : la métrique r08 définit
`engagement_rate_T2 = P(achat rang-3 au 1er round T2)`. **Mais la table de cotes (`00-state §4.3`) donne
rang-3 à 0 % en T2** (ligne T2 = R1 70 / R2 30 seulement). La métrique **mesure un comportement mécaniquement
impossible.**

**Vérifié par le synthétiseur** : `00-state §4.3`, table des cotes, ligne T2 ne contient que R1 et R2. Les
rang-3 n'apparaissent qu'à 20 % en T3. **La critique est factuellement correcte.**

**Décision (redéfinir, doc §7.1 + ~20 lignes `tools/sim.lua`)** :
```
engagement_rate_T2 (corrigé) = P(2e achat MÊME famille rang-2 en T2 vs 1er achat famille DIFFÉRENTE)
  → mesure si le joueur commence à S'ENGAGER sur un axe (2 rang-2 même famille = pré-activation d'archétype)
    vs diversifier (portefeuille). Cible 40-60 % (ni mono-commit trop tôt, ni diversification plate).
  → tracker les 2 derniers achats par famille en T2 (~20 lignes sim).
```
**§7.1 régime 2 corrigé.** ⟹ détecte enfin le vrai signal d'engagement de T2 (le début d'une identité de build).

### 2.3 ADOPTÉ (PRIORITÉ 0 — DOC BLOQUANTE §7.0) — Documenter l'INTENTION de `REROLL_COST` (coût relatif 1:1→1:5) (progression §2.1)

**Critique (progression §2.1, code-vérifié coût=rang)** : `REROLL_COST=1` est traité comme un placeholder
neutre à trancher en P3 (§7.5). Mais le coût RELATIF du reroll dérive de **1:1 (T1, reroll=achat) à 1:5 (T5,
reroll=⅕ achat)** car le coût d'achat = rang. **C'est une décision de design ACTIVE** : chaque run au T5
incite massivement au reroll plutôt qu'à l'achat. SAP n'a pas ce problème (prix uniformes 3g → ratio 1:3
constant) — The Pit et SAP ont des dynamiques fondamentalement différentes malgré le même `REROLL_COST=1`.

**Pourquoi c'est valide** : "documenter l'intention AVANT de mesurer" est la discipline de design déjà actée
(§7.0, Machinations.io). Le `[TBD]` actuel n'est pas neutre — c'est de la dette qui s'accumule à chaque run.

**Décision (doc §7.0, ~30 min, 0 code)** : ajouter une ligne `REROLL_COST` avec le tableau de coût relatif
complet + l'intention tranchée (statique voulu / scalant T3+ / soft-cap par signal) + le comportement attendu
en sim (`[STATIQUE] reroll_rate_T5 ≤ 1.5× reroll_rate_T1` ; `[SCALANT] reroll_rate_T3 ≈ reroll_rate_T1`) +
signal d'alarme `reroll_T5 > 2.5× reroll_T1`. **Recommandation de fond du synthétiseur** : conserver
`REROLL_COST=1` STATIQUE est défendable en grimdark ("le Puits montre ce qu'il veut" → le late favorise
l'exploration), MAIS le documenter comme VOULU, pas comme [TBD]. **§7.0 + §7.5 enrichis.** Le soft-cap (§3.5
progression, signal avant scalant — préserve l'agence vs le scalant dur Backpack qui a divisé 66/33 %) reste
**conditionnel à la mesure** (ne pas implémenter si `reroll_T5 ≤ 1.5× reroll_T1`).

### 2.4 ADOPTÉ (PRIORITÉ 1, ~1 h RENDER) — Signal de coût d'opportunité du SLOT-UNLOCK (symétrique §2.5bis) (progression §2.2)

**Critique (progression §2.2)** : la roadmap contextualise le coût d'opportunité de BUY_XP (§2.5bis : "+1 XP
= N rounds ou M BUY_XP") mais **il n'existe aucun équivalent pour le slot-decline `+3 or`.** Un joueur voit
"ACCEPTER le slot | REFUSER (+3 or)" sans contexte : 3 or maintenant valent-ils un slot qui durera 8 rounds ?
C'est une décision à **horizon différent** non affichée — la sim mesurerait un comportement de joueur aveugle.

**Pourquoi c'est valide (et nouveau vs rounds 6-7)** : les rounds 6-7 ont traité la MÉCANIQUE du slot-decline
(`SLOT_DECLINE_GOLD=3`, trade tall/wide) ; cette critique porte sur le **SIGNAL** autour de la mécanique,
exactement symétrique à §2.5bis. La progression LA PLUS VISIBLE du jeu (la grille qui grandit) n'a aucun
signal de coût d'opportunité.

**Décision (RENDER ~1 h, 0 SIM)** : ajouter une ligne contextuelle sous l'offre de slot, grimdark et
**sans prescription** ("Le Puits t'offre l'espace — ou son prix" ; le mot "optimal" interdit) — ex. early :
"Un slot = espace pour N unités d'ici la fin du run" ; T3+ : "Refuser = 3 or (= X XP équivalents)". Précondition :
tableau §7.0 inclut l'intention de `SLOT_DECLINE_GOLD`. Zone sans test → test du label aux cas limites
(slots=9 = pas d'offre ; slots=3 = début). **§2.5bis enrichi d'un volet slot.** Q1 progression (grants liés
ou non aux victoires) reste **ouverte** → recommandation (a) garder les grants fixes rounds 2-7 (signal de
temps, non lié au skill, compatible "égalisateurs pas gates") — à documenter §7.0.

### 2.5 ADOPTÉ (PRIORITÉ 1 — DOC SEULE §7.0) — Déclarer le RÔLE de la PASSIVE XP avant la 6e métrique (progression §2.4)

**Critique (progression §2.4)** : avant de mesurer si la passive (1/round) est "levier ou bruit" (6e
métrique `passive_vs_bought_ratio`), la roadmap doit décider **ce que la passive EST censée être** : [A]
levier mécanique (contribue à la courbe XP) ou [B] rituel de temps (signal de progrès perçu même en défaite,
Amabile & Kramer 2011). À 1/round sur 15 rounds (~13 XP), [A] est faible. Si [B], le chiffre 1 est un token
et `passive_vs_bought_ratio` n'est PAS le bon KPI pour la passive.

**Pourquoi c'est valide** : cette décision ne coûte rien (doc) mais détermine l'interprétation de la 6e
métrique. Si [A], cibles 20-50 % ; si [B], cible naturelle 15-25 % sur un run actif (ne pas "buffer" la
passive si <20 %, mais améliorer le signal §2.5bis).

**Décision (doc §7.0, ~20 min)** : ligne `XP_PASSIVE_RATE=1` avec INTENTION [A] ou [B] (décision user). Si
[B] → la 6e métrique mesure la santé du BUY_XP uniquement (cible bought 60-85 %). **§7.0 enrichi.**

> **Note factuelle du synthétiseur (incohérence mineure à signaler)** : le fichier progression r09 cite, dans
> sa section "Sources web", "TFT XP passive = 2/round" (wiki.leagueoflegends.com) — ce qui est CORRECT pour
> TFT. The Pit utilise **1/round** (`00-state §4.1`), une divergence DÉLIBÉRÉE déjà actée (round 8 : "2
> XP/round ≠ nos 1/round ; calibrage sur NOS contraintes"). Aucune contradiction de fond. Le même fichier dit
> au §1.2 "ratio BUY_XP 1:1" puis au §1.2-bis "identique à TFT 4:1" — coquille interne (TFT dépense 4g pour 4
> XP = face-value, comme nous) ; la substance (4g=4XP, neutre) est correcte. À ne pas propager.

---

## 3. Adoptions — Synergies & effets (LISIBILITÉ + dette de spec choc)

### 3.1 ADOPTÉ (PRIORITÉ HAUTE, ~10 lignes sim — PRÉCONDITION #FF ET §2.10) — Métrique `combat_effect_legibility` (synergies §2.1, Q3 r08 réintroduite)

**Critique (synergies §2.1, Q3 r08 IGNORÉE par le synthétiseur r08)** : la roadmap n'a aucune métrique de
lisibilité des effets EN COMBAT. Un tick peut déclencher 6-10 événements simultanés (6 familles + bouclier +
aura + propagation kill + contagion hit + décharge choc) ; avec #FF, 8-12. Or la perception simultanée
humaine plafonne à 3-5 éléments (NN/g). **Une interaction #FF invisible dans le pixel art 320×180 n'existe
pas pour le joueur** — la profondeur est dans le code, pas dans l'expérience. **Et** les signaux §2.3
(pourquoi) et §2.10 (relief) lisent le bus JSONL : s'il est trop dense, le signal d'attribution est noyé.

**Pourquoi le synthétiseur ADOPTE (et reconnaît sa propre omission r08)** : la Q3 r08 a été ignorée à tort.
Le round 8 a ajouté §2.10 (lit le bus) et adopté #FF (ajoute des événements) sans jamais poser la lisibilité.
C'est une précondition légitime de DEUX adoptions actées. La référence NN/g (3-5 éléments) est un standard UX
reconnu, appliqué ici à un contexte spécifique (la roadmap doit le documenter comme heuristique, pas comme
loi mesurée — synthétiseur honnête sur le statut de la source).

**Décision (~10 lignes sim, PRÉCONDITION de #FF en §5.4 ET de §2.10)** :
```
PRÉCONDITION LISIBILITÉ (avant #FF ET avant le code §2.10) :
  Mesurer sur N=200 combats (bus JSONL) : avg_events_per_tick, max_events_per_tick.
  Si avg > 4 OU max > 8 → règle de BATCHING obligatoire dans arena_draw.lua :
    - regrouper les ticks de même famille en 1 VFX cumulé ("BRÛLURE ×12" vs 12 ticks)
    - priorité d'affichage : mort > décharge choc > DoT tick > bouclier > regen
  Si avg ≤ 4 → #FF et §2.10 implémentables sans batching.
  Test : la condition se déclenche sur le golden (événements bus comptés par tick).
```
**§5.4 (#FF) + §2.10 enrichis d'une précondition commune. 0 invariant** (priorité d'affichage = RENDER).
⟹ débloque #FF/§2.10 si la lisibilité est OK, les conditionne sinon. Source : synergies §2.1 ; NN/g (3-5
éléments simultanés) ; switchbladegaming.com/balatro-best-joker-combos (interaction = déclencheur observable).

### 3.2 ADOPTÉ (#HH neuf, PRIORITÉ HAUTE — co-bloquant #GG) — Spécifier le palier CHOC-4 avant P1 (synergies §2.2, units §2.3/P-B)

**Critique (synergies §2.2)** : burn-4 (`burnIgnoreShield`), bleed-4 (`bleedPierceShield`), rot-4 (amputation
PV_max le plus élevé) ont un candidat twist **nommé** dans la roadmap. **Choc-4 = vide.** Le litige #GG (axe
A/B vs D pour l'APEX rang-5) a capturé l'attention, mais le **palier-4** (twist P1) doit exister **quelle que
soit la décision d'apex**. `rust_sentinel` rang-4 actuel = `stormcaller` rang-2 (op identique, viole #10,
code-vérifié round 8) → ce n'est PAS un vrai twist choc-4.

**Pourquoi c'est valide** : coder P1 avec un choc-4 absent/vague = les ghosteurs choc qui montent au shopTier
4 ne voient pas de payoff → perception de faiblesse structurelle. C'est le problème de l'apex (round 7) mais
au palier intermédiaire, jamais nommé en 9 rounds.

**Décision (#HH neuf, spec dans §3.7 + §5, co-trancher avec #GG)** :
```
PALIER CHOC-4 (co-décision avec #GG, avant P1) :
  Option A (si #GG → axe A/B pour l'apex) :
    twist = "la décharge arc à 1-2 voisins de la cible (arc électrique)"
    candidat = shockChain déjà câblé (ops.lua:187, dischargeShock:358-378) → 0 moteur (data)
    documenter : interaction avec DOT_CAP_MULT=3 (l'arc ne double pas le cap) ; stacks consommés 1×
  Option B (si #GG → axe D cohérent) :
    twist = "les 2 premiers ticks DoT de la famille du poseur sont amplifiés"
    paramètre tickCount=2 dans tickDots (~3 lignes SIM) ; distinct de l'apex Option 2 (shockAmpMult=
      magnitude) — tickCount=2 = durée d'amplification. Test synergies.lua (invariant #22 étendu).
  Les 2 options dans §5 ; choix tranché avec #GG (même décision).
```
**§3.7 + §5 enrichis. #HH = palier choc-4 (la 2e proposition #HH de ranked → renommée #KK, §5).**
Source : ROADMAP §0 (twist = 1 `more` bornée) ; 00-state §3.1 (caps choc).

### 3.3 ADOPTÉ (PRIORITÉ HAUTE, ~20 lignes sim — P0.5) — CONFIG-CE2 : la hiérarchie choc < poison est un problème de FIABILITÉ, pas de puissance (synergies §2.3, units §2.3)

**Critique convergente (synergies §2.3 + units §2.3, #JJ)** : les 3 mesures P0.5 (`--poison-frac`,
`--no-weaken`, `--pool-repr`) traitent des **leviers de puissance statique**. Mais poison domine d'abord par
son **horizon de payoff court** (stacks dès T2, weaken immédiat non-conditionnel) et choc échoue d'abord par
sa **condition de déclenchement dépendante de l'adversaire** (axe D exige un DoT actif sur la cible, hors
contrôle du joueur en async). Aucune mesure n'isole `P(décharge à vide sur cible sans DoT)`.

**Pourquoi c'est valide ET converge avec #JJ** : c'est la racine mécanique de la hiérarchie choc < poison,
non traitée par les 3 mesures. Le choc axe D est un payoff ancré sur l'adversaire (#JJ) — en async, le joueur
ne choisit pas son ghost granulairement. Balatro (conditions sous contrôle > contextuelles) confirme l'angle.

**Décision (CONFIG-CE2, ~20 lignes sim, P0.5)** :
```
CONFIG-CE2 (Choc Fiabilité — axe D) :
  Compo {1 galvanizer T4 + 1 burn-poseur r2 + 1 bleed-poseur r2} vs 3 configs adverses :
    (a) ghost burn-seul (DoT actif → D favorable) (b) ghost tank-seul (sans DoT → D défavorable)
    (c) ghost mixte. N=20/config, seed 20260623+offset.
  discharge_effective_ratio = nb décharges amplifiant un DoT actif / nb décharges totales.
  Alarme : ratio < 0.40 en config (b) → choc axe D CONDITIONNEL à l'adversaire → décision :
    (A) ajouter 1 unité rang-3 choc qui AUTO-POSE un DoT léger avant de charger (on_attack burn{dps=1}
        + shock{add=1}) = auto-conditionnel, ne dépend plus de l'adversaire (1 ligne data), OU
    (B) recommander axe A/B pour l'apex (burst, non conditionnel) → choc moins dépendant de l'adversaire.
```
**§3.7 matrice sim enrichie.** Non bloquant si ratio ≥ 0.40 (la puissance suffit). ⟹ on ne tune plus à côté.
Source : synergies §2.3 ; units §2.3 ; balatrowiki.org/w/Jokers ; poewiki.net/wiki/Ailment (co-présence).

### 3.4 ADOPTÉ (#II neuf, PRIORITÉ FAIBLE — DOC, précondition spec #FF) — Directionnalité de l'aggravation croisée #FF (synergies §2.4)

**Critique (synergies §2.4)** : la spec #FF dit "la 2e famille active reçoit un `more`". Mais l'ordre fixe
`tickDots` (`burn→bleed→poison→rot→choc→regen`) signifie que la "2e famille" est **toujours la même** pour une
paire donnée → "burn amplifie rot mais rot n'amplifie pas burn" = asymétrie non explicite. Deux lectures :
(a) directionnelle voulue ("le feu aggrave la pourriture", thématique) ; (b) bug de spec (on voulait
symétrique). Aucune n'est problématique, mais la spec doit **trancher** avant le test #FF.

**Pourquoi c'est valide** : sans décision, le test #FF pourrait passer avec une asymétrie non voulue. C'est
une précision de spec à coût nul.

**Décision (#II neuf, doc §5, 0 code)** : documenter le choix — Option A directionnelle (dernière famille de
l'ordre actif reçoit le `more` ; signal UI nomme la relation ; 0 moteur) vs Option B symétrique (2 passes,
~5 lignes, rebaseline golden possible). À trancher AVANT le test inter-famille de #FF. **#II ouvert pour R10.**
Lié à Q2 synergies (la directionnalité change le verdict du tableau de saturation : 1 entrée vs 2).
Source : 00-state §3.2 (ordre fixe) ; ROADMAP §5.

### 3.5 ADOPTÉ (PRIORITÉ FAIBLE, ~8-10 lignes — zone sans test §8) — Test 14 `aura_bakée × palier_teamFlag` (synergies §2.5)

**Critique (synergies §2.5)** : l'ordre de résolution à `combat_start` (bake auras de `shapes.lua` PUIS
`teamFlags` P1) est docté (engine-architecture §8) mais **non testé pour aura + palier sur la MÊME unité**.
`soot_acolyte` (aura `burnInc`) + `grant_team{burnInc=0.20}` (palier burn-2) : additif (correct, `increased`
additif `stats.lua:resolve`) ou écrasement ? Interaction la plus fréquente en P1 (chaque famille a ≥1 aura).

**Décision (test 14 `tests/synergies.lua`, ~8-10 lignes, 0 moteur)** : `soot_acolyte` + `grant_team
{burnInc=0.20}` → `assert |resolved_inc − (aura_inc + 0.20)| < 0.001`. Confirme l'architecture. Zone sans
test §8. **Ajouté à la liste P1.** Source : engine-architecture §8 ; stats.lua.

### 3.6 NON-DÉSACCORDS confirmés (synergies §5) — accords fermes non re-challengés

Le compteur de type GLOBAL PUR (#D clos), seuils 2/4, ordre `--pool-repr` AVANT `--poison-frac` strict (#DD
clos), `bleedPierceShield` (bleed-4), `DOT_CAP_MULT=3`, architecture `grant_team`/`teamFlags`, 12 synergies de
base, `famines_math` tri stable (#O clos), axe D `dot_family` du poseur + fallback : **tous confirmés, non re-
challengés**. La précision utile (synergies §1.4) : ajouter une ligne de flavor grimdark qui NOMME
l'interaction dans le Nom de Build ALCHIMISTE NAISSANT ("ton venin brûle tes blessures") — sinon l'effet
identitaire est réduit. **§2.4bis enrichi (flavor d'interaction).**

---

## 4. Adoptions — Reliques & rétention (alignement, hiérarchie, archétypes éco)

### 4.1 ADOPTÉ (PRIORITÉ 1 — DOC §4.11, 0 code) — Critère éditorial des COURONNEURS : les reliques E doivent OUVRIR une dimension (relics §2.1/Prop-B)

**Critique (relics §2.1, `relics.lua:51-58` relu)** : les 4 reliques E (`forked_tongue`, `everburn`,
`open_wounds`, `plague_communion`) posent toutes un `teamFlag` via `grant_team` à `combat_start` = des toggles
binaires ON/OFF sur des mécaniques existantes. La roadmap (§4.11) les classe "COURONNEURS build-defining" —
mais "burn ne décroît plus" (`burnNoDecay`) est un **ajustement de paramètre**, pas un moment de couronnement.
Burgun/Balatro : une relique build-defining (Dead Branch, Four Fingers) **change la STRUCTURE des décisions
suivantes** ; `everburn` ne change pas les décisions de placement/composition, il amplifie. **Inversion de
hiérarchie émotionnelle** : les 4 B plates (tier-2) sont PLUS build-defining que les 4 E (tier-4).

**Pourquoi le synthétiseur ADOPTE (en NUANÇANT la portée)** : la critique est juste — un COURONNEUR doit
ouvrir une dimension. **Mais** le synthétiseur REJETTE l'implication que les 4 E actuelles sont "ratées" : le
principe #2 (pas de downside, `relics-design.md §1`) est maintenu, et en async une relique sans downside est
préférable (le snapshoteur ne sait pas quels adversaires il affrontera). Le critère s'applique aux E
**FUTURES** (P1.5b+), pas comme un appel à refondre les existantes.

**Décision (doc §4.11, 0 code)** :
```
CRITÈRE DES COURONNEURS (reliques E tier-4 FUTURES, P1.5b+) :
  Une relique E est build-defining ssi elle ouvre ≥1 des 3 dimensions :
    (1) nouvelle décision de PLACEMENT (interaction avec la topologie du sigil actif)
    (2) nouvelle interaction entre FAMILLES de DoT (pas juste amplifier une seule)
    (3) nouveau comportement CONDITIONNEL LIÉ À LA COMPOSITION (dot_family_count, aggro, copies)
  Un toggle de flag sans condition nouvelle = SHAPER (tier-2/3), PAS COURONNEMENT.
Statut honnête des 4 E actuelles : forked_tongue → dimension placement implicite ; everburn/open_wounds →
  amplificateurs (acceptés, principe #2) ; plague_communion → satisfait (3) APRÈS la correction §1.1 (#JJ).
```
**§4.11 enrichi.** Converge avec #JJ : la dimension (3) EST l'ancrage sur la composition du joueur.
Source : keithburgun.net/pick-1-of-3 ; competitive/balatro.md §5.3 ; relics-design.md §1.

### 4.2 ADOPTÉ (PRIORITÉ 1 — DOC, 0 code) — `feeding_frenzy` est un AMPLIFICATEUR, pas un ÉGALISATEUR (relics §2.4)

**Critique (relics §2.4, `relics.lua:39` relu, Wayline luxury vs enabler)** : `feeding_frenzy`
(`on_death frenzy_gain per=0.08 cap=6`) est classée "égalisateur de matchup" (`relics-design.md §1 principe
#3`). Mais `on_death` est différé : dans un matchup FACILE (kill rapide) le bonus arrive après le cap naturel ;
dans un matchup DIFFICILE (tank adverse 40 aggro + `second_breath`) le bruiser peut ne JAMAIS obtenir le 1er
kill → silencieuse exactement quand on en aurait besoin. C'est une LUXE (forte quand on gagne), pas un
égalisateur.

**Pourquoi c'est valide** : Wayline.io (vérifié) — "items most useful when you're already winning are
luxuries, not enablers". La classification actuelle est inexacte (≠ retirer la relique : le snowball est un
archétype valide en tier-3).

**Décision (doc, 0 code)** : corriger la classification dans `relics-design.md §1` → `feeding_frenzy` =
**payoff bruiser/snowball, PAS égalisateur**. La garantie de pertinence (§4.1) doit la cibler aux builds à
aggro ≥20 (bruisers/tanks), pas la proposer à un joueur sans bruiser. **§4.3 + §4.1 enrichis.**
Source : `relics.lua:39` ; wayline.io/blog/roguelike-itemization ; relics-design.md §1.

### 4.3 ADOPTÉ (PRIORITÉ 2 — DOC AVANT P1.5c) — 3 archétypes économiques des reliques F (relics §2.5/Prop-C)

**Critique (relics §2.5, `relics.lua:64-66` relu)** : les F (`carrion_ledger`, `black_summons`,
`beggars_lantern`) sont dépriorisées vers le marchand P1.5c, mais leur RÔLE ÉCONOMIQUE distinct n'est pas
articulé. `beggars_lantern` (cotes -1 tier) est la SEULE mécanique créant une opposition montée-de-tier vs
max-doubles. Sans documenter les 3 archétypes éco, le marchand les vendra sans décision stratégique lisible.

**Décision (doc §4.6/§4.8, 0 code)** : tableau 3 lignes — `carrion_ledger`=rush-tier (accélère la vision des
hauts rangs) / `black_summons`=spike-mid (monte un palier précis ; nul si shopTier ≥ MAX-1) / `beggars_lantern`
=max-dup (cotes basses pour tripler ; conflit avec la montée de tier = vraie décision). **§4.6 enrichi.**
Q3 relics (`beggars_lantern` garantie de pertinence : ≥2 même id OU ≥1 rang-1) reste **ouverte** (à spécifier
avec le marchand P1.5c). Source : `relics.lua:64-66` ; competitive/balatro.md §7.3.

### 4.4 ADOPTÉ (PRIORITÉ 1 — DOC) — Hiérarchie one-more-run S1 + reliques A non-identitaires + règle de priorité §2.10/§2.4 (retention §2.3/Prop-C + relics §2.3 + Q_R9_4)

**Trois précisions doc convergentes :**

**(a) Hiérarchie one-more-run (retention §2.3/Prop-C, Grid Sage 2025)** : en S1 sans communauté visible, le
**near-miss actionnable (§2.3)** est le driver PRIMAIRE du restart (le restart est un test d'hypothèse :
"si j'avais placé X ici…") ; l'**identité (§2.4bis)** est SECONDAIRE (amplifie l'engagement déjà déclenché,
ne l'initie pas). La dépendance est **unidirectionnelle** : si §2.3 est faible, §2.4bis ne compense pas. En
S2+ avec communauté visible (ranked/leaderboard), l'identité monte en PRIMAIRE (comparaison sociale). **Doc
§0/§2** (les deux restent P0 à l'implémentation ; on clarifie le MÉCANISME).

**Pourquoi le synthétiseur ADOPTE (en NUANÇANT)** : la hiérarchie est correcte pour S1, mais le synthétiseur
**refuse de déclasser §2.4bis** : c'est un driver SECONDAIRE valide ET un moteur de méta-progression (mode
statistique sur 10 runs). La note clarifie la causalité, ne change pas les priorités d'implémentation.

**(b) Reliques A non-identitaires = choix ACCEPTÉ (relics §2.3/Prop-D)** : ≥89 % des offres early contiennent
une A (hypergéo `1−C(4,3)/C(7,3) ≈ 88.6 %`). Les A ne portent pas de `dot_family` → le Nom de Build est un
fallback ("ARPENTEUR NAISSANT") jusqu'au round 2-3 même avec le seuil progressif #EE. **C'est voulu** (les A
= stabilisateurs neutres) — documenter pour éviter qu'un round futur tente de le "corriger". **Doc §4.11/
§2.4bis.**

**(c) Règle de priorité §2.10/§2.4 (Q_R9_4)** : si §2.10 (relief) ET le Moment du Run §2.4 se déclenchent au
même combat → afficher §2.4 en PRINCIPAL, §2.10 en ligne SECONDAIRE (étend la règle "Moment du Run > Surprise
de Placement" §2.4). **Doc §2.4/§2.10, 0 code.**

Source : Grid Sage Games 2025 ; keithburgun.net/pick-1-of-3 ; Entalto Studios.

### 4.5 ADOPTÉ (PRIORITÉ 1 — DOC §8.0, 0 code AVANT code P2) — #U RE-QUALIFIÉ : Contrainte de Saison = "axe RÉSOLU + plus grand écart potentiel/réel" (ranked §2.2/§3.4)

**Critique (ranked §2.2, POE 2 game-wisdom.com)** : le critère #U ("sous-représenté vs bas win-rate") cible un
symptôme. La Contrainte de Saison n'est pas un outil d'équilibrage (= P3) mais de **renouveau méta**. Cibler
une famille à bas win-rate AVANT que son axe soit résolu (ex. choc avec #GG bloquant) = **amplifier un
archétype structurellement cassé** → frustration S2 garantie. POE 2 co-livre toujours le `teamFlag` avec un
équilibrage de la famille ciblée.

**Pourquoi c'est valide** : sans prérequis, le code P2 pourrait choisir `shockChain` équipe pour S1 (axe D non
implémenté, #GG bloquant). Le re-cadrage évite d'amplifier des dettes techniques actives.

**Décision (#U RE-QUALIFIÉ, doc §8.0, AVANT code P2)** :
```
PRÉREQUIS DE SÉLECTION DU TEAMFLAG SAISONNIER :
  1. La famille ciblée DOIT avoir son axe marqué "résolu" dans seed/decisions.md (PAS de litige bloquant :
     #GG pour choc, désert-rang-3 pour burn).
  2. Priorité parmi les "résolues" : (a) plus grand écart [potentiel théorique sim] − [win-rate réel] ;
     (b) à égalité : la moins représentée dans le pool ghost tier 3+.
  3. S1 (avant P3) : bleedSlow2x (bleed résolu, sous-représenté vs poison, aucun litige bloquant).
  4. FALLBACK ABSOLU (si aucune famille "résolue") : modificateur de SIGIL pur (lineSlow2x : unités en
     Ligne +15 % vitesse) — indépendant de l'équilibrage des familles (5 sigils, 0 dette hors profil anneau).
```
**§8.0 enrichi.** **#U reste OUVERT mais re-qualifié** (le prérequis est acté ; le choix précis dépend de P0.5/
P3). Prérequis bloquant : **choc interdit comme cible tant que #GG non tranché.** Source : ranked §2.2 ;
game-wisdom.com/poe2 (mars 2026) ; seed/decisions.md.

---

## 5. Adoptions — Ranked (signaux orthogonaux + corrections d'analogie)

### 5.1 ADOPTÉ (#KK neuf, PRIORITÉ 1 — SPEC P2, ~20 lignes IO+RENDER) — "Profondeur du Puits" : axe de progression mid-core ORTHOGONAL au LP (ranked §3.3, §0)

**Critique (ranked §0/§3.3, kydagames.com 2026, Management Science 2026)** : la roadmap n'a qu'UNE dimension
de classement (LP). Un joueur 7-3 répété n'a jamais de signal de compétence durable (les marques sub-tier
exigent 8-9 wins). La recherche Management Science 2026 (Lichess 5.4M parties) montre que considérer DEUX
dimensions (skill + historique récent) produit +4-6 % d'engagement. kydagames.com : "personal best alongside
competitive rank = motivation maximale".

**Pourquoi c'est valide ET grimdark-cohérent** : la Profondeur du Puits (round max atteint cette saison,
indépendamment du résultat final) est exactement le "personal best" qui mesure la progression INDIVIDUELLE.
Pour le 7-3 répété : Profondeur = Round 7 → axe d'amélioration concret ("qu'est-ce qui me bloque au round
8 ?"). Les "Cercles du Puits" (Dante/PoE) sont l'archétype grimdark parfait. Complémentaire des marques (qui
récompensent le meilleur résultat FINAL). Async-safe (stat de run, pas de snapshot), 0 invariant.

**Décision (#KK neuf, SPEC P2, ~20 lignes IO+RENDER)** : `depth_record = max(rounds_completed_this_season)`,
méta cross-run, reset saisonnier. **Per-run au score-screen** (feedback : "tu es descendu jusqu'au 7e cercle")
+ **record-saison au pré-run** (motivation : "ton record : 8e cercle"). **§6.2 + §6.11 enrichis.** Zone sans
test → test `depth_record` mis à jour à chaque combat ranked (golden run 7 combats). Source : kydagames.com
2026 ; eurekalert.org/news-releases/1130401 (juin 2026) ; thebigbois.com/legionbound-review (axe quotidien).

### 5.2 ADOPTÉ (PRIORITÉ 2 — P2 RENDER, ~30 lignes) — Signal d'ÉLAN des 3 derniers runs dans le pré-run (ranked §3.2)

**Critique (ranked §2.3/§3.2, Management Science 2026, Octalysis)** : le signal pré-run (§6.11) montre la
POSITION (LP, marque) mais pas l'**ÉLAN**. Deux joueurs à 14/35 LP (Forgé dans 2 runs) : l'un en progrès
(3.5 pts/run), l'autre en plateau (1.5 pts/run sur 9 runs) — même affichage, motivation de re-queue
radicalement différente. La recherche : "matchmaking = système dynamique où chaque match influence le suivant".

**Pourquoi c'est valide** : l'élan est le signal psychologique le plus direct du "je progresse". RENDER pur,
lit `player.ranked_history[-3:]` (IO hors SIM, 0 invariant).

**Décision (P2 RENDER ~30 lignes)** : `trend = sign(lp_run[-1] − lp_run[-3])` → "LE PUITS RESSENT TON
ASCENSION" (montant) / "LE PUITS ABSORBE TA CHUTE" (descendant, factuel sans jugement) / "LE PUITS TE TIENT"
(plateau). Si < 3 runs → afficher sans label de tendance (pas de signal faux). **§6.11 enrichi.** Zone sans
test → test du label sur 3 issues fixes. Source : ranked §3.2 ; yukaichou.com/leaderboard-design (avr. 2026).

### 5.3 ADOPTÉ (PRIORITÉ 2.5 — après baseline pool, ~15 lignes IO+RENDER) — Modificateur LP VISIBLE par contexte de pool (ranked §2.1/§3.1)

**Critique (ranked §2.1, SAP v0.28 ELO, fairgame.us)** : la grille `+4/+2/+1/0` récompense la DURÉE du run
(10V vs 8V), pas la QUALITÉ. Ascension 10V contre un pool choc (facile) = même +4 que 10V contre un pool
poison (difficile). Le signal de distribution du pool est adopté (round 8 §4.8) comme info, jamais comme
levier de score. SAP ranked utilise ELO (victoire contre mieux classé = plus de points).

**Pourquoi le synthétiseur ADOPTE (en BORNANT fortement)** : l'équité PERÇUE (fairgame.us : "fairness = trust,
not just math") exige qu'un run facile et un run difficile ne vaillent pas EXACTEMENT pareil. **Mais** le
synthétiseur REJETTE tout retour vers un MMR caché (round 8 : 6-9 runs insuffisants pour converger) : ce
modificateur est un ajustement **VISIBLE, grimdark, borné à ±1, JAMAIS de pénalité** (aligné §6.2). Il module
la grille, ne la remplace pas.

**Décision (P2.5, après la baseline pool round 8 §4.8, ~15 lignes IO+RENDER)** :
```
JUGEMENT DU PUITS (modificateur LP visible, borné) :
  pool "dominant" (≥60 % famille à win-rate max, ex. poison) → +1 LP ("pool corrosif")
  pool "faible" (≥60 % famille à win-rate min, ex. choc)    → +1 LP (under-challenge non contrôlé)
  pool "équitable" (aucune famille > 60 %)                  → 0 (base, aucune correction)
  JAMAIS de pénalité (le joueur choc qui gagne ne doit pas être puni pour un pool "facile").
  Calculé depuis les familles des snapshots servis (IO hors SIM, 0 invariant).
```
**§6.2 enrichi.** Dépend de la mesure `dot_family` des snapshots (P0.5 + `toComp`). Zone sans test → test sur
un golden store famille-distribution. Source : ranked §2.1 ; superautopets.wiki.gg/wiki/Version_0.28 ;
fairgame.us (mai 2026).

### 5.4 ADOPTÉ (corrections d'analogie + pré-annonce saison) — 3 analogies recalées + Fresh Start complété (ranked §4)

**(a) "SAP Arena = réf ranked async" = PARESSEUSE (ranked §4.1)** : SAP Arena (IA, casual, jamais de ranked)
≠ SAP async-versus (ghosts humains) ≠ SAP v0.41+ ranked (saisons ajoutées juillet 2025, APRÈS coup).
**Décision** : §6.1 distingue "SAP Arena = réf RUN-structure (10V, casual, pas de pénalité)" vs "SAP v0.41+ =
réf SAISONNIÈRE". Doc.

**(b) "LoL LP = ancrage de CALIBRAGE" = INVALIDE (ranked §4.3, comme TFT round 8)** : rank inflation 2023-2026
+ hard reset Masters+ 2026 (leagueoflegends.com). **Décision** : §6.2 retire toute mention de calibrage LoL ;
seule réf = `tools/ladder_sim.lua` + cible "1 tier/saison à 2-3 runs/sem". Doc.

**(c) "Fresh Start (Milkman 2014) = reset −20 % suffit" = INCOMPLET (ranked §4.2, POE 2)** : le Fresh Start
exige 3 conditions — reset + nouvelles règles + **INCERTITUDE PARTAGÉE** (personne ne sait ce qui marche).
Notre reset + Contrainte de Saison couvre 2/3 ; l'incertitude manque si "bleedSlow2x → build bleed" est connu.
**Décision** : **pré-annoncer** la Contrainte de Saison 24-48 h avant le reset (maximise la spéculation
collective). 1 clé i18n `ranked.season_preview` + logique de timing (`days_to_season_end < 2`). DA = "Présage"
grimdark, pas communication corporate (Q_R9 §5.4 ranked, décision éditoriale). Doc, 0 code maintenant. **§8.0
enrichi.** Source : game-wisdom.com/poe2 (mars 2026) ; leagueoflegends.com/dev-ranked-2026.

---

## 6. Adoptions — Units-power (collision burn, plancher poseurs, compatibilité sigil)

### 6.1 ADOPTÉ (PRIORITÉ HAUTE, #GG lié — DOC §3.7) — Collision d'identité famille burn de `skull_colossus` (units §2.1/P-A)

**Critique (units §2.1, DPS recalculés Python, Cloudfall StS)** : le remède #GG (`skull_colossus`/`deep_kraken`
→ apex à règle d'équipe) traite le symptôme DPS sans la **collision d'identité de famille**. `skull_colossus`
(burn `on_hit`, DPS 0.131, aggro=40, HP=92) **domine en DPS brut** `ash_maw`(0.100) et `plague_pyre`(0.107)
— les 2 T3 burn légitimes → **inverse le contrat rang-5** (le joueur apprend "carry burn DPS" au lieu de
"rendre les brûlures éternelles"). Triple collision : carry burn + tank (aggro=40) + dominance T3.

**Pourquoi c'est valide** : Cloudfall/StS (vérifié) — "if any choice is obviously the best regardless of
context, the designers have failed". `skull_colossus` est la meilleure unité burn en DPS dans TOUS les
contextes. Le brouillon (§3.7) ne couvrait que le DPS, pas l'inversion du modèle de valeur.

**Décision (enrichir le remède #GG, DOC §3.7, 0 code maintenant)** : ajouter l'analyse de la triple collision
+ proposer une **niche rang-5 exclusive non occupée par un T3 burn** : "burn SACRIFICIEL à la mort d'ALLIÉ"
(`on_death` allié, broadcast différé déjà câblé = 0 moteur), DPS frappe → 0.090, **retirer aggro=40** (le
tank-carry est la collision la plus grave). À trancher APRÈS #GG (la niche 0-moteur dépend des triggers).
Q1 units (contrat avec `plague_pyre` = mort d'ENNEMI vs mort d'ALLIÉ) + Q4 units (tank-burn couvert ailleurs ?
→ accepté : burn = famille carry-fragile, grimdark-cohérent) liées à #GG. `deep_kraken` : remède moins
contraint (poison a déjà `venom_censer` T3 croisé) ; niche "poison AoE colonne" = ~5 lignes SIM (nouveau
target) → à justifier pour un apex unique. **§3.7 enrichi.** Source : units §2.1 ; cloudfallstudios.com/sts
(2020) ; entaltostudios.com.

### 6.2 ADOPTÉ (Q3 units — DOC §3.1) — Le plancher "≥2 enablers/rang-3" doit compter les POSEURS ACTIFS, pas les auras (units §2.2, Q3)

**Critique (units §2.2/Q3, SAP a327ex)** : le plancher ≥2/rang appliqué au TOTAL (auras incluses) fait
"passer" toutes les familles par construction (chaque famille a une aura rang-3). `soot_acolyte` (aura,
amplificateur du rang-2) n'est PAS un twist rang-3 (SAP : "each tier = a new mechanic"). Burn rang-3 =
`bellows_priest` (1 poseur actif) + `soot_acolyte` (aura) → "2" artificiel alors que le désert est réel.
Pire, le joueur burn avec `soot_acolyte` + 4 rang-2 croit avoir une progression rang-3 = **piège de
composition** (amplifie des poseurs faibles, pas un twist).

**Décision (doc §3.1, redéfinir le plancher)** : "**≥2 POSEURS ACTIFS (trigger on_hit) par rang-3**" — les
auras ne comptent pas. **Burn rang-3 = 1 poseur actif = SOUS le plancher → désert confirmé sans ambiguïté.**
Croisé avec `--burn-progression-gap` (P-D units : `E[rounds bloqués en shopTier 2-3 sans bellows_priest
visible]` > 2 → trou ; ≤ 2 → bénin). **§3.1 enrichi.** Source : units §2.2 ; a327ex.com/super_auto_pets.

### 6.3 ADOPTÉ (PRIORITÉ MOYENNE — DOC §3.1, précondition P1) — Flag de compatibilité sigil pour les auras DoT rang-3/4 (units §2.4/P-C)

**Critique (units §2.4, Backpack Battles)** : la col J (valeur sigil-dépendante) est documentaire mais non
actionnable. Les 4 auras DoT rang-3 (`soot_acolyte`/`clot_mender`/`miasma_acolyte`/`decay_tender`) varient du
simple au double selon le sigil. Le sigil `ligne` (conduit front→back, archétype bleed-intuitif) ne donne que
2 voisins → une aura "5×4" devient "5×2" = 50 % de valeur perdue. **Si P1 prescrit `clot_mender` comme aura du
palier bleed-4, un joueur bleed qui joue `ligne` (son sigil naturel) trouve son aura à moitié inefficace** =
incompatibilité silencieuse archétype ↔ aura.

**Décision (doc §3.1, calcul sur `shapes.lua`, précondition P1)** : col J enrichie d'un flag "viable ≥3/5
sigils" + sigils-MAX/sigils-MIN. **Ne PAS retirer de U.pool** (trop radical). Mais : (a) alimente le tooltip
de boutique (§2.5) ; (b) **informe P1 (types)** — si un palier-4 prescrit une aura hostile au sigil naturel de
l'archétype, soit le palier prescrit une unité rang-4 différente, soit le tooltip signale l'incompatibilité.
Toutes les auras r3 passent "≥3/5", mais bleed=ligne reste un piège de spec P1 (Q2 units). **§3.1 + §5
enrichis.** Source : units §2.4 ; Backpack Battles (steam mai 2026, "positional items require spatial
tooltips").

### 6.4 ADOPTÉ (PRIORITÉ MOYENNE — DOC §3.1a) — Audit `burst_DPS_eq` de `galvanizer` CONDITIONNEL à l'axe D (units §2.3/P-B)

**Critique (units §2.3, GDC TFT)** : `galvanizer` (DPS 0.172) est l'outlier voulu. Mais l'axe D change la
valeur de `dynamo_priest` (transfer multi-cible, utile pour charger 2 cibles DoT-actives) vs `galvanizer`
(mono-cible fort). Figer l'audit `burst_DPS_eq` avant #GG = juger une hiérarchie provisoire.

**Décision (doc §3.1a, 0 code)** : noter que l'audit `burst_DPS_eq` de `galvanizer` est **conditionnel à l'axe
D** — simuler APRÈS #GG. **§3.1a enrichi.** Source : units §2.3 ; gdcvault.com/TFT (Abecassis).

---

## 7. Rejets et nuances (avec raison mécaniste)

> Un round adversarial doit aussi DÉMOLIR ce qui ne tient pas. Voici ce que le synthétiseur écarte ou borne.

### 7.1 REJETÉ (partiellement) — "§2.10 ne diversifie pas réellement le circuit, c'est un simple second Moment du Run" (retention §2.1)

**Ce qui est rejeté** : la conclusion que §2.10, dans un système déterministe répété, dégénère en "second
Moment du Run" sans valeur de contraste hédonique. **Raison** : la **différence de valence** (positif vs
évitement) reste réelle et mesurable même quand l'issue est prévisible sur un build connu. La reformulation
d'attribution (§1.2, adoptée) corrige la faille d'agence ; la calibration par rôle (§1.3, adoptée) corrige la
fréquence. Avec ces deux corrections, §2.10 garde un poids hédonique 2 distinct (retention §5.3 le confirme).
**Ce qui est adopté de la même critique** : la reformulation d'attribution + le blocage CONFIG-SURVIVAL. On
garde le signal, on corrige son ancrage et sa calibration — on ne le dégrade pas.

### 7.2 REJETÉ — Lier les grants de slot aux victoires (Q1 progression, option b)

**Ce qui est rejeté** : l'option (b) "1 grant supplémentaire tous les 3 wins" (progression Q1). **Raison** :
elle viole "égalisateurs, pas gates" (CLAUDE.md §2) — un joueur en loss-streak stagnerait à 3 slots trop
longtemps. Les grants fixes (rounds 2-7, option a) sont un signal de TEMPS non lié au skill ; même en défaite,
la grille qui grandit est un filet anti-tilt (SAP). **Adopté : option (a), à documenter §7.0.**

### 7.3 REJETÉ — Retirer les auras rang-3 hostiles au sigil de U.pool (units §2.4)

**Ce qui est rejeté** : retirer `clot_mender`/etc. de `U.pool` pour les builds ligne/anneau. **Raison** :
"trop radical pour une décision d'audit" (units §2.4 le reconnaît). Le flag de compatibilité sigil (§6.3,
adopté) alimente le tooltip et informe P1 — sans amputer le pool. Le problème réel est une **spec P1** (ne pas
prescrire une aura hostile au sigil naturel), pas une unité à retirer.

### 7.4 NUANCÉ — Le critère NN/g "3-5 éléments simultanés" est une heuristique, pas une loi mesurée (synergies §2.1)

**Ce qui est nuancé** : la critique présente "3-5 effets max" (NN/g) comme une limite quasi-mesurée. **Raison
de la nuance** : NN/g est un standard UX reconnu mais non spécifiquement validé pour un combat pixel art
320×180 à VFX batchés. **Ce qui est adopté quand même** : la métrique `combat_effect_legibility` (§3.1) est
légitime indépendamment du seuil exact — mesurer avg/max events/tick est utile, et le seuil "> 4" est un
point de départ raisonnable à affiner en playtest. On documente le seuil comme heuristique, pas comme loi.

### 7.5 CONFIRMÉ NON-DÉSACCORD — accords fermes des 4 lentilles non re-challengés

Or fixe 10/round (progression §1.1, **9e confirmation**) ; structure XP passive+achetable (progression §1.2) ;
barre XP §2.5bis + signal contextuel (progression §1.3) ; tableau §7.0 en précondition (progression §1.7) ;
co-calibration shopTier/slots (progression §1.6) ; pas de pénalité + SOFT/HARD pool + grille `+4/+2/+1/0`
(ranked §1.1) ; seed daily partagé + IA 1/famille (ranked §1.2) ; Contrainte de Saison avancée P2 (ranked
§1.3) ; communication honnête S1 "Invocations" (ranked §1.4) ; `offer_decision_quality` segmentée + pseudo-
décision (relics §1.1) ; `resonance_stone` P1.5b candidate (relics §1.2) ; drought protection intention
(relics §1.3) ; Peak-End Rule double niveau (retention §1.4) ; Ovsiankina + Goal Gradient Grimoire (retention
§5.1) ; nom de build mode statistique + Daily exclu (retention §5.2/§5.4) ; enveloppe VRR pondérée (retention
§5.3) ; #FF SPEC À PROUVER (synergies §1.1) ; ordre `--pool-repr` strict #DD (synergies §1.2) ; CONFIG-CE
co-prio apex (synergies §1.3) ; seuils 2/4 (synergies §1.5) ; paires de dominance r3/r4 #10 (units §1.1) ;
stat-sticks r5 bloquants (units §1.2) ; désert rang-3 burn (units §1.3) ; singletons rang-1 (units §1.4) ;
`runestone_golem` niche ambiguë (units §1.5). **Tous maintenus.**

---

## 8. Litiges — état après R09

| # | Litige | Statut R09 |
|---|---|---|
| **#JJ** | **NEUF** — alignement payoff↔agence (cause contrôlée par le joueur) | **ADOPTÉ comme garde-fou** (§10, §4.11). Ferme/réoriente plague_communion, badge MAÎTRE, §2.10, choc axe D. Pas un litige ouvert. |
| **#HH** | **NEUF** — palier choc-4 : Option A (shockChain arc) vs Option B (tickCount=2) | Ouvert, **co-bloquant #GG** (§3.2). Trancher R10/avant P1. |
| **#II** | **NEUF** — directionnalité #FF : asymétrique ordre-fixe vs symétrique 2 passes | Ouvert (§3.4). Doc avant le test #FF. |
| **#KK** | **NEUF** — Profondeur du Puits : per-run vs record-saison | Ouvert ; recommandation : **les deux** (§5.1). Spec P2. (était la 2e #HH de ranked, renommée pour désambiguïser.) |
| **#J** | plague_communion ancrage | **RE-TRANCHÉ (#JJ)** : `dot_family_count ≥ 2` du JOUEUR (§1.1). Annule la variante §11 "scalante cible". |
| **#GG** | apex choc axe A/B vs D | **Maintenu BLOQUANT.** Enrichi : co-décision avec #HH (palier choc-4) ; CONFIG-CE2 (§3.3) + collision burn (§6.1) liées. Prérequis : choc interdit comme Contrainte de Saison tant que non tranché. |
| **#U** | Contrainte de saison : cible | **RE-QUALIFIÉ** (§4.5) : critère = "axe RÉSOLU + plus grand écart potentiel/réel" ; prérequis bloquant + fallback sigil. Reste ouvert (choix précis post-P0.5/P3). |
| **#FF** | interactions inter-familles MID | Maintenu SPEC À PROUVER ; **+ précondition `combat_effect_legibility`** (§3.1) + directionnalité #II (§3.4). |
| **#A** | P1 types vs P2 ranked | Maintenu ; précision (ranked §5.3) : exclure de `--meta-convergence` les runs ranked teamFlag ET les daily à contrainte familiale. |
| **#EE-ranked** | scope seed daily | **CONFIRMÉ** (combat seul, SAP v0.47, ranked §1.2). |
| **#AA** | VRR boutique + pondération hédonique | Maintenu (calibration P3). |
| **#X** | relique contre-jeu méta | Maintenu (P1.5a/P3). |
| **#M** | relique wide quantité vs arête | Maintenu (P1.5b/P4). |
| **#Y** | FIFO ranked au reset de saison | Maintenu ouvert P2. |
| **#V** | snapshot schema version | Maintenu (re-lié #Y). |
| **#B** | inc saturation (+ resonance/#FF y entrent) | Maintenu (calculable via tableau de saturation). |
| **#CC** | wither_bloom critère | Maintenu (critère documenté, code P1.5b). |
| **#Z** | gate §2.8 | **CLOS round 8** (gate bloquant, décision DA user). |
| **#DD** | ordre --pool-repr strict | **CLOS round 8.** |
| **#BB** | Daily unranked seed partagé | **CLOS round 8.** |

**NEUFS R09** : **#HH** (palier choc-4), **#II** (directionnalité #FF), **#KK** (Profondeur du Puits), **#JJ**
(alignement payoff↔agence — adopté garde-fou, pas litige). **RE-TRANCHÉ** : **#J** (plague_communion vers la
compo du joueur). **RE-QUALIFIÉ** : **#U** (critère Contrainte de Saison). **CLOS R09** : aucun par preuve
concluante (méthode : un litige ne se clôt que sur preuve, pas sur consensus mou).

---

## 9. Ce qui s'est amélioré ce round (mesurable)

1. **Un fil rouge systémique découvert et nommé (#JJ)** : 4 lentilles indépendantes (reliques, rétention,
   synergies, units) convergent sur la même classe de bug — payoffs ancrés sur une cause non contrôlée par le
   joueur (cible / exposition / adversaire). Ce critère ferme `plague_communion` (§1.1), reformule le badge
   MAÎTRE (§1.4) et §2.10 (§1.2), et explique la hiérarchie choc < poison (§3.3). C'est le niveau d'attaque
   systémique le plus profond depuis le round 8 — et il ré-attaque le pilier async (l'ancrage adversaire est
   non-reproductible côté agence).

2. **Deux seuils d'alarme éco FAUX corrigés par code** : `reroll_dominance_T1 > 0.25` est trop bas (3 rerolls
   = 30 % du budget = sain → corrigé 0.45 + condition) ; `engagement_rate_T2 = P(achat rang-3 en T2)` est
   MÉCANIQUEMENT IMPOSSIBLE (rang-3 à 0 % en T2, vérifié `00-state §4.3` → redéfini). 8 rounds avaient laissé
   passer des seuils non ancrés sur la mécanique.

3. **Une dette de spec de 9 rounds exhumée** : le palier CHOC-4 (twist P1) n'a JAMAIS été nommé (burn-4/
   bleed-4/rot-4 le sont) — #HH neuf, co-bloquant #GG. Et la métrique `combat_effect_legibility` (Q3 r08
   IGNORÉE par le synthétiseur précédent) est réintroduite comme précondition de #FF ET §2.10.

4. **Le `REROLL_COST` re-cadré comme décision active** : son coût relatif dérive 1:1→1:5 de T1 à T5 (coût=rang)
   — pas un placeholder neutre. SAP (prix uniformes 3g → ratio 1:3 constant) ne partage PAS cette dynamique.
   Intention à documenter §7.0 AVANT la sim.

5. **3 analogies paresseuses corrigées** : SAP Arena ≠ SAP v0.41+ ranked ; LoL LP invalide comme calibrage
   (comme TFT round 8) ; Fresh Start incomplet sans incertitude partagée → pré-annonce de saison.

6. **2 nouveaux axes de signal ranked** (Profondeur du Puits #KK + élan 3 runs) répondant à Management
   Science 2026 (+4-6 % engagement via 2 dimensions d'historique) ; + modificateur LP borné ±1 sans pénalité
   (équité perçue) sans casser la grille.

7. **Sources plus récentes et plus directement pertinentes** : EurekAlert/Management Science (Lichess 5.4M,
   juin 2026), POE 2 seasonal (mars 2026), LoL ranked 2026, SAP v0.28/v0.41/v0.47, arXiv Ordeal Pleasure
   (2603.26677), arXiv SDT compétence (2502.07423), Cloudfall StS, Wayline luxury-vs-enabler.

8. **2 corrections internes à des fichiers de round signalées** (TFT passive 2/round vs nos 1/round délibéré ;
   coquille "BUY_XP 1:1 vs 4:1" — substance correcte) — pour ne pas propager d'erreur.

---

*Round 09 synthétisé le 2026-06-23. Méthode (rounds 4-9) : claims de constantes revérifiés dans le code avant
arbitrage (3 greps `00-state` ce round) ; une affirmation "code-vérifiée" reste contestable ; un litige nuancé
reste ouvert tant qu'une preuve neuve peut le trancher ; un litige ne se clôt que sur preuve. Adoptions =
data/doc/sim/RENDER/config ou décision éditoriale — 0 invariant, 0 modification du code du jeu ni des tests.
Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim
déterministe seedée / DA grimdark / pixel art procédural). 32 invariants préservés. 4 litiges neufs (#HH, #II,
#KK, #JJ-garde-fou) ; #J re-tranché ; #U re-qualifié. DESTINÉ À ÊTRE ATTAQUÉ au round 10 (dernier).*
