# Round 04 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v4, intégré round 3),
> `round-03.md` (synthèse), `rounds/r01-retention-addiction.md`,
> `rounds/r02-retention-addiction.md`, `rounds/r03-retention-addiction.md`,
> `competitive/*.md` (tous les 10 teardowns).
>
> **Recherche web menée ce round** :
> - Déclos 2025 (British Journal of Aesthetics, spectating games as gameplay) :
>   https://philarchive.org/rec/DECSGC
> - Kao et al. 2024 (CHI, juicy feedback motivators — effectance, competence, curiosity) :
>   https://nickballou.com/publication/2024-kao-et-al-juicy/
> - Nature Scientific Reports 2025 (difficulty-expectation disparity, learning progress) :
>   https://www.nature.com/articles/s41598-025-14628-2
> - Nature Scientific Reports 2024 (Wordle goal gradient + near-miss, Boyle et al.) :
>   https://www.nature.com/articles/s41598-024-74450-0
> - Springer 2020 (near-miss video game Finserås) :
>   https://link.springer.com/content/pdf/10.1007/s11469-019-00070-9.pdf
> - MDPI 2025 (Inherent Addiction in Gacha, pity et VRR) :
>   https://www.mdpi.com/2078-2489/16/10/890
> - Åslund 2026 (essays.se, heavy vs minimal meta-progression) :
>   https://www.essays.se/essay/6d9ac81240/
> - Diva-portal 2026 (Hades 2 vs TBOI meta-progression) :
>   https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf
> - Yonkers Times 2025 (spectator gaming design analysis) :
>   https://yonkerstimes.com/when-games-dont-need-you/
> - Grid Sage Games (Kyzrati 2025, mastery in roguelikes) :
>   https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/
> - SAP Wiki (Weekly Pack, Arena mode déterminisme) :
>   https://superautopets.wiki.gg/wiki/Weekly_Pack + /wiki/The_Basics
> - Reynad interview (async PvP design philosophy) :
>   https://noisypixel.net/the-bazaar-interview-reynad-asynchronous-pvp-deckbuilder/
>
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.
>
> **Posture adversariale** : les rounds 1-3 ont adopté trois mécanismes de rétention
> solides (Moment du Run ancré à l'unité-source, Codex bootstrappé, pity-signal sans
> garantie). Ce round 4 attaque les hypothèses psychologiques qui RESTENT non éprouvées
> après trois rounds de convergence — en particulier la question de l'agence dans un
> spectacle déterministe, la modélisation de la meta-stagnation, et les trois litiges
> ouverts liés à la rétention (#G axe choc, #L pity seedé, Q1 seuil de chaîne).

---

## 0. Position de l'agent

Les rounds précédents ont livré et sourcé une couche de rétention cohérente :

1. **Moment du Run ancré à l'unité-source** (ADOPTÉ, r03 §1.10) — le mécanisme de
   post-hoc attribution (« *mon* unité a fait ça ») est psychologiquement distinct du
   VRR pur, et c'est une bonne chose : il survit au contexte spectateur.
2. **Codex bootstrappé avec silhouettes** (ADOPTÉ, r02 §1.12) — l'horizon d'exploration
   visible (Zeigarnik) est bien ancré.
3. **Pity = signal sans garantie, cappé ×1.5, à 50-60 % du hunt médian** (ADOPTÉ, r03
   §1.11/#L) — la double démonstration par deux lentilles est solide.
4. **Post-combat « pourquoi » en co-priorité 1** (ADOPTÉ, r03 §1.10) — la priorité du
   feedback rétrospectif sur les runs perdues tient.

**Ce que ce round challenge** : (a) l'analogie spectateur n'est pas entièrement démontée
— il reste une hypothèse de transfert non vérifiée entre « le spectacle se produit sans
input » et « l'attribution reste forte » ; (b) le plafond de connaissance a un critère
d'alarme (`season_wins ≥ 50 AND Grimoire.synergies ≥ 25`) mais **aucune modélisation
des cadences de retour** — le critère seul ne suffit pas ; (c) le litige #G (axe choc
D) a des conséquences directes sur la densité du VRR en combat que le brouillon n'a pas
explorées ; (d) une proposition non vue par les rounds précédents : **la variance
positionnelle comme source propre de VRR**, orthogonale aux cascades DoT.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi précis et les nuances

### 1.1 Accord fort : le « Moment du Run » ancré à l'unité-source — le mécanisme de post-hoc attribution est CONFIRMÉ par la littérature 2024-2025

**Accord avec r03-retention §2.1/Prop-A ; ROADMAP-draft v4 §2.4.**

Le challenge du round 3 (r03) a correctement identifié que le VRR standard (action →
récompense) est affaibli par le découplage temporel du spectacle auto, et a substitué un
mécanisme de **post-hoc attribution** (fierté de construction). Ce round confirme ce
pivot avec deux sources nouvelles :

**Déclos 2025** (British Journal of Aesthetics 65(4):663-674) : l'article démontre que
les « spectateurs secondaires » qui ont *décidé des règles* de ce qui se passe accèdent
aux mêmes propriétés cognitivo-émotionnelles que les joueurs actifs, via ce qu'il appelle
« simulated play ». Pour The Pit : le joueur a *construit le build* — il est le « secondary
player » au sens de Déclos. Le combat spectateur **ne neutralise pas** le sentiment
d'authorship ; il le **différé et concentre** dans la phase de build. Cela valide le signal
post-hoc à condition qu'il nomme une **décision de build** (l'unité choisie), pas juste un
événement (la cascade).

**Yonkers Times 2025** (analyse spectator gaming) : « Pride — seeing a strategy succeed
without intervention. » La *fierté de construction* est listée comme un affect distinct
et positif propre au spectacle déterministe. **Ce mécanisme n'est pas une compensation
affaiblie du VRR — c'est un affect de catégorie différente**, plus proche de la satisfaction
d'un architecte que de la récompense d'un tireur.

**Implication pour le brouillon** : le signal « TON [NOM_UNITÉ] A CONSUMÉ 5 ENNEMIS EN
CHAÎNE » est correct. **Mais l'affect de fierté de construction est plus fort quand la
décision décisive est *non-évidente* a priori.** Si l'unité source de la cascade était
« évidemment la meilleure », la fierté est moindre (c'était prévisible). Si elle était
un choix de placement *non-trivial* (une adjacence de sigil qui crée le voisinage), la
fierté est plus forte. → **Enrichir le signal** : si la chaîne implique une arête du
sigil (adjacence positionnelle), le mentionner : « TON [NOM_UNITÉ] PLACÉ EN VOISIN DE
[NOM_AUTRE] A CONSUMÉ... » (placement = décision non-triviale). +1 champ à lire du bus
(`{source, cell.x, cell.y}` — déjà dans le snapshot). Coût : **0**, RENDER.

### 1.2 Accord fort : run court = one-more-run = CONFIRMÉ, et la récurrence saisonnière est nécessaire

**Accord avec r03 §1.8/#H ; r02-retention §1.2.**

**Åslund 2026** et **diva-portal 2026** (Hades 2 vs TBOI) confirment la conclusion de la
lentille rétention des rounds 1-3 :

> « Heavy meta-progression sustains motivation more *immediately* [...]
>  both approaches work, but they work for *different types of players*. »
>  — Åslund 2026, essays.se

Pour The Pit : notre Grimoire (méta-progression de *connaissance* minimale, sans puissance)
est aligné avec le modèle TBOI (minimal meta-progression) — il crée une **satisfaction de
maîtrise progressive** plus forte mais **à engagement plus tardif**. C'est un choix
conscient et sourcé. La distinction est maintenant nette :

- **Hades 2 (heavy)** : le joueur ressent toujours une progression visible après chaque
  run → motivation immédiate haute, mais masque la compétence.
- **TBOI / The Pit (minimal / connaissance)** : la motivation prend plusieurs runs à
  s'enclencher → **c'est précisément pourquoi le Codex bootstrappé ET le Moment du Run
  sont critiques pour la zone 0-5 runs** (sans ces signaux, le joueur quit avant que la
  motivation de type TBOI s'enclenche).

**Conséquence directe** : la saison (6-8 sem.) comme cadre **est nécessaire** (elle donne
la cadence aux joueurs TBOI-style pour ressentir la progression de connaissance), mais les
marques sub-tier (§6.2 brouillon) et le `season_wins` doivent combler le vide des 5-10
premiers runs pour les joueurs que le modèle TBOI perd pendant la phase de latching.

### 1.3 Accord fort : Codex bootstrappé (silhouettes + flash) — l'horizon Zeigarnik est correctement implémenté

**Accord avec r03 §6.7 ; r02-retention §2.3.**

Rien à challenger de nouveau. Le principe d'horizon d'exploration visible est bien documenté.
Le SEUL point à ajouter : **la cadence de découverte DANS le Codex doit être mesurée**, pas
seulement l'existence du mécanisme. La sim `--knowledge-ceiling` est le bon outil. **Ce round
ne re-challenge pas le mécanisme — il le considère acquis.**

### 1.4 Accord fort : pity = signal sans garantie, sans chiffre, à 50-60 % du hunt médian

**Accord avec r03 §1.11 ; r03-retention §2.3.**

**La source MDPI 2025** (Inherent Addiction Mechanisms in Gacha) confirme par un angle
différent : le pity *avec garantie explicite* crée une « gravity-in-mind » (GR metric)
qui **rapproche le jeu des seuils de gambling**, alors que le pity *implicite* (signal
de présence) préserve le VRR sans atteindre ces seuils. La formulation grimdark (« L'ombre
de cette créature est proche ») est donc non seulement psychologiquement optimale, mais aussi
déontologiquement plus saine (or in-game ≠ monnaie réelle — garde-fou progression §2.4
préservé).

**Source nouvellement sourcée pour le compromis seedé⊗variable (#L')** : Boyle et al. 2024
(Nature Scientific Reports, Wordle study) : « The first appearance of a near-miss led to
*higher motivation* and *positive affect* [...] than if the next guess revealed the same four
green letters (a thwarted near-miss). » → **le near-miss N+1 qui ne livre pas est plus
frustrant que la non-apparition normale**. Implication pour #L' : le pity seedé ne peut pas
garantir que la même position dans la run déclenche *toujours* l'unité — il doit déclencher
le **signal** de proximité (position seedée), mais laisser la **livraison réelle** dans la
distribution probabiliste seedée du même RNG. Ce compromis est exactement ce que le round 3
avait posé (#L') — cette source le confirme empiriquement.

---

## 2. DÉSACCORDS — ce qui est faible, mal calibré ou non étayé

### 2.1 DÉSACCORD MODÉRÉ : le seuil de chaîne du « Moment du Run » reste ARBITRAIRE — et l'hypothèse de la médiane est fragile pour notre déterminisme

**Ce que le brouillon v4 dit** (§2.4 + §12 Q1) : remplacer « chaîne ≤2 = pas de moment »
par « ≥ médiane des cascades mesurée en sim (`--chain-distribution`) ». Ce critère n'est
pas encore exécuté.

**Le problème spécifique à nos contraintes** : notre sim est **déterministe par seed**.
La distribution des cascades dans `tools/sim.lua` sur 250 combats (fuzz seed `20260620`)
est une distribution sur 250 seeds *fixes*, pas une distribution aléatoire. La « médiane
des cascades » dans ce contexte n'est pas la médiane sur la distribution des possibles —
c'est la médiane sur *un ensemble particulier de 250 situations*.

**Ce qui en résulte** : si les 250 seeds de fuzz contiennent accidentellement plus de
combats défavorables aux cascades (ex. tank-vs-tank sans DoT), la médiane sera sous-estimée,
et le seuil sera trop permissif (le Moment du Run se déclenche pour des cascades ordinaires).
Si elles contiennent plus de combats DoT-riches, le seuil sera trop restrictif (le Moment
ne se déclenche jamais sur un plateau en construction).

**Preuve par la littérature** : Kao et al. 2024 (CHI '24, « Juicy Game Feedback ») :
« Success dependence enhanced all motives [competence, effectance, curiosity] ». Mais
surtout : « *amplification unexpectedly reduced them, possibly because the tested condition
unintentionally impeded players' sense of agency*. » → un signal de « Moment du Run » qui
se déclenche trop souvent (seuil trop bas) **réduit le sentiment d'agence** — l'effet
inverse de ce qu'on cherche. La même logique s'applique à un seuil basé sur une médiane
qui sous-estime les cascades ordinaires.

**Proposition (§3.1)** : le seuil doit être fixé en **percentile, pas en médiane** : P75
des cascades (les 25 % les plus longues) sur un **ensemble de seeds VARIÉES** (pas les 250
seeds fixes du fuzz). Méthode : `tools/sim.lua --chain-distribution --n 1000 --random-seeds`.
Cible : seuil = valeur à P75 → ~25 % des combats déclenchent un Moment du Run. Ce chiffre
est cohérent avec la littérature sur la rareté attendue des récompenses variables (Hopson
2001 : VRR résiste à l'extinction si la fréquence de renforcement est ~20-30 %).

### 2.2 DÉSACCORD FORT : la modélisation du plafond de connaissance a UN CRITÈRE D'ALARME mais PAS DE MODÈLE DE RETOUR — le brouillon résout le mauvais problème

**Ce que le brouillon v4 dit** (§6.7, §7.1 + Q15) : plafond de connaissance à ~72 runs
(calcul r03) ; critère d'alarme `season_wins ≥ 50 AND Grimoire.synergies ≥ 25/30` →
prototyper 1 relique G pendant P3.

**Le problème** : le critère d'alarme identifie QUAND le plafond est atteint. Mais il ne
dit pas **à quelle cadence les joueurs REVIENNENT** après le plafond, ni **ce qui les fait
revenir**. C'est le vrai moteur du « one-more-run » à long terme.

**Preuve par la littérature** : diva-portal 2026 : Hades 2 (heavy meta-progression) produit
un « one-more-run mentality explicitly brought up in multiple threads ». TBOI (minimal) :
« sustains motivation through curiosity, completionism and the *path to Dead God* ». La
distinction est cruciale : TBOI retient les joueurs via **un arc long avec des jalons
visibles** (le chemin vers Dead God = 1,000+ heures de jeu), pas des récompenses cross-run.

The Pit n'a **pas d'arc long avec jalons visibles** après le Grimoire complet. Le Grimoire
rempli (30 interactions) n'a pas d'équivalent du « Dead God » — il n'y a pas de « niveau
suivant » de connaissance clairement affiché.

**Ce qui manque dans la roadmap** : une **structure de cadence longue** dans le Grimoire
— pas seulement « 30 interactions à découvrir » mais une **hiérarchie de maîtrise** :
- Niveau 1 : synergies de base (12 interactions, actuels) → Grimoire complété.
- Niveau 2 : synergies de type (P1, ~18 interactions) → Grimoire de type.
- Niveau 3 : synergies de sigil (reliques G, P4, ~5×4=20 interactions sigil×famille) →
  Grimoire de topologie.

**Ce arc long en 3 niveaux** correspond exactement aux phases P1/P4 de la roadmap — mais
ce n'est **pas explicitement présenté comme un arc de rétention au joueur**. Un Grimoire
qui ne montre pas « 30/30 synergies de base, 0/18 synergies de type, 0/20 synergies de
sigil » ne crée pas l'effet Dead God. Il suffirait de l'afficher comme une **progression
visible multi-niveaux**, pas juste un codex plat.

**Source** : Grid Sage Games (Kyzrati 2025) : « Metaprogression of the *mind* [...] 
players *feeling like a genius* for their growing ability to navigate the intersections
of all these systems. » Le « genius path » doit être *visible*, pas seulement *réel*.

**Proposition (§3.2)** : restructurer le Grimoire en **3 chapitres avec barre de progression
visible** : Afflictions (12 synergies), Essences (types P1, ~18), Abysses (sigils P4, ~20).
Chaque chapitre fermé tant que le précédent n'est pas débloqué (Zeigarnik : horizon fermé
= motivation). Coût : RENDER + structure de données dans `grimoire.lua`. 0 invariant SIM.

### 2.3 DÉSACCORD MODÉRÉ : l'effet de l'axe choc AXE D sur la DENSITÉ DU VRR n'est pas modélisé — c'est un trou dans la rétention

**Ce que le brouillon v4 dit** (§3.4) : l'axe D (décharge sur le 1er tick DoT) crée une
identité lisible « charger la cible, puis le DoT explose ». La sim 4-configs valide l'axe.

**Le problème non traité** : la densité du VRR **dans un combat** dépend du nombre
d'événements remarquables par unité de temps. L'axe D crée un événement remarquable
(`shock_amplify`) qui **dépend d'un tick DoT** — c'est-à-dire que le joueur doit AVOIR
un DoT sur la cible choc pour que l'événement se produise. Or, dans la phase early du
run (3-5 slots, boutique tier 1-2), la densité de DoT est faible : peu d'unités avec
affliction, peu de stacks posés avant que la cible meure.

**Conséquence** : l'axe D crée un VRR **conditionnel à un build DoT bien construit** —
ce qui est cohérent avec la philosophie « profondeur émergente ». Mais la question est :
est-ce que le joueur early (rounds 1-4) verra l'événement `shock_amplify` se déclencher
assez souvent pour que le mécanisme choc soit **compris** avant que sa densité VRR soit
réelle ?

**Preuve par analogie** : Reynad interview (noisypixel.net, dec 2024) : « PvP is tough
because players optimize very quickly. They'll always play in a way that maximizes their
win rate, regardless of what's fun. » La contrepartie : si un mécanisme (choc-D) n'est
pas *visible* dans les premières sessions, les joueurs ne l'exploreCont pas. Le VRR du
choc-D reste latent.

**Proposition (§3.3)** : dans la sim 4-configs (§3.4 brouillon), ajouter une **mesure
de latence VRR** : « combien de combats (median) avant qu'un joueur choc-D voie son
premier `shock_amplify` avec une équipe early (3-4 slots, tier 1-2) ? ». Si la latence
médiane > 3 combats → le mécanisme est invisible en early → ajouter une unité choc rang-1
**stat-stick + 1 stack choc auto** (facilite la découverte sans briser l'axe DoT). Coût :
data, 0 moteur, compatible avec le plancher ≥2/famille/rang (§3.1 brouillon).

### 2.4 DÉSACCORD LÉGER MAIS NOUVEAU : la VARIANCE POSITIONNELLE comme source de VRR propre — non traitée dans la roadmap

**Ce qui manque dans le brouillon v4** : toute la rétention VRR est portée par (a) les
cascades DoT (Moment du Run) et (b) les reliques (offre 1-parmi-3). Mais il existe une
troisième source de VRR **propre à la mécanique plateau-graphe 3×3** que ni les rounds 1-3
ni le brouillon n'ont explorée : **la surprise de placement**.

**Argument** : le même build (mêmes unités) sur le même sigil, placé différemment, produit
des résultats **radicalement différents** grâce aux auras d'adjacence. Ce n'est pas du
hasard — c'est du déterminisme révélé par l'expérimentation. La première fois qu'un joueur
découvre qu'en déplaçant son carry de la case 5 à la case 4, il active deux adjacences
supplémentaires et gagne le combat qu'il perdait, c'est un **moment de VRR sous agence
totale**.

**Preuve** : la recherche Boyle et al. 2024 (Nature Scientific Reports) montre que le
near-miss *sous contrôle personnel* (goal gradient dans Wordle) génère une arousal
**plus constructive** que le near-miss non-contrôlé (slot machine). La surprise de
placement est un near-miss sous contrôle maximal : « si j'avais placé différemment, j'aurais
gagné » → « *essayons de placer différemment* ».

**Ce qui manque dans la roadmap** : l'UI ne **révèle pas après le combat** ce que le
placement *aurait pu* donner. La carte de risque (§2.2) est prospective (avant le combat).
Mais il n'y a pas de **lecture rétrospective du plateau** : « EN PLAÇANT [UNITÉ] EN CASE 4,
TU AURAIS ACTIVÉ 2 ARÊTES SUPPLÉMENTAIRES ». Ce signal est :
- RENDER pur (lecture de `shapes.lua` + positions du snapshot).
- 0 SIM.
- Orthogonal aux cascades DoT (fonctionne même sans chaîne longue).
- Déclenche un VRR de type « insight » (je comprends rétrospectivement pourquoi j'ai perdu).

**La limite** : ce signal peut être perçu comme « tu aurais dû faire X » (culpabilisant).
**Mitigation grimdark** : le formuler comme une révélation du plateau, pas un reproche :
« LE PUITS A RETENU [UNITÉ] — UNE ARÊTE PLUS PROCHE DE TOI EXISTAIT ». Même mécanique,
tonalité Discovery.

**Proposition (§3.4)** : après chaque défaite, lire le snapshot + sigil actif + positions
et calculer si **le déplacement de 1 unité** aurait activé ≥1 arête de plus. Si oui,
afficher le signal. Coût : RENDER + 1 calcul de graphe (arêtes de `shapes.lua`, déjà en
mémoire au moment du post-combat). Aucun invariant. Test : sur le golden connu (carré),
vérifier que le calcul retourne le bon slot.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — Enrichir le signal du « Moment du Run » avec le placement (si cascade via adjacence) (P0, RENDER, +0.5 champ)

**Ce** : lire depuis le bus `{source, cell.x, cell.y}` du 1er événement de la chaîne max.
Si l'unité source est adjacente à une autre unité de son build **via une arête du sigil
actif** (vérifier `shapes[shape].edges`), enrichir le signal :
- Sans adjacence : « TON [NOM_UNITÉ] A CONSUMÉ 5 ENNEMIS EN CHAÎNE »
- Avec adjacence : « TON [NOM_UNITÉ] PLACÉ EN VOISIN DE [NOM_AUTRE] A CONSUMÉ 5 ENNEMIS
  EN CHAÎNE »

**Seuil de chaîne** : remplacer la médiane par **P75 sur 1000 combats seeds aléatoires**
(`tools/sim.lua --chain-distribution --n 1000 --random-seeds`) pour éviter le biais des
250 seeds fixes du fuzz. Cible : signal déclenché sur ~25 % des combats (Hopson 2001).

**Pourquoi priorisé** : coût nul, renforce l'attribution causale via le *placement* (agence
maximale, near-miss sous contrôle — Boyle et al. 2024) ET via la cascade (post-hoc
attribution — Déclos 2025). Double levier de rétention sur le même signal.

**Garde-fou** : RENDER + lecture bus. Invariants inchangés.

### Proposition B — Restructurer le Grimoire en 3 chapitres (arc long de maîtrise) (P2, RENDER data)

**Ce** : modifier la structure de `grimoire.lua` (et son onglet Grimoire dans `scenes/`) pour
afficher 3 chapitres progressifs :
- **Chapitre I — Afflictions** : les 12 synergies actuelles de `tests/synergies.lua`. Débloqué dès le run 1.
- **Chapitre II — Essences** : les ~18 synergies de type à venir (P1). Silhouette « ??? » tant
  que P1 n'est pas implémenté / tant que le joueur n'a pas complété Chapitre I.
- **Chapitre III — Abysses** : les ~20 synergies sigil×famille (P4, reliques G). Totalement
  verrouillé jusqu'à Chapitre II complet.

**Affichage** : barre de progression par chapitre (« Chapitre I : 7/12 »). Le Chapitre II fermé
est visible mais verrouillé (Zeigarnik). Pas d'unlock de puissance — unlock d'*horizon*.

**Pourquoi** : diva-portal 2026 : le « path to Dead God » de TBOI est le moteur de rétention
long terme dans un jeu à minimal meta-progression. L'arc 3 chapitres EST notre Dead God —
il doit être visible dès le run 1. Actuellement, le brouillon ne prévoit pas cet arc long
explicite.

**Coût** : RENDER + extension de `grimoire.lua` (ajout de champs `chapter`, `entries_by_chapter`).
IO hors SIM. 0 invariant. À coder pendant P2 (ranked v1), pas P4.

### Proposition C — Ajouter la mesure de latence VRR du choc-D dans la sim 4-configs (P0.5)

**Ce** : dans les 4 configs de la sim choc (§3.4 brouillon), ajouter une 5e mesure :
« latence médiane avant le 1er `shock_amplify` sur un plateau early tier-1 (3 slots,
rang-1/2 seulement) ». Si médiane > 3 combats → le mécanisme est invisible en early.

**Seuil** : si latence > 3 combats, créer une unité choc rang-1 (coût 1) avec `shock=1` à
l'attaque (1 stack auto) + stats de base. Profil « leurre choc » pour les nouveaux joueurs —
active le mécanisme dès les premiers rounds. Niche distincte (pas un doublon si le rang-1
actuel `stormcaller` a un mécanisme différent — à vérifier dans l'audit P0.5 §3.1).

**Pourquoi** : Kao et al. 2024 (CHI '24) : « *Success dependence* enhanced all motives. »
Un mécanisme qui ne se déclenche pas en early (success-dependant mais dépendant d'une
condition non remplie early) **n'améliore pas les motifs early**. La latence VRR mesure
cette condition.

**Garde-fou** : data + sim, 0 moteur. Compatible avec le plancher ≥2/famille/rang.

### Proposition D — Signal « arête révélée » post-défaite (calcul de graphe rétrospectif) (P0, RENDER)

**Ce** : après chaque combat PERDU, calculer (RENDER côté `arena_draw` ou `build.lua`) :
pour chaque position de l'équipe du joueur, si on déplace cette unité vers une case voisine
vide (selon le sigil actif), combien d'arêtes supplémentaires du sigil seraient activées ?
Si max(déplacement_+arêtes) ≥ 1, afficher :
« LE PUITS A RETENU [UNITÉ] — UNE ARÊTE DE [SIGIL] T'ÉTAIT PLUS PROCHE »
avec surligné la case optimale.

**Condition de déclenchement** : uniquement si le joueur a PERDU (évite le paternalisme sur
les victoires) ET si le combat n'a impliqué que le front (depth < 2 — sinon le problème est
d'exposition, pas de placement).

**Seuil** : déclenche si ≥1 arête supplémentaire possible → haute fréquence early (plateau
peu peuplé = beaucoup d'adjacences manquées) → découverte rapide du système. Désactivable
après X combats (quand le joueur a compris le mécanisme — `grimoire:hasLearnedAdjacency()`).

**Garde-fou** : RENDER uniquement. Lit `shapes[shape].edges` (déjà en mémoire côté RENDER).
0 invariant. **Zone sans test** → ajouter test que le calcul retourne le bon slot sur le
golden (carré, positions fixes).

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R4_1 — Seuil P75 pour le Moment du Run** : quelle est la distribution des longueurs de
cascade sur 1000 seeds aléatoires (pas les 250 seeds fixes du fuzz) ? La médiane et P75
divergent-ils significativement ? Si oui, le seuil actuellement proposé (médiane) est
sous-optimal. → `tools/sim.lua --chain-distribution --n 1000 --random-seeds` avant v0.9.

**Q_R4_2 — Arc long du Grimoire : cadence de déblocage du Chapitre II** : le Chapitre II
(synergies de type, P1) ne se débloque qu'une fois le Chapitre I complet (12/12). Estimation
r03 : ~72 runs pour tout découvrir. Un joueur moyen (~2 runs/semaine) prend ~36 semaines =
4+ saisons. C'est trop long pour le déblocage du Chapitre II. → **Ajuster la condition** :
Chapitre II débloqué à `Grimoire.synergies_base ≥ 8/12` (pas 12/12), pour que le Chapitre II
soit visible dans la saison 1. Question ouverte : à quel seuil l'horizon est-il suffisamment
motivant sans être trop facile ?

**Q_R4_3 — VRR du placement vs VRR des cascades : substituts ou complémentaires ?** Si le
signal « arête révélée » (Prop D) se déclenche fréquemment en early (plateau peu peuplé) ET
que le signal « Moment du Run » (cascades) se déclenche moins fréquemment en early (peu de
DoT), les deux signaux se **complètent temporellement** : Prop D en early (rounds 1-5), Moment
du Run en mid-late (rounds 6-10). Cette temporalité est-elle intentionnelle ? À vérifier sur
la distribution des cascades par round (`tools/sim.lua --chain-by-round`).

**Q_R4_4 — Cohérence DA grimdark de Prop D** : le signal « LE PUITS A RETENU [UNITÉ] » est-il
cohérent avec la tonalité da DA ? « Retenu » implique une agence du Puits (grimdark, cosmique) —
c'est cohérent. Mais formuler « une arête de [sigil] t'était plus proche » expose les mécanismes
internes (les arêtes du sigil) dans un contexte habituellement cryptique. Risque : casser la
fiction grimdark par une transparence mécanique trop explicite. Alternative : utiliser un langage
de *sigil* : « LE [NOM_SIGIL] MURMURE — TU N'AS PAS ENTENDU ».

---

## 5. CHALLENGE CLÉ (résumé)

Le brouillon v4 a une couche de rétention cohérente et bien sourcée. Ce round identifie trois
trous résiduels : **le seuil de chaîne du Moment du Run est calibré sur une médiane biaisée par
les 250 seeds fixes du fuzz** (P75 sur 1000 seeds aléatoires est la bonne métrique, validée par
la psychologie du VRR) ; **le Grimoire a un critère d'alarme de plafond mais pas d'arc long de
maîtrise visible** — sans une structure multi-chapitres ancrée dans la DA, il n'y a pas
d'équivalent du « Dead God path » de TBOI pour retenir les joueurs très actifs entre P1 et P4 ;
**une troisième source de VRR propre à la mécanique plateau-graphe 3×3 (la surprise de placement
rétrospectif) est entièrement absente de la roadmap** — elle est coût nul (RENDER + graphe
existant), orthogonale aux cascades DoT, et représente le near-miss sous contrôle maximal
(Boyle et al. 2024 : goal gradient under personal control > random near-miss pour l'affect
positif et la motivation).

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 4/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *Déclos 2025 (British Journal of Aesthetics) : https://philarchive.org/rec/DECSGC*
- *Kao et al. 2024 (CHI '24, Juicy Feedback) : https://nickballou.com/publication/2024-kao-et-al-juicy/*
- *Boyle et al. 2024 (Nature Scientific Reports, Wordle near-miss) : https://www.nature.com/articles/s41598-024-74450-0*
- *Finserås 2020 (Springer, near-miss video game) : https://link.springer.com/content/pdf/10.1007/s11469-019-00070-9.pdf*
- *MDPI 2025 (Inherent Addiction Gacha) : https://www.mdpi.com/2078-2489/16/10/890*
- *Åslund 2026 (essays.se, heavy vs minimal meta-progression) : https://www.essays.se/essay/6d9ac81240/*
- *Diva-portal 2026 (Hades 2 vs TBOI) : https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf*
- *Yonkers Times 2025 (spectator gaming) : https://yonkerstimes.com/when-games-dont-need-you/*
- *Grid Sage Games Kyzrati 2025 : https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/*
- *SAP Wiki (Weekly Pack, Arena mode) : https://superautopets.wiki.gg/wiki/Weekly_Pack + /wiki/The_Basics*
- *Reynad interview noisypixel.net dec 2024 : https://noisypixel.net/the-bazaar-interview-reynad-asynchronous-pvp-deckbuilder/*
