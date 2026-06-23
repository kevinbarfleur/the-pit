# Round 06 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 6/10. Challenge le brouillon v6 (`ROADMAP-draft.md` post-round-5) et la
> synthèse `round-05.md`. Les rounds 1-5 ont posé :
> - Grille sans pénalité `+4/+2/+1/0`
> - Pool ranked/unranked SÉPARÉ (`mode` dans snapshot, adopté r05)
> - `RANKED_MIN_POOL=5` [PH] (intégrité async)
> - Marques sub-tier Survivant/Forgé/Ascendant
> - `slot_tier_composite` matchmaking + fallback descendant
> - Signal pré-run au sub-tier (goal-gradient borné ~7 étapes, Nunes & Drèze 2006)
> - `RANKED_MIN_POOL` gate + signal de pool pré-run
> - Signal d'appartenance « ton spectre a été affronté » (session initiation, SDT)
> - Contrainte du Jour gating famille par `win_rate ≥ 0.8×médiane`
> - Contrainte Permanente de Saison §8.0 + litige #U (sous-représenté vs win_rate bas)
> - Daily timezone locale acceptable v1
>
> Ce round attaque **4 angles structurellement non-résolus ou falsement résolus** dans la
> couche ranked v6 — 2 DÉSACCORDS FONDÉS (avec recherche), 2 LACUNES de spec.
>
> **Sources primaires mobilisées** :
> - `ROADMAP-draft.md` v6, `round-05.md`, `00-state.md`, `competitive/{the-bazaar,hs-battlegrounds}.md`
> - Bazaar : `bazaar-builds.net/ranking-update-reset-item-changes-and-more/` (feb 2025)
> - Bazaar : `bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/` (sep 2025)
> - Bazaar matchmaking changes : `steamcommunity.com/app/1617400/discussions/0/591781420376206105/`
> - Bazaar ghost pool : `thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar`
> - Fresh Start Effect : Dai, Milkman & Riis 2014, Management Science, DOI:10.1287/mnsc.2014.1901
> - Milkman temporal landmarks : `katymilkman.com/journal-articles/the-fresh-start-effect-temporal-landmarks-motivate-aspirational-behavior`
> - SAP ranked update : `store.steampowered.com/news/app/1714040/view/3689065475857403445`
> - SBMM retention : `pmc.ncbi.nlm.nih.gov/articles/PMC10839887/`
> - Backpack Battles ranks : `thegamer.com/backpack-battles-ranks-explained-guide/`
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés.

---

## 0. TL;DR du challenge R06

**Quatre angles d'attaque, un désaccord de fond et trois lacunes de spec.**

(1) **DÉSACCORD MAJEUR : la saison de 6-8 semaines proposée est trop longue pour le format run-based
async de The Pit.** Le brouillon v6 aligne sur HS:BG (3-4 mois) et Bazaar (mensuel depuis mars 2025)
sans vérifier que le « pourquoi psychologique » du reset saisonnier — le Fresh Start Effect (Dai,
Milkman & Riis 2014) — tient pour 2-3 runs/semaine sur 6-8 semaines. Il ne tient pas.

(2) **DÉSACCORD PARTIEL : le Bazaar a migré vers un système de gain ET de perte de points ranked**
(patch 2025), et les runs 1-5 ont maintenu « sans pénalité » comme consensus «6e confirmation». Ce
consensus s'appuie partiellement sur un état du Bazaar qui a changé. La conclusion reste probablement
bonne pour nos contraintes, mais le raisonnement doit être mis à jour — sinon on valide sur une fausse
analogie.

(3) **LACUNE de spec : le reset saisonnier −20 % (§6.3) est insuffisamment spécifié pour coexister
avec le gate `RANKED_MIN_POOL`.** Si la saison reset le rating et vide le pool ranked FIFO, le joueur
se retrouve simultanément en « Puits Silencieux » (pool insuffisant) et avec son rating réinitialisé.
Le démarrage de saison est le moment le plus fragile de la rétention ranked — et la roadmap ne le
documente pas.

(4) **LACUNE de spec : aucune récompense cosmétique de FIN DE SAISON distribuée à la fin de la saison,
seulement des marques sur le meilleur run.** Les marques Survivant/Forgé/Ascendant sont permanentes sur
le profil. Mais la psychologie du reset saisonnier fonctionne par l'arc : « j'ai accompli quelque chose
cette saison avant que ça disparaisse ». Sans récompense distribuée (même cosmétique), le reset n'a
pas d'urgence émotionnelle — il n'est qu'une perte de points.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 Grille `+4/+2/+1/0` — ACCORD MAINTENU AVEC MISE À JOUR DU RAISONNEMENT

**Accord maintenu, mais le raisonnement « Bazaar confirme » doit être mis à jour.**

Le Bazaar a introduit le gain ET la perte de rank points en 2025 (patch feb 2025 :
bazaar-builds.net/ranking-update-reset-item-changes-and-more — « Players now gain and lose rank
points throughout the ranking process »). Le consensus de 5 rounds sur « grille sans pénalité »
s'appuyait partiellement sur « Bazaar pré-Legend = gains seulement » comme validation de marché.
Ce fait n'est plus exact.

**Cela dit, la conclusion reste juste POUR NOS CONTRAINTES SPÉCIFIQUES** — et pour des raisons plus
robustes que l'analogie Bazaar :

1. Le Bazaar a introduit les pénalités **parce qu'il a un backend mondial** avec des pools de centaines
   de milliers de joueurs. Avec un pool mondial, la pénalité est l'outil de calibrage du MMR (faire
   redescendre les surévalués). Notre FIFO 200 local ne peut pas garantir la représentativité du tier
   — une pénalité punirait le joueur pour la pauvreté du pool, pas son skill (inchangé, confirmé r05).

2. La recherche sur les pénalités et la rétention (PMC/NCBi PMC10839887 : « match experiences affect
   interest — impacts of matchmaking and performance on churn ») montre que l'effet négatif d'une
   perte sur la rétention est amplifié quand le **matchmaking est perçu comme injuste**. Notre FIFO
   avec `RANKED_MIN_POOL` est transparent sur l'imperfection du pool — une pénalité dans ce contexte
   serait perçue comme une injustice mécanique plutôt que comme un signal de skill.

3. Format run-court (10 victoires avant 5 défaites) : le **coût d'une run** en temps est de 1-2h.
   Une pénalité sur une run perdue = 1-2h de travail effacées. L'aversion à la perte
   (Kahneman-Tversky : perte pèse ~2,3× la gain équivalent) est **proportionnelle à l'investissement
   temps**. Pour 2h de run, une pénalité est psychologiquement équivalente à ~4h de gain perdues.
   Incompatible avec le « jeu de grind fun » visé.

**Verdict** : conserver `+4/+2/+1/0`, mais ne plus citer Bazaar comme validation. Citer le format
run-court + pool local imparfait + FIFO transparent. Le Bazaar est désormais une contre-référence
partielle (il a les pénalités CAR il a les moyens de les rendre légitimes).

**Coût** : 0 code, 1 mise à jour de spec dans §6.2 (sourcer correctement).

### 1.2 Pool ranked SÉPARÉ (`mode`) + `RANKED_MIN_POOL` — ACCORD FORT (inchangé)

**Accord maintenu, renforcé par les changements Bazaar 2025.**

Le Bazaar sep. 2025 (bazaar-builds.net/announcement-future-updates) a étendu la séparation ranked/
normal ET ajouté un filtrage « rang ≤ joueur » pour les ghosts ranked. Nos décisions structurelles
anticipaient exactement ce besoin. `RANKED_MIN_POOL` + 2 FIFO séparés = architecture correcte.

**Ce qui tient** : la séparation garantit que battre un débutant en ranked ne rapporte pas +4.
`RANKED_MIN_POOL=5 [PH]` est la bonne mécanique — mais le litige #T (3 vs 5) DOIT être tranché
avant de coder. Voir §3.1 pour une proposition de résolution.

### 1.3 Signal d'appartenance « ton spectre a été affronté » (session initiation) — ACCORD FORT

**Accord maintenu.** La logique SDT (appartenance = besoin structurellement absent) est solide.
Le mécanisme est simple (compteur IO hors SIM, 0 invariant) et la DA grimdark s'y prête naturellement.

**Ce qui tient** : en cold-start (pool vide), silence → correct (ne pas tricher avec les IA).
La v2 backend enrichit. Pas de re-challenge ici.

### 1.4 Signal pré-run au sub-tier (goal-gradient borné) — ACCORD FORT

**Accord maintenu.** Nunes & Drèze 2006 (Endowed Progress Effect, JCR) : efficace si distance < ~7
étapes. Sub-tier closable en 1-3 runs. La mécanique « PROCHAIN GRADE : Forgé — 4 pts » est la bonne
granularité pour 2-3 runs/semaine. Tier suivant ~8-17 runs = hors horizon.

### 1.5 Contrainte du Jour gating famille par `win_rate ≥ 0.8×médiane` — ACCORD

**Accord maintenu.** Fairness de difficulté ≠ reproductibilité du seed (dev.to/yurukusa 2026). La
condition est juste et la dépendance P0.5 (`dot_family` dans la sim) est bien documentée.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD FONDAMENTAL — La saison de 6-8 semaines est trop longue pour 2-3 runs/semaine

**Ce que le brouillon v6 §6.3 dit** : « Cadence : 6-8 semaines — 15-25 runs = narration. » Le
calibrage est basé sur « 1 tier / saison 6-8 sem. » (§6.2 : ~35 pts/tier).

**Mon désaccord** : la durée de saison et le Fresh Start Effect (Dai, Milkman & Riis 2014,
Management Science) sont **inversement corrélés à la fréquence de jeu perçue**. L'effet psychologique
du reset saisonnier (motivation à reprendre, « cette saison je vais faire mieux ») **décroît si la
durée est perçue comme trop longue pour être closable**.

**Maths du problème** :
- Joueur type : 2-3 runs/semaine.
- Run : 10 victoires ou jusqu'à 5 défaites → ~10-19 rounds → 30-90 min.
- 6-8 semaines à 2-3 runs/sem = **12-24 runs par saison**.
- Tier cible : 35 pts / (grille moyenne +2 à +4) = **9-18 runs pour 1 tier complet**.
- Résultat : un joueur mid-core qui progresse normalement fait **1 tier / saison**. La saison = exactement
  l'horizon d'un tier = **aucune variabilité narrative** (chaque saison est identique, pas de surprise
  temporelle).

**Le Fresh Start Effect fonctionne SEULEMENT si le reset crée une discontinuité perçue significative.**
Dai, Milkman & Riis 2014 (katymilkman.com/journal-articles/the-fresh-start-effect-temporal-landmarks-motivate-aspirational-behavior) :
« temporal landmarks help people separate past failures from future potential ». Pour que cela fonctionne,
le joueur doit ressentir que la **durée de la saison correspond à une période narrative complète** dans
sa vie de joueur. 6-8 semaines pour 12-24 runs = une période trop longue pour l'habituation (le mid-
core jouant 2-3×/sem voit la même boutique, les mêmes unités, pendant 6 semaines sans nouveau contenu).

**Référence concrete** : le Bazaar a des resets **mensuels** (bazaar-builds.net/ranking-update-reset)
depuis feb 2025. HS:BG a des resets **trimestriels** mais avec **nouveau contenu par saison** (nouveaux
héros, nouvelles tribus). The Pit v1 n'a pas de nouveau contenu à chaque saison (P4 = reliques G est
différé). Une saison sans nouveau contenu de **6-8 semaines** = stagnation perçue + reset = désengagement.

**Ce qui manque** : la roadmap confond la cadence de reset avec la cadence de contenu. TFT reset = 4
mois PARCE QUE chaque set amène ~40 nouvelles unités. Notre P4 amènera des reliques G — mais entre
P2 (v0.11, ranked v1) et P4 (sigils/saisons), la roadmap planifie **des saisons sans contenu nouveau**.
Le Fresh Start Effect sans nouveau contenu = ressemble à un timer, pas à un renouveau.

**Proposition** : voir §3.2.

### 2.2 DÉSACCORD PARTIEL — Le reset conditionnel `<3 runs ranked` (§6.3) est une demi-solution qui ne traite pas le vrai démarrage de saison

**Ce que le brouillon v6 §6.3 dit** : « Reset conditionnel : si `ranked_runs_this_season < 3` → reset
à 0 (pas −20 %) + message clair 'tu n'as pas perdu de rating'. »

**Mon désaccord** : ce reset conditionnel traite le joueur qui **entre tard dans la saison**. Mais le
problème structurel le plus grave est le **démarrage de saison pour un joueur établi** :

1. La saison reset le rating visible −20 %.
2. `RANKED_MIN_POOL=5` a été accumulé pendant la saison précédente dans le FIFO ranked.
3. Le FIFO ranked (200 max) ne se vide pas au reset de saison — ou se vide-t-il ?

**Trou de spec non résolu** : la roadmap ne dit pas si le **pool ranked FIFO est vidé au reset
saisonnier**. Les deux options sont mauvaises :
- **FIFO non vidé** : les snapshots de la saison précédente (avec l'ancien `slot_tier_composite`)
  persistent → matchmaking contre des builds obsolètes → intégrité compromise en début de saison.
- **FIFO vidé** : le pool ranked retombe à 0 → `RANKED_MIN_POOL=5` non satisfait → ranked
  « indisponible » pour les premières runs de la saison → le joueur qui rouvre le jeu après le reset
  se retrouve **bloqué hors du ranked** → abandon.

**La tension est réelle** : on veut à la fois un pool fresh (compétitif) et un pool peuplé (accessible).
Le Bazaar gère ça avec un **backend mondial** : même en début de saison, le pool contient des millions
de snapshots. Notre FIFO 200 local n'a pas cette densité.

**Conséquence pour la rétention** : le démarrage de saison — le moment où le Fresh Start Effect est le
plus fort — est aussi le moment où le joueur est le plus susceptible de se heurter au « ranked
indisponible ». C'est une **collision entre le moteur psychologique (vouloir se relancer) et la
contrainte technique (pool vide)**. La roadmap l'ignore complètement.

**Proposition** : voir §3.3.

---

## 3. Propositions priorisées

### 3.1 — Trancher le litige #T (`RANKED_MIN_POOL` = 3 vs 5) par une règle PROGRESSIVE — PRIORITÉ 1

**Problème** : le litige #T (seuil 3 vs 5) est « à trancher selon la taille de la bêta » (round-05,
§4 litiges). C'est une fausse dichotomie : les deux valeurs ont raison selon la phase.

**Proposition** : remplacer la constante par une **règle progressive à 2 paliers** :

```
RANKED_MIN_POOL_SOFT = 3   -- ranked disponible, signal « Pool Mince » 🟡
RANKED_MIN_POOL_HARD = 5   -- ranked indisponible en dessous
```

- Si `countRankedByTier(tier) < 3` → « Puits Silencieux » (ranked indisponible, fallback IA, résultat
  non compté).
- Si `3 ≤ count < 5` → « Pool Mince » 🟡 (ranked disponible, progression partielle — signal clair que
  certains combats peuvent être vs IA). Le joueur **choisit** de jouer avec un pool mince.
- Si `count ≥ 5` → « Pool Vivant » 🟢 (progression complète).

**Pourquoi** : le seuil 3 est safe pour une bêta fermée (< 20 joueurs actifs) ; le seuil 5 est l'idéal
pour early access. La règle progressive **évite de bloquer le ranked en bêta** tout en signalant
honnêtement les limites du pool. Compatible avec `RANKED_MIN_POOL` déjà structuré dans §6.4bis.

**Coût** : 2 constantes au lieu d'1 dans `snapstore.lua` ; le signal UI §6.5 supporte déjà 3 états
🟢/🟡/🔴 (architecture inchangée). **0 invariant de combat.** Zone sans test → ajouter un test que
le signal retourne bien l'état correct pour chaque plage de `count`.

**Règle de compatibilité litige #T** : adopter SOFT=3/HARD=5 **clos le litige #T** sans trancher
arbitrairement — la valeur utilisée dépend de l'état du pool, pas d'un seuil figé.

### 3.2 — Saison COURTE (3-4 semaines) + ARC DE CONTENU cohérent avec le cycle de contenu réel — PRIORITÉ 2

**Problème** : 6-8 semaines sans nouveau contenu = stagnation perçue + Fresh Start Effect affaibli
(§2.1).

**Proposition** : ajuster la cadence de saison à **3-4 semaines** pour les saisons sans nouveau contenu,
et 6-8 semaines seulement quand un **lot de contenu significatif** est livré en même temps que la saison.

**Maths recalibrées** :
- 3-4 semaines à 2-3 runs/sem = **6-12 runs par saison**.
- Grille moyenne +2 → tier en ~9-18 runs. → 1 tier de progression / 1-2 saisons. Le joueur mid-core
  monte plus lentement **mais ressent le fresh start plus fréquemment** → plus d'occasions de retour.
- Avec 3-4 semaines : le Bazaar (mensuel) est le bon benchmark. HS:BG (trimestriel) ne s'applique pas
  sans nouveau contenu.

**Règle concrète** :
| Saison | Durée | Condition |
|--------|-------|-----------|
| Saisons 1-2 (pré-P3) | **3 sem.** | Pas de nouveau contenu — Fresh Start court |
| Saisons P3+ (post-équilibrage) | **4-5 sem.** | Nouveau tuning majeur = mini-refresh |
| Saisons P4+ (reliques G) | **6-8 sem.** | Nouveau contenu = durée longue justifiée |

**Pourquoi ça tient** : Dai, Milkman & Riis 2014 montrent que le Fresh Start Effect est plus fort pour
les landmarks **temporellement proches** (début de semaine > début de trimestre). Une saison de 3 semaines
= reset plus saillant psychologiquement qu'une saison de 8 semaines pour un joueur à 2-3 runs/sem.

**Adaptation du calibrage** : le target « 1 tier / saison » doit rester valide avec 3 semaines. Deux
options (non bloquantes ici) : (a) réduire les points par tier (~20 pts au lieu de 35) ou (b) garder 35
mais c'est 1 tier / 2 saisons. Les deux sont acceptables — ce n'est pas un litige bloquant.

**Coût** : 1 constante `SEASON_WEEKS` dans `state.lua` [PH]. 0 invariant. Décision éditorial, pas code.

**Garde-fou** : ne pas migrer vers des saisons ultra-courtes (< 2 sem.) — en dessous, le Fresh Start
Effect est annulé par la fréquence (les joueurs perdent le sens du temps saison vs temps de jeu habituel,
Milkman 2014 ibid).

### 3.3 — Spec du démarrage de saison : comportement du FIFO ranked au reset + « Montée des Ombres » — PRIORITÉ 1

**Problème** : collision Fresh Start vs pool vide non documentée (§2.2).

**Proposition** : définir une politique explicite pour le FIFO ranked au reset de saison :

**(a) FIFO ranked = NON VIDÉ au reset.** Les snapshots persistent entre saisons. Seul le `season_id`
dans le snapshot change (champ déjà prévu §6.4 : `version+season_id`). Un snapshot de saison S peut
être servi en saison S+1 sous condition :
- `snap.wins_at_capture ≥ 3` (snapshot d'un joueur établi) : **conservé**.
- `snap.wins_at_capture < 3` : **retiré** (snapshot d'un joueur early qui n'a pas encore de niveau
  de jeu stable).

Ce filtre préserve la densité du pool en début de saison sans altérer l'intégrité (un joueur
d'ascension-8-wins de la saison précédente est un adversaire légitime en début de saison suivante).

**(b) Fenêtre de grâce « Montée des Ombres »** : pendant les **7 premiers jours** de la saison,
le gate `RANKED_MIN_POOL` est remplacé par le mode `SOFT=3` (jamais `indisponible`). Le signal est
🟡 « Pool en réveil — les ombres de la saison passée rôdent encore » (grimdark, justifie le filtre
`wins_at_capture ≥ 3`). Après 7 jours, retour au comportement standard.

**Pourquoi** : la fenêtre de grâce évite la collision « reset + ranked bloqué » qui détruirait
la rétention en début de saison (le joueur qui rouvre le jeu après le reset veut jouer en ranked
immédiatement — c'est le pic du Fresh Start Effect). 7 jours = largement suffisant pour que les
premiers joueurs accumulent 5 nouveaux snapshots ranked.

**Coût** : 1 flag `season_start_grace` (bool, 7 jours après le reset) ; filtre `wins_at_capture ≥ 3`
dans `snapstore:purgeSeason()`. IO hors SIM. **0 invariant de combat.** Zone sans test → ajouter un
test que les snapshots `wins_at_capture < 3` sont bien retirés du pool ranked au reset, et que les
`≥ 3` persistent.

### 3.4 — Récompense cosmétique de FIN DE SAISON (urgence émotionnelle du reset) — PRIORITÉ 2

**Problème** : les marques Survivant/Forgé/Ascendant sont permanentes. Le reset de saison n'a pas
d'urgence émotionnelle — il n'enlève rien de mémoriel (§0 lacune #4).

**Proposition** : à la FIN de chaque saison (avant le reset du rating), distribuer automatiquement
**1 cosmétique daté par joueur ayant joué ≥1 run ranked cette saison** :

| Meilleur résultat | Cosmétique distribué |
|---|---|
| ≥1 Ascension | **Icône de profil « Puits Traversé »** (saison + numéro, grimdark) |
| ≥8 wins en ranked | **Titre « Forgé dans le Puits — Saison N »** (texte) |
| ≥1 run ranked | **Mention « Témoin — Saison N »** (log du Grimoire) |

L'icône/titre est **daté de la saison** → non reproductible en saison suivante → crée la
**rareté temporelle** qui donne de l'urgence au reset (« cette saison sera fermée, c'est ma dernière
chance d'avoir le cosmétique Saison 2 »).

**Pourquoi c'est nécessaire** : sans récompense distribuée à la fin de la saison, le reset est une
perte neutre (−20 % points, marques qui restent). Avec un cosmétique daté, le reset devient un
**événement avec un avant et un après** — ce qui est la définition psychologique d'un temporal
landmark (Dai, Milkman & Riis 2014). Sans cela, le Fresh Start Effect est structurellement absent
même avec un reset mécanique.

**Coût** : RENDER + 1 entrée `grimoire:addSaisonTemoignage(season_id, best_rank)` (IO hors SIM).
0 invariant. Les cosmétiques sont texte/icône = pixel art procédural compatible ou texte pur.
**Zone sans test** → test que `grimoire` enregistre bien le cosmétique au reset (pas avant, pas
après).

**Référence** : LoL ranked rewards saisonniers (emblème/icône) = moteur de rétention #1 citée dans
les études de motivation de joueur (egamersworld.com, cité round-04 §6.2). HS:BG Track saisonnier
= cosmétiques cosmétiques purs, pas de gameplay. Le principe est validé dans tous les jeux qui ont
des saisons.

**Garde-fou** : cosmétiques UNIQUEMENT (zéro gameplay). Aucun item, aucune unité, aucune relique
lockée derrière la récompense — aligné avec le pilier « égalisateurs, pas de gates ».

---

## 4. Points maintenus tels quels (pas de challenge, accord net)

### 4.1 Pas de score intra-run — MAINTENU (6e confirmation)

StS Ascension a abandonné le score classé par run (pousse à optimiser le score, pas le build).
Dota Underlords « ranking mixte » = fragmentation de valeur (postmortems §3.2A). Rien de nouveau
à ajouter. Le verdict est solide.

### 4.2 `slot_tier_composite` matchmaking — MAINTENU

Les rounds 3-4 ont validé le mécanisme. Le composite est monotone croissant (stable à la capture),
plus granulaire que le rang pur du Bazaar. Le fallback descendant 5-étapes est correct.

### 4.3 Contrainte du Jour timezone locale v1 — MAINTENU

Accepter la date locale en v1 (comme SAP Arena / Spell Cascade). UTC au backend P4. Rien à challenger.

### 4.4 Litige #U (Contrainte Permanente de Saison : famille à bas win-rate vs sous-représentée) — MAINTENU OUVERT

Le litige est réel et sa résolution dépend de données post-P0.5 (`win_rate` par famille dans `report.json`).
Ne pas trancher maintenant sans les données. Maintenu.

---

## 5. Questions ouvertes (nouvelles)

### 5.1 [NOUVEAU litige #Y] — Comportement du FIFO ranked entre saisons : persistance filtée vs vidage complet

La proposition §3.3 préconise la persistance filtrée (`wins_at_capture ≥ 3`). Un agent futur pourrait
challenger : « purger complètement le FIFO ranked est plus propre ». Les arguments :
- **Pour la persistance filtrée** : maintient la densité du pool en début de saison, évite le cold-start
  systématique après chaque reset.
- **Pour le vidage complet** : chaque saison est propre ; un snapshot de saison précédente (build
  peut-être obsolète si P0.5 a ajouté `dot_family`) est potentiellement un adversaire mal calibré.

**Arbitre** : le champ `snap.sv` (litige #V, différé) est exactement la solution propre ici — un
snapshot de saison précédente sans `dot_family` dans le schéma est identifiable et ignorable via `sv`.
**Si `sv` est adopté en P0.5 (la recommandation du round-05 §3.1 REJET), le vidage complet devient
safe et préférable.** Si `sv` reste différé, la persistance filtrée par `wins_at_capture` est le seul
garde-fou raisonnable.

**Conséquence** : litige #V (`sv` maintenant vs différé) EST en fait un prérequis du litige #Y. Les
résoudre dans le bon ordre évite de spécifier le FIFO de saison sur une base instable.

→ **Recommandation** : rouvrir le litige #V en P0.5 avec ce nouveau contexte. Si `dot_family` est
ajouté en P0.5, il FAUT `sv=2` pour que les snapshots de saison précédente ne produisent pas de
famille `nil` en ranked post-P0.5.

### 5.2 [NOUVEAU] Cosmétiques de saison : écran de distribution ou log Grimoire ?

La proposition §3.4 dit « 1 cosmétique distribué automatiquement ». Le vecteur de distribution est
important pour la rétention :
- **Écran modal à la fin de saison** : saillant, mémorable, risque d'être dismissé rapidement.
- **Log Grimoire + notification au lancement** : cohérent avec le signal d'appartenance §2.8 (même
  vecteur), moins saillant mais articulé avec la méta-progression existante.

**Recommandation** : **log Grimoire + message au menu** (cohérent avec le signal d'appartenance « ton
spectre a été affronté »). Le Grimoire est le lieu de la méta-progression — les cosmétiques datés
y ont leur place naturelle.

### 5.3 [HÉRITÉ R05, précisé] Condition de mesure du litige #A (P1 types vs P2 ranked)

Le litige #A dit : « `--meta-convergence < 8 runs pour ≥2 sigils` sur méta NON cassée (après
`--poison-frac` ET `--no-weaken`) → types d'abord ». La condition est correcte, mais elle ne précise
pas : mesurer sur les **runs ranked uniquement, runs unranked uniquement, ou les deux** ?

**Position R06** : mesurer sur les **runs unranked libres** (sans contrainte du jour). Les runs ranked
ont un biais de sélection (les joueurs ranked choisissent potentiellement les builds les plus forts →
convergence artificielle vers le meta dominant). Une convergence sur les runs unranked libres est plus
représentative de la variance naturelle. **Ce n'est pas un litige bloquant** — c'est une précision de
mesure à ajouter à la spec du critère #A.

---

## 6. Synthèse des propositions du brouillon v6 (§6) touchant le ranked

| Proposition v6 | Verdict R06 | Action recommandée |
|---|---|---|
| Grille `+4/+2/+1/0` (§6.2) | ACCORD MAINTENU, raisonnement mis à jour | Ne plus citer Bazaar 2025 comme validation — Bazaar a les pénalités. Citer format run-court + FIFO local. |
| Marques sub-tier (§6.2) | ACCORD | Conserver + ajouter la récompense cosmétique datée de fin de saison (§3.4) pour leur donner une urgence. |
| Cadence 6-8 semaines (§6.3) | DÉSACCORD | Migrer vers 3-4 sem. sans nouveau contenu (§3.2). |
| Reset conditionnel `<3 runs` (§6.3) | ACCORD + LACUNE | Ajouter la fenêtre de grâce « Montée des Ombres » 7 jours (§3.3). |
| `RANKED_MIN_POOL=5` (§6.4bis) | ACCORD + AFFINEMENT | Remplacer par SOFT=3/HARD=5 (résout #T, §3.1). |
| Pool ranked FIFO au reset de saison | TROU DE SPEC | Définir politique FIFO : persistance filtrée `wins_at_capture ≥ 3` OU vidage dépendant de `sv` (§3.3 + litige #Y). |
| Récompenses de fin de saison | ABSENT | Ajouter cosmétiques datés (§3.4) pour l'urgence émotionnelle du reset. |
| Signal de pool pré-run 🟢🟡🔴 (§6.5) | ACCORD FORT | Conserver. Intégrer SOFT=3/HARD=5. |
| Contrainte du Jour gating famille (§6.6) | ACCORD | Conserver avec dépendance P0.5 déjà documentée. |
| Contrainte Permanente de Saison (§8.0) | ACCORD + LITIGE #U | Maintenir ouvert. |
| Grimoire 3-chapitres + Chapitre III silhouette (§6.7) | ACCORD | Conserver. Ajouter les cosmétiques datés en Chapitre I (Mentions de Témoin). |

---

## 7. Index des sources R06

| Affirmation | Source vérifiée |
|---|---|
| Bazaar gain ET perte de rank points (2025) | [bazaar-builds.net/ranking-update-reset-item-changes-and-more/](https://bazaar-builds.net/ranking-update-reset-item-changes-and-more/) |
| Bazaar resets mensuels depuis feb 2025 | [bazaar-builds.net/ranking-update-reset-item-changes-and-more/](https://bazaar-builds.net/ranking-update-reset-item-changes-and-more/) |
| Bazaar futures améliorations matchmaking (Wins-Based) | [thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar](https://www.thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar) |
| Bazaar septembre 2025 : rank ≤ joueur pour les ghosts ranked | [bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/](https://bazaar-builds.net/announcement-future-updates-for-the-bazaar-september-10th-patch/) |
| Fresh Start Effect : temporal landmarks motivent | Dai, Milkman & Riis 2014, Management Science 60(10):2563-2582 — [katymilkman.com/journal-articles/the-fresh-start-effect-temporal-landmarks-motivate-aspirational-behavior](https://www.katymilkman.com/journal-articles/the-fresh-start-effect-temporal-landmarks-motivate-aspirational-behavior) |
| Fresh Start Effect décroît si distance perçue trop longue | [anderson-review.ucla.edu/wp-content/uploads/2021/03/Dai-Li_2018_TemporalLandmarks_CurrentOpinioninPsychology.pdf](https://anderson-review.ucla.edu/wp-content/uploads/2021/03/Dai-Li_2018_TemporalLandmarks_CurrentOpinioninPsychology.pdf) |
| Matchmaking + churn : perte amplifie le désengagement sur matchmaking perçu injuste | [pmc.ncbi.nlm.nih.gov/articles/PMC10839887/](https://pmc.ncbi.nlm.nih.gov/articles/PMC10839887/) |
| SAP Update 0.28 : ranked lancé + matchmaking changements | [store.steampowered.com/news/app/1714040/view/3689065475857403445](https://store.steampowered.com/news/app/1714040/view/3689065475857403445) |
| Backpack Battles : matchmaking dégradé en Diamond+ (pool trop petit) | [thegamer.com/backpack-battles-ranks-explained-guide/](https://www.thegamer.com/backpack-battles-ranks-explained-guide/) |
| LoL ranked rewards saisonniers = moteur rétention #1 | cité round-04 §6.2 — egamersworld.com/league-of-legends/ranked-rewards-2025 |
| Nunes & Drèze 2006, Endowed Progress Effect — horizon < ~7 étapes | JCR (cité rounds 1-5, maintenu) |

**Sources rounds 1-5 conservées** : bazaar-builds.net/did-you-know-how-ghosts-work ; Kahneman-Tversky
(perte 2,3×) ; SDT 2024 Möller et al. ; Kao et al. 2024 CHI ; Smashing Magazine 2026 UX streaks ;
seganerds.com 2026 (incertitude résoluble) ; Nunes & Drèze 2006 ; StS Ascension abandon score classé ;
postmortems Dota Underlords §3.2A.

---

## 8. Nouvelles décisions proposées pour intégration dans la roadmap

| Décision | Section roadmap | Priorité |
|---|---|---|
| **Raisonnement grille sans pénalité mis à jour** : ne plus citer Bazaar 2025 (a les pénalités), citer format run-court + FIFO local | §6.2 | Correction doc immédiate |
| **Cadence de saison : 3-4 sem. sans contenu / 6-8 sem. avec contenu** | §6.3 | P2 spec |
| **Fenêtre de grâce « Montée des Ombres » 7 jours** au démarrage de saison (`RANKED_MIN_POOL` → SOFT seulement) | §6.4bis / §6.3 | P2 spec |
| **FIFO ranked au reset : persistance filtrée** (`wins_at_capture ≥ 3`) OU vidage complet si `sv` adopté en P0.5 (litige #Y) | §6.3 / §5 snapshot | P2 spec (après litige #Y/#V) |
| **RANKED_MIN_POOL progressif** : SOFT=3 (🟡 Pool Mince) / HARD=5 (🔴 indisponible) — clos litige #T | §6.4bis / §6.5 | P2 |
| **Cosmétiques datés de fin de saison** (Icône/Titre/Mention) — urgence émotionnelle du reset | §6.2 + §6.7 Grimoire | P2 |
| **Litige #Y** : FIFO ranked persistance filtrée vs vidage selon `sv` | nouveau | P2 (avant spec FIFO de saison) |
| **Litige #V re-priorisé** : `sv` est maintenant lié à #Y — doit être décidé AVANT la spec du FIFO de saison | §5 snapshot + §6.3 | P0.5 (re-évaluer) |
| **Litige #A précisé** : mesurer `--meta-convergence` sur les **runs unranked libres** uniquement (éviter biais de sélection ranked) | §1 §litige #A | P0.5 (précision spec) |

---

## 9. Récapitulatif des litiges

| # | Litige | Statut R06 |
|---|---|---|
| **#T** | `RANKED_MIN_POOL` = 3 vs 5 | **CLOS par §3.1** : SOFT=3/HARD=5 progressif |
| **#Y** | **NOUVEAU** : FIFO ranked entre saisons — persistance filtrée vs vidage + dépendance `sv` | **Ouvert** ; lié à #V |
| **#V** | `sv` maintenant vs au 1er champ persisté | **RE-PRIORISÉ** : lié à #Y, doit précéder la spec FIFO de saison → à décider en P0.5 |
| **#U** | Saison : famille à bas win-rate vs sous-représentée | Maintenu ouvert (données P0.5 requises) |
| **#A** | P1 types vs P2 ranked | Maintenu ouvert ; précision : mesurer sur runs unranked libres |

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 6/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont RENDER/IO/data hors SIM.*
*Zones sans test nouvelles signalées : §3.1 (signal SOFT/HARD) ; §3.3 (FIFO persistance filtrée +*
*fenêtre de grâce) ; §3.4 (cosmétique distribué au Grimoire au reset).*
*Sources web vérifiées : bazaar-builds.net (feb+sep 2025), thebazaargame.net, PMC10839887, katymilkman.com,*
*anderson-review.ucla.edu, steampowered.com SAP, thegamer.com Backpack.*
