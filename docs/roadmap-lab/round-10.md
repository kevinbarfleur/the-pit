# Round 10 — Synthèse adversariale FINALE (10/10)

> **Méthode** : intégration critique des 6 lentilles `rounds/r10-*.md` contre le brouillon v10
> (`ROADMAP-draft.md`, intégré round 9). On **adopte** les critiques valides et sourcées, on
> **rejette/nuance** les faibles (raison mécaniste), on **consigne** les vrais litiges restants. C'est un
> débat, pas une addition. **Round FINAL** — les rounds 1-9 ont bâti une architecture solide ; ce round
> attaque les **angles morts résiduels** que 9 itérations n'ont jamais regardés en face, et **clôt** les
> litiges clôturables par preuve.
>
> **Claims de code revérifiés ce round par les lentilles** (lecture seule, session 2026-06-23) :
> 1. `units.lua:421-424` : `skull_colossus = { type="bone", family="crane", burn{dps=4, dur=200} }` → la
>    réorientation « apex choc » du brouillon est **DA-invalide** (crâne osseux ≠ électricité, décision #3)
>    ET le diagnostic « carry burn » mélange DPS_frappe (mélée) et burn_dps (DoT) — le burn_dps=4 est **sous
>    le rang-1** `ash_moth`(7). (units §2.1/§2.2, **le renversement le plus net du round**).
> 2. `relics.lua:26-29` : les 4 reliques B sont **architecturalement identiques** (`relic_affliction_inc`,
>    seule la famille diffère) → elles ne distinguent pas les STYLES intra-famille (relics §2.1).
> 3. `relics.lua:64-66` : le tier-gating de `carrion_ledger` (tier 3) est **anti-optimal** — sa valeur est
>    maximale en EARLY (bypasse un palier XP entier), pas en mid (relics §2.2).
> 4. Snapshot capturé à `startCombat` seul (`snapstore.lua:save`, 00-state §5) → **faille d'intégrité
>    « concede meta »** : un run avorté avant `startCombat` ne génère pas de ghost (ranked §2.1).
>
> **Garde-fou** : lecture seule du repo, écriture uniquement sous `docs/roadmap-lab/`. Piliers intacts
> (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural). 32 invariants
> préservés (toutes les adoptions sont RENDER / IO / data / doc / sim / config ou décision éditoriale).

---

## 0. Ce qui change ce round (résumé exécutif)

**Le round 10 est un round de COMPLÉTUDE DE SPEC + INTÉGRITÉ + FEEDBACK.** Là où le round 9 a découvert un
fil rouge systémique (#JJ, alignement payoff↔agence), le round 10 fait trois choses neuves :
(a) il **corrige une proposition DA-invalide** que 3 rounds avaient laissée passer (`skull_colossus → apex
choc` : un crâne osseux ne lance pas d'électricité) ; (b) il **identifie une faille d'intégrité async
silencieuse** (le « concede meta » : capturer le snapshot seulement à `startCombat`) que 9 rounds n'avaient
jamais nommée ; (c) il **comble des angles morts de spec sur la SIGNATURE du jeu** — aucune relique
positionnelle (sigils), aucune mesure de saturation des ARÊTES, le high-roll spécifié comme probabilité au
lieu de **feedback séquentiel visible**. **La leçon de méthode tient une 6e fois** : les lentilles qui
relisent le code (units, relics, ranked) trouvent des défauts concrets que les rounds précédents avaient
posés « au jugé ».

**Le fil rouge inter-lentilles de R10 — LA SIGNATURE EST SOUS-SPÉCIFIÉE.**
Trois lentilles indépendantes convergent sur le même constat : *le moteur (effets/sigils/adjacence/déterminisme)
est riche, mais les couches qui exploitent la SIGNATURE du jeu (le plateau-graphe, le déterminisme comme
chance de feedback causal) sont sous-spécifiées dans la roadmap.*
- **Relics §2.5** : AUCUNE des 21 reliques n'interagit avec la topologie du plateau (les 5 sigils). Le
  différenciateur #1 du jeu n'a aucun payoff de relique.
- **Synergies §2.3** : la saturation des ARÊTES d'adjacence n'a JAMAIS été mesurée — on a un tableau de
  saturation des `inc` (P1) mais zéro pour la dimension qui distingue The Pit de tous les autobattlers.
- **Rétention §2.1** : le déterminisme est une CHANCE de feedback causal (le joueur peut reconstruire la
  chaîne exacte), mais le high-roll est spécifié comme une probabilité (enveloppe VRR) sans la **séquence
  d'activation visible** qui transforme une cascade en apprentissage (mécanisme Balatro).

= **un constat transversal adopté** : avant de figer P1 et P2, la roadmap doit poser les **préconditions de
la signature** (saturation des arêtes + premières reliques sigil-aware + feedback séquentiel), au même titre
que le tableau de saturation `inc` et le tableau d'intention éco l'ont été pour leurs chantiers.

**16 adoptions majeures (toutes data/doc/sim/RENDER/IO/config, 0 invariant) :**

1. **`skull_colossus → apex choc` est DA-INVALIDE — créer une NOUVELLE unité rang-5 choc** (units §2.1/§2.2,
   `units.lua:421-424` code-vérifié) : `type="bone", family="crane"` (crâne osseux mort-vivant) + `shockChain`
   (électricité) = incohérence thème/mécanique (décision #3, le différenciateur du jeu). Tous les units choc
   sont `type=arcane/abyss`. **Décision** : (a) NOUVELLE unité rang-5 choc `type=arcane/abyss` (~15 lignes
   data + `grant_team`) ; (b) `skull_colossus` **reste burn**, niche tank-burn clarifiée (burn_dps 4→8) ou
   sacrificielle. **Le « 0 moteur » du recyclage était une analogie mécanique paresseuse.** ⟹ corrige la
   proposition la plus erronée des 9 rounds.
2. **Audit rang-5 à TROIS colonnes E1/E2/E3 (DPS_frappe / DoT_dps / grant_team)** (units §2.3/P-C) : le
   diagnostic « carry burn DPS 0.131 » de R09 porte sur la **frappe mélée** (`dmg/cd`), pas sur la contribution
   burn (`burn_dps=4`, **sous le rang-1** `ash_moth`=7). `skull_colossus` = E1 haut + E2 bas (tank-burn opaque) ;
   `deep_kraken` = E1 ET E2 hauts (confond carry/transform). **Remèdes DIFFÉRENTS** → distinguer les axes.
3. **FAILLE D'INTÉGRITÉ « CONCEDE META » = #LL neuf — capturer le snapshot au PREMIER ACHAT, pas seulement à
   `startCombat`** (ranked §2.1, Steam Bazaar août 2025 : « kinda HAVE TO concede to win ») : un run avorté
   avant `startCombat` ne génère aucun ghost → le joueur qui concède sélectionne ses bons départs sans
   alimenter le pool. **Décision (~5 lignes IO `snapstore.lua`)** : capturer dès `shopBuys >= 1` OU round 2
   atteint (whichever first) ; exclusion si jour-0 identique (shopTier==START AND slots==START AND 0 achat).
   **AVANT le code ranked P2.**
4. **HIGH-ROLL = FEEDBACK SÉQUENTIEL VISIBLE, pas probabilité — spécifier l'activation séquentielle dans §2.4
   /§2.3** (rétention §2.1/Prop-A, Blake Crosley + CHI 2025 Kao n=1699) : la roadmap dose les VRR en fréquence
   sans spécifier que les événements du bus sont rendus SÉQUENTIELLEMENT (délai 80-120ms/nœud, accélération
   Balatro). Sans cette spec, l'impl par défaut = affichage simultané (bruit), pas cascade lisible
   (apprentissage + dopamine). **Spec RENDER, 0 SIM ; le bus JSONL a déjà source/cause/tick.**
5. **AUCUNE RELIQUE POSITIONNELLE — spécifier 4 candidats sigil-aware pour P1.5b** (relics §2.5) : le
   plateau-graphe 3×3 est LE différenciateur (CLAUDE.md §2) mais aucune relique ne récompense un sigil.
   Candidats 0-moteur (lisent `shapes[shape].edges`, snapshotable, déterministes) : `axis_pact` (croix),
   `bloodline` (ligne), `ring_hunger` (anneau), `horde_pact` (diamant). Satisfont le critère COURONNEURS
   (dimension placement, adopté R09).
6. **TABLEAU DE SATURATION DES ARÊTES (parallèle au tableau de saturation `inc`) = précondition P1** (synergies
   §2.3, Kritz & Gaina 2025 : saturation positionnelle > saturation de type car co-location requise) : par
   (sigil × famille × slots=3/5/7/9), `saturation = E[arêtes_homogènes] / arêtes_max` ; alarme < 0.3 à 7 slots
   = incompatibilité positionnelle (ex. bleed+ligne). ~1 h combinatoire sur `shapes.lua`, 0 sim.
7. **CRITÈRE DE TRANCHAGE CONFIG-CE2 : Option A (auto-DoT) par défaut, aligné #JJ** (synergies §2.1, PoE
   Lightning Exposure) : si `discharge_effective_ratio < 0.40` en config (b) → Option A (1 rang-3 choc qui
   auto-pose un DoT avant de charger = fiabilité dépend du BUILD, pas de l'adversaire). Option B (axe A/B) =
   fallback secondaire. **Ferme « détection sans résolution ».**
8. **#HH (palier choc-4) ÉVALUÉ PAR #JJ → Option B (`tickCount=2`) CLÔT #HH MAINTENANT, indépendamment de
   #GG** (synergies §2.2) : Option A (arc → voisin ADVERSE) = cause partiellement contrôlée (placement adverse
   en async) ; Option B (ticks DoT du POSEUR amplifiés) = cause FORTE (compo du build). Option B est compatible
   avec les deux axes d'apex → **#HH tranchable, #GG reste ouvert.**
9. **GRIMOIRE MINIMAL AVANCÉ à v0.9.3 (// P0.5), pas v0.11** (rétention §2.3/Prop-D, Åslund 2026) : la
   méta-progression légère requiert plus de temps pour « devenir claire » → un Chapitre I (reliques + silhouettes)
   dès le 1er run donne l'ancre méta-progressif dans la fenêtre la plus critique (runs 1-5). ~2 h RENDER, lit
   `grimoire.lua` déjà câblé.
10. **GRIMOIRE CHAPITRE II SEGMENTÉ PAR FAMILLE — passe le seuil 40 % en 2-3 runs** (rétention §2.2/Prop-B,
    Yu-Kai Chou : seuil de bascule empirique 40-60 %) : 83 unités totales = un joueur mono-famille reste sous
    40 % pendant 5-7 runs (« bruit de fond »). Afficher « 4/13 essences BURN (31 %) » par section → l'Ovsiankina
    devient personnalisé à l'archétype. **Déjà esquissé §6.7 (segmenté par famille) — R10 ajoute le RATIONNEL du
    seuil 40 % + le risque mono-famille.** ~1 h RENDER, dépend de P0.5 (`dot_family`).
11. **CADENCE DE SAISON S1-S2 : 5 SEMAINES (non 3)** (ranked §2.2, Milkman 2014 démontée + GamineAI 2026) :
    3 sem. = 6-9 runs = une session, pas une saison ; le joueur n'a pas le temps de s'identifier à sa position
    pour ressentir le reset comme un renouveau. **Et** pool FIFO 200 LOCAL ≠ Bazaar mondial : à 5 sem. (10-15
    runs = 1 tier mid-core), le joueur voit ~50 ghosts et le pool a le temps de se régénérer. **Garde-fou bas :
    jamais < 4 sem.** ⟹ révise le §6.3 (qui avait 3 sem. sur un benchmark Bazaar mal transféré).
12. **RE-TIER `carrion_ledger` (tier 3 → 2)** (relics §2.2, `relics.lua:64-66`) : +6 XP de boutique = valeur
    MAXIMALE en early (bypasse le 1er palier XP entier). En tier-3, elle arrive systématiquement après le seuil
    optimal = anti-optimal depuis le code. 1 ligne data, golden-safe (F = `runOp`, pas de combat).
13. **GRANULARITÉ INTRA-FAMILLE sur UNE relique B (test `venom_covenant` poison)** (relics §2.1,
    `relics.lua:26-29`) : les 4 B sont architecturalement identiques (`relic_affliction_inc`) → un build
    poison-spread et un build poison-weaken reçoivent la MÊME `kings_bowl` avec le même effet (StS Paper Phrog =
    contre-exemple : amplifie le sous-build qui applique Vulnerable). Ajouter 1 variante B à périmètre étroit +
    fort (lit `spec.effects` au build = 0 moteur, async-safe). **UNE famille à la fois (poison dominant), après
    sim.**
14. **DÉCIDER `hollow_choir` : RÉORIENTÉE (`pierceShield`) en P1.5b, PAS retirée par inertie** (relics §2.4) :
    si retirée de `U.pool` (pool-A) sans décision de réorientation, elle risque d'être oubliée en P1.5b puis
    re-ajoutée = double travail. Graver la décision dans §4.10 AVANT P1.5a. Décision doc, 0 code maintenant.
15. **FILTRE DE PERSISTANCE GHOST ENRICHI : `wins_at_capture ≥ 3 AND tier_proxy`** (ranked §1.4) : 3 victoires
    early ≠ 3 victoires late STRUCTURELLEMENT (un build chanceux tôt peut être plus avancé qu'un build à win=7).
    Double critère `wins_at_capture ≥ 3 AND slot_tier_composite ≥ MIN_COMPOSITE [PH]` (le même proxy de
    matchmaking §6.4) + fallback si pool < SOFT. Doc, 0 code.
16. **CANDIDAT POISON-4 NOMMÉ `poisonWeakenDeep` (SPEC À PROUVER)** (synergies §2.4) : burn-4/bleed-4/rot-4 ont
    un twist nommé, choc-4 = #HH (ci-dessus), poison-4 = vide depuis 10 rounds. Candidat : le weaken s'applique
    aux passives adverses (auras) à coefficient réduit (0.30). Compléte la spec P1 SYMÉTRIQUEMENT (5/5 familles).

**8 adoptions de précision / métrique / doc (doc ou sim) :**
- **TABLE DU PLAFOND NATUREL DE LA PASSIVE avant `--xp-climax`** (progression §2.1/§3.5) : 5 lignes
  arithmétiques par courbe candidate (round où un joueur 0-BUY_XP atteint chaque tier) → prédit si la sim va
  valider/invalider chaque courbe SANS la lancer. `{2,5,10,18}` : T5 passif à R19 (juste à la fin d'un run long).
- **SIGNAL SLOT-UNLOCK CORRIGÉ : intégrer l'HORIZON DE RUN** (progression §2.2) : `(9 − slots)` mesure le
  potentiel TOTAL, pas la valeur MARGINALE MAINTENANT (4 slots au round 2 ≠ 4 slots au round 7). Remplacer par
  `rounds_remaining_est = (WIN_TARGET − wins) + lives − 1` (borne haute, hors SIM). Même coût de dev (~1 h
  RENDER), signal plus précis.
- **REMPLACER Amabile & Kramer par l'ENDOWED PROGRESS EFFECT (Nunes & Drèze 2006)** pour le rôle [B] de la
  passive (progression §2.3) : Amabile & Kramer étudient la motivation au TRAVAIL signifiant ≠ jeu ; une passive
  invisible ne déclenche pas la même neurochimie qu'un progrès actif. L'Endowed Progress Effect (avantage perçu
  comme effort du soi) est la source correcte — **avec précondition de framing** : la passive doit être présentée
  comme un DON grimdark (« LE PUITS T'ACCORDE SA MARQUE »), pas un fait du temps.
- **HIÉRARCHIE DE REMÈDES à la co-calibration §7.1 condition 4** (progression §2.4) : R1 (sans code,
  communication de coût d'opportunité) > R2 (data, `BUY_XP_COST` T1 → 5g) > R3 (mesure, exclure rush_XP). Sans
  critère de résolution, la condition 4 est « détection sans verdict » — exactement ce que le tableau §7.0 doit
  éviter. Ordre strict : R1 avant R2 avant R3.
- **NEAR-MISS REFORMULÉ COMME HYPOTHÈSE TESTABLE (0 moteur supplémentaire)** (ranked §2.3 + rétention §2.4) :
  « [UNITÉ] A CÉDÉ AU ROUND N — [FAMILLE ADVERSE] — ESSAIE [UNITÉ ANTI-X] » (lit l'event-log JSONL déjà
  structuré + famille dominante du snapshot servi + table statique anti-fam dans `units.lua`). Grimdark : « le
  Puits révèle sa faille ». Contrainte : ne JAMAIS prescrire une unité absente du pool boutique actuel.
- **HINT NEAR-MISS OPTIONNEL (opt-in, runs 1-3)** (rétention §2.4/Prop-C) : le post-combat est diagnostique
  (« exposé front ») mais non prescriptif. Ajouter UNE ligne opt-in (`settings.near_miss_hint`, off par défaut)
  « un taunt en avant-gauche aurait absorbé l'attaque » — respecte l'autonomie des experts (Grid Sage 2025) tout
  en balisant le near-miss type-1 pour les novices. ~30 min RENDER.
- **PRÉREQUIS PROFONDEUR DU PUITS : vérifier l'escalade IA (`encounters.lua`)** (ranked §1.2/§3.5) : la
  Profondeur du Puits (#KK) n'est motivante que si les adversaires scalent réellement entre le round 4 et le
  round 8 ; sinon elle mesure un plafond de difficulté, pas de skill. Vérification : 1 grep sur `encounters.lua`
  AVANT de coder le signal §6.2 (si plat = dette de contenu à résoudre d'abord).
- **DIRECTIONNALITÉ #FF → Option B (symétrique 2 passes) favorisée par #JJ** (synergies Q2) : Option A
  (directionnelle) = condition partielle (dépend de la présence de la famille adverse) ; Option B (les 2 familles
  co-présentes du BUILD s'amplifient) = condition FORTE (compo contrôlée). **Recommandation de clôture #II**,
  à décision user (rebaseline golden potentielle = garde-fou explicite).

**4 ré-ancrages / corrections d'analogie :**
- **« Milkman 2014 justifie des saisons courtes » = mal transféré** (ranked §4.1) : Milkman étudie des
  landmarks NATURELS (lundi, Nouvel An) — préexistants, indépendants du comportement. Un reset de saison est un
  landmark ARTIFICIEL imposé : sa puissance Fresh Start est PROPORTIONNELLE au sentiment d'avoir quelque chose à
  recommencer (accumulation préalable). Retenir Milkman pour le garde-fou BAS (jamais < 4 sem.), pas pour
  justifier 3 vs 5.
- **« Le Bazaar mensuel = notre benchmark de cadence » = fausse équivalence** (ranked §4.2) : pool mondial de
  dizaines de milliers (adversaires non répétitifs) ≠ FIFO 200 LOCAL (épuisé en ~20 runs). Ce qui reste valide
  du Bazaar : le reset SOFT (top players ramenés à un tier inférieur, non Bronze) — déjà adopté §6.3 (−20 %).
- **« skull_colossus convient à l'apex choc car HP/aggro suffisent » = analogie mécanique paresseuse** (units
  §2.2) : le slot existe, le stat-line convient → donc électricité. Le « pourquoi psychologique » de The Pit
  (immersion grimdark par cohérence thème/mécanique, décision #3) NE transfère PAS. Le stat-line ne fait pas
  l'identité.
- **« Plus de slots = plus d'arêtes = plus de profondeur » = hypothèse non vérifiée** (synergies §2.3) : la
  croix n'a que 4 arêtes (branches isolées) ; avec 5 slots ouverts, 3 branches peuvent n'avoir qu'une unité (0
  arête active). La profondeur positionnelle est structurellement variable par sigil → d'où le tableau de
  saturation des arêtes.

**Litiges neufs / clos / re-qualifiés :**
- **#LL (neuf, ranked §2.1)** : ancre de snapshot ranked (premier achat vs round 2 vs startCombat). Ouvert,
  recommandation = les deux en OR. **Prérequis P2, AVANT code ranked.**
- **#HH → CLOS (synergies §2.2)** : palier choc-4 = Option B (`tickCount=2`), aligné #JJ, compatible avec les
  deux axes de #GG. **Tranchable maintenant, indépendamment de #GG** (preuve : évaluation #JJ des 2 options).
- **#II → CLOS recommandé (synergies Q2)** : directionnalité #FF = Option B (symétrique), favorisée par #JJ.
  Décision user (rebaseline golden = garde-fou).
- **#Y RÉ-OUVERT (ranked §5.2)** : avec #LL (capture au premier achat), la fenêtre de grâce 7 j se remplit plus
  vite → l'argument de la persistance filtrée vs vidage change. **Re-trancher en P2 après mesure de densité.**
- **Q_R10_4 / Q_R9_2 RE-QUALIFIÉ BLOQUANT (rétention §4)** : gate §2.10 sur `ghost_is_human == true` — en bêta,
  majorité IA → un signal §2.10 non-gaté est banal dès le round 1. Décision éditoriale user requise avant le
  code §2.10.
- **#GG maintenu BLOQUANT** mais **DÉCOUPLÉ de #HH** : le palier choc-4 ne contraint plus l'axe d'apex (Option
  B compatible avec les deux). #GG = uniquement l'axe de l'APEX rang-5 + (R10) le besoin d'une NOUVELLE unité
  rang-5 choc (non skull_colossus).

---

## 1. Adoptions — UNITS-POWER (le renversement DA-invalide + l'audit two-axis)

> La lentille units-power a relu `units.lua` intégralement et calculé DPS_frappe ET DoT_dps. Elle livre le
> désaccord le plus net du round : la réorientation `skull_colossus → apex choc` du brouillon est invalide.

### 1.1 ADOPTÉ (PRIORITÉ HAUTE, co-bloquant #GG — DOC §3.7 + NOUVELLE unité data) — `skull_colossus → apex choc` est DA-INVALIDE ; créer une nouvelle unité rang-5 choc (units §2.1/§2.2)

**Critique (units §2.2, `units.lua:421-424` + `:299-334` relus, décision #3 DA grimdark)** : le brouillon §3.7
réoriente `skull_colossus` (libéré du rang-5 burn) en **apex choc rang-5** via `grant_team {shockChain}`. Mais
`skull_colossus = { type="bone", family="crane" }` — un crâne colossal osseux (mort-vivant grimdark). **TOUS
les units choc existants sont `type=arcane` ou `type=abyss`** (live_wire/thunderhead/stormlord = arcane ;
static_swarm/arc_warden/siphon_jelly = abyss ; galvanizer = flesh-arachnide « fil électrique »). Aucun n'est
`type=bone`. L'électricité sur un crâne osseux **brise la cohérence visuelle-mécanique** qui est le
différenciateur de The Pit (décision #3 : « DA grimdark = thème + mécanique fusionnés »).

**Pourquoi le synthétiseur ADOPTE (et corrige une décision de 3 rounds)** : c'est exactement le type
d'analogie mécanique paresseuse que le BRIEF interdit (« le slot existe, le HP/aggro convient → donc
électricité »). Le « pourquoi psychologique » du jeu (immersion grimdark par cohérence) ne transfère pas au
stat-line seul. La proposition « 0 moteur » du round 7 était fausse sur le **fond thématique**, pas seulement
sur le moteur (que #GG avait déjà nuancé). **La proposition apex-choc-via-skull_colossus est RETIRÉE.**

**Décision (DOC §3.7, NOUVELLE unité data ~15 lignes)** :
```
APEX CHOC rang-5 = NOUVELLE UNITÉ (pas un recyclage de skull_colossus) :
  type = "arcane" OU "abyss" (cohérent avec la famille choc) ; family = électrique (DA grimdark)
  rank=5, cost=5, hp=60-70 (carry, pas tank), aggro=5-10, dmg=7, cd=60-70
  effects : { on_hit: shock{add=2, volt=6, cap=8, dur=240} }
          + { combat_start: grant_team{shockChain=true} }  -- SI #GG → axe A/B (0 moteur, ops.lua:187)
          OU { combat_start: grant_team{shockAmplify=true} } -- SI #GG → axe D (~3-5 lignes SIM)
  → respecte le contrat rang-5 (grant_team = règle d'équipe, comme TOUS les T3 légitimes).
  → pool : U.order direct ; U.pool conditionnel à CONFIG-CE2 (si axe D fragile sans setup, U.order d'abord).
skull_colossus RESTE burn (voir §1.2) — libéré du faux rôle d'apex choc.
```
**§3.7 corrigé (réorientation apex choc RETIRÉE).** Q2 units (U.pool vs U.order) tranchée par #GG/CONFIG-CE2.
Source : units §2.2 ; `units.lua:421-424` (type=bone) ; décision #3.

### 1.2 ADOPTÉ (PRIORITÉ HAUTE — DOC §3.7) — Audit rang-5 à TROIS colonnes E1/E2/E3 + remèdes différenciés skull_colossus / deep_kraken (units §2.1/§2.3/P-C)

**Critique (units §2.1, DPS recalculés)** : le diagnostic R09 « `skull_colossus` carry burn DPS 0.131 qui
domine `ash_maw`(0.100) » porte sur la **frappe mélée** (`dmg/cd`), pas sur la contribution burn. Le burn_dps
réel = **4** — soit **égal à `cinder_cur` rang-2 et SOUS le rang-1 `ash_moth`(7)**. `skull_colossus` n'est PAS
un carry burn : c'est un **tank avec burn résiduel** à niche ambiguë. R09 a confondu deux axes orthogonaux.

**Vérifié par la lentille** : `units.lua:421-424` (burn_dps=4) vs `:100` (ash_moth=7) vs `:231-236` (ash_maw=6
+ grant_team). **L'asymétrie skull_colossus / deep_kraken** : `deep_kraken` a un poison_dps=4 qui est
SUPÉRIEUR aux T3 légitimes (festering/venom_censer à dps=2) — problème INVERSE (confond carry et transform).

**Pourquoi c'est valide** : un remède mal ciblé (traiter skull_colossus comme deep_kraken) corrigerait le
mauvais axe. La distinction E1 (DPS_frappe) / E2 (DoT_dps) / E3 (grant_team) est la grille correcte.

**Décision (doc §3.7, enrichir la grille §3.1 d'une distinction rang-5)** :
```
Audit rang-5 à 3 colonnes (E1 DPS_frappe = dmg/cd | E2 DoT_dps = dps de l'effet | E3 grant_team) :
  skull_colossus : E1=0.131 HAUT | E2=burn 4 BAS | E3=AUCUN → tank-burn opaque (niche ambiguë)
    Remède A (recommandé) : burn_dps 4→8 (cohérent ash_moth=7), aggro=40 maintenu → "mur qui brûle fort"
    Remède B (alt) : burn{dps=4} + on_death_ally{spread_burn frac=1.0, dps=10} → "crémateur d'alliés"
  deep_kraken : E1=0.154 HAUT | E2=poison 4 HAUT | E3=AUCUN → confond carry/transform
    Remède : target="column" AoE + grant_team{poisonNoShield} (~5 lignes SIM si target neuf) ou croisé poison-rot
  → les deux problèmes sont DIFFÉRENTS (E2 bas vs E2 haut) → remèdes différents.
```
**§3.7 enrichi.** Golden à grep avant tout change (`skull_colossus` dans le scénario ? burn_dps=8 peut déclencher
`DOT_CAP_MULT=3`). Q1/Q3 units (golden + distinction pyre_tender) à vérifier en sim. Source : units §2.1/§2.3 ;
`units.lua` (lignes citées) ; Cloudfall StS ; GDC 2019 Giovannetti.

### 1.3 CONFIRMÉ NON-DÉSACCORD (units §1.1-1.6) — les accords de 8 rounds tiennent

Stat-sticks rang-5 violent le contrat (§1.1) ; paire `corruptor`/`bile_spitter` (§1.2) ; `rust_sentinel` =
`stormcaller` déguisé (§1.3) ; désert rang-3 burn = 1 poseur actif (§1.4) ; flag compatibilité sigil auras r3/4
(§1.5) ; trou rang-5 choc structurel #GG (§1.6). **Tous re-confirmés par relecture code ce round, non
re-challengés.** La précision R10 (§1.5) : le flag hostile pour la `ligne` est critique SPÉCIFIQUEMENT pour
bleed (archétype ligne-intuitif) — confirme que P1 ne doit pas prescrire `clot_mender` comme aura centrale d'un
palier bleed ciblant la ligne (croisé avec §2.3 synergies, tableau de saturation des arêtes).

---

## 2. Adoptions — RANKED (intégrité du concede + cadence corrigée)

### 2.1 ADOPTÉ (#LL neuf, PRIORITÉ 0 AVANT code ranked — ~5 lignes IO `snapstore.lua`) — Ancre de snapshot ranked : capturer au PREMIER ACHAT (ranked §2.1)

**Critique (ranked §2.1, Steam Bazaar août 2025 + Reynad interview déc. 2024)** : le snapshot est capturé à
`startCombat` (build actif). Un joueur ranked qui voit une mauvaise boutique R1 et **abandonne la run** (avant
`startCombat`) ne génère aucun ghost → il sélectionne effectivement ses bons départs sans pénalité ni
contribution au pool. Preuve directe (steamcommunity.com/app/1617400, août 2025) : « players can just concede
until they get ideal rewards. There is no punishment for doing this. [...] you kinda HAVE TO concede to win. »
Reynad confirme avoir conçu le matchmaking Swiss AUTOUR de ce problème.

**Pourquoi c'est valide ET ré-attaque le pilier async** : en pool FIFO 200 LOCAL (petit), chaque ghost écarté
par un concede = un ghost de moins pour les autres. Le pool ranked se biaise vers les builds qui ont eu une
bonne boutique R1-2, pas ceux qui ont géré l'adversité. **C'est une faille d'intégrité silencieuse que 9 rounds
n'ont jamais nommée** — elle structure le comportement ranked dès S1.

**Pourquoi le synthétiseur ADOPTE (en nuançant l'angle déterministe)** : la critique soulève aussi que le
RNG de run seedé rend le concede « semi-déterministe » (le joueur apprendrait à identifier les R1 favorables).
**Le synthétiseur BORNE cet angle** : c'est un risque LONG-TERME spéculatif pour une bêta (le joueur ne lit pas
`rng_state` en jeu normal), PAS le justificatif premier. **Le vrai problème est l'intégrité du POOL** (un run
avorté ne l'alimente pas), et le remède est cheap et sain.

**Décision (#LL, ~5 lignes IO `snapstore.lua:save`, AVANT code ranked P2)** :
```
ANCRE DE SNAPSHOT RANKED (#LL, integrity guard) :
  Déclencher snapstore.save (mode ranked) dès :
    (a) premier achat de run effectué (runState.shopBuys >= 1)  OU
    (b) round 2 atteint (startRound(2))  OU
    (c) startCombat (comportement actuel, fallback)  — whichever FIRST.
  Exclusion : shopTier==START_TIER AND slots_actifs==START_SLOTS AND shopBuys==0
    (jour-0 identique pour tous = ghost informatif nul → ne pas polluer le pool).
  Flag debug : capture_reason = "first_buy" / "round_2" / "combat" (pas dans toComp).
  Effet intégrité : un concede APRÈS le premier achat alimente quand même le pool → l'avantage du concede
    est NEUTRALISÉ (son build R1 sert au pool de ses futurs adversaires). PAS de pénalité directe (cohérent
    §6.2 sans pénalité). Grimdark : « Le Puits garde trace de chaque descente, même avortée. »
```
**§6.4bis enrichi.** Zone sans test → test que `save()` est appelé au premier achat ranked + test que les runs
avortées avant achat ne génèrent PAS de ghost. ⟹ **#Y RÉ-OUVERT** (§5.2 : impact sur la densité de la grâce
7 j). Source : ranked §2.1 ; steamcommunity.com/app/1617400 (août 2025) ; bazaar-builds.net/reynad-interview ;
azurgames.com Kingdom Clash (exploits = confiance détruite).

### 2.2 ADOPTÉ (PRIORITÉ 1 — DOC §6.3, 0 code) — Cadence de saison S1-S2 : 5 SEMAINES (non 3) (ranked §2.2/§4.1-4.2)

**Critique (ranked §2.2, Milkman 2014 démontée + GamineAI 2026)** : le §6.3 fixe les saisons 1-2 à 3 semaines
en citant Fresh Start (Milkman 2014) + Bazaar mensuel. Mais (a) Milkman étudie des landmarks NATURELS
(préexistants, indépendants du comportement) — un reset de saison est ARTIFICIEL : sa puissance Fresh Start est
proportionnelle au sentiment d'avoir quelque chose à recommencer, ce qui exige une accumulation préalable. **3
sem. = 6-9 runs = une session, pas une saison.** (b) Bazaar mensuel = pool mondial (adversaires non répétitifs)
≠ FIFO 200 LOCAL (épuisé en ~20 runs). À 3 sem., le joueur a vu ~60 ghosts sur 200 mais le pool n'a pas eu le
temps de se régénérer (dépend du nombre de joueurs ranked actifs).

**Pourquoi le synthétiseur ADOPTE (renversement d'une valeur faiblement fondée)** : le §6.3 v10 justifiait les
3 sem. par « Bazaar mensuel = benchmark » — analogie que ce round démontre fausse pour notre pool local. La
maths propre de la lentille (2-3 runs/sem × 5 sem = 10-15 runs = 1 tier mid-core = ~50 ghosts rencontrés) est
plus solide que la valeur héritée. GamineAI 2026 confirme « most teams start between 6 and 12 weeks » pour une
saison. **C'est une vraie résolution de litige, pas une addition** : la valeur précédente (3 sem.) était
elle-même posée sur un benchmark mal transféré.

**Décision (doc §6.3, cadence révisée)** :
```
CADENCE RÉVISÉE §6.3 (challenge la valeur héritée de 3 sem.) :
  | Saison              | Durée  | Condition                                                |
  | Saisons 1-2 (pré-P3)| 5 sem. | pas de contenu — Fresh Start minimal mais RÉEL (non 3)   |
  | Saisons P3+         | 6-8 sem| nouveau tuning majeur = mini-refresh                     |
  | Saisons P4+ (G)     | 8-10 sem| contenu nouveau = durée longue justifiée                |
  Garde-fou BAS : jamais < 4 sem. (dessous = session, pas saison ; Milkman 2014 relu = landmark naturel,
    non arbitraire → ne justifie QUE le garde-fou bas, pas 3 vs 5).
  Garde-fou HAUT : jamais > 10 sem. sans contenu (pool ghost stagne, méta prévisible).
  Rationnel : 2-3 runs/sem × 5 sem = 10-15 runs = 1 tier mid-core = ~50 ghosts rencontrés + temps de
    régénération du pool FIFO 200 LOCAL.
```
**§6.3 corrigé (3 sem. → 5 sem. S1-S2 ; garde-fou bas 2→4 sem.).** Source : ranked §2.2 ; GamineAI 2026
(6-12 sem.) ; Milkman 2014 relu (landmark naturel ≠ reset arbitraire) ; FIFO 200 local ≠ pool mondial Bazaar.

### 2.3 ADOPTÉ (PRIORITÉ 1 — DOC §6.3/§6.4bis) — Filtre de persistance ghost enrichi : `wins_at_capture AND tier_proxy` (ranked §1.4)

**Critique (ranked §1.4)** : le filtre `wins_at_capture >= 3` (§6.3) porte une hypothèse non vérifiée — que
3 victoires au moment de la capture garantissent un ghost « légitime ». Mais avec notre économie (boutique
seedée par le RNG du run), un build capturé à win=3 peut être plus avancé qu'un build à win=7 si le joueur a eu
de la chance tôt. La capture est temporellement liée aux victoires mais **structurellement liée au shopTier +
reliques**, pas au compte de victoires brut.

**Pourquoi c'est valide** : le `slot_tier_composite` (proxy de matchmaking §6.4 déjà utilisé pour le serve) est
la mesure structurelle correcte. Les deux s'ajoutent bien (temporel + structurel).

**Décision (doc §6.3 + §6.4bis)** :
```
FILTRE DE PERSISTANCE ghost ENRICHI :
  Critère : wins_at_capture >= 3 AND slot_tier_composite >= MIN_COMPOSITE [PH]
  MIN_COMPOSITE = shopTier × slots_actifs ; suggestion >= 6 (ex. shopTier=2,slots=4 OU shopTier=3,slots=3).
  Garde-fou : si pool ghost < RANKED_MIN_POOL SOFT=3 avec le double critère → relaxer à wins_at_capture >= 2
    (priorité : pool non vide). Grimdark : « Le Puits ne garde que les ombres qui ont prouvé leur descente. »
```
**§6.3 + §6.4bis enrichis.** Zone sans test → test que les ghosts filtrés respectent les 2 critères + fallback.
Source : ranked §1.4 ; arxiv.org/html/2602.17015 (Cinder : distribution de skill > proxy discret — non
implémenté, mais documenter `slot_tier_composite` comme PROXY uni-dimensionnel, §4.3 ranked).

### 2.4 ADOPTÉ (PRIORITÉ 2 — DOC §6.2 prérequis, 1 grep) — Profondeur du Puits : prérequis de scaling IA (ranked §1.2/§3.5, #KK)

**Critique (ranked §1.2)** : la Profondeur du Puits (#KK, adoptée R09) est un signal de progression
INDIVIDUELLE motivant SEULEMENT si le joueur perçoit une vraie différence de difficulté entre le round 4 et le
round 8. Si la courbe d'escalade des IA (`encounters.lua`) est plate, la Profondeur du Puits mesure un plafond
d'ÉCONOMIE (or), pas de skill.

**Pourquoi c'est valide** : « je suis bloqué au round 8 » = signal de progression seulement si le round 8 est
réellement plus dur que le 4. C'est un prérequis de SIGNAL, pas un tuning.

**Décision (doc §6.2, 1 grep AVANT code §6.2 signal)** :
```
PRÉREQUIS #KK : vérifier que les builds IA de `encounters.lua` ESCALADENT sur les rounds (1 grep, lecture
  seule). Si plat → dette de contenu à résoudre AVANT d'implémenter le signal Profondeur du Puits, OU
  reformuler comme "rounds atteints" sans promettre de difficulté croissante. + les ghosts ranked servis au
  round 8+ doivent avoir slot_tier_composite >= seuil visible (signal de menace pré-run, 0 mécanique).
```
**§6.2 enrichi (prérequis #KK).** Source : ranked §1.2/§3.5 ; #KK (R09).

### 2.5 ADOPTÉ (corrections d'analogie + #Y ré-ouvert) — Bazaar mensuel démonté + #Y dépend de #LL (ranked §4.2/§5.2)

**(a) « Bazaar mensuel = benchmark » = fausse équivalence** : pool mondial ≠ FIFO 200 local (§2.2 ci-dessus).
Ce qui reste valide du Bazaar = le reset SOFT (top players ramenés à un tier inférieur, déjà adopté §6.3 −20 %).
Et (R10) : Bazaar a SÉPARÉ ses règles de pénalité par niveau (sept. 2025) = confirme « pas de pénalité sur
pool imparfait » (§6.2). **(b) #Y RÉ-OUVERT** : avec #LL (capture au premier achat), la grâce 7 j se remplit
plus vite → l'argument de la persistance filtrée vs vidage complet change. **Re-trancher en P2 après mesure de
densité du pool avec la nouvelle règle de capture.** §6.3/§6.4bis. Source : ranked §4.2/§5.2 ;
bazaar-builds.net/announcement (sept. 2025).

---

## 3. Adoptions — SYNERGIES & EFFETS (clôtures #HH/#II + précondition signature)

### 3.1 ADOPTÉ (#HH → CLOS, PRIORITÉ HAUTE — DOC §3.7/§5) — Évaluation #JJ des candidats choc-4 → Option B clôt #HH indépendamment de #GG (synergies §2.2)

**Critique (synergies §2.2, #JJ + balatrowiki.org)** : les 2 candidats choc-4 (#HH) sont présentés comme des
choix techniques (« si axe A/B → A, si axe D → B ») sans évaluation selon le critère #JJ (cause contrôlée par
le joueur). Or :

| | Option A (arc → voisin) | Option B (tickCount=2) |
|---|---|---|
| Déclencheur | décharge → bounce voisin de la CIBLE | tick DoT du POSEUR |
| Cause contrôlée | PARTIELLE (le voisin ciblé = placement adverse, hors contrôle async) | FORTE (la famille du poseur = compo du build) |
| Verdict #JJ | PARTIEL | FORT |

**Pourquoi le synthétiseur ADOPTE et CLÔT #HH** : Option B (`tickCount=2`) est plus alignée #JJ (le critère
garde-fou adopté R09). **Et — c'est la clé — elle est compatible avec les DEUX axes d'apex** : le tickCount
amplifie les DoTs actifs au moment du tick, PAS au moment de la décharge → indépendant de la décision #GG.
Donc **#HH peut être tranché MAINTENANT (Option B), #GG reste ouvert** (et n'est plus contraint par le palier-4).

**Décision (#HH CLOS, doc §3.7/§5)** :
```
PALIER CHOC-4 = Option B (`tickCount=2`, ~3 lignes SIM) — TRANCHÉ par #JJ :
  twist = "les 2 premiers ticks DoT de la famille du poseur de choc sont amplifiés"
  Cause = compo du build (FORTE #JJ). Distinct de l'apex Option 2 (shockAmpMult = magnitude ; tickCount = durée).
  Compatible avec les 2 axes de #GG → #HH NE CONTRAINT PLUS #GG. Test synergies.lua (invariant #22 étendu).
```
**§3.7/§5 corrigés ; #HH CLOS ; #GG découplé de #HH.** Source : synergies §2.2 ; round-09 §1.0 (#JJ) ;
balatrowiki.org/w/Jokers (« most engaging jokers trigger on cards you CHOOSE to play »).

### 3.2 ADOPTÉ (PRIORITÉ HAUTE — DOC §3.7) — Critère de tranchage CONFIG-CE2 : Option A (auto-DoT) par défaut, #JJ (synergies §2.1)

**Critique (synergies §2.1, PoE Lightning Exposure)** : CONFIG-CE2 mesure `discharge_effective_ratio` mais les
2 branches de décision (A = unité auto-DoT / B = recommander axe A/B) sont « à décider selon la mesure » sans
critère de QUI décide, QUAND, sur QUEL critère. PoE résout la conditionnalité du choc par un ciblage
spécialisé (Lightning Exposure garantit le choc avant les DoT) — l'analogue = l'Option A (l'unité auto-pose un
DoT léger avant d'accumuler du choc, rendant l'axe D auto-conditionnel).

**Pourquoi c'est valide** : une « décision selon la mesure » sans critère = décision différée indéfiniment.
Option A rend la fiabilité dépendante du BUILD (#JJ), pas de l'adversaire. C'est la correction minimale.

**Décision (doc §3.7)** :
```
CRITÈRE DE TRANCHAGE CONFIG-CE2 (aligné #JJ) :
  Si discharge_effective_ratio < 0.40 en config (b) [adversaire sans DoT] :
    → DÉFAUT → Option A : 1 unité rang-3 choc avec on_attack {burn{dps=1,dur=60}} + shock{add=1}
      (auto-pose un DoT avant d'accumuler) = fiabilité dépend du build DU JOUEUR. ~1 ligne data, test headless.
    → FALLBACK → Option B (axe A/B) uniquement si l'auto-DoT crée une collision d'identité rang-3 burn (col A audit).
  Si ratio >= 0.40 : aucune correction ; DOCUMENTER inactif (traçabilité, un round futur ne re-cherche pas).
```
**§3.7 enrichi.** Source : synergies §2.1 ; poewiki.net/wiki/Shock + /Ailment (Lightning Exposure = choc
auto-garanti) ; #JJ.

### 3.3 ADOPTÉ (PRIORITÉ MOYENNE — précondition P1, ~1 h combinatoire) — Tableau de saturation des ARÊTES (synergies §2.3)

**Critique (synergies §2.3, Kritz & Gaina 2025)** : les arêtes d'adjacence sont la SIGNATURE de The Pit
(« la forme EST le graphe de synergies »), mais on a un tableau de saturation des `inc` (P1) et **zéro tableau
de saturation des ARÊTES**. L'hypothèse « plus de slots = plus d'arêtes = plus de profondeur » est non
vérifiée : la croix n'a que 4 arêtes (branches isolées) ; bleed+ligne peut avoir une saturation trop faible
(archétype intuitif mais sous-optimal à cause de l'incompatibilité aura + saturation faible). Kritz & Gaina
2025 : la saturation positionnelle est PLUS à risque que la saturation de type (co-location requise, pas
seulement co-existence).

**Pourquoi c'est valide** : on ajoute des synergies de TYPE (P1) qui CUMULENT avec les auras d'adjacence — sans
connaître la saturation des arêtes, on risque de prescrire des combinaisons P1 incompatibles avec l'archétype
positionnel naturel d'une famille. C'est une précondition de P1 au même titre que le tableau `inc`.

**Décision (doc §5 préconditions, ~1 h combinatoire sur `shapes.lua`, 0 sim)** :
```
PRÉCONDITION P1 — TABLEAU DE SATURATION DES ARÊTES (parallèle au tableau de saturation inc) :
  Pour chaque (sigil ∈ {carré,croix,anneau,diamant,ligne} × famille DoT × slots ∈ {3,5,7,9}) :
    arêtes_max(sigil) = |edges| de shapes.lua ; E[arêtes_homogènes_actives] (pool uniforme par rang)
    saturation = E[arêtes_homogènes] / arêtes_max
  Alarme : saturation < 0.3 à 7 slots → incompatibilité positionnelle documentée AVANT de prescrire une AURA
    de cette famille sur ce sigil en P1 (ex. si bleed+ligne < 0.3 → P1 ne prescrit pas clot_mender comme arme
    principale sur la ligne → note dans la spec P1).
  + colonne "saturation_shield" pour les 6 porteurs de bouclier (Q4 synergies).
```
**§5 enrichi (précondition P1).** Source : synergies §2.3 ; Kritz & Gaina 2025 (arxiv.org/html/2502.10304v1) ;
00-state §2.3 (5 sigils, arêtes explicites).

### 3.4 ADOPTÉ (PRIORITÉ FAIBLE mais COMPLÉTUDE — DOC §5) — Candidat poison-4 `poisonWeakenDeep` (SPEC À PROUVER) + #II clôturable (synergies §2.4/Q2)

**(a) Poison-4 nommé** : burn-4/bleed-4/rot-4 ont un twist nommé, choc-4 = #HH (clos §3.1), poison-4 = vide
depuis 10 rounds. Candidat naturel (le poison agit sur la VALUE via weaken) :
```
POISON-4 (SPEC À PROUVER) — poisonWeakenDeep : si ≥4 unités dot_family=="poison" → teamFlag{poisonWeakenPassif}
  → le weaken s'applique aux passives adverses (auras "combat_start") à coefficient réduit (0.30).
  ~5 lignes data + 1 op {on_hit: weaken_passif, factor=0.30}. Alignement #JJ : compo (4 poison) = contrôlée.
  Garde-fou : ne s'applique PAS aux teamFlags de TYPE adverses (évite la boucle d'interactions inter-camps).
  Compatible DOT_CAP_MULT=3 (le cap borne le DPS, pas le weaken). Simuler P90/P10 poison-4 vs aura-lourde adverse.
```
**(b) #II clôturable (Q2)** : la directionnalité de #FF — Option B (symétrique, les 2 familles co-présentes du
BUILD s'amplifient = condition FORTE #JJ) est favorisée par #JJ vs Option A (directionnelle = condition
partielle). **Recommandation de clôture #II → Option B**, à décision user (rebaseline golden = garde-fou
explicite, ~5 lignes SIM). **§5 enrichi.** Source : synergies §2.4/Q2 ; 00-state §3.1 ; #JJ.

### 3.5 ADOPTÉ (PRIORITÉ FAIBLE — PRÉCISION §5.4) — Batching #FF : distinguer ticks HOMOGÈNES vs MODIFIÉS (synergies §1.1)

**Critique (synergies §1.1)** : la règle de batching `combat_effect_legibility` (« BRÛLURE ×12 ») est correcte
pour la FRÉQUENCE des ticks homogènes, mais #FF ajoute un type d'événement DISTINCT (l'aggravation croisée =
MODIFICATEUR de tick, pas un tick de plus). Sans distinction, le batching aplanit exactement l'interaction que
#FF est censé rendre visible. **Décision (précision §5.4)** : la règle de batching distingue ticks HOMOGÈNES
(« BRÛLURE ×12 ») vs ticks MODIFIÉS par #FF (« BRÛLURE++(×12) » ou VFX couleur mixte). **§5.4 enrichi.**
Source : synergies §1.1 ; accessiblegamedesign.com/guidelines/statuseffects.html.

### 3.6 CONFIRMÉ NON-DÉSACCORD (synergies §5) — accords fermes maintenus

Compteur global pur (#D clos) ; burn-vuln-bouclier (#W clos) ; `bleedPierceShield` ; `DOT_CAP_MULT=3` (cap
essentiel #FF-safe, confirmé Kritz & Gaina) ; `grant_team`/`teamFlags` ; 12 synergies de base ; seuils 2/4 ;
`plague_communion` re-tranché compo joueur (#JJ) ; ordre `--pool-repr` strict (#DD). **Tous maintenus.**

---

## 4. Adoptions — RELIQUES (la couche topologique manquante + granularité intra-famille)

### 4.1 ADOPTÉ (PRIORITÉ HAUTE — SPEC §4.11/§8.1, 0 moteur) — 4 reliques POSITIONNELLES sigil-aware pour P1.5b (relics §2.5)

**Critique (relics §2.5, `relics.lua` intégrale relue, StS contextuel)** : parmi les 21 reliques, **AUCUNE
n'interagit avec la topologie du plateau** (les 5 sigils, les arêtes, la profondeur de colonne). Le critère des
COURONNEURS (R09) cite « dimension de placement » comme critère E valide — mais aucune relique existante ne le
fait, et aucune candidate concrète n'est nommée. C'est un TROU de catégorie entière sur LE différenciateur
signature (CLAUDE.md §2). Le joueur qui maîtrise un sigil n'a pas de relique qui amplifie cette maîtrise.

**Pourquoi c'est valide ET transfère async** : une relique positionnelle s'active au BUILD (lit le `shape` du
sigil actif au `combat_start`) → snapshotable (`shape` déjà dans le format), déterministe (arêtes fixes dans
`shapes.lua`), async-safe. StS 2026 : les reliques les plus mémorables sont CONTEXTUELLES à la stratégie (créent
le « lock-in »). **C'est la convergence #1 du round (la signature sous-spécifiée).**

**Décision (spec §4.11 + §8.1, 0 moteur, P1.5b)** :
```
4 RELIQUES POSITIONNELLES (sigil-aware, 0 moteur, lisent shapes[shape].edges + spec.id) — P1.5b :
  | Sigil cible        | Relique       | Effet                                                  |
  | Croix (mono-carry) | axis_pact     | Le carry central (2,2) gagne +30 % dmg et +50 % HP     |
  | Ligne (conduit)    | bloodline     | Unités en ligne directe (même colonne) partagent 10 % dps max |
  | Anneau (chaîne)    | ring_hunger   | Chaque unité donne +5 % affliction_inc à ses 2 voisins de l'anneau |
  | Diamant (go-wide)  | horde_pact    | Unités rang-1/2 gagnent +10 HP chacune                 |
  Satisfont le critère COURONNEURS (dimension PLACEMENT). NE PAS imposer de sigil (récompensent un engagement
    déjà pris = égalisateurs, pas gates, conforme relics-design §1). Grimdark : noms courts ancrés sur le Puits.
  Garde-fou saturation (Q4 relics) : vérifier que anneau+resonance_stone+ring_hunger ne passe pas DOT_CAP_MULT=3
    AVANT de graver resonance_stone ET ring_hunger dans la même vague.
```
**§4.11 + §8.1 enrichis.** Distinct des reliques G (qui MODIFIENT la topologie, P4) : une positionnelle
RÉCOMPENSE le sigil sans le changer = catégoriquement plus légère (0 moteur). Source : relics §2.5 ;
nat1gaming.com/sts2 (A-tier = contextuel) ; switchbladegaming.com/sts2 ; `shapes.lua` ; CLAUDE.md §2.

### 4.2 ADOPTÉ (PRIORITÉ HAUTE post-sim — DATA §4, 0 moteur) — Granularité intra-famille sur UNE relique B (`venom_covenant` poison) (relics §2.1)

**Critique (relics §2.1, `relics.lua:26-29` relu)** : les 4 reliques B sont architecturalement identiques
(`relic_affliction_inc`, seule la famille diffère). Un build poison-spread (`contagion`/propagation) et un
build poison-weaken (`bile_spitter`/`corruptor`) reçoivent EXACTEMENT la même `kings_bowl` (+20 % poisonInc)
avec le même effet — deux stratégies radicalement différentes traitées identiquement. StS Paper Phrog =
contre-exemple : amplifie le sous-build qui applique Vulnerable, pas tous les builds Silent.

**Pourquoi c'est valide** : le STYLE (spread vs weaken) est dérivable des triggers/ops des unités au
`combat_start` (compter `on_death`/`on_attacked` vs `on_hit` standard) = GRATUIT (0 moteur, lit `spec.effects`),
async-safe (effets dans le snapshot v1). Si le tableau de saturation P1 montre que `DOT_CAP_MULT=3` est atteint
avec B+aura+palier, une variante à périmètre PLUS ÉTROIT mais PLUS FORTE est le bon levier (tension intra-famille
sans casser le cap).

**Décision (data §4, UNE famille à la fois, après sim)** :
```
GRANULARITÉ INTRA-FAMILLE (test sur la famille DOMINANTE = poison) :
  kings_bowl (actuelle) : +20 % poisonInc — universel poison
  venom_covenant (nouvelle) : +15 % poisonInc PAR unité avec trigger on_death (spread-style)
                              OU +15 % si build a une unité weaken (weaken-style) [à trancher en sim]
  ~5 lignes data, 0 moteur (poisonInc déjà lu dans ampDps). NE PAS faire pour toutes les B simultanément :
    commencer par poison, mesurer offer_decision_quality, puis étendre (1 levier à la fois, balance-sim-design).
```
**§4 enrichi (ticket P1.5a post-sim).** Q2 relics (interaction avec `beggars_lantern` + dup rang-1) à mesurer.
Source : relics §2.1 ; `relics.lua:26-29` ; switchbladegaming.com/sts2 (Paper Phrog contextuel).

### 4.3 ADOPTÉ (PRIORITÉ HAUTE — DATA §4.6, 1 ligne) — Re-tier `carrion_ledger` (tier 3 → 2) (relics §2.2)

**Critique (relics §2.2, `relics.lua:64-66` + cotes `00-state §4.3` relus)** : le tier-gating des F est basé
sur le NUMÉRO DE TIER, pas sur la VALEUR ATTENDUE par phase. `carrion_ledger` (tier 3) donne +6 XP de boutique
= valeur MAXIMALE en EARLY (shopTier 1→2 = 2 XP ; +6 XP BYPASS le 1er palier entier). En tier-3, elle
n'apparaît qu'au round 2-3 → son meilleur usage est manqué = ANTI-OPTIMAL depuis le code. StS2 (mobalytics) :
« the relics that matter most in Act 1 function IMMEDIATELY ».

**Pourquoi c'est valide** : la valeur d'une relique dépend de QUAND on la reçoit autant que de son effet. Le
gating doit aligner VALEUR PAR PHASE avec DISPONIBILITÉ PAR PHASE.

**Décision (data §4.6, 1 ligne)** : `carrion_ledger` tier 3 → 2 (disponible dès early). `beggars_lantern` reste
tier 2 MAIS + garantie de pertinence (≥2 même id du build au `rollRelicChoices`). `black_summons` reste tier 4
(spike-mid juste). **§4.6 enrichi.** Golden-safe (F = `runOp`, pas de combat ; vérifier invariants #18-21).
Source : relics §2.2 ; `relics.lua:64-66` ; mobalytics.gg/slay-the-spire-2.

### 4.4 ADOPTÉ (PRIORITÉ 1 BLOQUANTE pour P1.5a — DOC §4.10) — Décider `hollow_choir` : RÉORIENTÉE, pas retirée (relics §2.4)

**Critique (relics §2.4)** : `hollow_choir` (`pierceHeal=0.40`) est correctement identifiée comme
contre-archétype inexistant (regen = 1 unité) → pool-A. Mais le brouillon prévoit la réorienter en `pierceShield`
(§4.10) en P1.5b. **Si retirée de `U.pool` sans décision de réorientation, elle risque d'être oubliée puis
re-ajoutée = double travail.**

**Pourquoi c'est valide** : la réorientation `pierceHeal → pierceShield` est une opération DATA (+ ~3 lignes SIM
dans le gate `Arena:damage`, déjà doté de `ignoreShield`). Retirer maintenant (pool-A) est correct, mais la
décision de réorienter doit être gravée AVANT P1.5a pour éviter le retrait définitif par inertie.

**Décision (doc §4.10)** : graver explicitement que `hollow_choir` est **RÉORIENTÉE (`pierceShield`) en P1.5b**,
PAS retirée définitivement. La retirer de `U.pool` maintenant (pool-A) reste correct (regen counter inexistant) ;
la décision de réorienter est consignée. **§4.10 corrigé (décision explicite).** Source : relics §2.4 ;
`relics.lua:37-38` ; `arena.lua:432` (gate bouclier).

### 4.5 NUANCÉ (relics §1.2/§2.3/§2.6) — accords avec précisions, pas adoptions structurelles

- **§1.2 (signal visuel A vs B/C/E)** : ADOPTÉ FAIBLE — glyphe grimdark discret sur les A (« socle ») vs B/C/E
  (« rune »), pas le mot « commun/rare » (casse le DA). RENDER ~30 min, 0 SIM, aligné §2.6 (audit ≤12 mots).
- **§2.3 (`second_breath` universelle vs `sacred_shield` situationnelle)** : NUANCÉ — la critique (combats longs
  `HP_MULT=2` → `sacred_shield invulnT=30` ≈ 1-2 attaques = quasi-inerte) est code-correcte et **déjà actée**
  (§4.9 : `sacred_shield [PH] à régler`). L'enrichissement proposé (invulnT=30 + shield=10) est une option de
  tuning valide → l'ajouter aux candidats §4.9, pas une refonte.
- **§2.6 (`thornguard` D mais joue C)** : ADOPTÉ FAIBLE (doc) — les épines récompensent l'EXPOSITION (payoff
  conditionnel = rôle C), pas une réduction de dégâts (rôle D). Reclassifier en C dans `relics-design.md` +
  tier 2 → 3 (mid/late, build assez populate). 1 ligne data, 0 moteur.

---

## 5. Adoptions — RÉTENTION (high-roll séquentiel + Grimoire calibré)

### 5.1 ADOPTÉ (PRIORITÉ 1 — SPEC §2.4/§2.3, 0 code now) — Activation SÉQUENTIELLE des événements bus (rétention §2.1/Prop-A)

**Critique (rétention §2.1, Blake Crosley + CHI 2025 Kao n=1699)** : le high-roll (Moment du Run, VRR boutique)
est traité comme une PROBABILITÉ (enveloppe pondérée hédonique). Mais Balatro — la masterclass de référence
citée par la roadmap — produit le high-roll par un mécanisme DISTINCT : chaque élément de score s'active
SÉQUENTIELLEMENT avec callout visuel (« 30 ms par Joker → attribution causale par l'animation, remplace un
tutoriel de 10 pages par 300 ms d'animation »). CHI 2025 confirme : l'amplification (volume) SANS
success-dependency ne produit PAS l'engagement équivalent. La roadmap copie le RÉSULTAT de Balatro sans son
MÉCANISME.

**Pourquoi c'est valide ET distinct des métriques existantes** : ce n'est PAS `combat_effect_legibility`
(densité d'événements) — c'est la TEMPORALITÉ DE L'AFFICHAGE (séquentiel vs simultané), indépendante de la
densité. Le bus JSONL émet déjà source/cause/target/tick → toutes les données sont là. Sans cette spec, l'impl
par défaut = VFX simultanés (bruit) ; le high-roll sera invisible même si les effets sont là.

**Décision (spec §2.4 + §2.3, RENDER ~2-3 h en implémentation, 0 code maintenant)** :
```
SPEC SÉQUENTIELLE DU MOMENT DU RUN (§2.4) :
  La chaîne d'événements (bus JSONL) est affichée nœud par nœud, délai 80-120ms entre chaque, accélération
  Balatro sur les 5+ derniers nœuds (100→60→40ms) pour préserver la cascade (12 nœuds × 100ms = 1200ms trop long).
  Chaque nœud : [ICONE_FAMILLE] [SOURCE] → [ACTION] → [CIBLE]. Total : [N morts en chaîne].
CONNEXION §2.3 : si la chaîne la plus longue >= 3 nœuds, le Moment du Run EST la synthèse post-combat.
  Priorité étendue : Moment du Run (seq. ≥3) > §2.10 (relief survie) > post-mortem diagnostic.
```
**§2.4 + §2.3 enrichis.** Q_R10_1 (cadence exacte du délai) → à valider en playtest, non sim. Zone sans test →
test que la chaîne la plus longue sur le golden est identifiée (`tools/eventlog.lua` déjà câblé). Source :
rétention §2.1 ; blakecrosley.com/balatro ; CHI 2025 (Kao, n=1699) ; bus.lua.

### 5.2 ADOPTÉ (PRIORITÉ 1 — CALENDRIER §9) — Grimoire MINIMAL avancé à v0.9.3 (// P0.5) (rétention §2.3/Prop-D)

**Critique (rétention §2.3, Åslund 2026 DIVA)** : le calendrier place le Grimoire 3-chapitres en v0.11 (ranked).
Pendant v0.9-v0.9.5 (P0, P0.5), les runs 1-5 sont joués SANS méta-progression visible. Åslund 2026 : la
méta-progression LÉGÈRE (comme la nôtre) requiert PLUS de temps pour « devenir claire » → le hook est plus
tardif. Attendre v0.11 laisse la fenêtre la plus critique (runs 1-5) sans ancre méta-progressif.

**Pourquoi c'est valide** : le P0 (lisibilité) est la vraie précondition (confirmé) — mais un Grimoire minimal
(Chapitre I : reliques + silhouettes des 21) dès le 1er run donne le hook sans attendre le Grimoire complet.
Le joueur qui finit son 1er run et voit « 3/21 reliques du Puits » a un ancre immédiat.

**Décision (calendrier §9, v0.9.3 // P0.5, ~2 h RENDER)** :
```
GRIMOIRE MINIMAL (v0.9.3, // P0.5) : Chapitre I SEUL (reliques découvertes/vues + silhouettes des non-découvertes,
  21 total). Affichage [NOM] • [EFFET COURT] • [FLAVOR]. AUCUNE mécanique (lit grimoire.lua déjà câblé). 0 SIM.
GRIMOIRE COMPLET (v0.11) : Chapitre II (segmenté par famille, §5.3) + III (sigils) + badges MAÎTRE/PRATICIEN.
```
**§9 calendrier corrigé (Grimoire minimal en v0.9.3).** Q_R10_2 (montrer les reliques VUES en boutique ou
seulement acquises ?) → recommandation : VUE = silhouette + nom ; ACQUISE = + effet (modèle StS ; leurres
retirés § décision-jeu simplifient). Source : rétention §2.3 ; Åslund 2026 (DIVA).

### 5.3 ADOPTÉ (PRIORITÉ 2 — RENDER §6.7, ~1 h) — Grimoire Chapitre II segmenté par famille (seuil 40 % en 2-3 runs) (rétention §2.2/Prop-B)

**Critique (rétention §2.2, Yu-Kai Chou CD4 : seuil de bascule empirique 40-60 %)** : sous 40 % de complétion,
une collection est « bruit de fond » (pas d'urgence d'engagement, même si l'Ovsiankina est présent). Calcul : le
Chapitre II (83 unités totales) — un joueur mono-famille voit ~5 unités/run et son archétype en priorité → peut
ne voir que 15 des 83 sur 5 runs = 18 % → reste « bruit de fond » pendant toute la phase early. **C'est la
variante la plus probable pour un joueur engagé (il optimise son achat) — exactement le joueur le plus
susceptible de churner sans hook.**

**Pourquoi le synthétiseur ADOPTE (en notant le chevauchement avec l'existant)** : le §6.7 prévoit DÉJÀ le
Chapitre II « segmenté par famille » (round 6) — mais R10 ajoute le RATIONNEL du seuil 40 % + le diagnostic
mono-famille (le segment passe vite, mais SEULEMENT pour la famille jouée). La segmentation par section
(« 4/13 essences BURN — 31 % ») rend l'Ovsiankina personnalisé à l'archétype : chaque famille passe le seuil
40 % en ~2-3 runs si le joueur la joue.

**Décision (RENDER §6.7, ~1 h, dépend de P0.5)** :
```
GRIMOIRE CHAPITRE II — SOUS-INDEX PAR FAMILLE (renforce le "segmenté par famille" §6.7) :
  [SECTION BURN] 4/13 essences (31 %) ████░░░░ → silhouettes des manquantes
  [SECTION BLEED] 7/13 (54 %) ████████░ ← SEUIL 40 % FRANCHI (urgence visible)
  Chaque famille passe 40 % en ~2-3 runs si jouée → Ovsiankina personnalisé à l'archétype, pas à la collection
  totale. Q_R10_3 (FOMO de famille) : sections NON jouées = taille réduite, pas de silhouettes (compteur discret
  seul) → l'Ovsiankina se déclenche sur la section ACTIVE, pas de FOMO inter-familles.
```
**§6.7 enrichi (rationnel 40 % + sous-index par famille).** Dépend de P0.5 (`dot_family`) — à coder EN MÊME
TEMPS que P0.5. Source : rétention §2.2 ; yukaichou.com/collection-set-design-cd4 ; Åslund 2026.

### 5.4 ADOPTÉ (PRIORITÉ 3 — DOC §2.3, RENDER) — Near-miss reformulé comme hypothèse testable + hint opt-in (rétention §2.4 + ranked §2.3)

**Critique convergente (rétention §2.4 + ranked §2.3, Grid Sage 2025 + stat.berkeley near-miss type 1/2)** :
le near-miss async est de TYPE 1 (sous agence rétrospective — AMPLIFIÉ par le déterminisme), MAIS le joueur ne
le perçoit comme tel que si le post-combat montre la CAUSALITÉ, pas seulement le diagnostic. Le §2.3 actuel est
diagnostique (« exposé front ») mais non prescriptif. Le format ranked propose une hypothèse testable
(« [UNITÉ] a cédé au round N face à [FAMILLE] — essaie [UNITÉ ANTI-X] »).

**Pourquoi c'est valide (0 moteur supplémentaire)** : l'event-log JSONL capture source/cause de la mort ; la
famille dominante de l'adversaire est connue (snapshot servi) ; le profil des unités par famille est dans
`units.lua`. La reformulation est une lecture de données existantes. Grid Sage 2025 : le feedback actionnable
est le moteur de mastery (les experts rejettent les hints prescriptifs → opt-in).

**Décision (doc §2.3, RENDER, 0 SIM)** :
```
(a) NEAR-MISS COMME HYPOTHÈSE (victoires >= WIN_TARGET-2 ET défaite au round N>5) :
  "[UNITÉ] A CÉDÉ AU ROUND N — FAMILLE DOMINANTE : [FAM] — ESSAIE [UNITÉ_ANTI_FAM] ([sa mécanique en 3 mots])"
  Logique RENDER : unité morte en dernier + famille la plus représentée dans les stacks DoT à la mort (event-log)
    + 1 unité anti-fam (table statique units.lua). CONTRAINTE : JAMAIS prescrire une unité absente du pool boutique
    actuel (sinon frustration) → suggestion de la famille adverse OU type "shield" si famille non reconnue.
  Grimdark : "Le Puits révèle sa faille." Zone sans test → ne crash pas si event-log vide.
(b) HINT OPT-IN (settings.near_miss_hint, off par défaut, runs 1-3 OU loss-streak >= 2) :
  ligne prescriptive "un taunt en avant-gauche aurait absorbé l'attaque initiale" (si 1ère mort front ET aggro<15
  ET aucun taunt même colonne → inférer). Respecte l'autonomie des experts (SDT). ~30 min RENDER.
```
**§2.3 enrichi.** Source : rétention §2.4 ; ranked §2.3 ; gridsagegames.com 2025 ; stat.berkeley.edu/near_miss ;
armchairarcade 2026 (Balatro : « each run teaches something new »).

### 5.5 CONFIRMÉ + Q RE-QUALIFIÉE (rétention §1, §4-§6) — accords définitifs + gate §2.10

Réforme #JJ (§1.1) ; hiérarchie near-miss PRIMAIRE/identité SECONDAIRE (§1.2, confirmé Polygon 2025
Dr. Lichtman = confirmation médicale indépendante) ; §2.10 reformulé agence + bloqué CONFIG-SURVIVAL (§1.3) ;
Peak-End Rule double niveau (§1.5) ; enveloppe VRR pondérée (§5.1, avec la nuance : ASSUME l'affichage
séquentiel §5.1 en place, sinon poids surestimés) ; absence de monétisation compulsive comme renforcement de
rétention (§5.4, garde-fou éthique sourcé). **REJETS maintenus** : score preview ex-ante (GMTK 2024 : LocalThunk
l'a refusé délibérément) ; Grimoire adaptatif (détruit le mystère, Yu-Kai Chou) ; Grimoire live win-rate (< 30
runs = bruit). **Q_R10_4 / Q_R9_2 RE-QUALIFIÉE BLOQUANTE** : gate §2.10 sur `ghost_is_human == true` — en bêta
(majorité IA), un signal §2.10 non-gaté est banal dès le round 1. **Décision éditoriale user requise avant le
code §2.10** (cf. §8 litiges).

---

## 6. Adoptions — PROGRESSION & ÉCONOMIE (plafond passif + sources corrigées)

### 6.1 ADOPTÉ (PRIORITÉ 0 — DOC §7.0, 15 min) — Table du plafond naturel de la passive avant `--xp-climax` (progression §2.1/§3.5)

**Critique (progression §2.1, `00-state §4.1-4.3` + calcul direct)** : la courbe `{2,5,10,18}` est calibrée pour
un comportement acheteur hypothétique, mais le PLAFOND NATUREL de la passive (1/round) n'est jamais calculé — et
personne ne pose si la courbe est COHÉRENTE avec ce plafond. Calcul : run 10 rd = 9 XP passive (T3, jamais T4) ;
run 19 rd = 18 XP (T5 passif à R19, juste à la fin). **Sur run long 17-19 rd, T5 passif élimine la tension
finale.**

**Pourquoi c'est valide** : 5 lignes arithmétiques par courbe candidate prédisent si la sim va valider/invalider
chaque courbe SANS la lancer. Évite une itération sim si la courbe est déjà incohérente avec l'intention déclarée.

**Décision (doc §7.0/eco-decisions.md, AVANT `--xp-climax`)** :
```
TABLE DU PLAFOND PASSIF (par courbe candidate, policy = 0 BUY_XP, passive dès round 2) :
  {2,5,10,18} : T2=R3 / T3=R6 / T4=R12 (OK run médian) / T5=R19 (juste à la fin run long → risque tension finale)
  {2,5,10,20} : T5=R21 (jamais passivement sur un run normal → T5 toujours actif, plus propre pour [A])
  → prédit le verdict de --xp-climax sans le lancer. Croisé avec la 6e métrique passive_vs_bought_ratio.
```
**§7.0 enrichi.** Source : progression §2.1 ; `00-state §4.1-4.3` ; calcul direct.

### 6.2 ADOPTÉ (PRIORITÉ 1 — RENDER §2.5bis, ~1 h) — Signal slot-unlock intégrant l'HORIZON DE RUN (progression §2.2)

**Critique (progression §2.2)** : le signal slot-unlock adopté R09 (`"espace pour {9 − slots} unités"`) mesure
le potentiel TOTAL restant, pas la valeur MARGINALE du slot MAINTENANT. `9 − slots` est identique au round 2 et
au round 7 — mais un slot au round 2 (8 rounds d'usage) ≠ un slot au round 7 (3 rounds). Le signal ne distingue
pas les deux. Un slot refusé tard est souvent un or inutile (le run finit avant de le dépenser).

**Pourquoi c'est valide** : en async, l'horizon de run est une info que le joueur n'a pas toujours en tête. La
valeur marginale = combats restants × valeur d'une unité de plus. `rounds_remaining_est = (WIN_TARGET − wins) +
lives − 1` (borne haute) est accessible hors SIM dans `build.lua`.

**Décision (RENDER ~1 h, remplace le signal R09 §2.5bis volet slot)** :
```
SIGNAL SLOT-UNLOCK avec HORIZON (corrige le (9−slots) de R09) :
  rounds_remaining_est = max(0, (WIN_TARGET − wins) + lives − 1)  -- borne haute, hors SIM
  early (slots<5, horizon>5) → "Un slot = {rounds_remaining_est} combats à venir — ou {SLOT_DECLINE_GOLD} or maintenant"
  late (horizon<=5) → "Refuser = {SLOT_DECLINE_GOLD} or ({ceil(SLOT_DECLINE_GOLD/BUY_XP_COST*BUY_XP_AMOUNT)} XP) — ~{horizon} combats"
  Grimdark : "Le Puits t'offre l'espace — ou son prix. Il ne restera pas longtemps." (tilde = approximation assumée)
```
**§2.5bis corrigé (volet slot).** Précondition : `WIN_TARGET`/`START_LIVES` accessibles depuis `build.lua`. Zone
sans test → cas limites (`wins=0/lives=5` ; `wins=9/lives=1`). Source : progression §2.2 ; gamedeveloper.com 2013.

### 6.3 ADOPTÉ (PRIORITÉ 1 — DOC §7.0) — Remplacer Amabile & Kramer par l'Endowed Progress Effect pour le rôle [B] (progression §2.3)

**Critique (progression §2.3, Nunes & Drèze 2006 vs Amabile & Kramer 2011)** : la passive comme « rituel [B] »
est sourcée sur Amabile & Kramer — une étude de motivation au TRAVAIL signifiant (238 personnes en entreprise),
pas du jeu. Le mécanisme n'est PAS le même : dans The Pit, +1 XP passif est un chiffre invisible jusqu'à
l'ouverture de boutique, et le joueur n'a aucune action pour le déclencher. Or Amabile & Kramer précisent que le
progrès motivant est celui PERÇU comme résultat de l'effort du soi. Un fait passif génère de l'ATTENTE, pas du
progrès.

**Pourquoi c'est valide** : l'Endowed Progress Effect (Nunes & Drèze 2006, JCR) est la source correcte —
l'avantage initial accélère la complétion SI perçu comme un avantage. **Avec précondition de framing** : la
passive doit être présentée comme un DON (« LE PUITS T'ACCORDE SA MARQUE — un XP en silence chaque round »),
pas comme un fait du temps. Si le framing est absent, [B] génère de la frustration (attente), pas de la
motivation.

**Décision (doc §7.0, remplace la référence Amabile & Kramer ligne `XP_PASSIVE_RATE`)** :
```
XP_PASSIVE_RATE | 1/round | INTENTION [A] ou [B] (user) :
  [A] Levier : passive_vs_bought_ratio cible 20-50 %. 1/round sur 15 rd = 13 XP (T4 ~R13) ; T5 exclusivement actif.
  [B] Rituel perçu comme DON ACTIF (Endowed Progress Effect, Nunes & Drèze 2006) :
      → PRÉCONDITION : le signal §2.5bis frame la passive comme un DON grimdark (« LE PUITS T'ACCORDE SA MARQUE »),
        PAS un fait du temps. Sans ce framing, [B] = attente (frustration), pas progrès.
      → ratio attendu 15-25 % ; NE PAS ajuster la passive si <20 % (voulu si [B]) ; ajuster le SIGNAL si <15 %.
  Amabile & Kramer 2011 (travail signifiant) RETIRÉE — non transférable sans condition de framing.
```
**§7.0 corrigé (source [B] = Nunes & Drèze, framing).** Source : progression §2.3 ; Nunes & Drèze 2006 (JCR) ;
Csikszentmihalyi 1990 (Flow).

### 6.4 ADOPTÉ (PRIORITÉ 1 — DOC §7.1 condition 4) — Hiérarchie de remèdes à la co-calibration (progression §2.4)

**Critique (progression §2.4, `00-state §4.1-4.3`)** : la condition 4 (`ratio = shopTier/slots > 1.5`) détecte
le déséquilibre mais ne prescrit AUCUN remède en sim — « calibrer ensemble OU limiter le rush » ont des
implications radicalement différentes (option B exigerait un coût variable dynamique, hors spec `state.lua`).
Sans critère de sélection AVANT la sim, la condition 4 est une **détection sans résolution** — exactement ce que
le tableau §7.0 doit éviter.

**Décision (doc §7.1 condition 4)** :
```
Si ratio > 1.5 en rush_XP (ET <= 1.5 en standard) :
  Remède 1 [sans code, // P0] : vérifier si les signaux §2.5bis + slot-unlock (§6.2) suffisent à réduire le ratio
    (comportement informé vs aveugle — la différence peut être le signal, pas la mécanique).
  Remède 2 [data] : BUY_XP_COST T1 → 5g (ralentit le rush sans bloquer ; retest condition 4 + --xp-climax).
  Remède 3 [mesure] : exclure rush_XP de la co-calibration (si le problème est propre à la politique extreme).
  Ordre STRICT : R1 avant R2 avant R3 (ne pas complexifier avant de mesurer si R1 suffit).
```
**§7.1 condition 4 enrichi.** Source : progression §2.4 ; `00-state §4.1-4.3`.

### 6.5 CONFIRMÉ NON-DÉSACCORD (progression §1, §5) — accords éco définitifs

Or fixe 10/round (10e confirmation — **peut passer en historique**) ; structure XP passive+achetable ratio 4:1
(à calibrer avec le plafond passif §6.1) ; barre XP §2.5bis + signal contextuel ; tableau §7.0 en précondition ;
3 régimes de tension + seuils corrigés R09 ; co-calibration condition 4 (+ remèdes §6.4) ; `REROLL_COST` tranché
par sim (+ signal d'alarme). **Tous maintenus.** Q1 progression (dérive 1:5 reroll PERÇUE ?) + Q (intention
`REROLL_COST=1` en T5 VOULU/NON ?) → trancher dans §7.0 comme INTENTION (pas TBD) pour ne pas passer P3 à
chercher un choix non distingué.

---

## 7. Rejets et nuances (avec raison mécaniste)

### 7.1 REJETÉ — L'angle « concede semi-déterministe » comme justificatif PREMIER de #LL (ranked §2.1)

**Ce qui est rejeté** : que le RNG de run seedé rende le concede meta exploitable à court terme (le joueur
apprendrait à lire `rng_state` pour identifier les R1 favorables). **Raison** : c'est spéculatif pour une bêta
(le joueur ne voit `rng_state` qu'en debug, pas en jeu normal) et SAP (RNG non lisible) ne l'a pas. **Ce qui est
adopté de la même critique** : le mécanisme CORE (run avorté avant `startCombat` = pas de ghost = pool biaisé)
est valide et le remède §2.1 est cheap. On adopte le fix sur la justification POOL, pas sur l'angle déterministe.

### 7.2 NUANCÉ — « La méta-progression légère du Grimoire est sans risque » (rétention §2.3)

**Ce qui est nuancé** : la critique présente la légèreté comme potentiellement risquée (hook tardif, Åslund
2026). **Raison de la nuance** : ce n'est PAS un désaccord — la critique REFORCE la logique P0-précondition déjà
actée (« si le run 1-2 est confus, le Grimoire ne sauve pas »). **Ce qui est adopté** : le Grimoire minimal
avancé à v0.9.3 (§5.2) répond exactement à ce risque sans changer la priorité de P0. Confirmation, pas refonte.

### 7.3 REJETÉ — Implémenter Cinder matchmaking (distribution de skill) (ranked §4.3)

**Ce qui est rejeté** : remplacer le `slot_tier_composite` (proxy uni-dimensionnel) par une comparaison de
distributions de skill (Cinder, arxiv 2602.17015). **Raison** : over-engineering pour un pool de 200 snapshots
(la lentille ranked le reconnaît elle-même). **Ce qui est adopté** : DOCUMENTER que `slot_tier_composite` est un
PROXY (pas une mesure de skill) dans §6.4, et que des améliorations futures (ratio wins/runs dans le snapshot)
renforceraient l'équité. Doc, pas implémentation.

### 7.4 NUANCÉ — Le seuil 40 % de Yu-Kai Chou comme « loi » (rétention §2.2)

**Ce qui est nuancé** : le seuil 40-60 % est présenté comme empirique fort. **Raison de la nuance** : c'est une
heuristique de game design (Yu-Kai Chou, observation), pas une loi mesurée pour notre contexte spécifique —
comme le NN/g « 3-5 éléments » (nuancé R09). **Ce qui est adopté quand même** : la segmentation par famille
(§5.3) est utile INDÉPENDAMMENT du seuil exact (un segment de 13 unités est un goal-gradient plus motivant que
83) — on documente le seuil comme heuristique, pas comme loi.

### 7.5 CONFIRMÉ NON-DÉSACCORD — la cadence 5 sem. n'est pas un retour aux saisons longues

Le passage 3→5 sem. (§2.2) reste dans la fourchette « courte » (GamineAI 6-12 sem. = leur PLANCHER) et
préserve l'escalade par contenu (P3+ = 6-8 sem., P4+ = 8-10 sem.). Ce n'est pas un abandon du Fresh Start court
— c'est une correction d'un benchmark mal transféré (Bazaar mondial ≠ FIFO local).

---

## 8. Litiges — état après R10 (FINAL)

| # | Litige | Statut R10 |
|---|---|---|
| **#LL** | **NEUF** — ancre snapshot ranked (premier achat vs round 2 vs startCombat) | Ouvert ; recommandation = les deux (OR), §2.1. **Prérequis P2, AVANT code ranked.** |
| **#HH** | palier choc-4 | **CLOS** (§3.1) : Option B (`tickCount=2`), aligné #JJ, compatible avec les 2 axes → **découple #GG**. |
| **#II** | directionnalité #FF | **CLOS recommandé** (§3.4) : Option B (symétrique), favorisée #JJ. Décision user (rebaseline golden). |
| **#GG** | apex choc axe A/B vs D | **Maintenu BLOQUANT** mais **DÉCOUPLÉ de #HH** (§3.1). Enrichi : apex = NOUVELLE unité rang-5 choc (non skull_colossus, §1.1). À trancher avant P1. |
| **#Y** | FIFO ranked au reset de saison | **RÉ-OUVERT** (§2.5) : #LL (capture au premier achat) accélère la grâce 7 j → re-trancher en P2 après mesure de densité. |
| **Q_R10_4 / #Q_R9_2** | gate §2.10 sur `ghost_is_human` | **RE-QUALIFIÉ BLOQUANT** (§5.5) : majorité IA en bêta → signal non-gaté banal. Décision éditoriale user avant code §2.10. |
| **#U** | Contrainte de Saison : critère | **Re-qualifié R09** (axe résolu + écart potentiel/réel). Reste ouvert (choix précis post-P0.5/P3). |
| **#J** | plague_communion ancrage | **RE-TRANCHÉ R09** (`dot_family_count ≥ 2` du joueur, #JJ). Maintenu. |
| **#A** | P1 types vs P2 ranked | Maintenu (exclure ranked teamFlag + daily-contrainte de `--meta-convergence`). |
| **#B** | inc saturation | Maintenu (+ resonance/#FF/positionnelles y entrent ; tableau saturation `inc` + ARÊTES §3.3). |
| **#X** | relique contre-jeu méta | Maintenu (`hollow_choir → pierceShield` P1.5b, décision §4.4). |
| **#M** | relique wide quantité vs arête | Maintenu (P1.5b/P4 ; lié aux positionnelles §4.1). |
| **#V** | snapshot schema version | Maintenu (re-lié #Y, ré-ouvert). |
| **#AA** | VRR boutique + pondération hédonique | Maintenu (calibration P3 ; ASSUME affichage séquentiel §5.1). |
| **#CC** | wither_bloom critère | Maintenu (critère documenté, code P1.5b). |

**NEUFS R10** : **#LL** (ancre snapshot ranked — intégrité du concede).
**CLOS R10 par preuve** : **#HH** (palier choc-4 = Option B via #JJ) ; **#II** (directionnalité #FF = Option B
via #JJ, recommandé à décision user). **RÉ-OUVERT** : **#Y** (impact de #LL). **RE-QUALIFIÉ** : **Q_R9_2** (gate
§2.10 → bloquant). **DÉCOUPLÉ** : **#GG** de **#HH**.
**Q OUVERTES (playtest/user, non litiges de sim)** : Q_R10_1 (cadence animation séquentielle, playtest) ;
Q_R10_3 (FOMO famille, résolu doc : sections réduites) ; Q1 progression (dérive reroll perçue) ; intention
`REROLL_COST=1` T5 (VOULU/NON, §7.0).

---

## 9. Ce qui s'est amélioré ce round (mesurable)

1. **Une proposition DA-invalide de 3 rounds corrigée par relecture code** : `skull_colossus → apex choc` est
   thématiquement incohérent (`type="bone", family="crane"` ≠ électricité, décision #3). Remplacé par une
   NOUVELLE unité rang-5 choc `type=arcane/abyss`. **Le « 0 moteur » du recyclage était une analogie mécanique
   paresseuse** que le BRIEF interdit explicitement. + le diagnostic « carry burn » corrigé (DPS_frappe mélée vs
   burn_dps=4 réel, sous le rang-1) via l'audit à 3 colonnes E1/E2/E3.

2. **Une faille d'intégrité async silencieuse identifiée et spécifiée (#LL)** : le « concede meta » (capture
   seulement à `startCombat`) est documenté avec preuve externe (Steam Bazaar août 2025 : « kinda HAVE TO
   concede to win »), mécanisme précisé pour notre pool FIFO local, fix proposé (~5 lignes IO). Ce bug n'était
   pas dans la roadmap en 9 rounds.

3. **Deux litiges clos par le critère #JJ (preuve mécaniste)** : #HH (palier choc-4 = Option B `tickCount=2`,
   cause contrôlée par le build → découple #GG) ; #II (directionnalité #FF = Option B symétrique). Le garde-fou
   #JJ adopté R09 devient un OUTIL DE CLÔTURE, pas seulement un principe.

4. **La SIGNATURE du jeu (le plateau-graphe) enfin spécifiée dans les reliques ET les synergies** : 4 reliques
   positionnelles sigil-aware (0 moteur, snapshotables) comblent un trou de catégorie entière ; le tableau de
   saturation des ARÊTES (jamais mesuré en 10 rounds) devient une précondition de P1 au même titre que la
   saturation `inc`.

5. **Le high-roll re-cadré comme FEEDBACK SÉQUENTIEL, pas probabilité** : la roadmap copiait le RÉSULTAT de
   Balatro (high-roll mémorable) sans son MÉCANISME (activation séquentielle causalement explicite). Spec
   séquentielle ajoutée à §2.4 (0 SIM, le bus JSONL a déjà source/cause/tick). Ancré Blake Crosley + CHI 2025
   (n=1699 : amplification sans success-dependency ≠ engagement équivalent).

6. **La cadence de saison corrigée (3 → 5 sem.)** : Milkman 2014 démontée (landmark naturel ≠ reset arbitraire),
   Bazaar mensuel démonté (pool mondial ≠ FIFO 200 local), maths propres (10-15 runs/saison = 1 tier + temps de
   régénération du pool). Une valeur héritée faiblement fondée remplacée par un raisonnement mécaniste.

7. **Le Grimoire calibré sur la psychologie de collection** : minimal avancé à v0.9.3 (hook dans la fenêtre
   critique runs 1-5, Åslund 2026) ; Chapitre II segmenté par famille avec le rationnel du seuil 40 %
   (Yu-Kai Chou) — le joueur mono-famille passe le seuil en 2-3 runs au lieu de 5-7.

8. **Deux sources de progression corrigées** : Amabile & Kramer (travail) → Endowed Progress Effect (Nunes &
   Drèze 2006, avec précondition de framing) pour le rôle [B] de la passive ; + table du plafond naturel de la
   passive (prédit le verdict de `--xp-climax` sans le lancer) + hiérarchie de remèdes à la condition 4 (ferme
   « détection sans résolution »).

9. **Sources nouvelles et directement pertinentes** : Steam Bazaar (concede meta), Blake Crosley + CHI 2025
   (feedback séquentiel), Yu-Kai Chou CD4 (seuil 40 %), Åslund 2026 DIVA (méta-progression légère), GamineAI 2026
   (cadence saison), Nunes & Drèze 2006 (Endowed Progress), Kritz & Gaina 2025 (saturation positionnelle), PoE
   Lightning Exposure (auto-conditionnel), nat1gaming/StS2 (reliques contextuelles).

---

*Round 10 synthétisé le 2026-06-23 (FINAL). Méthode (rounds 4-10) : claims de code/constantes revérifiés avant
arbitrage ; une affirmation « code-vérifiée » reste contestable ; un litige ne se clôt que sur preuve (jamais sur
consensus mou) ; un litige nuancé reste ouvert tant qu'une preuve neuve peut le trancher. Adoptions =
data/doc/sim/RENDER/IO/config ou décision éditoriale — 0 invariant, 0 modification du code du jeu ni des tests.
Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim
déterministe seedée / DA grimdark / pixel art procédural). 32 invariants préservés. 1 litige neuf (#LL) ; 2 clos
par preuve via #JJ (#HH, #II) ; #Y ré-ouvert ; Q_R9_2 re-qualifiée bloquante ; #GG découplé de #HH. Une
proposition DA-invalide corrigée (skull_colossus apex choc). DESTINÉ À PRODUIRE LA ROADMAP INTÉGRÉE v11.*
