# Round 08 — Synthèse adversariale (8/10)

> **Méthode** : intégration critique des 6 lentilles `rounds/r08-*.md` contre le brouillon v8
> (`ROADMAP-draft.md`, intégré round 7). On **adopte** les critiques valides et sourcées, on
> **rejette/nuance** les faibles (avec raison mécaniste), on **consigne** les vrais litiges pour les
> rounds 9-10. C'est un débat, pas une addition. **4 claims de code revérifiés ce round par le
> synthétiseur** (`corruptor`/`bile_spitter`, `rust_sentinel`/`stormcaller`, `runestone_golem`/
> `oath_keeper`, **`dischargeShock`/`shockChain` vs axe D**) — le 4e **corrige une affirmation
> optimiste du round 7** (« apex choc = 0 moteur »).
>
> **Garde-fou** : lecture seule du repo, écriture uniquement sous `docs/roadmap-lab/`. Piliers intacts
> (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural). 32 invariants
> préservés (toutes les adoptions sont RENDER / IO / data / doc / sim / config ou décision éditoriale).

---

## 0. Ce qui change ce round (résumé exécutif)

**Le round 8 est un round de PROFONDEUR STRUCTURELLE.** Les lentilles ne cherchent plus des trous de
contenu ponctuels (rounds 4-7) mais attaquent des **hypothèses de fonctionnement systémique** que la
roadmap traitait comme acquises : (a) l'apex choc « 0 moteur » est-il vraiment 0 moteur si l'axe D est
adopté ? (b) la métrique `offer_decision_quality` mesure-t-elle vraiment des décisions intéressantes
ou valide-t-elle un système structurellement trivial ? (c) les 5 sources de VRR sont-elles diverses ou
est-ce le **même circuit positif** sous 5 noms ? (d) la couche de types P1 fait-elle **résonner** les
familles ou les **cloisonne**-t-elle ? **La leçon de méthode des rounds 4-7 (« relire le code avant
d'affirmer ») a payé une 4e fois** : 4 greps du synthétiseur ce round tranchent/corroborent.

**13 adoptions majeures (toutes data/doc/sim/RENDER/config, 0 invariant) :**

1. **APEX CHOC `skull_colossus → shockChain` n'est PAS « 0 moteur » si l'axe D est adopté = LITIGE
   #GG BLOQUANT** (units §2.3/P-C, **code-vérifié synthé**) — `shockChain` est consommé dans
   `dischargeShock` (`arena.lua:342-388`) qui est un **burst de décharge (axe A/B)** ; l'axe D
   (ampli du 1er tick DoT) **n'est pas implémenté**. « 0 moteur » ne tient que si le choc reste en
   axe A/B. **2 affirmations du round 7 (§3.7 « 0 moteur » + §3.4 « le rebond devient propagation
   d'ampli DoT ») sont contradictoires.** → **à trancher AVANT P1.**
2. **`corruptor`/`bile_spitter` rang-3 = paire de DOMINANCE** (units §2.1, code-vérifié synthé) :
   **op identique** (`poison dps=2 dur=180`), `weaken 0,06 < 0,10` = `bile_spitter` **strictement
   meilleur** sur chaque axe → `corruptor` = dead pick garanti (pire qu'une paire de niche). L'audit
   col B **DOIT s'étendre au rang-3.**
3. **`rust_sentinel` rang-4 = `stormcaller` rang-2 (op IDENTIQUE)** (units §2.2, code-vérifié synthé) :
   **`shock add=1 cap=6 dur=150`** aux deux → enabler rang-2 en taille rang-4 = **viole #10**
   (rang-4 = twist), jamais détecté en 7 rounds. + `runestone_golem` (aura=12 < `oath_keeper`=18 +
   plus de HP/DPS) = **niche ambiguë**. L'audit col B/E **DOIT s'étendre au rang-4.**
4. **`--pool-repr` AVANT `--poison-frac` en ORDRE STRICT = #DD CLOS (strict)** (synergies §2.1 +
   units Q3) — **nouvelle preuve** que la nuance r07 n'avait pas : retirer `corruptor` **change la
   représentation rang-3 poison** → simuler `--poison-frac` avant la décision de cohorte mesure un
   **pool à corriger**. L'isolation des variables (Kritz & Gaina 2025) **exige** l'ordre.
5. **`offer_decision_quality` SEGMENTÉE par tier + métrique « pseudo-décision »** (relics §2.1/Prop-A) :
   le seuil uniforme « 40 % triviales » **ignore la trivialité STRUCTURELLE early** (**≥89 % des offres
   contiennent une A**, hypergéométrique vérifié) et ne détecte pas les **pseudo-décisions** (2 B de la
   même famille = non-triviale au lift mais 0 tension de direction). → cibles **par tier** (early <60 %,
   mid <40 %, late <30 %) + **divergence de conséquence** (<20 % pseudo-décisions).
6. **Signal VRR de RELIEF « CONTRE LA MORT »** (retention §2.1/Prop-B) : **tous les 5 signaux VRR sont
   de valence POSITIVE** → habituation au **même circuit** (Game Developer : « habituation by reward
   TYPE, not frequency »). Il manque le **contraste hédonique** (relief = évitement sous agence, SDT
   Dark Souls). Signal post-VICTOIRE seulement, unité-singulière. P0 RENDER ~1 h.
7. **Daily SEED PARTAGÉ (date + contrainte) = #BB CLOS (avec condition)** (ranked §2.1, §3.1) : sans
   adversaires partagés, l'analogie StS Daily est **paresseuse** — le leaderboard mesure « qui a eu de
   la chance de pool ». **1 ligne** (`daily_seed = hash(date+constraint)` injecté dans `state.rng`),
   **psychologiquement transformatif** (comparable même à 10 joueurs). Scope = **seeds de combat
   uniquement** (shop libre, variance de build préservée).
8. **CONTRAINTE DE SAISON → P2 (depuis P4-light)** (ranked §2.3) : `grant_team` déjà câblé
   (`ops.lua:276`) → **0 moteur** ; sans différenciateur méta saisonnier, **la S2 = un reset de score
   dans une méta inchangée** (le Fresh Start de Milkman 2014 **exige** une nouvelle règle). Livrer avec
   ranked v1, **4 `teamFlags` saisonniers** pré-définis.
9. **IA cold-start ranked = 1 build par famille (6 Encounters)** (ranked §3.3) : le pool FIFO biaise
   vers les familles à win-rate élevé (Backpack Battles, steam mai 2026) → le joueur choc en S1 ne voit
   jamais de ghost choc → abandonne l'archétype. Curation : 1 burn + 1 bleed + 1 poison + 1 rot + 1 choc
   + 1 tank dans `aiComp` ranked.
10. **GRIMOIRE — couche de MAÎTRISE visible** (retention §2.3/Prop-C) : le Grimoire implémente la
    **découverte** (Ovsiankina) mais pas la **maîtrise manifestée** (SDT-compétence — le type de
    progression le plus durable, IntechOpen 2025). Badge INITIÉ/PRATICIEN/MAÎTRE par famille (dérivé des
    apex rang-5 découverts). P2 RENDER ~2 h.
11. **Seuil PROGRESSIF du Nom de Build = #EE** (synergies §2.3) : `≥4` est **impossible à 3 slots**
    (START_SLOTS=3) → « ARPENTEUR DU PUITS » (fallback) pendant les rounds 1-4 = **exactement la zone
    0-5 wins (churn max)**. Seuil progressif (≥2 early / ≥3 mid / ≥4 late), lit `state.wins`, RENDER.
12. **DÉSERT RANG-3 BURN** (units §2.4, code-vérifié) : 5 enablers r2 / **1 seul r3** (`bellows_priest`,
    `P(visible T3) ≈ 27 %` vs bleed 61 %) → fenêtre mid-game burn **2,3× plus étroite**. Documenter +
    décider voulu/trou.
13. **CONFIG-CE co-prioritaire à la décision d'apex choc** (synergies §2.4) : l'apex choc **sans
    correction de la latence early** = apex **jamais atteint** (le joueur quitte choc au round 3 avant
    de voir l'apex au shopTier 5). Promu de « diagnostic P3 » à mesure **co-prioritaire de la décision
    apex** (P0.5).

**8 adoptions de précision / métrique (doc ou sim P3) :**
- **6e métrique `passive_vs_bought_ratio`** (progression §3.2) : la passive contribue-t-elle ou
  est-elle du bruit ? Cible 20-50 %. Précondition du choix de courbe XP.
- **Trois RÉGIMES de tension éco** (progression §3.3) : T1 recherche / T2 engagement / T3 pivot ; les
  sims actuelles n'isolent que T3 (pivot). 3 ratios de régime au tableau §7.0.
- **Retirer la table TFT comme ancrage de CALIBRAGE** (progression §2.1) : superlinéaire = **forme**
  validée par la logique de design, **pas** par les seuils TFT (set-dépendants ; 2 XP/round ≠ nos
  1/round). Le calibrage appartient aux sims sur **nos contraintes**.
- **Signal passive CONTEXTUALISÉ** (progression §3.4) : « +1 XP (N rounds ou M BUY_XP) » au lieu de
  « +1 XP » nu → organise le coût d'opportunité.
- **Ordre de calibration des reliques B** (relics §2.6/Prop-E) : d'abord réduire `kings_bowl` (poison),
  puis augmenter `weeping_nail`/`grave_cap` (bleed/rot faibles), `ember_heart` (burn) en dernier.
- **Critère de tranchement #CC `wither_bloom` documenté AVANT P1** (relics §2.5 + synergies Q4).
- **Baseline `offer_decision_quality` post-correction-garantie-early** (relics §2.3) : mesurer le delta
  pour distinguer « gain de la garantie » de « gain de P1 ».
- **Note d'intention DROUGHT PROTECTION reliques (P3)** (relics §2.4/Prop-D) : analogue rare-climb StS,
  3 lignes, 0 code maintenant.

**4 ré-ancrages / gates de priorisation :**
- **#Z = GATE BLOQUANT de §2.8** (retention §2.4/Prop-D) : « recommandé clos » au round 7 mais §2.8
  peut entrer en P0 **silencieux pour la majorité S1** si #Z n'est pas tranché. **Décision DA requise
  AVANT le code §2.8.**
- **Signal de distribution du pool en post-combat ranked** (ranked §2.2/§3.4) : rendre visible le biais
  du pool pour que le joueur attribue ses résultats correctement (pas un accusé, une transparence).
- **Framing i18n ranked/normal AVANT le code P2** (ranked §2.4) : la DA structure le code, pas l'inverse.
- **Nom de build = mode STATISTIQUE, pas liste** (retention §2.2 + Q_R8_3) : « TU ES PRINCIPALEMENT UN
  BRÛLEUR [4/10] » (reflète le pattern, dev.to/yurukusa 2026 « reflect, not list ») ; **per-run**, Daily
  **exclu** de la persistance d'identité.

**4 litiges neufs/rouverts + 3 clos :**
- **#GG (neuf, BLOQUANT)** : apex choc — **axe A/B (2 axes coexistent)** vs **axe D cohérent
  (`shockAmpMult`, moteur minimal)** ? À trancher avant P1.
- **#FF (neuf, synergies §2.2)** : **interactions inter-familles MID** dans P1 — nécessaires (sinon
  build monofamille = méta par défaut) **ou** prématurées (saturation, golden) ? **Adopté comme SPEC À
  ÉVALUER, pas gravé.**
- **#EE (neuf, synergies §2.3)** : seuil Nom de Build **progressif** vs fixe ≥4 → **adopté progressif**.
- **#EE-ranked (neuf, ranked §5.1)** : scope du seed daily — **run entier vs combat seul** → **recommandé
  combat seul** (shop libre).
- **CLOS** : **#DD** (`--pool-repr` ordre STRICT, nouvelle preuve corruptor) ; **#BB** (Daily UNRANKED +
  leaderboard journalier, **conditionnel au seed partagé**) ; **#Z** (recommandé clos → **gate explicite**
  de §2.8, décision DA à l'user).

---

## 1. Adoptions — units-power (contenu, code-vérifié)

### 1.1 ADOPTÉ (BLOQUANT, #GG neuf) — Apex choc `shockChain` ≠ « 0 moteur » si l'axe D est adopté (units §2.3/P-C)

**Critique (units-power, `units.lua`+`ops.lua` relus)** : le round 7 dit « `shockChain` déjà câblé →
apex choc `grant_team {shockChain}` = 0 moteur » (§3.7) **et** « si l'axe D est adopté, le rebond
devient propagation d'ampli DoT » (§3.4). **Ces deux affirmations ne peuvent pas être vraies
simultanément.**

**Vérifié par le synthétiseur (grep `src/`, décisif)** :
- `shockChain` est **consommé** dans `dischargeShock` (`arena.lua:342-388`) : la décharge inflige
  `volt × stacks` en une **instance burst** (`cause="shock"`, `ignoreShield=true`, l.349) et **chaîne
  la décharge** à un voisin (l.358 `arc`, l.370-378 `spread`). C'est l'**axe A/B** (burst électrique
  qui rebondit).
- **L'axe D (ampli du 1er tick DoT) N'EST PAS implémenté** : le bloc choc de `tickDots` (`arena.lua:
  522-525`) ne fait qu'**écouler la durée** des stacks ; aucune logique « `tick_amplifié = tick ×
  (1 + stacks × N)` ». La promesse « ton choc amplifie TON DoT » est **du design futur, pas du code**.

**Donc** : « 0 moteur » est vrai **uniquement** si le choc reste en axe A/B (burst). Si l'axe D est
adopté en P0.5 (§3.4), reformuler `shockChain` en propagation d'ampli DoT **exige une réécriture de
`tickDots`/`dischargeShock`** (un `for voisin in neighborsOf(source)` après l'amplification) = **SIM,
pas data**, et un test (invariant #22, famille choc).

**Pourquoi c'est valide ET important** : c'est exactement le genre de « 0 moteur » optimiste qu'un
round adversarial doit débusquer. Entalto (« build identity clear within 2 min ») : le ladder choc
doit savoir **sur quel axe il amplifie** AVANT de coder le palier-type choc-4. **Adopté — LITIGE #GG.**

**Décision (à trancher AVANT P1, units §2.3/P-C)** :
- **Option 1 (0 moteur, axe A/B)** : `skull_colossus` apex via `shockChain` = rebond de décharge burst.
  Les rang-2/4 utilisent l'axe D (ampli tick). **2 axes coexistent sur la famille choc** (profondeur :
  « charger pour amplifier le DoT » vs « charger pour rebondir la décharge »). **À documenter + tester
  que `shockChain` et l'axe D ne se court-circuitent pas** (un stack ne déclenche pas 2 amplifications,
  interaction avec `DOT_CAP_MULT=3`).
- **Option 2 (moteur minimal, axe D cohérent)** : apex via `grant_team {shockAmpMult=1.5}` (amplifie le
  multiplicateur de l'axe D au tick). **0 moteur SI `shockAmpMult` est déjà un paramètre de `tickDots`**
  (à vérifier) ; sinon ~5 lignes SIM. Préserve la **cohérence de l'axe D** pour tout le ladder choc.

→ **§3.7 enrichi** : la décision d'apex choc devient une **décision de spec sur l'axe** (pas juste une
réorientation de data). **§3.4 corrigé** : la phrase « le rebond devient propagation d'ampli DoT »
n'est plus présentée comme « 0 moteur ».

### 1.2 ADOPTÉ — `corruptor`/`bile_spitter` rang-3 = paire de DOMINANCE → audit col B au rang-3 (units §2.1/P-A)

**Critique (calculs `units.lua:62-65` + `:122-125`)** : l'audit col B (paires de niche, ≤20 % d'écart)
ne couvre **que le rang-2** depuis 7 rounds. Le rang-3 a une **paire de DOMINANCE**.

**Vérifié par le synthétiseur (`units.lua:64` + `:124`)** :
```lua
corruptor   : rank=3, poison{dps=2, dur=180, weaken=0.06}   -- DPS frappe 0,097
bile_spitter: rank=3, poison{dps=2, dur=180, weaken=0.10}   -- DPS frappe 0,089
```
**Op identique** (`poison dps=2 dur=180`) ; seul `weaken` diffère (0,06 vs 0,10). `bile_spitter` a un
weaken **supérieur** ET un DPS frappe seulement 8 % inférieur → **strictement meilleur sur la dimension
principale**. **Ce n'est pas une paire de niche (50/50) — c'est une dominance** : `corruptor` est un
dead pick garanti (P(choisi) ≈ 0 % avec joueur informé).

**Pourquoi c'est valide** : Ariely/Loewenstein/Prelec 2003 (« Coherent Arbitrariness ») — un item
dominé par un concurrent visible **dégrade la décision** (le dominant paraît meilleur par contraste). Une
dominance est **plus corrosive** qu'une paire de niche. Pool LOCAL → co-apparition fréquente.

**Décision (data, 0 moteur)** : col B étendue au rang-3. Pour `corruptor` : (a) différencier sur un axe
orthogonal (ex. `dps=3` → « empoisonneur rapide » vs `bile_spitter` « affaiblisseur lent ») **OU** (b)
retirer de `U.pool` (garder en `U.order`). Garde-fou : après retrait, poison rang-3 garde `bile_spitter`
≥1 enabler (oui). **Croisé avec la cohorte v7 (§3.2) ET l'ordre `--pool-repr` (§1.5 ci-dessous).**

### 1.3 ADOPTÉ — `rust_sentinel` rang-4 = enabler rang-2 + `runestone_golem` niche ambiguë → audit col B/E au rang-4 (units §2.2/P-B)

**Critique (`units.lua:425-432`)** : l'audit rang-4 cite `galvanizer` (§3.1a) et `runestone_golem`
(§3.1b « budget à trancher »). `rust_sentinel` **jamais cité en 7 rounds**.

**Vérifié par le synthétiseur (`units.lua:427` vs `:80`)** :
```lua
rust_sentinel : rank=4, shock{add=1, cap=6, dur=150}   -- DPS 0,125, aggro=20
stormcaller   : rank=2, shock{add=1, cap=6, dur=150}   -- DPS 0,103, aggro=5
```
**Op IDENTIQUE** (même `add`, même `cap`, même `dur`). `rust_sentinel` = `stormcaller` avec plus de HP/
DPS = **enabler rang-2 en taille rang-4** → **viole #10** (rang-4 = twist, pas enabler). Ni twist (op
identique), ni tank (aggro=20, pas de taunt), ni choc avancé (cap=6 = stormcaller).

**Vérifié `runestone_golem` (`:431`)** : `shield_aura value=12` (rang-4) vs `oath_keeper` (`:353`)
`shield_aura value=18`. runestone = **aura plus faible** mais **plus de HP (88 vs 84) et DPS (0,125 vs
0,114)** → niche **ambiguë** (laquelle pour un build bouclier ?). Deux unités dont l'une est invisible.

**Pourquoi c'est valide** : GhostCrawler (« a unit should not hold a design role that already exists at a
lower tier without adding a new dimension ») + Giovannetti (« power must match complexity »). `rust_sentinel`
= déception valeur-complexité (4 or pour un shock add=1 du rang-2).

**Décision (data, AVANT P1)** : `rust_sentinel` → ajouter un T2 twist choc (ex. `chain=1` ou auto-discharge
lent) pour justifier le rang-4 **OU** rétrograder rang-3 (stats ajustées ; libère un slot rang-4 choc pour
un vrai twist). `runestone_golem` → trancher la niche (aura pure : réduire DPS/HP ; OU carry-tank sans aura :
renommer). **L'audit col B/E (§3.1) s'étend au rang-4** ; croisé avec la cohorte v7. **Garde-fou** :
`rust_sentinel` est dans `U.pool` ligne 482 (bloc v7) — vérifier s'il est compté dans les « 4 rang-4 choc »
(sinon le ladder choc a en fait 5 rang-4 dont 1 enabler simple — units Q2).

### 1.4 ADOPTÉ — DÉSERT RANG-3 BURN documenté (units §2.4/P-D)

**Critique (densité par rang, calculée `units.lua`)** :
```
burn : r1=1 r2=5 r3=1(bellows_priest) r4=2 r5=3 → DÉSERT r3
bleed: r1=1 r2=5 r3=3                r4=2 r5=2 → OK
```
`P(bellows_priest visible en T3, SHOP_SIZE=5) ≈ 27 %` vs `P(≥1 bleed r3) ≈ 61 %` → un joueur burn trouve
sa progression rang-3 **2,3× moins souvent** qu'un joueur bleed. En async, asymétrie de progression dans
les pools d'adversaires.

**Pourquoi c'est valide** : SAP (a327ex : « each tier = introduction to the next mechanic ») — si rang-3 =
« introduction aux twists » et que burn n'a qu'un twist r3, la progression burn **plafonne en mid** (rounds
4-7 = shopTier 2-3 = où les archétypes se consolident). Les rounds précédents ont compté les **singletons
rang-1** mais jamais la **densité rang-3**.

**Décision (audit §3.1, data-only)** : nouvelle ligne « densité rang-3 par famille ». Décider : **voulu**
(bridge resserré = build burn plus exigeant, grimdark-cohérent) **ou trou** = 1 enabler burn rang-3 distinct
(ex. burn + aura d'explosion ≠ `wildfire_hound`) → porte la P à ~45-50 %. **À croiser avec la cohorte v7 et
le plancher ≥2/rang.** Priorité moyenne (audit P0.5, ne bloque pas les paires de dominance).

---

## 2. Adoptions — synergies / effets

### 2.1 ADOPTÉ — `--pool-repr` AVANT `--poison-frac` en ORDRE STRICT → #DD CLOS (strict) (synergies §2.1/P1 + units Q3)

**Rouverture du #DD nuancé au round 7.** La synthèse r07 (§5.1) avait **nuancé** l'ordre strict (« même
lot P0.5, pas d'ordre prouvé ; l'audit col B fait déjà le diagnostic qualitatif »). Le round 8 apporte
**une preuve nouvelle** que cette nuance n'avait pas.

**Argument décisif (synergies §2.1 + units Q3)** : l'audit col B identifie les **REDONDANTES** (paires de
niche/dominance) mais **ne décide pas COMBIEN retirer** — il n'adresse pas l'**excédent de représentation**.
Exemple : même après retrait de `corruptor` (dominance) et `wailing_shade` (niche), poison rang-2 reste à
~5-6 unités vs choc ~2-3. **Et — preuve nouvelle (units Q3)** : retirer `corruptor` **change la représentation
rang-3 poison de 2 à 1**. Donc lancer `--poison-frac` **avant** la décision de cohorte mesure un **pool qu'on
va corriger** → le levier `frac=0,5` serait calibré sur une propagation d'un poison **AUSSI sur-représenté**,
les deux causes confondues dans le win%.

**Pourquoi la nuance r07 tombe** : elle confondait « fait le même travail qualitativement » (col B) avec
« produit le même résultat quantitatif ». **L'isolation des variables** (Kritz & Gaina 2025, arxiv.org/abs/
2502.10304 : « measuring synergy requires isolating element contributions ») **exige** l'ordre :
```
ORDRE STRICT P0.5 :
  1. décision de cohorte v7 (col B/E étendues r2/r3/r4 : corruptor, rust_sentinel, runestone_golem…)
  2. --pool-repr   : alarme si max_famille/min_famille > 1,5 par rang → corriger le pool
  3. --poison-frac : mesure la propagation sur un pool REPRÉSENTATIF
  4. --no-weaken   : isole le weaken sur le même pool corrigé
```

**Décision (#DD CLOS — ordre STRICT)** : §3.5 impose l'ordre. **Coût : doc pur, 0 code.** C'est la
**3e fois** qu'une convergence de 2 lentilles (synergies + units) tranche un litige — et la 1re fois qu'une
preuve neuve (corruptor) **inverse** une nuance précédente. **Méthode validée : un litige nuancé reste
ouvert tant qu'une preuve neuve peut le trancher.**

### 2.2 ADOPTÉ (#FF neuf, SPEC À ÉVALUER, pas gravé) — Interactions inter-familles MID (synergies §2.2/P2)

**Critique (la plus structurante de la lentille)** : les interactions inter-familles n'existent qu'aux
**T3 croisées** (`bleed→rot`, `poison→burn à 5 stacks`) = rang-3, round 8+. Les paliers de type P1 sont
**par FAMILLE SEULE** (bleed-4 OU poison-4, jamais « bleed+poison »). **Résultat** : un build 2-familles
n'a **aucune décision asymétrique** vs un build 1-famille avant le mid-game → les builds **monofamille
dominent**, la diversification n'est **récompensée** que par opportunité boutique, pas par stratégie.

**Distinction Kritz & Gaina (arxiv 2502.10304)** : synergie **intra-ensemble** (notre palier 2/4 par
famille) vs **inter-ensemble** (2 familles créent un effet que ni l'une ni l'autre n'a — nos T3 seules).
Le **manque d'inter-ensemble en MID** est la lacune de profondeur #1 non adressée en 8 rounds.

**2 mécaniques proposées (triggers existants, 0 nouveau moteur)** :
- **A — Aggravation croisée par co-présence** (`tickDots`) : si une cible a 2 familles DoT actives
  (dps>0), le 2nd tick a un `more` de +10-15 % (cap = 1× l'incident, pas de cascade).
- **B — Contagion de famille au kill** (`on_death`) : si une unité meurt avec 2+ familles, la **plus
  forte** se propage aux voisins de combat à 15-20 % (distincte de la propagation poison à 1,0×).

**Pourquoi ADOPTÉ MAIS PAS GRAVÉ (nuance critique du synthétiseur)** : la critique est **valide et
importante** (la diversification doit être mécaniquement rentable avant les T3, run court). **Mais** :
1. **Sa propre Q2 le reconnaît** : ces interactions **interagissent avec le tableau de saturation** (un
   build complet pourrait dépasser le seuil de saturation `more`). Elles **dépendent donc du tableau de
   saturation (précondition P1) ET de `dot_family` (P0.5)**.
2. **Golden** : un bonus conditionnel `more` au tick → **rebaseline si la config golden contient une
   co-présence** (à vérifier avant commit). Ce n'est **pas** « 0 invariant » comme la critique l'affirme.
3. **2 rounds restants** : ajouter une mécanique structurelle au P1 sans l'avoir simulée vs le tableau de
   saturation = risque de graver un combo cassé (exactement ce que `offer_decision_quality` et le tableau
   de saturation cherchent à éviter).

**Décision (#FF ouvert, SPEC À ÉVALUER en P1)** : **documenter les 2 mécaniques dans la spec P1 (§5)** comme
**candidates à spécifier APRÈS le tableau de saturation**, avec un garde-fou : le `more` croisé entre dans
le **même tableau de saturation** que les paliers/auras/reliques B, et sa magnitude est bornée pour ne pas
dépasser le seuil de saturation de la famille la plus chargée. **Si la sim de saturation montre un dépassement
→ réduire le `more` croisé OU le différer P1.5b.** C'est la lacune de profondeur la plus prometteuse du round 8
— mais elle se **prouve en sim avant de se graver**, pas l'inverse. **Litige #FF à trancher rounds 9-10.**

### 2.3 ADOPTÉ (#EE neuf) — Seuil PROGRESSIF du Nom de Build (synergies §2.3/P3)

**Critique** : §2.4bis dérive le nom de `≥4 dot_family` — **impossible à 3 slots** (START_SLOTS=3). Le
palier-4 P1 ne s'active qu'au round 5+. → « ARPENTEUR DU PUITS » (fallback) pendant les **rounds 1-4** =
**exactement la zone 0-5 wins (churn maximal, §2.3)**. Le signal promis (« ancre le Moment du Run dans
l'identité ») n'existe **qu'en mid-game**.

**Pourquoi c'est valide** : la fonction de §2.4bis est de **lutter contre le churn en zone 0-5 wins**. Un
nom-placeholder pendant 4 rounds **manque l'objectif** précisément quand il compte le plus. Entalto (« build
identity clear within 2 min »).

**Décision (#EE → seuil progressif, RENDER, lit `state.wins`)** :
```
slots 3-5 (early)  → nom si ≥2 même famille OU ≥2 familles → "[FAM] NAISSANT" / "ALCHIMISTE NAISSANT"
slots 5-7 (mid)    → seuil=3 ; nom complet sans "NAISSANT"
slots 7-9 (late)   → seuil=4 (palier P1 actif, nom = palier actif)
```
**L'option « 2 familles → ALCHIMISTE dès l'early » aligne le signal d'identité avec l'incitation à
diversifier** (synergie avec #FF §2.2) — un joueur 1 burn + 1 bleed au round 2 se voit nommer « ALCHIMISTE »
= signal **positif** pour la diversification. **Coût RENDER nul supplémentaire.** **Se simplifie en post-P1**
(le nom = palier de type actif, supprime l'ambiguïté 2+2 — déjà anticipé §2.4bis). **§2.4bis enrichi.**

### 2.4 ADOPTÉ — CONFIG-CE co-prioritaire à la décision d'apex choc (synergies §2.4/P4)

**Critique** : CONFIG-CE (latence early du choc) est classée « diagnostic P3 » (§11 « à l'étude »). Mais
l'apex choc est promu BLOQUANT (§3.7). **Si la latence early du choc n'est pas mesurée avant la décision
d'apex** : le joueur engage choc en early (peu de DoT adverse → axe D ne se déclenche pas → choc paraît
faible) → quitte l'archétype au round 3 → **l'apex rang-5 ajouté au shopTier 5 n'est jamais atteint**.
**« L'apex choc sans correction de la latence early est un apex qui n'est jamais atteint. »**

**Aggravé async (synergies §2.4)** : un ghost choc tier-4 sans DoT adverse en early → décharges
n'amplifient rien → ghost « faible » au snapshot → déconseille l'archétype dans la méta perçue.

**Pourquoi c'est valide** : c'est la **condition de validité** de l'apex choc, pas un tuning ultérieur. Le
problème de latence early du choc (NOTÉ P3 au round 7, §2.5) est **mal priorisé** — il est lié à la décision
bloquante d'apex (§3.7) et au litige #GG (§1.1).

**Décision (synergies §2.4/P4)** : **promouvoir CONFIG-CE de « à l'étude/P3 » à mesure co-prioritaire de la
décision d'apex choc (P0.5, §3.7)** :
```
PRÉCONDITION APEX CHOC :
  Avant de coder skull_colossus → shockChain/shockAmpMult (#GG), lancer CONFIG-CE :
  {1 galvanizer T4 choc + 1 burn-poseur rang-2 + 1 stat-stick rang-1} vs IA round-2, N=30, seed 20260620.
  burst_DPS_eq réel vs théorique. Si écart > 40 % :
    → corriger 1 unité choc rang-1 avec fallback dégât direct non-nul (stat-stick) AVANT de coder l'apex.
```
**§3.7 enrichi + §11 (CONFIG-CE) promu.** Coût ~15 lignes sim, non bloquant si écart < 40 %.

### 2.5 ADOPTÉ (priorité faible) — Test edge-case axe D + C2 sur `wither_bloom` (synergies §2.5/P5)

**Critique précise** : après C2, `wither_bloom` (rot dps>0 + bleed dps=0 + poison dps=0). Si l'axe D cherche
le 1er DoT actif dans l'ordre fixe `burn→bleed→poison→rot` et qu'un poseur choc pur amplifie sur cette cible,
le fallback peut « voir » le bleed inerte (dps=0) et **l'amplifier pour 0** → décharge **consommée sans
effet visible** (la promesse de l'axe D silencieusement violée). **Ce n'est PAS une brisure d'invariant** (la
décharge est bien consommée) mais une frustration opaque.

**Décision (test ~15 lignes `tests/synergies.lua`, 0 moteur)** : test 13 — cible `wither_bloom` post-C2 +
poseur choc sans famille rot → vérifier que le fallback **saute les familles à dps=0** et amplifie le seul
dps>0 (rot). **Croise la décision #CC (§3.8) ET l'axe D.** Zone sans test (00-state §8). Priorité faible,
non bloquant P0.5.

---

## 3. Adoptions — reliques

### 3.1 ADOPTÉ — `offer_decision_quality` SEGMENTÉE par tier + métrique « pseudo-décision » (relics §2.1/Prop-A)

**Critique (la plus structurante de la lentille reliques)** : le seuil **uniforme** « < 40 % triviales »
(§3.10) **ignore l'hétérogénéité temporelle** et **manque la pseudo-décision**.

**Argument en 3 temps (relics §2.1)** :
- **Trivialité STRUCTURELLE early non-tunable** : sur 21 reliques, 4 A (universelles). En tier-1, 3 A sur 7
  éligibles → **`P(≥1 A dans une offre de 3) = 1 − C(4,3)/C(7,3) ≈ 88,6 %`** (hypergéométrique vérifié). ~89 %
  des offres early contiennent une A « meilleure par défaut » si le build n'est pas engagé → **impossible à
  atteindre < 40 % en early STRUCTURELLEMENT** (pas par tuning). Facile en late (A diluées dans le pool T4).
- **« Triviale » (lift > 2×) ne capture pas la pseudo-décision** : 2 reliques B de la même famille ont un
  lift similaire (toutes deux amplifient le même axe) → classées « non-triviales » alors que c'est une
  **pseudo-décision** (0 tension de direction). Burgun (« interesting = meaningful alternatives that cost
  something not to take ») : le lift capture le cas trivial mais pas l'**absence d'alternative distincte**.
- **Conséquence** : la métrique pourrait **valider** un système (< 40 % triviales) atteint par des offres
  A+B+B (pseudo-décisions) tout en laissant ouvert le problème de Burgun.

**Décision (§3.10 enrichi, ~15 lignes sim)** :
1. **Cibles PAR TIER D'AVANCÉE** : early (wins 0-1) **< 60 %** triviales (structurel) ; mid (2-4) **< 40 %** ;
   late (5+) **< 30 %** (les décisions les plus tendues).
2. **Sous-métrique DIVERGENCE DE CONSÉQUENCE** : pour chaque offre non-triviale, si les 2 options au lift le
   plus proche ciblent la **même `dot_family`** OU sont deux A → classer **« pseudo-décision »**. Cible
   **< 20 %**.
3. **Reporter % d'offres en TENSION RÉELLE** = total − triviales − arbitraires − pseudo-décisions. Cible
   **> 35 %**.

**Pourquoi maintenant et pas P3** : si la baseline mesure des pseudo-décisions comme bonnes, P1 (types) peut
les dégrader sans que la métrique le détecte (relics §2.1). **Précondition P1 maintenue.** Source : keithburgun
.net/pick-1-of-3 ; Wayline.io/blog/roguelike-itemization (« overlaps and genuine conflicts »).

### 3.2 ADOPTÉ (doc) — Baseline `offer_decision_quality` post-correction-garantie-early (relics §2.3)

**Critique (mineure, valide)** : la garantie de pertinence renforcée en early (§4.1, priorité 3 adoptée
round 7) **changerait** la baseline `offer_decision_quality` si implémentée. Mesurer la baseline **avant**
cette correction = deux métriques incomparables (le « gain » apparent de P1 pourrait refléter la correction
de la garantie, pas l'ajout de contenu).

**Décision (~2 lignes de note, §3.10)** : noter que la baseline doit être mesurée **sur le pool
post-correction-garantie-early** OU **mesurer les deux et documenter le delta** (« gain de la garantie » vs
« gain de P1 »). 0 code.

### 3.3 ADOPTÉ (doc, P3 intention) — DROUGHT PROTECTION reliques (relics §2.4/Prop-D)

**Critique** : le Fisher-Yates seedé des reliques (00-state §2.2) n'a **aucune** protection contre la
sécheresse d'archétype (contrairement au **rare-climb StS** : +1 % de rare par commune vue). Un joueur burn
qui ne voit aucune relique burn en 6 rounds installe la frustration « unlucky RNG ». **L'absence d'INTENTION
documentée** crée un risque de re-découverte en P3.

**Pourquoi c'est valide MAIS pas urgent** : la garantie de pertinence (§4.1) atténue **partiellement** (si
une B est offerte, sa famille est présente) **mais ne garantit pas qu'une B de l'archétype dominant soit DANS
l'offre du tout** (garantie de pertinence ≠ drought protection). Adaptive RNG sourcée (Medium/@JeongHyeonUk :
« strategic investments pay off statistically without guaranteeing outcomes »).

**Décision (3 lignes de note d'intention, §4.1/§7.x, 0 code maintenant)** :
```
NOTE P3 — DROUGHT PROTECTION RELIQUES (intention, pas code) :
Si le build a ≥60 % dot_family depuis ≥2 offres sans une B/E de cette famille, augmenter le poids de
tirage seedé de +20 %/offre manquée (cap +60 %, JAMAIS une garantie dure). Déterministe : poids depuis
l'état seedé du run. Analogue rare-climb StS. S'active SEULEMENT si la garantie de pertinence a été
satisfaite mais n'a pas produit la bonne B (≠ doublement de la garantie — relics Q4).
```
**Garde-fou** : pas une pity-garantie (rejet round 7 maintenu) ; poids supplémentaire, pas garantie. Évite la
re-découverte en P3.

### 3.4 ADOPTÉ (doc) — Ordre de calibration des reliques B en P3 (relics §2.6/Prop-E)

**Critique (nuance, valide)** : les inc actuels des B sont **inversés vs l'idéal** : `kings_bowl`
(poison)=0,20 conservateur (correct, poison dominant) **mais** `weeping_nail`/`grave_cap` (bleed/rot
faibles)=0,18 **< `ember_heart` (burn)=0,30** → les familles faibles ont un inc **inférieur** à burn, ne
compensant pas leur faiblesse. Le brouillon marque `[PH-DÉPENDANT]` (correct) mais ne dit pas l'**ORDRE**
d'ajustement → risque de tuner burn (visible) avant bleed/rot (invisibles) = biais de confirmation du
symptôme.

**Décision (3 lignes, §4.8 sous `[PH-DÉPENDANT]`)** :
```
Ordre de calibration P3 (NE PAS inverser) :
  (1) pool-repr → si poison sur-représenté → réduire kings_bowl (0,20 → 0,14-0,16)
  (2) pool-repr → si bleed/rot sous-représentés → augmenter weeping_nail/grave_cap (0,18 → 0,22)
  (3) recalibrer ember_heart en DERNIER (burn a déjà l'inc le plus haut + meilleure propagation)
```
Cohérent avec l'anti-circularité déjà actée (§7.1 inc-B post-rééquilibrage) ; ajoute la **priorité famille
faible d'abord**.

### 3.5 ADOPTÉ (doc, critère AVANT P1) — Tranchement #CC `wither_bloom` documenté (relics §2.5 + synergies Q4)

**Critique convergente (2 lentilles)** : `wither_bloom` est en `U.pool` et participe aux offres **maintenant**.
Le report du tranchement #CC à P1.5b **sans critère** fait entrer P1 avec une unité au rôle « indécis » : son
`dot_family=rot` ne capture pas ses effets bleed/poison → en P1, elle ne contribue qu'au palier rot (1 fois),
mais les joueurs qui l'ont auront l'impression d'un multi-affliction = **fausse attribution**. + col B : si
elle reste un rot-T3 (option b), son rôle vs `pit_maw` (rot équipe ennemie) est flou (chevauchement de niche).

**Décision (~5 lignes de critère, §3.8/§5, 0 code maintenant)** :
```
Critère de tranchement #CC (à trancher AVANT de coder P1, code en P1.5b) :
- Option (a) : CONFIG-XY = 1 wither_bloom + 1 poseur bleed + 1 poseur poison vs IA, N=30 ;
  si bleed ET poison se déclenchent et interagissent avec leur palier de type respectif
  → option (a) viable → reconcevoir dps bleed/poison non-nuls (vrai multi-affliction, dot_family=rot,
  contribue au palier rot ET via cross-type).
- Option (b) : si dps trop bas pour le palier → renommer i18n en archétype rot pur (« DISTILLATEUR DE
  VIDE ») + retirer de U.pool si écart < 20 % avec pit_maw (col B §3.1).
```
**§3.8 (litige #CC) enrichi du critère.** Lié à C1 (`apply_status`).

### 3.6 ADOPTÉ (P1.5b CANDIDATE, pas gravé) — Relique B SCALANTE « resonance » (relics §2.2/Prop-B)

**Critique** : les reliques B sont des **boosts PLATS** (`ember_heart` +30 % flat) → elles n'engagent pas le
joueur **progressivement**. La référence correcte est **Balatro** (notre réf d'addiction, gd-research §2.6) :
un Joker qui « s'active à chaque Flush » **monte en valeur si on continue dans la direction** (cost to not
committing). Nos B sont l'inverse (Akabeko +8 atk plat, pas Dead Branch émergent). **Une relique B SCALANTE**
(`+5 % affliction_inc par unité du même dot_family`, team-wide, calculée au build) crée un **coût
d'irréversibilité POSITIF** (sans downside) : le joueur qui pivote **perd le scaling accumulé**.

**Pourquoi c'est valide (forte critique)** : cohérent avec **tous nos piliers** — déterministe (lit
`dot_family`), team-wide, async-safe (calculé au build), pas de downside (≥1 unité = +5 %, utile même en
early), pas un gate. Crée une **NOUVELLE dimension de décision** : « certitude (B plate +30 %) vs croissance
(resonance +5 %×N) ». C'est la profondeur que les B plates ne donnent pas.

**Pourquoi ADOPTÉ MAIS PAS GRAVÉ (nuance synthétiseur)** : la critique le reconnaît dans sa propre Q2 — la
resonance + palier-2 de type + B plate + aura peut **dépasser le seuil de saturation** (§5.2). Elle **dépend
de `dot_family` (P0.5) ET du tableau de saturation (précondition P1)**. C'est un **nouveau op** (`relic_resonance
_inc`, ~10 lignes) → pas P1.5a (data pure), mais **P1.5b** (après le tableau de saturation). Q3 relics : 22
reliques au lieu de 21 → `P(≥1 F parmi 3)` passe de 38,7 % à 35,9 % (variation mineure, OK).

**Décision (P1.5b candidate, litige léger)** : ajouter `resonance_stone` à la liste P1.5b des candidats
(§4.8/§5), **conditionnée par P0.5 (dot_family) + le tableau de saturation** ; sa magnitude entre dans le
tableau de saturation comme les autres sources d'inc. **Non gravé** tant que la saturation n'est pas validée.
Source : balatrogame.fandom.com/wiki/Guide:General_strategy (scaling par tags) ; Wayline.io (commitment costs).

> **Note du synthétiseur sur Prop-B vs #FF** : la relique resonance (§3.6) et les interactions inter-familles
> MID (#FF, §2.2) attaquent le **même problème** (la diversification/cohérence n'est pas mécaniquement
> récompensée avant les T3) par 2 angles : resonance récompense la **cohérence MONO-famille**, #FF récompense
> la **diversification MULTI-familles**. **Ils sont complémentaires, pas redondants** — mais les deux dépendent
> du tableau de saturation. **Les traiter ensemble en P1.5b/P1** une fois la saturation mesurée.

---

## 4. Adoptions — rétention / progression / ranked

### 4.1 ADOPTÉ (P0 RENDER) — Signal VRR de RELIEF « CONTRE LA MORT » (retention §2.1/Prop-B)

**Critique (la plus profonde de la lentille rétention)** : la roadmap traite les 5 sources VRR (boutique,
Moment du Run, placement, reliques, trace d'impact) comme « temporellement et psychologiquement distinctes »
(§2.9, PSU.com 2025). **La faille** : la distinction « agence directe / narration rétrospective » concerne
deux **TYPES d'action** (décision vs observation), pas deux **circuits émotionnels**. **Sur le plan de la
valence, tous les 5 signaux sont POSITIFS (récompense + surprise)** → leur accumulation **sature le même
circuit**, pas 5 circuits distincts.

**Preuve (Game Developer, Reward Schedules)** : « Players habituate to reward *type*, not just *frequency*.
A mix of rewards that feel structurally identical — all positive surprises — habituates at the same rate as a
single repeated reward. Diversity requires *hedonic contrast*. » + SDT Dark Souls (researchgate.net/
publication/399804244) : « the avoidance-followed-by-mastery loop is more durable than pure positive
reinforcement, because it introduces hedonic contrast — relief after a threat overcome is qualitatively
different. »

**Ce qui manque** : aucune source VRR de type **RELIEF** (évitement d'une conséquence négative sous agence).
Or « éviter la défaite grâce à un placement minutieux » est **déjà dans le jeu** — mais jamais NOMMÉ comme
source VRR. La DA grimdark oppressive (« le Puits a failli te consumer ») est le **cadre idéal** pour le relief.

**Pourquoi c'est valide ET nouveau** : 8 rounds ont empilé des signaux **positifs** sans jamais questionner
leur **homogénéité de valence**. C'est exactement le niveau d'attaque systémique que le round 8 promettait.

**Décision (P0 RENDER ~1 h, 0 SIM, 0 invariant)** : après chaque **VICTOIRE** où une unité du build a survécu
en ayant perdu ≥75 % de ses PV (lu du bus `{target, hp_before, damage}`), afficher **1 ligne distincte du
Moment du Run** : « [NOM_UNITÉ] A TENU — LE PUITS A FAILLI TE CONSUMER » + surlignage discret.
- **Conditions** : VICTOIRE uniquement (jamais défaite — éviter le paternalisme) ; `hp_remaining > 0` (vraie
  survie) ; **1 seule unité** satisfait (sinon perd sa singularité).
- **Garde-fou DA** : grimdark pur (le Puits = ennemi, pas ami), 0 félicitation, survie = miracle sombre.
- **Compatible enveloppe VRR** (Q_R8_1) : ~2-3 signaux/run estimés (poids hédonique 2) → +4-6 unités
  pondérées, dans la borne. **À valider en sim** (lire `{hp_before, damage_taken}` sur N=200).
- **Zone sans test** → test que la condition se déclenche sur un golden (scénario avec unité survivante
  proche de 0 HP). **§2.x nouveau (P0).**

### 4.2 ADOPTÉ (P2 RENDER) — Grimoire : couche de MAÎTRISE visible (retention §2.3/Prop-C)

**Critique** : le Grimoire implémente la **découverte** (Ovsiankina) mais pas la **maîtrise manifestée**
(SDT-compétence). Un joueur qui a découvert 12/15 unités poison **SAIT** construire un build poison optimal
— mais le Grimoire **stocke les découvertes, il ne les traduit pas en capacités**.

**Preuve (IntechOpen 2025, Pathways to Mastery)** : 3 types de progression — (1) puissance, (2) **contenu
découvert**, (3) **maîtrise** (efficacité accrue). **La maîtrise (type 3) a la plus longue durabilité de
rétention** (perçue comme récompense de skill). Notre Grimoire n'implémente que le type 2 sans lien vers le
type 3.

**Pourquoi c'est valide (et nuance l'accord round 6-7)** : le round 6 a ancré le Grimoire sur l'Ovsiankina
(« reprendre une tâche interrompue »). La lentille rétention le **nuance** (accord 1.5 r08) : dans un jeu
**déterministe**, le mécanisme dominant est la **compétence accumulée** (la connaissance se manifeste
mécaniquement — même build → même résultat). **Les deux doivent coexister.**

**Décision (P2 RENDER ~2 h, 3 règles de données, 0 SIM, 0 invariant)** : dans le Chapitre II (essences par
famille, §6.7), ajouter un **badge de maîtrise à 3 paliers** dérivé des apex (rang-5) de la famille
découverts :
```
MAÎTRISE POISON :
  ○ INITIÉ    — 0/2 apex découverts
  ◑ PRATICIEN — 1/2 apex découverts
  ● MAÎTRE    — 2/2 apex + ≥1 relique-E poison vue
```
**3 paliers** (Goal Gradient maximal ≤7 étapes, LogRocket 2024). **Connexion au Nom de Build** : « Tes runs
BRÛLEUR : 3× INITIÉ, 1× PRATICIEN. Prochaine étape : découvrir [ASH_MAW] » → résout le problème §2.2 (identité
de run → identité durable via maîtrise). **§6.7 enrichi.**
- **Q_R8_2 (à trancher après sim hunt-médian P3)** : les apex rang-5 sont au shopTier 5 → la majorité S1
  restera INITIÉ (run fini avant le tier 5). Si les apex sont vus en ~1/3 des runs → Goal Gradient OK ; si
  ~1/10 → tirer l'horizon vers « 2 unités T3 rang-4 de la famille » (plus accessible). **À trancher après
  la sim hunt-médian.**

### 4.3 ADOPTÉ — Nom de build = mode STATISTIQUE + per-run + Daily exclu (retention §2.2 + Q_R8_3 + §5.2)

**Critique (§2.2 + dev.to/yurukusa relu)** : §2.4bis **persiste une LISTE** de noms (« tes 5 derniers
runs »). Mais le même article cité dit en fait : « The name alone doesn't create retention. What creates
retention is *recognition* — the player sees their name repeated and thinks: 'I'm *that* kind of player.'
This requires the game to REFLECT the pattern back, not just list it. » La roadmap n'implémente que la
**première moitié** (lister).

**Décision (RENDER, données déjà disponibles)** :
- Le signal d'identité durable affiche le **mode statistique** : « **TU ES PRINCIPALEMENT UN BRÛLEUR [4/10
  runs]** » (Q_R8_3 : nom **per-run**, mode sur les 10 derniers → évite l'instabilité « BRÛLEUR/ALCHIMISTE/
  BRÛLEUR » sur sessions courtes). **§2.4bis enrichi.**
- **Daily EXCLU de la persistance d'identité** (§5.2, retention) : un Daily à contrainte imposée force un
  nom différent de l'archétype habituel (« BRÛLEUR habituel » qui fait le Daily poison = « DISTILLATEUR »).
  Même convention que StS (Daily n'alimente pas l'Ascension). **Ne pas persister le nom des Daily dans
  `grimoire.lua`.** Doc, 0 code. **§6.6 enrichi.**

### 4.4 ADOPTÉ (gate de priorisation) — #Z = GATE BLOQUANT de §2.8 (retention §2.4/Prop-D)

**Critique** : le litige #Z (signal spectre en cold-start, N=0 silencieux) est « recommandé clos » au round 7
mais **reste ouvert**, laissant la décision DA à l'user. **En l'absence de décision, §2.8 peut entrer en P0
avec le comportement par défaut (silencieux si N=0)** — qui invalide l'objectif de session-initiation pendant
toute la phase S1 (pool quasi-vide). **C'est un gate de priorisation, pas un changement de design.**

**Vérifié (retention §2.4)** : en S1 local sans backend, le pool FIFO n'est affronté que par les propres
combats du joueur (le cold-start IA utilise `aiComp`, pas les ghosts locaux) → **N = 0 systématiquement** sauf
formulation IA distincte. **#Z DOIT être tranché AVANT §2.8.**

**Décision (gate documenté)** : inscrire que **l'implémentation de §2.8 est BLOQUÉE par la décision DA de
#Z** (2 options) :
- **Option 1 (silencieux si N=0)** : §2.8 ne fonctionne qu'en backend (P4). En S1 local → pas de signal de
  session-initiation → **accepté explicitement**.
- **Option 2 (IA formulation distincte, recommandée)** : « LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE —
  [N] INVOCATION[S] L'ONT ÉPROUVÉ » ; fallback silencieux si N=0 même pour IA. Fonctionne dès S1.

**Position du synthétiseur** : Option 2 est la seule qui rende §2.8 utile en S1, **cohérente avec ranked S1 =
Invocations (§6.5)**. La **décision DA finale reste à l'user** (« ÉPREUVES DU VIDE » casse-t-il le cryptique ?)
— mais **consciente, pas par défaut**. **§2.8 enrichi du gate ; #Z = recommandé clos vers Option 2.**

### 4.5 ADOPTÉ (#BB CLOS, condition seed) — Daily SEED PARTAGÉ + #EE-ranked (ranked §2.1/§3.1/§5.1)

**Critique (ranked §2.1, partielle mais décisive)** : le Daily « unranked + leaderboard journalier » (#BB,
acté r07) résout **la mauvaise moitié** : un leaderboard journalier à < 50 joueurs S1 est **psychologiquement
creux**. La **vraie valeur** de la Contrainte du Jour est la **SEED PARTAGÉE** — si tous les joueurs affrontent
**les mêmes ghosts** ce jour-là, les résultats deviennent **comparables** (yurukusa 2026 : « use the date as
the seed. The 'map' is shared. The score is earned. »). **Sans le seed partagé, le leaderboard mesure « qui a
eu la meilleure chance de pool » → l'analogie StS Daily est PARESSEUSE** (StS Daily = run à seed partagée,
comparabilité totale).

**Pourquoi c'est valide** : la critique **complète** #BB (acté correct au round 7 sur le « unranked ») avec
le mécanisme psychologique manquant. **Comparable même à 10 joueurs** (« j'ai monté en 12 rounds, X vies »
vs les 9 autres dans les **mêmes conditions**).

**Décision (#BB CLOS — condition seed partagé)** : dériver le seed de combat du Daily depuis
`hash(date_ymd .. constraint_id)` au lieu d'un seed libre. **1 ligne** (`state.lua:startRound` → `self.rng =
newRandomGenerator(daily_seed)` si `mode=="daily"`). Compatible déterminisme (invariant #4 : RNG injecté).
**§6.6 enrichi.**
- **#EE-ranked (neuf, scope du seed daily)** : s'applique-t-il au **run entier (shop inclus)** ou aux **seeds
  de combat seulement** ? **Recommandation (ranked §5.1) : combat seulement** — si le shop est aussi seedé, tous
  voient les mêmes offres → run encore plus comparable mais **perd la variance de build** (trop restrictif). Le
  seed daily contrôle l'**ordre de tirage des ghosts**, pas le shop. **Variante de l'invariant #2 à documenter**
  dans `seed/tests.md` (« même seed daily → même suite d'adversaires »).
- **Précision #BB** : le leaderboard journalier est **conditionnel** au seed partagé. Sans lui, ne pas le
  présenter comme compétitif.

### 4.6 ADOPTÉ (P2) — Contrainte de Saison → P2 avec 4 teamFlags pré-définis (ranked §2.3/§3.2)

**Critique** : §8.0 (Contrainte de Saison) est en **P4-light** (entre P2 et P4). C'est le mécanisme le **moins
coûteux** et **plus impactant** pour la rétention S2 → doit entrer **avec le ranked v1 (P2)**.

**Vérifié (ranked §2.3)** : `grant_team` est déjà câblé (`ops.lua:276`, confirmé synthé round 7) ; les
`teamFlags` existants (`burnNoDecay`, `poisonNoCap`, `shockChain`…) sont déjà data-driven et injectés à
`combat_start`. Une Contrainte de Saison = **1 `teamFlag` saisonnier** posé **dans la spec ranked, pas dans le
snapshot** (injecté côté résolution depuis la saison courante — async-safe, acté round 7 §1.7). **0 moteur.**

**Pourquoi c'est valide** : sans différenciateur méta saisonnier, **la S2 = un reset de score dans une méta
inchangée** — les joueurs S1 qui ont appris « poison domine » reviennent en S2 avec **le même avantage**. Le
Fresh Start (Milkman 2014) **exige une nouvelle règle** pour être ressenti (yukaichou 2023 ; seganerds 2026 :
« a scoreboard that resets just often enough »). **POE 2** (gamedesigning.org 2026) : « a build that dominated
last season may be ordinary now » = différenciateur S1→S2 minimal. La cohérence avec le round 7 (§8.0 déjà
« priorité visible ») **renforce** cette avance.

**Décision (avancer §8.0 de P4-light à P2, livrer avec ranked v1)** : 4 `teamFlags` saisonniers data-définis
(1 par saison prévue), injectés au démarrage de chaque saison depuis `src/data/season.lua` :
- S1 : `bleedSlow2x` (favorise bleed) · S2 : `burnPropagateAlways` (favorise burn) · S3 : `poisonWeakenStack`
  (favorise poison) · S4 : `shockChain` équipe (favorise choc).
- **0 moteur** (tous câblés ou triviaux à câbler) ; décision data au démarrage de saison. **§8.0 → calendrier
  P2 (v0.11.3).**
- **Croisé avec #U** (critère de sélection : famille **sous-représentée**, pas dominante) ET **#5.3 ranked**
  (le `teamFlag` saisonnier biaise `--meta-convergence` → mesurer #A sur les runs **normaux non-ranked sans
  teamFlag**).
- **Zone sans test** → le `teamFlag` saisonnier n'altère pas le golden (golden ≠ run ranked) + s'applique aux
  2 camps + uniquement en ranked.

### 4.7 ADOPTÉ (P2) — IA cold-start ranked = 1 build par famille (6 Encounters) (ranked §3.3)

**Critique** : le filtre `wins_at_capture ≥ 3` ne distingue pas **compétence de chance** — en pool FIFO, les
ghosts à haut tier sont **biaisés vers les familles à win-rate élevé** (poison > tank > … > choc). **Preuve
Backpack Battles (steam mai 2026)** : « pairing you up against the best builds pulled from thousands of games
with the best combined skill and luck... no way to parse the actual contents of your build. » → un joueur choc
en S1 ne voit **jamais** de ghost choc à son tier → abandonne l'archétype (biais de sélection par pool).

**Pourquoi c'est valide** : l'IA ranked (Encounters puissants, acté §6.4bis round 7) **doit couvrir toutes les
familles**, pas seulement les Encounters aux meilleurs stats. Sinon le cold-start ranked **reproduit** le biais
du pool.

**Décision (0 code, curation, §6.4bis)** : spécifier que `aiComp` ranked cold-start = **6 builds** : 1 burn
fort + 1 bleed fort + 1 poison fort + 1 rot fort + 1 choc fort + 1 tank (les Encounters les plus puissants par
famille). **Zone sans test** → `serveComp(ranked)` retourne 1 build par famille (golden store). **§6.4bis
enrichi.**

### 4.8 ADOPTÉ (P2 RENDER + doc) — Signal de distribution du pool + framing i18n ranked/normal (ranked §2.2/§2.4/§3.4/§3.5)

**Deux adoptions liées** :

**(a) Signal de distribution du pool en post-combat ranked (P2 RENDER ~1 h)** : après le « pourquoi » (§2.3),
ajouter « **TU AS AFFRONTÉ [N] INVOCATIONS : [K BRÛLEURS / M SAIGNEURS / …]** » (lu de `dot_family` sur les
snapshots servis ce run, IO hors SIM). Renforce l'**attribution correcte** : « 7 poison → le pool est
poison-lourd ce tier » vs « 2 choc + 3 poison + 2 burn → mon build a un problème générique ». **Ce n'est pas un
accusé de biais — c'est rendre visible la distribution** (grimdark : « le Puits révèle ce qu'il t'a envoyé »).
Zone sans test → comptage correct sur golden run. **§2.3/§6.x enrichi.**

**(b) Framing i18n ranked/normal AVANT le code P2 (doc, 5 clés i18n)** : le signal pré-run (§6.11) répond à
« combien de LP ? » mais pas à « **pourquoi ce run ranked est-il différent ?** ». La DA résout ça (ranked §2.4) :
| Moment | Normal | Ranked |
|---|---|---|
| Sélection | « UNE DESCENTE DANS LE PUITS » | « UNE ÉPREUVE DU PUITS » |
| Lancement | « LE PUITS ATTEND » | « LE PUITS PÈSE TON BUILD » |
| Victoire run | « TU AS SURVÉCU » | « LE PUITS T'A RECONNU » |
| Défaite run | « LE PUITS T'A CONSUMÉ » | « LE PUITS A JUGÉ TON BUILD INSUFFISANT » |
| Saison active | — | « SAISON DES [NOM] — LES RÈGLES DU PUITS ONT CHANGÉ » |
**Doit être écrit AVANT le code** (la DA structure le code, pas l'inverse). 0 mécanique. **§6.5/§6.11 enrichi.**

### 4.9 ADOPTÉ (sim P3 + doc) — Métriques éco : `passive_vs_bought_ratio`, 3 régimes, signal passive contextualisé, retrait ancrage TFT (progression §2.1/§2.2/§2.3/§2.4)

**4 adoptions de la lentille progression (toutes valides, sourcées)** :

- **(§2.1) Retirer la table TFT comme ancrage de CALIBRAGE** : la **forme superlinéaire** est validée par la
  logique de design (tension croissante voulue) ; les **seuils TFT changent à chaque set** (wiki Riot
  vérifié : L4=10/L5=20 par palier actuel ≠ table v7 citée) et ciblent **2 XP/round sur 30 rounds** ≠ **nos
  1 XP/round sur 15**. **Citer TFT comme ancrage de valeurs précises est non fondé.** → §7.1 : remplacer
  « super-linéaire TFT (lolchess vérifié) » par « forme superlinéaire validée par la logique de design ;
  calibrage ancré sur NOS contraintes (run 10-19 rd, 1 XP/round) ; l'analogie TFT est de FORME uniquement ».
  **Empêche une future lentille de proposer des seuils basés sur une table qui bouge.**
- **(§2.2/§3.2) 6e métrique `passive_vs_bought_ratio`** : aucune des 4 conditions de sim ne mesure la
  **dépendance au BUY_XP vs passive**. Calcul vérifié (state.lua : passive 1/round dès round 2) : sur un run
  médian 15 rounds, la passive seule (~13 XP) atteint T4 vers le round 11 mais **T5 (cumulé 27 avec la courbe
  actuelle, ou 18+ avec candidate) est inatteignable passivement** → T5 = exclusivement BUY_XP. **Est-ce
  voulu ?** Métrique : `xp_from_passive / (passive + bought)` sur N=200. Cibles : **< 20 %** = passive = bruit
  (signal §2.5bis décoratif → buff ou simplifier) ; **20-50 %** = sain ; **> 60 %** = BUY_XP sous-utilisé. ~5-8
  lignes sim, précondition du choix de courbe XP. **§7.0/§7.1 enrichi.**
- **(§3.3) Trois RÉGIMES de tension éco** : le « pivot T4 » (round 7) est le **3e** d'une série de 3 régimes ;
  les sims n'isolent que le 3e. **Régime 1 (T1-T2, recherche)** : `reroll_dominance_T1 > 0,25` (pool peu
  diversifié) ; **Régime 2 (T2-T3, engagement)** : `engagement_rate_T2 < 0,50` (le joueur reroll sans s'engager
  rang-3 = niches indistinctes OU BUY_XP trop attractif) ; **Régime 3 (T3-T4, pivot)** : `pivot_T4_decision_rate`
  (déjà défini). **Une métrique globale masque des comportements opposés par tier.** 3 ratios au tableau §7.0,
  ~20 lignes sim. **§7.0/§7.1 enrichi.**
- **(§2.4/§3.4) Signal passive CONTEXTUALISÉ** : « +1 XP passif » nu **risque une décision d'attente
  irrationnelle** (3 rounds de passive = 3 XP < 1 BUY_XP). Remplacer par « +1 XP passif (N rounds ou M BUY_XP) »
  (gamedeveloper.com 2013 : « organize trade-offs »). RENDER ~0,5 h. **§2.5bis enrichi.**

**Garde-fou commun** : toutes les intentions `[TBD]` (T5 = accès actif uniquement ? régime 2 = goulet ?) sont
**soumises à l'user** dans le tableau §7.0 (Q4 progression). Les sims **mesurent**, l'user **décide**.

---

## 5. Rejets et nuances (avec raison mécaniste)

### 5.1 NUANCÉ (pas rejeté) — « Leaderboard journalier creux » (ranked §2.1)

La critique « leaderboard journalier psychologiquement creux à < 50 joueurs » est **partiellement valide mais
la conclusion correcte n'est pas de le retirer** — c'est d'ajouter le **seed partagé** (§4.5 adopté). Avec le
seed partagé, le leaderboard est meaningful même à 10 joueurs. **Le leaderboard reste, CONDITIONNEL au seed
partagé.** Ce n'est pas un rejet, c'est une précision de précondition.

### 5.2 REJET CONFIRMÉ (re-validé) — MMR caché à la TFT (ranked §4.3)

La lentille ranked **confirme** le rejet (déjà en anti-patterns §10) : TFT MMR caché converge sur ~100+ parties/
set ; un joueur The Pit joue **6-9 runs/saison de 3 sem.** → un MMR caché **n'a pas le temps de converger** →
ingénierie prématurée. `slot_tier_composite` (monotone, simple) suffit pour le volume S1. **Maintenu rejeté.**

### 5.3 REJETS CONFIRMÉS (rétention §6) — 3 propositions auto-rejetées par la lentille

La lentille rétention **rejette elle-même** 3 idées tentantes (et a raison) :
- **Partage social des noms de build** : anonymat grimdark ; le partage est un levier de **croissance**
  (marketing), pas de **rétention** (psychologie interne) — ne pas confondre. Différé post-v1.0.
- **Compteur de STREAK de nom de build** (« 3 runs BRÛLEUR ») : crée une **obligation implicite** de répéter
  l'archétype → **punit l'exploration** (pilier roguelite). DA grimdark ne supporte pas les streaks mobile-gamey.
- **VRR négatif sur régression de stats en combat** : le **déterminisme** rend le signal **prévisible** (même
  build = même signal) → ce n'est **pas** du VRR, c'est un feedback fixe. Le déterminisme invalide toute VRR
  négative prévisible. **Maintenus rejetés.**

### 5.4 NUANCÉ (adopté avec garde-fou) — Interactions inter-familles MID (#FF, synergies §2.2)

**Adopté comme SPEC À ÉVALUER, PAS gravé** (§2.2). La critique surestime « 0 invariant » (un `more`
conditionnel au tick **rebaseline le golden** si la config golden contient une co-présence) et minimise la
dépendance au **tableau de saturation** (sa propre Q2 la reconnaît). → spécifier dans P1 **après** la
saturation, magnitude bornée dans le **même tableau**. Si dépassement → réduire ou différer P1.5b. **Litige
#FF ouvert.**

### 5.5 NUANCÉ (P1.5b candidate) — Relique B SCALANTE « resonance » (relics §2.2)

**Adopté comme candidate P1.5b, pas P1.5a** (§3.6). Nouveau op (`relic_resonance_inc`) → pas « data pure »
(P1.5a) ; dépend de `dot_family` (P0.5) + tableau de saturation (sa propre Q2). **Complémentaire de #FF, pas
redondant** (resonance = cohérence mono-famille ; #FF = diversification multi-familles). Les traiter ensemble
en P1/P1.5b après la saturation.

---

## 6. Litiges — état après round 8

| # | Litige | Statut R08 |
|---|---|---|
| **#A** | P1 types vs P2 ranked | Ouvert ; **mesurer `--meta-convergence` sur runs NORMAUX sans `teamFlag` saisonnier** (ranked §5.3 — le teamFlag S1 biaise vers une famille) |
| **#B** | inc saturation | Ouvert ; tableau de saturation par famille (§5.2) ; **+ resonance #FF entrent dans le même tableau** |
| **#F** | 6e type non-DoT | Orienté « aucun » (confirmé) ; dispersion DPS tank = audit budget |
| **#G** | axe choc = AXE D | Ouvert P0.5 ; **lié à #GG neuf (l'apex est-il dans l'axe D ?)** |
| **#GG** | **NEUF — apex choc : axe A/B (2 axes) vs axe D cohérent (`shockAmpMult`)** | **Ouvert, BLOQUANT avant P1** (units §2.3, code-vérifié — « 0 moteur » r07 corrigé) |
| **#FF** | **NEUF — interactions inter-familles MID dans P1** | **Ouvert** ; adopté SPEC À ÉVALUER (après saturation) ; nécessaires (build monofamille = méta défaut) ou prématurées ? |
| **#EE** | **NEUF — seuil Nom de Build progressif vs ≥4** | **ADOPTÉ progressif** (≥2 early/≥3 mid/≥4 late, §2.4bis) |
| **#EE-ranked** | **NEUF — scope seed daily : run entier vs combat seul** | **Recommandé combat seul** (shop libre, ranked §5.1) ; variante invariant #2 à documenter |
| **#DD** | `--pool-repr` ordre | **CLOS (strict)** — nouvelle preuve corruptor (retirer = change repr rang-3) → ordre strict requis |
| **#BB** | Daily ranked/unranked | **CLOS** — UNRANKED + leaderboard journalier, **CONDITIONNEL au seed partagé** (§4.5) |
| **#Z** | spectre cold-start | **CLOS (gate)** — recommandé Option 2 (IA distincte) ; **gate bloquant de §2.8**, décision DA à l'user |
| **#CC** | wither_bloom post-C2 | Ouvert P1.5b ; **critère de tranchement documenté AVANT P1** (§3.5) |
| **#U** | Contrainte saison cible | Ouvert ; **croisé avec §8.0→P2 et `--pool-repr`** (famille sous-représentée, pas dominante) |
| **#AA** | seuil VRR boutique | Ouvert ; **+ pondération hédonique du tableau de fréquence** (retention §3.1, doc) ; **+ signal RELIEF (poids 2) entre dans l'enveloppe** |
| **#X** | relique contre-jeu méta | Ouvert ; `hollow_choir → pierceShield` candidat (P1.5b) |
| **#Y** | FIFO de saison au reset | Ouvert P2 ; persistance filtrée (défaut, pas de `sv`) vs vidage complet (`sv`) |
| **#V** | `sv` schema-version | Différé (re-lié #Y) |
| **#M** | relique wide quantité vs arête | Ouvert ; quantité scalante P1.5b vs arête relique G (P4) |
| **#N** | pré-run + pool même écran | Tranché (même écran) |

**CLOS ce round** : **#DD** (ordre strict), **#BB** (seed partagé), **#Z** (gate §2.8). **NEUFS** : **#GG**
(axe apex choc, BLOQUANT), **#FF** (inter-familles MID), **#EE** (seuil nom de build — adopté), **#EE-ranked**
(scope seed daily). **CLOS antérieurs maintenus** : #D, #W, #T, #O (round 6), #Q2-relics, #S.

---

## 7. Pondération hédonique du tableau de fréquence VRR (retention §3.1) — adopté (doc)

**Adoption mineure mais utile** (retention §3.1) : l'enveloppe VRR ≤20 signaux/run (§2.9) **agrège des
signaux de poids émotionnel très différents**. Une offre de relique (identité du run, high-stakes) ≠ un signal
VRR boutique (low-stakes). Couper sans distinguer = borne arbitraire. **Ajouter une colonne POIDS HÉDONIQUE** :

| Source VRR | Fréq/run | Poids | Pondérée |
|---|---|---|---|
| Boutique (reroll) | ~9-14 | 1 | 9-14 |
| Moment du Run | ~3-4 | 3 | 9-12 |
| Surprise de Placement | ~2-3 | 2 | 4-6 |
| Offre de Relique | ~4-5 | 4 | 16-20 |
| Trace d'impact | 1 | 2 | 2 |
| **CONTRE LA MORT** (§4.1) | ~2-3 | 2 | 4-6 |

**Total pondéré ~44-60 unités.** Borne devient « ≤50-60 unités pondérées/run » (plus précis que « ≤20
bruts »). Si dépassement → couper en priorité les signaux poids=1 (boutique). **Doc pur, 0 code. §2.9 enrichi.
Enrichit #AA.**

---

## 8. Ce qui s'est amélioré ce round (mesurable)

**Le round 8 a élevé le débat de « détection de trous ponctuels » (rounds 4-7) à « audit d'hypothèses
systémiques ».** Améliorations mesurables vs v8 :

1. **1 affirmation optimiste du round 7 CORRIGÉE par code** (#GG) : « apex choc = 0 moteur » est faux si l'axe
   D est adopté → décision de spec bloquante explicitée. **Prouve que même les adoptions « code-vérifiées »
   d'un round précédent restent contestables au round suivant** (le grep `shockChain` du round 7 confirmait la
   *consommation* mais pas la *compatibilité* avec l'axe D).
2. **1 litige nuancé ROUVERT et tranché par preuve neuve** (#DD) : la nuance r07 (« même lot ») tombe car
   retirer `corruptor` change la représentation rang-3 → ordre strict requis. **La méthode « un litige nuancé
   reste ouvert tant qu'une preuve neuve peut le trancher » a payé.**
3. **2 paires de niche/dominance code-vérifiées au rang-3/4** (`corruptor`/`bile_spitter`, `rust_sentinel`/
   `stormcaller`) — l'audit col B s'étend de rang-2 à rang-2/3/4. **Une violation #10 (`rust_sentinel`) jamais
   détectée en 7 rounds.**
4. **3 hypothèses systémiques attaquées et corrigées** : (a) VRR à valence unique → signal RELIEF ; (b)
   Grimoire = découverte sans maîtrise → badge SDT-compétence ; (c) métrique d'offre uniforme → segmentée par
   tier + pseudo-décision.
5. **2 mécaniques de PROFONDEUR proposées (inter-familles MID #FF + resonance B)** — adoptées **comme spec à
   prouver en sim** (pas gravées), avec garde-fou saturation. C'est la 1re fois qu'une lentille attaque le
   **cloisonnement des familles** par P1.
6. **3 réorientations de calendrier** : Contrainte de Saison P4-light → **P2** ; CONFIG-CE P3 → **co-prio apex
   (P0.5)** ; #Z recommandé clos → **gate bloquant de §2.8**.
7. **Daily passe de « contrainte + leaderboard » à « seed partagé »** (#BB clos) — l'analogie StS Daily est
   désormais **non-paresseuse** (le mécanisme psychologique transféré, pas la forme).

**Litiges nets** : +4 neufs (#GG bloquant, #FF, #EE adopté, #EE-ranked recommandé) − 3 clos (#DD, #BB, #Z) =
**le débat converge** (les neufs sont plus précis et 2/4 sont déjà résolus/recommandés).

---

*Synthèse round 8/10 — rédigée le 2026-06-23. Intégration critique des 6 lentilles `rounds/r08-*.md` contre
le brouillon v8. **4 claims de code revérifiés par le synthétiseur** (`corruptor`/`bile_spitter` `units.lua:
64/124` ; `rust_sentinel`/`stormcaller` `:427/80` ; `runestone_golem`/`oath_keeper` `:431/353` ;
`dischargeShock`/`shockChain` `arena.lua:342-388` + `ops.lua:187` vs `tickDots:522` → axe D non implémenté).
**13 adoptions majeures + 8 précisions/métriques + 4 gates** (toutes data/doc/sim/RENDER/config). **3 litiges
clos** (#DD strict, #BB seed, #Z gate), **4 neufs** (#GG bloquant, #FF, #EE, #EE-ranked). **5 rejets/nuances
sourcés** (leaderboard creux→seed, MMR caché, 3 auto-rejets rétention, #FF/resonance non gravés). Lecture
seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe
seedée / DA grimdark / pixel art procédural), 32 invariants préservés.*
