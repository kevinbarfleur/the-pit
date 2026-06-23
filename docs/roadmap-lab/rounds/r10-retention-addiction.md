# Round 10 — Critique adversariale : lentille rétention-addiction (FINAL)

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Posture adversariale** : round FINAL. Les rounds 1-9 ont bâti une architecture solide ;
> ce round attaque les **hypothèses RÉSIDUELLES non challengées** et les **zones d'ombre**
> qui persistent malgré 9 itérations. Le round 9 a bien résolu les 3 failles principales
> (attribution §2.10, badge MAÎTRE, hiérarchie near-miss/identité). Ce round ne les re-démolit
> pas — il challenge ce qui n'a PAS été attaqué en 9 rounds :
> (1) La distinction **near-miss sous agence** vs near-miss pur (slot machine) — la roadmap les
>     traite comme un mécanisme unique mais ce sont deux circuits cérébraux distincts.
> (2) Le **high-roll** : la roadmap cite le concept mais n'a jamais vérifié si le moteur SIM
>     produit des moments de haute magnitude VISIBLEMENT lisibles — la « dopamine machine »
>     de Balatro est d'abord un problème de FEEDBACK SÉQUENTIEL, pas de probabilité.
> (3) La **méta-progression Grimoire** : 9 rounds ont parlé de collection et de badges, mais
>     personne n'a challengé la structure d'incomplétion (Ovsiankina) au regard de la
>     THÉORIE DE LA COLLECTION (yukaichou.com — le seuil 40-60 % est le point de bascule,
>     pas la fin). Le Grimoire tel que conçu ignore ce seuil.
> (4) Le **one-more-run via méta-progression vs one-more-run via near-miss** : la thèse de
>     Åslund 2026 (DIVA) montre que la méta-progression LOURDE (Hades) CONCEAL la maîtrise
>     — est-ce que notre Grimoire (méta-progression LÉGÈRE) évite ce piège ?
>
> **Recherche web menée ce round** :
> - Armchair Arcade — Why Balatro Is So Addictive (mai 2026) :
>   https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/
> - Blake Crosley — Balatro Juicy Feedback design analysis :
>   https://blakecrosley.com/guides/design/balatro
> - GMTK — Balatro's Cursed Design Problem (score preview) :
>   https://gmtk.substack.com/p/balatros-cursed-design-problem
> - Near-miss psychology iGaming UX (mai 2026) :
>   https://igaming.createit.com/news/the-dopamine-loop-why-the-near-miss-is-powerful-tool-in-igaming-ux/
> - Psychology of near-miss slot machines (stat.berkeley.edu) :
>   https://www.stat.berkeley.edu/~aldous/Papers/near_miss.pdf
> - Yu-Kai Chou — Collection Set Design (CD4) :
>   https://yukaichou.com/gamification-analysis/collection-set-design-cd4-engagement-guide/
> - Grid Sage Games — Designing for Mastery in Roguelikes (août 2025) :
>   https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/
> - Åslund 2026 (DIVA) — Meta-progression player experience (Hades 2 vs Binding of Isaac) :
>   https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf
> - Scientific Reports (2025) — Difficulty, learning progress, success in games :
>   https://www.nature.com/articles/s41598-025-14628-2
> - Polygon — Why losing in roguelikes feels like winning (2025) :
>   https://www.polygon.com/psychology-roguelikes-punishment-into-reward/
> - Kao 2025 (CHI) — Juicy feedback : Curiosity, Competence, Effectance :
>   https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf
>
> **Garde-fou absolu** : lecture seule du code. Écriture uniquement sous `docs/roadmap-lab/`.
> Piliers respectés : async par snapshots, sim déterministe seedée, DA grimdark, pixel art
> procédural. 32 invariants préservés.

---

## 0. Position de l'agent (round 10)

Le round 9 a tranché trois failles importantes avec une rigueur mécaniste réelle. Ce round
**valide ces tranches** et pousse trois attaques résiduelles sur des hypothèses que 9 rounds
ont acceptées sans les démontrer :

1. **La distinction near-miss sous agence** n'est pas juste un détail d'implémentation —
   c'est un MÉCANISME PSYCHOLOGIQUE DISTINCT du near-miss slot machine. La roadmap fait la
   distinction verbalement mais n'en tire pas les conséquences de design correctes.

2. **Le high-roll** est traité comme une probabilité (« VRR ») alors que le mécanisme
   Balatro prouve que c'est d'abord un problème de **SÉQUENCE D'ACTIVATION VISIBLE** —
   la magnitude perçue n'est pas une propriété de l'événement mais de son feedback.

3. **La structure d'incomplétion du Grimoire** ignore le seuil critique 40-60 % de
   completion (Yu-Kai Chou) — en dessous, la collection est « bruit de fond » sans
   engagement ; notre Grimoire à 3 chapitres peut rester sous ce seuil pendant 10+ runs.

---

## 1. ACCORDS — ce qui tient définitivement, avec pourquoi dans NOS contraintes

### 1.1 Accord fort (DÉFINITIF) : la réforme #JJ (alignement payoff↔agence) est structurellement juste

**Accord avec round-09 §1.0 et ses 4 applications.**

La preuve indépendante la plus solide vient de la recherche sur les slot machines à
compétence simulée (PMC 2025 — illusion of control study) : même quand l'outcome est
identique (même RTP), les joueurs qui perçoivent l'exercice d'une compétence réelle
s'engagent significativement plus longtemps ET évaluent l'expérience comme meilleure.
**La perception de l'agence est un modificateur de récompense, pas simplement un
préalable éthique.**

Dans NOS contraintes (sim 100 % déterministe) : le déterminisme est une CHANCE. Un jeu
déterministe peut promettre que la cause RÉELLE de l'issue est identifiable à rebours —
ce que ne peut pas faire un jeu à RNG élevé. #JJ ne cède donc rien en DA grimdark et
gagne en clarté causale. Les 4 applications (plague_communion, badge MAÎTRE, §2.10,
choc axe D) restent valides.

Sources : PMC11737417 (skill-based vs EGM) ; keithburgun.net/pick-1-of-3.

### 1.2 Accord fort (DÉFINITIF) : la hiérarchie near-miss PRIMAIRE / identité SECONDAIRE

**Accord avec round-09 §1.2 (Prop-C adoptée) et Grid Sage Games 2025.**

Confirmation indépendante : le Dr. Lichtman (Polygon 2025) formule exactement ce
mécanisme — « It's not even like 'Oh, maybe this time I'll beat the boss'. It's more
about 'How am I going to beat the boss? Does this strategy work? One more run, maybe
this other strategy will work.' [...] 'I think the appeal is that feeling of: I'm going
to understand this.' » — c'est le near-miss actionnable (l'hypothèse à tester), pas
l'identité, qui initie le restart en S1 solo.

**Dans NOS contraintes** : un jeu déterministe AMPLIFIE ce mécanisme car le restart
est un test d'hypothèse à information stable — le joueur sait que s'il reçoit le même
ghost et place différemment, le résultat SERA différent. C'est impossible dans un jeu
à RNG. Notre déterminisme est un accélérateur du near-miss actionnable.

Source : Polygon 2025 (Dr. Lichtman) ; Grid Sage Games 2025.

### 1.3 Accord fort : §2.10 reformulé vers l'agence + bloqué par CONFIG-SURVIVAL

**Accord avec round-09 §1.2 et §1.3.**

La reformulation est correcte ; la précondition CONFIG-SURVIVAL est légitime. Round 10
ajoute une nuance : Åslund 2026 (DIVA) note que dans Binding of Isaac (méta-progression
minimale, comme The Pit sur la puissance permanente), « the sense of competence [...] feels
hard-earned » justement parce que la survie n'est pas subsidée par des upgrades permanents.
Un signal §2.10 qui attribue à l'agence du joueur (et non au Puits) s'inscrit exactement
dans cette logique : « j'ai survécu PARCE QUE j'ai bien placé, pas parce que le jeu
m'a rendu plus fort. » C'est grimdark-cohérent ET psychologiquement supérieur.

Sources : Åslund 2026 (DIVA p.22) ; arXiv 2603.26677 (ordeal pleasure).

### 1.4 Accord conditionnel : le Grimoire 3 chapitres avec silhouettes Ovsiankina

**Accord PARTIEL avec ROADMAP §6.7 et round-09 §4.4.**

Les silhouettes du Chapitre III visibles au lancement (Ovsiankina) sont correctes. MAIS
(désaccord §2.3 ci-dessous) : l'architecture en chapitres crée un risque que le joueur
reste sous le seuil d'engagement 40-60 % pendant 10+ runs. L'accord porte sur le principe
des silhouettes — la critique porte sur la CADENCE d'exposition.

### 1.5 Accord fort : Peak-End Rule à double niveau (combat + run)

**Accord définitif avec la roadmap §2.4 / §6.10.**

Scientific Reports 2025 (3 jeux × 795 000 parties) confirme que le plaisir est
maximisé à difficulté intermédiaire AVEC succès — « difficulty-expectation disparity »
ET « effect of success in easy levels » influencent l'évaluation. Pour nous : un combat
gagné de justesse (near-miss) est exactement le point d'inflexion de la Peak-End Rule au
niveau combat. L'architecture roadmap (Moment du Run = pic, résultat victoire/défaite = end)
est correctement alignée avec cette recherche.

Source : Nature Scientific Reports 2025 (s41598-025-14628-2).

---

## 2. DÉSACCORDS — ce qui est faible, insuffisamment challengé, ou suppose une psychologie non vérifiée

### 2.1 DÉSACCORD FORT : le high-roll est présenté comme un problème de PROBABILITÉ (VRR) alors que c'est un problème de FEEDBACK SÉQUENTIEL VISIBLE — la différence change l'implémentation

**Ce que la roadmap suppose** : le « high-roll » (Moment du Run, VRR boutique, signal
§2.10) est une question de calibrage de FRÉQUENCE de l'événement remarquable. La roadmap
dose les VRR dans une enveloppe pondérée (round 8 §7 : 44-60 unités pondérées/run) — c'est
un raisonnement de PROBABILITÉ.

**La faille** : Balatro est la masterclass de référence et son mécanisme est DISTINCT.
Blake Crosley (design analysis, 2026) l'isole avec précision : « The most important design
innovation in Balatro is how it shows players WHY their score happened. When a hand is
played, each scoring element activates SEQUENTIALLY with visual callouts. [...] By showing
each Joker trigger individually, players learn which combinations matter. This replaces a
10-page tutorial with 300ms of sequential animation. » La magnitude perçue du high-roll
Balatro est le produit de la SÉQUENCE VISIBLE, pas de la magnitude brute.

**Preuve additionnelle (CHI 2025 — Kao, Juicy Feedback)** : étude pré-enregistrée (n=1699)
montrant que la CURIOSITÉ est le plus fort prédicteur de durée de jeu volontaire, et que
la « success dependency » (le feedback conditionné au SUCCÈS d'une action) produit curiosité +
compétence + effectance. L'étude isole : « amplifcation (volume) without success-dependency
does not produce equivalent engagement ». Autrement dit : plus de VFX sans montrer le POURQUOI
du succès = pas le même effet que voir la cascade causale.

**Ce que ça implique pour nous** : la roadmap cite Balatro comme référence (ROADMAP §0,
§2.4) mais copie son RÉSULTAT (high-roll mémorable) sans son MÉCANISME (activation
séquentielle et causalement explicite). Notre bus JSONL émet les événements avec `source`,
`cause`, `target`, `tick` — TOUTES les données sont là pour une activation séquentielle
visible. Mais la roadmap ne spécifie PAS une activation séquentielle des ticks/effets dans
`arena_draw.lua` ; elle spécifie des VFX de familles d'afflictions. C'est une distinction
non anodine : VFX simultanés sur un tick = bruit ; VFX séquentiels avec le LIEN CAUSAL
visible = apprentissage + dopamine.

**Ce n'est PAS une proposition de codage** (garde-fou : lecture seule). C'est une SPÉCIFICATION
MANQUANTE dans le brouillon : §2.4 (Moment du Run) + §2.3 (post-combat) devraient spécifier
que les événements du bus sont rendus SÉQUENTIELLEMENT avec un délai minimal (~100-200ms
entre triggers) POUR QUE LE JOUEUR VOIE LA CHAÎNE. Sans cette spec, l'implémentation par
défaut sera des VFX simultanés — le high-roll sera invisible même si les effets sont là.

**Note : ce n'est PAS la même chose que la métrique `combat_effect_legibility`** (déjà
adoptée, round-09 §3.1). Cette métrique mesure la densité d'événements. Ce désaccord porte
sur la TEMPORALITÉ DE L'AFFICHAGE — séquentiel vs simultané — indépendamment de la densité.
On peut avoir 3 événements bien sous le seuil NN/g et les afficher simultanément (invisible)
ou séquentiellement (cascade lisible). **Les deux sont préconditions complémentaires**, pas
le même critère.

Sources : blakecrosley.com/guides/design/balatro ; CHI 2025 (Kao arXiv-adjacent, n=1699) ;
armchairarcade.com/balatro-addictive (2026).

### 2.2 DÉSACCORD MODÉRÉ : la structure d'incomplétion du Grimoire ignore le seuil critique 40-60 % de YU-KAI CHOU — le Grimoire peut rester en zone « bruit de fond » pendant 10+ runs

**Ce que la roadmap suppose** : le Grimoire à 3 chapitres crée un effet Ovsiankina dès
le premier run (silhouettes visibles = tâche incomplète visible). L'architecture est
acceptée comme correcte depuis le round 8.

**La faille** : Yu-Kai Chou (2026, collection set design CD4) documente un seuil de bascule
empirique : « there's a critical point around 40-60% completion where the engagement graph
shifts dramatically. Below 40%, collections feel like background noise. You're still in the
novelty phase. You pick up pieces naturally, but there's no urgency. » En dessous de 40 %,
l'effet Ovsiankina est présent (la tâche est visible) mais l'URGENCE d'engagement est
absente.

**Calcul ancré sur NOS ressources** :
- Chapitre II (Essences des familles) : 83 unités à découvrir. À 5 unités achetées/run
  (boutique de 5), un run moyen expose ~10 unités. Atteindre 40 % = 33 unités découvertes
  ≈ 3-4 runs. Le seuil est rapide → **Chapitre II passe la bascule rapidement.**
- Chapitre I (Reliques) : 21 reliques. Un run offre 3 reliques (1-parmi-3 tous les 3
  combats, 10 combats = ~3 offres). Atteindre 40 % = 8-9 reliques ≈ 3 runs. → **Chapitre I
  aussi relativement rapide.**
- Chapitre III (Sigils) : 5 sigils. Un sigil par run au moins. 40 % = 2 sigils ≈ 2 runs.
  → **Chapitre III bascule dès le run 2.**

**Diagnostic** : le problème n'est pas d'être sous le seuil longtemps — le Chapitre II
(83 unités) est le seul à risque de RESTER sous 40 % si le joueur est mono-famille (il ne
voit que les unités du shop, ~5/run, et les unités de son archétype en priorité). Un joueur
poison peut ne voir que 15 des 83 unités sur 5 runs = 18 % → la collection reste « bruit
de fond » pendant toute la phase early. **C'est la variante la plus probable pour un joueur
engagé (il optimise son achat).**

**Conséquence** : l'effet Ovsiankina du Grimoire fonctionne pour les joueurs curieux qui
achètent large, mais PAS pour les joueurs engagés qui optimisent leur build. Or les joueurs
les plus susceptibles de churner sans retention hook sont précisément les joueurs medium-
engagés qui ont trouvé un archétype et le répètent. **Le Grimoire Chapitre II ne les accroche
pas dans la fenêtre critique (runs 2-5).**

**Proposition (§3.2 ci-dessous)** : modifier l'affichage du Chapitre II pour montrer un
SOUS-ENSEMBLE par famille (« 15 unités POISON — 4/15 découvertes ») plutôt que 83 unités
total. Chaque joueur voit une sous-collection qui passe vite au-dessus de 40 %. Coût :
0 mécanique, ~1 h RENDER.

Sources : yukaichou.com/collection-set-design-cd4 (avril 2026) ; Åslund 2026 (DIVA) ;
nos mécaniques : `00-state §2.1` (83 unités) + `§2.2` (21 reliques) + `§2.3` (5 sigils).

### 2.3 DÉSACCORD MODÉRÉ : la méta-progression « légère » du Grimoire (puissance non permanente) est décrite comme sans risque — Åslund 2026 montre que ce n'est pas automatiquement vrai

**Ce que la roadmap suppose** : notre Grimoire est méta-progression LÉGÈRE (pas de pouvoir
permanent — on apprend ce qu'on a déjà, décision §7 : reliques lisibles sans identification
obligatoire). Cette légèreté évite le piège Hades (méta-progression lourde = maîtrise
masquée par les upgrades permanents).

**La nuance (pas un désaccord fort)** : Åslund 2026 (DIVA) montre que les deux approches
ont des risques inverses. Méta-progression LOURDE (Hades 2) : « mastery is muddled » (p.22) ;
le joueur ne sait pas si c'est son skill ou ses upgrades. Méta-progression MINIMALE (Binding
of Isaac) : « requires the player to invest more time before its motivational pull becomes
clear » (résumé) — le hook est plus tardif. Notre Grimoire est minimal-à-light.

**Le vrai risque pour NOS contraintes** : avec une méta-progression légère, la motivation
initiale (runs 1-3) repose ENTIÈREMENT sur le gameplay de run — si le run 1-2 est confus
(build non lisible, exposition non visible), le Grimoire ne sauve pas le joueur. La roadmap
traite P0 (lisibilité) comme une précondition — c'est CORRECT et NÉCESSAIRE. Mais le
calendrier (`v0.9` = P0 d'abord, `v0.11` = Grimoire complet) signifie qu'en S1 bêta, les
runs 1-3 seront joués SANS le Grimoire 3-chapitres. C'est un risque de churn précoce
documenté mais acceptable SI P0 est solide. Ce round confirme que P0 EST la vraie précondition.

**Ce qui est manquant** : le Grimoire doit apparaître — même vide, avec les silhouettes
visibles — DÈS LE RUN 1. Pas en v0.11 (ranked). Une version minimale (Chapitre I uniquement :
1 relique sur 21, visible dès l'acquisition de la première relique + silhouettes des 20
autres) devrait être codée en v0.9 ou v0.9.3 en parallèle de P0. Sinon le hook meta-
progressif est absent pendant toute la fenêtre la plus critique (runs 1-5).

Sources : Åslund 2026 (DIVA) ; theseus.fi/bitstream roguelite progression thesis 2024.

### 2.4 DÉSACCORD LÉGER : le near-miss asyncrone est plus complexe à ancrer que le round 9 ne le stipule — il y a 2 sous-types avec des conséquences différentes

**Ce que le round 9 stipule** : le near-miss actionnable (§2.3, post-combat) est le driver
primaire du restart. Formulation : « si j'avais placé gravewarden en front-left, le bleed
ne l'aurait pas tué. »

**La nuance** : la recherche (near-miss psychology, stat.berkeley.edu — Kahneman & Tversky,
cité par l'article) distingue deux circuits :

1. **Near-miss sous agence rétrospective** : « J'aurais pu faire différemment » → restart
   comme hypothèse testable. FORT en déterministe, faible dans les jeux à RNG pur (le dé
   dit non même avec le même placement). C'est notre cas → **AMPLIFIÉ par le déterminisme.**

2. **Near-miss sans agence** : « J'étais si près de gagner » → affect sans direction
   d'amélioration. Classiquement associé aux slot machines → **Conduit à l'engagement
   compulsif sans progression de compétence.**

**Pour NOS combats async** : tous nos near-miss sont de type 1 (le placement était une
décision du joueur, le résultat est déterministe). MAIS — et c'est la nuance non traitée
— **le joueur ne sait pas toujours que son near-miss était sous agence**. Si l'écran
post-combat montre « BLEED A TUÉ TON CARRY » sans montrer « TA DÉCISION DE PLACEMENT
L'A EXPOSÉ », le joueur perçoit un near-miss de type 2 (chance adverse) et non de type 1
(erreur de placement). **Le round 9 a corrigé la formulation de §2.10 vers l'agence — mais
§2.3 (post-combat) nécessite la même précision de causalité.**

**Spécifiquement** : le post-combat (§2.3) montre « 1ère unité morte + cause (exposée front
/ aggro faible / pas de taunt) ». C'est du TYPE 1 valide. Mais il ne montre pas LA DÉCISION
QUI AURAIT ÉVITÉ ÇA. La description est diagnostique (« exposée front ») mais pas prescriptive
(« mettre une unité taunt en front-left t'aurait protégé »). La prescription directe risque
le paternalisme (Grid Sage 2025 : les joueurs experts rejettent les hints) ; mais sans
direction, le joueur novice (0-5 wins, churn maximal) ne reconstruit pas l'hypothèse.

**Proposition (§3.3 ci-dessous)** : ajout d'une ligne de near-miss ANCRÉ (« SI tu avais
un taunt en front... ») avec un DRAPEAU optionnel (mode grimdark = off par défaut ; activable
dans les paramètres pour les novices). Coût : ~30 min RENDER. **Ne viole aucun invariant.**

Sources : stat.berkeley.edu/~aldous/Papers/near_miss.pdf ; igaming.createit.com (2026) ;
Grid Sage Games 2025.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — SPÉCIFIER l'activation SÉQUENTIELLE des événements bus dans §2.4 et §2.3 (PRIORITÉ 1, spec uniquement — 0 code now)

**Problème identifié §2.1** : le Moment du Run est spécifié comme « lire la chaîne la plus
longue du bus » et « l'afficher en nommant l'unité source ». Mais sans préciser que l'affichage
est SÉQUENTIEL (chaque événement de la chaîne s'active avec un délai visible), l'implémentation
sera probablement un affichage simultané (blast de texte) — visible mais pas impressionnant.

**Ce** : ajouter à §2.4 (Moment du Run) et §2.3 (post-combat) la spec d'activation :

```
SPEC SÉQUENTIELLE DU MOMENT DU RUN (§2.4) :
  La chaîne d'événements est affichée événement par événement avec un délai de 80-120ms
  entre chaque noeud. Chaque noeud affiche :
    [ICONE_FAMILLE] [NOM_SOURCE] → [ACTION] → [NOM_CIBLE]
  Exemple : [FLAMME] BELLOWS_PRIEST → BRÛLURE (3 dps) → ASH_CRAWLER
             [FLAMME] ASH_CRAWLER → MORT → (on_death propage)
             [FLAMME] VOISIN_GAUCHE → CONTAMINÉ → BLEED_TICK (2 dps)
  Total : [5 morts en chaîne]
  La séquence s'accélère légèrement sur les derniers noeuds (effet d'escalade Balatro).
  RENDER ~2-3 h. Utilise le bus JSONL existant (00-state §3, bus.lua).

CONNEXION §2.3 (post-combat) :
  Si la chaîne la plus longue est >= 3 noeuds, le Moment du Run EST la synthèse post-combat
  (pas deux signaux distincts — l'un absorbe l'autre). Règle de priorité étendue :
    Moment du Run (seq. ≥3) > §2.10 (relief survie) > post-mortem diagnostic.
```

**Pourquoi cette spec répond à la faille** : en 300ms de séquence explicite, le joueur
apprend QUELLE unité a déclenché quoi et DANS QUEL ORDRE — le high-roll devient compréhensible,
pas seulement spectaculaire. C'est le mécanisme Balatro (30 ms par Joker trigger = attribution
causale par l'animation). CHI 2025 (Kao) confirme : l'apprentissage par feedback conditionné
au succès amplifie la curiosité + compétence simultanément.

**Garde-fou** : RENDER pur, lit bus JSONL, 0 SIM, 0 invariant. Zone sans test → ajouter test
que la chaîne la plus longue sur le golden est bien identifiée (golden bus JSONL lu par
`tools/eventlog.lua`, déjà câblé).

Sources : blakecrosley.com/balatro ; CHI 2025 (Kao) ; bus.lua (00-state §3).

### Proposition B — SEGMENTER le Chapitre II du Grimoire PAR FAMILLE pour passer le seuil 40 % en 2-3 runs (PRIORITÉ 2, RENDER ~1 h)

**Problème identifié §2.2** : le Chapitre II montre 83 unités totales. Un joueur mono-famille
voit ~5 unités/run → atteint 40 % (33 unités) en 6-7 runs si même famille. Trop lent pour
la fenêtre critique.

**Ce** : afficher dans le Grimoire Chapitre II un SOUS-INDEX par famille :

```
GRIMOIRE — CHAPITRE II : ESSENCES
  [SECTION BURN] — FLAMME DU PUITS — 4/13 essences (31 %)
    ████░░░░░░░░░  → silhouettes des 9 manquantes (flou + contour)
  [SECTION BLEED] — SANG DU PUITS — 7/13 essences (54 %) ← SEUIL FRANCHI
    ████████░░░░░  → plus d'urgence visible, progression nette
  [SECTION POISON] — VENIN DU PUITS — 2/15 essences (13 %)
    ██░░░░░░░░░░░  → très incomplet → effet Ovsiankina faible intentionnellement
  ...
```

Chaque famille passe le seuil 40 % en ~2-3 runs si le joueur joue cet archétype.
Le joueur mono-burn voit sa progression BURN rapidement — l'Ovsiankina est maintenant
personnalisé à l'archétype, pas à la collection totale.

**Connexion avec badge MAÎTRE (round-09 §1.4)** : « 4/13 essences » devient visible
dès le run 1. Le PRATICIEN (apex dans un run) + MAÎTRE (victoire avec apex) s'inscrivent
naturellement dans ce compte. La section Grimoire par famille remplace le risque de « bruit
de fond sous 40 % » par un signal immédiat.

**Garde-fou** : 0 mécanique, 0 invariant. Le `dot_family` des unités est posé en P0.5
(`00-state §2.1`) — ce système dépend logiquement de P0.5 (on ne segmente que si on
connaît la famille de chaque unité). **À coder EN MÊME TEMPS que P0.5**, pas en P2.

Sources : yukaichou.com/collection-set-design-cd4 ; Åslund 2026 (DIVA) ; 00-state §2.1.

### Proposition C — HINT DE NEAR-MISS ACTIONNABLE optionnel dans §2.3 (PRIORITÉ 3, RENDER ~30 min)

**Problème identifié §2.4** : le post-combat est diagnostique (« exposé front ») mais non
prescriptif (ne dit pas quelle décision alternative). Un joueur 0-5 wins peut ne pas
inférer la correction.

**Ce** : après le diagnostic standard, ajouter UNE LIGNE prescriptive optionnelle (flag
`settings.near_miss_hint`, off par défaut) :

```
Format (si activé, après diagnostic) :
  Diagnostique : "TON [NOM_UNITÉ] — EXPOSÉ EN FRONT, AGGRO FAIBLE"
  Prescriptif  : "UN TAUNT EN AVANT-GAUCHE AURAIT ABSORBÉ L'ATTAQUE INITIALE"
  Ligne atmosphérique (toujours visible) : "LE PUITS GARDE SES SECRETS — MAIS PAS TOUS"

Logique : si la 1ère unité morte est en front ET aggro < 15 ET aucun taunt dans la même
  colonne → inférer qu'un taunt aurait protégé (simple lecture de `units.lua` aggro).
  Cette logique est RENDER, lit les stats déjà calculées, 0 SIM.
```

**Pourquoi optionnel** : Grid Sage Games 2025 — les joueurs experts (mastery seekers)
rejettent les hints comme « le jeu joue à ma place ». Rendre le hint opt-in respecte
l'autonomie (SDT). Pour les débutants qui l'activent, c'est exactement le near-miss de
type 1 bien balisé qui génère le restart comme hypothèse testable.

**Seuil de déclenchement** : uniquement runs 1-3 OU après 2 défaites consécutives (loss
streak ≥ 2 déjà géré §2.3 LIEN STREAK-LOSS). Ne pas déclencher sur les runs 4+ (le
joueur a assez d'expérience pour inférer seul).

Sources : Grid Sage Games 2025 ; stat.berkeley.edu near-miss (type 1 vs type 2).

### Proposition D — AVANCER le Grimoire minimal (Chapitre I, silhouettes) à v0.9/v0.9.3 — NE PAS l'attendre en v0.11 (PRIORITÉ 1, calendrier)

**Problème identifié §2.3** : le calendrier roadmap place le Grimoire 3-chapitres en v0.11
(ranked). Pendant v0.9 et v0.9.5 (P0 et P0.5), les runs 1-5 sont joués SANS meta-progression
visible. Le risque de churn précoce est réel si P0 seul ne suffit pas.

**Ce** : spécifier dans le calendrier §9 que le **Grimoire minimal** (Chapitre I uniquement,
UI simplifiée) est codé EN PARALLÈLE de P0.5 (v0.9.3-v0.9.5) :

```
GRIMOIRE MINIMAL (v0.9.3, // P0.5) :
  Chapitre I SEUL : reliques découvertes (ACQUISES dans un run ou vues en boutique)
  Affichage : [NOM_RELIQUE] • [EFFET COURT] • [FLAVOR]
  Silhouettes des reliques non découvertes (21 total, contour seul)
  AUCUNE mécanique : lecture de grimoire.lua (déjà câblé, 00-state §5)
  ~2 h RENDER. 0 invariant. 0 SIM.

GRIMOIRE COMPLET (v0.11, ranked) :
  Chapitre II (segmenté par famille, Prop-B) + Chapitre III (sigils) + badges MAÎTRE/PRATICIEN
  Dépend de P0.5 (dot_family) + ranked (histoire de run)
```

**Pourquoi urgent** : Åslund 2026 montre que la méta-progression légère requiert plus de
temps pour « devenir claire ». Avancer le Grimoire minimal donne ce hook dès v0.9.3 sans
attendre v0.11 — le joueur qui finit son 1er run et voit « 3/21 reliques du Puits » a
un ancre méta-progressif immédiat même si le Grimoire n'est pas complet.

Sources : Åslund 2026 (DIVA) ; calendrier roadmap §9 (00-state §7).

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R10_1 — Cadence d'animation de la chaîne séquentielle : quel délai entre noeuds ?**
80ms ? 120ms ? Balatro utilise ~30ms par Joker (5 Jokers = 150ms environ). Nos chaînes
peuvent avoir 3-12 noeuds. À 100ms/noeud : 300ms (3 noeuds) à 1200ms (12 noeuds). La
1200ms est trop longue (perd l'effet de cascade). Recommandation : délai décroissant
(100ms → 60ms → 40ms sur les 5+ derniers noeuds, accélération Balatro). À valider en
playtest — pas en sim.

**Q_R10_2 — Le Grimoire minimal à v0.9.3 doit-il montrer les reliques VUES EN BOUTIQUE
(pas seulement acquises) ?** Avantage : la découverte est plus rapide (3 offres/run = 1
relique acquise + 2 vues). Inconvénient : le joueur peut voir une relique excellente en
boutique sans pouvoir l'acheter → frustration avant maîtrise. Le modèle StS (découverte
= lore visible, acquis = effet complet) est le bon référentiel. Recommandation : relique
VUE = silhouette + nom, ACQUISE = silhouette + nom + effet. Les leurres retirés (décision
§7) simplifient ce modèle : tout ce qui est vu EST lisible.

**Q_R10_3 — Le Grimoire segmenté par famille (Prop-B) crée-t-il une FOMO de famille ?**
Un joueur BURN qui voit « VENIN DU PUITS — 2/15 » pourrait vouloir explorer le poison
juste pour compléter la section — ce qui dilue son build de run. Est-ce un phénomène
bénin (exploration encouragée) ou nocif (distraction du build) ? La réponse dépend de si
les sections « autres familles » sont présentées de manière ATTRACTIVE (invitante à
l'exploration) ou NEUTRE (juste un compte). Recommandation : sections familles non
jouées = taille réduite, pas de silhouettes visibles (pas de FOMO — juste un compteur
discret). L'Ovsiankina se déclenche sur la section ACTIVE de la famille du build du run.

**Q_R10_4 (litige ouvert persistant) — Q_R9_2 non résolue : §2.10 doit-il être gaté sur
`ghost_is_human == true` ?** En phase bêta S1, pool faible, majorité des combats = IA.
La survie limite contre une IA froide n'est pas un ordeal (l'IA n'est pas optimale). Le
signal §2.10 contre l'IA dilue la rareté VRR. Ce round soutient que le gate est
RECOMMANDÉ pour §2.10 (le signal relief est uniquement pertinent contre un ghost humain ou
une IA montée en rang 5+). **Q_R9_2 reste ouverte, ce round la re-qualifie comme
BLOQUANTE pour le code §2.10** (pas juste une nuance — si la majorité des runs sont
contre l'IA en bêta, un signal §2.10 non-gaté sera banal dès le round 1).

---

## 5. VALIDATIONS SOURCÉES — propositions non challengées des rounds précédents qui tiennent

### 5.1 VRR boutique (§2.9 enveloppe pondérée hédonique) — VALIDÉ sans challenger

La pondération hédonique est correcte dans son principe. Ce round n'a pas trouvé de
preuve contraire. Seule nuance : le SCORING SÉQUENTIEL (Prop-A) change le poids hédonique
PERÇU d'un événement sans changer sa fréquence — un même événement mal affiché pèse moins
hédoniquement. L'enveloppe pondérée doit donc ASSUMER que l'affichage séquentiel est en
place (sinon les poids sont surestimés).

### 5.2 Mode statistique du Nom de Build (`≥3 runs`) — VALIDÉ

La condition `≥3 runs avant d'afficher le mode` (round-09 §5.2) est correcte. Le round 10
ajoute que si le Grimoire minimal (Prop-D) est avancé à v0.9.3, le Nom de Build peut être
affiché DANS le Grimoire comme « Ta signature du Puits : [mode statistique] » — ce qui
ancre l'identité à la méta-progression plutôt qu'à l'écran post-combat seul. Les deux sont
complémentaires. 0 coût additionnel.

### 5.3 Hiérarchie one-more-run S1 (near-miss PRIMAIRE, identité SECONDAIRE) — CONFIRMÉ

Polygon 2025 (Dr. Lichtman) et Polygon 2025 (Dr. Sood) confirment indépendamment : « It's
more about 'How am I going to beat the boss? Does this strategy work?' » (near-miss
actionnable = hypothèse testable) — pas l'identité. **Ce round apporte la confirmation
médicale-psychiatrique indépendante**, pas seulement Game Design. Adopté définitivement.

### 5.4 L'absence de monétisation compulsive comme renforcement de la rétention — VALIDÉ (angle non sourcé avant ce round)

Armchair Arcade 2026 + Coruzant 2025 sur Balatro : « The absence of monetization removes
a source of resentment that typically builds in games designed around retention. Players
return to Balatro because the mechanics reward them, not because a pop-up notification
reminded them to. » The Pit est F2P async avec un modèle inconnu — mais TOUTES les sources
de rétention intrinsèque documentées (near-miss actionnable, SDT compétence, Grimoire
Ovsiankina) fonctionnent mieux sans monétisation compulsive. Si la monétisation du Pit est
envisagée, ce cadre positionne FERMEMENT contre les dark patterns de VRR (loot boxes,
timers) et POUR la vente unique ou le cosmétique narratif grimdark. Ce n'est pas une
proposition de design — c'est un garde-fou éthique et de rétention sourcé.

Sources : armchairarcade.com/balatro-addictive ; coruzant.com/balatro-gacha-print-money.

---

## 6. REJETS — propositions qui auraient pu être soulevées mais sont contreproductives

### 6.1 REJETÉ — Score preview type « estimé » avant le combat (analogue au score preview Balatro)

GMTK 2024 (Balatro's Cursed Design Problem) documente que LocalThunk a DÉLIBÉRÉMENT refusé
le score preview pour préserver « suspense et drama ». Notre contexte est différent (autobattler
async, pas de poker) mais la logique tient : si le joueur peut estimer l'outcome avant le
combat, le combat devient une confirmation plutôt qu'une révélation. **La tension et la découverte
sont le mécanisme de rétention intra-combat, pas le calcul ex-ante.** REJETÉ. Déjà dans §0
(« Ce qui NE doit PAS entrer »).

### 6.2 REJETÉ — Limiter le Grimoire aux archétypes DÉJÀ JOUÉS (Grimoire adaptatif)

Tentant : ne montrer que les unités des familles jouées dans les 3 derniers runs.
Avantage : passe le seuil 40 % immédiatement pour n'importe quel joueur.
Problème : détruit l'effet d'invitation à l'exploration (l'utilisateur ne sait pas ce qu'il
ne voit pas). Yu-Kai Chou : « Mystery filtering works too. Don't reveal what pieces exist
until users encounter them. This maintains the novelty phase longer. » Le Grimoire adaptatif
RÉDUIT le mystère en cachant ce que le joueur pourrait vouloir découvrir. Prop-B (segmenté
par famille mais toutes familles visibles) est supérieur.

### 6.3 REJETÉ — Grimoire live avec stats de win-rate « en direct » (round-09 §6.3 confirmé)

Déjà rejeté au round 9 (< 20 runs = bruit). Ce round confirme : Scientific Reports 2025
(3 jeux, data naturelle) rappelle que les statistiques de performance nécessitent N suffisant
pour être informatives. Avant 30 runs, les win-rates par famille ont des intervalles de
confiance trop larges pour être actionnables. **Maintenu rejeté.**

---

## 7. CHALLENGE CLÉ — résumé pour le synthétiseur (round 10 FINAL)

**Le round 10 apporte 3 corrections à la roadmap existante et 1 correction de calendrier :**

1. **Le high-roll est un problème de FEEDBACK SÉQUENTIEL, pas de probabilité.** La
   roadmap dose les VRR en fréquence (enveloppe pondérée hédonique) sans spécifier que
   les événements du bus sont rendus SÉQUENTIELLEMENT dans l'animation. Cette spec manquante
   dans §2.4 est la faille d'implémentation la plus probable — sans elle, le Moment du Run
   sera un affichage simultané (bruit), pas une cascade lisible (apprentissage + dopamine
   Balatro). **Prop-A : spec séquentielle à ajouter dans §2.4 et §2.3. 0 code maintenant,
   ~2-3 h RENDER en implémentation.**

2. **Le Grimoire en 83 unités totales reste sous le seuil d'engagement 40-60 % pour les
   joueurs mono-famille pendant 5-7 runs.** La segmentation par famille (Prop-B) passe le
   seuil en 2-3 runs pour CHAQUE archétype. C'est la correction qui transforme le Grimoire
   d'un registre passif en moteur de rétention actif pour les joueurs engagés. **~1 h
   RENDER, dépend de P0.5 (dot_family).**

3. **Le near-miss async est de TYPE 1 (sous agence) — mais le joueur ne le perçoit comme
   tel que si le post-combat montre la CAUSALITÉ, pas seulement le diagnostic.** Le hint
   optionnel de Prop-C complète §2.3 pour les runs 1-3, sans imposer le paternalisme aux
   joueurs experts.

4. **Le Grimoire minimal doit être avancé à v0.9.3** (Prop-D, // P0.5). Attendre v0.11
   laisse les runs 1-10 sans anchor méta-progressif dans la version la plus critique pour
   la rétention initiale.

**Ces 4 corrections ne démolissent pas l'architecture de rétention construite en 9 rounds —
elles l'affinent sur les mécanismes psychologiques qui étaient sous-spécifiés. Les 9 rounds
ont posé les bons concepts ; ce round spécifie les 2-3 détails d'implémentation qui font la
différence entre un effet hédonique faible et un effet fort.**

---

## 8. LITIGES DU ROUND 10

| # | Litige | Statut R10 |
|---|--------|------------|
| **Q_R10_4 / Q_R9_2** | Gate §2.10 sur `ghost_is_human == true` | **RE-QUALIFIÉ BLOQUANT** pour le code §2.10 en bêta (majorité IA). Décision éditoriale utilisateur requise avant implémentation. |
| **Q_R10_1** | Cadence d'animation séquentielle (délai par noeud) | Ouvert — à valider en playtest, non sim. Recommandation : décroissant 100→40ms. |
| **Q_R10_3** | FOMO famille dans le Grimoire segmenté | Ouvert — résolu par taille réduite des sections familles non actives (recommandation doc). |
| **#HH, #II, #GG, #U** | Litiges inter-lentilles ouverts depuis R09 | **Non challengés depuis leur lentille de rétention** — les laisser à leurs lentilles respectives pour arbitrage final round-10 (synergies/ranked). |

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (round 10/10, FINAL). Lecture seule
du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers async/déterministe/grimdark/
procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *Armchair Arcade — Balatro addictive (mai 2026) : https://armchairarcade.com/perspectives/2026/05/20/balatro-game-review-why-is-it-so-addictive/*
- *Blake Crosley — Balatro feedback design : https://blakecrosley.com/guides/design/balatro*
- *GMTK — Balatro's Cursed Design Problem : https://gmtk.substack.com/p/balatros-cursed-design-problem*
- *Near-miss psychology iGaming UX (2026) : https://igaming.createit.com/news/the-dopamine-loop-why-the-near-miss-is-powerful-tool-in-igaming-ux/*
- *Near-miss psychology (stat.berkeley.edu) : https://www.stat.berkeley.edu/~aldous/Papers/near_miss.pdf*
- *Yu-Kai Chou — Collection Set Design CD4 (2026) : https://yukaichou.com/gamification-analysis/collection-set-design-cd4-engagement-guide/*
- *Grid Sage Games — Designing for Mastery in Roguelikes (2025) : https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/*
- *Åslund 2026 (DIVA) — Meta-progression comparative (Hades 2 vs Binding of Isaac) : https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf*
- *Scientific Reports (2025) — Difficulty + learning progress + success : https://www.nature.com/articles/s41598-025-14628-2*
- *Polygon (2025) — Why losing in roguelikes feels like winning : https://www.polygon.com/psychology-roguelikes-punishment-into-reward/*
- *CHI 2025 (Kao) — Juicy feedback : Curiosity, Competence, Effectance : https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf*
- *PMC11737417 — Illusions of control : skill-based vs EGM : https://pmc.ncbi.nlm.nih.gov/articles/PMC11737417/*
- *Coruzant (2025) — Balatro vs Gacha : https://coruzant.com/esports/how-balatros-success-proved-you-dont-need-gacha-to-print-money/*
