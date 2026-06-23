# Round 05 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v5, intégré round 4),
> `round-04.md` (synthèse), `rounds/r0{1,2,3,4}-retention-addiction.md`,
> `competitive/super-auto-pets.md`, `competitive/balatro.md`, `competitive/slay-the-spire.md`,
> `competitive/hades.md`, `competitive/the-bazaar.md`, `competitive/tft.md`,
> `competitive/hs-battlegrounds.md`, `competitive/postmortems.md`.
>
> **Recherche web menée ce round** :
> - EBSCO Research Starters (Schedules of Reinforcement, VRR vs FI) :
>   https://www.ebsco.com/research-starters/psychology/schedules-reinforcement
> - MDPI 2025 (Inherent Addiction Mechanisms in Gacha, pity systems) :
>   https://www.mdpi.com/2078-2489/16/10/890
> - ScienceDirect 2025 (Monetization gacha, behavioral triad, pity systems) :
>   https://www.sciencedirect.com/science/article/abs/pii/S1875952125001247
> - Boyle et al. 2024 (Wordle near-miss goal gradient, Nature Sci Rep) :
>   https://www.nature.com/articles/s41598-024-74450-0 (rapporté round 4)
> - Kao et al. 2024 (CHI, Juicy Feedback, sense of agency) :
>   https://nickballou.com/publication/2024-kao-et-al-juicy/ (rapporté round 4)
> - Deci & Ryan SDT (Self-Determination Theory, autonomie/compétence/appartenance) :
>   https://selfdeterminationtheory.org/wp-content/uploads/2024/06/2024_MollerKornfieldLu_CompDigitalGame.pdf
> - LogRocket 2024 (Goal Gradient Effect, progress bars, UX) :
>   https://blog.logrocket.com/ux-design/goal-gradient-effect/
> - Nunes & Drèze 2006 (Goal Gradient Hypothesis Resurrected) :
>   https://www.researchgate.net/publication/239776073 (rapporté rounds 1-4)
> - Diva-portal 2026 (Hades 2 vs TBOI minimal meta-progression) :
>   https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf (rapporté round 4)
> - Kyzrati 2025 (Grid Sage Games, mastery in roguelikes) :
>   https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/ (rapporté round 4)
> - Theseus.fi Kammonen (Progression Systems in Roguelite Games, academic) :
>   https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
>
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.
>
> **Posture adversariale** : les rounds 1-4 ont converge sur trois mécanismes de rétention
> adoptés : (1) Moment du Run enrichi placement+P75, (2) Grimoire 3 chapitres arc Dead God,
> (3) Surprise de placement. Ce round 5 attaque les HYPOTHÈSES IMPLICITES qui restent non
> questionnées dans la v5, en particulier : (a) le VRR du Grimoire est-il structurellement
> autonome ou dépendant de la découverte d'effets non-attestés ? ; (b) la surprise de
> placement se déclenche-t-elle assez tôt dans le run pour combler la « zone de latence 0-3 »
> où le joueur quit ? ; (c) l'hypothèse que l'attribution post-hoc (Déclos 2025) compense
> entièrement le découplage spectateur est-elle EXCESSIVE — y a-t-il un type de joueur pour
> qui l'agence spectateur échoue systématiquement ? ; (d) le « moteur pré-run ranked » adopté
> est-il le levier du bon niveau — ou y a-t-il une couche en amont (la décision de lancer une
> SESSION, pas un RUN) que la roadmap n'adresse pas ?

---

## 0. Position de l'agent

Les rounds 1-4 ont posé des fondations psychologiquement solides. Ce round 5 ne les démonte
pas — il cherche les zones de FAUSSE SÉCURITÉ où une citation correcte masque une hypothèse
de transférabilité non éprouvée dans NOS contraintes. Le déterminisme async + la run courte +
la DA grimdark changent le contexte psychologique de manière non triviale.

**Challenge central** : la roadmap v5 traite la rétention comme si le joueur avait déjà
démarré un run. Mais les études de churn les plus robustes (Kammonen theseus.fi 2024 ;
diva-portal 2026) montrent que le premier abandon est PRÉ-RUN : le joueur ouvre le jeu,
voit l'écran de sélection, et ferme. Les mécanismes P0 (Moment du Run, Surprise de placement)
sont tous post-combat. Le §6.11 (moteur pré-run ranked) est le seul élément en amont — mais
il ne traite que le ranked. La **zone de latence 0-1 RUN** reste non adressée pour l'unranked.

---

## 1. ACCORDS — ce qui tient, avec le pourquoi précis et les nuances

### 1.1 Accord fort : le Grimoire 3 chapitres répond à un vrai besoin de VISIBILITÉ D'ARC LONG

**Accord avec round 4 §1.9 ; ROADMAP-draft v5 §6.7.**

La restructuration en Afflictions / Essences / Abysses est correcte et bien sourcée
(diva-portal 2026 : « path to Dead God » TBOI = jalons visibles). Ce round confirme avec
une nuance supplémentaire :

**Kammonen 2024 (theseus.fi, Progression Systems in Roguelite Games)** établit que la
méta-progression de *connaissance* (sans puissance) fonctionne à condition que le joueur
ait un **accès visuel à sa progression relative** — pas seulement à ce qu'il a découvert,
mais à ce qu'il lui reste. La structure 3-chapitres donne ça. Mais **la cadence de déblocage
du Chapitre II (seuil 8/12, Q_R4_2) est une question ouverte que la roadmap n'a pas tranchée
avec des données**. C'est un litige mineur mais non nul.

**Le sous-accord sur le Chapitre III (Abysses = synergies sigil×famille, P4)** : verrouillé
jusqu'à P4 = ~6-9 mois de développement après v0.11. Zeigarnik fonctionne pour un horizon
**visible mais fermé**. Un horizon **absent** (P4 non codé = chapitre III invisible même en
silhouette) ne crée pas d'effet Zeigarnik — il ne fait rien du tout. **Le Chapitre III doit
exister comme silhouette dès P2, même si son contenu ne sera livré qu'en P4.** La roadmap
v5 dit « Chapitre III verrouillé jusqu'à Chapitre II complet » : c'est correct pour le
déblocage, mais l'**existence visible** du chapitre III (silhouette + titre + nombre de
synergies « ??? ») doit être présente dès P2. Ce point n'est pas explicitement affirmé dans
§6.7 — à clarifier.

### 1.2 Accord fort : la Surprise de Placement comme source VRR propre au plateau-graphe

**Accord avec round 4 §1.10 ; ROADMAP-draft v5 §2.7.**

Boyle et al. 2024 (Nature Sci Rep) est une source solide pour le near-miss sous contrôle
personnel. L'application au plateau-graphe est correcte : déplacer 1 unité = une décision
sous agence totale. **Ce mécanisme est orthogonal aux cascades DoT** (confirmation du round 4 :
utile en early, plateau peu peuplé).

**Nuance de ce round** : la condition « uniquement si le combat n'a impliqué que le front
(depth < 2) » est trop restrictive en pratique. En early (rounds 1-3), presque tous les
combats n'impliquent que le front (peu d'unités, peu de slots). La condition est donc
quasi-systématiquement vraie — ce qui est bien, mais la formulation laisse entendre que le
signal est rare. **À reformuler** : « déclencher si depth_max <= 2 OU si #unités_adverses <=
3 », pour couvrir aussi les combats courts mid-run où l'adversaire est faible.

**Accord sur la désactivation automatique** (`grimoire:hasLearnedAdjacency()`) : correcte en
principe. **Mais le critère de désactivation n'est pas défini**. Proposer : désactivé après
que le joueur a activé ≥5 arêtes distinctes sur 3 combats différents (mesurable depuis le
bus, déjà encodé). Ce seuil doit être dans la spec P0, pas laissé flottant.

### 1.3 Accord fort : P75 sur 1000 seeds variées pour le seuil de chaîne du Moment du Run

**Accord avec round 4 §1.13 ; ROADMAP-draft v5 §2.4.**

La critique du biais d'échantillon des 250 seeds fixes (r04-retention §2.1) est correcte
et bien sourcée (Kao et al. 2024 CHI). Ce round confirme avec un angle supplémentaire :

Hopson 2001 (VRR résiste à l'extinction à ~20-30 %) est la source citée pour la cible
~25 % des combats. **Cette fréquence cible est raisonnable**, mais elle suppose que le VRR
du Moment du Run est le mécanisme DOMINANT de rétention dans notre jeu — ce que la roadmap
n'établit pas explicitement. Si la Surprise de Placement se déclenche plus souvent (~40-50 %
des combats en early via la condition laxe), et le Moment du Run à ~25 % en mid-late, la
distribution temporelle est saine. Mais si les deux se déclenchent simultanément (même
combat : cascade + arête manquée), il y a un risque de **dilution des signaux** (l'un
écrase l'autre). **À tester** : est-ce que combat avec `chain_len ≥ P75` et `edge_missed ≥
1` se chevauchent souvent ? Si oui, prioriser l'un des deux (probablement le Moment du Run,
car post-victoire).

### 1.4 Accord conditionnel : moteur pré-run ranked (§6.11) — le mécanisme est correct mais INCOMPLET

**Accord partiel avec round 4 §1.6 ; ROADMAP-draft v5 §6.11.**

L'incertitude résoluble pré-run (seganerds 2026 : « uncertainty keeps you queuing » ;
TFT LP display à la sélection de mode, immortalboost) est un mécanisme solide pour le
joueur qui est **déjà en session**. Le goal-gradient (Nunes & Drèze 2006 ; LogRocket 2024 :
« closer to goal = higher motivation ») s'active bien sur « il vous manque 23 pts ».

**Mais ce round identifie une lacune en amont** : ce moteur pré-run **suppose que le joueur
a déjà ouvert le jeu et navigué jusqu'à l'écran de sélection**. Il ne traite pas la décision
**d'ouvrir le jeu** (la session initiation). Ce sont deux comportements distincts en
psychologie comportementale (Fogg Behavior Model 2009 : motivation + ability + prompt ; le
§6.11 fournit le prompt → motivation, mais seulement quand la session est déjà engagée).

**Impact sur NOS contraintes** : en async sans timer, l'avantage est de pouvoir jouer
«whenever» (SAP, Fabian Fischer @Ludokultur). Mais l'absence de timer signifie aussi
**aucune urgence externe** pour ouvrir le jeu. La session initiation doit donc être motivée
par un signal **EXTÉRIEUR à la session** (notification, streak social, événement limité).
La roadmap v5 n'a aucun mécanisme de ce type. Voir §2.1 pour le désaccord détaillé.

---

## 2. DÉSACCORDS — ce qui est faible, mal calibré ou non étayé

### 2.1 DÉSACCORD FORT : la roadmap adresse le VRR INTRA-SESSION mais IGNORE la session initiation — la zone de churn la plus critique

**Lacune de v5** (aucun §) : l'écran de menu est le seul déclencheur de session dans The
Pit. En async sans timer, rien n'invite le joueur à revenir après une pause de plusieurs
jours.

**Preuve mécaniste** : le modèle SDT (Deci & Ryan ; Möller, Kornfield & Lu 2024,
selfdeterminationtheory.org) identifie 3 besoins psychologiques qui maintiennent l'engagement
intrinsèque : **autonomie** (je joue parce que je veux), **compétence** (je progresse), et
**appartenance** (je joue avec/contre des gens qui comptent). The Pit satisfait fortement
l'autonomie (async, pas de timer) et la compétence (Grimoire, ranked). Mais l'**appartenance**
est structurellement absente : le joueur ne sait jamais si quelqu'un a joué contre son ghost,
si son build a été battu, si quelqu'un a atteint le même tier cette semaine. Or SDT 2024 montre
que relatedness est le **facteur le moins étudié** et souvent le **facteur manquant** dans les
jeux de type solo-compétitif (Möller 2024 : « relatedness need satisfaction frequently ignored
despite its importance »).

**Ce qui manque** : un **signal de retour passif** — une notification (ou un élément
d'interface au PROCHAIN lancement, pas cette session) qui dit « 3 joueurs ont affronté ton
build cette semaine » ou « Ton Âme du Puits a gagné 2 combats hier ». Ce signal :
- Ne **rompt pas l'async** (ton build est un snapshot figé ; les résultats sont publics).
- Ne requiert **aucun serveur temps réel** (les résultats des combats locaux contre des
  ghosts sont connus localement).
- Satisfait le besoin d'**appartenance** sans live : « mon build a eu une vie propre ».
- Est un **prompt de session initiation** (Fogg : trigger externe au bon moment).

**En v1 LOCAL** (avant backend) : le store `snapstore.lua` enregistre les combats contre des
ghosts locaux. Chaque combat résolu génère un event `{ghost_id, result, round}` → un
compteur « ton ghost a été affronté N fois » est calculable localement. Affichage au lancement
(écran menu) : « LE PUITS A UTILISÉ TON SPECTRE — [N] ENTITÉS L'ONT AFFRONTÉ DEPUIS TA
DERNIÈRE DESCENTE ». RENDER + IO hors SIM, 0 invariant.

**Source** : Deci & Ryan SDT (Möller et al. 2024, need satisfaction in digital games) ;
Fogg Behavior Model (motivation + ability + prompt sequence) ; SAP §3.1 (snapshot comme
adversaire perçu quasi-humain — la réciprocité renforce l'engagement).

**Verdict** : c'est une **LACUNE NON TRAITÉE de v5**. Il ne s'agit pas d'une fonctionnalité
complexe mais d'un signal d'appartenance minimal, async-safe, local-first. **Priorité P0**
(même coût que la Surprise de Placement — RENDER + lecture store local, sans serveur).

### 2.2 DÉSACCORD MODÉRÉ : l'arc VRR repose sur 3 sources TEMPORELLEMENT SÉQUENTIELLES — mais la distribution temporelle N'EST PAS VÉRIFIÉE pour qu'elles soient réellement complémentaires

**Ce que v5 affirme** (§1.1 + §2.4 + §2.7) : les 3 sources de VRR sont complémentaires
temporellement — surprise de placement (early), Moment du Run (mid-late), reliques (offre
1-parmi-3 tous les 3 combats).

**Le problème** : cette complémentarité temporelle est une HYPOTHÈSE, pas un fait mesuré.
Elle repose sur deux sous-hypothèses :
1. La surprise de placement se déclenche surtout en early (plateau peu peuplé = arêtes
   manquées fréquentes).
2. Le Moment du Run se déclenche surtout en mid-late (DoT denses = chaînes longues).

**Pourquoi ces hypothèses peuvent être fausses** :

**Sub-hypothèse 1 fausse possible** : un plateau de 3-4 unités en early a peu d'arêtes
*activables* (le sigil carré avec 3 unités a 2 arêtes max, dont beaucoup sont déjà actives).
Le nombre d'arêtes *manquées* (déplaceable→+1 arête) peut être faible précisément parce
que les adjacences disponibles sont peu nombreuses. **La surprise de placement est peut-être
plus fréquente en mid-run (5-7 slots, sigil anneau ou diamant) qu'en early.** Sans sim, on
ne sait pas.

**Sub-hypothèse 2 fausse possible** : les chaînes DoT peuvent être longues en early si le
joueur a mis 3 unités burn/poison directement. Le Moment du Run peut se déclencher dès le
round 2 dans un build focalisé — ce qui signifierait que les deux signaux se chevauchent
en mid-run (rounds 3-6), créant une saturation de signaux positifs = dilution (Kao et al.
2024 : amplification excessive réduit le sentiment d'agence).

**Proposition concrète** : la sim `tools/sim.lua` existe et les deux métriques sont
mesurables :
- Fréquence de `chain_len ≥ P75` PAR ROUND (1-10) : distribution du Moment du Run.
- Fréquence de `edge_missed ≥ 1` PAR ROUND : distribution de la Surprise de Placement.
- Chevauchement : `P(chain AND edge_missed | round_i)` pour chaque round.

**Ajouter ces métriques en P0 avant de coder les deux signaux.** Si les distributions
se chevauchent significativement en round 4-6, introduire une **priorité de signal** :
Moment du Run > Surprise de Placement (la cascade est plus spectaculaire ; la surprise de
placement passe en mode silencieux si le Moment se déclenche le même combat).

**Source** : Kao et al. 2024 (CHI) : « amplification unexpectedly reduced [agency] » ;
principes de game feedback hiérarchique (Hunicke et al. 2004 MDA, « aesthetics don't
stack neutrally »).

### 2.3 DÉSACCORD MODÉRÉ : le pity signal adopté (§2.5 v5, litige #L/#L') souffre d'un défaut structurel — la frontière de la compulsion N'EST PAS LÀ OÙ LA ROADMAP LA CROIT

**Ce que v5 dit** (#L/#L', round-04 §3 litige 12) : pity = signal sans garantie explicite,
cappé ×1.5, à 50-60 % du hunt médian. Signal implicite (icône qui s'intensifie, pas de
chiffre). Sources : MDPI 2025 + ACM SIGCHI 2023.

**Ce que la recherche 2025 dit EN PLUS** :

**ScienceDirect 2025** (Monetization mechanisms in gacha, behavioral triad) : les systèmes
pity créent un **réinvestissement cognitif** (« j'approche la garantie ») qui déclenche des
comportements compulsifs **même sans argent réel**, simplement via le *coût cognitif*
investi dans le tracking du pity. Ce n'est pas le seuil de 55 pulls (gacha) qui s'applique
directement — en jeu non-monétisé (or in-game), le mécanisme est plus léger. **Mais** :

Le MDPI 2025 identifie deux comportements distincts selon le type de pity :
- **Hard pity** (garantie explicite à N) : déclenche la compulsion active (le joueur
  calcule N − compteur et gère ses ressources pour « l'atteindre »).
- **Soft pity** (probabilité croissante, signal implicite) : déclenche un arousal plus
  doux, moins compulsif, mais aussi **moins motivant**.

**La roadmap v5 adopte le soft pity implicite** (signal d'intensification sans chiffre) —
c'est le choix le moins compulsif, mais aussi potentiellement le moins efficace pour la
rétention. **Ce n'est pas un problème critique** (l'or in-game sans valeur réelle réduit
l'enjeu), mais c'est un **vrai trade-off non nommé** dans la roadmap.

**Question ouverte (#L concrète)** : à quelle fréquence une unité rank-5 est-elle « proche »
dans notre pool à 83 unités ? Si le hunt médian d'une rank-5 est 7 boutiques (chiffre P2.5 du
pool, non encore sim), le seuil à 50-60 % = ~4 boutiques. Est-ce suffisamment long pour
créer l'arousal du near-miss sans être frustrant ? **Ou est-ce que le pool à 83 unités et le
tier-gating rendent le hunt intrinsèquement long (>10 boutiques), auquel cas 50-60 % = 5-6
boutiques — plus que ce que le joueur peut tracker sans interface** ?

**Proposition** : la spec de pity DOIT être conditionnée à la **sim du hunt médian par rang**
(§7.1 de v5 le liste comme « précondition »). **Élever cette précondition en BLOQUANT la
spec pity tant que la sim n'est pas faite.** Sans le chiffre, la spec est une présupposition.

### 2.4 DÉSACCORD LÉGER : l'attribution post-hoc (Déclos 2025) est VRAIE pour un profil de joueur mais échoue pour un autre — et la roadmap ignore le second profil

**Ce que v5 dit** (§2.4, §1.12) : l'attribution post-hoc (fierté de construction, Déclos 2025)
compense le découplage spectateur. Le joueur a *construit* le build → le combat spectateur
concentre et différé l'authorship dans le build.

**Ce qui n'est pas dit** : Déclos 2025 (British Journal of Aesthetics) porte sur les
« secondary players » qui ont **choisi les règles** du spectacle. Il suppose un joueur qui
**s'identifie à ses décisions de build**. Ce profil correspond au joueur ENGAGÉ (5+ runs).

**Il existe un second profil** : le joueur PASSIF qui subit le RNG de boutique, copie des
builds vus ailleurs, et ne perçoit pas ses décisions de placement comme *les siennes*. Pour
ce joueur, l'attribution post-hoc échoue : « ton [unité] a consumé 5 ennemis » n'est pas
une fierté de construction si l'unité a été achetée par réflexe, pas par stratégie.

**Preuve** : SDT 2024 (Möller et al.) : le besoin d'autonomie (« je joue parce que je
veux ») est satisfait quand le joueur **perçoit** ses choix comme causaux. Un joueur qui
ne comprend pas les synergies d'adjacence au round 2 ne perçoit pas ses décisions de
placement comme causales — il perçoit le combat comme du pur hasard.

**Impact sur NOS contraintes** : ce n'est pas le joueur qui va quit après 20 runs — c'est
le joueur qui va quit après 2-3 runs, avant que l'attribution post-hoc s'enclenche. **La
zone 0-3 runs est la zone à risque maximale**, et c'est précisément là où le mécanisme
Déclos 2025 ne fonctionne pas encore (le joueur n'a pas encore intégré ses décisions comme
siennes).

**Ce qui manque dans la roadmap** : un mécanisme de **guidance d'agence précoce** (rounds
1-3) qui aide le joueur à percevoir ses premières décisions comme causales, *avant* que
la fierté de construction s'enclenche naturellement. Exemple : au round 1, si le joueur
place une unité sur la case centrale du sigil carré (4 voisins), un micro-signal (RENDER) :
« [SIGIL CARRÉ] CONVERGE SUR TON [UNITÉ] » — pas un guide, une révélation du plateau.
Ce signal est une forme de **tutoriel cryptique** qui attribue la décision au joueur.

**Garde-fou DA** : grimdark = cryptique, pas pédagogique. Les signaux de guidance doivent
être formulés comme des révélations du Puits, pas comme des conseils. **Différent de la
Surprise de Placement** (qui est rétrospective — après la défaite) : ce signal est
**prospectif** (pendant le build) et se déclenche sur les bonnes décisions, pas les mauvaises.

**Source** : SDT 2024 (Möller et al., autonomy need satisfaction, selfdeterminationtheory.org) ;
Déclos 2025 (British J. Aesthetics, limites du secondary player authorship au joueur engagé).
**Ce n'est pas un désaccord sur la validité de Déclos — c'est une extension au second profil
de joueur que Déclos n'a pas étudié.**

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — Signal d'appartenance asynchrone : « le Puits a utilisé ton spectre » (P0, RENDER + IO local, ~2 h)

**Ce** : à chaque lancement de The Pit (écran menu), lire depuis `snapstore.lua` le nombre
de combats résolus contre le ghost du joueur local depuis sa dernière session. Si N ≥ 1 :
afficher un message grimdark « LE PUITS A UTILISÉ TON SPECTRE — [N] ÂME[S] L'ONT AFFRONTÉ
DEPUIS TA DERNIÈRE DESCENTE ». Message cliquable → résumé des combats (qui a gagné, en
quelques lignes depuis le bus JSONL local). Sinon : rien (pas de message « 0 combats »).

**Compteur technique** : dans `snapstore.lua`, ajouter un champ `battles_since_last_session`
incrémenté par `serveComp` quand le ghost local est servi, et remis à 0 à chaque lancement
(`love.filesystem`, hors SIM, IO déjà prévu). **0 invariant. Zone sans test → ajouter un
test que le compteur s'incrémente correctement sur le golden.**

**Pourquoi priorité P0** :
- Coût : RENDER + ~10 lignes `snapstore.lua` + 3 lignes menu.
- Bénéfice : satisfait le besoin d'**appartenance** SDT (Möller et al. 2024) = le besoin
  le moins adressé dans la roadmap actuelle.
- Traite la **session initiation** (Fogg : prompt externe au lancement, pas pendant la session).
- **Local-first** : fonctionne sans backend. La v2 (backend) enrichit avec les combats inter-joueurs.
- Aucun lien avec la monétisation → pas de dérive compulsive (ScienceDirect 2025 : pity
  compulsif = quand un coût réel est en jeu).

**Garde-fou piliers** : async-safe (ghost figé, pas de live). Déterministe (compteur local,
pas de RNG). DA grimdark (formulation du Puits, pas de félicitation).

### Proposition B — Validation des distributions temporelles VRR avant de coder les signaux (P0 précondition, ~0.5 h sim)

**Ce** : ajouter 3 métriques dans `tools/sim.lua` AVANT de coder la Surprise de Placement et
le Moment du Run :
1. Distribution `chain_len` par round 1-10 : `--chain-by-round --n 500 --random-seeds`.
2. Distribution `edge_missed` par round 1-10 : nécessite de simuler le graphe sigil +
   positions (la sim actuelle ne simule pas le build, seulement le combat — à vérifier si
   c'est faisable en headless, sinon mesurer via `--build-log` de `tools/sim.lua`).
3. Chevauchement : `P(chain_len ≥ P75 AND edge_missed ≥ 1 | round_i)`.

Si `P(chevauchement) > 0.30` pour le même round → introduire une **règle de priorité de
signal** (Moment > Surprise) pour éviter la saturation.

**Pourquoi précondition** : Kao et al. 2024 (CHI) montre que l'amplification excessive
réduit le sentiment d'agence. Deux signaux positifs simultanés peuvent diluer l'attribution
causale. Cette mesure coûte ~0.5 h et évite de coder deux signaux qui se cannibalisent.

### Proposition C — Guidance d'agence précoce : signal « convergence du sigil » au round 1-2 (P0, RENDER, ~1 h)

**Ce** : dans `build.lua` (RENDER, pas SIM), au round 1-2 uniquement (éteindre après le
round 3 pour ne pas être paternaliste) : quand le joueur **place** une unité sur une case
ayant **≥3 arêtes actives** (lue depuis `shapes[shape].edges` + positions occupées + la
case placée), déclencher un micro-signal grimdark :
« [NOM_SIGIL] RESSENT SA FORME » + légère pulsation de la case (RENDER).

**Différence avec la Surprise de Placement** :
- La Surprise est **rétrospective** (post-défaite, arête *manquée*).
- Ce signal est **prospectif** (pendant le build, arête *activée*).
- La Surprise s'adresse au joueur ENGAGÉ qui comprend le plateau.
- Ce signal s'adresse au joueur NOVICE (rounds 1-2) qui n'a pas encore intégré les arêtes.

**Pourquoi ça traite le profil 2 (joueur passif)** : le signal lui dit, sans explication,
que sa décision de *placement* a eu un effet sur le Puits. Il perçoit sa décision comme
causale — l'attribution s'enclenche avant même qu'il comprenne le mécanisme.

**Garde-fou DA** : formulé comme le Puits qui réagit, pas comme un tutoriel. Désactivé
après le round 3 (ou dès que `grimoire:hasLearnedAdjacency()` est vrai). **Zone sans
test → test que le signal se déclenche sur le bon slot dans le golden (case centrale carré
avec 2 voisins existants).**

### Proposition D — Clarifier la spec de pity comme BLOQUÉE par la sim hunt médian (P3 précondition réaffirmée)

**Ce** : inscrire explicitement dans la roadmap v5 §7.1 que **la spec de pity (litige #L)
ne peut pas être finalisée avant la sim du hunt médian par rang** (P(rang-X visible en N
boutiques tier-Y)). Si le hunt médian rang-3 > 7 boutiques en T2 → recalibrer le seuil pity.

**Non pas un travail nouveau** : §7.1 liste déjà le hunt médian comme précondition. Ce round
demande de **l'élever en gate dur** (pity spec suspendue, pas juste notée) pour éviter de
spécifier un seuil aveugle qui se révèle trop permissif (arousal insuffisant) ou trop agressif
(compulsion sans valeur réelle, ScienceDirect 2025).

**Chiffre cible** : seuil pity à `max(3, 0.5 × hunt_médian_rang_2_T2)` (formule déjà adoptée
round 3, litige #L). La formule tient ; le hunt médian est le seul paramètre inconnu.

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R5_1 — Seuil de désactivation de la Surprise de Placement** : `grimoire:hasLearnedAdjacency()`
n'est pas défini. Proposer : désactivé après ≥5 arêtes activées sur ≥3 combats distincts (bus
JSONL). À confirmer avec le game designer. Risque si trop tôt : les joueurs novices ne voient
pas le signal assez longtemps. Risque si trop tard : les joueurs avancés le voient comme du
bruit.

**Q_R5_2 — Appartenance locale vs appartenance inter-joueurs** : le signal « spectre utilisé »
(Prop A) est local-first. En v1, N = combats contre les ghosts du pool LOCAL (FIFO 200
`snapstore.lua`). Si le joueur est seul (cold-start, pool vide), N = 0 et le signal ne se
déclenche jamais → la prop A ne fonctionne pas en cold-start. Mitigation : ajouter des
encounters IA dans le compte (« les Invocations ont afronté ton spectre ») — mais c'est
tricher sur l'appartenance. **Decision design : accepter N = 0 silencieux en cold-start,
ou déclencher sur les IA comme fallback avec formulation différente ?**

**Q_R5_3 — Profil de joueur passif : mesurable ?** Le profil 2 (joueur passif, non-agentif)
est-il détectable dans les données du run ? Proxy possible : `reroll_count / round` (joueur
passif = peu de rerolls, achat systématique du premier) + `placement_variance / run` (joueur
passif = placements peu variés entre rounds). Si détectable → activer la guidance d'agence
précoce (Prop C) seulement pour ce profil (sinon condescendant pour le joueur engagé).

**Q_R5_4 — Cadence de déclenchement du Moment du Run en ranked vs unranked** : le Moment du
Run est RENDER, lu du bus. En ranked (ghost humain plus optimisé), les combats sont potentiellement
plus courts (moins de chaînes longues si les builds adverses sont efficaces). La distribution
`chain_len` ranked peut-elle différer significativement de l'unranked ? Si oui, le seuil P75
(calculé sur 1000 seeds mixtes) peut être inadapté pour le ranked. **À mesurer séparément.**

---

## 5. CHALLENGE CLÉ (résumé)

La roadmap v5 a une couche de rétention intra-session très bien construite et sourcée (Moment
du Run, Surprise de Placement, Grimoire 3 chapitres). Ce round identifie trois lacunes
complémentaires : (1) **la session initiation est ignorée** — le joueur qui revient après 3
jours d'absence n'a aucun signal d'appartenance pour rouvrir The Pit, et ce vide n'est pas
comblé par les mécanismes P0 actuels qui sont tous post-launch-de-run ; le signal «spectre
utilisé» (Prop A) est une correction à coût nul qui traite exactement ce vide via la SDT
(besoin d'appartenance). (2) **la complémentarité temporelle des 3 sources VRR est une
hypothèse non mesurée** — avant de coder deux signaux de feedback distincts, une sim de 30
minutes (Prop B) valide ou invalide l'assumption ; si les signaux se chevauchent au round 4-6,
ils se cannibalisent. (3) **le profil du joueur passif (0-3 runs) n'est pas adressé par
l'attribution post-hoc de Déclos 2025**, qui présuppose un joueur qui s'identifie déjà à ses
décisions ; la guidance d'agence précoce (Prop C, ~1 h RENDER) comble ce trou sans rompre
la DA grimdark.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 5/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *EBSCO Research Starters (VRR vs FI schedules) : https://www.ebsco.com/research-starters/psychology/schedules-reinforcement*
- *MDPI 2025 (Inherent Addiction Gacha, pity systems) : https://www.mdpi.com/2078-2489/16/10/890*
- *ScienceDirect 2025 (Monetization gacha behavioral triad) : https://www.sciencedirect.com/article/pii/S1875952125001247*
- *Möller, Kornfield, Lu 2024 (SDT digital games) : https://selfdeterminationtheory.org/wp-content/uploads/2024/06/2024_MollerKornfieldLu_CompDigitalGame.pdf*
- *LogRocket 2024 (Goal Gradient UX) : https://blog.logrocket.com/ux-design/goal-gradient-effect/*
- *Kammonen 2024 (Progression Systems in Roguelite Games) : https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf*
- *Boyle et al. 2024 (Nature Sci Rep, Wordle near-miss) : https://www.nature.com/articles/s41598-024-74450-0*
- *Kao et al. 2024 (CHI Juicy Feedback) : https://nickballou.com/publication/2024-kao-et-al-juicy/*
- *Diva-portal 2026 (Hades 2 vs TBOI) : https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf*
- *Grid Sage Games Kyzrati 2025 : https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/*
- *Nunes & Drèze 2006 (Goal Gradient Hypothesis) : https://www.researchgate.net/publication/239776073*
