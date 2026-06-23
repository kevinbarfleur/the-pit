# Round 05 — Synthèse adversariale (6 lentilles)

> **Rôle** : synthétiseur, round 5/10 du roadmap-lab. Intègre **de façon critique** les 6 critiques
> `rounds/r05-*.md` contre le brouillon v5 (`ROADMAP-draft.md`). Adopte les critiques **valides et
> sourcées**, rejette les faibles (en disant pourquoi), consigne les **vrais litiges** pour le round 6.
> C'est un débat, pas une addition.
>
> **Méthode (round 4, maintenue)** : reformuler/corriger un mécanisme existant = **citer la ligne de
> code relue ce round**. Le synthétiseur a **revérifié 4 claims load-bearing** (ci-dessous) — pas hérité.
>
> **Ancrage** : `00-state.md` (32 invariants), `BRIEF.md`, `round-0{1,2,3,4}.md`, les 6 `r05-*.md`,
> les 10 teardowns `competitive/*`. **Garde-fou absolu** : lecture seule du repo ; n'édite que sous
> `docs/roadmap-lab/`. Piliers : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.

---

## 0. Vérifications de code menées par le synthétiseur (avant d'arbitrer)

Quatre critiques de ce round reposent sur des assertions de code fortes. **Le synthétiseur les a relues
ligne à ligne** (pas hérité) — toutes **CONFIRMÉES** :

1. **`afflictionCount` compte la PRÉSENCE, pas le dps** (`arena.lua:234-242`, relu) :
   ```lua
   local function afflictionCount(d)
     local n = 0
     if d.burn then n = n + 1 end ; if d.bleed then n = n + 1 end
     if d.rot then n = n + 1 end ; if d.shock then n = n + 1 end
     if #d.poison > 0 then n = n + 1 end
     return n
   end
   ```
   → **la critique units-power §2.3 est EXACTE** : `wither_bloom` (`units.lua:280-287`, relu) pose
   `rot` + `bleed{dps=0}` + `poison{dps=0}` → 3 familles présentes → `afflictionCount ≥ 2` → déclenche
   **`plague_communion` (+25 % de TOUS nos dégâts) à lui seul**, et une aura `miasma_acolyte` (+50 %
   poison dps) sur lui amplifie un dps de **0**. **Bug code-vérifié, non hérité.** → **ADOPTÉ** (§ ci-dessous).

2. **`barrier_savant`/`mirror_ward`/`surge_warden` SONT dans `U.pool`** (`units.lua:479` et `:507`, relu)
   et sont des ops `aura_shield` (`:366-376`) qui cherchent un `shield_caster` voisin — **seul `ward_weaver`
   l'est** (`:362-364`). → **la critique units-power §2.2 est EXACTE** : achetés sans `ward_weaver` voisin
   = **stat inerte, dead pick silencieux**. → **ADOPTÉ**.

3. **Struct snapshot = `{version, tier, seed, shape, units}`** (`snapshot.lua:24`, relu) — **pas de champ
   `mode` ni `sv`**. → les critiques ranked §1.3 (pool ranked/unranked non séparé = trou de spec) et §2.3
   (dette de schéma) **portent sur du code réel**. → **ADOPTÉ** (`mode`), **DIFFÉRÉ** (`sv`, cf. litige).

4. **`REROLL_COST=1`, `GOLD_PER_ROUND=10`, `STREAK_CAP=3`, `cost=rank`** (`state.lua:26-34`, relu) →
   la critique progression §2.1 (reroll = rang-1 = quasi-gratuit, jamais challengé en 4 rounds) **porte
   sur des constantes réelles**. → **ADOPTÉ comme décision à exposer + sim**.

**Conclusion de méthode** : ce round produit **3 corrections code-vérifiées de plus** (afflictionCount,
shield-renforts pool, snapshot mode). La règle « citer la ligne avant de proposer » continue de payer.

---

## 1. Ce qui CHANGE dans la roadmap (adopté, avec le POURQUOI)

### 1.1 [P0.5, HAUTE] `afflictionCount` ne doit compter que les afflictions à dps réel — corrige `plague_communion` (Option C2)

**Adopté de** units-power §2.3/P-C. **Pourquoi** : code-vérifié (§0.1). C'est une **précondition du tuning
`plague_communion`** (§4.2 roadmap) : régler la magnitude d'une relique qui se déclenche **faussement** sur
un seul `wither_bloom` = tuner sur une base cassée. **Remède (1 ligne)** : `afflictionCount` ne compte une
famille que si elle a un dps/stacks réel (`bleed.dps>0`, `poison[i].dps>0`, etc.), pas la simple présence.
**Garde-fou code-vérifié** : `dischargeShock` lit `target.dots.shock.stacks` (pas `afflictionCount`) → C2
n'affecte pas l'invariant #22 ; **rebaseline golden seulement si `wither_bloom`-seul y figure** (à vérifier
avant). **Mieux qu'Option C1** (`apply_status` dédié) à court terme : C1 reste la cible propre, mais C2
ferme le faux signal **maintenant**, sans nouveau moteur. → **C2 en P0.5, C1 en P1.5b** quand les types
auront besoin de conditions orthogonales (slow/weaken sans dps).

### 1.2 [P0.5, HAUTE] `--no-weaken` : mesurer la SECONDE cause de poison>choc (pas seulement la propagation)

**Adopté de** synergies §2.1/P1. **Pourquoi** : la roadmap v5 traite `--poison-frac` comme **LA** cause de
poison>choc. Mais poison a **3 axes** (stacks multi-sources / weaken / propagation-à-la-mort) et le choc **1**
(condenser→décharger). `--poison-frac` ne borne que la propagation. **Le `weaken` (malus sur l'output ennemi,
`ops.lua:71` + `chitin_drone`/`corruptor`, relu) est un axe défensif que `win_rate(dégâts bruts)` ne capte
pas.** Précédent sourcé : PoE **Wither** (debuff cumulatif d'affaiblissement) dominait le late-game « only
measurable by isolating the debuff contribution », plafonné à 15 charges (pathofexile.com/forum/view-thread/
3870562). **Remède** : ajouter `--no-weaken` (~5 lignes, désactive l'op weaken) aux configs de sim P0.5 ;
mesurer `win_rate(poison)` avec/sans weaken, N=200 seeds aléatoires. **Seuil d'alarme : delta > 0.3σ →
weaken est une 2e cause à corriger AVANT P1** (sinon le palier poison-4 amplifie un axe déjà dominant non
détecté). Golden inchangé (flag de sim). → **ajouté à §3.5 / §7.1**.

### 1.3 [P0.5, HAUTE] Litige #S TRANCHÉ : l'ampli choc-D cible la `dot_family` du poseur, fallback ordre fixe

**Adopté de** synergies §2.2/P2 (la critique relics §2.4 le **corrobore** depuis l'angle `forked_tongue`).
**Pourquoi** : la roadmap v5 laissait #S « à trancher en P0.5 » entre (a) **ordre fixe** (burn>bleed>poison>rot)
et (b) **`dot_family` du poseur**. **L'ordre fixe pur est une mauvaise réponse de design** : il amplifie
**burn en premier par défaut** = la famille qui (i) **absorbe les boucliers** (burn non-ignoreShield,
`arena.lua:432` relu round 4) et (ii) **n'est pas celle autour de laquelle le joueur a construit**. Un build
4-choc+4-poison verrait son choc amplifier le **bleed adverse**, pas son poison = **l'opposé de la promesse**
(« charge la cible, TON DoT explose »). **Décision** : `family = source.dot_family` ; si présent sur la cible
→ amplifier cette famille ; sinon **fallback** = 1er disponible dans l'ordre fixe (préserve les stat-sticks
choc sans affiliation). **Coût** : 1 lookup d'un champ statique posé au build, **0 invariant, 0 RNG,
déterministe**. **Le statut « litige » est retiré** ; #S devient une **décision de design tranchée** avec
réponse correcte selon la promesse. Le **signal UI** (§3.4, déjà obligatoire) devient alors *attendu* et non
surprenant. → **#S clos ; §3.4 met à jour la spec de l'axe D**.

> **Pourquoi le synthétiseur tranche ici et n'attend pas** : les 6 rounds ont **convergé** sur l'axe D + le
> signal UI ; le seul point ouvert était la cible de l'ampli, et la critique en donne une réponse mécaniste
> sourcée (la promesse de design) que **rien ne contredit**. Laisser flotter un litige résolu dilue le débat.

### 1.4 [P2, HAUTE] Pool ranked SÉPARÉ du pool unranked (`mode` dans le snapshot) + `RANKED_MIN_POOL`

**Adopté de** ranked §1.3 + §2.1/P1. **Pourquoi** : **fait Bazaar vérifié** (bazaar-builds.net/did-you-know-
how-ghosts-work) : « ghosts from ranked games only appear in ranked matches… separation ensures competitive
integrity. » Notre struct est **un seul FIFO 200** (§0.3) → un débutant peut **polluer le cold-start ranked**
d'un joueur établi (et inversement, gagner +4 en battant des builds tier-1 faute de pairs dans le pool). C'est
**la vraie faille d'intégrité async** que `slot_tier_composite` (proxy de *matching*) ne résout pas : le
composite filtre **qui** servir, pas **si le pool contient des pairs de tier**. **Remède** :
(a) champ `mode = "ranked"|"unranked"` dans le snapshot (rétro-compatible : `nil → "unranked"`), 2 FIFO ;
(b) **`RANKED_MIN_POOL` [PH=5]** : si `countRankedByTier(tier) < seuil` → ranked « indisponible, joue N runs
unranked pour alimenter le pool » (**condition de fairness, pas pénalité** — grimdark « Le Puits exige des
témoins avant de juger »), avec fallback IA explicite **non compté en points**. → **nouveau §6.4bis + test
« `serve('ranked')` ≠ snapshot unranked » et « ≠ tier < demandé−1 »**. **Litige #T** (seuil 3 vs 5) ouvert.

### 1.5 [P0, HAUTE] Signal d'APPARTENANCE async « ton spectre a été affronté » — comble la session initiation

**Adopté de** retention §2.1/Prop-A. **Pourquoi** : **lacune structurelle de v5** — toute la couche rétention
est **intra-session** (Moment du Run, Surprise de Placement, post-combat) ou **pré-run mais ranked-only**
(§6.11). **Personne ne traite la décision d'OUVRIR le jeu** après 3 jours d'absence. SDT (Möller, Kornfield &
Lu 2024, selfdeterminationtheory.org) : 3 besoins — autonomie (✓ async), compétence (✓ Grimoire/ranked),
**appartenance (✗ structurellement absente)**, « relatedness frequently ignored despite its importance ».
**Remède local-first, 0 backend** : au lancement (menu), lire `snapstore.lua` le nb de combats résolus contre
**le ghost local du joueur** depuis la dernière session ; si ≥1 → « LE PUITS A UTILISÉ TON SPECTRE — [N]
ÂME(S) L'ONT AFFRONTÉ DEPUIS TA DERNIÈRE DESCENTE » (Fogg : prompt externe au bon moment ; SAP : le snapshot
= adversaire perçu quasi-humain). **RENDER + IO hors SIM, ~2 h, 0 invariant.** **Limite (Q ouverte) :
cold-start (pool vide) → N=0 silencieux** ; ne pas tricher avec les IA. → **nouveau §2.8**.

### 1.6 [P0, MOYENNE] Valider les distributions temporelles VRR AVANT de coder les 2 signaux (anti-cannibalisation)

**Adopté de** retention §2.2/Prop-B (corrobore une zone que synergies/units ne touchent pas). **Pourquoi** :
la « complémentarité temporelle » des 3 sources VRR (placement=early, cascades=mid-late, reliques=offre) est
une **hypothèse non mesurée**. Sous-hypothèses fragiles : un plateau de 3-4 unités a **peu d'arêtes
activables** → la surprise de placement peut être plus fréquente en **mid** (5-7 slots, anneau) qu'en early ;
et un build focalisé peut produire des chaînes longues dès le round 2. **Si les deux se déclenchent au même
combat (round 4-6), ils se cannibalisent** (Kao et al. 2024 CHI : l'amplification excessive *réduit* le
sentiment d'agence). **Remède (~0.5 h sim)** : mesurer `chain_len` et `edge_missed` **par round** + le
chevauchement `P(chain≥P75 ET edge_missed≥1 | round_i)`. **Si chevauchement > 0.30 → règle de priorité
Moment du Run > Surprise de Placement** (la surprise passe en silencieux ce combat). → **ajouté à §2.4/§2.7
comme précondition de codage**.

### 1.7 [P0, MOYENNE] Lier le signal streak-loss au post-combat « pourquoi » (actionnable, pas qu'un chiffre d'or)

**Adopté de** progression §2.2/§3.2. **Pourquoi** : **asymétrie psychologique sourcée** (Smashing Magazine
2026 ; Kahneman-Tversky : la perte pèse ~2,3×) — un joueur en loss-streak reçoit +3 or **trop tard dans le
cycle de correction** : son build est mal orienté, pas sous-financé. L'or seul **renforce** parfois un build
inadapté. **Remède (coût ~0, lecture `state.streaks` + bus, déjà planifiés)** : au post-combat (§2.3), si
loss-streak ≥2, ajouter une ligne grimdark **pointant une décision** (slot le plus exposé + le moins d'arêtes)
au lieu d'un simple chiffre. → **ajouté à §2.3**.

### 1.8 [P2, MOYENNE] Daily : gater les contraintes-famille par équilibre (`win_rate ≥ 0.8 × médiane`)

**Adopté de** ranked §2.2/P2. **Pourquoi** : la seedification garantit la **reproductibilité**, pas l'**équité
de difficulté inter-contraintes** (dev Spell Cascade, dev.to/yurukusa 2026 : « the seed is authentication,
but the experience must feel fair »). « Jour de Brûlure » vs « Jour de Poison » ne sont **pas d'égale
difficulté** tant que burn<poison structurellement (hiérarchie diagnostiquée). Sur 10 jours, la progression
d'un joueur dépend de **quelles contraintes tombent ses jours de jeu**, pas de son skill. **Remède** : une
famille n'est imposée comme contrainte daily que si `win_rate(famille) ≥ 0.8 × médiane` dans `report.json` ;
sinon le tuple `{famille, sigil, éco}` retombe sur **sigil/éco seuls**. **Dépend de P0.5** (`dot_family` dans
la sim) ; jusque-là, daily = axes sigil+éco. **Discipline de déploiement, 0 code moteur.** → **ajouté à §6.6**.

### 1.9 [P2, MOYENNE] Signal pré-run = distance au prochain GRADE sub-tier (primaire), tier (secondaire)

**Adopté de** ranked §1.5/P4. **Pourquoi** : **goal-gradient borné** (Nunes & Drèze 2006, « Endowed Progress
Effect » : l'effet s'efface quand la cible perçue dépasse **~7 étapes**). « Il vous manque 23 pts pour le
prochain tier » = **8-17 runs** à `+4/+2/+1/0` = **hors horizon** pour 2-3 runs/sem. La **marque sub-tier**
(Survivant/Forgé/Ascendant) est l'horizon **closable** (1-3 runs). **Remède** : §6.11 affiche **« PROCHAIN
GRADE : Forgé — 4 pts »** en primaire + « Tier 2 — Condemned (12/35) » en secondaire. RENDER, ~3 lignes. →
**affine §6.11**.

### 1.10 [P1.5a, doc] Critère reliques/archétype affiné : ≥1 SHAPER-MID (tier≤3) ET ≥1 PAYOFF-LATE (tier-4)

**Adopté de** relics §2.2/Prop-B + §2.1/Prop-A. **Pourquoi** : le critère v5 « ≥2 reliques, P<25 % » compte
le **pool total** mais le gating crée des **arcs temporels**. Tableau code-ancré (relics §2.2) :
**rot = pas de payoff-late** (`grave_cap` T2 seul) ; **choc = pas de shaper-mid** (`forked_tongue` T4 seul) ;
**wide = rien**. Un build qui n'a **pas d'arc late** « plafonne en mid » (le joueur voit des ghosts T3-T4 avec
un payoff late, lui non). **Remède** : reformuler §4.8 → « ≥1 relique tier≤3 ET ≥1 relique tier-4 par
archétype engagé ; P<25 % calculé **sur le pool tier≤3 séparément** ». **Conséquence directe** : confirme que
`shock_conduit` (shaper-mid choc) + `swarm_logic` (wide) + **1 relique rot tier-4** sont nécessaires en P1.5b.
La **colonne rôle temporel (§4.7) doit être ACTIONNABLE**, pas seulement doc (relics §2.1) : signaler le
mismatch **ET** prescrire (recatégoriser la fenêtre d'offre OU déclarer le mismatch accepté + documenter).
→ **§4.7 + §4.8 mis à jour** ; **`forked_tongue` reçoit un gating conditionnel** (offrable dès 3 wins si ≥1
unité choc au build) — sous réserve que le filtre seedé reste déterministe (invariant #3).

### 1.11 [P1, doc] Spécifier le twist bleed-4 AVANT P1 (candidat : `bleedPierceShield`)

**Adopté de** synergies §2.4/P4. **Pourquoi** : v5 spécifie burn-4/rot-4/poison-4 mais **oublie bleed-4** → le
dev l'inventerait pendant le code **sans croiser la colonne F** (risque de vider un T2). **Candidat orthogonal
sourcé** : **bleed-4 = « Décomposition » — chaque tick bleed retire 1 point de bouclier** (`grant_team
{bleedPierceShield}`). Ne vide aucun T2 bleed (`razor_fiend`=burst, `blood_echo`=cadence, `leech_thorn`=épines
— tous relus round 5). Crée un **counter-bouclier lent et prévisible** (1 pt/tick, pas instantané → n'invalide
pas les tanks). À valider en Config D de la sim. → **ajouté à §5.2 comme candidat**.

### 1.12 [P0.5, doc] Étendre la grille d'audit : colonne (H) « dépendance de pool » + colonne (I) « contre quoi optimal »

**Adopté de** units-power §2.2/§2.4/P-B/P-D + synergies §2.5/P5. **Pourquoi** : la grille 7-col (A-G) ne
couvre ni la **dépendance de pool** (adjuvants `shield_caster` = dead picks, §0.2) ni les **cibles optimales**
(profondeur de counter invisible). **(H) dépendance de pool** : signale les adjuvants-dépendants
(`barrier_savant`/`mirror_ward`/`surge_warden` inertes sans `ward_weaver`) → **décision pool-A : les retirer
de `U.pool`, garder en `U.order`** (avec la cohorte v7) ; intègre aussi le « contre-bouclier » par famille
(burn=absorbé / bleed-poison-rot=ignoreShield / choc-D=partiel) → **décision : burn-vuln-bouclier voulu
(payoff burn-4 = `burnIgnoreShield`) ou accident ?**. **(I) contre quoi optimal** : burn→front faible-HP /
bleed→carries haute-cadence / poison→haute-valeur-stat / **rot→tanks/taunt (amputation PV max contourne le
HP brut — code-vérifié `chooseTarget` aggro câblée)** / choc-D→cibles déjà dotées. Pilote l'i18n grimdark +
l'audit reliques (révèle **rot = counter taunt orphelin de relique**). → **§3.1 passe à 9 colonnes (A-I)**.

### 1.13 [P3, décision à exposer] `REROLL_COST=1` : trancher explicitement (décision jamais challengée en 4 rounds)

**Adopté de** progression §2.1/§3.1 (désaccord MAJEUR de ce round). **Pourquoi** : code-vérifié (§0.4) —
`REROLL_COST=1` **=** `cost=rank` au rang-1 → **le reroll ne coûte rien vs un achat rang-1** en early, et
~quasi-rien en late (rang-4/5 à 4-5 or) → **la tension « reroll vs acheter » n'existe que rounds 4-6**.
Comparatif sourcé : **TFT reroll=2 or = 40 % du revenu passif** (« players agonize », boosteria.org) ;
**HS:BG reroll scalant** par tier. **C'est une décision implicite copiée de SAP, jamais interrogée.** **Remède**
— **deux options à trancher en sim, AVANT de figer la courbe XP** (le reroll affecte le budget réel donc la
courbe) : **(a) garder=1** → la tension vient **entièrement de la qualité des 5 offres** (alors garantie de
pertinence + pity deviennent **doublement critiques**) ; **(b) scaler** `REROLL_COST = max(1, shopTier−1)`
(T1-2→1, T3-4→2, T5→3, cohérent HS:BG). **Sim** `--reroll-cost-scaling` : mesurer rerolls/round et
conversion-vue→achat par tier ; si T3-4 chute >40 % → trop fort → garder (a). → **nouveau §7.5 + tableau des
constantes économiques à documenter** (§3.4 progression : exposer l'intention de chaque ratio avant de tuner).

### 1.14 [P3, doc] La sim de la courbe XP doit modéliser les STREAKS dans le budget réel

**Adopté de** progression §2.4/§3.3. **Pourquoi** : le critère 3-tranches (#R) calcule sur **10 or/round fixe**,
mais un win-streak parfait ajoute ~+24 or (budget ~124) et un loss-streak ~+12 (budget ~192 sur run long) →
le seuil « rush T5 ≥20 %/≥10 % » bascule de 5 points selon la base. **Remède (1 clause de sim, 0 code)** :
mesurer le budget **réel** = `10×rounds + Σ streak_bonus` (win-streak P50 + loss-streak P50 sur N=200) ;
documenter `std_dev(budget) < 30 %`. → **ajouté à §7.1 (#R)**.

### 1.15 [P2, doc] Critère de la Contrainte Permanente de Saison : famille SOUS-REPRÉSENTÉE, pas dominante

**Adopté de** ranked §1.4 (avec litige #U ouvert). **Pourquoi** : §8.0 v5 donnait un exemple (« +1 aggro aux
sans-`dot_family` ») qui **favorise les stat-sticks déjà nombreux** → ne crée pas de neuf-à-apprendre, en
favorise un existant. **Critère** : chaque saison cible l'archétype au **plus bas `win_rate_présence`** de la
saison précédente (renouveau = apprendre du neuf). **Litige #U** : « plus bas win-rate » (frustrant si c'est
choc, le plus dur) vs « plus sous-représenté en pool boutique » (ce que les joueurs jouent peu) — **2 critères
différents, à trancher avant la spec §8.0**. → **§8.0 mis à jour + #U ouvert**.

### 1.16 [P2/P4, doc] Le Chapitre III du Grimoire doit EXISTER en silhouette dès P2 (Zeigarnik)

**Adopté de** retention §1.1. **Pourquoi** : Zeigarnik ne fonctionne que sur un horizon **visible mais fermé**.
Un horizon **absent** (P4 non codé = Chapitre III invisible) **ne fait rien**. **Remède** : §6.7 précise que
le Chapitre III (Abysses) existe en **silhouette + titre + « ??? synergies »** dès P2, même si son contenu
arrive en P4. → **clarifie §6.7**.

---

## 2. Consensus (5e-6e confirmations — verrouillés, ne plus rouvrir sans preuve neuve)

- **Grille `+4/+2/+1/0` sans pénalité** : **6e confirmation** (ranked §1.1). Bazaar **pré-Legend** = gains
  seulement ; la pénalité Bazaar 6.0.0 n'existe que **parce qu'ils ont un backend + pool mondial** — notre
  FIFO 200 local punirait le joueur pour la pauvreté du pool. **Pénalité = backend P4 seulement.**
- **`plague_communion` gardée telle quelle** (payoff multi-affliction sur la CIBLE) : **accord très fort**
  (relics §1.1) — mécaniquement supérieure au design scalante du round 3, robuste async (évaluée à chaque
  `damage()`, pas à `combat_start`). **Seul reste le tuning de magnitude** (après la correction §1.1).
- **Or fixe 10/round** : **5e confirmation** (progression §1.1). Bazaar a **migré vers un income linéaire**
  (patch 7.0.0) après plaintes d'onboarding → **confirmation de marché** que la simplicité d'income est
  correcte en async.
- **`burst_DPS_eq` pour le choc** (condensateur, anti-nerf-aveugle de `galvanizer`) : accord (units §1.1) —
  étendu : appliquer le critère à **tout le ladder** (pas que `galvanizer`) ; `stormlord` (DPS=0.111, dans la
  norme rang-3) ne doit pas être **sous-évalué** par `burst_DPS_eq` si son burst est faible.
- **Seuils 2/4 sur 9 slots** : accord fort (synergies §1.4) — justification **endogène** (palier-6 = 67 % de
  la compo = pas de tank = front détruit), plus forte que l'analogie TFT.
- **`grant_team`/`teamFlags` pour les paliers** : accord technique (synergies §1.5) — 0 nouvelle mécanique.
- **Signal UI obligatoire de la famille amplifiée (choc-D)** : accord fort (synergies §1.2) — condition
  nécessaire pour que l'axe D soit une décision, pas un artefact opaque (Wagar : attribuer le résultat au
  choix).
- **`--poison-frac` + `--position-variance` promus en P0.5** : accords (synergies §1.1/§1.3 ; progression).
- **Pity = signal sans garantie, `max(3, 0.5×médiane)` + progression visuelle, cappé ×1.5** : accord
  (progression §1.4 ; retention §2.3 le **nuance** : c'est un *soft pity* — moins compulsif mais moins
  motivant ; trade-off à nommer, pas un défaut ; la spec reste **bloquée par la sim hunt-médian**).
- **Déprio reliques F avant le marchand ; `second_breath` universelle tier-3 ; `famines_math` option (a)
  reformulée** : accords maintenus (relics §1.4/§1.5/§1.6 ; progression §1.6).
- **Moteur pré-run §6.11 ; 10+ contraintes daily compositionnelles + tooltip pédagogique** : accords
  (corroborés multi-lentilles), avec les affinements §1.8/§1.9.
- **Rejet du score intra-run** : **réaffirmé** (ranked §4.1) — StS Ascension a **abandonné le classement par
  score** (pousse à optimiser le score, pas le build) ; Dota Underlords « ranking mixte skill/speed » a
  fragmenté la valeur (postmortems §3.2A). **La grille plate est une qualité, pas un défaut.**

---

## 3. Critiques REJETÉES ou DÉPRIORISÉES (avec le pourquoi)

### 3.1 REJET — `snapshot_schema_version` (`sv`) MAINTENANT (ranked §2.3/P3) → différé, pas adopté en P0.5

**Position** : la dette de schéma est **réelle** (struct sans versioning, §0.3), mais l'urgence est
**surestimée**. **Pourquoi différer** : (1) `toComp` **ignore déjà les ids inconnus** (`snapshot.lua:53`,
relu) → un snapshot pré-`dot_family` ne **crashe pas** ; (2) `dot_family` est **déduit dynamiquement de
`Units.dotFamily(id)`** (champ de stat, pas stocké dans le snapshot v1) → un snapshot ancien lu **après** P0.5
récupère la famille **du `units.lua` courant**, ce qui est **correct tant que l'id existe** ; (3) le seul cas
cassant (un id devenu roster-only entre P0.5 et P2) est **rare et déjà géré par le silencing**. **Ajouter `sv`
en P0.5 = complexité spéculative avant le besoin** (l'invariant moteur « 1er modificateur en % → buckets » de
`engine-architecture.md §12` suit la même discipline « au 1er besoin réel »). → **`sv` devient prioritaire au
1er champ snapshot réellement persisté (reliques en v2)** ; jusque-là, **une purge de pool unique au passage
P0.5 suffit** (acceptable une fois ; le pool ranked d'un joueur établi n'existe pas encore avant P2). **Noté
en idées à l'étude + litige #V.**

### 3.2 DÉPRIORISÉ — relique de « contre-jeu méta » (relics §2.6/Prop-E)

**Position** : idée **intéressante et grimdark-cohérente** (« ceux qui ont survécu au Puits savent quels
poisons y circulent »), mais **P3 au plus tôt**, pas un manque urgent. **Pourquoi déprio** : (1) elle dépend
d'un champ `previousCombatAfflictions` dans `RunState` (touche la SIM, même 2 lignes) → coût > 0 contrairement
aux propositions RENDER ; (2) le **post-combat « pourquoi » (§2.3) + le signal de pool pré-run (§6.5)** donnent
**déjà** l'info méta du tier sans nouveau mécanisme ; (3) la **Q4 de la lentille elle-même** pose une vraie
question de DA non tranchée (le Puits « impénétrable » subi vs « appris ») → **à trancher avant de spécifier**.
→ **idées à l'étude ; conditionné à la résolution de la Q DA + après équilibrage** (une relique de counter sur
une méta non équilibrée = bruit).

### 3.3 DÉPRIORISÉ — friction inter-familles bleed/rot « by-design » (units §2.1, options F1/F2)

**Position** : le **constat est juste** (bleed/rot = co-build naturel sans friction, là où PoE/LE séparent par
type de dommage phys/chaos), mais **F1 (friction moteur : les ops s'excluent) est rejetée** (change le moteur,
risqué, casse la composabilité data qui est un pilier d'archi) et **F2 (redessiner les niches) est
prématurée**. **Pourquoi** : la « friction » PoE/LE vient de **systèmes de résistance** que The Pit **n'a pas
et ne veut pas** (petits nombres, pas de %res). Le co-build bleed+rot **n'est un problème que si la sim montre
qu'il domine** — non démontré. **Remède retenu = F3 (le moins cher)** : **documenter** bleed+rot comme co-build
légitime **sans palier propre** (son identité = tempo + tank-buster), via la **colonne (I)** (§1.12) qui rend
les niches orthogonales **explicites** (bleed→cadence, rot→HP). → **F3 dans la colonne (I)** ; F1/F2 **rejetées
sauf si la sim P3 révèle une domination du co-build**. La question « relique dédiée bleed+rot ? » reste ouverte
(relève du critère ≥2/archétype, §1.10).

### 3.4 REJET PARTIEL — compteur HYBRIDE 2-global / 4-global+adjacence comme DÉCISION tranchée (synergies §2.3/P3)

**Position** : le design hybride est **séduisant et bien argumenté** (le palier-2 global lisible + le twist-4
conditionné à une arête de sigil = « la forme EST le graphe »), mais **le trancher MAINTENANT contredit la
décision méthodologique du round 4** : `--position-variance` (P0.5) **mesure d'abord** si l'adjacence-type
apporte de la variance. **Pourquoi ne pas l'adopter sec** : (1) l'hybride **ajoute 2 invariants de test** (count≥4
+ paire adjacente vs count≥4 sans paire) → coût de test réel **avant** d'avoir mesuré le besoin ; (2) la
critique units-power §2.1 **et** la Q3 synergies (« le sigil croix active difficilement le twist adjacence →
hostile aux types ? ») montrent que **toutes les formes ne supportent pas également la condition d'adjacence**
→ risque de graver « 1 sigil = anti-type » par accident. → **Retenu comme l'OPTION PRIVILÉGIÉE du litige #D
SI `--position-variance > 0.05`** (au lieu de « adjacence-type pleine »), mais **la mesure tranche** : si
`< 0.02`, **global pur** (l'hybride est over-engineering). **#D reste ouvert, enrichi du 3e design.** La
décision « palier-2 toujours global, twist-4 = lieu de l'adjacence si la variance le justifie » est **la bonne
forme** de la question — mais pas une décision avant la mesure.

### 3.5 REJET — moteur pré-run §6.11 « directif » qui dicte la décision éco du run (progression §2.3)

**Position** : **rejeté comme amélioration v1** (la lentille elle-même le qualifie de « non bloquant, retour
user »). **Pourquoi** : le moteur pré-run **informe** (goal-gradient) ; le rendre **directif** (« vise telle
éco ce run ») = **réintroduit le DPS-estimé pré-combat** déjà démonté (§10 : LocalThunk cache le score exprès).
La grille + la distance suffisent. → **idées à l'étude (v2)**.

### 3.6 REJET — guidance d'agence précoce « prospective » au round 1-2 (retention §2.4/Prop-C)

**Position** : **le diagnostic est valide** (le profil joueur-passif 0-3 runs ne profite pas de l'attribution
post-hoc de Déclos), mais **la solution proposée (« [SIGIL] RESSENT SA FORME » au placement sur case à ≥3
arêtes) est rejetée telle quelle**. **Pourquoi** : (1) elle frôle le **tutoriel** que la DA grimdark refuse
(« cryptique, pas pédagogique » — la lentille le reconnaît mais le contourne mal) ; (2) elle **chevauche** le
**surlignage d'arêtes en build (§2.1, P0 priorité 1)** qui montre **déjà** « qui buffe qui » au survol/drag —
un joueur qui place sur une case dense **voit les arêtes s'allumer**. → **le besoin (rendre le placement
lisible tôt) est DÉJÀ couvert par §2.1** ; pas de nouveau signal. La détection du profil passif (Q_R5_3 :
`reroll_count/round` + `placement_variance`) est **notée en idées à l'étude** (utile pour calibrer **quels**
signaux activer, pas pour en ajouter un). → **rejeté en doublon de §2.1.**

### 3.7 NON RETENU — `swarm_logic` adjacence vs quantité tranché en P1.5b (relics §2.5)

**Position** : la critique **maintient** que la distinction quantité/adjacence doit être tranchée en P1.5b, pas
P4. **Pourquoi je maintiens la position v5 (différer la version « par arête » en relique G)** : la version
**adjacence** (« +X %/arête active ») **récompense la topologie** = c'est **exactement** le rôle des reliques G
(P4, « la forme EST le graphe »). Mettre une relique d'arête en P1.5b **empièterait** sur les reliques G et
créerait une redondance avec les **auras d'adjacence déjà bakées au build**. La version **quantité** (« +X %/
unité ») en P1.5b est **distincte** (récompense le wide, pas la forme). → **position v5 maintenue**, mais
**documenter explicitement** (la critique a raison sur ce point) que `swarm_logic`-quantité est
**intentionnellement non-topologique, complémentaire** des auras d'adjacence. **#M reste ouvert.**

---

## 4. Litiges ouverts pour le round 6 (vrais désaccords, pas tranchés)

| # | Litige | Positions | Trancher en |
|---|---|---|---|
| **#A** | P1 (types) vs P2 (ranked) en premier | `--meta-convergence < 8 runs` pour ≥2 sigils **sur méta saine** (après `--poison-frac` ET `--no-weaken`) → types | P3 (mesure) |
| **#D** | Compteur type : global / adjacence / **hybride 2-global+4-adjacence** | `--position-variance < 0.02` → global ; `> 0.05` → **hybride** (pas adjacence pleine) ; la mesure tranche, pas le débat | P0.5 (mesure) → P1 |
| **#M** | `swarm_logic` quantité (P1.5b) vs adjacence-par-arête (relique G P4) | Position v5 maintenue (quantité ≠ topologie) ; documenter la complémentarité | P1.5b / P4 |
| **#O** | `famines_math` : (a) reformuler non-anti-growth / (b) retirer | (a) préférée (préserve le tall) ; **deadline P1.5a** (sa sémantique C affecte la réaction à une offre C) | P1.5a |
| **#S** | **CLOS round 5** : ampli choc-D = `dot_family` du poseur + fallback ordre fixe | tranché (§1.3) | — |
| **#T** | `RANKED_MIN_POOL` = 3 (bêta fermée) vs 5 (early access) | dépend de la taille de la bêta | au launch |
| **#U** | Contrainte de Saison : cible famille **plus bas win-rate** vs **plus sous-représentée en pool** | 2 critères différents ; « plus bas win-rate » peut frustrer (choc) | avant spec §8.0 |
| **#V** | **NOUVEAU** : `snapshot_schema_version` (`sv`) maintenant (ranked) vs au 1er champ persisté (synthé) | synthé : différer (silencing + déduction dynamique suffisent ; purge unique acceptable) | au 1er champ snapshot persisté (reliques v2) |
| **#W** | **NOUVEAU** : burn-vuln-bouclier = **contre voulu** (payoff burn-4 = `burnIgnoreShield`) vs **accident** à corriger | colonne (H) le documente ; à trancher à la spec burn-4 | P0.5 doc → P1 |
| **#X** | **NOUVEAU** : relique de « contre-jeu méta » compatible DA ? (le Puits subi vs appris) | Grimoire + post-combat impliquent « appris » → cohérent ; mais à acter | avant Prop-E (P3) |
| **#B** | Twist palier-4 = `more` hors-cap → borner séparément | confirmé code (cap borne l'output, pas inc/more) | avant P1 |
| **#E/#L** | Hunt 3e copie → pity ; **spec bloquée par la sim hunt-médian** (retention §2.3 l'élève en gate dur) | accord ; mesurer avant de figer | P3 |
| **#F** | 6e type non-DoT | « aucun » confirmé (shield/tank = enablers ; dispersion DPS = audit budget §3.1b) | clos sauf preuve |
| **#R** | Courbe XP robuste variance **+ STREAKS dans le budget réel** (§1.14) **+ recalibrer après décision REROLL_COST (§1.13)** | critère 3-tranches + clause streak + dépend de #reroll | P3 |

**Litiges clos ce round** : **#S** (ciblage choc-D, §1.3). **#J** reste requalifié (round 4, plague_communion
gardée — le tuning suit la correction §1.1).

---

## 5. Preuves nouvelles apportées ce round (sources)

- **Bazaar pools ranked/unranked séparés** (intégrité async) : bazaar-builds.net/did-you-know-how-ghosts-work
  (« separation ensures competitive integrity »). → §1.4.
- **Bazaar migration vers income linéaire** (patch 7.0.0) après friction onboarding : bazaar-builds.net/
  patch-7-0-0 → **confirme l'or fixe**. → §2.
- **Spell Cascade daily** (dev.to/yurukusa 2026) : « the seed is authentication, but the experience must feel
  fair » → équité de difficulté ≠ reproductibilité. → §1.8. + **timezone** (date locale acceptable en v1).
- **PoE Wither** (pathofexile.com/forum/view-thread/3870562) : debuff cumulatif dominant « only measurable by
  isolating the debuff contribution », plafonné 15 charges → **analogue du weaken**. → §1.2.
- **PoE Shock = ampli universel toutes sources** (poewiki.net/wiki/Shock) → l'ordre-fixe-pur trahit la
  promesse ; ampli par famille-du-poseur. → §1.3.
- **Nunes & Drèze 2006** (« Endowed Progress Effect », JCR) : goal-gradient s'efface au-delà de ~7 étapes →
  signal pré-run au **sub-tier**. → §1.9.
- **SDT — Möller, Kornfield & Lu 2024** (selfdeterminationtheory.org) : appartenance = besoin le moins traité ;
  Fogg Behavior Model (prompt externe) → signal « spectre affronté ». → §1.5.
- **Kao et al. 2024 (CHI)** : l'amplification excessive *réduit* l'agence → valider le chevauchement des 2
  signaux VRR avant de coder. → §1.6.
- **Smashing Magazine 2026** (UX streaks) + Kahneman-Tversky : loss-streak = anxiété ~2,3× → signal
  actionnable, pas qu'un chiffre. → §1.7.
- **Wayward Strategy 2018** : « units that combo but appear independently create dead picks » → adjuvants
  `shield_caster` hors pool. → §1.12.
- **TFT reroll = 2 or = 40 % du revenu passif** (boosteria.org) + **HS:BG reroll scalant** → trancher
  `REROLL_COST`. → §1.13.
- **StS Ascension a abandonné le score classé** + Dota Underlords ranking mixte → **rejet du score intra-run**
  réaffirmé. → §2.
- **Vérifs code synthétiseur** (relues ce round) : `arena.lua:234-242` (afflictionCount = présence) ;
  `units.lua:280-287` (wither_bloom dps=0) ; `:362-376`/`:479`/`:507` (shield renforts dans U.pool) ;
  `snapshot.lua:24` (struct sans `mode`/`sv`) ; `state.lua:26-34` (REROLL_COST=1 etc.). → §0.

---

## 6. Améliorations mesurables vs v5 (ce que cette synthèse ajoute)

1. **3 corrections code-vérifiées de plus** (afflictionCount/plague_communion faux signal ; shield-renforts =
   dead picks dans le pool ; snapshot sans `mode`) — la règle « citer la ligne » continue de débusquer des bugs.
2. **1 litige clos** (#S → `dot_family` du poseur + fallback, par argument de promesse de design).
3. **2 secondes causes structurelles nommées** : `--no-weaken` (poison) et le pool ranked/unranked (intégrité).
4. **1 lacune de rétention majeure comblée** : session initiation (signal d'appartenance async, SDT).
5. **1 anti-cannibalisation** : valider la distribution temporelle des 2 signaux VRR **avant** de les coder.
6. **1 décision éco jamais challengée exposée** : `REROLL_COST=1` → sim + tableau d'intention des constantes.
7. **2 colonnes d'audit ajoutées** (H dépendance pool, I contre-quoi-optimal) → 9 colonnes A-I.
8. **5 nouveaux litiges** (#V sv, #W burn-bouclier, #X relique-méta-DA, + #T/#U précisés) ; **6 critiques
   rejetées/dépriorisées avec raison mécaniste** (sv-maintenant, hybride-sec, friction-moteur, pré-run-directif,
   guidance-prospective-doublon, contre-jeu-méta-prématuré).

---

*Round 05 synthétisé le 2026-06-23. Débat, pas addition : 14 adoptions argumentées, 7 rejets/déprios sourcés,
14 litiges (1 clos, 5 neufs). Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés.
4 claims code revérifiés par le synthétiseur. ROADMAP-draft réécrit en conséquence (v6).*
