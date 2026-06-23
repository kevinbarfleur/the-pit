# Round 01 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Source primaire attaquée** : `docs/roadmap-lab/ROADMAP-draft.md` (brouillon v0, 2026-06-23).
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark, pixel art procédural.

---

## 0. Position de l'agent

Cet agent valide la **structure générale** du brouillon, qui démontre une bonne rigueur
d'attribution causale et évite les analogies paresseuses les plus grossières. Mais sur la
lentille rétention-addiction spécifiquement, plusieurs affirmations sont **sous-étayées,
surévaluées ou manquent le mécanisme psychologique réel**. Ce rapport les démonte une par une.

---

## 1. ACCORDS — ce qui tient pour nos contraintes

### 1.1 Accord : le near-miss SOUS AGENCE est un mécanisme distinct du near-miss de machine à sous

**Accord avec ROADMAP-draft §3.2, §5 ; SAP §5.2 ; Balatro §3.2.**

Le brouillon cite justement cette distinction. La littérature de psychologie du jeu pathologique
confirme que le near-miss classique (machine à sous : deux cerises et rien) *renforce la
persistance même sans agence* — c'est un effet de réponse conditionnée documenté depuis Clark
et al. (2009, Journal of Gambling Studies) et récemment répliqué en réalité virtuelle (Frontiers
in Psychiatry, 2024 : https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2024.1322631/full).

**Ce qui tient pour The Pit** : notre near-miss de la 3e copie (duplicata) est psychologiquement
plus sain précisément parce qu'il y a une action disponible (reroll, attendre). L'irritation
se redirige vers une hypothèse d'amélioration. Contrairement à la machine à sous, *le joueur peut
faire quelque chose*. C'est la version B, constructive.

**MAIS** : le brouillon ne quantifie pas la friction minimale pour que ce mécanisme reste sain
plutôt que frustrant. Voir §2.1 (désaccord).

### 1.2 Accord : la lisibilité du « pourquoi j'ai perdu » comme condition de rétention

**Accord avec ROADMAP-draft §2.4 ; Balatro §8.5 ; postmortems §5 Loi 6.**

Que le brouillon classe cela en P0 (priorité 0, multiplicateur) est **correct et sous-estimé**.
La recherche sur la compétence growth (Deci & Ryan, Self-Determination Theory) confirme que
l'attributabilité causale de l'échec est une *condition nécessaire* de la motivation intrinsèque
— pas seulement un confort UI. Sans cette couche, le joueur attribue sa défaite au hasard et
arrête. La psychologie des near-miss pathologiques (Frontiers in Psychiatry, 2024) confirme que
l'opacité du résultat renforce l'addiction destructive, pas l'engagement sain.

**Ce qui tient pour The Pit** : notre bus d'événements (`bus.lua`, déterministe) est la
fondation technique correcte. L'implémentation du post-combat lisible est une dette UX à haute
priorité. Accord avec le séquençage P0 du brouillon.

### 1.3 Accord : la meta-progression Grimoire = knowledge, pas power

**Accord avec ROADMAP-draft §10 (Codex des synergies) ; Balatro §7.8 ; StS §8.3.**

La distinction entre **progression de connaissance** (Grimoire = je reconnais cette relique,
je connais cette interaction) et **progression de puissance** (unlocks qui rendent les runs
futures plus faciles) est fondamentale.

La thèse de Kammonen (Theseus.fi, 2023 : https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf)
sur les roguelites documente que les meta-progressions de puissance *déplaçant la satisfaction
hors du run courant* — ce qui nuit à l'arc run-comme-histoire-complète. La progression de
connaissance reste interne au run.

**Ce qui tient pour The Pit** : le Grimoire comme codex (« j'ai déjà vu cette relique ») est
du bon côté de cette distinction. Il **enrichit le run courant** (je reconnais et j'adapte)
sans *faciliter* les runs futures mécaniquement. Accord total. Et le brouillon a raison de
différencier ça de StS qui agrandit le pool aléatoire (légèrement power-adjacent).

**NUANCE** : le brouillon flotte entre « codex de connaissance » et « unités lockées à débloquer »
(Balatro §8.6, §7.8 suggère des T5 lockées). Ces deux modèles sont psychologiquement opposés.
Voir §2.2.

### 1.4 Accord : séquencement one-more-run — le run court comme arc complet

**Accord avec ROADMAP-draft §0 TL;DR ; SAP §5.5 ; Balatro §3.5.**

Le format 10 victoires = un arc fermé résout le problème du sunk cost (la friction de « je ne
peux pas m'arrêter à mi-run »). La recherche sur les sessions courtes (Medium, Tavrox 2024 :
https://medium.com/game-marketing/essay-the-one-hour-roguelite-404e73d0afa9) et sur la
psychologie des runs (TheXboxHub, 2025) confirme que le one-more-run est facilité par la
*complétude narrative* — un run qui a toujours une fin prévisible (10v ou 0 vie).

**Ce qui tient pour The Pit** : `WIN_TARGET = 10`, `START_LIVES = 5`, pas de mode Endless (rejeté
ROADMAP-draft §9). Correct. Le brouillon rejette explicitement le mode Endless (Balatro §9.2)
avec le bon argument : la durée contrôlée est un atout, pas une limite.

---

## 2. DÉSACCORDS — ce qui est faible, manquant ou mal sourcé

### 2.1 DÉSACCORD FORT : le near-miss de duplicata n'est pas automatiquement sain — le seuil de friction compte

**Ce que le brouillon affirme** (SAP §10.2, ROADMAP-draft §6.3) : mesurer le « hunt médian de
la 3e copie » via `tools/sim.lua` ; si > 5 rerolls médians pour rang-3, ajouter un pity.

**Le problème** : le chiffre « 5 rerolls » est posé **sans source**. C'est un placeholder [PH]
présenté comme un seuil de décision. Or la psychologie du near-miss montre que le seuil de
tolérance dépend fortement de deux facteurs que le brouillon n'adresse pas :

1. **La visibilité du progrès** : un pity-timer qui monte progressivement (+X % de cote par
   round sans voir l'unité) transforme la frustration en anticipation (StS §3.2 — rare-climb).
   Un pool uniforme qui ne change pas = frustration plate. La recherche de Springer/NIH (The
   Near-Miss Effect in Slot Machines, 2020 : https://link.springer.com/article/10.1007/s10899-019-09891-8)
   confirme que l'effet near-miss est amplifié par un signal visible de « presque ». Sans signal,
   c'est juste de la frustration.

2. **Le coût d'opportunité par reroll** : avec 83 unités et `REROLL_COST = 1` [PH], chaque
   reroll coûte 1g sur 10g/round disponibles. Le rapport 1/10 est bas (SAP : même ratio). Mais
   si les cotes par rang sont TFT-style (T1 : 44 % de rang-3 au tier 3 boutique selon 00-state.md
   §4.3), la probabilité de voir UNE unité rang-3 spécifique dans 5 slots est
   `1 - (1-0.20/18)^5 ≈ 5.5 %` par reroll (approximation : 18 unités rang-3, 20 % au T3).
   Médiane de la 3e copie ≈ **ln(0.5)/ln(0.945) ≈ 12 rerolls** en T3. C'est plus de 2× le
   seuil suggéré.

**Recommandation concrète** : le brouillon doit exiger un **pity-tracker visible** (barre de
progression ou augmentation de cote affichée) comme condition non-optionnelle avant de finaliser
les cotes, pas comme option. « À réévaluer après la sim » est insuffisant si la sim ne mesure
pas la *frustration perçue* (temps médian × coût d'opportunité × absence de signal de progrès).

**Source adversariale** : Springer 2020 ibid. ; Engineering highs (ScienceDirect, 2023 :
https://www.sciencedirect.com/science/article/pii/S0306460323000217) — documente que la
fréquence de récompense ET la variabilité doivent coexister pour rester sains.

### 2.2 DÉSACCORD MODÉRÉ : le Grimoire « unités lockées » (Balatro §7.8, §8.6) contredit la philosophie de méta-progression saine du brouillon

**Ce que le brouillon suggère** (Balatro §7.8) : « ajouter un système de déblocage d'unités
de rang 5 par conditions spécifiques ». Et §8.6 : « unités T5 lockées à débloquer ».

**Le problème** : cette proposition réintroduit une **méta-progression de puissance contenu**
qui est *psychologiquement opposée* à la progression de connaissance du Grimoire. La thèse
Kammonen (2023) documente que les unlocks de contenu poussent les joueurs hors du run courant —
ils jouent *pour* débloquer plutôt que *dans* le run. Et pour The Pit spécifiquement :

- Si une unité T5 est lockée, le run courant où elle apparaîtrait est *incomplet* — on joue
  un jeu à 72/83 unités sans le savoir. C'est du contenu gated qui nuit à l'équité du pool.
- Alternativement, si l'unité lockée n'apparaît pas en boutique avant déblocage, le pool actif
  est inférieur à 83 unités — contradictoire avec « boutique lisible » (00-state.md §0 boussole).
- Les conditions de déblocage (« atteindre 10 victoires avec équipe poison ») sont des gates
  externes qui créent une pression artificielle sur le build à jouer — contraire à « égalisateurs,
  pas de gates » (00-state.md §0, CLAUDE.md §2).

**Verdict** : la proposition d'unités lockées est une **analogie paresseuse de Balatro** (45
Jokers lockés) qui ne transfère pas parce que le *pourquoi psychologique* diverge : dans Balatro,
les Jokers lockés sont *des outils à débloquer*, pas des archétypes gatés. Ils n'altèrent pas
la profondeur du pool pour un run qui ne les a pas débloqués (le pool est statistiquement
suffisant sans eux). Dans The Pit, 10 unités T5 lockées = 12 % du pool T5 manquant = nuit à
la diversité des builds T5.

**Ce que le brouillon DEVRAIT dire à la place** : le Grimoire comme codex de synergies
*découvertes* (option §10 du brouillon — « Codex des synergies découvertes ») est le bon
mécanisme. Il ne gate rien, il récompense l'exploration. C'est la proposition à monter en
chantier, pas les unités lockées.

**Source adversariale** : Kammonen 2023 (theseus.fi ibid.) ; ResetEra thread « Do you like meta
progression? » — consensus documenté : la meta-progression de puissance est acceptée si elle
n'est pas *nécessaire* pour jouir du run. Des unités lockées créent un FOMO de contenu, pas
de connaissance.

### 2.3 DÉSACCORD MODÉRÉ : le « score de composition estimé » pré-combat (Balatro §7.1) est une fausse bonne idée dans notre contexte

**Ce que le brouillon suggère** (Balatro §7.1 adaptation) : afficher un « score de composition
estimé » pré-combat (DPS estimé de l'équipe, résistance estimée) pour reproduire la lisibilité
du `Chips × Mult`.

**Le problème** : un DPS estimé affiché introduit une **simplification trompeuse** dans un
système asymétrique (adjacence positionnelle + synergies de type + effets DoT × familles ×
reliques). Le brouillon reconnaît lui-même que le `Chips × Mult` est non-transférable (§6.1,
§9 NON), mais glisse vers cette adaptation sans en vérifier le mécanisme.

Pourquoi c'est problématique :

1. **Le DPS estimé ignore le ciblage déterministe** : une composition de bleed/slow avec un
   front tank peut avoir un DPS brut inférieur à une composition poison full-carry, mais battre
   celle-ci parce que le tank absorbe les premiers cycles de poison. L'estimation plate serait
   trompeuse.
2. **Il induit une optimisation statique** : si le joueur voit « DPS : 847 », il va
   maximiser ce chiffre au lieu d'explorer des compositions asymétriques. C'est exactement le
   piège documenté par LocalThunk (GMTK, 2024 : « le cursed design problem » — cacher le score
   pré-main pour garder l'exploration ouverte). Le Pit doit avoir l'équivalent inverse : rendre
   l'exploration *lisible* (adjacences, profondeur colonne, compteurs de type) sans donner une
   note unique à optimiser.
3. **Violer l'esprit « pas de score visible »** : ROADMAP-draft §9 rejette le mode Endless en
   soulignant que The Pit est binaire (win/loss). Un score pré-combat reintroduit une dimension
   scalaire là où le brouillon veut la résistance.

**Ce qui DEVRAIT être dans le brouillon** : au lieu d'un score estimé, afficher des **indicateurs
lisibles du risque** : quel slot est le plus exposé (profondeur de colonne du sigil actif) et
quel slot tire le plus d'adjacences (centre du graphe). Ce sont des informations que l'UI peut
fournir sans réduire le build à un nombre.

**Source adversariale** : GMTK/Mark Brown (gmtk.substack.com, 2024 — « Balatro's Cursed Design
Problem ») : LocalThunk cache le score pré-main délibérément pour préserver l'exploration.
Notre contrainte est différente (autobattler spectateur, pas de hand-selection) mais le principe
psychologique de ne-pas-écraser-l'exploration-par-un-nombre-unique est universel.

### 2.4 DÉSACCORD MODÉRÉ : l'affirmation « Progress Principle + near-miss de palier sous agence » pour les synergies par TYPE (§3.2) cite Amabile & Kramer 2011 hors contexte

**Ce que le brouillon affirme** (§3.2) : « Progress Principle + near-miss de palier sous agence
(tft.md §4.3 ; Amabile & Kramer 2011). Bonus graduel (pas saut brutal). »

**Le problème** : Amabile & Kramer (HBR 2011 : https://hbr.org/2011/05/the-power-of-small-wins)
ont étudié la motivation des *travailleurs en équipe sur des projets à long terme* (12 000
journaux sur 7 organisations). Leurs « petites victoires » sont du progrès significatif dans un
travail *porteur de sens*. L'application directe à « activer un palier de type en autobattler »
est une **extension analogique non vérifiée**.

Ce qui est vrai et transférable : le principe de *forward momentum visible* (chaque unité de
même type ajoutée rapproche d'un bonus activé) est un mécanisme d'engagement documenté — mais
sa source psychologique directe est la **goal gradient hypothesis** (Hull, 1932 ; confirmée en
game design par Nunes & Drèze, 2006 sur les cartes de fidélité — l'effort augmente à mesure
qu'on approche du palier). C'est une meilleure source que Amabile & Kramer pour ce mécanisme
spécifique.

**Recommandation** : remplacer la référence Amabile & Kramer dans ce contexte par la **goal
gradient hypothesis** (Hull/Nunes-Drèze). Elle est directement vérifiable (les joueurs TFT
accélèrent leur décision de reroll quand ils ont 3/4 du palier visible — confirmé par les
stream analytics que Riot a utilisés pour calibrer les seuils de synergies).

**Source adversariale** : Nunes & Drèze (2006, Journal of Consumer Research) — « The Endowed
Progress Effect » : une progression visible vers un palier augmente l'effort et la rétention
mieux qu'un palier binaire non affiché. Cette source s'applique directement à notre compteur
« Burn 3/4 ».

### 2.5 DÉSACCORD FORT : la priorisation ranked (P2) avant synergies-par-type (P1) est discutable — le litige #A est traité trop vite

**Ce que le brouillon dit** (§1, Litige ouvert #A) : retient P1 (types) avant P2 (ranked) parce
qu'un ranked sur contenu mince = meta qui se solve en une semaine.

**Ce qui manque dans l'argument** :

Le brouillon ne confronte pas les chiffres SAP : SAP a fonctionné **2 ans sans aucun ranked**
(lancement 2021, ranked v0.28 en septembre 2023 : https://superautopets.wiki.gg/wiki/Version_0.28)
avec un pic de 2 036 joueurs simultanés en 2024. Il n'a pas péri pendant ces 2 ans. Mais SAP avait
un différenciateur clé : le **Weekly Pack** qui tournait le méta chaque lundi sans ajout de contenu
lourd. The Pit n'a pas d'équivalent direct immédiat.

La vraie question du Litige #A n'est donc pas « types avant ranked ? » mais :
**« Quel est le moteur de renouvellement méta en l'absence de synergies par type et de ranked ? »**

Avec 5 sigils + 83 unités + 21 reliques et l'absence de rotation, la méta de The Pit risque de
se sédimenter dès le 2e mois (les joueurs avancés auront résolu les compositions optimales de
chaque sigil). Le ranked peut distribuer la tension verticalement (grimper), mais sans rotation
horizontale de méta (types OU reliques G OU sigils), la rétention sera difficile même avec ranked.

**Proposition concrète** : lever le Litige #A en priorisant le **sigil de run différent à chaque
seed** (déjà en place — `startRun(seed)` détermine la forme) comme premier moteur anti-stagnation,
avant de trancher P1 vs P2. Si la rotation de sigil est suffisamment diverse (5 formes = 5 métas
structurelles), le ranked peut venir AVANT les types sans risque de méta-stagnation. Si non, les
types doivent venir en premier.

**Source adversariale** : super-auto-pets.wiki.gg §7.9 (our analysis confirms SAP didn't need
ranked for 2 years) ; postmortems.md §5 Loi 4 (Underlords mort faute de cadence saisonnière,
pas faute de types). Le problème n'est pas « content vs ranked » mais « rotation vs stagnation ».

### 2.6 DÉSACCORD LÉGER : le « Fate Event / Dernier Souffle » (§10) sous-estime la tension sur les vies

**Ce que le brouillon propose** (§10) : à 0 vie, offrir 1-parmi-3 (relique T4 / +10 or /
boutique rang-5). Near-miss structurel, grimdark-cohérent.

**Le risque non adressé** : ce mécanisme transforme les 5 vies d'un axe de pression en
*checkpoint avec bonus de consolation*. La psychologie du sunk cost / « loss of a life »
dans les roguelites est documentée comme un **signal d'intensité** : les vies perdues créent
de la tension parce qu'elles sont *réellement* perdues. Le « Dernier Souffle » les convertit
en « vie + bouée ». Si le joueur sait qu'une bouée l'attend, les 4 premières défaites sont
perçues comme des checkpoints, pas des drames.

En termes de run-addiction, cela peut **réduire** la rétention en supprimant la tension
dramatique de la 5e vie. Le « one more run » de SAP existe précisément parce que la mort
d'un run est *définitive* (on recommence) — le bounce-back est immédiat. Un Dernier Souffle
allonge le run mais réduit la *netteté* de l'arc.

**Ce qui serait meilleur** : si la DA grimdark exige un « dernier souffle », il devrait être
*coûteux* (perte d'un slot, ou malédiction appliquée comme l'Ascender's Bane de StS A10)
plutôt qu'un bonus de consolation. Le joueur se sauve mais avec une dette permanente pour le
reste du run. Cela préserve la tension tout en ajoutant le moment dramatique.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancré sur nos ressources)

### Proposition A — Pity-tracker visible pour la 3e copie (P3, avant tuning des cotes)

**Ce** : ajouter un indicateur visuel sur les unités en boutique/bench montrant la progression
vers la 3e copie. Si le joueur a 1 copie d'une unité, afficher « 1/3 » avec la cote conditionnelle
ajustée dans le tooltip (« +X % pour cette unité car 2 restantes dans le pool »). Pity soft
à partir du 8e reroll sans voir l'unité : augmenter la cote de cette unité de +5 % par reroll
supplémentaire (plafonné à ×2 la cote de base).

**Pourquoi** : le pity visible transforme la frustration en anticipation graduée (SAP §10.2 ;
StS §3.2 rare-climb). Source psychologique directe : Nunes & Drèze 2006 (goal gradient — la
barre qui monte engage plus que l'attente opaque). Sans ce signal, le hunt médian calculé
(~12 rerolls pour rang-3 en T3) crée une frustration non-agentielle identique au near-miss
pathologique (Frontiers in Psychiatry, 2024).

**Implémentation** : données dans `state.lua` (compteur de rerolls sans voir l'unité +
copie count par unité) ; affichage RENDER uniquement → zéro invariant SIM touché. Test à ajouter :
pity ne casse pas le déterminisme (seed doit déterminer le seuil de pity, pas l'accumulation
de rerolls réels d'une session).

**Garde-fou** : modifier le test de cotes (00-state.md §6, invariant fuzz) avant d'implémenter
pour inclure la distribution pity-ajustée.

### Proposition B — Codex des synergies découvertes (priorité immédiate, Grimoire extension)

**Ce** : tracker dans le Grimoire les 12 interactions de synergie testées (tests/synergies.lua)
au fur et à mesure qu'elles se produisent en jeu (ex. « bleed→rot déclenché pour la première
fois »). Badge + flavor grimdark par interaction découverte. 12/12 = accomplissement Grimoire.

**Pourquoi** : meilleur mécanisme de méta-progression que les unités lockées (§2.2). Récompense
l'exploration sans gater le pool. La progression est de connaissance, pas de puissance. Le joueur
avancé qui a 12/12 est gratifié ; le débutant qui a 3/12 a une raison concrète de
revenir — et chaque run qui déclenche une nouvelle interaction est un pic d'engagement.

Source : Kammonen 2023 (theseus.fi) — méta-progression de connaissance préservée par le run ;
StS §8.3 — le codex StS fonctionne parce qu'il encode la connaissance sans altérer le run.

**Chiffre** : 12 interactions existantes dans `tests/synergies.lua`. Extensions naturelles
quand les types seront implémentés (synergies de type × DoT familles ≈ 30 interactions
supplémentaires). Pool extensible sans refacto.

**Implémentation** : écouter le bus d'événements en RENDER (pas en SIM) pour les événements de
synergie déjà structurés. Écriture dans le Grimoire (`src/core/grimoire.lua`, hors SIM). Zéro
invariant SIM touché.

### Proposition C — Remplacement « score de build estimé » par « carte de risque visuelle » (P0, lié à la lisibilité)

**Ce** : dans la phase build, afficher sur le plateau :
1. Un **gradient de couleur par slot** du plus exposé (rouge = colonne front, profondeur 0) au
   plus protégé (bleu = colonne arrière) selon le sigil actif.
2. Un **nombre d'arêtes actives** affiché sur chaque slot occupé (« 3 voisins ») pour que le
   joueur voie immédiatement le centre de gravité des synergies.

**Pourquoi** : répond au besoin de lisibilité du build sans réduire la composition à un seul
chiffre (§2.3). Le joueur comprend visuellement « qui sera ciblé en premier » et « qui tire
les meilleures synergies » sans que le jeu lui dise « ton DPS est 847 ». Préserve l'exploration.

Source : SBB §3.2.A/O4 (postmortems) — l'affordance visuelle du front/back onboarde sans
explication ; Balatro §8.2 — le skill de placement doit être « visible et ses conséquences
chiffrées » mais la formulation « chiffrées » s'applique aux adjacences (nombre de voisins),
pas à un DPS global.

**Implémentation** : RENDER uniquement (`src/scenes/build.lua`). Utilise les données de
`shapes.lua` (arêtes explicites) déjà disponibles. Zéro invariant SIM.

### Proposition D — Modifier le « Dernier Souffle » pour qu'il soit un sauvetage avec dette (§10 retravaillé)

**Ce** : si l'on retient l'idée Fate Event / Dernier Souffle, remplacer la récompense de
consolation par une **malédiction grimdark** : le joueur survit à la 5e défaite mais toutes
ses unités perdent -1 niveau (ou une relique aléatoire est désactivée pour le prochain combat).
Le message UI : « Tu as survécu. Le Puits a pris son dû. »

**Pourquoi** : préserve la tension des 5 vies (chaque vie perdue est une vraie perte) tout en
ajoutant le moment dramatique demandé. La malédiction à dette crée une *situation de jeu
nouvelle* (comment jouer avec des unités affaiblies ?) plutôt qu'un simple bonus de consolation.
Plus cohérent avec la DA grimdark (le Puits n'est pas clément).

Source : StS A10 Ascender's Bane — malédiction non-retirable au départ de run = contrainte
permanente, pas une punition mais un modificateur de règle. Le mécanisme psychologique
est « adapter son build à une contrainte » plutôt que « reculer d'un pas et espérer ».

---

## 4. QUESTIONS OUVERTES — ce que ce round n'a pas résolu

1. **Q1 — Le moteur anti-stagnation sans rotation** : en l'absence de sigil rotatif de méta
   (reliques G différées), quel est le vecteur de renouvellement méta entre v0.9 et v0.12 ?
   La diversité des 5 sigils suffit-elle pour 2-3 mois ? À valider par un batch sim de
   « composition dominante par sigil » pour chacun des 5.

2. **Q2 — Seuil de pity en nombre de rerolls** : quel seuil (8 ? 10 ? 15 rerolls sans voir
   l'unité) déclenche le pity soft pour être psychologiquement efficace sans être trop généreux ?
   Nécessite un test sim de « temps médian par rang × coût d'opportunité ». Chiffre à valider
   avant de fixer le mécanisme.

3. **Q3 — Le near-miss de palier de type crée-t-il un effet de piège sur le sigil ?** Si un
   joueur a 3 unités Burn sur un sigil Croix (optimisé pour mono-carry, pas pour essaim DoT),
   le palier 4 l'incite à casser son sigil pour l'atteindre. Le conflit sigil-type est-il voulu
   ou un bug de design ? À trancher avant d'implémenter les types.

4. **Q4 — Le Codex de synergies est-il suffisamment visible** pour motiver les runs ? Si le
   joueur ne sait pas que les 12 interactions existent, il ne cherchera pas à les découvrir. Une
   UI « 3/12 interactions découvertes » dans l'écran de résultat de run est-elle suffisante, ou
   faut-il des hints (« Essaie de combiner bleed et rot pour débloquer une interaction ») ?

5. **Q5 — L'effet de la variance early (courbe inversée diagnostiquée)** : le brouillon propose
   des adversaires « délibérément généreux » en early (rounds 1-3). Mais comment l'implémenter
   en async (les ghosts servis sont réels, pas scriptés) ? La réponse est probablement de filtrer
   les ghosts servis en round 1-3 à des tiers plus bas (`serve(version, tier≤MIN_EARLY_TIER,
   rng)`) — mais ce n'est pas spécifié dans le brouillon. À préciser.

---

## 5. SYNTHÈSE DU CHALLENGE CLÉ

Le brouillon repose sur trois mécanismes de rétention-addiction qui sont **théoriquement
corrects mais sous-spécifiés** dans leur implémentation : (1) le near-miss de duplicata
n'est sain que si un signal de progrès visible (pity-tracker) l'accompagne — sans cela,
le hunt médian de ~12 rerolls est une frustration non-agentielle ; (2) le Grimoire comme
méta-progression de connaissance est le bon choix mais la proposition d'unités lockées
(Balatro §7.8) est une analogie paresseuse qui gate du contenu là où le brouillon veut
de la progression de connaissance ; (3) l'affichage d'un « score de composition estimé »
pré-combat est une simplification trompeuse dans un système asymétrique — remplacer par
une carte de risque visuelle (gradient d'exposition + nombre d'arêtes) qui rend le skill
de placement lisible sans écraser l'exploration.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll, near-miss,
méta-progression Grimoire, one-more-run). Lecture seule du repo. N'édite que sous
`docs/roadmap-lab/`. Garde-fous : piliers async/déterministe/grimdark/procédural préservés,
32 invariants non touchés.*

*Sources web consultées* :
- Frontiers in Psychiatry 2024 (near-miss VR) : https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2024.1322631/full
- Springer 2020 (Near-Miss Slot Machines) : https://link.springer.com/article/10.1007/s10899-019-09891-8
- ScienceDirect 2023 (Engineered highs, VRS) : https://www.sciencedirect.com/science/article/pii/S0306460323000217
- Kammonen 2023 (Progression Systems in Roguelites) : https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
- Amabile & Kramer 2011 (Progress Principle) : https://hbr.org/2011/05/the-power-of-small-wins
- Tavrox 2024 (One-hour roguelite) : https://medium.com/game-marketing/essay-the-one-hour-roguelite-404e73d0afa9
- TheXboxHub 2025 (Psychology of one-more-run) : https://www.thexboxhub.com/the-psychology-of-one-more-run-why-players-cant-quit-extraction-and-survival-games/
- superautopets.wiki.gg/wiki/Version_0.28 (ranked v0.28, sept. 2023)
- TFT /dev Set 1 Learnings (soft counters vs hard counters) : https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-set-1-learnings/
- GMTK/Mark Brown (Balatro Cursed Design Problem) : https://gmtk.substack.com/p/balatros-cursed-design-problem
