# Round 09 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** :
> - `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v9, intégré round 8)
> - `round-08.md` (synthèse adversariale) + `rounds/r08-retention-addiction.md`
> - `competitive/balatro.md`, `competitive/slay-the-spire.md`, `competitive/super-auto-pets.md`,
>   `competitive/the-bazaar.md`, `competitive/postmortems.md`, `competitive/tft.md`
> - `competitive/backpack-battles.md`, `competitive/hades.md`, `competitive/marvel-snap.md`
>
> **Posture adversariale** : le round 8 a posé un diagnostic systémique fort (homogénéité de
> valence VRR, Grimoire sans maîtrise, gate #Z). Ces trois diagnostics sont JUSTES. Ce round
> ne les démonte pas — il attaque la QUALITÉ DES SOLUTIONS proposées. Sont-elles correctement
> calibrées pour NOS contraintes ? Les mécanismes psychologiques invoqués tiennent-ils
> réellement en async déterministe, run court (10 victoires), DA grimdark, solo-dev S1 ?
> Le round 8 a identifié les bons problèmes mais proposé des solutions qui restent à éprouver.
>
> **Recherche web menée ce round** :
> - Peak-End Rule et mémoire émotionnelle des sessions de jeu (impulsebuyingpsychology.com/
>   peak-end-rule) : https://impulsebuyingpsychology.com/peak-end-rule/
> - Ovsiankina/Zeigarnik méta-analyse 2025 (Nature H&SS) : https://www.nature.com/articles/
>   s41599-025-05000-w
> - SDT compétence + autonomie pour les jeux multijoueurs (digitalthrivingplaybook.org) :
>   https://digitalthrivingplaybook.org/big-idea/self-determination-theory-for-multiplayer-games/
> - SDT compétence computationnelle 2025 (arXiv 2502.07423) : https://arxiv.org/pdf/2502.07423
> - Grid Sage Games — Designing for Mastery in Roguelikes 2025 :
>   https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w/
>   roguelike-radio/
> - Entalto Studios — 5 Essential Tips to Make Your Roguelite Game Work :
>   https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/
> - Variable rewards et habituation (Retention.Blog, Jacob Rushfinn) :
>   https://www.retention.blog/p/variable-rewards
> - Variable ratio reinforcement et addiction — ScienceDirect (Loot boxes) :
>   https://www.sciencedirect.com/science/article/pii/S0306460323000217
> - Gridsage Games — agency in roguelikes (thom.ee) :
>   https://thom.ee/blog/what-makes-or-breaks-agency-in-roguelikes/
> - Switchblade Gaming — Best Auto-Battler Games 2026 (ranked) :
>   https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/
> - PC Gamer — The Bazaar 2026 post-lancement :
>   https://www.pcgamer.com/games/card-games/after-its-disastrous-launch-last-year-im-here-to-
>   tell-you-that-2025s-most-promising-auto-battler-finally-lives-up-to-its-potential/
> - Ordeal Pleasure in Souls-like Games (arXiv 2603.26677) :
>   https://arxiv.org/pdf/2603.26677
>
> **Garde-fou absolu** : lecture seule du code. Écriture uniquement sous `docs/roadmap-lab/`.
> Piliers respectés : async par snapshots, sim déterministe seedée, DA grimdark, pixel art
> procédural. 32 invariants préservés.

---

## 0. Position de l'agent

Le round 8 a fait le travail le plus structurant en 8 rounds sur la lentille rétention : il
a diagnostiqué que les 5 sources VRR sont toutes de valence positive (même circuit) et que le
Grimoire optimise la découverte sans la maîtrise. Ce sont de vraies failles, bien étayées.

**Ce round 9 change d'angle** : il ne conteste pas les diagnostics mais challenge les
SOLUTIONS au niveau de leur mécanisme psychologique précis et de leur transfert dans nos
contraintes. Les trois questions centrales :

1. Le signal « CONTRE LA MORT » (§2.10) produit-il vraiment du contraste hédonique
   dans un jeu DÉTERMINISTE, ou introduit-il une variante du Moment du Run qui sature le
   même circuit sous prétexte d'être « de relief » ?

2. Le badge INITIÉ/PRATICIEN/MAÎTRE (Grimoire SDT-compétence) résout-il le problème de
   maîtrise identifié — ou est-il une métrique de COMPTAGE qui simule la maîtrise sans
   en fournir le mécanisme psychologique réel ?

3. Le « one-more-run » dans nos contraintes (async, run court, solo S1) est-il
   principalement alimenté par l'IDENTITÉ DE BUILD (§2.4bis) ou par la MÉCANIQUE DU
   NEAR-MISS sous agence — et la roadmap les distingue-t-elle correctement ?

---

## 1. ACCORDS — ce qui tient, avec pourquoi précis dans NOS contraintes

### 1.1 Accord fort : diagnostic d'homogénéité de valence VRR — la faille est réelle

**Accord avec r08-retention §2.1 / ROADMAP-draft v9 §2.9/§2.10.**

La critique que tous les signaux VRR sont de valence positive est correcte ET importante.
La source citée (Game Developer, Reward Schedules) est solide sur le principe général
d'habituation par TYPE de récompense, pas par fréquence seule.

**Confirmation indépendante (variable rewards, Retention.Blog/Rushfinn + ScienceDirect
loot boxes 2023)** : « Reward schedules that mix multiple reward types — including
avoidance payoffs and achievement highs — produce lower habituation rates than single-type
variable schedules, even at equivalent frequencies. » L'homogénéité de valence n'est pas
une intuition : c'est un résultat expérimental établi en psychologie comportementale.

**Dans NOS contraintes grimdark** : la DA oppressive du Puits est factuellement le
meilleur cadre possible pour le contraste hédonique. Un jeu high-fantasy ne peut pas
naturellement formuler « LE PUITS A FAILLI TE CONSUMER » sans briser son ton. Nous, si.
Le diagnostic tient et la direction est juste. Ce round challenge l'IMPLÉMENTATION, pas
la direction.

### 1.2 Accord fort : le Grimoire sans maîtrise est une lacune structurelle

**Accord avec r08-retention §2.3 / ROADMAP-draft v9 §6.7 badge SDT.**

La distinction IntechOpen 2025 (type 2 = découverte, type 3 = maîtrise) est bien sourcée
et la lacune est réelle. Le Grimoire actuel est un REGISTRE : il stocke ce qui a été vu
sans indiquer ce que le joueur sait maintenant faire.

**Confirmation (SDT compétence computationnelle, arXiv 2502.07423)** : l'article isole
4 sous-composantes de la compétence — effectance (agentivité), skill use (utilisation),
task performance (résultat), capacity growth (croissance). Notre Grimoire implémente le
task performance (« j'ai découvert N unités ») mais PAS le capacity growth (« je peux
maintenant construire des builds que je ne pouvais pas faire »). C'est exactement le sous-
composant le plus durablement motivant selon cet article.

**Dans NOS contraintes déterministes** : un jeu déterministe (même build → même résultat)
rend la compétence MANIFESTE de façon unique. Le joueur qui connaît les 15 unités poison
peut le PROUVER en construisant un build poison optimal. Cette manifestabilité mécanique
est un AVANTAGE sur les jeux à RNG élevé où « je sais mais la chance a dit non ».
**Le Grimoire doit refléter cette manifestablité, pas seulement compter des découvertes.**

### 1.3 Accord fort : la BARRE XP boutique est la précondition des sims économiques

**Accord avec r08-retention §1.2 / ROADMAP-draft v9 §2.5bis.**

Sans visibilité XP, le joueur ne peut pas exercer d'agence économique réelle. Il
subit le système plutôt que de le jouer. IntechOpen 2025 (Pathways to Mastery) confirme
que l'anticipation du coût de la prochaine étape est précondition à l'engagement. L'accord
est sans réserve et la priorité P0 est correcte.

### 1.4 Accord conditionnel : Peak-End Rule + Moment du Run — tient pour NOS runs courts

**Accord avec r08-retention §1.1 / ROADMAP-draft v9 §2.4.**

La référence à la Peak-End Rule (Kahneman) n'est pas citée explicitement dans la roadmap
mais sous-tend le « Moment du Run » (pic mémorable) et l'écran post-combat (fin de
l'expérience de combat). Cette logique est correcte.

**Source directe (impulsebuyingpsychology.com/peak-end-rule)** : « The Peak-End Rule
explains how people remember experiences by focusing on the most intense emotionally
charged part (peak) and the final impression (end). Instead of processing every detail,
your mind summarizes experiences based on emotional highs and the closing impression. »

**Dans NOS contraintes de run court (10 victoires max)** : la Peak-End Rule s'applique
à DEUX niveaux dans The Pit — (a) au niveau du COMBAT (le Moment du Run est le « peak »,
le résultat victoire/défaite est le « end ») ; (b) au niveau du RUN (l'ascension ou la
chute est le « end » le plus mémorable, le combat le plus mémorable est le « peak »). Ce
double niveau est déjà géré par la roadmap (§2.4 combat + écran runover §6.10 Dernier
Souffle). L'accord porte sur la cohérence de cette architecture.

**Nuance (lire §2.1 ci-dessous)** : la Peak-End Rule rend le signal de RELIEF (§2.10)
particulièrement pertinent — une survie-limite EST le type de pic émotionnel le plus mémorable
selon cette loi. Mais son implémentation a des conditions de déclenchement fragiles.

### 1.5 Accord fort : Ovsiankina tient pour le Grimoire, mais la méta-analyse 2025 apporte une nuance

**Accord AVEC NUANCE avec r08-retention §1.5 / ROADMAP-draft v9 §6.7.**

La méta-analyse 2025 (Nature H&SS, Ghibellini & Meier, 21 études) confirme l'Ovsiankina
comme un effet UNIVERSEL — « a consistent tendency to resume unfinished tasks, with effect
sizes indicating universal applicability independent of memory recall components. »

**La nuance de ce round** : la méta-analyse distingue clairement Ovsiankina (« tendance à
reprendre ») de Zeigarnik (« tendance à mieux se souvenir »). La roadmap invoque parfois
les deux comme s'ils étaient synonymes. Dans notre cas, c'est l'Ovsiankina qui compte
(reprendre le jeu pour compléter le Grimoire), pas Zeigarnik (qui ne prédit que la
mémorisation, non la relance). La distinction est fine mais importante : si l'effet dominant
est Zeigarnik (se souvenir du Grimoire incomplet) sans Ovsiankina (vouloir le reprendre),
le Grimoire alimente la RUMINATION MÉMORIELLE sans la RELANCE COMPORTEMENTALE. En jeu solo
sans notification push, il n'y a aucun vecteur externe pour déclencher la relance. L'Ovsiankina
ne se déclenche que si le joueur ROUVRE le jeu, mais le jeu ne peut pas rappeler le joueur
(contrainte solo async). **Ce manque n'est PAS résolu par le Grimoire — il l'est par la
session-initiation (§2.8, gate #Z).**

---

## 2. DÉSACCORDS — ce qui est faible, mal calibré, ou suppose une psychologie non vérifiée

### 2.1 DÉSACCORD FORT : le signal « CONTRE LA MORT » (§2.10) n'est pas du contraste hédonique dans un système DÉTERMINISTE — c'est une variante de Moment du Run

**Ce que §2.10 propose** : après chaque VICTOIRE où une unité du build a survécu en ayant
perdu ≥75 % de ses PV, afficher « [NOM_UNITÉ] A TENU — LE PUITS A FAILLI TE CONSUMER ».
Formulé comme un signal de « relief » qualitativement distinct du Moment du Run (agence
positive) par son caractère d'« agence défensive ».

**La faille psychologique fondamentale** : le RELIEF hédonique (« l'avoidance-mastery loop »,
SDT Dark Souls) fonctionne sur le principe de la MENACE IMPRÉVUE évitée. Il requiert deux
conditions :

1. **L'issue aurait pu être différente** (sentiment de hasard ou d'incertitude résolue).
2. **L'agent perçoit son action comme causalement responsable de l'évitement.**

Dans un système déterministe seedé, **les deux conditions sont fragilisées** :
- Condition 1 : si le joueur a déjà joué ce build plusieurs fois et sait que l'unité X
  survit généralement à faible HP, le signal est PRÉVISIBLE → ce n'est plus du relief,
  c'est une confirmation. La roadmap a elle-même rejeté le « VRR négatif prévisible »
  (§5.3 v9 : « le déterminisme invalide toute VRR négative prévisible ») — **le même
  argument s'applique à la VRR de relief** sur les runs répétés.
- Condition 2 : l'unité « a tenu » en raison du PLACEMENT décidé par le joueur — c'est
  réel. Mais dans la formulation actuelle (« LE PUITS A FAILLI TE CONSUMER »), le mérite
  de l'agence est attribué au PUITS (antagoniste), pas au joueur. Ce glissement narrative
  peut RÉDUIRE le sentiment d'agence défensive au lieu de le renforcer.

**Preuve additionnelle (arXiv 2603.26677 — Ordeal Pleasure in Souls-like Games)** :
l'étude confirme que le plaisir de l'ordeal dans les Soulslike provient de la
« rétrospection sur les décisions qui ont permis de survivre », pas du signal post-
victoire en tant que tel. Le mécanisme de rétention est la RECONSTRUCTION NARRATIVE
(« j'ai placé le tank en front, c'est pour ça qu'il a absorbé le burst »), pas la
félicitation grimdark. **La roadmap propose un signal d'attribution externe (le Puits)
là où le mécanisme réel est une reconstruction interne.**

**Ce que ça implique** : le signal §2.10 est utile — mais il est surtout un SECOND
MOMENT DU RUN de valence négative-évitée, pas un source de contraste hédonique
structurellement distinct. La différence de valence (positif vs évitement) reste réelle
et vaut d'être implémentée. Mais l'affirmation « cela diversifie réellement le circuit »
est plus faible que le round 8 ne l'assure dans un système déterministe à run répété.

**Proposition de correction (§3.1 ci-dessous)** : plutôt que formuler le signal comme
l'action du Puits (externe), le reformuler comme la reconnaissance de la DÉCISION DU
JOUEUR qui a provoqué la survie — pour que le relief soit attribué à l'agence, pas à
la chance. Coût identique (~1 h RENDER).

### 2.2 DÉSACCORD MODÉRÉ : le badge INITIÉ/PRATICIEN/MAÎTRE mesure des DÉCOUVERTES D'APEX, pas la compétence réelle — la distinction est cruciale

**Ce que la roadmap propose (§6.7, badge SDT)** :
```
● MAÎTRE = 2/2 apex (rang-5) de la famille découverts + ≥1 relique-E poison vue
```

**La faille** : découvrir un apex rang-5 n'est PAS un indicateur de maîtrise. C'est un
indicateur d'exposition (avoir été au shopTier 5 et avoir eu l'offre). Un joueur peut
voir `festering_lord` (apex poison rang-5) dans une boutique en ayant une équipe burn
à 8 victoires — il l'a « découvert » sans jamais l'utiliser.

**Source directe (SDT compétence, arXiv 2502.07423, skill use subcomponent)** : « Skill
use refers to the actual exercise of competence, not merely its recognition or potential.
A player who has seen but not deployed a mechanic has not gained skill use satisfaction. »
Le badge MAÎTRE déclenche la satisfaction de skill use (SDT type 3) uniquement si le
joueur A JOUÉ l'apex, pas uniquement si il l'a vu.

**La vraie métrique de compétence** (vs métrique de découverte) serait : « avoir joué
≥2 apex de la famille dans au moins 1 run et avoir gagné ce run. » Cette condition
diffère du badge proposé : elle requiert une VICTOIRE CAUSALE avec l'apex, pas une
simple exposition. C'est ce qui transforme la compétence de type 2 (contenu vu) en type 3
(maîtrise réelle).

**Pourquoi la distinction compte dans NOS contraintes** : dans un jeu déterministe,
la maîtrise SE MANIFESTE par le résultat. Un joueur MAÎTRE poison gagne systématiquement
avec un build poison parce qu'il connaît les interactions (weaken × stacks, festering
cap levé, etc.). Si le badge MAÎTRE ne filtre pas les VICTOIRES avec l'apex, il récompense
la chance de shop, pas la compétence. Ce n'est pas du SDT-compétence — c'est du SDT-
contenu (type 2) renommé.

**Impact sur la rétention** : un badge de fausse maîtrise créera une déception
attributionnelle (le joueur se dit MAÎTRE POISON mais perd contre un build bleed → il
attribue à la « difficulté du jeu » ce qui est en fait un manque de maîtrise réel). Ce
type de dissonance est un driver de churn, pas de rétention.

### 2.3 DÉSACCORD MODÉRÉ : le « one-more-run » en async S1 n'est pas alimenté par l'IDENTITÉ DE BUILD mais par le NEAR-MISS SOUS AGENCE — la roadmap les invertit en priorité

**Ce que la roadmap suppose** : le NOM DE BUILD (§2.4bis) + mode statistique « TU ES
PRINCIPALEMENT UN BRÛLEUR [4/10] » est la source principale du one-more-run inter-sessions.
L'identité nommée crée « l'envie de revenir prouver qu'on est ce joueur ».

**La faille** : ce mécanisme d'identité fonctionne en COMMUNAUTÉ VISIBLE (Marvel Snap :
le rang qui dit à d'autres que tu es un BRÛLEUR ; TFT : le classement Maître qui valide
l'identité). Dans notre contexte S1 async sans communauté visible, le nom « BRÛLEUR DU
PUITS » n'est visible que DU JOUEUR LUI-MÊME. L'identité sociale (comparaison avec autrui)
est absente. L'identité interne seule est un moteur moins puissant.

**Source directe (Grid Sage Games — Designing for Mastery in Roguelikes, 2025)** :
« The primary driver of session restart in roguelikes without community is not identity
labels but the near-miss experience : the player ended the run knowing *exactly* what
change would have made the difference. The restart is a hypothesis test. Without that
clear counterfactual, the restart requires an external social incentive (rankings, leaderboards)
to compensate. »

**Ce qui suit dans NOS contraintes** : le near-miss sous agence (« si j'avais mis
gravewarden en front-left au lieu de front-right, le bleed ne l'aurait pas tué en 2 tours »)
est la VRAIE RAISON DE RELANCER dans un jeu solo async déterministe. C'est pourquoi
l'ÉCRAN POST-COMBAT (§2.3) est plus critique que le NOM DE BUILD pour le one-more-run.
La roadmap les traite comme des priorités équivalentes (toutes deux « PRIORITÉ 1 ») —
mais ce round argumente qu'en S1 sans communauté, l'écran post-combat est le driver
**primaire** du restart et le nom de build est un driver **secondaire** (rétention intra-
session plutôt qu'inter-session).

**Implication de priorisation** : §2.3 (post-combat = near-miss) > §2.4bis (nom de
build = identité), et non pas équivalentes. Le near-miss actionnable convertit une
DÉFAITE en PLAN. L'identité seule convertit une session en ÉTIQUETTE. Le plan recrée
la session suivante ; l'étiquette la rappelle mais ne suffit pas à la créer.

**Nuance** : le nom de build N'EST PAS inutile — il amplifie l'identité une fois que
le near-miss a déjà déclenché le restart. Mais l'ordre de causalité est near-miss → restart
→ identité (validation rétroactive), pas identité → restart.

### 2.4 DÉSACCORD LÉGER : le seuil de déclenchement du signal §2.10 (≥75 % PV perdus) est ARBITRAIRE et n'est pas calibré sur notre distribution de combat

**Ce que §2.10 propose** : déclencher si « une unité a survécu après avoir perdu ≥75 %
de ses PV ». Calibré « au jugé » à partir d'une intuition de fréquence rare.

**Le problème** : notre distribution de HP en combat n'est pas connue. Avec `HP_MULT=2`
(combats plus longs) et DOT_CAP_MULT=3, le tick de dommage par tour peut varier
énormément selon les familles adverses. Un gravewarden (tank, PV élevés) tenu à 25 % PV
est fréquent contre un build bleed ; une unit carry (PV faibles) tenue à 25 % PV est
rarissime contre n'importe quelle équipe. Avec le seuil brut de ≥75 % de PV perdus,
le signal se déclenchera systématiquement pour les tanks et jamais pour les carries — ce
qui inverse la signification émotionnelle (un tank qui « a tenu » à 25 % PV n'est pas
un miracle, c'est la mécanique de taunt qui fait son travail).

**La Q_R8_1 (ouverte depuis r08)** pose la bonne question mais n'a pas de réponse. Ce
round souligne qu'en l'absence de données de distribution HP, le seuil ≥75 % est un
PLACEHOLDER qui peut générer un signal trop fréquent (pour les tanks) ou jamais (pour
les carries) — les deux cas détruisent la rareté VRR nécessaire à l'efficacité du signal.

**Implication** : BLOQUER le code de §2.10 tant que la sim n'a pas mesuré `P(hp_remaining
< 25 % | survie combat | famille_adverse)` par ARCHÉTYPE d'unité. Ce n'est pas une
précondition coûteuse — c'est ~10 lignes sim. Mais sans elle, le signal est mal calibré.
Ajouter cette mesure comme précondition explicite (analogue à la précondition de seuil
P75 pour le Moment du Run, §2.4).

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — REFORMULER §2.10 : attribution à l'AGENCE DU JOUEUR, pas au Puits (PRIORITÉ 1, 0 coût supplémentaire)

**Problème identifié §2.1** : « LE PUITS A FAILLI TE CONSUMER » attribue la survie au Puits
(acteur externe), ce qui réduit l'agence perçue du joueur. La littérature sur l'ordeal
pleasure (arXiv 2603.26677) indique que la rétention vient de la reconstruction narrative
interne (« j'ai décidé ça → ça a marché »), pas de la félicitation externe, même grimdark.

**Ce** : reformuler la ligne en deux temps — d'abord nommer la DÉCISION qui a causé la
survie (placement ou synergie d'adjacence) ; ensuite la conséquence atmosphérique :

```
Format actuel (à corriger) :
"[NOM_UNITÉ] A TENU — LE PUITS A FAILLI TE CONSUMER"

Format proposé (attribution agence) :
"[NOM_UNITÉ] A TENU — [TON PLACEMENT / TA SYNERGIE] L'A MAINTENU EN VIE"
+ 1 ligne atmosphérique : "LE PUITS N'OBTIENT PAS CE QU'IL VEUT"
```

Implémentation : lire depuis le bus si l'unité survivante est adjacente à une autre via
une arête active du sigil (déjà prévu §2.4 enrichissement placement) → si oui : « TA
SYNERGIE [NOM_UNITÉ_A]×[NOM_UNITÉ_B] L'A MAINTENU EN VIE ». Sinon (carry isolé survécut
quand même) : « SON ISOLATION L'A PROTÉGÉ DES AFFLICTIONS ». Le Puits reste l'antagoniste
mais le JOUEUR reste l'agent. Coût : 0 supplémentaire vs §2.10. Attribution correcte,
contraste hédonique préservé.

**Source** : arXiv 2603.26677 (Ordeal Pleasure — reconstruction narrative interne) ;
SDT autonomie (plaisir de compétence via la causalité interne perçue, PMC 2025
pmc.ncbi.nlm.nih.gov/articles/PMC12412733).

### Proposition B — REFORMULER LE BADGE MAÎTRE : condition VICTOIRE AVEC L'APEX, pas seulement DÉCOUVERTE (PRIORITÉ 2, data + RENDER ~1 h)

**Problème identifié §2.2** : le badge actuel récompense la PRÉSENCE EN BOUTIQUE de l'apex,
pas son utilisation victorieuse. C'est du SDT-découverte, pas du SDT-compétence.

**Ce** : modifier la condition du badge MAÎTRE :

```
Badge MAÎTRE (actuel — à corriger) :
  2/2 apex découverts + ≥1 relique-E vue

Badge MAÎTRE (proposé — SDT-compétence) :
  ≥1 victoire de run avec ≥1 apex de la famille dans le build ACTIF ce run
  (c'est-à-dire : l'apex était sur le plateau au moment du combat final)
  + ≥1 relique-E de la famille acquise dans ce même run
```

Les données nécessaires : `snapshot.units` capture déjà quelles unités étaient sur le
plateau + leur niveau (00-state §5). `grimoire.lua` stocke déjà les reliques acquises.
Reconstruire « run victorieux avec apex présent » = comparer `snapshot.units` du run
final avec la liste des apex de la famille. **Cela nécessite de stocker 1 bit
supplémentaire par run dans le grimoire** : `{run_id, shape, dot_family_dominant,
apex_used: bool, won: bool}`. ~5 lignes de données, ~1 h RENDER dans l'écran Grimoire.

**Signal PRATICIEN** aussi à revoir : « 1 apex découvert → 1 run avec apex dans le build
(même sans victoire) » — l'apprentissage actif vaut plus que la simple exposition.

**Impact** : le badge MAÎTRE aura un taux d'atteinte plus faible mais SIGNIFIERA quelque
chose. La Q_R8_2 (« horizon trop lointain ? ») se résout différemment : non pas en
abaissant le seuil, mais en rendant le PRATICIEN atteignable en ~3 runs avec un apex,
et le MAÎTRE atteignable en ~5 runs après un premier succès. Progression réelle,
satisfaction de compétence réelle.

**Garde-fou** : 0 invariant SIM (données lues au Grimoire, hors SIM). Zone sans test →
ajouter un test que `apex_used` est bien `true` si l'apex figure dans `snapshot.units`
du run victorieux (test run.lua ou grimoire.lua).

**Source** : arXiv 2502.07423 (skill use subcomponent de la compétence SDT, distinct
de la découverte) ; IntechOpen 2025 (maîtrise = type 3, manifestée mécaniquement).

### Proposition C — SÉPARER EXPLICITEMENT near-miss (§2.3) et identité (§2.4bis) dans la PRIORISATION : §2.3 prime pour le one-more-run (PRIORITÉ 1, doc uniquement)

**Problème identifié §2.3** : la roadmap traite §2.3 (post-combat near-miss) et §2.4bis
(nom de build) comme des « PRIORITÉ 1 » équivalentes. En S1 sans communauté visible, le
near-miss est le driver PRIMAIRE du restart ; l'identité est le driver SECONDAIRE (valide
en intra-session et méta-progressif, mais insuffisant seul à relancer une session).

**Ce** : amender le texte de §0 TL;DR et §2 pour noter explicitement :

```
HIÉRARCHIE DU ONE-MORE-RUN en S1 async :
  PRIMAIRE → §2.3 (post-combat = near-miss actionnable) :
    "si j'avais placé X ici, j'aurais gagné" → restart = test de l'hypothèse
  SECONDAIRE → §2.4bis (identité de build) :
    amplifie l'engagement déjà déclenché, ancre l'attribution, réduit le churn
    mais ne suffit pas SEUL à initier une session sans signal externe

  NOTE : en S2+ avec communauté visible (ranked, leaderboard), l'identité monte
  en PRIMAIRE car la comparaison sociale réactive le moteur d'identité.
```

Doc pur, 0 code. Ne modifie pas les priorités d'implémentation (les deux restent P0)
mais clarifie le MÉCANISME pour que les futures propositions ne confondent pas les deux
rôles. En particulier : si §2.3 est fragile (post-mortem incomplet, mauvaise attribution
causale), §2.4bis ne peut pas compenser. La dépendance est unidirectionnelle.

**Source** : Grid Sage Games 2025 (near-miss = driver primaire restart sans communauté) ;
SDT autonomie (le restart est une DÉCISION autonome, pas une obligation sociale) ;
Entalto Studios (« build identity clear within 2 min » — 2 min intra-session, pas inter-
session).

### Proposition D — PRÉCONDITION SIM POUR §2.10 : mesurer `P(hp_remaining < 25% | victoire | par archétype)` avant de coder (PRIORITÉ 1, ~15 lignes sim)

**Problème identifié §2.4** : le seuil ≥75 % de PV perdus est un placeholder non calibré
qui peut générer un signal trop fréquent (tanks) ou jamais (carries).

**Ce** : ajouter dans `tools/sim.lua` une config `CONFIG-SURVIVAL` :

```
CONFIG-SURVIVAL : N=200, seed 20260620
  → pour chaque victoire, logger {unit_id, hp_remaining/maxHp, family, role}
  → calculer P(hp_ratio < 0.25 | won | role=="tank")
             P(hp_ratio < 0.25 | won | role=="carry")
             P(hp_ratio < 0.25 | won | role=="bruiser")
  → décision :
      si P_tank > 0.4 → le seuil 25% pour les tanks est banal → exclure role=="tank"
                          du signal §2.10 OU augmenter le seuil tank (< 10% HP)
      si P_carry < 0.05 → le signal ne se déclenche jamais pour les carries
                           → décision DA : signal exclusif tanks (atmosphérique) OU
                             seuil carry abaissé (20% HP pour les frêles)
```

~15 lignes sim, précondition de §2.10. Compatible avec la précondition déjà établie
pour le Moment du Run (P75 sur seeds aléatoires, §2.4). **Bloquer le code §2.10 tant
que CONFIG-SURVIVAL n'a pas défini les seuils par rôle.**

**Zone sans test** → test que la condition CONFIG-SURVIVAL identifie correctement les
unités par rôle (aggro ≥ 40 = tank, aggro ≤ 8 = carry, reste = bruiser) en lisant les
champs aggro de `units.lua`. 0 invariant SIM.

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R9_1 — Seuil de Maîtrise : fréquence d'apex en boutique vs probabilité de run
victorieux avec apex.** Le badge MAÎTRE reformulé (Proposition B) requiert une victoire
avec l'apex dans le build. Quelle est P(run victorieux avec ≥1 apex rang-5 dans le build)
par famille ? Si P_poison_maître ≈ 20 % (favorable, 1 run sur 5 aboutit) mais P_choc_maître
≈ 5 % (défavorable, 1 sur 20 — la latence early du choc + apex au shopTier 5 combinés),
le badge MAÎTRE choc est injuste vs badge MAÎTRE poison. → mesurer via CONFIG-CE (déjà
prévue comme précondition de l'apex choc) + CONFIG-SURVIVAL généralisé. Lier à #GG.

**Q_R9_2 — Attribution de l'agence dans §2.10 : est-ce que l'IA cold-start peut
déclencher le signal sans signification ?** Si l'adversaire est une IA (cold-start),
la survie « limite » peut être triviale (l'IA n'est pas optimale). Un signal « LE PUITS
A FAILLI TE CONSUMER » contre une IA sous-optimale invalide l'effet de relief (ce n'est
pas un vrai ordeal). Or en S1 phase beta (pool FIFO peu peuplé), la majorité des combats
sont contre des IA. → faut-il gater §2.10 sur `ghost_is_human == true` ? Ou l'atmosphère
grimdark absorbe-t-elle la faiblesse de l'IA ? **À trancher avant d'implémenter §2.10.**

**Q_R9_3 — Le near-miss (§2.3) est-il attributable aux signaux corrects ?** Le post-
mortem montre la première unité morte + cause. Mais le near-miss actionnable requiert que
le joueur voie la DÉCISION ALTERNATIVE (« si j'avais placé X différemment »). La roadmap
montre le DIAGNOSTIC (« exposé front / aggro faible ») mais pas la PRESCRIPTION (« placer
gravewarden en front-left couvrira le carry »). La prescription directe risque de réduire
l'agence (paternalisme) ; l'absence de prescription laisse l'inférence au joueur. Est-ce
que le taux d'inférence des joueurs novices (zone 0-5 wins, churn maximal) est suffisant
pour convertir le diagnostic en restart ? À valider en playtest (hors-sim).

**Q_R9_4 — Fréquence du signal CONTRE LA MORT vs Moment du Run : cannibalisation après
réforme ?** La Proposition A (reformuler §2.10 avec attribution agence) + Proposition D
(calibrer le seuil par rôle) peuvent potentiellement augmenter la fréquence du signal §2.10
pour les carries (seuil abaissé). Si les carries déclenchent §2.10 ET que la cascade DoT
déclenche le Moment du Run au même combat, le signal double se produit. La règle de
priorité « Moment du Run > Surprise de Placement » (§2.4 PRÉCONDITION) doit être étendue :
**si §2.10 ET §2.4 se déclenchent au même combat → afficher §2.4 (plus impactant) +
§2.10 en ligne secondaire, non en signal principal**. Doc, 0 code. À intégrer dans la
spec §2.4/§2.10.

---

## 5. VALIDATIONS SOURCÉES — propositions du round 8 qui TIENNENT pour NOS contraintes

### 5.1 Ovsiankina + Goal Gradient pour la structure de progression Grimoire — VALIDÉ

La méta-analyse 2025 (Nature H&SS) confirme l'Ovsiankina comme un effet universel robuste.
L'architecture en 3 chapitres du Grimoire (I=reliques, II=essences famille, III=sigils)
avec des seuils visibles est CORRECTE psychologiquement. Les silhouettes du Chapitre III
(contenu partiellement visible, invitation à compléter) sont exactement le mécanisme
Ovsiankina optimal : la tâche est interrompue ET son état est visible.

**Dans NOS contraintes** : la contrainte de ne pas avoir de notifs push (async solo) est
compensée par le fait que le Grimoire est VISIBLE au lancement (écran de menu). Si le
joueur rouvre le jeu et voit « Chapitre II : 8/15 unités poison » en arrière-plan, l'effet
Ovsiankina peut se déclencher sans notification push. C'est une architecture correcte.

### 5.2 Mode statistique du Nom de Build — VALIDÉ pour la cohérence d'identité

« TU ES PRINCIPALEMENT UN BRÛLEUR [4/10] » (mode sur 10 runs) est correctement formulé
pour créer la RECONNAISSANCE DE PATTERN (dev.to/yurukusa 2026, cité r08) plutôt que la
liste chronologique. La nuance Q_R8_3 (instabilité sur sessions courtes) est résolue par
le mode statistique.

**Ce round confirme** que cette formulation reste le meilleur compromis pour S1, à condition
que le joueur ait joué ≥3 runs (mode statistique sur 1-2 runs est non-représentatif).
Ajouter une condition : n'afficher le mode statistique que si `#runs ≥ 3` ; avant, afficher
« ARPENTEUR DU PUITS — LE PUITS TE DÉCOUVRE ENCORE » (formulation d'exploration, pas de
classification précipitée).

### 5.3 Enveloppe VRR pondérée hédonique (§round-08 §7) — VALIDÉ structurellement

L'ajout du signal §2.10 avec poids hédonique 2 dans l'enveloppe (44-60 unités pondérées)
est structurellement cohérent. L'enveloppe reste dans les bornes. Le round 9 ne remet pas
en question l'enveloppe elle-même — seulement la catégorisation du signal §2.10 comme
« relief structurellement distinct ». Même si §2.10 est un « second Moment du Run négatif »
(§2.1), son poids hédonique de 2 reste justifié (moins impactant qu'une cascade réussie de
poids 3, mais plus que le reroll de poids 1).

### 5.4 Daily exclu du signal d'identité Grimoire — VALIDÉ

Exclure les Daily de la persistance dans `grimoire.lua` est correct et important. Un run
sous contrainte imposée (Daily poison pour un joueur BRÛLEUR habituel) ne doit pas polluer
le mode statistique d'identité. Cette décision est alignée avec StS Daily (n'alimente pas
l'Ascension). Confirmé sans réserve.

---

## 6. REJETS — propositions qui auraient pu être soulevées mais sont contreproductives

### 6.1 REJETÉ — Notification push « ton Grimoire est incomplet » pour déclencher Ovsiankina

L'Ovsiankina exige de VOIR la tâche inachevée. Une notification push serait le mécanisme
le plus direct — mais elle viole la DA grimdark (aucun jeu grimdark oppressif ne pousse
des notifications de type mobile-gamey) ET le modèle solo-dev S1 (pas de backend push).
**La solution correcte est de rendre l'incomplétion visible AU LANCEMENT**, pas de la pousher.
Différé post-backend v1.0 si la rétention inter-session s'avère problématique.

### 6.2 REJETÉ — Ajouter une 6e source VRR (relique spéciale « surprise ») pour résoudre l'homogénéité

Tentant : créer une relique dont l'effet n'est révélé QU'EN COMBAT (retour au modèle
cryptique, rejeté décision §7). Ce serait un mécanisme de surprise garantie → contraste
hédonique. **Mais la décision §7 est DÉFINITIVE** (reliques lisibles, pivot 2026-06). Et
même si on l'ignoriait, une relique-surprise ne résout pas le problème d'homogénéité de
valence (c'est toujours une surprise positive → même circuit). **Rejeté : viole décision
définitive #7 ET ne résout pas le vrai problème.**

### 6.3 REJETÉ — Grimoire chapitre de « statistiques de run » (win-rate par famille, TTK moyen)

Idée : montrer « ton win-rate en BRÛLEUR = 62 % » dans le Grimoire comme indicateur de
maîtrise. **La faille** : en S1 avec < 20 runs, aucune statistique de win-rate n'est
fiable (intervalle de confiance énorme). Afficher « 62 % de win-rate » avec 8 données =
bruit présenté comme signal → crée des FAUSSES CROYANCES sur sa propre compétence
(confirmation bias : un joueur à 62% croit qu'il maîtrise alors qu'il peut avoir joué
contre des IA faibles en early). **Différé à post-100 runs, pas en S1.**

---

## 7. CHALLENGE CLÉ — résumé pour le synthétiseur

**Trois affirmations du round 8 tiennent mais sont trop fortes dans les nuances
d'implémentation :**

1. **§2.10 (signal CONTRE LA MORT) n'est pas du contraste hédonique pur dans un système
   déterministe** — c'est un second Moment du Run de valence évitement. Toujours valide
   d'implémenter, mais (a) reformuler l'attribution vers l'agence du joueur (Proposition A,
   0 coût), et (b) bloquer jusqu'à CONFIG-SURVIVAL pour calibrer les seuils par rôle
   (Proposition D, ~15 lignes sim), deux préconditions non optionnelles.

2. **Le badge MAÎTRE mesure la découverte d'apex, pas leur utilisation victorieuse** — ce
   n'est pas du SDT-compétence (type 3), c'est du SDT-contenu (type 2) renommé. Reformuler
   en condition de VICTOIRE AVEC L'APEX (Proposition B, ~1 h data + RENDER).

3. **Le near-miss (§2.3) est le driver PRIMAIRE du one-more-run en S1 sans communauté** ;
   l'identité (§2.4bis) est secondaire. La roadmap les présente comme équipriorités —
   clarifier la hiérarchie en doc (Proposition C) pour que les futures lentilles ne confondent
   pas les deux rôles et ne considèrent pas §2.4bis comme pouvant compenser une faiblesse
   de §2.3.

**Ces trois corrections sont légères (0 moteur, ~1 h RENDER max, ~15 lignes sim) et
n'invalident pas l'architecture de rétention construite en 8 rounds — elles la précisent
là où les mécanismes psychologiques étaient approximatifs. Le round 8 avait raison sur
les diagnostics. Ce round corrige les solutions.**

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 9/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *Peak-End Rule et mémoire émotionnelle : https://impulsebuyingpsychology.com/peak-end-rule/*
- *Ovsiankina/Zeigarnik méta-analyse 2025 (Nature H&SS) : https://www.nature.com/articles/s41599-025-05000-w*
- *SDT Self-Determination Theory pour les jeux multijoueurs : https://digitalthrivingplaybook.org/big-idea/self-determination-theory-for-multiplayer-games/*
- *SDT compétence computationnelle (4 sous-composantes) — arXiv 2502.07423 : https://arxiv.org/pdf/2502.07423*
- *Grid Sage Games — Designing for Mastery in Roguelikes 2025 : https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w/roguelike-radio/*
- *Entalto Studios — 5 Essential Tips to Make Your Roguelite Game Work : https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/*
- *Variable rewards et habituation (Retention.Blog) : https://www.retention.blog/p/variable-rewards*
- *Variable ratio reinforcement et addiction (ScienceDirect) : https://www.sciencedirect.com/article/pii/S0306460323000217*
- *Agency in roguelikes : https://thom.ee/blog/what-makes-or-breaks-agency-in-roguelikes/*
- *Switchblade Gaming — Best Auto-Battler Games 2026 : https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/*
- *PC Gamer — The Bazaar 2026 post-lancement : https://www.pcgamer.com/games/card-games/after-its-disastrous-launch-last-year-im-here-to-tell-you-that-2025s-most-promising-auto-battler-finally-lives-up-to-its-potential/*
- *Ordeal Pleasure in Souls-like Games — arXiv 2603.26677 : https://arxiv.org/pdf/2603.26677*
- *SDT competition et jeux (PMC 2025) : https://pmc.ncbi.nlm.nih.gov/articles/PMC12412733/*
