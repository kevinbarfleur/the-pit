# Round 03 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v3, intégré round 2),
> `round-02.md` (synthèse), `rounds/r01-retention-addiction.md`,
> `rounds/r02-retention-addiction.md`, `competitive/balatro.md`,
> `competitive/super-auto-pets.md`, `competitive/slay-the-spire.md`,
> `competitive/the-bazaar.md`, `competitive/postmortems.md`.
>
> **Recherche web menée ce round** : variable ratio reinforcement (TandfonLine 2023,
> explorepsychology.com), pity systems (ScienceDirect 2025, MDPI 2025), knowledge
> vs power progression (ResetEra, LevelUpTalk), The Bazaar async review
> (mobalytics.gg 2025, bazaar-builds.net), mastery roguelikes (gridsagegames.com 2025),
> endowed progress effect (psychologyofgames.com, gamedeveloper.com), TFT meta
> stagnation (zleague.gg 2024).
>
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.
>
> **Posture adversariale** : les rounds 1 et 2 ont bien établi la couche de base
> (Grimoire de connaissance, high-roll nommé, Codex bootstrappé). Ce round cherche
> les **zones molles que les deux premiers ont laissées passer**, les analogies encore
> trop paresseuses, et les hypothèses de rétention qui ne tiennent pas une fois qu'on
> fait les maths.

---

## 0. Position de l'agent

Les rounds 1 et 2 ont livré deux vrais gains sur la rétention : (1) le **« Moment
du Run »** (high-roll nommé, lu du bus, adopté en P0) et (2) le **Codex bootstrappé**
(silhouettes + flash d'accroche, adopté en P2). Ces deux mécanismes sont bien sourcés
et bien calibrés pour nos contraintes. **Je les confirme.**

Mais trois zones restent non résolues ou mal calibrées, que les deux rounds précédents
ont effleurées sans les trancher :

1. **Le plafond du Codex de connaissance** : identifié comme risque (r02 §1.1,
   r02 §Q2), mais la question « qu'est-ce qui retient *après* les 30 interactions
   connues ? » n'a pas de réponse chiffrée dans la roadmap. La réponse « reliques G +
   saisons » est nommée mais pas modélisée.
2. **Le pity-tracker sous-spécifié** : adopté en P3 (r01 Prop-A, r02 §1.3), mais le
   **seuil de déclenchement** reste un placeholder pur. Ce round vérifie la
   psychologie exacte du mécanisme — un pity trop généreux détruit la tension ;
   trop serré, il ne signal rien.
3. **Le « Moment du Run » est une récompense PASSIVE** — le joueur a regardé le combat
   se dérouler. La chaîne qu'on lui montre s'est produite *sans lui*. Le round 2 présume
   que le mémorable se transfère depuis la résolution de combat vers la session suivante.
   Ce transfert n'est pas automatique dans les autobattlers full-spectateur.

Un quatrième point est entièrement neuf : **le risque de la grille ranked sur
l'agence perçue**. La grille `+4/+2/+1/0` est sans pénalité — c'est bon. Mais elle
n'est **jamais** remise en cause depuis l'angle de la *perceived randomness* : un
joueur qui perdra systématiquement au round 7 à cause d'une mauvaise seed de
relique aura 0 point et attribuera sa stagnation au hasard, pas à sa compétence.
Le ranked sans pénalité ne règle pas le problème de l'attributabilité du résultat
— il l'atténue juste.

---

## 1. ACCORDS — ce qui tient, et pourquoi avec précision

### 1.1 Accord fort : Moment du Run adopté en P0 — le mécanisme psychologique TIENT

**Accord avec ROADMAP-draft v3 §2.6 ; r02-retention §2.1 ; synthèse round 2 §1.11.**

Le « Moment du Run » repose sur un mécanisme de rétention documenté :
le **variable ratio reinforcement** (VRR), documenté en Skinner 1938 et appliqué
au jeu depuis les travaux de Hopson (2001, Gamasutra). Le VRR produit la
résistance à l'extinction la plus élevée de tous les régimes de renforcement —
c'est pourquoi les slot machines y ont recours. Dans un jeu de compétence, le même
mécanisme devient sain : la chaîne imprévue de combos (burn → mort → propagation →
poison → chaîne) est un renforcement variable *sous agence* (le joueur a choisi le
build). La distinction « agence + VRR = sain » vs « pas d'agence + VRR = addictif
pathologique » est documentée dans TandFonLine 2023 et ScienceDirect 2023 (Engineered
Highs) :

> « Variable ratio schedules produce the highest rate of responses and the greatest
> resistance to extinction. » — explorepsychology.com (synthèse de la littérature Skinner).

Pour The Pit : les cascades DoT + propagation-à-la-mort sont **exactement** un VRR
sous agence. Le « Moment du Run » nommé est la *photo* de ce renforcement variable.
**Ce mécanisme est solide pour nos contraintes déterministes** : le bus JSONL encode
la cascade, la chaîne max est extractible, le signal n'est jamais fabriqué.

**Nuance importante non résolue (voir §2.1)** : le VRR fonctionne quand le joueur
*subit* le bruit aléatoire. Ici, le combat est spectateur — il y a une couche
d'indirection. Le signal « Moment du Run » doit contrebalancer cette indirection.

### 1.2 Accord fort : Grimoire = connaissance, pas puissance — la distinction TIENT

**Accord avec ROADMAP-draft v3 §6.7 ; r01 §1.3 ; r02 §1.1.**

La distinction connaissance / puissance est confirmée par la littérature récente :
- LevelUpTalk (2025) : « Progression should enhance skill rather than compensate for
  a lack of it. » La progression de puissance pure (stats cross-run) déplace la
  satisfaction hors du run courant.
- ResetEra (thread « Do you like meta progression in your roguelikes/roguelites? ») :
  consensus documenté — les unlocks de contenu créent du FOMO, pas de l'engagement
  sain.
- Kammonen 2023 (theseus.fi) : la progression de connaissance *interne au run* (je
  reconnais cette synergies) préserve l'arc run-complet sans diluer le skill gap.

**Ce qui tient pour nos contraintes** : le Grimoire des 12 synergies (puis ~30 avec
les types P1) + les reliques identifiées cross-run est du bon côté de cette ligne.
Il n'ajoute aucune puissance, il rend le joueur plus *lisible à lui-même*.

**NUANCE avec désaccord potentiel** : Kammonen 2023 note aussi que TBOI (The Binding
of Isaac) a besoin d'une communauté wiki externe pour scaffolder la découverte —
précisément parce que la connaissance pure ne suffit pas à retenir *sans signal*.
Le Codex bootstrappé (r02) répond à ça. **Mais le plafond de la progression de
connaissance est réel** — voir §2.2.

### 1.3 Accord fort : run court = arc complet = one-more-run facile

**Accord avec ROADMAP-draft v3 §6.1 ; r01 §1.4 ; r02 §1.2.**

La littérature sur la durée des runs confirme que la clarté de fin est le principal
moteur du « juste encore un » :
- Grid Sage Games (Kyzrati, 2025) sur Cogmind : « Replayability is agency that
  survives repetition. » La condition nécessaire est que chaque run soit un arc
  complet.
- La Bazaar Review (mobalytics.gg 2025) : « you can go AFK whenever you'd like, and
  return to your run while still having a PvP experience. » — ce que The Pit fait
  aussi, mais sans la pression de shop-timer.

10 victoires ou 5 défaites = format optimal pour notre DA. **Accord total.** Le
rejet du mode Endless est une bonne décision pour les mêmes raisons.

### 1.4 Accord conditionnel : grille ranked sans pénalité — le PRINCIPE est bon, la CALIBRATION reste ouverte

**Accord avec ROADMAP-draft v3 §6.2 (principe, pas les chiffres [PH]).**

La grille `+4/+2/+1/0` sans pénalité est confirmée par l'état de l'art :
- Bazaar S2 (bazaar-builds.net, Reynad interview dec 2024) : le jeu async le plus
  comparable est passé en mai 2025 à un scoring par wins de run, sans pénalité. Notre
  direction est juste.
- SAP : pas de ranked dans les 2 premières années — mais a tenu grâce à son Weekly
  Pack (rotation lundi). La grille sans pénalité n'est pas la *cause* de la rétention ;
  c'est une *condition permissive*.

**MAIS** : voir §2.3 sur l'attributabilité perçue. La grille est bonne, elle est
insuffisante seule.

### 1.5 Accord : Codex bootstrappé (silhouettes + flash) — mécanisme psychologique validé

**Accord avec ROADMAP-draft v3 §6.7 ; r02 §1.12 ; r02-retention §2.3.**

Le bootstrap par silhouettes repose sur un principe de design cognitif bien établi :
l'**horizon d'exploration visible** (Zeigarnik effect : les tâches incomplètes
restent en mémoire de travail plus longtemps que les complètes). Montrer « ???
— Saignement × Pourriture » déclenche ce mécanisme. La référence Balatro (Joker
unknown) l'exploite explicitement.

**Ce qui tient pour nos contraintes** : RENDER uniquement, 0 SIM, s'intègre au
Grimoire 2-onglets déjà prévu. Coût faible, mécanisme solide.

---

## 2. DÉSACCORDS — ce qui est faible, mal calibré ou non étayé

### 2.1 DÉSACCORD FORT : le « Moment du Run » est une récompense PASSIVE dans un spectacle auto — l'attribution causale n'est pas garantie

**Ce que le brouillon v3 dit** (§2.6) : lire la chaîne d'événements la plus longue
depuis le bus JSONL et afficher « MOMENT DU RUN — CORRUPTION EN CHAÎNE (5 unités) »
au post-combat.

**Le problème fondamental** : dans un autobattler full-spectateur, le joueur regarde
le combat mais **n'agit pas pendant la résolution**. La chaîne DoT s'est produite *à
cause de son build*, mais il n'a pas appuyé sur un bouton au moment de l'explosion.
La psychologie du VRR (§1.1) repose sur le couplage *action → récompense variable*.
Ici, le découplage temporel (build construit 30 secondes avant la résolution, chaîne
observée passivement) affaiblit l'attribution causale.

**Preuve par comparaison** : dans Balatro, le « Moment » (Joker × Joker × Boss) se
produit *pendant que le joueur joue sa main*. Il y a une action motrice au moment
de la récompense. Dans The Pit, la chaîne se produit sans input. C'est pour cette
raison que des jeux comme Into the Breach ont choisi un modèle *prédictor* (le joueur
voit les conséquences AVANT l'action) — pour maintenir l'attribution causale dans un
système sans combat en temps réel.

**Ce n'est pas une raison de retirer le Moment du Run** — il reste valide. Mais
le mécanisme psychologique sous-jacent est **différent du VRR standard** : c'est
plutôt un mécanisme de **post-hoc attribution** (l'intelligibilité rétroactive du
combo renforce la *fierté de construction*, pas la *récompense d'action*). Ce
mécanisme est moins fort mais réel — Kammonen 2023 le note dans le contexte des jeux
de stratégie asynchrones.

**Implications concrètes** :

1. Le signal doit être **attribué au build, pas au hasard**. « CORRUPTION EN CHAÎNE
   (5 unités) » est insuffisant — il faut nommer *quelle décision de build* a causé
   ça : « MOMENT DU RUN — TA LIGNÉE DE POISON A CONSUMÉ 5 ENNEMIS » (en référence
   à la position que le joueur a choisie). Ce lien explicite build → résultat
   **renforce l'attribution causale post-hoc**.
2. Le seuil « chaîne ≤2 = pas de moment » (brouillon v3 §2.6) est correct pour
   éviter l'inflation. Mais **le seuil de 2** est arbitraire — il devrait être
   **≥ la médiane des cascades sur N combats sim** (pour que « Moment du Run » ne
   se déclenche que pour les cascades au-dessus de la médiane, pas les 50 % les
   plus courants). Si la médiane est 3 liens, le seuil devrait être 4.

**Source** :
- Grid Sage Games (Kyzrati, 2025) : « Emergent systems let players uncover mastery
  organically, through experimentation and failure. » L'**expérimentation** est la clé
  — le joueur doit ressentir que *sa décision* a produit le résultat.
  https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/
- Wayline.io (2025) : « What happens on that stage should still feel like it belongs to
  the player's choices and skill. » En autobattler full-spectateur, cela exige un lien
  explicite *build → résultat* dans le signal.
  https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency

### 2.2 DÉSACCORD MODÉRÉ : le plafond de la progression de connaissance est réel mais NON MODÉLISÉ — la roadmap le reporte sans le chiffrer

**Ce que le brouillon v3 dit** (§6.7 nuance round 2) : « la progression de connaissance
a un plafond d'engagement (12, puis ~30 interactions connues → le Codex ne retient plus)
que la progression de puissance n'a pas. Les reliques G (P4) + saisons sont le vrai
relais — à quelle cadence ? À modéliser avant P4. »

**Le problème** : cette nuance est correcte *et est reportée sans critère chiffré*. Le
brouillon nomme le plafond mais ne dit pas **quand il arrive** (en termes de sessions,
pas de jours) ni **quel signal déclenche l'alarme**.

**Calcul approximatif** : 30 interactions à découvrir (12 synergies actuelles + ~18
de type en P1). Un joueur actif fait 2 runs/session. Une interaction se produit si le
build contient les deux familles concernées — probabilité brute dépend de la densité
de build, disons 25 % par run pour une interaction donnée. Médiane de découverte d'une
interaction : `ln(0.5)/ln(0.75) ≈ 2.4 runs`. 30 interactions × 2.4 runs = **~72 runs
pour tout connaître**. À 2 runs/session : **~36 sessions**. À 3 sessions/semaine :
**~12 semaines** — c'est la durée d'une saison (6-8 sem. donne 2 saisons).

**Conclusion non triviale** : le plafond de connaissance arrive *pendant la saison 1*
pour un joueur actif. **Les reliques G (P4) et la deuxième saison ne relaient pas
in-time** si P4 est séquencé après v0.12 (équilibrage auto). Le brouillon séquence P4
en dernier, mais les joueurs actifs atteignent le plafond de connaissance AVANT P4.

**Ce que la roadmap devrait contenir** : un **critère d'alarme explicite** du plafond,
pas juste un label « à modéliser ». Proposition : si `season_wins/joueur_actif > 50`
(~25 runs) ET `Grimoire.synergies_discovered ≥ 25/30 interactions`, alors le relais
P4 est urgent — lancer le prototype d'une relique G dès v0.12.

**Source** :
- Kammonen 2023 (theseus.fi, pp. 28-32) : « Knowledge-based progression reaches a
  ceiling when all system states are understood. After that point, only new content or
  new systems can re-engage the player. »
  https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
- ResetEra (« Do you like meta progression? ») : le consensus — les joueurs reviennent
  pour le contenu nouveau, pas pour re-découvrir ce qu'ils savent déjà.
  https://www.resetera.com/threads/do-you-like-meta-progression-in-your-roguelikes-roguelites.1341955/

### 2.3 DÉSACCORD MODÉRÉ : le pity-tracker a une double contrainte psychologique non adressée — trop fort OU trop faible le tuent chacun à leur façon

**Ce que les rounds précédents ont dit** : r01-retention §3 (Prop-A) : pity soft à
partir du 8e reroll, +5 %/reroll, cappé ×2. r02-retention §1.3 : accord conditionnel,
seuil « 8 rerolls » reste arbitraire.

**Ce que le brouillon v3 dit** (§7.3) : pity-tracker visible, seuil à valider par
sim (hunt médian > 5 rounds = trop dilué). Le seuil de 8 rerolls du round 1 n'a pas
été rebasé.

**Le problème : double contrainte** que les deux rounds n'ont pas articulée ensemble :

**(A) Pity trop généreux → supprime la tension du near-miss**. La recherche ScienceDirect
2025 sur les gacha (Harbin Institute of Technology, « Monetization mechanisms in gacha
games : pity systems and belief of luck ») montre que le pity *explicitement visible*
réduit le *perceived risk* — ce qui est utile pour la monétisation (réduit l'anxiété
de dépense) mais réduit aussi la *valeur émotionnelle de la récompense quand elle arrive*.
Si le joueur sait qu'il AURA l'unité dans 4 rerolls de toute façon, la joie de la voir
apparaître plus tôt est diminuée. Ce n'est pas le même mécanisme que le near-miss
constructif (anticipation → récompense imprévue).

**(B) Pity trop tardif → frustration précoce**. Hunt médian de 12 rerolls (calculé r01
§2.1 pour rang-3 en T3) = 12 gold sur un budget de 10/round = **impossible à sustainer
en 1 round** → le pity arrive après 1.2 rounds de chasse déjà frustrants. À ce stade,
le near-miss était déjà devenu de la frustration plate, pas de l'anticipation.

**La zone utile** est entre ces deux extrêmes. La psychologie du near-miss sous agence
(Frontiers in Psychiatry 2024 ; Springer 2020) montre que le signal optimal est :
- Déclenché **après** ~50-60 % du hunt médian attendu (assez pour que la tension soit
  établie, pas avant).
- Visible mais **non-garantie explicite** — « chance croissante » est plus efficace que
  « garanti dans N rerolls » (le premier maintient l'espoir variable, le second neutralise
  le VRR).

**Calcul pour The Pit** : hunt médian rang-3 en T3 ≈ 12 rerolls (r01 §2.1). Zone
utile = déclencher à ~6-7 rerolls (50-60 %). Formulation UI : « [icône sang] Ta proie
sent ta présence » (flavor grimdark) + indication de cote légèrement augmentée —
**sans indiquer de garantie**. Cappé à ×1.5 la cote de base (pas ×2 du round 1 — trop
généreux).

**Proposition de sim** : mesurer deux populations dans `tools/sim.lua` :
- **Pop A** : pity visible avec garantie explicite (« +5 % × rerolls, cappé ×2 »)
- **Pop B** : pity visible sans garantie (cote légèrement augmentée, sans chiffre exact)
- **Métrique** : `session_length_post_acquisition` (le joueur joue-t-il plus après avoir
  trouvé l'unité dans le régime B vs A ?). Si B > A, le VRR est mieux préservé.

**Source** :
- ScienceDirect 2025, Harbin Institute : « Pity systems lower perceived risk and boost
  payment intention, but can also encourage irrational consumption » — la réduction du
  *perceived risk* a des effets ambigus sur l'engagement.
  https://www.sciencedirect.com/science/article/abs/pii/S1875952125001247
- MDPI 2025 (Information journal) : « Inherent Addiction Mechanisms in Video Games'
  Gacha » — les pity trop généreux réduisent l'engagement répété.
  https://www.mdpi.com/2078-2498/16/10/890
- Frontiers in Psychiatry 2024 (VR near-miss) : signal visible = anticipation construc-
  tive ; guarantee = désactivation du VRR.
  https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2024.1322631/full

### 2.4 DÉSACCORD LÉGER MAIS STRUCTUREL : la grille ranked `+4/+2/+1/0` présuppose que la variance de run est *perçue comme agentielle* — elle ne l'est pas toujours

**Ce que le brouillon v3 dit** (§6.2) : grille sans pénalité, pas de floors, écrémage
explicite en haut.

**Ce qui manque** : la grille ne règle pas le problème de l'**attribution du résultat
dans la zone 0-5 victoires**. Un joueur qui termine régulièrement à 4-5 victoires
(toujours 0 point) peut attribuer son stagnation à deux causes très différentes :
- (A) « Mon build était mauvais » → attributabilité agentielle → il revient.
- (B) « La seed de boutique ne m'a pas donné les bonnes unités » → attribution au
  hasard → il churne.

La grille `+4/+2/+1/0` **ne discrimine pas** entre ces deux perceptions. Le `season_wins`
(r02 §1.13) comble le vide de progression visible — c'est bien. Mais il ne résout pas
l'attribution causale pour la zone 0-5 victoires.

**Pourquoi c'est un problème structurel** : le déterminisme de The Pit (invariant #1-5)
rend *techniquement* tout résultat attribuable. Mais la perception du joueur ne suit
pas les maths. La recherche de Jesper Juul (« Fear of Failing ? ») indique que
l'attributabilité perçue exige une **lisibilité causale directe** du type « j'aurais
pu faire X différemment ». Le post-combat « pourquoi » (P0 §2.4) y répond — mais il
est classé après la carte de risque et le Moment du Run dans les priorités, alors qu'il
est le **remède premier** de l'attributabilité pour la zone 0-5 victoires.

**Proposition** : le **post-combat « pourquoi » (§2.4)** devrait être **co-priorité 1
avec la carte de risque** en P0, pas Priorité 2. Pour les joueurs 0-5 victoires, la
lisibilité de l'échec est plus urgente que le Moment du Run (qui concerne les combats
où on *gagne*). La répartition dans le brouillon v3 donne les étoiles au succès (Moment
du Run) et relègue en deuxième le feedback sur l'échec — or pour la rétention des
joueurs intermédiaires, c'est l'inverse qui compte.

**Source** :
- Jesper Juul (« Fear of Failing ? », jesperjuul.net) : « Players prefer to attribute
  failure to their own error over randomness. Causal attribution = retention. »
  https://jesperjuul.net/text/fearoffailing/
- Entalto Studios (2025) : « If systems are unclear, failure feels arbitrary. When
  players lose a run, they should immediately recognize why. »
  https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/
- Grid Sage Games (Kyzrati, 2025) : « Arbitrary failure kills retention. »
  https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — Ancrer le « Moment du Run » à la DÉCISION DE BUILD, pas seulement à la chaîne (P0, RENDER, coût nul)

**Ce** : modifier le signal (brouillon v3 §2.6) pour nommer **quelle unité du build du
joueur** a déclenché la chaîne. Plutôt que « CORRUPTION EN CHAÎNE (5 unités) »,
afficher : « TON [NOM_UNITÉ] A PROPAGÉ SON AFFLICTION À TRAVERS 5 ENNEMIS » — en lisant
depuis le bus JSONL le `source` du premier événement de la chaîne max (le bus encode
déjà `{source, cause, target, tick}`). Coût : 1 ligne de lecture supplémentaire du log.

**Seuil à calibrer** : remplacer « chaîne ≤2 = pas de moment » par « chaîne < médiane
des cascades sur les N derniers combats stockés » (ou une valeur fixe issue de la sim
headless sur le golden). **Proposer de lancer `tools/sim.lua` pour mesurer la
distribution des longueurs de chaîne avant de figer le seuil.**

**Pourquoi** : renforce l'attribution causale post-hoc (§2.1). Ce n'est plus « le jeu
m'a donné un moment fort » mais « *mon unité* a fait quelque chose d'extraordinaire ».
La distinction est psychologiquement significative pour les autobattlers spectateurs
(Grid Sage Games 2025 ; Wayline 2025 — « should still feel like it belongs to the
player's choices »).

**Garde-fou** : RENDER + lecture du bus, 0 SIM. L'invariant de déterminisme (#1-#5)
garantit que le source est exact.

### Proposition B — Modéliser explicitement le plafond de connaissance et déclencher un prototype relique G AVANT la fin de P3 (nouveau critère P3→P4)

**Ce** : ajouter dans `tools/sim.lua` un mode `--knowledge-ceiling` qui :
1. Pour N runs simulés, compte les interactions déclenchées parmi les 30 prévues (12
   synergies + ~18 de type).
2. Mesure à quel N un joueur actif-moyen (2 runs/session, 3 sessions/semaine) a
   couvert ≥ 80 % des interactions.
3. Si ce N < 25 runs (~12-13 semaines) → alerter que le plafond de connaissance
   arrive AVANT la fin de P3 → urgentiser un prototype de relique G à prototyper
   pendant P3 (pas après).

**Critère d'alarme en production** : `season_wins ≥ 50 ET Grimoire.synergies ≥ 25`
pour une cohorte de joueurs → déclencher le prototype relique G (changement de
topologie, même minimal — 1 forme seule).

**Pourquoi** : le calcul approximatif (§2.2) montre que le plafond arrive en ~72 runs
pour un joueur actif. La saison 1 dure ~8 semaines à 2 runs/semaine = 16 runs. La
saison 2 ajoute 16 runs = 32 au total — encore loin du plafond. MAIS un joueur très
actif (5 runs/semaine) atteint 40 runs en 8 semaines = plafond dans la saison 1. Sans
contenu de relique G, ces joueurs churneront *pendant la saison 1*. Le lab doit
anticiper ce cas limite, pas juste le « modéliser avant P4 ».

**Garde-fou** : 0 modification du code de jeu dans ce round. C'est une proposition de
CRITÈRE pour le sequencement, pas de code.

### Proposition C — Affiner le pity-tracker : « présence invisible » (flavor grimdark), sans chiffre de garantie, déclenché à 50-60 % du hunt médian (P3, avant tuning des cotes)

**Ce** : au lieu de « +5 % par reroll, cappé ×2 » (trop explicite → neutralise le VRR),
proposer un **signal de présence sans quantification explicite** : à partir du 6e reroll
sans voir l'unité cherchée (si on peut la traquer), afficher dans le tooltip de la
boutique une icône de « trace » + flavor grimdark (ex. : « [icône empreinte] L'ombre de
cette créature est proche »). La cote augmente en interne (+5 %/reroll), mais **le
joueur ne voit pas le chiffre exact** — il voit un signal de « presque ».

**Calibrage** : seuil = 6-7 rerolls (≈ 50-60 % du hunt médian rang-3 en T3 = ~12
rerolls). Plafond interne ×1.5 (pas ×2 — assez pour que l'espoir soit maintenu sans
garantie de livraison).

**Pourquoi sans garantie explicite** : le pity visible avec chiffre (*garantie*) réduit
le *perceived risk* et l'affect positif à la découverte (ScienceDirect 2025, Harbin
Institute). Le pity visible *sans chiffre* (signal de présence) maintient l'espoir
variable tout en atténuant la frustration plate. C'est la forme la plus compatible
avec notre DA grimdark (« l'ombre est proche ») et avec le déterminisme (seedé, pas
accumulé en session).

**Garde-fou** : la cote interne doit être **dérivée du seed de run**, pas du compteur
de rerolls de session (invariant #2 : même seed de run → même distribution de boutique).
Architecturalement : le seed de run détermine une probabilité de « pity déclenché » par
position de boutique (bitmask ou paramètre injecté), pas un état mutable de session.

### Proposition D — Reclasser le post-combat « pourquoi » en CO-PRIORITÉ 1 avec la carte de risque en P0 (réorganisation, 0 code nouveau)

**Ce** : dans le brouillon v3, le résumé post-combat (§2.4) est Priorité 2 derrière
le surlignage d'adjacence (§2.1) et la carte de risque (§2.2). **Passer §2.4 en
co-priorité 1 avec §2.2** (ils sont de coût comparable — RENDER + lecture bus).

**Pourquoi** : la carte de risque agit sur les *combats futurs* (feedback prospectif).
Le résumé post-combat agit sur les *combats perdus* (feedback rétrospectif). Pour la
rétention des joueurs dans la zone 0-5 victoires (les plus à risque de churner), le
feedback rétrospectif est **plus urgent** : c'est lui qui convertit la frustration de
la défaite en compréhension actionnable. La priorité 2 retarde ce feedback d'une
itération — ce qui peut être une itération de trop pour les joueurs qui abandonnent
après 3 défaites consécutives.

**Ce que la priorisation n'affecte pas** : l'implémentation reste RENDER + lecture du
bus déterministe. Les invariants #1-#5 garantissent l'exactitude. 0 code SIM.

---

## 4. QUESTIONS OUVERTES non résolues par ce round

**Q1 — Critère de seuil de chaîne max pour le « Moment du Run »** : quelle est la
médiane des cascades sur les 250 combats du fuzz ? Si elle est de 3 liens, le seuil
à 2 déclenche le signal pour ~50 % des combats → inflation. À mesurer avant v0.9
(`tools/sim.lua --chain-distribution`). Non tranché ce round.

**Q2 — Cadence exacte avant le plafond de connaissance** : le calcul de §2.2 est une
approximation (probabilité d'interaction = 25 % par run). La vraie probabilité dépend
de la densité de build (combien d'unités de famille A ET B dans un plateau à 3-9 slots)
= sim headless nécessaire. Non tranché ce round.

**Q3 — Le pity seedé vs pity accumulé** : le brouillon v3 (§7.3) dit que le pity doit
dériver du seed pour le déterminisme — mais le pity par seed de RUN implique que la
même run voit toujours l'unité au même reroll, ce qui n'est plus du near-miss variable
mais du near-miss déterministe. Est-ce que le VRR tient dans un système entièrement
déterministe ? La contrainte async (invariant #2) exige le déterminisme ; le near-miss
psychologique exige de la variance. Ce conflit n'a pas de solution propre dans le
brouillon. Un compromis : le seuil de pity est seedé (position dans la run), mais la
rencontre exacte de l'unité cherchée reste variable dans la distribution seedée. À
spécifier avant P3.

**Q4 — « Moment du Run » dans un combat perdu** : si la chaîne max se produit côté
ennemi (l'adversaire a propagé 5 afflictions sur notre équipe), doit-on afficher un
Moment du Run pour l'ennemi ? C'est une chaîne mémorable aussi — mais elle a causé
notre défaite. Le signal génère-t-il alors de la frustration ou de la compréhension ?
Non spécifié dans le brouillon. Suggestion grimdark : le nommer différemment (« LE
PUITS VOUS A CONSUMÉ — 5 DE VOS UNITÉS TOMBÉES EN CASCADE ») — même mécanique, tonalité
inversée.

**Q5 — `season_wins` comme remède unique vs Codex** : le brouillon v3 (§6.8) adopte
le `season_wins` comme remède principal du vide intermédiaire et relègue
`COMPLETION_BONUS` à « optionnel ». Ce choix est défendable — mais `season_wins` est
un compteur brut qui monte toujours, ce qui finit par perdre sa signification. Un
compteur qui monte toujours n'est pas une **progression** — c'est une accumulation.
À quel point le `season_wins` reste-t-il motivant quand on dépasse 200 victoires dans
la saison 3 ? Pas adressé.

---

## 5. CHALLENGE CLÉ (résumé)

Le brouillon v3 a posé les bons fondements de rétention (Moment du Run, Codex
bootstrappé, grille ranked sans pénalité) mais laisse trois failles non colmatées :
**le signal du Moment du Run attribue la cascade au jeu plutôt qu'au build du joueur**,
ce qui l'affaiblit dans le contexte spectateur d'un autobattler — un ajout de 1 ligne
(nommer l'unité source) le renforce sans coût. **Le plafond de la progression de
connaissance arrive avant la fin de P3 pour les joueurs actifs** et aucun critère
d'alarme ni raccourci vers P4 n'est défini — or The Bazaar (patché mensuellement avec
de nouveaux items dès le lancement) montre que les joueurs async churneront sans contenu
nouveau dans les 10-12 semaines. **Le pity-tracker sous sa forme actuelle (+5 %/reroll,
cappé ×2, visible) risque de neutraliser le VRR qu'il est censé accompagner** — la
recherche 2025 sur les gacha distingue clairement pity-garantie (neutralise le
near-miss) de pity-signal (maintient l'anticipation) ; la formulation grimdark sans
chiffre exact est la forme correcte.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Lecture seule du repo.
N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers async/déterministe/grimdark/
procédural préservés, 32 invariants non touchés.*

*Sources web consultées ce round* :
- explorepsychology.com (Variable Ratio Schedule, synthèse Skinner) :
  https://www.explorepsychology.com/variable-ratio-schedule/
- TandFonLine 2023 (Media Psychology, renforcement variable et jeux) :
  https://www.tandfonline.com/doi/pdf/10.1080/15213269.2023.2242260
- ScienceDirect 2025 (Harbin Institute, pity systems gacha) :
  https://www.sciencedirect.com/science/article/abs/pii/S1875952125001247
- MDPI 2025 (Inherent Addiction Mechanisms, gacha) :
  https://www.mdpi.com/2078-2498/16/10/890
- Frontiers in Psychiatry 2024 (VR near-miss) :
  https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2024.1322631/full
- Kammonen 2023 (Progression Systems in Roguelites, theseus.fi) :
  https://www.theseus.fi/bitstream/handle/10024/881994/Kammonen_Eino.pdf
- ResetEra (meta-progression discussion) :
  https://www.resetera.com/threads/do-you-like-meta-progression-in-your-roguelikes-roguelites.1341955/
- Grid Sage Games, Kyzrati 2025 (Designing for Mastery in Roguelikes) :
  https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/
- Wayline.io 2025 (Balancing Randomness and Player Agency) :
  https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency
- Jesper Juul (Fear of Failing, attributabilité) :
  https://jesperjuul.net/text/fearoffailing/
- Entalto Studios 2025 (Tips to Make Your Roguelite Work) :
  https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/
- Mobalytics (The Bazaar Review, async PvP design) :
  https://mobalytics.gg/news/guides/the-bazaar-review
- Bazaar-builds.net (Reynad Interview dec 2024) :
  https://bazaar-builds.net/reynad-interview-insights-on-the-future-of-the-game/
- Psychologyofgames.com (Endowed Progress Effect) :
  https://www.psychologyofgames.com/2010/11/endowed-progress-effect-and-game-quests/
- LevelUpTalk (Progression system roguelite) :
  https://leveluptalk.com/news/game-progression-system-roguelike-or-roguelite/
