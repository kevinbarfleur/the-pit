# Round 02 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v2, intégré round 1),
> `round-01.md` (synthèse), `rounds/r01-retention-addiction.md`, `competitive/balatro.md`,
> `competitive/super-auto-pets.md`, `competitive/slay-the-spire.md`.
>
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.
>
> **Posture** : challenger adversarial du brouillon v2 ET de la synthèse round 1, pas
> une reformulation. Là où le round 1 a accepté trop vite, je le signale.

---

## 0. Position de l'agent

Le brouillon v2 et la synthèse round 1 ont bien intégré les critiques du round 1 sur
la méta-progression (Grimoire de connaissance plutôt que puissance) et le pity-tracker.
Mais **trois zones restent sous-étayées ou mal calibrées** du point de vue rétention :

1. Le **highroll explicite** n'est pas traité comme un pilier de rétention — c'est une
   omission majeure que le round 1 n'a pas pointée. Sans moment mémorable de puissance,
   pas de « je dois retrouver ce feeling ».
2. La **stagnation méta** est sous-traitée : le brouillon reformule le litige #A en
   « rotation vs stagnation » mais ne chiffre pas le risque réel, ne propose pas de
   mesure concrète, et confond deux niveaux de variance (intra-run vs inter-run).
3. Le **Codex des synergies adopté** (12 interactions) a un problème de **visibilité
   initiale** que le round 1 a effleuré (Q4) mais que le brouillon n'a pas résolu. Un
   Grimoire que personne ne sait explorer ne retient pas.

---

## 1. ACCORDS — ce qui tient pour nos contraintes (avec le POURQUOI précis)

### 1.1 Accord fort : Grimoire = progression de connaissance, pas de puissance

**Accord avec ROADMAP-draft v2 §6.7 ; round-01.md §1.10 ; r01-retention-addiction §2.2.**

La synthèse round 1 a correctement démoli les unités T5 lockées. Le choix Grimoire-codex
est psychologiquement sain : la littérature distingue la méta-progression de *puissance*
(buff permanent cross-run) de la méta-progression de *connaissance* (ce que j'ai appris
sur le système). Kammonen 2023 (theseus.fi) documente que la progression de puissance
floue la lisibilité du skill — le joueur ne sait plus s'il a gagné par compétence ou
par accumulation. Le Grimoire de connaissance préserve cette lisibilité.

**Ce qui tient pour The Pit** : les 12 interactions de `tests/synergies.lua` sont
des faits *sur le système*, pas des bonus. Les découvrir ne rend pas le joueur plus
fort — ça le rend *plus expert*. C'est la bonne distinction, et c'est ici que le
Grimoire a un potentiel très élevé de rétention à long terme (« je suis l'un des rares
à connaître toutes les synergies »). Accord total avec le maintien de cet axe.

**NUANCE importante non adressée par le round 1** : la progression de connaissance
a un **plafond d'engagement** que la progression de puissance n'a pas. Une fois les
12 synergies connues, le Grimoire ne retient plus. Le brouillon suppose que les ~30
interactions de type (P1) l'étendront naturellement — c'est probable mais pas garanti.
→ Voir §2.3.

### 1.2 Accord fort : run de 10 victoires = arc complet = one-more-run sain

**Accord avec ROADMAP-draft v2 §6.1 ; SAP §1.2 ; r01-retention-addiction §1.4.**

La durée contrôlée (10 victoires ou 5 défaites) crée le format psychologiquement optimal
pour le one-more-run. La littérature récente (Polygon 2025 — « Why losing in roguelikes
feels like winning ») et les études de Dr. Sood/Lichtman confirmées en 2025 identifient
la **brièveté des runs** (~15-20 min) comme le principal facilitateur du « juste encore
un ». Une run trop longue transforme le sunk cost en frein, pas en moteur.

**Ce qui tient pour nos contraintes** : `WIN_TARGET=10`, `START_LIVES=5`, pas de mode
Endless. Le format async renforce même le one-more-run : la session de jeu n'a pas de
timer social (pas de lobbies qui attendent). La mort d'un run est nette, le restart est
immédiat. Correct et bien calibré.

### 1.3 Accord : near-miss de duplicata sous agence = mécanisme sain avec signal visible

**Accord avec round-01.md §1.7 ; r01-retention-addiction §2.1 ; ROADMAP-draft v2 §7.3.**

Le pity-tracker visible (adopté en synthèse) est la bonne réponse. La littérature
(Springer/NIH 2020 ; Psychology of Games, Madigan 2016) confirme que le near-miss
sans signal visible est de la frustration plate, identique au near-miss pathologique
de machine à sous. Avec un signal (« +5 % de cote par reroll au-delà du 8e »), le
même phénomène devient de l'anticipation constructive. La distinction psychologique
est réelle.

**Ce qui tient** : le mécanisme de pity soft ancré sur le **seed** (pas sur l'accumulation
de session) préserve le déterminisme (invariant #2). La proposition Prop-A du round 1
est correcte et bien architecturée.

**NUANCE** : la calcul du seuil (8 rerolls) reste arbitraire. Le round 1 a bien posé
le problème (~12 rerolls médians pour rang-3 en T3) mais le seuil « 8 rerolls avant
déclenchement » n'est pas défini par la sim. Voir §3.1.

### 1.4 Accord : lisibilité du « pourquoi j'ai perdu » = P0 obligatoire, pas optionnel

**Accord avec ROADMAP-draft v2 §2.4 ; r01-retention-addiction §1.2.**

La carte de risque visuelle (gradient d'exposition + arêtes actives) et le résumé
post-combat depuis le bus sont des préconditions de la rétention basée sur la compétence.
La recherche de Jesper Juul (« Fear of Failing ? », jesperjuul.net) documente que les
joueurs préfèrent *de loin* attribuer leur défaite à leur propre erreur qu'au hasard.
L'attributabilité causale = rétention. Le déterminisme de The Pit est un avantage
structurel ici : le post-mortem est *exact*, pas une estimation.

---

## 2. DÉSACCORDS — ce qui est faible, manquant ou mal calibré

### 2.1 DÉSACCORD FORT : le HIGH-ROLL est absent du brouillon v2 — c'est une omission structurelle

**Ce que le brouillon propose** : la rétention repose sur la lisibilité (P0), les types
(P1), les reliques complètes (P1.5), le ranked (P2). Nulle part le brouillon ne parle
de **moments de puissance mémorables** comme pilier de rétention en soi.

**Le problème** : la recherche sur la rétention des roguelites distingue systématiquement
deux couches de motivation :
- **Base** : agence, attributabilité, progression de connaissance.
- **Pic** : le *high-roll*, le moment où un build « explose » d'une façon qui dépasse
  les attentes du joueur.

La littérature (ejaw.net 2026 sur Balatro ; Roguelike Celebration 2024, talk
« Life, Liberty, and the Pursuit of Comboness », C. Dotal) documente que ce « good
cheat sensation » (le sentiment d'avoir *brisé* le jeu sans *détruire* le jeu) est
l'un des deux vecteurs principaux du replay compulsif dans les roguelites.

> « That gap between perceived skill and actual skill depth is the engine that drives
> 400-hour playtimes. » — ejaw.net, analyse Balatro 2026

Dans The Pit, le high-roll existe *en puissance* : une unité T3 de niveau 3 avec aura
d'adjacence et relique ampli + propagation poison peut décimer une équipe entière.
**Mais ce moment n'est pas rendu *mémorable* dans l'UI.** Il se produit dans une
animation de combat que le joueur regarde passivement. Sans VFX distinctif, sans score
affiché, sans récapitulatif post-combat qui met en valeur le combo qui a fonctionné,
le high-roll de The Pit ne *marque* pas.

**Verdict** : le brouillon traite les VFX afflictions (the-pit-affliction-vfx, mémoire)
comme un chantier séparé et ne l'ancre pas dans la rétention. C'est une erreur de
séquencement. Le **feedback de puissance** n'est pas décoratif — c'est le signal qui
déclenche le « je dois retrouver ça ». Il manque dans la roadmap v2 en tant que
**chantier de rétention explicite**, pas juste comme polish UI.

**Source adversariale** :
- ejaw.net (2026-03-03) : « Give players a rocket ship, but make them learn to fly it. »
  Le high-roll doit être *hard-earned* pour être mémorable, pas trivial.
- Roguelike Celebration 2024, C. Dotal : un combo est « non-obvious » par définition.
  L'UI doit rendre la non-obviousness *visible après coup* pour déclencher le replay.
- medium.com/@yyh19971004 (2026-02) : les effets visuels de Balatro « transforment une
  opération mathématique en expérience sensorielle » ; sans eux, le jeu reste fun mais
  moins mémorable. Pour The Pit : les chainages DoT + propagation à la mort sont le
  *contenu* du high-roll. Sans signal amplifié, ils passent inaperçus.

**Proposition concrète** : ajouter au post-combat un **Moment du Run** — la séquence
d'événements la plus longue déclenchée en chaîne (ex. « Bleed → Rot consommé →
propagation à la mort → 3 unités tuées dans le même tick »). Calculé depuis le bus
JSONL (déterministe, déjà structuré). Zéro SIM, RENDER uniquement. Ce signal est le
haut-roll *nommé* — il devient une raison de revenir.

### 2.2 DÉSACCORD MODÉRÉ : la stagnation méta est sous-traitée — le litige #A est mal cadré

**Ce que le brouillon dit** : le litige #A est reformulé en « rotation vs stagnation »
(round-01.md §3, ROADMAP-draft v2 §1, §12.1). La résolution proposée : sim « compo
dominante par sigil » — si 5 sigils = 5 métas distinctes, le ranked peut précéder les
types.

**Ce qui est faible** : le brouillon *confond deux niveaux de variance* qui répondent
à des besoins psychologiques différents.

**Niveau 1 — variance INTRA-RUN** : à l'intérieur d'un run, est-ce que deux runs avec
le même sigil produisent des builds différents ? C'est principalement assuré par
l'aléa de boutique + le seed de run + les reliques proposées.

**Niveau 2 — variance INTER-RUNS** : est-ce que la méta (builds dominants par sigil)
change au fil du temps ? C'est le problème de la stagnation méta — une fois qu'un joueur
avancé a « solved » le sigil Croix (composition poison carry + tank taunt, positions
optimales), tous ses runs Croix sont des exécutions de la même solution.

La sim « compo dominante par sigil » mesure le **niveau 1** (un seul sigil a-t-il un
build universel ?), pas le **niveau 2** (la méta change-t-elle sans contenu nouveau ?).

**Preuve que le problème est réel** : TFT est l'exemple de référence. Riot a documenté
explicitement que sans rotation de sets, la méta « becomes increasingly solved and
matches could start to feel repetitive » (teamfighttactics.leagueoflegends.com,
« /dev: Design Pillars of TFT »). Leurs mises à jour de patch bihebdomadaires ont
précisément pour rôle de déstabiliser la méta entre les sets.

The Pit a **zéro équivalent de ce vecteur de déstabilisation** entre v0.9 et v0.12.
Les 5 sigils sont fixes, les 83 unités sont fixes, les 21 reliques sont fixes. Même
avec les types (P1), une fois que les paliers de type sont découverts, la méta se
stabilise à nouveau — elle se stabilise à un niveau plus riche, mais elle se stabilise.

**Ce qui tient malgré tout** (et que le round 1 a bien vu, r01-retention-addiction §2.5) :
le brouillon propose la daily seedée comme moteur anti-stagnation. SAP a tenu 2 ans sans
ranked grâce à son Weekly Pack (rotation lundi, `superautopets.wiki.gg/wiki/Weekly_Pack`)
— mais The Pit n'a pas d'équivalent direct immédiat.

**Verdict** : le brouillon v2 nomme le litige mais propose une **mesure qui ne mesure
pas ce qu'il faut mesurer**. La sim « compo dominante par sigil » est nécessaire mais
pas suffisante. Il faut y ajouter une mesure de **vitesse de résolution** : dans le
fuzz 250 combats, combien de rounds un joueur expert (score optimal) met-il pour
trouver la compo dominante d'un sigil donné ? Si < 5 runs, la méta se stabilise trop
vite même avec les types.

**Proposition concrète** : ajouter un drapeau de sim spécifique : « taux de convergence
méta par sigil » = nombre de runs simulés pour que `win%(compo_top_3) > win%(compo_mid)
+ 2σ ». Si la convergence arrive < 5-8 runs, introduire **un mécanisme léger de variance
forcée** sans rotation lourde : par exemple, pour chaque run, 2-3 unités de rang 5 sont
exclues du pool (tirées au seed de run — déterministe, Golden-safe si gated). Cela
déstabilise la méta sans nécessiter de contenu nouveau.

### 2.3 DÉSACCORD MODÉRÉ : le Codex de synergies a un problème de BOOTSTRAP — le round 1 l'a vu mais pas résolu

**Ce que le brouillon dit** (ROADMAP-draft v2 §6.7) : tracker les 12 interactions
synergies.lua → badge + flavor grimdark. 12/12 = accomplissement.

**Le problème** : le round 1 (r01-retention-addiction §4, Q4) avait posé la question
sans la résoudre : « Si le joueur ne sait pas que les 12 interactions existent, il ne
cherchera pas à les découvrir. »

La brouillon v2 **ne résout pas ce problème**. Il dit que le Codex « enrichit le run
courant » — mais seulement si le joueur sait qu'il y a quelque chose à découvrir. Dans
l'état actuel, les interactions synergies se produisent en combat auto (spectateur) sans
signal distinct. Un joueur débutant verra « bleed → rot consommé » se produire sans
comprendre que c'est un événement spécial, sans savoir que 11 autres interactions l'attendent.

**Preuve par analogie** : The Binding of Isaac est l'exemple référence de la progresson
de connaissance sans puissance. Mais TBOI maintient l'engagement grâce à une **communauté
wiki** qui documente les synergies (la « méta-connaissance » est externalisée vers Reddit/
wikis). Kammonen 2023 et Arvid Åslund 2026 (his.diva-portal.org) notent que TBOI « takes
considerably more time and investment » pour que la motivation s'engage — précisément
parce que la progression de connaissance n'est pas visible in-game.

The Pit ne peut pas s'appuyer sur une communauté wiki au lancement. Le Codex doit donc
**auto-scaffolder la découverte**, pas seulement la récompenser rétrospectivement.

**Proposition concrète** (amélioration de Prop-B du round 1) :
- Quand une interaction se produit pour la première fois, un **flash d'accroche** dans
  la zone de log combat (nom de l'interaction en 2-3 mots, flavor grimdark, disparait
  en 3s). Ex. « SANGUIN CORROSIF » pour bleed→rot. Cela **nomme** l'événement sans
  interrompre le spectacle.
- Dans l'écran de résultat, « Découverte : SANGUIN CORROSIF (1/12 synergies connues) »
  avec un lien vers l'entrée Grimoire.
- Dans l'onglet Grimoire, les interactions inconnues affichent une **silhouette** avec
  leur emplacement de famille (ex. « ??? — famille Saignement × Pourriture »), pas une
  liste vide. Cela crée un horizon d'exploration visible, identique au « Joker unknown »
  de Balatro.

Ces trois ajouts sont RENDER uniquement, zéro SIM. Ils rendent le Codex *agentiel* dès
le premier run, au lieu d'être une récompense passive pour les joueurs experts.

### 2.4 DÉSACCORD FORT (challenge du round 1) : la grille de score ranked « sans pénalité » est CORRECTE mais INSUFFISAMMENT ANCREE sur le one-more-run

**Ce que le round 1 a adopté** (round-01.md §1.3) : `+4/+2/+1/0`, jamais de pénalité.
La synthèse cite SAP post-v0.41 (store.steampowered.com 2025) comme référence.

**Ce qui est faible** : SAP n'a pas de ranked score — il a des **trophées** (win/loss
binaire). La référence « SAP n'impose pas de pénalité sur les runs courtes » est
correcte (pas de pénalité de run), mais elle ne valide pas la *grille de score spécifique*
(`+4/+2/+1/0`). C'est une extrapolation, pas une transposition directe.

**Le vrai problème de rétention** de la grille `+4/+2/+1/0` : elle crée une **pente
d'ascension trop plate pour la zone 0-5 victoires**. Un joueur en apprentissage qui
fait 4-5 victoires régulièrement reçoit **0 point de ranked** — il ne voit aucune
progression pendant des semaines si son run typique est dans cette plage. Or, la
littérature sur la rétention des roguelites (diva-portal.org 2021 ; essays.se 2026)
montre que la **progression visible** (même micro) est le principal vecteur de
rétention des joueurs intermédiaires — ceux qui ne font pas encore l'ascension mais
qui ne sont plus débutants.

Une grille `+4/+2/+1/0` sans rien en dessous de 6 victoires dit au joueur moyen :
« tu n'existes pas dans le classement tant que tu ne fais pas les 2/3 du run ». C'est
un vide de feedback pour la population qui a le plus besoin de rétention.

**Proposition concrète** : différencier **ranked** et **score de progression personnelle**
visible :
- Le **ranked global** reste `+4/+2/+1/0` (pas de pénalité — correct, conservé).
- Ajouter un **score de saison personnel** qui comptabilise *toutes* les victoires
  (même les runs avortées à 3 victoires) : `saison_wins += nb_wins_ce_run`. C'est un
  compteur brut affiché sur l'écran de run (« 37 victoires cette saison »). Il monte
  toujours. Il ne remplace pas le ranked — il comble le vide de feedback pour les runs
  courtes. RENDER + IO hors SIM, zéro invariant.

**Source adversariale** : Polygon 2025 (psychologie roguelikes) : « getting little
pieces of story [...] the sense of getting a little bit further next on this run ». La
progression *visible même sur les runs perdantes* est le moteur de la rétention en
zone intermédiaire. La grille ranked, par définition, ne le fournit pas.

### 2.5 DÉSACCORD LÉGER : la daily seedée a un problème d'EQUITE DES GHOSTS non traité

**Ce que le brouillon dit** (ROADMAP-draft v2 §6.6) : run quotidien à seed identique
pour tous, leaderboard éphémère 24h, ghosts présélectionnés le matin.

**Le problème** : la sélection des ghosts présélectionnés le matin est un **choix
éditorial** qui n'a pas de critère objectif dans le brouillon. Si les ghosts daily
sont tous des builds hyper-optimisés (top-tier du pool ranked), le joueur moyen fait
une run « punition » qui ne reflète pas sa progression normale. Si les ghosts sont
trop faciles, le leaderboard ne mesure pas le skill.

**Ce qui manque** : un critère de sélection des ghosts daily. La proposition la plus
propre (et compatible avec notre déterminisme) : les ghosts daily sont servis par
**bucket de progression** à l'identique du ranked (`wins_at_capture`, mais les ghosts
daily ont un range forcé à `wins_at_capture ∈ [3, 7]` — milieu de run, ni débutant
ni ascension). Cela garantit que tous les joueurs ont des adversaires d'un niveau de
run similaire, quel que soit leur rang. Le leaderboard mesure alors l'*efficience*
(score daily = `wins × (10 - lives_lost) × (1+xp_spent)`) sur des adversaires de
difficulté homogène.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — Highroll Nommé : « Moment du Run » au post-combat (P0, RENDER, hors SIM)

**Ce** : lire le bus JSONL du combat terminé pour identifier la **chaîne d'événements
la plus longue déclenchée en cascade** (ex. : unité A tue B → `on_death` propage
burn → burn tue C → C propage poison → etc.). Afficher dans l'écran post-combat :
**« MOMENT DU RUN — CORRUPTION EN CHAINE (5 unités) »** + flavor grimdark
(2-3 mots) + nombre d'unités touchées. Si aucune chaîne > 2 événements : pas de moment
affiché (éviter l'inflation).

**Pourquoi** : sans cette récompense post-hoc, le high-roll n'est pas mémorable.
« Give players a rocket ship, but make them learn to fly it » (ejaw.net 2026). The Pit
a le rocket ship (propagation en cascade, DoT cross-familles). Il n'a pas encore la
*photo du décollage*. Ce signal déclenche le replay : « je veux retrouver ce combo ».

**Chiffre** : le bus JSONL existe (`tools/eventlog.lua`). Calcul de la chaîne max =
lecture de la liste d'événements triée par timestamp, groupement par `cause` chaînée.
RENDER uniquement. Aucun invariant SIM touché. Test à ajouter : que la chaîne max
est correctement identifiée sur le golden connu (empreinte 970156547).

**Priorisation** : P0 (peut se faire pendant que les types sont conçus, coût faible,
impact élevé sur le « je dois retrouver ça »).

### Proposition B — Drapeau de sim « vitesse de résolution méta par sigil » (P3, avant tuning)

**Ce** : ajouter à `tools/sim.lua` un mode `--meta-convergence` qui :
1. Génère N=200 runs par sigil (5 × 200 = 1000 runs) avec le roster actuel.
2. Pour chaque sigil, calcule `win%(compo_top_1)` et `win%(compo_top_3)` au fil des
   rounds simulés.
3. Mesure à quel N la courbe `win%(top_1) - win%(pool_moyen)` dépasse `+2σ` de façon
   stable → c'est le **rang de convergence méta**.

**Critère d'alarme** : si `rang_convergence < 8 runs` pour un sigil, ce sigil a une
méta trop vite résolue → ajouter une exclusion aléatoire de 2 unités rang-5 par run
(seedée, gated → Golden-safe).

**Pourquoi** : le litige #A ne peut pas être tranché sans cette mesure. La sim actuelle
mesure le win% unitaire, pas la *vitesse de convergence stratégique* — ces deux choses
ne se corrèlent pas nécessairement.

**Priorisation** : P3 (outillage sim, pas de code moteur), mais **à coder avant de
figer P1 (types)** : si les sigils convergent trop vite même sans types, les types
n'aident pas sur la stagnation inter-runs, seulement sur la richesse d'un run individuel.
→ Tranche le litige #A avec des données.

### Proposition C — Bootstrap du Codex : nommer les interactions inconnues (P2, RENDER)

**Ce** : dans l'onglet Grimoire (onglet Synergies, à créer) :
- **Interactions connues** : nom complet + description + flavor grimdark.
- **Interactions inconnues** : `« ??? — [famille A] × [famille B] — à découvrir en
  combat »`. La famille est affichée, pas l'effet. Cela crée un horizon d'exploration
  lisible sans spoiler la mécanique.

**Flash d'accroche en combat** : quand une interaction se produit pour la 1re fois,
dans la zone de log combat, un badge 2s : `« [DÉCOUVERTE] CORRUPTION SANGUIN »`. Zéro
interruption du spectacle, maximum d'impact.

**Dans l'écran de résultat** : badge « Synergies découvertes cette run : 2 » (liste).

**Chiffre** : 12 interactions initiales. Extensions naturelles avec P1 (types) → ~30
interactions. Zéro SIM. RENDER + lecture bus. Écriture dans `grimoire.lua` (hors SIM).
Aucun invariant touché.

**Priorisation** : P2 (après le Codex de synergies adopté en §6.7 du brouillon, qui
doit d'abord exister).

### Proposition D — Score de saison personnel visible (P2, RENDER + IO)

**Ce** : ajouter dans `state.lua` un compteur `season_wins` qui incrémente de
`nb_wins_ce_run` à chaque `resolve()`, quel que soit l'issue (victoire ou chute). Ce
compteur est affiché dans l'écran de menu et l'écran de fin de run : « 37 victoires
cette saison ». Reset au changement de saison (reset partiel −20 % rating = reset
complet du `season_wins`).

**Pourquoi** : comble le vide de feedback pour les joueurs intermédiaires (0-5 victoires
régulières) que la grille `+4/+2/+1/0` ne couvre pas. Une progression qui monte toujours
crée un vecteur de rétention distinct du ranked. Permet aussi de mesurer l'engagement
réel de la saison (un joueur à `season_wins=0` ne joue plus → seuil de churne visible).

**Priorisation** : P2 (naturellement lié au ranked v1). Coût : minimal (1 variable d'état
+ affichage RENDER). Aucun invariant SIM touché.

### Proposition E — Critère de sélection des ghosts daily par range `wins_at_capture` (P2)

**Ce** : les ghosts présélectionnés pour la daily quotidienne ont `wins_at_capture ∈ [3, 7]`
(hardcodé dans la présélection du matin). Cela garantit une difficulté homogène pour
tous les joueurs de la daily, quel que soit leur rang.

**Pourquoi** : sans critère, les ghosts daily sont soit trop faciles (débutants), soit
trop durs (top-ranks), rendant le leaderboard éphémère non équitable. Ce critère
minimal rend la daily mesurable (efficience vs un niveau de run comparable pour tous).

**Priorisation** : P2 (intégré dans la conception de la daily, avant implémentation).

---

## 4. QUESTIONS OUVERTES non résolues par ce round

1. **Q1 — Seuil optimal du pity-tracker** : le round 1 adopte « 8 rerolls » sans le
   valider par sim. Quelle est la bonne valeur ? Critère proposé : la médiane de hunt
   des unités les plus recherchées (rang-3 en T3) doit être < 2× le seuil de pity pour
   que le signal « presque » soit crédible et non angoissant. À valider avec `tools/sim.lua`
   en mode `--hunt-median --tier 3 --rank 3`.

2. **Q2 — Plafond d'engagement du Codex de connaissance** : une fois les 12 synergies
   (puis ~30 avec P1) connues, qu'est-ce qui retient ? La littérature (diva-portal.org 2026)
   montre que la progression de connaissance pure mène à un plateau plus abrupt que la
   progression de puissance. Les reliques G (P4) et les saisons apportent une réponse —
   mais à quelle *cadence* ? À modéliser avant P4.

3. **Q3 — Effet de l'absence de feedback sensoriel sur le high-roll en spectateur** :
   dans un autobattler full-auto, le joueur regarde le combat. Sans VFX distinctif des
   chainages DoT + sans audio (muet probable sur mobile), le high-roll est-il perçu ?
   La réponse dépend de la DA grimdark : les afflictions VFX existants (the-pit-affliction-vfx)
   couvrent-ils suffisamment les chainages ou faut-il un VFX de chaîne dédié ?

4. **Q4 — Tranche du litige #A par la sim** : la sim « compo dominante par sigil »
   (Prop-B) doit être menée AVANT de décider si ranked (P2) peut précéder types (P1).
   Le critère de décision est : `rang_convergence < 8 runs` pour ≥ 2 sigils → types
   d'abord ; sinon → ranked peut précéder. Trancher avec ce critère au round 3.

5. **Q5 — Interaction Codex × Grimoire existant** : le Grimoire actuel (`src/core/grimoire.lua`)
   track les reliques identifiées cross-run. L'onglet Synergies du Codex serait un second
   onglet du même écran (the-pit-ui-da-layer, mémoire : « codex 2 onglets »). La structure
   est déjà prévue — mais le contenu Synergies n'y est pas encore conceptualisé. À aligner
   avec P2 (Codex §6.7 du brouillon).

---

## 5. SYNTHESE DU CHALLENGE CLÉ

Le brouillon v2 traite correctement la méta-progression (Grimoire de connaissance),
le pity-tracker, et la grille ranked sans pénalité — mais il **manque le pilier
émotionnel central de la rétention des roguelites** : le moment de puissance mémorable
(high-roll) qui déclenche le replay. Sans « Moment du Run » nommé et visible dans le
post-combat, les combinaisons de DoT en cascade de The Pit sont fonctionnelles mais
pas *mémorables* — or la mémorabilité du run est exactement ce qui provoque le
« je dois retrouver ça ». Deuxièmement, la stagnation méta est traitée comme un litige
à résoudre par sim « compo dominante » mais la mesure proposée ne capte pas la
*vitesse de résolution stratégique* qui est le vrai risque de désengagement inter-runs ;
sans drapeau de convergence méta, on ne sait pas si les 5 sigils produisent une
diversité réelle ou juste 5 niveaux du même puzzle résolu en 3 runs.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss, méta-progression Grimoire, one-more-run). Lecture seule du repo. N'édite
que sous `docs/roadmap-lab/`. Garde-fous : piliers async/déterministe/grimdark/procédural
préservés, 32 invariants non touchés. Tout le code cité = lectures, pas modifications.*

*Sources web consultées ce round* :
- ejaw.net (2026-03-03, Why Balatro's Low-Key Difficulty is a Masterclass) :
  https://ejaw.net/balatro/
- Roguelike Celebration 2024, C. Dotal « Life, Liberty, and the Pursuit of Comboness » :
  https://speakerdeck.com/cedotal/life-liberty-and-the-pursuit-of-comboness-roguelike-celebration-2024-talk
- Polygon 2025 « Why losing in roguelikes feels like winning » :
  https://www.polygon.com/psychology-roguelikes-punishment-into-reward/
- diva-portal.org 2026 (thèse sur Hades 2 vs TBOI meta-progression) :
  https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf
- essays.se 2026 (méta-progression et player experience, Åslund) :
  https://www.essays.se/essay/6d9ac81240/
- Kammonen 2023 (theseus.fi, méta-progression roguelites) :
  https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
- TFT /dev Design Pillars (Riot, stagnation méta sans rotation) :
  https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-design-pillars-of-tft/
- Jesper Juul « Fear of Failing » (attributabilité de l'échec) :
  https://jesperjuul.net/text/fearoffailing/
- Psychology of Games, Madigan 2016 (near-miss et rewards) :
  https://www.psychologyofgames.com/2016/09/the-near-miss-effect-and-game-rewards/
- Springer 2020 (near-miss slot machines) :
  https://link.springer.com/article/10.1007/s10899-019-09891-8
- superautopets.wiki.gg/wiki/Weekly_Pack (SAP Weekly Pack rotation) :
  https://superautopets.wiki.gg/wiki/Weekly_Pack
- medium.com/@yyh19971004 (Balatro design analysis, VFX et feedback) :
  https://medium.com/@yyh19971004/balatro-design-analysis-visual-packaging-and-interactive-feedback-cc6fa6a65370
