# Round 07 — Synthèse adversariale (7/10)

> **Méthode** : intégration critique des 6 lentilles `rounds/r07-*.md` contre le brouillon v7
> (`ROADMAP-draft.md`, intégré round 6). On **adopte** les critiques valides et sourcées, on
> **rejette** les faibles (avec raison), on **consigne** les vrais litiges pour les rounds 8-10.
> C'est un débat, pas une addition. **2 claims de code revérifiés ce round par le synthétiseur**
> (`shockChain`, `shield_caster`) tranchent 2 questions ouvertes.
>
> **Garde-fou** : lecture seule du repo, écriture uniquement sous `docs/roadmap-lab/`. Piliers
> intacts (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).
> 32 invariants préservés (toutes les adoptions sont RENDER / IO / data / doc / sim ou décision
> éditoriale).

---

## 0. Ce qui change ce round (résumé exécutif)

**Le round 7 est un round de DÉTAILS DE CONTENU et de DÉTECTION DE BUGS LATENTS, pas de grands
litiges structurels.** Les 4 litiges majeurs clos round 6 (#D global pur, #W burn intentionnel,
#T SOFT/HARD, #O famines_math) **ne sont pas re-contestés** (5 des 6 lentilles les confirment
explicitement). Mais 3 lentilles ont **relu le code/calculé les stats** et débusqué **4 trous de
contenu sévères et 3 bugs latents de mécanique** que 6 rounds avaient manqués. La leçon de méthode
des rounds 4-6 (« grep avant d'affirmer ») **a payé une 3e fois** : 2 greps du synthétiseur ce round
tranchent 2 questions ouvertes.

**8 adoptions majeures (toutes data/doc/sim/RENDER, 0 invariant) :**

1. **`deep_kraken`/`skull_colossus` rang-5 = BLOQUANT P0.5** (units §2.1, code-vérifié synthé) — pas
   « décision différable » : `deep_kraken` DPS=0,154 **dépasse de 34 % le meilleur T3 transform**
   (`marrow_drinker` 0,115) ; ce sont des **stat-sticks `on_hit` purs sans règle d'équipe** au rang-5
   (qui doit être « transform/règle d'équipe », décision #10). **Promu en §3.7 BLOQUANT.**
2. **Apex choc rang-5 MANQUANT = trou de contenu structurel** (units §2.3, code-vérifié synthé) — la
   famille choc est la **seule des 5** sans rang-5 dans `U.pool` (live_wire r1 / 4× r2 / 2× r3 / 4× r4 /
   **0 r5**). Un build choc commit n'a **aucune conclusion de run** → mort de l'archétype en ranked.
   **Solution économique adoptée** : réorienter `skull_colossus` (libéré du rang-5 burn) **en apex choc**
   (`grant_team {shockChain}`) — résout §2.1 ET §2.3 d'un coup.
3. **NOM DE BUILD post-combat** (retention §2.2/Prop-A) — le Moment du Run nomme une **unité** mais
   jamais un **BUILD** ; sans identité de run nommée, la fierté de construction reste de l'attribution
   d'événement, pas d'identité. Trivial à dériver de `dot_family`+`shape` (P0.5). **AJOUTÉ en §2.4bis,
   PRIORITÉ 1 RENDER.**
4. **Métrique de QUALITÉ D'OFFRE 1-parmi-3** (relics §2.1/Prop-A) — la roadmap corrige le **contenu** du
   pool (garantie B-E, déprio F, arcs temporels) mais ne **mesure jamais la densité de décisions
   réelles** (Keith Burgun : couplage trop lâche = arbitraire, trop fort = évident). **AJOUTÉ à la sim
   P0.5 (§7.4bis), précondition P1.**
5. **`bleedPierceShield` potentiellement inerte vs `shield_caster`** (synergies §2.1, code-vérifié
   synthé) — `ward_weaver` re-bouclier **20/4 s, SCALANT par niveau** → un `ward_weaver` niveau-3
   (60/4 s) **absorbe entièrement** le drain de 1 pt/tick. **Test 2 inter-famille ÉTENDU** à un
   `shield_caster` actif (pas juste `shield_aura` statique).
6. **Cas dégénéré CHOC dans le tableau de saturation d'inc** (synergies §2.2) — `base_dps tick = 0`
   pour le choc (condensateur) → `seuil_inc = (cap/base_min)−1 = N/0 = ∞/crash`. **Exception choc
   ajoutée** au tableau §5.2 + le twist choc-4 ne peut pas être un `more` sur l'output.
7. **`forked_tongue` N'EST PAS silencieuse** (relics Prop-D + synthé) — grep `shockChain` : **consommé**
   à `ops.lua:187` (lit `tf.shockChain`) et posé à `:276`. La relique **chaîne bien la décharge** → le
   gating conditionnel (§4.7) est **justifié, pas du code mort**. **#Q2-relics CLOS.**
8. **Barre XP de boutique visible intra-round** (progression §2.3) — la décision « monter vs reroller
   vs acheter » est la décision éco centrale ; sans la barre XP, les sims P3 mesurent un **joueur
   aveugle**. **AJOUTÉ en §2.5bis, PRIORITÉ 1 RENDER.**

**3 ré-ancrages / précisions de spec :**
- **`famines_math` tri par coût : exiger un tri STABLE secondaire par `id`** (relics §1.3) — `table.sort`
  Lua **n'est pas stable** (lua.org/manual/5.1#5.5) → 2 unités de même coût = non-déterministe = viole
  l'invariant #2. **1 ligne de plus dans la spec #O, NON-NÉGOCIABLE.**
- **Reliques E = AMPLIFICATEURS, pas CRÉATEURS d'identité** (relics §2.2) — les E (everburn, plague_communion…)
  **n'ont aucun downside** (principe relics-design #2) → elles amplifient un archétype existant, elles ne le
  créent pas (≠ boss relics StS à downside qui **forcent** le theming). **Conséquence forte : P1 (types)
  est un PRÉREQUIS DE FUN, pas une amélioration de contenu** — sans types, les reliques seules ne portent
  pas 3-4 identités de build distinctes.
- **VRR boutique : demi-vie courte si la règle est devinable** (retention §2.1) — Hopson 2001 (20-30 %)
  vaut pour le **VRR pur** (règle invisible) ; notre signal est **semi-prévisible** (règle `rang≥shopTier`
  OU `≥60 % dot_family`) → dégénère en « info utile » après ~10 runs. **Spec Phase 2 documentée** (3e
  facteur : distance à la 3e copie), non bloquante.

**3 litiges neufs + 2 reconfirmés à trancher :**
- **#BB (neuf, ranked §5.1)** : le Daily est-il **ranked ou unranked** ? (recommandation : unranked +
  leaderboard journalier séparé, modèle StS).
- **#CC (neuf, synthé)** : `wither_bloom` après le fix C2 ne déclenche **plus** `plague_communion`
  (afflictionCount=1) → son rôle « multi-affliction proxy » s'effondre ; reconcevoir ou accepter ?
- **#DD (neuf, synergies §2.3 + units §2.3)** : faut-il une 3e mesure sim **`--pool-repr`**
  (représentation pool par famille/rang) AVANT `--poison-frac` ? (poison 15 unités vs choc 11 = ~36 %
  de sur-visibilité boutique non mesurée).
- **#Z (reconfirmé)** : 2 lentilles convergent (ranked §3.3 + retention Prop-D) vers **IA avec
  formulation distincte** → **recommandé à CLORE**, décision DA finale à l'user.
- **#AA (reconfirmé, enrichi)** : seuil VRR boutique — ajout d'un critère de **prévisibilité de la règle**
  (retention §2.1) au-delà du seul taux de déclenchement.

---

## 1. Adoptions — contenu (le cœur du fun)

### 1.1 ADOPTÉ — `deep_kraken`/`skull_colossus` rang-5 = correction BLOQUANTE (units §2.1/P-A)

**Critique (units-power, `units.lua` relu intégralement + DPS calculés)** : les deux v7 rang-5 sont des
**stat-sticks `on_hit` purs** :
- `deep_kraken` : dmg=12/cd=78 = **DPS 0,154** + `poison{dps=4}` simple, **aucune règle d'équipe**.
- `skull_colossus` : dmg=11/cd=84 = **DPS 0,131** + `burn{dps=4}` + aggro=40, **aucune règle d'équipe**.

**Vérifié par le synthétiseur** (`units.lua:421-423`, `:437-439`) : exact. `deep_kraken` DPS **dépasse de
34 % `marrow_drinker`** (0,115, le plus haut T3 transform légitime) ; `skull_colossus` dépasse 7 des 8 T3.

**Pourquoi c'est valide et adopté** : la décision #10 (`cost=rank` = complexité croissante) est un
**contrat d'apprentissage** ; un rang-5 (coût max) doit être une **transform / règle d'équipe**. Un
stat-stick à rang-5 viole ce contrat (Giovannetti GDC 2019 : « the power of a card must match its
complexity — a rare that does nothing complex is worse than a common with a twist »). **Aggravant async**
(units §2.1) : un `deep_kraken×3` (niveau-3 = DPS frappe 0,462) en ghost tier-4/5 est un **mur de DPS brut
sans counter-play lisible** (pas de trigger conditionnel, pas d'axe à exploiter) → **amplifie les matchups
ennuyeux** dans la méta async figée. C'est exactement ce que le pilier « petits nombres, profondeur
émergente » refuse.

**Décision (data, 1-2 lignes, BLOQUANT avant P3)** : option (a) **rétrograder/réorienter**. `skull_colossus`
→ **apex choc** (§1.2 ci-dessous, résout 2 trous). `deep_kraken` → **rang-4** (HP=84/DPS=0,154 = haut mais
gérable en rang-4 ; rang-3 trop haut en HP). Option (b) « ajouter une règle d'équipe » rejetée pour
`deep_kraken` car `grant_team {poisonNoCap}` **duplique `festering`**. **→ §3.7 promu BLOQUANT.**

### 1.2 ADOPTÉ — Apex choc rang-5 manquant + réorienter `skull_colossus` (units §2.3/P-C)

**Critique** : la famille choc est la **SEULE des 5** sans rang-5 dans `U.pool`. **Vérifié synthé** :
live_wire (r1), stormcaller/thunderhead/static_swarm/siphon_jelly (r2), stormlord/storm_anchor (r3),
galvanizer/dynamo_priest/arc_warden/rust_sentinel (r4), **rien en r5**. Les 4 autres familles ont 1-2
apex rang-5. Le choc a 11 unités (densité égale) **mais aucun closing move**.

**Pourquoi c'est valide** : Giovannetti GDC 2019 + Entalto 2026 (« build identity must be clear within
2 min ; every archetype must have a closing move ») — un joueur qui commit choc et monte au shopTier 5
**ne trouve jamais d'apex** → croit que c'est de la malchance, pas une absence de design. **Aggravé par
la boucle VRR boutique** (§2.9) : une famille sans surprise apex est une boucle **tronquée**. **Aggravé en
async** : un ghost choc tier-4 sans rang-5 est **structurellement moins menaçant** → `--meta-convergence`
mesurerait une convergence **artificielle** vers les familles à apex (pas une préférence joueur).

**Décision adoptée (data, 0 moteur)** : réorienter `skull_colossus` (libéré du rang-5 burn par §1.1, aggro=40
+ HP=92 = morphologie « conducteur-terminateur » grimdark-cohérente) **en apex choc rang-5** via
`grant_team {shockChain}` (les décharges sautent à un voisin de la cible) — **un `teamFlag` qui s'insère
dans le moteur existant**. Budget stat : réduire dmg/cd vers DPS≈0,100-0,110 (pattern T3 pur, cohérent
`ash_maw` 0,100). **Cela résout §1.1 (stat-stick rang-5 burn) ET §1.2 (apex choc) simultanément.**

**Nouveauté code-vérifiée décisive (synthé)** : `shockChain` **est déjà entièrement câblé** —
`ops.lua:187` (`local chain = p.chain or (tf and tf.shockChain) or nil`) le **consomme**, `:276` le
pose via `grant_team`. Donc l'apex choc proposé est **0 moteur** (juste data) — le mécanisme de chaîne
existe déjà (`forked_tongue` l'utilise). **PRIORITÉ : avant P1** (le palier-4 type choc sans apex = mort
de l'archétype en ranked).

### 1.3 ADOPTÉ — Paires de niche quasi-identiques rang-2 (units §2.2/P-B)

**Critique (calculs `units.lua`)** : la règle `P90/P10 ≤ 3×` **passe** (2,11× sur les DoT rang-2) **mais
masque la redondance de NICHE**. Paires quasi-identiques (params ≤20 % sur l'axe principal) :
- `pyre_herald` (burn dps=6, dur=170) ≈ `emberling` (dps=6, dur=150) — différentiel = 9 % DPS frappe.
- `wailing_shade` (bleed dps=2, slow=15 %) ≈ `razorkin` (dps=2, slow=20 %) — différentiel = 4 % DPS frappe.
- `byakhee` (bleed dps=3, slow=10 %) ≈ `gash_fiend` (dps=3, slow=20 %) — doublon + violation cross-rank (§1.4).

**Pourquoi c'est valide** : a327ex.com (« 1 pet = 1 valeur ; si 2 pets font la même chose dans la même
tranche éco, l'un est invisible ») + pool **LOCAL** (≠ TFT partagé) → 2 enablers quasi-identiques co-
apparaissent souvent → le joueur prend le 1er → **l'autre n'existe pas pour lui** → les « 83 unités » ne
se manifestent pas dans le jeu vécu (15-20 niches perçues). La règle P90/P10 mesure le **spread** (lisibilité
de rang), pas la **distinction de niche** — **les deux instruments sont nécessaires**.

**Décision** : la colonne B de l'audit (§3.1) ajoute explicitement la **détection de paires de niche**
(≤20 % d'écart sur l'axe principal) → différencier l'axe OU retirer la plus faible de `U.pool`. **Candidats
prioritaires croisés avec la cohorte v7 (§3.2)** : `pyre_herald`, `wailing_shade`, `byakhee`. **Garde-fou** :
ne pas retirer si ça passe une famille sous le plancher ≥2/rang (rot rang-2 = 2 enablers seulement).

### 1.4 ADOPTÉ — Violation cross-rank `byakhee` r2 > `vein_splitter` r3 (units §2.4/P-D)

**Critique (vérifié synthé)** : `byakhee` (rang-2, dmg=8/cd=50 = **DPS 0,160**) **dépasse de 76 %**
`vein_splitter` (rang-3, dmg=4/cd=44 = **DPS 0,091**). Plus sévère que l'anomalie `cinder_cur`/`bellows_priest`
(1,37×) déjà signalée. Cause : `byakhee` est une v7 « familles visuelles » sans calibrage cross-rank — son
DPS frappe est emprunté à un profil rang-3 carry.

**Pourquoi c'est valide** : Ariely/Loewenstein/Prelec 2003 (ancrage par comparaison simultanée) — un joueur
qui voit `byakhee` à 2 or ET `vein_splitter` à 3 or dans la **même boutique T3** n'achète jamais
`vein_splitter`. L'inversion **cross-rank** est le pire cas de signal `cost=rank` cassé (2 tiers concernés).

**Décision** : colonne E de l'audit ajoute la règle cross-rank explicite (« DPS_frappe rang-n < médian
rang-n+1 par famille ») ; `byakhee` → réduire dmg 8→5-6 (DPS 0,100-0,120, budget rang-2). **Tranché avec la
cohorte v7 (§3.2).**

### 1.5 ADOPTÉ — Singleton bleed rang-1 `gnaw_rat` (units §1.4/Q4)

**Critique** : la roadmap §3.1 documente burn (`ash_moth`) et rot (`carrion_pecker`) comme singletons
rang-1 mais **oublie `gnaw_rat`** (bleed rang-1, `units.lua:446`). **3 familles sur 5** ont un singleton
rang-1 (burn, rot, bleed) ; seuls poison (`spore_tick`) et choc (`live_wire`) en ont sans le souligner.

**Pourquoi c'est valide et adopté (mineur mais correct)** : SAP « early tiers = introduction à chaque
mécanique ». La décision de plancher rang-1 doit traiter **les 5 familles uniformément** — ne pas en
documenter 2 et oublier la 3e. **Coût 0** : ajouter `gnaw_rat` à la liste des singletons rang-1 dans §3.1
(rareté voulue OU trou, comme les 2 autres).

### 1.6 ADOPTÉ — NOM DE BUILD post-combat = identité de run nommée (retention §2.2/Prop-A)

**Critique (la plus forte de la lentille rétention)** : 6-8 rounds ont enrichi le **signal** du Moment du
Run (source, placement, P75, chaîne) **mais n'ont jamais nommé le BUILD**. « Ta torche a brûlé 5 ennemis »
(attribution d'événement) ≠ « TU ÉTAIS UN BRÛLEUR DU PUITS — 5 consumés » (identité de run). Déclos 2025
(fierté de construction = s'identifier à ses décisions) exige une **identité**, pas un fait isolé.

**Pourquoi c'est valide** : DEV Community 2026 (dev.to/yurukusa, implémentation concrète roguelite) — « Stats
are data. Names are identity. [...] The name converts a technical state into a social object. » Dans The Pit,
c'est **trivial** : dériver de `dot_family` (P0.5) + `shape` + présence d'unités spéciales un nom grimdark
(≥4 burn → « BRÛLEUR DU PUITS », 2+2 → « ALCHIMISTE DU PUITS », croix+taunt → « CROISÉ MAUDIT »…). Deux
fonctions : (a) **ancre le Moment du Run dans l'identité** (« [BRÛLEUR DU PUITS] — TA [ASH_MOTH] A CONSUMÉ…»)
au lieu de hors d'elle ; (b) **rend le Grimoire II identifiable par archétype** (goal-gradient sur identité
nommée).

**Décision (AJOUTÉ §2.4bis, PRIORITÉ 1 RENDER, ~1 h)** : ~8-10 noms (5 familles + 2 sigil-spéciaux +
fallback), data-driven, lus après combat + persistés dans `grimoire.lua` (« tes 5 derniers runs :
[BRÛLEUR], [ALCHIMISTE]… » = arc d'identité). **Grimdark seul** (titres sombres courts, jamais félicitation).
**Précondition `dot_family` (P0.5)** → codable en // dès P0.5 livré. **Zone sans test** → test de dérivation
du nom sur golden. **Dépendance** : ce nom **subsume** la vue Grimoire-par-archétype (retention §2.4) et
**se simplifie** si P1 (types) est adopté (le nom = palier de type actif au résultat, supprime l'ambiguïté
2+2 — Q_R7_2).

### 1.7 ADOPTÉ — Reliques E = AMPLIFICATEURS, pas CRÉATEURS (relics §2.2/Prop-B)

**Critique** : le brouillon qualifie les reliques E (`forked_tongue`, `everburn`, `open_wounds`,
`plague_communion`) de « payoffs-late build-defining » analogues aux **boss relics StS**. **C'est une
analogie paresseuse** : les boss relics StS ont un **downside explicite** (Ectoplasm : +1 énergie, plus
d'or ; Fusion Hammer : +1 énergie, pas de forge) qui **FORCE** la construction autour d'elles (Giovannetti
2018 : « the downside functions as a forced theming »). **Nos E n'ont aucun downside** (principe relics-
design #2 : « aucune relique ne handicape ») → elles **amplifient** un archétype existant sans le **créer**.
La décision « est-ce que ça aide mon build ? » est presque toujours oui si le joueur est déjà engagé.

**Pourquoi c'est valide ET important** : la vraie analogie StS est les **rares non-boss** (Dead Branch,
Frozen Egg) — amplification sans pivot forcé. **Conséquence de design décisive** : si les E ne créent pas
l'identité, **P1 (types) DOIT la créer** — sinon P1 est une duplication fonctionnelle des E (ambiguïté de
design). **Cela élève P1 de « amélioration de contenu » à PRÉREQUIS DE FUN** (relics Q4 : les reliques
seules ne portent pas 3-4 identités de build distinctes dans un run de 10 victoires).

**Décision (doc ~10 lignes, §4.11)** : ajouter une **hiérarchie de build-definition** explicite —
**Types P1 = CRÉATEURS** (paliers 2/4, oriente 5-9 rounds) ; **Reliques B = SHAPERS** (inc, amplifie l'axe
engagé) ; **Reliques E = COURONNEURS de commit** (transforment une règle, post-commit) ; **Reliques A =
FONDATIONS** (pas de vote d'identité). Rend explicite que les E sont **correctement** en tier-4 (post-commit)
ET que P1 est leur prérequis.

### 1.8 ADOPTÉ — Audit rang-5 dédié + `wither_bloom` post-C2 (units §1.5/Q1 → litige #CC)

**Constat croisé (units Q1 + le fix C2 §3.8)** : après C2 (`afflictionCount` ne compte que les dps réels),
`wither_bloom` (rot{base=2} + bleed{dps=0} + poison{dps=0}) compte **1 famille active** (rot), pas 3 →
**ne déclenche plus `plague_communion`** seul (ce qui est l'objectif du fix). **MAIS** son rôle de « proxy
multi-affliction » s'effondre : il pose 3 familles dont 2 inertes en dps, et une aura `miasma_acolyte`
posée sur lui amplifierait toujours un dps de 0.

**Décision (litige #CC, neuf)** : à trancher avant P1.5b — soit (a) **reconcevoir** `wither_bloom` avec des
dps non-nuls sur bleed/poison (le slow/weaken deviennent secondaires, pas les axes principaux) → il
redevient un vrai multi-affliction ; soit (b) **accepter** qu'il est un rot-T3 avec slow+weaken cosmétiques
(et le documenter comme tel). **Lié à l'option C1** (`apply_status` op slow/weaken sans dps, §3.8) qui le
nettoierait proprement. Non bloquant P0.5 (C2 ferme le faux signal ; la reconception est P1.5b).

---

## 2. Adoptions — synergies / effets

### 2.1 ADOPTÉ — Test 2 inter-famille ÉTENDU : `shield_caster` actif, pas juste `shield_aura` (synergies §2.1/P1)

**Critique (la plus forte de la lentille synergies)** : le twist bleed-4 = `bleedPierceShield` (1 pt
bouclier/tick) peut être **quasi-inerte** contre les builds à `shield_caster` (re-bouclier périodique).
Le test 2 spécifié en §5.2 (`shield_aura` **statique**) est insuffisant — il ne teste que les boucliers
qui ne se régénèrent pas.

**Vérifié par le synthétiseur (`units.lua:362-364`)** — claim CORROBORÉ et chiffré : `ward_weaver` pose
`shield_caster {value=20, cd=240}` = **re-bouclier 20 toutes les 4 s** aux voisins, **et la valeur SCALE
par niveau** (`LEVEL_MULT={1,1.8,3}`). Donc :
- vs `ward_weaver` **niveau-1** : drain bleed ≈ 1 pt/tick × 240 ticks = **240 ponctionnés** entre 2 regens
  de 20 → le drain **gagne** largement.
- vs `ward_weaver` **niveau-3** : regen = **60/4 s** ; si le bleed actif est faible (1-2 instances), le drain
  peut être **entièrement absorbé** → twist quasi-inerte (exact schéma `sacred_shield invulnT=30`).

**Décision (adopté)** : étendre le **test 2 inter-famille** en **2 sous-tests** (§5.2) :
- **(2a)** `shield_aura` statique + `bleedPierceShield` → drain progressif validé (l'aura ne se reconstruit
  pas en combat).
- **(2b)** `shield_caster` actif (`ward_weaver`, voire niveau-3) + `bleedPierceShield` → mesurer le bouclier
  **NET** après N ticks. **Si NET < 0 (absorbé) → augmenter à 2 pts/tick OU passer à un burst de stacks**
  (« à 5 stacks bleed, vider 50 % du bouclier courant »). **Précondition** : le drain doit être net > 0 sur
  une durée de combat standard. **PRIORITÉ HAUTE, précondition P1.** + **Q3 synergies** : clarifier si
  `bleedPierceShield` s'applique à **tous les ticks de toutes les instances** (alors drain = nb_stacks ×1 pt,
  bien plus fort que « 1 pt/tick »).

### 2.2 ADOPTÉ — Exception CHOC dans le tableau de saturation d'inc (synergies §2.2/P2)

**Critique** : le tableau de saturation (`seuil_inc = (cap/base_min)−1`) a un **cas dégénéré non signalé**
pour le choc : `base_dps tick = 0` (condensateur, 0 dégât à la pose) → la formule = `N/0` = infini/crash,
et le cap du choc est `SHOCK_STACK_CAP=8` (stacks), **pas** `DOT_CAP_MULT=3` (output DoT) — deux axes
incompatibles.

**Pourquoi c'est valide** : si un agent/l'user remplit le tableau sans cette précision, le choc est soit
ignoré (non calculable) soit mal calculé (DPS frappe ≠ DPS décharge) → le palier choc-4 serait spécifié
sur un budget d'inc **sans rapport avec la décharge réelle**. a327ex : un burst-condensateur est un
« Counter » (événement, pas durée) → métrique = `P(décharge) × magnitude`, pas `seuil_inc`.

**Décision (adopté, doc §5.2)** : ligne d'exception choc explicite — `base = N/A` ; cap = `SHOCK_STACK_CAP=8`
(pas `DOT_CAP_MULT=3`) ; métrique = `burst_DPS_eq` (§3.1a). **Le palier choc-4 ne peut PAS être un `more`
sur l'output** ; il doit modifier un des 3 axes : `shockStackBonus` (nb stacks/hit), `shockAmpMult`
(magnitude ampli par famille du poseur), ou `shockTrigger` (condition de décharge : `any_dot` vs
`dot_family` seul). **PRIORITÉ HAUTE, précondition P1.**

### 2.3 ADOPTÉ (en litige #DD) — `--pool-repr` : 3e mesure de représentation de pool AVANT `--poison-frac` (synergies §2.3/P3 + units §0)

**Critique convergente (2 lentilles)** : `--poison-frac` (propagation) et `--no-weaken` (weaken) mesurent
la **puissance** de poison, mais pas sa **sur-représentation de pool**. Poison = 15 unités vs choc = 11
(00-state §2.1) → P(voir poison en boutique) ≈ **36 % plus élevée** que choc à cotes uniformes. La cause
de **visibilité** est **antérieure** à toute propagation : si poison est vu 2,3× plus souvent en T2 (calcul
synergies §2.3), le joueur construit poison **par défaut d'exposition**.

**Pourquoi c'est valide** : SAP (mobilegamereport.com 2026 : la profondeur commence par la **visibilité en
boutique**, surtout en pool LOCAL où il n'y a pas de concurrence inter-joueurs pour les unités). `--poison-frac`
seul corrigerait « l'arbre et pas les racines » — il ajusterait la puissance d'un poison **déjà sur-représenté
ET sur-puissant**, les deux leviers se confondant dans le win%.

**Décision (litige #DD)** : `--pool-repr` (~10 lignes, compter unités/famille/rang, alarme si
`max_famille/min_famille > 1,5` par rang) est **ADOPTÉ comme mesure** — **MAIS son ORDRE (avant ou en
parallèle de `--poison-frac`) reste un litige** : la critique veut l'imposer **avant** ; le synthétiseur
note que l'audit colonne B (§3.1, retrait des enablers POOL redondants) **fait déjà ce travail
qualitativement** — `--pool-repr` en est la **validation quantitative**, pas un préalable bloquant
indépendant. **Position synthé** : intégrer `--pool-repr` au **même lot P0.5** que l'audit colonne B et
`--poison-frac` (ils se nourrissent), sans imposer un ordre strict. **À trancher round 8** si une lentille
montre que l'ordre change le résultat. **Lié à Q2 synergies** (répartition choc par rang, qui aggrave la
sur-représentation poison en early).

### 2.4 ADOPTÉ (doc) — Condition de placement rot-counter-tank (synergies §2.4/P5)

**Critique (précise, faible sévérité)** : « rot → tanks/taunt » (col I) n'est vrai que **si le rot atteint
les tanks**, or le ciblage déterministe cible la **colonne avant**. Si le sigil adverse met ses **carries
en front** (croix, carry central) et ses **tanks en flanc**, le rot cible les carries, pas les tanks. **Le
rot counter les tanks SEULEMENT quand les tanks sont en front adverse** — non garanti.

**Pourquoi c'est valide** : conséquence directe du ciblage déterministe (combat-model-decision §4). La
colonne I doit **noter cette condition**, et la relique rot tier-4 (P1.5b) devrait idéalement fonctionner
**indépendamment du placement adverse** si l'archétype rot-tank est voulu comme réponse fiable.

**Décision (doc, col I §3.1)** : ajouter la condition de placement + **candidat twist/relique rot-4 =
amputation de la cible à PV_max le plus élevé** (pas la cible front) → rend le counter rot-tank
**placement-indépendant**. Doc seulement, intègre la spec de la relique rot tier-4 (P1.5b).

### 2.5 NOTÉ (P3/diagnostic) — Latence early du choc (synergies §2.5/P4)

**Critique (faible)** : en early (3 slots), un build choc a peu d'unités de la `dot_family` ciblée + la
cible adverse a peu de DoT actif → la décharge choc amplifie un tick **qui peut ne pas exister** → le choc
**paraît faible en early** non par puissance mal calibrée mais par **condition de déclenchement non remplie
structurellement** → le joueur quitte l'archétype avant le mid.

**Décision (P3/doc, optionnel)** : ajouter **CONFIG-CE (Choc Early)** à la matrice sim (§3.4) — `{1 choc +
1 burn-poseur + 1 stat-stick} vs IA round-2`, mesurer `burst_DPS_eq` réel vs théorique ; écart > 40 % →
documenter une règle de rampe (fallback dégât direct non-nul si 0 DoT actif). **Recoupe le `--meta-convergence`
artificiel (units §2.3) et la latence VRR early (#Q déjà ouvert).** Non bloquant ; signalé pour ne pas
graver un design d'apex choc que la sim contredira.

---

## 3. Adoptions — reliques

### 3.1 ADOPTÉ — Métrique de QUALITÉ D'OFFRE 1-parmi-3 (relics §2.1/Prop-A)

**Critique (la plus structurante de la lentille reliques)** : la roadmap corrige le **contenu** du pool
(garantie B-E §4.1, déprio F §4.6, arcs temporels §4.8) mais **ne mesure jamais la QUALITÉ DE DÉCISION** de
l'offre. Keith Burgun (keithburgun.net/pick-1-of-3, vérifié) : « when powers are loosely coupled, the
decision is random/arbitrary ; when highly coupled with no restrictions, the choice is obvious — neither
is interesting. » La garantie de pertinence peut être satisfaite **formellement** tout en produisant une
offre **triviale** (1 option dominante) ou **arbitraire** (0 tension).

**Pourquoi c'est valide ET précondition P1** : si la qualité d'offre est faible **avant** P1, les paliers de
type peuvent la **dégrader encore** (un palier-4 burn rend les reliques B burn encore plus triviales).
Connaître la baseline AVANT permet de spécifier les twists pour **diversifier** les décisions, pas les
homogénéiser.

**Décision (AJOUTÉ §7.4bis, sim ~10 lignes, P0.5, s'insère dans CONFIG-PC)** : `offer_decision_quality` —
pour N=200 runs, à chaque offre, calculer le `lift` de win-rate (déjà codé) des 3 reliques sur les 10
combats suivants. **Triviale** = `lift(1re) > 2× max(lift des 2 autres)` ; **arbitraire** =
`std_dev(lift des 3) < 0,02`. **Cible : < 40 % triviales + < 20 % arbitraires** (> 40 % d'offres en tension
réelle). **Baseline mesurée sur le pool actuel (21 reliques) AVANT P1.**

### 3.2 ADOPTÉ (NON-NÉGOCIABLE) — `famines_math` : tri STABLE secondaire par `id` (relics §1.3)

**Critique (bug de déterminisme dans la spec)** : l'option (a) #O (« tes 3 unités les plus coûteuses »)
modifie `R.apply` avec `table.sort(comp, by cost desc)`. **Mais `table.sort` en Lua n'est PAS stable**
(lua.org/manual/5.1#5.5) → si 2 unités ont le **même coût** (fréquent : 2 rang-3), l'ordre de sortie peut
**varier selon l'ordre d'insertion** → **viole l'invariant #2 (déterminisme)**.

**Pourquoi c'est valide et critique** : un snapshot async rejoué doit donner le **même résultat** ; un tri
non-déterministe sur égalité de coût casse cette garantie de façon **silencieuse**. **Décision (NON-
NÉGOCIABLE, +1 ligne dans la spec #O §4.5)** : tri **secondaire par `id` alphabétique** —
`table.sort(comp, function(a,b) c1,c2 = a.cost or 0, b.cost or 0; if c1 ~= c2 then return c1 > c2 else
return a.id < b.id end end)`. Garantit le déterminisme. Le test #21 vérifie aussi cet edge-case (2 unités
de même coût → ordre stable).

### 3.3 ADOPTÉ — `forked_tongue` N'EST PAS silencieuse (relics §2.4/Prop-D, grep synthé) — #Q2-relics CLOS

**Critique (Prop-D)** : grep `shockChain` dans `arena.lua` pour confirmer si le flag `forked_tongue`
(`shockChain=1`) est **consommé** ou si c'est un placeholder silencieux. Si non lu → relique tier-4 inerte
en production + gating conditionnel = code mort.

**Vérifié par le synthétiseur (grep `src/`)** : **`shockChain` EST consommé** — `ops.lua:187`
(`local chain = p.chain or (tf and tf.shockChain) or nil`) le lit pour fixer le nombre de rebonds,
`:276` le pose via `grant_team`. Donc **`forked_tongue` chaîne bien la décharge** ; ce n'est ni un stub
ni du code mort. **#Q2-relics CLOS** : le gating conditionnel (§4.7, offrable dès 3 wins si ≥1 unité choc)
est **justifié**. La seule dépendance restante : si l'axe D est adopté (P0.5), le « rebond » devient
propagation d'ampli DoT — la reformulation reste la 1re tâche de P1.5a après #G tranché (déjà acté §4.7).

### 3.4 ADOPTÉ — `sacred_shield` cible 120 ticks (haute) (relics §1.4) + tableau de saturation PAR RANG (relics §2.5/Prop-E)

**Précision 1 (relics §1.4)** : le brouillon §4.9 acte « `invulnT` cible 60-120 ticks ». La lentille
précise que la **valeur haute (120 ticks = 2 s)** est recommandée : à 120 ticks, les unités cd-court
(rang-1, cd≈180-240) **n'ont pas encore frappé** → l'invulnérabilité **bloque le 1er hit de chaque unité
adverse** = avantage **lisible et visible**, pas « quelques ticks de DoT ». **Décision** : noter `invulnT
[PH] cible 120` (haute) dans §4.9 (reste à valider en sim sans dépasser FATIGUE_START=1020).

**Précision 2 (relics §2.5/Prop-E)** : le tableau de saturation d'inc doit spécifier le seuil **PAR RANG**,
pas seulement par famille — `BLEED_DPS_CAP=12` est un cap **absolu** : pour un bleed rang-2 (dps=2), seuil =
500 % (marge énorme) ; pour un bleed rang-3 (dps=6), seuil = **100 %** (marge serrée : si inc naturel=0,58,
reste 42 %). **Décision (adopté, +5 lignes §5.2)** : le tableau ajoute une colonne « rang-3 représentatif »
pour les familles à cap fixe (bleed). **Recoupe l'exception choc §2.2** (le tableau a 2 cas spéciaux : choc
hors-formule, bleed par-rang).

### 3.5 ADOPTÉ (P3) — Garantie de pertinence renforcée en early (relics §2.3/Prop-C)

**Critique** : en early (plateau 3 slots, 1 burn + 1 bleed + 1 poison), la garantie de pertinence est
satisfaite **simultanément** pour les 3 familles → l'offre propose un B **arbitraire** qui « confirme un
axe à 33 % » au lieu d'orienter. Burgun : « orientation requires a cost to not committing » — et en early,
rien n'est perdu à ne pas committer.

**Pourquoi c'est valide mais NON bloquant** : la garantie actuelle est **meilleure que pas de garantie**.
**Décision (PRIORITÉ 3, P1.5a)** : pour les rounds ≤3 wins, un B est « pertinent » seulement si sa famille
≥50 % de la compo OU ≥2 unités de cette famille achetées (~3 lignes dans `rollRelicChoices`). Empêche la
satisfaction triviale en early. Test #3 à adapter avec le reste (invariant #3 déjà reformulé par §4.1).
**Croisé avec le drapeau Q4 déjà ouvert** (distribution des familles round 3).

### 3.6 ADOPTÉ — `pierceShield` (hollow_choir réorienté) ≠ doublon de `bleedPierceShield` à vérifier (relics §1.5)

**Précision** : si `hollow_choir` est réorientée en `pierceShield` (option §4.10, P1.5b), vérifier qu'elle
**n'est pas un doublon fonctionnel** du twist bleed-4 `bleedPierceShield`. **Décision** : les deux réduisent
les boucliers mais par mécanismes distincts (relique = flat instantané / twist = par tick) → **pas un doublon
si les niveaux d'activation et magnitudes diffèrent significativement** (à croiser colonne F de l'audit). Doc,
non bloquant, P1.5b.

---

## 4. Adoptions — progression / économie & ranked

### 4.1 ADOPTÉ — Barre XP de boutique visible intra-round (progression §2.3) — PRIORITÉ 1

**Critique** : la décision **« monter (BUY_XP) vs reroller vs acheter »** est la décision éco **centrale**,
en temps réel pendant la boutique. Si le joueur ne voit pas (a) son XP vs seuil du prochain tier, (b) l'XP
passive de ce round, (c) ce que +4 XP lui rapporte → il **ne peut pas évaluer le coût d'opportunité**. TFT
affiche la barre XP en permanence (lolchess.gg/guide/exp) ; HS:BG affiche le coût d'upgrade à côté de l'or.

**Pourquoi c'est valide ET URGENT avant P3** : les sims P3 supposent un **joueur informé qui décide**. Sans
ce signal, on calibre pour un **joueur aveugle** et on livre un jeu aveugle (même logique que le tooltip de
cotes §2.5, mais pour l'axe XP — qui est **plus** décisionnel). **Décision (AJOUTÉ §2.5bis, PRIORITÉ 1
RENDER, ~1 h)** : afficher « XP : {shopXp}/{xpToNext()} → Tier {shopTier+1} » + preview BUY_XP au survol
+ « +1 XP passif fin de round ». Lit `state.shopXp`/`shopTier`/`xpToNext()` (déjà exportés), 0 invariant.
Test headless : pas de crash à `shopTier==MAX` (`xpToNext()=nil`).

### 4.2 ADOPTÉ — Pivot T4 (BUY_XP = rang-4) dans le tableau d'intention éco (progression §2.2)

**Critique** : à `BUY_XP_COST=4`, le ratio BUY_XP/unité est **4:1 en T1-T3** (monter = sacrifice lourd =
tension voulue) mais devient **1:1 en T4** (monter = même coût qu'une unité rang-4) — un **point de pivot
décisionnel** non documenté. Intentionnel (« est-ce que T5 rapporte plus qu'une unité T4 ? » = profondeur
réelle) ou accidentel (déséquilibre) ?

**Pourquoi c'est valide** : le tableau d'intention (§7.0) est **précondition** des sims P3 (acté round 6) ;
`BUY_XP_COST` est la 2e constante la plus décisionnelle (après `REROLL_COST`) et **n'a jamais eu d'intention
documentée**. **Décision (adopté, +1 ligne §7.0 + 5e métrique sim §7.1)** : documenter le pivot T4 ;
`pivot_T4_decision_rate` (P(BUY_XP vs achat rang-4 en T4)) cible **30-70 %** (ni dominant ni négligé). <30 %
= BUY_XP trop cher ; >70 % = montée automatique. Intention `[TBD]` soumise à l'user.

### 4.3 ADOPTÉ (précision doc) — Gel de boutique : critère STRUCTUREL, pas « hunt médian » (progression §2.1)

**Critique** : le critère du gel (freeze SAP) « si hunt médian > 3 rounds → utile » est la **mauvaise
question**. La valeur du freeze SAP a 2 fonctions propres : **(A) report de décision** (option « now or
later ») et **(B) signal d'information** (séparer gelé/nouveau au reroll) — **aucune liée au hunt médian**.
Or dans The Pit : (A) est **structurellement invalide** (budget non reporté entre rounds → geler pour le
prochain round = acheter avec un budget qu'on n'a pas) ; (B) est **peu marginale** (à `REROLL_COST=1`,
explorer coûte déjà presque rien, vs SAP 1:3).

**Pourquoi c'est valide (précision, pas changement d'issue)** : le gel reste **différé v1.5+** dans tous
les cas, mais **ancrer la décision sur les bonnes raisons** empêche une future lentille de le réintroduire
au prétexte du « hunt long ». **Décision (doc §7.x)** : remplacer « hunt médian > 3 rounds » par « gel
conditionnel à (a) mécanisme de report d'or inter-round OU (b) `REROLL_COST` scalant en T3-4 ; sinon différé
v1.5+ ». **Couplé à #DD-éco** (la décision gel dépend de la décision `REROLL_COST` §7.5).

### 4.4 ADOPTÉ (litige #BB, neuf) — Daily = ranked ou unranked ? (ranked §5.1)

**Critique** : la roadmap §6.6 **ne précise pas** si le Daily est ranked ou unranked. Si **ranked** → les
familles sur-représentées dans le pool ranked du jour biaisent la contrainte ; si **unranked** → la
contrainte est découplée du MMR et perd son rôle d'intégration méta.

**Décision (litige #BB, recommandation préliminaire)** : **Daily = UNRANKED avec leaderboard journalier
séparé** (score daily ≠ ranked MMR), modèle **StS Daily** (compétition journalière distincte du ladder).
Raison décisive : le gating par `win_rate ≥ 0,8×médiane` (§6.6) **exige que le daily fonctionne dès la S1**,
avant que le pool ranked soit assez grand pour mesurer les win-rate par famille → le daily ne peut pas
**attendre** l'équilibre ranked. **Les 2 modes partagent `state.lua`** → à trancher AVANT le code P2.

### 4.5 ADOPTÉ — IA ranked = builds Encounter PUISSANTS (ranked §5.2) + proposition de valeur ranked S1 (ranked §3.2)

**Critique (ranked §2.2)** : en S1 (< 50 joueurs beta), le pool ranked sera **quasi-vide** 2-3 semaines →
les runs ranked seront **majoritairement contre des IA**. La distinction ranked/unranked **perd son sens**
si les deux affrontent des IA. Le Bazaar (backend mondial, dizaines de milliers de joueurs) a **quand même**
souffert d'un ranked mal peuplé au lancement (steamcommunity 1617400).

**Pourquoi c'est valide (pas un drapeau pilier, une alerte de COMMUNICATION)** : l'async par snapshots
reste correct. Mais le ranked S1 doit être **présenté honnêtement** comme un mode de **progression personnelle
contre fantômes**, pas un PvP compétitif classique. **Décisions adoptées** :
- **(ranked §3.2, option a)** : assumer la DA — « LE PUITS S'ÉVEILLE — tes premiers rivaux sont les
  Invocations (Fantômes du Puits) ». La faiblesse (peu de joueurs) devient **caractéristique thématique**
  grimdark. Pas de tromperie, pas de déception. (Option b « ranked désactivé en S1 » **rejetée** : frustre
  les early adopters qui veulent le lancement compétitif.) → §6.5/§6.11.
- **(ranked §5.2)** : les IA ranked (`aiComp`) sont sélectionnées depuis les **Encounters les plus
  puissants** (pas `rand()`), pour que les runs ranked S1 n'affrontent pas des « builds aléatoires ». 0 code
  (les Encounters existent), décision de sélection. → §6.4bis.

### 4.6 ADOPTÉ — Score ranked persiste ENTRE saisons, rendu explicite (ranked §3.5/§1.6)

**Critique** : à 3 sem./saison, le joueur mid-core ne monte que d'un demi-tier/saison → le signal pré-run
montrera « PROCHAIN GRADE — 4 pts » pendant 2 saisons. Ce n'est pas un problème **si** le joueur comprend que
les points **s'accumulent** d'une saison à l'autre (reset −20 %, pas à 0). Mais cette persistance est
**implicite** dans la spec §6.3, jamais communiquée.

**Décision (adopté, doc §6.3)** : au démarrage de saison, le signal pré-run (§6.11) affiche **explicitement**
« PUITS S[N] : TU AS CONSERVÉ [X] PTS DE TA DESCENTE PRÉCÉDENTE — TA PROGRESSION TRAVERSE LES SAISONS. »
Prévient la déception du reset partiel + renforce la valeur long-terme de chaque saison. 0 mécanique.

### 4.7 ADOPTÉ (recommandé CLORE) — #Z cold-start spectre : IA formulation distincte (ranked §3.3 + retention Prop-D)

**Convergence de 2 lentilles** : le litige #Z (signal « spectre » §2.8 en cold-start, pool vide → N=0
silencieux) doit être tranché vers **IA avec formulation distincte** (« LE PUITS A SOUMIS TON BUILD AUX
ÉPREUVES DU VIDE — [N] INVOCATION[S] L'ONT ÉPROUVÉ »). Arguments convergents :
- **Onboarding = phase la plus critique** (Countly 2026 : 90 s post-relance) ; au lancement **tous** les
  joueurs sont en cold-start → le **silence supprime le moteur de session-initiation exactement quand il
  est le plus nécessaire**.
- **Honnêteté préservée** : les IA ne sont **pas présentées comme humaines**. La **trace d'impact reste
  réelle** (N combats réellement simulés contre le build).
- **Cohérence avec la proposition de valeur ranked S1** (§4.5 : ranked S1 = Invocations) → la formulation
  spectre pour les IA **s'aligne** sur le mode ranked.

**Décision (recommandé CLORE #Z)** : **IA formulation distincte, fallback silencieux si N=0 même pour les
IA.** Texte i18n + condition `if N>0 AND battles_are_ai THEN "INVOCATIONS" ELSE "ÂMES"`. **Décision DA
finale à l'user** (le mot « ÉPREUVES DU VIDE » casse-t-il le cryptique ou l'enrichit ?). Si l'user tranche
« casse » → silence accepté.

### 4.8 ADOPTÉ (spec Phase 2) — VRR boutique : demi-vie courte si la règle est devinable (retention §2.1)

**Critique (raffine #AA)** : Hopson 2001 (seuil 20-30 %) vaut pour le **VRR pur** (renforcement aléatoire
sans règle visible). Notre signal est **semi-prévisible** (règle `rang≥shopTier` OU `≥60 % dot_family`) →
un joueur qui comprend la règle (les compétitifs vite) **anticipe** le signal au lieu d'être surpris → il
**dégénère en info utile** après ~10 runs (PSU.com 2025 : « a variable ratio system keeps engagement
because you can't predict ; a fixed/visible-rule system, once understood, drops the excitement »).

**Pourquoi c'est valide (pas un retrait, une 2-phases)** : **Décision (spec Phase 2 documentée, §2.9, 0 code
avant P0)** :
- **Phase 1 (runs 1-10)** : règle actuelle. Surprenante pour un nouveau. **Acceptable.**
- **Phase 2 (runs 10+)** : ajouter un **3e facteur** moins modélisable — **distance à la 3e copie d'une
  unité du build** (`≥60 % dot_family` ET `shopTier` OU à 1 copie d'un triple). Plus rare, contextuellement
  fort, difficile à anticiper. **Implémentation Phase 2 = P3** ; l'**intention doit exister AVANT** pour ne
  pas graver Phase 1 comme définitive. **Enrichit #AA** : calibrer non seulement le **taux** (~30 %) mais la
  **prévisibilité** (Q_R7_1 : à quel run le joueur devine la règle → playtest).

### 4.9 ADOPTÉ (doc) — Enveloppe de fréquence VRR sur un run complet (retention §2.3/Prop-B)

**Critique** : la précondition de mesure du **chevauchement** des signaux VRR (§2.4) est au niveau du
**combat**, pas du **run entier**. Sur 10-15 rounds, on cumule ~17-28 signaux VRR (9-14 boutique + 3-4
Moment du Run + 2-3 surprise placement + 4-5 offres reliques + 1 trace d'impact). Kao et al. 2024 (CHI) :
« amplification unexpectedly reduced all motives [...] impeded sense of agency » → l'amplification
**excessive** réduit l'agence. Pas de cap global dans la roadmap.

**Pourquoi c'est valide (intention, pas chiffre gravé)** : **Décision (doc §2.9, 0 code)** : tableau
d'intention de fréquence VRR sur un run de 10 victoires (comme le tableau d'intention éco §7.0), **cible
≤20 signaux/run** (hypothèse de travail à valider en playtest). Si les sims dépassent → prioriser le VRR
**boutique** (circuit agence directe) sur les autres en cas de budget saturé. Aligné avec la logique
« définir l'intention avant de mesurer » déjà adoptée pour l'éco.

---

## 5. Rejets et nuances (avec raison mécaniste)

### 5.1 NUANCÉ (pas imposé) — `--pool-repr` AVANT `--poison-frac` (ordre strict)

La **mesure** `--pool-repr` est adoptée (§2.3, litige #DD), mais l'**ordre strict « avant `--poison-frac` »**
réclamé par 2 lentilles est **nuancé** : l'audit colonne B (§3.1, retrait des enablers POOL) fait déjà le
diagnostic qualitatif de sur-représentation ; `--pool-repr` en est la **validation quantitative**, pas un
préalable bloquant **indépendant**. **Position** : même lot P0.5, pas d'ordre imposé. Raison : sur-imposer
des dépendances séquentielles entre 3 mesures du même lot **fragmente** le travail sans gain prouvé (aucune
lentille n'a montré que l'ordre **change le résultat**). À rouvrir round 8 si preuve du contraire.

### 5.2 REJETÉ — Vue Grimoire-par-archétype comme item séparé (retention §2.4/Prop-D, partiellement absorbé)

La vue Grimoire II **par archétype de build** (vs par famille) est **partiellement absorbée** par le **nom
de build** (§1.6) : une fois les noms de build existants, la vue par archétype est triviale. **Mais elle ne
devient PAS un item de roadmap distinct** : le brouillon a déjà acté le bestiaire **segmenté par famille**
(round 6, goal-gradient ~7 étapes) ; ajouter une **2e segmentation** (par archétype) **avant** d'avoir validé
que la 1re fonctionne = sur-engineering. **Position** : la vue par archétype est une **note « à l'étude »**
(§11), conditionnée à (a) noms de build livrés ET (b) P1 (types) qui rend l'archétype non-ambigu (Q_R7_2/3).
Pas un livrable P2.

### 5.3 REJETÉ — Reconcevoir `bleedPierceShield` en burst PAR DÉFAUT (synergies §2.1, option de repli seulement)

La critique synergies §2.1 propose, **si** le drain net est absorbé, de **changer l'axe** vers un burst de
stacks (« à 5 stacks, vider 50 % du bouclier »). **Adopté comme REPLI conditionnel**, **pas par défaut** :
le drain progressif 1 pt/tick est l'**identité de design voulue** (bleed = « ronge lentement », cohérent
grimdark) ; le burst est un **pivot d'identité** qu'on ne fait que **si la sim (2b) prouve l'inertie**. Le
1er remède reste **2 pts/tick** (préserve l'identité « drain »). Raison : ne pas changer une identité de
design par anticipation d'un bug non encore mesuré (la sim 2b tranche).

### 5.4 RAPPEL — Litiges round 6 NON re-contestés (consensus confirmé)

Aucune lentille n'a rouvert **#D** (global pur), **#W** (burn-vuln intentionnel), **#T** (SOFT/HARD), **#O**
(famines_math option a). **Mieux** : 3 lentilles les **confirment** avec des sources **indépendantes** :
- **#D global pur** : synergies §1.1 ajoute **TFT Inkborn Fables** (« big vertical traits must have primary
  stars ») — angle **différent** de TFT Galaxies (dead-zone) : la **lisibilité de valeur** (count=4 sans
  exception de placement). Sur 9 slots à START_SLOTS=3, le global pur est le seul design **lisible**.
- **#W burn intentionnel** : synergies §1.2 ajoute **PoE1 vs PoE2 Ignite** — PoE1 Ignite ignorait la
  résistance feu et a dû être **tuné violemment** (plus de shield méta) ; notre approche (burn absorbé par
  bouclier = coût ; twist burn-4 = `burnIgnoreShield` keystone) est **mécanistement plus saine**. Bonus :
  le système burn>carries/tank>burn est un **counterplay VÉRIFIABLE DANS LES SNAPSHOTS** (défaite
  attribuable post-combat).
- **`afflictionCount` C2** : synergies §5 maintenu, non re-challengé.

---

## 6. Consensus établi (7e confirmation pour l'éco/ranked, plancher sain pour le contenu)

**Éco / progression (progression §1, 5 des accords = 7e confirmation)** : or fixe 10/round non reporté ;
XP TFT-style (passive 1/round + BUY_XP=4) ; courbe recourbée `{2,5,10,18}` (critère 4+1 conditions) ;
`REROLL_COST=1` tranché par sim P3 (analogie SAP corrigée 1:3≠1:1, verrouillée) ; co-calibration
shopTier/slots (4e condition) ; **tableau d'intention éco = PRÉCONDITION P3** (2e confirmation) ; pity
`max(3, 0.5×médiane)` + progression visuelle ; option C slot-decline.

**Ranked (ranked §1+§4, accords maintenus)** : grille `+4/+2/+1/0` sans pénalité (consolidé par Activision
2024 SBMM : la perte perçue injuste amplifie le churn des 90 % de tiers bas — notre FIFO local ne peut
garantir la qualité) ; `RANKED_MIN_POOL` SOFT=3/HARD=5 (SOFT = **norme S1**, pas exception) ; pré-run
sub-tier (goal-gradient borné) ; `slot_tier_composite` matchmaking **V1** (avec amélioration cohérence V2,
§7) ; fenêtre de grâce 7 j ; cosmétique daté ; Dernier Souffle (1 vie) ; saisons courtes 3-4 sem.
échelonnées par contenu ; Contrainte Permanente de Saison (mais à **élever en priorité visible P2**, pas
note de bas de page — ranked §1.7).

**Reliques (relics §1, accords forts)** : déprio F + garantie B-E ; arc ≥1 shaper-mid + ≥1 payoff-late
(rot sans payoff-late / choc sans shaper-mid prouvés) ; #O option a ; `sacred_shield` [PH] ;
`hollow_choir` pool-A.

**Synergies/effets (synergies §1+§5, plancher sain)** : compteur GLOBAL PUR ; burn-vuln intentionnel ;
12 synergies + 3 tests inter-famille ; `DOT_CAP_MULT=3` ; architecture `grant_team`/`teamFlags` ; seuils
2/4 sur 9 slots ; axe rot = amputation PV max.

**Rétention (retention §1, ancrages round 6 confirmés)** : VRR boutique (bon problème, bonne réponse —
confirmé Mobile Game Report 2026 « shop sequencing ») ; Ovsiankina + goal-gradient Grimoire (67 %
resumption, Nature 2025) ; cap dur 10 sessions surprise placement ; trace d'impact async (sous réserve
compteur non-nul en v1, #Z).

**Units (units §1, accords)** : règle P90/P10 ≤ 3× (2,11× mesuré, passe) ; retrait shield-renforts de
`U.pool` ; `burst_DPS_eq` condensateurs ; singletons rang-1.

---

## 7. Litiges ouverts (pour rounds 8-10)

| # | Litige | Statut R07 | À trancher |
|---|---|---|---|
| **#A** | P1 types vs P2 ranked | Maintenu ; mesure sur runs UNRANKED libres + méta saine (`--poison-frac`+`--no-weaken`) | P3 (après P0.5) |
| **#B** | Double-comptage inc% | Borné cap ×3 output ; twist-4 = `more` séparé ; tableau saturation (+ exception choc R07 + par-rang bleed R07) | Avant P1 |
| **#CC** | **NEUF** : `wither_bloom` post-C2 (afflictionCount=1) → rôle multi-affliction effondré | **Ouvert** : reconcevoir (dps non-nuls) vs accepter (rot+slow+weaken cosmétiques) | Avant P1.5b |
| **#DD** | **NEUF** : `--pool-repr` AVANT `--poison-frac` (ordre strict) | **Ouvert** : mesure ADOPTÉE, ordre strict NUANCÉ (même lot P0.5) | Round 8 si l'ordre change le résultat |
| **#U** | Saison : bas win-rate vs sous-représentée | Maintenu (données P0.5) | Avant spec §8.0 |
| **#V** | `sv` schema-version | Différé (dot_family déduit dynamiquement) ; re-lié #Y | Si #Y = vidage complet |
| **#Y** | FIFO ranked au reset (persistance filtrée vs vidage) | Maintenu ; §5.2-ranked R07 précise que la persistance filtrée (`wins_at_capture≥3`) est un AVANTAGE de qualité | P2 |
| **#Z** | Spectre cold-start (silence vs IA distincte) | **RECOMMANDÉ CLORE → IA formulation distincte** (2 lentilles convergent) ; décision DA finale user | Avant code §2.8 |
| **#AA** | Seuil VRR boutique | Maintenu ; **+ critère de prévisibilité de règle** (R07) ; cible ~30 % rerolls + Phase 2 | P0 sim / playtest |
| **#BB** | **NEUF** : Daily ranked ou unranked ? | **Ouvert** : recommandation = unranked + leaderboard journalier séparé (StS) | Avant code P2 |
| **#X** | Relique de contre-jeu méta | `hollow_choir`→`pierceShield` candidat (P1.5b après colonne I) ; vérifier ≠ doublon `bleedPierceShield` (R07) | P1.5b |

**Litiges CLOS ce round** : **#Q2-relics** (`forked_tongue` non silencieuse — `shockChain` consommé,
grep synthé). **Recommandé CLORE** : **#Z** (IA formulation distincte). **Neufs** : **#CC**, **#DD**, **#BB**.

---

## 8. Preuves nouvelles vérifiées ce round (par le synthétiseur)

| Claim | Vérification | Conséquence |
|---|---|---|
| `forked_tongue` (`shockChain=1`) est-il consommé ? | **OUI** — `ops.lua:187` lit `tf.shockChain` (nb rebonds), `:276` le pose via `grant_team` | **#Q2-relics CLOS** ; gating §4.7 justifié ; **apex choc `grant_team {shockChain}` = 0 moteur** (§1.2) |
| `shield_caster` régen + scaling | **`ward_weaver` (`units.lua:362-364`) = re-bouclier 20/240 ticks (4 s) aux voisins, SCALANT par niveau** | `bleedPierceShield` 1 pt/tick **absorbé par `ward_weaver` niveau-3** (60/4 s) → test 2b inter-famille **justifié** (§2.1) |
| `deep_kraken`/`skull_colossus` rang-5 stat-sticks | `units.lua:421-423` (skull dmg=11/cd=84, `on_hit burn`) + `:437-439` (kraken dmg=12/cd=78, `on_hit poison`) — **aucune règle d'équipe** | DPS 0,131/0,154 confirmés ; **deep_kraken dépasse marrow_drinker (+34 %)** → §1.1 BLOQUANT |
| `byakhee` r2 > `vein_splitter` r3 | `:402-403` (byakhee dmg=8/cd=50=0,160) vs `:195-196` (vein_splitter dmg=4/cd=44=0,091) | **Inversion cross-rank 1,76×** confirmée → §1.4 |
| Choc sans rang-5 dans `U.pool` | live_wire/stormcaller/stormlord/galvanizer relus (r1/r2/r3/r4) ; **aucun r5** | Famille choc tronquée → §1.2 (apex via skull_colossus réorienté) |

---

## 9. Impact sur le calendrier (deltas vs v7)

- **v0.9** : +**§2.4bis nom de build** (RENDER, après dot_family) ; +**§2.5bis barre XP boutique** (RENDER) ;
  +spec **Phase 2 VRR boutique** (doc) ; +**enveloppe fréquence VRR** (doc).
- **v0.9.3 (P1.5a)** : +**spec #O tri stable par `id`** (NON-NÉGOCIABLE) ; +**§4.11 hiérarchie build-
  definition** (E=amplificateurs) ; +`sacred_shield` cible 120 ; +garantie pertinence renforcée early (P3).
- **v0.9.5 (P0.5)** : **§3.7 promu BLOQUANT** (deep_kraken/skull_colossus rang-5) ; +**apex choc** (skull→
  choc `grant_team {shockChain}`) ; +**paires de niche** (col B) ; +**cross-rank `byakhee`** (col E) ;
  +**singleton bleed `gnaw_rat`** ; +**`--pool-repr`** (litige #DD) ; +**`offer_decision_quality`** (sim) ;
  +**exception choc + bleed-par-rang** tableau saturation ; +**condition placement rot col I** ;
  +(option) CONFIG-CE choc early ; +litige #CC (wither_bloom post-C2).
- **v0.10 (P1)** : **test 2 inter-famille → 2a/2b** (shield_caster actif) ; reste inchangé.
- **v0.11 (P2)** : +**Daily unranked + leaderboard journalier** (#BB) ; +**proposition de valeur ranked S1
  Invocations** ; +**IA ranked = Encounters puissants** ; +**score persiste inter-saisons explicite** ;
  +**#Z = IA formulation distincte** ; **Contrainte de Saison §8.0 élevée en priorité visible**.

**Aucun invariant touché ce round.** Toutes les adoptions sont data / doc / sim / RENDER / décision
éditoriale. Le seul changement de spec à signal fort est le **tri stable de `famines_math`** (préserve
l'invariant #2, donc le renforce).

---

*Round 07 synthétisé le 2026-06-23. Intégration critique des 6 lentilles `r07-*.md`. 2 claims de code
revérifiés (shockChain, shield_caster) → #Q2-relics clos + test 2b justifié. 8 adoptions de contenu/sim,
3 ré-ancrages, 3 litiges neufs (#CC, #DD, #BB), 1 recommandé clos (#Z). Lecture seule du repo, écriture
uniquement sous `docs/roadmap-lab/`. Piliers respectés, 32 invariants préservés. Améliore mesurablement v7
par la DÉTECTION DE TROUS DE CONTENU (apex choc manquant, rang-5 stat-sticks) et de BUGS LATENTS (tri
non-stable, bleedPierceShield absorbé, qualité d'offre non mesurée) que 6 rounds avaient manqués.*
