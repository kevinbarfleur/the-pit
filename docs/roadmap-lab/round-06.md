# Round 06 — Synthèse adversariale (6 lentilles)

> **Rôle** : synthétiseur, round 6/10 du roadmap-lab. Intègre **de façon critique** les 6 critiques
> `rounds/r06-*.md` contre le brouillon v6 (`ROADMAP-draft.md`). Adopte les critiques **valides et
> sourcées**, rejette les faibles (en disant pourquoi), consigne les **vrais litiges** pour le round 7.
> C'est un **débat, pas une addition**.
>
> **Méthode (round 4-5, maintenue)** : reformuler/corriger un mécanisme existant = **citer la ligne de
> code relue ce round**. Le synthétiseur a **revérifié 1 claim code load-bearing** (ci-dessous, §0) —
> pas hérité : l'unité de `invulnT` (`sacred_shield`), qui tranche la Prop-E relics.
>
> **Ancrage** : `00-state.md` (32 invariants), `BRIEF.md`, `round-0{1..5}.md`, les 6 `r06-*.md`,
> les 10 teardowns `competitive/*`. **Garde-fou absolu** : lecture seule du repo ; n'édite que sous
> `docs/roadmap-lab/`. Piliers : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.

---

## 0. Vérification de code menée par le synthétiseur (avant d'arbitrer)

La critique relics §2.5/Prop-E reposait sur une **incertitude d'unité** (`invulnT` en ticks ou en
secondes) qu'elle demandait de lever par grep. **Le synthétiseur l'a fait** (lecture seule) :

- **`sacred_shield` pose `invulnT=30`** (`relics.lua:46`, relu) via `grant_team` à `combat_start`.
- **La garde** (`arena.lua:247`, relu) : `if itf and itf.invulnT and self.t < itf.invulnT then return 0 end`
  — l'équipe ne subit rien tant que `self.t < invulnT`.
- **`self.t` est en TICKS @ 60 fps** : `FATIGUE_START = 1020 -- ~17 s @ 60 fps (1 tick = 1/60 s)`
  (`arena.lua:58`, relu) ; `self.t` est incrémenté du compteur de tick de la boucle pas-fixe.

→ **`invulnT=30` = 30 ticks = 0,5 s d'invulnérabilité d'ouverture** = **~2,9 % d'un combat de 17 s**.
**La critique relics §2.5 est EXACTE et code-vérifiée** : `sacred_shield` est **fonctionnellement
quasi-inerte** (une unité rang-1 ne peut pas frapper dans les 30 premiers ticks ; seuls quelques ticks
de DoT d'ouverture sont bloqués). → **ADOPTÉ** : `sacred_shield` reçoit un `[PH]` explicite (cible
60-120 ticks = 1-2 s pour être visible), pas un bug de signe (l'unité EST bien en ticks). Pas de
relique brisée ; une relique **inerte** à régler. C'est la **4e relique** à ré-évaluer côté valeur
(après les 3 F déjà dépriorisées et `hollow_choir` ce round).

**Conclusion de méthode** : la règle « grep avant d'affirmer » continue de payer — elle a transformé
une incertitude (« inerte OU brisée ? ») en **décision tranchée** (inerte, valeur à régler) en 1 grep.

---

## 1. Ce qui CHANGE dans la roadmap (adopté, avec le POURQUOI)

### 1.1 [P0.5/P1, HAUTE] Litige #D TRANCHÉ : compteur de type = GLOBAL PUR (2 et 4 sans condition d'adjacence)

**Adopté de** synergies §2.1/P1 (corroboré units §2.5/Q3, qui pointe les sigils hostiles à l'adjacence).
**Pourquoi je tranche maintenant et ne renvoie plus à la mesure** : la critique apporte un **argument
mécaniste neuf et sourcé que `--position-variance` ne peut pas capter**. TFT Galaxies (officiel,
teamfighttactics.leagueoflegends.com/dev/dev-teamfight-tactics-galaxies-learnings, relu) documente que
les traits à **double condition simultanée** (nombre + autre facteur) créent une **« dead zone »** :
le joueur a 3 unités, vise le palier 4, mais n'a **ni** la 4e unité **ni** la paire adjacente — deux
axes **hétérogènes qui ne progressent pas ensemble** (or vs réarrangement). Riot a explicitement
retravaillé pour rendre « as many traits as possible viable across all stages ». **Le point décisif** :
`--position-variance` mesure si la **position impacte le win-rate**, **pas si la condition d'adjacence
au palier 4 crée une EXPÉRIENCE de frustration** — un joueur peut être en état frustrant (3+0 adjacence)
sans que ça apparaisse dans les stats de win-rate. Et surtout : **les auras d'adjacence build-résolues
(`shield_aura`, `miasma_acolyte`…) SONT déjà la couche positionnelle du type** — un palier de type =
« combien de burn tu as » ; les auras = « où tu les places ». Deux couches **orthogonales et
cumulatives**, pas redondantes. Dupliquer l'axe positionnel dans le compteur = sur-engineering qui
**grave un anti-pattern**. → **#D clos vers GLOBAL PUR.** **Gains mesurables** : −2 invariants de test
(plus de « count=4+paire » vs « count=4 sans paire ») ; **aucun sigil n'est hostile aux paliers de type**
(résout la Q3 round 5 : la croix activait mal l'adjacence) ; design plus lisible (goal-gradient sur un
**count visible** qui progresse — diva-portal.org 2025).

> **Pourquoi pas « mesurer d'abord » (round 4-5) ?** Parce que la décision de round 5 (« mesure
> tranche ») supposait que `--position-variance` était l'instrument adéquat. La critique **démontre
> qu'il ne l'est pas** pour ce litige (il mesure le win-rate, pas la dead-zone). Quand l'instrument est
> inadéquat, on tranche sur le mécanisme — et le mécanisme (auras = déjà l'axe spatial) est clair et
> rien ne le contredit. **`--position-variance` est CONSERVÉ mais REPOSITIONNÉ** (§1.2).

### 1.2 [P0.5, HAUTE] `--position-variance` repositionné : calibrer les AURAS d'adjacence, pas décider du compteur

**Adopté de** synergies Q2. **Pourquoi** : conséquence directe de #D-global-pur. La mesure ne sert plus
à « global vs adjacence » — elle reste **utile** pour : (a) **valider que les auras d'adjacence
existantes génèrent une variance positionnelle significative** par sigil (sinon le plateau-graphe est un
**décor topologique**, pas un différenciateur de gameplay) ; (b) **comparer les sigils entre eux** (le
plateau a 5 formes ; si la variance est homogène sur tous → les formes ne différencient pas le
gameplay = **problème de design sigil indépendant des types**). **Nouveau critère** : `variance < 0.02`
sur **TOUS** les sigils → les auras sont **trop faibles** → les **amplifier** (pas ajouter de paliers
de type adjacents). → **§3.6 réécrit avec ce nouvel objectif.**

### 1.3 [P0.5/P1, HAUTE] Litige #W TRANCHÉ : burn-vuln-bouclier = INTENTIONNEL ; twist burn-4 = `burnIgnoreShield` (keystone)

**Adopté de** synergies §2.2/P2. **Pourquoi** : la critique transforme un litige ouvert depuis le round 5
en **décision de rôle archétypal**, avec un argument mécaniste **rock-paper-scissors propre et sourcé** :
1. **Burn DÉCROÎT** (30 %/s, 00-state §3.1) = fort en early, faible en fin → s'il ignorait les boucliers
   dès le départ, son profil + l'absence de counter défensif le rendrait trivial à exploiter en early.
2. **Burn se propage à la mort** (saute par-dessus les tanks vers les carries) = déjà un ignore-bouclier
   **implicite** ; `burnIgnoreShield` de base **doublerait** l'avantage AoE.
3. **La vulnérabilité au bouclier = le COÛT de la propagation.** Système clair : **burn > carries,
   tank > burn, les autres familles percent les tanks via `ignoreShield`** → ce n'est pas une asymétrie
   invisible, c'est un système.
4. **Wayward Strategy 2024** (waywardstrategy.com/2024/03/20, relu) : « counterplay functions when all
   options have measurable responses — when some options have no response, it's not counterplay, it's
   dominance ». Si burn ignorait les boucliers, les tanks n'auraient **aucune réponse** au burn =
   dominance. Avec la vulnérabilité actuelle, le tank **répond** (absorbe) = counterplay sain.

→ **#W clos = INTENTIONNEL.** Conséquences directes : (a) la **spec burn-4 est débloquée** (plus de
litige « à trancher à la spec ») ; le **twist burn-4 = `burnIgnoreShield`** devient un **keystone de
commit** (« je sacrifie la sécurité pour percer les boucliers ») = identité forte et lisible ; (b)
**l'archétype tank est RENFORCÉ** : counter dur au burn = identité claire et enseignable. → **colonne (H)
§3.1 + §5.2 mis à jour ; #W retiré des litiges.**

### 1.4 [P0, HAUTE] VRR de BOUTIQUE — le vrai moteur du « one-more-run » dans une boucle build-spectateur

**Adopté de** retention §2.3 + Proposition B. **Pourquoi c'est une lacune structurelle majeure de v6 que
5 rounds ont manquée** : toute la couche VRR de la roadmap (le « Moment du Run », §2.4) est de la
**narration post-combat** — le joueur **LIT** le résumé du bus d'un combat qu'il **n'a pas joué** (il est
**spectateur**). La littérature VRR (PSU.com 2025) distingue **VRR sous agence** (chaque geste est une
décision → l'incertitude est « au bout du geste », c'est le one-more-run de Balatro) de **VRR narré** (on
raconte → « c'était bien de lire ça »). **Les deux ne sont pas équivalents pour la motivation de
relance.** Dans **SAP (notre référence)**, le VRR est dans la **BOUTIQUE**, pas le combat — on relance
pour voir **quelles unités seront proposées**. **Preuve sourcée** (Switchblade Gaming 2026,
switchbladegaming.com/strategy-games/best-auto-battler-games-2026) : facteur **#1** de rétention des
autobattlers = « **the build phase unpredictability — what will the shop offer me?** » — **pas** la
phase de combat ; **les jeux morts** (Dota Underlords, Storybook Brawl) ont tous essayé de rendre le
**combat plus spectaculaire** ; **les jeux vivants** (SAP, TFT) ont rendu la **boutique plus
imprévisible**. **Remède (RENDER pur, ~2 h, 0 SIM, 0 invariant)** : un **signal VRR de boutique**
discret au **reroll** quand l'offre contient une unité de **rang ≥ `shopTier`** OU une unité dont le
`dot_family` (P0.5) correspond à **≥ 60 % du build courant** — pulsation légère + texte grimdark. **Seuil
[PH]** calibré en sim sur N=100 builds, cible **~30 % des rerolls** déclenchent (Hopson 2001 : 20-30 %).
**Garde-fous DA (Q_R6_4) — décisifs** : le signal est **DISCRET** (pulsation, pas fanfare), **jamais
actif sur le 1er shop d'un round** (sinon le joueur apprend à attendre le signal avant d'acheter), et
**formulé comme une résistance/menace, pas une aide** (« LE PUITS RÉSISTE À TA FAIBLESSE — [UNITÉ]
S'IMPOSE ») pour rester grimdark (le Puits ne te **guide** pas, il te **force la main**).
**Complémentarité prouvée, pas cannibalisation** : VRR boutique = **BUILD, agence directe** ; Moment du
Run = **post-COMBAT, narration** → temporellement et psychologiquement distincts (circuits cérébraux
différents, PSU.com 2025). → **nouveau §2.9.**

> **Le Moment du Run N'EST PAS démonté** (rejet partiel de retention §2.3, cf. §3.2) : il reste le
> mécanisme de **mémorabilité mid-session** (le high-roll nommé). La critique a raison que **ce n'est pas
> LUI qui fait rouvrir/relancer** — mais il fait **rester**. On **ajoute** l'axe boutique, on ne
> **remplace** rien. La roadmap avait l'axe « rester », il lui manquait l'axe « relancer ».

### 1.5 [P0, doc→spec] Ré-ancrer « SPECTRE AFFRONTÉ » sur la TRACE D'IMPACT, pas la SDT-relatedness

**Adopté de** retention §2.1 + Proposition A. **Pourquoi** : la critique **démonte le fondement
théorique** du signal §2.8 (adopté round 5) sans toucher au signal lui-même. **Ballou et al. 2024 (ACM
TOCHI, « SDT and HCI Games Research: Unfulfilled Promises », arxiv.org/html/2405.12639** — revue de
**259 papiers)** : « all of the above posited causal relations remain empirically untested in published
SDT literature » ; la **relatedness** est la **moins documentée** des 3 besoins (traitée dans 59,85 %
des papiers, effets causaux du design **non testés**). Pire : le papier **Möller et al. 2024** que la
roadmap v6 **citait comme validation** dit en réalité « **studies have frequently ignored relatedness
need satisfaction** » = un **constat d'absence d'étude**, pas une validation → **la roadmap inversait la
charge de preuve**. Et un **ghost figé qu'un inconnu a affronté** sans connaissance mutuelle est
**l'analogue le plus distant possible de la relatedness** (connexion sociale) — **c'est de la trace, pas
de la connexion**. **Remède (0 code, doc)** : remplacer la justification SDT-relatedness par **« amorce
comportementale par trace d'impact persistante »** (Fogg Behavior Model : prompt externe + motivation de
l'impact ; Countly 2026 : les 90 premières s après relance = moment critique, le prompt doit concerner
**l'identité/l'impact persistant**, pas un événement social). **Impact concret** : prévient une mauvaise
décision UX dérivée — **ne PAS afficher le nom des joueurs** qui ont affronté le ghost (si la valeur est
la **trace**, l'**anonymat grimdark est préférable**). Formulation affinée : « **LE PUITS GARDE MÉMOIRE
DE TON BUILD — [N] ÂME[S] Y ONT AFFRONTÉ SON ÉCHO DEPUIS TON DÉPART** » (« âme » pour l'adversaire
renforce l'asymétrie anonyme). → **§2.8 ré-ancré ; litige #Z ouvert** (cold-start : silence vs
IA-formulation distincte).

### 1.6 [P2/P4, doc→spec] Ré-ancrer le Chapitre III du Grimoire sur OVSIANKINA + Goal-Gradient, pas Zeigarnik

**Adopté de** retention §2.2 + Proposition C. **Pourquoi** : **Nature H&SS 2025 (méta-analyse Zeigarnik
& Ovsiankina, nature.com/articles/s41599-025-05000-w)** : « found no memory advantage for unfinished
tasks but found a general tendency to resume tasks. The **Ovsiankina effect represents a general
tendency**, whereas the **Zeigarnik effect lacks universal validity** ». La roadmap v6 (§1.16/§6.7)
invoque « Zeigarnik » pour la silhouette du Chapitre III, mais ce qu'elle décrit (« silhouette fermée →
tension de reprise ») est en réalité l'**Ovsiankina** (reprise d'interrompu) **+ Goal Gradient** (Nunes
& Drèze 2006, déjà cité pour le sub-tier ranked). **Le mécanisme est juste, le nom est faux.** **Et ce
n'est PAS qu'un doc** : la distinction **change la spec de la silhouette** — Zeigarnik (mémoire
d'inachevé) → silhouette **mémorable/riche** ; Ovsiankina (reprise d'interrompu) → silhouette qui semble
**déjà commencée, pas juste annoncée**. → **§6.7 ré-ancré** : le Chapitre III en silhouette (P2) montre
**1-2 synergies en « ??? » avec une structure reconnaissable** (ex. « [SIGIL ANNEAU] × [POISON] → ??? »),
pas un simple titre verrouillé. **Q_R6_3 adoptée en sous-spec** : le Goal Gradient s'efface au-delà de
~7 étapes (LogRocket 2024) → **83 unités ≠ 83 étapes** → le **Chapitre II (Essences/bestiaire) doit être
segmenté par famille** (« 11/15 unités poison découvertes », cible = 15, pas 83).

### 1.7 [P0, doc] Critère de désactivation de la « Surprise de Placement » = déplacement INTENTIONNEL, pas quantité d'arêtes

**Adopté de** retention §2.4 + Proposition D. **Pourquoi** : le critère v6 (`hasLearnedAdjacency` ≈ ≥5
arêtes sur ≥3 combats) est une **mesure de QUANTITÉ, pas d'APPRENTISSAGE** (Q_R5_1 jamais tranchée). Un
joueur passif qui active 5 arêtes **par accident** (plateau de départ naturellement adjacent) verra la
Surprise disparaître **avant d'avoir appris** que le placement est une décision. **Digital Thriving
Playbook (SDT autonomie)** : « autonomy satisfaction requires that the player perceives their choices as
**causal**, not just that choices occurred ». **Remède (~1 h RENDER, lit les drags du bus JSONL)** :
désactiver quand le joueur a **déplacé une unité (`cause="player_move"`) qui a activé une arête nouvelle**
≥3 fois — il perçoit que **SA décision** a activé l'arête. **Garde-fou ajouté par le synthétiseur** :
**cap dur à ~10 sessions** quel que soit le critère d'intentionnalité, sinon le profil purement passif
(qui ne déplace jamais) voit la Surprise devenir du **bruit après 20 runs** (litige #Y retention,
fusionné). → **§2.7 affiné.**

### 1.8 [P0, PRÉCONDITION] Le tableau d'intention des constantes éco passe en PRÉCONDITION de P3 (pas livrable P3)

**Adopté de** progression §2.3/§3.1. **Pourquoi (renversement d'ordre, pas nouveau contenu)** : le
tableau d'intention (REROLL_COST / BUY_XP_COST / GOLD_PER_ROUND / STREAK_CAP / SELL_REFUND_FRAC /
SLOT_DECLINE_GOLD) **dit ce qu'une constante est censée faire** ; la sim **mesure si elle le fait**. **Si
le tableau n'existe pas AVANT la sim, on mesure sans savoir quoi optimiser.** Les 5 rounds ont **révélé**
que plusieurs constantes n'ont **aucune intention documentée** (REROLL_COST copié de SAP, SLOT_DECLINE
fixé arbitrairement, STREAK_CAP non challengé) → **les sims P3 produiraient des chiffres sans verdict**
(« le comportement observé est-il voulu ou accidentel ? »). **Principe sourcé** : Machinations.io 2025
(« define the goal before measuring » — « the simulation confirmed the system is balanced » **seulement
parce que** les objectifs étaient préalablement définis). **Remède** : créer `seed/eco-decisions.md` (≈
2-3 h éditorial, 0 code) **comme 1re tâche de P3**, **avant** `--xp-climax`/`--reroll-cost-scaling`. **Les
intentions sont proposées `[TBD]` et soumises à l'user** (les choix de design appartiennent à l'user, pas
à la sim — Q4 progression). → **§7.0 nouveau (précondition de §7) + §7.5 référence le tableau.**

### 1.9 [P0.5, doc] L'analogie SAP pour `REROLL_COST=1` est CORRIGÉE : ratio SAP = 1:3, jamais 1:1

**Adopté de** progression §2.1. **Pourquoi (correction d'une analogie utilisée depuis r01)** :
vérification wiki (superautopets.wiki.gg/wiki/Gold ; superautopets.fandom.com/wiki/Shop ;
twoaveragegamers.com) — **dans SAP, TOUS les pets coûtent 3 or, reroll = 1 or → ratio reroll/achat =
1:3, JAMAIS 1:1**. Dans The Pit, `cost=rank` → **rang-1 = 1 or = prix d'un reroll → ratio 1:1 en T1**
(le plus favorable au reroll en early), 1:3 en mid (rang-3, = SAP), 1:5 en late. **The Pit a en T1 un
ratio que SAP n'a JAMAIS eu** → « SAP fait 1 or donc acceptable » **ne s'applique qu'aux rangs 3+**. **Ce
n'est PAS un argument pour changer `REROLL_COST`** — c'est un argument pour **ne plus citer SAP comme
justification en T1** et pour **valider empiriquement** la décision sur ses propres mérites (la tension
en T1 vient de la diversité des 5 offres, pas du prix). **Calcul corroborant (progression Q3)** :
SHOP_SIZE=5, pool 12 rang-1 → **P(≥1 doublon en T1) ≈ 61,8 %** (tirage avec remise) → reroller en T1 =
souvent « éviter de voir 2× le même rang-1 » (décision réelle mais **mécanique**, pas « chercher une
unité précise »). → **§7.5 + §3.5 (note SAP corrigée) ; la sim `--reroll-cost-scaling` reçoit 2 métriques
ciblées T1-vs-T3** (§1.10).

### 1.10 [P3, sim] La sim `--reroll-cost-scaling` distingue T1 (ratio 1:1) de T3+ — 2 métriques séparées

**Adopté de** progression §3.2. **Pourquoi** : le pivot décisionnel du reroll **change par tier** — en T1,
« chercher ou se contenter » ; en T3, « chercher ou investir en puissance ». Une seule métrique
(rerolls/round) **ne capte pas** si le reroll est utilisé **par stratégie ou par défaut**. **Remède (~5-10
lignes sim)** : (A) **`reroll_opportunity_cost`** = `P(reroll produit une unité strictement meilleure que
la meilleure déjà visible)` par tier — **si < 30 % en T1 → reroll = bruit → garder=1 OK** ; **si > 60 %
en T1 → reroll dominant → envisager scaler** ; (B) **`reroll_by_tier_ratio`** = `rerolls/or total` par
tier — **si T1 > 0,20 ET T3 < 0,05 → asymétrie structurelle → scaler** ; si T1 ≈ T3 → homogène → garder.
→ **§7.5 enrichi.**

### 1.11 [P3, sim] Co-calibrer la courbe XP et le calendrier de slots : ratio `shopTier / slots_actifs`

**Adopté de** progression §2.2/§3.3. **Pourquoi (tension non mesurée)** : `START_SLOTS=3`,
`SLOT_GRANT_ROUNDS` 2-7 → un joueur qui **rush XP** rounds 1-2 (8 or de BUY_XP → T3 au round 3) se
retrouve en T3 avec **3 slots** : il voit des rang-3 (P=20 %) qu'il **ne peut pas placer** → l'avantage du
tier est **dilué**. Cas dégénéré : rush XP **+ option C slot-decline** (refus de slots) → boutique très
puissante mais **3 slots** = soit le rush est gaspillé, soit les slots refusés le sont. **Le critère
actuel « rush T5 ≥20 % du budget » ne vérifie pas si T5 est UTILISABLE à ce moment.** **Remède (3-4
lignes sim, données shopTier/slots déjà tracées)** : ajouter une **4e condition** au critère §7.1 —
`ratio_boutique_slots = shopTier_moyen / slots_actifs_moyen` par round par politique ; **cible < 1,5 à
tout round** ; **si > 1,5 pour `rush_XP` (ou `rush_XP + option_C`) → déséquilibre structurel** (calibrer
ensemble, ou limiter le rush aux rounds post-grant). → **§7.1 (#R) reçoit la condition (4) ; litige
co-calibration ouvert** (Q2 progression : rush_XP + option_C = archétype viable ou gaspillage ?).

### 1.12 [P2, spec] Saisons COURTES (3-4 sem.) sans contenu, ÉCHELONNÉES par lot de contenu — Fresh Start Effect

**Adopté de** ranked §2.1/§3.2. **Pourquoi (la roadmap confond cadence de RESET et cadence de CONTENU)** :
le **Fresh Start Effect (Dai, Milkman & Riis 2014, Management Science 60(10):2563-2582)** —
katymilkman.com/journal-articles/the-fresh-start-effect — fonctionne **seulement si le reset crée une
discontinuité perçue significative**, et les landmarks **temporellement proches** sont plus puissants
(début de semaine > début de trimestre). **Maths** : 6-8 sem. à 2-3 runs/sem = **12-24 runs/saison** ≈
**exactement 1 tier** (~35 pts / +2 à +4) = **aucune variabilité narrative** (chaque saison identique).
**TFT reset = 4 mois PARCE QUE chaque set amène ~40 unités** ; HS:BG trimestriel **avec nouveau contenu**.
**The Pit v1 n'a pas de contenu nouveau à chaque saison** (reliques G = P4, différé) → **6-8 sem. sans
contenu = stagnation perçue + reset = désengagement** (« ressemble à un timer, pas à un renouveau »).
**Remède (1 constante `SEASON_WEEKS` [PH], décision éditoriale)** — cadence échelonnée :
| Saison | Durée | Condition |
|---|---|---|
| Saisons 1-2 (pré-P3) | **3 sem.** | pas de contenu nouveau — Fresh Start court (Bazaar mensuel = benchmark) |
| Saisons P3+ (post-équilibrage) | **4-5 sem.** | nouveau tuning majeur = mini-refresh |
| Saisons P4+ (reliques G) | **6-8 sem.** | contenu nouveau = durée longue justifiée (HS:BG/TFT) |
**Garde-fou (synthé)** : **pas en dessous de 2 sem.** (en dessous, la fréquence annule le Fresh Start —
le joueur perd le sens « temps saison vs temps de jeu », Milkman 2014). Le target « 1 tier/saison » reste
acceptable même à 3 sem. (soit ~20 pts/tier, soit 1 tier / 2 saisons — non bloquant). → **§6.3 + §8.2
mis à jour** ; **« 6-8 sem. confirmé » est RETIRÉ** comme consensus (jamais challengé avant, l'argument
Fresh Start est neuf et sourcé).

### 1.13 [P2, spec] Démarrage de saison : politique du FIFO ranked + fenêtre de grâce « Montée des Ombres »

**Adopté de** ranked §2.2/§3.3. **Pourquoi (collision non documentée — le moment le plus fragile de la
rétention ranked)** : au reset de saison, **2 forces se heurtent** — le **Fresh Start** (le joueur veut
se relancer **immédiatement** en ranked) et **`RANKED_MIN_POOL`** (le pool ranked FIFO peut être vide).
La roadmap v6 **ne dit pas** ce qu'il advient du FIFO ranked au reset, et **les deux options brutes sont
mauvaises** : **FIFO non vidé** → snapshots obsolètes (ancien `slot_tier_composite`, build pré-`dot_family`
si P0.5 est passé) = intégrité compromise ; **FIFO vidé** → pool à 0 → `RANKED_MIN_POOL` non satisfait →
ranked « indisponible » au pic du Fresh Start → **abandon**. Notre FIFO 200 local n'a pas la densité du
backend mondial Bazaar (qui n'a jamais ce problème). **Remède (IO hors SIM, 0 invariant de combat)** :
**(a) persistance FILTRÉE** — le FIFO ranked **n'est pas vidé** ; un snapshot de saison S sert en S+1 si
`snap.wins_at_capture ≥ 3` (joueur établi = adversaire légitime), retiré si `< 3` (early, niveau de jeu
instable) ; **(b) fenêtre de grâce « Montée des Ombres »** — pendant les **7 premiers jours** de la
saison, `RANKED_MIN_POOL` est remplacé par le **mode SOFT** (jamais « indisponible »), signal 🟡 « Pool
en réveil — les ombres de la saison passée rôdent encore » (grimdark, justifie le filtre
`wins_at_capture ≥ 3`). 7 jours = largement suffisant pour ré-accumuler 5 snapshots ranked. → **§6.3 +
§6.4bis** ; **litige #Y ouvert** (persistance filtrée vs vidage complet **selon `sv`** — voir §1.14).

### 1.14 [P0.5→P2, litige re-priorisé] `sv` (schema version) re-lié à #Y ; à RÉ-ÉVALUER en P0.5

**Adopté de** ranked §5.1. **Pourquoi (révise le rejet de round 5 §3.1)** : round 5 différait `sv` au 1er
champ persisté (silencing + déduction dynamique suffisent). **La critique apporte un contexte neuf** :
**si `dot_family` est ajouté en P0.5**, un snapshot de saison précédente **sans `dot_family` dans le
schéma** peut produire une **famille `nil` en ranked post-P0.5** — et le **vidage complet du FIFO de
saison (option propre de #Y) ne devient SAFE que si `sv` permet d'identifier/ignorer** ces snapshots.
**Donc #V (`sv` maintenant vs différé) est en fait un PRÉREQUIS de #Y (politique FIFO de saison).** →
**Position synthé révisée** : `dot_family` est **déduit dynamiquement de `Units.dotFamily(id)`** (champ
de stat, **pas stocké** dans le snapshot v1) → un snapshot ancien lu après P0.5 récupère la famille **du
`units.lua` courant** tant que l'**id existe** → **pas de `nil` dans le cas courant**. Le seul cas
cassant reste un id devenu roster-only entre P0.5 et P2 (**rare, déjà géré par le silencing**). **Donc
`sv` reste DIFFÉRABLE pour la SIM**, MAIS la **spec FIFO de saison (#Y) doit choisir explicitement** :
persistance filtrée par `wins_at_capture` (n'exige PAS `sv`, §1.13) **OU** vidage complet (exige `sv`).
→ **§6.4bis note la dépendance ; #V re-priorisé « à RÉ-ÉVALUER en P0.5 quand on tranche #Y », pas adopté
maintenant.** (Le synthé maintient : ne pas coder `sv` spéculativement ; la persistance filtrée est le
chemin **qui ne l'exige pas** et reste préférable par défaut.)

### 1.15 [P2, spec] `RANKED_MIN_POOL` PROGRESSIF (SOFT=3 / HARD=5) — clôt le litige #T

**Adopté de** ranked §3.1. **Pourquoi** : #T (« 3 bêta fermée vs 5 early access ») est une **fausse
dichotomie** — les deux ont raison **selon l'état du pool**. **Remède** : 2 constantes au lieu d'1 dans
`snapstore.lua` — `RANKED_MIN_POOL_SOFT=3` / `RANKED_MIN_POOL_HARD=5` : `count<3` → 🔴 « Puits Silencieux »
(indisponible, IA, **non compté**) ; `3≤count<5` → 🟡 « Pool Mince » (ranked **disponible**, progression
partielle, certains combats vs IA, **le joueur choisit**) ; `count≥5` → 🟢 « Pool Vivant ». **Le signal UI
§6.5 supporte déjà 3 états 🟢🟡🔴** → architecture inchangée. → **#T clos** (la valeur dépend de l'état du
pool, pas d'un seuil figé) ; **§6.4bis + §6.5 mis à jour ; zone sans test** → l'état retourné est correct
pour chaque plage de `count`.

### 1.16 [P2, spec] Récompense cosmétique DATÉE de FIN DE SAISON (urgence émotionnelle du reset)

**Adopté de** ranked §3.4. **Pourquoi (lacune réelle)** : les marques Survivant/Forgé/Ascendant sont
**permanentes** → le reset de saison n'**enlève rien de mémoriel** = **pas d'urgence émotionnelle** (juste
−20 % de points). Or le temporal landmark (Dai/Milkman/Riis 2014) fonctionne par l'**arc** : « j'ai
accompli quelque chose **avant que ça disparaisse** ». **Remède (RENDER + 1 entrée
`grimoire:addSaisonTemoignage(season_id, best_rank)`, IO hors SIM, 0 invariant)** : à la **fin** de chaque
saison, distribuer **1 cosmétique DATÉ** (non reproductible en saison suivante = **rareté temporelle**) :
≥1 Ascension → icône « Puits Traversé — Saison N » ; ≥8 wins ranked → titre « Forgé dans le Puits —
Saison N » ; ≥1 run ranked → mention « Témoin — Saison N » (log Grimoire). **Garde-fou DA + pilier
(décisif)** : **cosmétiques UNIQUEMENT** (zéro gameplay, zéro item/unité/relique locké) → aligné «
égalisateurs, pas de gates ». **Vecteur (Q5.2 ranked, tranché)** : **log Grimoire + message au menu**
(cohérent avec le signal d'appartenance §2.8, même endroit que la méta-progression) plutôt qu'un modal
dismissable. **Source** : LoL/HS:BG ranked rewards saisonniers = moteur de rétention validé. → **nouveau
§6.12 + §6.7 (Chapitre I reçoit les « Mentions de Témoin »).**

### 1.17 [P0.5, sim BLOQUANTE] `plague_communion` : la magnitude DOIT être simulée (CONFIG-PC) avant d'être figée

**Adopté de** relics §2.1/Prop-A. **Pourquoi (élève le tuning de « ultérieur » à « bloquant »)** : la
roadmap garde `plague_communion` telle quelle (`plagueAmp=0.25`, accord maintenu, §3.2) **mais c'est le
SEUL `more` hors-cap du système** (`arena.lua:252`, post-cap) **et il n'a jamais été simulé contre un
ghost tier-3/4**. Le risque code-ancré : **`festering` lève le cap de stacks** (`poisonNoCap`,
`ops.lua:22`) → sur une cible >8 stacks, `plague_communion` amplifie un tick **hors-cap** = la **seule
interaction `more` + `poisonNoCap` du système**, **non simulée**. Et le **seuil `afflictionCount ≥ 2`
est sur la CIBLE** → la **contagion adverse** (`ops.lua:135-140`) + un mix de familles ennemies le
déclenche **facilement dès le round 5-6** en 6v6. **La comparaison `bloodstone` (+14 % toujours, frappe
ponctuelle) vs `plague_communion` (+25 % sur frappe ET DoT continu)** est **non-homogène** (les DoT
tiquent en continu → `plague_communion` outperform de façon **non-linéaire**). **Précédent décisif** :
MegaCrit (Giovannetti GDC 2019) « we run 18 million simulated runs per balance patch » → **une magnitude
non validée par sim est une dette de balance, pas un PH**. **Remède** : **CONFIG-PC** ajoutée à la matrice
sim — `{festering×2, plague_bearer, chitin_drone} + plague_communion` vs sans relique, N=50, seed
`20260623`, mesurer **win% + % de combats où `afflictionCount(cible) ≥ 2` se déclenche**. **Seuils** :
win% cible **[0,55 ; 0,65]** (tier-4 = avantage sans dominer) ; **si win% > 0,70 OU activation > 80 %** →
réduire `plagueAmp` à **0,15** OU exception **`NOT poisonNoCap`** (éviter le combo `festering`+`plagueAmp`
hors-cap) ; **si activation > 80 % ET win% > 0,65** → préférer l'**option (c) scalante** (`plagueAmp =
f(afflictionCount cible)` : 2→+20/3→+30/4+→+40 %, plus élégant, pousse vers le commit multi-affliction).
→ **§3.4-bis nouveau + §4.2 marque le tuning « BLOQUANT P0.5, pas ultérieur ».**

### 1.18 [pré-P1, doc] Tableau de SATURATION d'inc% par famille AVANT de spécifier les valeurs des paliers de type

**Adopté de** relics §2.2/Prop-B (corrobore le litige #B sous un angle calculable). **Pourquoi (#B est
modélisable MAINTENANT, sans sim)** : la formule `(base+Σflat)(1+Σinc)·Π(1+more)` (`stats.lua`) + le cap
sur l'**output** (pas sur l'inc) laisse une **zone de saturation** calculable sur un build concret. La
critique chiffre la **composition de 3 sources d'inc de la même famille** (relique B + palier type +
aura), **probable dès le tier-3 sur 9 slots** : poison = `kings_bowl` 0,20 + palier 0,20 + `miasma_acolyte`
0,50 = **inc 0,90** ; burn = `ember_heart` 0,30 + palier 0,20 + `warmth_emitter` 0,25 = **inc 0,75**.
**Le cap sur l'output ne borne pas l'inc** : si le cap est bas vs la base, il **écrase la profondeur**
(l'inc ne sert plus à rien) ; trop haut → sur-puissance. Et **les familles n'ont pas le même cap** :
`DOT_CAP_MULT=3` (`ops.lua:22`) ≠ `BLEED_DPS_CAP=12` (`ops.lua:28`). **Remède (doc ~5-15 lignes, 0 code)**
: avant P1, produire un **tableau de saturation par famille** — `base_dps médian`, `cap output`, **`seuil
d'inc saturé = (cap/base_min) − 1`** (au-delà, le cap est toujours atteint = profondeur écrasée), `inc
naturel max (B+aura)`, **marge avant saturation**, et **marquer `[SATURATION_RISK]`** toute famille dont
la stack d'inc dépasse 1,0 en combinaison naturelle. **Cela permet de spécifier les paliers de type P1
sans saturer une famille déjà à 0,90** (poison : marge ~130 % → +20 % palier OK, +40 % twist = risque si
base haute). → **§5.2 reçoit ce tableau en précondition ; §3.1 col E le référence.**

### 1.19 [pré-P1.5a, doc + 1 ligne] `famines_math` : trancher #O AVANT P1.5a + spécifier la modif de `R.apply` et du test #21

**Adopté de** relics §2.3/Prop-C. **Pourquoi (#O n'est pas « à trancher en P1.5a » — il MODIFIE le code et
les tests de P1.5a)** : `famines_math` (`relics.lua:34-35`, `relic_few_units {max=3}`) évalue `if #comp ≤ 3`
à `R.apply` (`relics.lua:77-94`) ; les `SLOT_GRANT_ROUNDS` (`state.lua:50`, 2-7, **6 grants automatiques**)
rendent le joueur **adverse à sa propre progression** par défaut (refuser 4 grants pour garder le bonus).
**L'option (a) « tes 3 unités les plus coûteuses » élimine le conflit** — mais elle **change `R.apply`** :
il faut **trier `comp` par coût** (aujourd'hui `ipairs` sans tri) et **adapter le test #21** (« applyRelics
ne crash pas »). **Si on entre en P1.5a avec le code courant**, la garantie B-E (§4.1) est implémentée
avec `famines_math` dans un **état indéfini**. **Remède** : (1) **acter formellement l'option (a) AVANT
P1.5a** ; (2) ticket P1.5a explicite : `R.apply` trie `comp` par `spec.cost or spec.rank` décroissant et
ne garde que les 3 premiers (`n_active = math.min(3, #sorted)`) ; **adapter test #21** (ne crash pas sur
compo de 1-2 unités). → **#O clos (option a) ; §4.5 + §9 (jalon v0.9.3) spécifient la modif.**

### 1.20 [P0.5, doc] 3 colonnes/lignes d'audit de PLUS : `siege_breaker`, singletons rang-1, `soot_acolyte`, colonne (J)

**Adopté de** units §2.1/§2.2/§2.3/§2.4/§2.5 + synergies §2.4. **Pourquoi (5 angles non épuisés, relus
ligne à ligne)** :
- **(a) Dispersion DPS intra-rang-2 = 7,24×** (`witch` 0,181 → `shieldbearer` 0,025, `units.lua` relu) →
  **rupture perceptive du contrat `cost=rank`** bien plus large que l'anomalie `cinder_cur` (Ariely,
  Loewenstein & Prelec 2003, QJE « Coherent Arbitrariness » : une ancre visible déforme la perception des
  items co-présentés ; SHOP_SIZE=5 → ancrage maximal en pool LOCAL). **Remède** : règle de **dispersion**
  dans la colonne E — **`P90/P10 intra-rang ≤ 3×` (enablers DoT, tanks/condensateurs EXCLUS** car ils ont
  leurs propres critères §3.1a/b) **+ signal boutique « GARDIEN »** pour les tanks (le rôle bas-DPS doit
  être **signalé autrement que par le prix**). **Ce n'est pas du rééquilibrage** (les tanks DOIVENT avoir
  un DPS bas) — c'est de la **lisibilité**. → **§3.1 col E reçoit la règle de dispersion + pilote le
  tooltip boutique §2.5.**
- **(b) `siege_breaker` (rang-3, DPS=0,154, `strip_shield`, `units.lua:377-380`) = anomalie budgétaire la
  plus sévère du rang-3, jamais citée en 5 rounds** : DPS le plus haut du rang-3 **+** counter-bouclier =
  **double-valeur (carry + counter)** ; glisse entre les catégories (pas `aggro=40`/taunt → hors radar
  tank). GhostCrawler : « a unit should not be both the best attacker and the best counter ». → **§3.1b/§3.2
  : catégorie NICHE** — réduire DPS ≤0,095 (counter pur) OU retirer de `U.pool` (garder en `U.order` pour
  encounters IA). **Décision binaire avant P3.**
- **(c) Burn rang-1 ET rot rang-1 = SINGLETONS** (`ash_moth` HP=26 DPS=0,075 ; `carrion_pecker`) → P(visible
  T1) ≈ 42 % (juste au-dessus du plancher) **mais visibilité de RECONNAISSANCE plus basse** (un singleton
  fragile ne « ressemble pas à la porte d'entrée burn »). SAP : « early tiers = introduction à chaque
  mécanique ; sans ancre early-accessible, le joueur ne peut s'orienter ». → **§3.1 plancher : documenter
  le singleton (rareté voulue grimdark OU trou). Si trou → 1 stat-stick rang-1 (DPS≈0,09, HP≈40).**
- **(d) `soot_acolyte` (aura burn, DPS=0,111 = MÉDIAN rang-3) vs les 3 autres auras (0,067)** = **aura +
  carry secondaire** non documenté → le joueur la pick **pour son DPS de frappe**, pas pour l'aura (SAP « 1
  trigger = 1 valeur »). Q3 round 4, **jamais répondue**. → **§3.1 col G/B : trancher** — (a) normaliser
  vers 0,07-0,08 (aura pure) OU (b) documenter « carry-aura » (niche unique à burn). **Option (b)
  recommandée si la DA supporte un « brûleur-prêtre » hybride.**
- **(e) Colonne (J) VALEUR SIGIL-DÉPENDANTE** (units §2.5 + synergies §2.4) : pour les unités
  `trigger="combat_start", target="neighbors"` (auras + `shield_aura`), la valeur **varie 2×** selon le
  sigil (croix/carré centre = 4 voisins ; ligne/anneau = 2) — **dimension absente des 9 colonnes A-I**.
  Backpack : « positional adjacency items require spatial tooltips ». → **§3.1 passe à 10 colonnes (A-J)**
  : (J) = valeur max (sigil à N voisins) / min / **sigil hostile (efficacité < 50 %)**. Révèle si une aura
  est viable **dans tous les sigils ou seulement certains**. Doc, lit `shapes.lua`, 0 code.

### 1.21 [pré-P1, test] 3 synergies adjacentes INTER-FAMILLE à ajouter à `tests/synergies.lua` avant P1

**Adopté de** synergies §2.4/P3. **Pourquoi (gap de garde-fou)** : les 12 synergies testées couvrent
l'intra-famille + quelques inter-famille, **pas** les interactions **aura × palier-type × adjacence** —
or le palier de type pose un `teamFlag` à `combat_start` **APRÈS** le bake des auras → l'**ordre de
résolution n'est pas testé** (si `poisonIncTeam` est appliqué avant que `miasma_acolyte` ne soit bakée,
l'accumulated peut diverger du cap ×3). Le fuzz (déterministe) **ne couvre pas ces cas-limites
déterministes**. **Remède (~3 tests, seed connue, 0 code moteur, précondition P1)** : (1) `miasma_acolyte`
+ palier poison-2 + tick cible → l'accumulated ne dépasse pas le cap ×3 ; (2) `shield_aura` (voisin) +
twist bleed-4 `bleedPierceShield` → le tick retire 1 pt **ET** l'aura se reconstruit ; (3) choc-D
`dot_family` + aura d'amplification (post-`miasma`) → l'ampli touche le tick **aura-amplifié**, pas un
tick fantôme. → **§5.2 reçoit ces 3 tests en précondition + Q1 synergies (nommage des `teamFlags` de
palier ≠ `poisonNoCap` de `festering`).**

### 1.22 [P0.5, doc] `hollow_choir` (pierceHeal, tier-3) → candidat pool-A (counter d'un archétype inexistant)

**Adopté de** relics §2.4/Prop-D. **Pourquoi** : `hollow_choir` (`relics.lua:37-38`, `grant_team
{pierceHeal=0.40}`) perce 40 % des **soins** ennemis — mais **regen = 1 unité** (`plague_doctor`),
**heal-on-kill = 0** (00-state §2.1) → **counter d'un archétype qui n'existe pas** = **bruit dans le pool**
(quasi-nul dans ~95 % des matchups), et en gating tier≤3 il **contamine les offres mid** d'une option sans
valeur (réduit la qualité de l'offre 1-parmi-3). Ce n'est **pas un égalisateur** (pilier §2). → **§3.1 col
H + §4 : ajouter aux candidats pool-A** (retrait de `U.pool`, garder en `U.order` ; réintégrer quand ≥3
unités regen/heal-on-kill). **Q ouverte (Q2 relics, liée à #X)** : **réorienter** `hollow_choir` en
`pierceShield` (counter-bouclier light, lisible, non-dominant) au lieu de la retirer → 1re relique de
**counter actif**, orthogonale aux 4 défensives, qui comblerait partiellement la relique de contre-jeu
méta #X **sans toucher la SIM**. → **§4 + Q ouverte ; à croiser avec la colonne (I).**

---

## 2. Consensus (confirmations — verrouillés, ne plus rouvrir sans preuve neuve)

- **Or fixe 10/round** : **7e confirmation** (progression §1.1 ; SAP wiki confirme « l'or ne se reporte
  pas »). Bazaar a migré vers un income linéaire (patch 7.0.0) = confirmation de marché.
- **Grille `+4/+2/+1/0` sans pénalité** : **7e confirmation** (ranked §1.1) — **MAIS raisonnement mis à
  jour** : **ne plus citer Bazaar comme validation** (le Bazaar a introduit gain ET **perte** de points
  en 2025 — bazaar-builds.net/ranking-update-reset). Citer désormais : **format run-court** (1-2 h de run
  → une pénalité = ~4 h de gain perdues en aversion à la perte, Kahneman-Tversky 2,3×) + **FIFO local
  imparfait** (une pénalité punirait la pauvreté du pool, pas le skill ; PMC10839887 : la perte amplifie
  le churn quand le matchmaking est perçu injuste). **Le Bazaar est désormais une contre-référence
  partielle** (il a les pénalités CAR son backend mondial les rend légitimes). → §6.2 sourcé correctement.
- **`plague_communion` gardée telle quelle** (payoff multi-affliction sur la CIBLE) : accord maintenu
  (relics §2.1) — **mais la magnitude passe en sim BLOQUANTE P0.5** (§1.17), pas « ultérieure ».
- **Pool ranked SÉPARÉ (`mode`) + `RANKED_MIN_POOL`** : accord fort, **renforcé** par Bazaar sept. 2025
  (séparation ranked/normal étendue + filtrage rang ≤ joueur) — ranked §1.2.
- **Signal « spectre affronté »** : accord fort sur la VALEUR (ranked §1.3, retention §1.1) — **mais
  l'ancrage théorique passe de SDT-relatedness à trace d'impact** (§1.5).
- **Signal pré-run au sub-tier** (goal-gradient borné ~7 étapes) : accord fort (ranked §1.4).
- **Seuils 2/4 sur 9 slots** : accord fort **renforcé** (synergies §1.3) — TFT Galaxies : les traits à
  seuil 6 créent une « dead zone » mid-tier (Cybernetic/Chrono) ; Riot a retravaillé pour « as many
  traits viable across all stages ». Sur 9 slots, un palier-6 serait pire.
- **`grant_team`/`teamFlags`** : accord technique (synergies §1.4) — 0 nouvelle mécanique.
- **Signal UI obligatoire de la famille amplifiée (choc-D)** : accord fort (synergies §1.1) — PoE Shock
  confirme (poewiki.net/wiki/Shock : ampli universel → notre ciblage par famille-du-poseur = transposition
  correcte de la **promesse**).
- **`--poison-frac` + `--no-weaken` en P0.5** : accords (synergies §1.2 ; précision : la cible n'est PAS
  la parité — poison à 3 axes est **structurellement plus riche** ; viser `écart < +1σ`, pas l'égalité ;
  Ludus AAAI : méta saine = faible σ + haute entropie = **diversité de builds viables**).
- **Option C2 `afflictionCount` (ne compter que les dps réels)** : maintenu (synergies §5, units), corrige
  le faux `plague_communion` de `wither_bloom`.
- **`burst_DPS_eq` pour le choc** (condensateur) : accord (units §1.1) — `galvanizer` = outlier voulu ;
  `stormlord` à ne pas **sous-évaluer** (burst > son DPS-frappe 0,111 ne le laisse croire — Q1 units).
- **Pity = signal sans garantie, `max(3, 0.5×médiane)` + progression visuelle, cappé ×1,5** : accord
  (progression §1.5) — plancher absolu garantit la saillance même si l'audit réduit la médiane.
- **Déprio reliques F ; `second_breath` universelle tier-3 ; daily 10+ contraintes + tooltip ; daily
  gating par équilibre `win_rate ≥ 0.8×médiane` ; timezone locale v1** : accords maintenus (relics
  §1.1/§1.3, ranked §1.5, progression §1.6/§1.7).
- **Rejet du score intra-run** : **7e confirmation** (ranked §4.1) — StS Ascension l'a abandonné ; Dota
  Underlords « ranking mixte » a fragmenté la valeur. **La grille plate est une qualité.**
- **Validation de la distribution temporelle des 2 signaux VRR AVANT de coder** (anti-cannibalisation,
  Kao 2024 CHI) : accord (retention §1.2). **Note synthé** : ce 3e signal VRR (boutique, §1.4) entre dans
  la même validation — mesurer le chevauchement boutique × placement × cascade par round.

---

## 3. Critiques REJETÉES ou NUANCÉES (avec le pourquoi)

### 3.1 REJET — `REROLL_COST` à changer ; NUANCE adoptée (analogie corrigée, pas la valeur)

**Position** : progression §2.1 **corrige l'analogie** SAP (1:3 ≠ 1:1, **adopté** §1.9) mais **ne demande
PAS** de changer `REROLL_COST` — elle demande de **valider empiriquement**. Le synthétiseur **confirme** :
**ne pas toucher la valeur ce round** (decision reste en sim P3, §7.5). Le calcul progression Q3 (P(doublon
T1) ≈ 62 %) **justifie partiellement** garder=1 (reroller pour éviter un doublon = décision raisonnable à
1 or). → **la correction est doc (note SAP) + 2 métriques de sim** (§1.9-1.10) ; **`REROLL_COST=1` reste
ni confirmé ni rejeté**, tranché par `--reroll-cost-scaling` en P3.

### 3.2 REJET PARTIEL — « le Moment du Run n'est pas le one-more-run » (retention §2.3) → on AJOUTE, on ne remplace pas

**Position** : retention §2.3 a **raison** que le Moment du Run (narration post-combat) **ne crée pas la
relance** dans une boucle build-spectateur, et **raison** d'ajouter un VRR de boutique (§1.4, **adopté**).
**Mais le synthétiseur REJETTE toute lecture qui DÉMONTERAIT le Moment du Run** : il reste le mécanisme de
**mémorabilité mid-session** (high-roll nommé) qui fait **RESTER** dans le run (≠ relancer). La roadmap
avait l'axe « rester » ; il lui manquait l'axe « relancer » (boutique). **Les deux coexistent.** → §2.4
**inchangé** ; §2.9 **ajouté**. (La critique elle-même est complémentaire, pas substitutive — elle ne
demande pas de retirer le Moment du Run.)

### 3.3 REJET — re-prioriser `sv` en P0.5 « maintenant » (ranked §5.1) → re-LIÉ, pas adopté

**Position** : ranked §5.1 recommande de **rouvrir #V en P0.5** et suggère `sv=2` **obligatoire** si
`dot_family` est ajouté. **Le synthétiseur maintient le différé pour la SIM** (§1.14) : `dot_family` est
**déduit dynamiquement** (`Units.dotFamily(id)`, pas stocké) → un snapshot ancien récupère la famille
courante tant que l'id existe → **pas de `nil` dans le cas courant** ; le seul cas cassant est rare et
silencé. **`sv` n'est requis que par le VIDAGE COMPLET du FIFO de saison (#Y)** — or la **persistance
filtrée** (§1.13, le chemin par défaut) **ne l'exige pas**. → `sv` reste **différé** ; **re-priorisé
seulement comme prérequis CONDITIONNEL de #Y** (« à décider en P0.5 **si** on choisit le vidage complet »).
Anti-complexité spéculative maintenue (cohérent `engine-architecture §12` : « au 1er besoin réel »).

### 3.4 NUANCE — l'empilement inc% des reliques B (relics §2.2) n'est PAS un nouveau litige

**Position** : relics §2.2 traite l'empilement B+type+aura comme une zone de danger distincte. **Le
synthétiseur l'INTÈGRE au litige #B existant** (déjà ouvert : « le cap borne l'output, pas l'inc/more »)
**via le tableau de saturation** (§1.18, **adopté**). Ce n'est **pas** un litige neuf — c'est la
**forme calculable** de #B. → pas de nouveau # ; #B enrichi du tableau de saturation par famille.

### 3.5 DÉPRIORISÉ — réorienter `hollow_choir` en counter-bouclier (relics Q2) → P1.5a, après l'audit colonne (I)

**Position** : idée **intéressante et grimdark-cohérente** (1re relique de counter actif, comblerait #X
sans toucher la SIM). **Mais déprio à P1.5a** : la décision « retirer (pool-A) vs réorienter » **dépend de
la colonne (I)** de l'audit (§3.1, « contre quoi optimal ») qui révèle **si un counter-bouclier comble un
trou réel de la méta** (P0.5). Trancher avant l'audit = spéculer. → **retrait pool-A en P0.5 (sûr) ; la
réorientation est une OPTION à trancher en P1.5a après la colonne (I).** (Le retrait n'est pas perdu : si
on réoriente, on la réinsère.)

### 3.6 REJET — « 6-8 sem. confirmé » comme consensus de saison → RETIRÉ (jamais challengé, Fresh Start le contredit)

**Position** : le brouillon v6 portait « cadence 6-8 sem. » comme acquis. **Le synthétiseur le RETIRE du
consensus** : il n'avait **jamais été challengé** sous l'angle du Fresh Start Effect, et l'argument
ranked §2.1 (landmarks proches > lointains ; saison sans contenu = timer) est **neuf et sourcé**. →
remplacé par la cadence échelonnée (§1.12). **Ce qui RESTE** : 6-8 sem. **uniquement quand un lot de
contenu accompagne la saison** (P4+ reliques G).

---

## 4. Litiges ouverts pour le round 7 (vrais désaccords, pas tranchés)

| # | Litige | Positions | Trancher en |
|---|---|---|---|
| **#A** | P1 (types) vs P2 (ranked) en premier | `--meta-convergence < 8 runs` pour ≥2 sigils **sur méta saine** (après `--poison-frac` ET `--no-weaken`) → types. **Précision R06** : mesurer sur **runs unranked LIBRES** (sans contrainte du jour) — les runs ranked ont un biais de sélection vers le méta dominant (ranked §5.3) | P3 (mesure) |
| **#M** | `swarm_logic` quantité (P1.5b) vs adjacence-par-arête (relique G P4) | Position v5 maintenue (quantité ≠ topologie) ; documenter la complémentarité | P1.5b / P4 |
| **#T** | **CLOS R06** : `RANKED_MIN_POOL` SOFT=3 / HARD=5 progressif | tranché (§1.15) | — |
| **#U** | Contrainte de Saison : famille **plus bas win-rate** vs **plus sous-représentée en pool** | 2 critères ; « plus bas win-rate » peut frustrer (choc) ; données post-P0.5 requises | avant spec §8.0 |
| **#V** | `sv` (schema version) | **Re-LIÉ à #Y** (R06) : différé pour la SIM (déduction dynamique suffit) ; **requis SEULEMENT si #Y choisit le vidage complet** ; à ré-évaluer en P0.5 quand on tranche #Y | au 1er champ persisté OU avec #Y |
| **#X** | Relique de « contre-jeu méta » compatible DA ? (Puits subi vs appris) | Grimoire + post-combat impliquent « appris » → cohérent ; **`hollow_choir` réorientée en `pierceShield` est un candidat light** (§3.5) | avant Prop-E (P3) / P1.5a pour hollow_choir |
| **#Y** | **NOUVEAU** : FIFO ranked au reset de saison — **persistance filtrée** (`wins_at_capture ≥ 3`, n'exige pas `sv`) vs **vidage complet** (exige `sv`) | synthé : persistance filtrée par défaut (§1.13) ; vidage = plus propre **si** `sv` adopté | P2 (avant spec FIFO de saison) |
| **#Z** | **NOUVEAU** : signal « spectre » en cold-start (pool vide) — **silence** vs **IA avec formulation distincte** (« LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE — [N] INVOCATION[S] ») | retention : IA-formulation distincte (honnêteté : pas présentée comme humaine, impact réel) ; à acter | avant le code §2.8 |
| **#AA** | **NOUVEAU** : seuil + DA du signal VRR boutique (§2.9) | cible ~30 % des rerolls (Hopson) ; formulation « résistance », jamais 1er shop du round ; à playtester | P0 (sim seuil) / playtest (feel) |
| **#B** | Twist palier-4 = `more` hors-cap → borner séparément ; **+ tableau de saturation d'inc par famille** (R06, §1.18) | confirmé code (cap borne l'output) ; le tableau rend #B calculable AVANT P1 | avant P1 |
| **#O** | **CLOS R06** : `famines_math` option (a) « 3 plus coûteuses » + spec `R.apply` (tri) + test #21 | tranché (§1.19) | — |
| **#D** | **CLOS R06** : compteur type = GLOBAL PUR (2 et 4 sans adjacence) | tranché (§1.1) ; `--position-variance` repositionné (§1.2) | — |
| **#W** | **CLOS R06** : burn-vuln-bouclier = INTENTIONNEL ; twist burn-4 = `burnIgnoreShield` | tranché (§1.3) | — |
| **#E/#L** | Hunt 3e copie → pity ; spec bloquée par la sim hunt-médian | accord ; mesurer avant de figer | P3 |
| **#F** | 6e type non-DoT | « aucun » confirmé (shield/tank = enablers ; dispersion DPS = audit budget §3.1b + `siege_breaker` §1.20b) | clos sauf preuve |
| **#R** | Courbe XP robuste variance + streaks + **co-calibration shopTier/slots (4e condition, R06 §1.11)** + **dépend de REROLL_COST** | critère 4-tranches + clause streak + ratio slots ; **co-calibration rush_XP+option_C ouverte** (Q2 progression) | P3 |

**Litiges clos ce round** : **#D** (global pur), **#W** (burn-vuln intentionnel), **#T** (SOFT/HARD),
**#O** (famines_math option a). **Litiges neufs** : **#Y** (FIFO de saison), **#Z** (cold-start spectre),
**#AA** (VRR boutique). **#V re-lié à #Y** (re-évaluation conditionnelle, pas adoption).

---

## 5. Preuves nouvelles apportées ce round (sources)

- **TFT Galaxies learnings** (teamfighttactics.leagueoflegends.com/dev/dev-teamfight-tactics-galaxies-learnings) :
  traits à **double condition** = « dead zone » mid-tier ; « as many traits viable across all stages ». →
  §1.1 (#D global pur) **et** §2 (seuils 2/4 renforcés).
- **Wayward Strategy 2024** (waywardstrategy.com/2024/03/20) : « counterplay needs measurable responses
  for all options ; no response = dominance ». → §1.3 (#W burn intentionnel).
- **Switchblade Gaming 2026** (switchbladegaming.com/strategy-games/best-auto-battler-games-2026) :
  rétention autobattler #1 = **imprévisibilité de la phase boutique**, pas le combat ; jeux morts ont
  rendu le combat spectaculaire, jeux vivants la boutique imprévisible. → §1.4 (VRR boutique).
- **Ballou et al. 2024 (ACM TOCHI, « Unfulfilled Promises », 259 papiers, arxiv.org/html/2405.12639)** :
  relations causales SDT **non testées** ; relatedness la moins documentée. **Möller et al. 2024**
  (pmc.ncbi.nlm.nih.gov/articles/PMC12412733) : « relatedness frequently ignored » = absence d'étude, pas
  validation. → §1.5 (ré-ancrage trace d'impact). **Countly 2026** : 90 s post-relance = moment critique,
  prompt sur l'identité/impact persistant.
- **Nature H&SS 2025** (méta-analyse Zeigarnik & Ovsiankina, nature.com/articles/s41599-025-05000-w) :
  **Zeigarnik manque de validité universelle** ; **Ovsiankina** (reprise d'interrompu) **tient**. →
  §1.6 (Chapitre III ré-ancré, silhouette « déjà commencée »).
- **Dai, Milkman & Riis 2014** (Management Science 60(10):2563-2582, katymilkman.com/journal-articles/
  the-fresh-start-effect) : landmarks **proches** > lointains ; reset doit créer une discontinuité
  perçue. → §1.12 (saisons 3-4 sem.). **Dai & Li 2018** (anderson-review.ucla.edu) : l'effet décroît si
  la distance perçue est trop longue.
- **PMC10839887** (matchmaking + churn) : la perte amplifie le churn quand le matchmaking est perçu
  injuste → §2 (grille sans pénalité, raisonnement mis à jour). **Bazaar 2025**
  (bazaar-builds.net/ranking-update-reset) : gain **ET perte** de points → ne plus citer Bazaar comme
  validation du « sans pénalité ».
- **SAP wiki/fandom + twoaveragegamers.com** : pets 3 or, reroll 1 or = **ratio 1:3, jamais 1:1**. →
  §1.9 (analogie corrigée). **Machinations.io 2025** : « define the goal before measuring ». → §1.8
  (tableau d'intention en précondition).
- **Ariely, Loewenstein & Prelec 2003** (QJE, « Coherent Arbitrariness ») : ancre visible déforme la
  perception co-présentée → §1.20a (dispersion DPS intra-rang = ancrage). **GhostCrawler** (askghostcrawler.tumblr.com)
  : « not both best attacker and best counter » → §1.20b (`siege_breaker`). **Backpack Battles** (steam) :
  « positional items require spatial tooltips » → §1.20e (colonne J). **a327ex.com SAP** : « 1 pet =
  1 valeur ; early tiers = introduction » → §1.20c/d.
- **MegaCrit / Giovannetti GDC 2019** (gamedeveloper.com) : « 18 million simulated runs per balance
  patch » → §1.17 (magnitude `plague_communion` = sim bloquante, pas PH).
- **PoE Shock** (poewiki.net/wiki/Shock) : ne stacke pas, ampli universel → §2 (choc-D ciblé = bonne
  transposition de la promesse). **Ludus / AAAI** (ojs.aaai.org/index.php/AAAI/article/view/21550) :
  méta saine = faible σ + haute entropie = **diversité**, pas égalité.
- **Vérif code synthétiseur** (relue ce round) : `relics.lua:46` (`invulnT=30`) ; `arena.lua:247`
  (garde `self.t < invulnT`) ; `arena.lua:58` (`self.t` en ticks @60 fps, FATIGUE_START=1020≈17 s) →
  `sacred_shield` = 0,5 s = quasi-inerte. → §0.

---

## 6. Améliorations mesurables vs v6 (ce que cette synthèse ajoute)

1. **3 litiges majeurs CLOS par argument mécaniste sourcé** : #D (global pur, dead-zone TFT), #W
   (burn-vuln intentionnel, counterplay measurable), #T (SOFT/HARD), #O (famines_math). + #V re-lié à #Y.
2. **1 lacune de rétention structurelle comblée** : le **VRR de boutique** — le vrai moteur du
   one-more-run dans une boucle build-spectateur (5 rounds l'avaient manqué ; le Moment du Run faisait
   « rester », pas « relancer »). Sur l'axe psychologique **correct** (agence directe, pas narration).
3. **3 ré-ancrages théoriques** qui préviennent de mauvaises décisions UX : SDT-relatedness → trace
   d'impact (anonymat grimdark préférable) ; Zeigarnik → Ovsiankina (silhouette « déjà commencée ») ;
   Moment du Run = mémorabilité, pas relance.
4. **1 renversement d'ordre éco** : le tableau d'intention des constantes passe en **précondition** des
   sims P3 (mesurer sans intention = chiffres sans verdict).
5. **1 analogie corrigée depuis r01** : `REROLL_COST` SAP = 1:3, jamais 1:1 (+ 2 métriques de sim
   T1-vs-T3).
6. **1 collision de rétention ranked documentée** : démarrage de saison (Fresh Start vs pool vide) →
   persistance filtrée + fenêtre de grâce 7 j + saisons courtes échelonnées + cosmétique daté.
7. **1 sim élevée de « ultérieure » à BLOQUANTE** : magnitude `plague_communion` (seul `more` hors-cap +
   combo `festering`).
8. **1 tableau de saturation d'inc par famille** (rend #B calculable AVANT P1) + **5 angles d'audit
   units** (dispersion 7,24×, `siege_breaker`, singletons rang-1, `soot_acolyte`, colonne J) + **3 tests
   inter-famille** (précondition P1) + **1 colonne d'audit de plus** (A-J).
9. **1 fait code-vérifié de plus** : `sacred_shield invulnT=30` = 0,5 s quasi-inerte (grep d'unité).

---

*Round 06 synthétisé le 2026-06-23. Débat, pas addition : ~22 adoptions argumentées, 6 rejets/nuances
sourcés, litiges (4 clos, 3 neufs, 1 re-lié). Lecture seule du repo ; n'édite que sous
`docs/roadmap-lab/`. Piliers respectés. 1 claim code revérifié par le synthétiseur (`invulnT` = ticks).
ROADMAP-draft réécrit en conséquence (v7).*
