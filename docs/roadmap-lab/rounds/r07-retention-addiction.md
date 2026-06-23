# Round 07 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v7, intégré round 6),
> `round-06.md` (synthèse), `rounds/r0{1,2,3,4,5,6}-retention-addiction.md`,
> `competitive/balatro.md`, `competitive/super-auto-pets.md`, `competitive/slay-the-spire.md`,
> `competitive/the-bazaar.md`, `competitive/postmortems.md`, `competitive/tft.md`.
>
> **Recherche web menée ce round** :
> - Boyle et al. 2024 (Nature Sci Rep, Wordle, goal gradient & near-miss) :
>   https://www.nature.com/articles/s41598-024-74450-0
> - Kao et al. 2024 (CHI, Juicy Feedback, agency, amplification paradox) :
>   https://nickballou.com/publication/2024-kao-et-al-juicy/
> - Nature H&SS 2025 (meta-analyse Zeigarnik & Ovsiankina) :
>   https://www.nature.com/articles/s41599-025-05000-w
> - Yu-kai Chou 2026 (Behavioral designer's guide, Zeigarnik vs Ovsiankina) :
>   https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/
> - PSU.com 2025 (Variable Ratio Reinforcement, slot machine psyche) :
>   https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/
> - MDPI 2025 (Inherent Addiction Mechanisms in Gacha, pity, threshold N≈55) :
>   https://www.mdpi.com/2078-2489/16/10/890
> - Kammonen 2024 (Progression Systems in Roguelite Games) :
>   https://www.theseus.fi/bitstream/10024/881994/2/Kammonen_Eino.pdf
> - Diva-portal 2026 (Hades 2 vs TBOI meta-progression comparative) :
>   https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf
> - Nature Sci Rep 2025 (Learning progress, difficulty, fun in video games) :
>   https://www.nature.com/articles/s41598-025-14628-2
> - DEV Community 2026 (Build naming — post-run identity mirror) :
>   https://dev.to/yurukusa/50-lines-of-code-15-build-names-one-accidental-challenge-mode-1be1
> - Countly 2026 (Push notifications, lapsed player re-engagement) :
>   https://countly.com/blog/how-to-use-push-notifications-to-bring-lapsed-players-back-to-your-game
> - AMCIS 2025 (Progress bar design principles, motivation) :
>   https://aisel.aisnet.org/amcis2025/sig_game/sig_game/5/
>
> **Posture adversariale** : les rounds 1-6 ont construit une architecture de rétention
> compétente sur ses fondements théoriques (les 3 ré-ancrages du round 6 ont fermé les
> litiges SDT et Zeigarnik). Ce round 7 ne revient pas sur ces corrections. Il attaque
> QUATRE HYPOTHÈSES DE MÉCANISME qui n'ont pas encore été challengées avec rigueur :
> (A) Le VRR de boutique est-il réellement une source de **one-more-run** ou risque-t-il
> de devenir du bruit au-delà de la session initiale ? (B) Le Moment du Run (attribution
> post-hoc) suppose une identité de build nommée — qui n'existe pas encore dans The Pit.
> (C) L'Ovsiankina dans le Grimoire est-il suffisant seul, ou la spec de silhouette
> « déjà commencée » sous-exploite-t-elle le near-miss sous agence propre au plateau-graphe ?
> (D) La roadmap a trois signaux VRR indépendants — mais aucune mesure du **taux de
> saturation** sur un run court (10 victoires max) ni du risque de leur obsolescence asymptotique.
>
> **Garde-fou absolu** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> Piliers respectés : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.

---

## 0. Position de l'agent

Les rounds 1-6 ont produit une couche de rétention sérieuse. Les ré-ancrages théoriques
du round 6 (SDT → trace d'impact ; Zeigarnik → Ovsiankina + Goal Gradient) étaient
**nécessaires et corrects** — ce round les confirme. Mais six rounds de débat ont
progressivement ajouté des signaux, des préconditions et des specs sans jamais se poser
la question inverse : **est-ce que l'ensemble tient dans un run court de 1-2 h pour un
joueur solo sans communauté visible ?**

Ce round attaque la **robustesse systémique** de la couche VRR dans nos contraintes
spécifiques (run 10 victoires, solo, DA grimdark cryptique, async sans live), et
identifie **un trou mécaniste majeur** que tous les rounds ont manqué : le Moment du
Run nomme l'unité mais **jamais le BUILD**. C'est la différence entre « ta torche a brûlé
5 ennemis » et « TU ÉTAIS UN BRÛLEUR DE PUITS — 5 ennemis consumés ». La seconde
formulation crée une identité persistante ; la première crée un fait.

---

## 1. ACCORDS — ce qui tient, avec le POURQUOI précis dans NOS contraintes

### 1.1 Accord fort : le VRR de boutique (§2.9) est la bonne réponse au bon problème

**Accord avec round 06 §1.4 / ROADMAP-draft v7 §2.9.**

Le diagnostic du round 6 est exact et sourcé : le Moment du Run est de la narration
rétrospective, pas du VRR sous agence. Dans une boucle build-spectateur, le déclencheur
de relance est l'**anticipation de la prochaine boutique**, pas du prochain combat.

**Confirmation indépendante (Mobile Game Report 2026, mobilegamereport.com/articles/
super-auto-pets-depth-vs-casual-2026)** : « Super Auto Pets' depth comes from two sources:
composition synergies and **shop sequencing**. [...]  The specific challenge SAP poses —
build decisions with cascading consequences inside a roguelite loop. » Le mot « shop
sequencing » est précis : ce n'est pas « la boutique offre de bonnes choses », c'est
« la séquence des décisions boutique sur toute la durée du run génère la profondeur ».
Notre VRR boutique cible exactement cet axe.

**Dans NOS contraintes async** : le signal est RENDER pur, 0 SIM, 0 invariant. Il opère
sur `shopTier` + `dot_family` des offres, deux données disponibles sans serveur. Coût ~2 h.
L'accord est fort et sans réserve sur le PRINCIPE. La réserve porte sur le CALIBRAGE
(voir §2.1 ci-dessous).

### 1.2 Accord fort : l'Ovsiankina + Goal Gradient pour le Grimoire (§6.7)

**Accord avec round 06 §1.6 / ROADMAP-draft v7 §6.7.**

La méta-analyse Nature H&SS 2025 (doi:10.1057/s41599-025-05000-w, relu ce round) confirme :
taux de reprise Ovsiankina = **67 % dans toutes les conditions** (N=21 publications,
`weighted resumption rate = 67.00 %`). C'est une tendance robuste. **Yu-kai Chou 2026**
(yukaichou.com, relu) synthétise élégamment : « The resumption effect has held up far better
in replication than the recall effect. If you want to bet on one, bet on the pull to resume,
not on enhanced memory. »

La spec du Chapitre III en silhouette « déjà commencée » (ex. `[SIGIL ANNEAU] × [POISON]
→ ???`) est correcte : elle doit paraître **interrompue**, pas juste verrouillée. Ce round
confirme la spec sans la modifier.

**Dans NOS contraintes** : la simulation déterministe rend la méta-progression de
connaissance (Grimoire) particulièrement puissante — les builds sont reproductibles, la
connaissance accumulée a une valeur réelle. Ovsiankina + goal-gradient tiennent bien.

### 1.3 Accord fort : le cap dur à ~10 sessions pour la Surprise de Placement

**Accord avec round 06 §1.7 / ROADMAP-draft v7 §2.7.**

Le critère de désactivation par déplacement intentionnel (`grimoire:hasMovedForAdjacency()`,
≥3 drags intentionnels ayant activé une arête nouvelle) est plus robuste que la quantité
pure. **Le cap dur à 10 sessions** est essentiel : sans lui, le profil passif (qui ne
déplace jamais) voit la Surprise devenir du bruit après 20 runs sans jamais déclencher le
critère. C'est la seule garantie d'extinction contrôlée. Accord maintenu.

### 1.4 Accord conditionnel : la trace d'impact async (§2.8) comme levier de session initiation

**Accord avec round 06 §1.5, MAINTENU sous conditions.**

Le mécanisme — amorce comportementale par trace d'impact persistante (Fogg BM + Countly
2026) — est correct et mieux ancré que la SDT-relatedness. La formulation grimdark
(« LE PUITS GARDE MÉMOIRE DE TON BUILD ») est cohérente avec la DA.

**Condition de validité non vérifiée (NOUVEAU ce round)** : le signal suppose que
`snapstore.lua` enregistre les combats **contre le ghost LOCAL du joueur** depuis sa
dernière session (`battles_since_last_session`). Ce compteur n'existe pas encore dans le
code (00-state §5 : « effets aura/relique non capturés dans le snapshot (v1 = effets de
base) »). Le bug potentiel : en **cold-start** ou en **version 1 locale** avec FIFO de
pool à 200 snapshots, combien de fois le ghost du joueur courant est-il réellement servi ?
Si la probabilité est faible (`1/200 × combats_round_joué`), le compteur est souvent 0 et
le signal ne se déclenche jamais → la promesse de session initiation est **illusoire en
v1 locale**. **Litige #Z non tranché** (00-state §7 : ouvert, à décider avant le code).
L'accord porte sur la valeur du mécanisme, sous réserve que le compteur soit
empiriquement non-nul en v1.

---

## 2. DÉSACCORDS — ce qui est faible, mal calibré, ou structurellement incomplet

### 2.1 DÉSACCORD MODÉRÉ : le VRR de boutique a un risque d'extinction rapide si le signal est trop prévisible — la roadmap ne le modélise pas

**Position §2.9 de la roadmap** : le signal se déclenche sur ~30 % des rerolls (Hopson
2001 : 20-30 %) ; formulé comme une résistance/menace ; jamais actif sur le 1er shop du
round.

**La faille** : Hopson 2001 est cité comme justification du seuil 20-30 %, mais cette
source concerne le **VRR opérant pur** (renforcement variable aléatoire sans règle visible).
Notre signal VRR boutique, tel que spécifié (rang ≥ `shopTier` OU ≥ 60 % `dot_family`),
est **un signal semi-prévisible basé sur une RÈGLE** — pas un VRR pur. Un joueur qui
comprend la règle (et les joueurs compétitifs la découvrent vite) peut **anticiper le
signal** au lieu d'être surpris par lui. Ce changement de régime psychologique est décisif.

**La littérature est claire là-dessus (PSU.com 2025, psu.com/news/the-slot-machine-psyche)** :
« In a fixed system, you get a prize every 10th time. Once you hit the 9th, you know the
next is guaranteed. The excitement drops. But in a variable ratio system, your engagement
stays constant because you're continuously driven by the hope that *this attempt will pay
off*. » Un signal semi-prévisible (règle transparente) **dégénère en fixe partiel** pour
les joueurs qui l'ont compris. La surprise disparaît.

**Ce que la roadmap ne modélise pas** : la demi-vie psychologique du signal. Un joueur
qui a vu le signal 20 fois l'a modélisé. Après ce seuil, le signal ne surprend plus —
il **informe** (ce qui est utile, mais différent du VRR). La roadmap traite le signal
comme s'il était invariant dans le temps, alors que son effet décroît avec la connaissance
de la règle.

**Risque spécifique à NOS contraintes (run court)** : dans un run de 10 victoires (12-15
rounds estimés), si le joueur fait ~3 rerolls/round en moyenne, il voit le signal ~12 à
18 fois par run sur 4-5 runs. L'apprentissage de la règle = ~3-5 runs = demi-vie très
courte. Après ça, le signal est de l'**UI utile, pas du VRR**.

**Ce n'est pas un argument pour retirer le signal** — c'est un argument pour :
1. **Calibrer la condition sur une règle plus complexe que le joueur ne peut pas
   facilement modéliser** (ex. combinaison de 3 facteurs : rang + dot_family + distance
   à la 3e copie d'une unité) ; ou
2. **Accepter explicitement que le signal a deux phases** : surprise (5-10 premiers runs)
   puis information utile — et calibrer la formulation en conséquence (la phase 2 peut
   devenir plus subtile). Source : PSU.com 2025 (on ne peut pas maintenir un VRR pur
   avec une règle visible à long terme).

**Seuil [PH] #AA (litige ouvert)** : la roadmap reconnaît que le seuil 60 % est un
placeholder à calibrer. **Ce round ajoute une précision** : calibrer non seulement le
TAUX de déclenchement (~30 %) mais la **PRÉVISIBILITÉ** de la règle pour un joueur
expérimenté (~10 runs). Si la règle est devinée après 10 runs → repenser la condition.

### 2.2 DÉSACCORD FORT : le Moment du Run nomme une UNITÉ mais pas un BUILD — la fierté de construction est incomplète sans identité nommée du run

**Position §2.4 de la roadmap** : le Moment du Run identifie l'unité-source de la chaîne
(+ enrichissement placement si voisine d'une autre unité du build) — «  TA [NOM_UNITÉ]
A CONSUMÉ 5 ENNEMIS EN CHAÎNE ».

**La faille** : le mécanisme de fierté de construction (Déclos 2025, British J. Aesthetics,
cité en rounds 4-5) suppose que le joueur **s'identifie à ses décisions de build**. Mais
s'identifier à une décision isolée (« j'ai bien placé Ash_Moth ») est différent de
s'identifier à **UN BUILD** (« j'étais un Brûleur du Puits »). La première est de
l'attribution d'événement ; la seconde est de l'identité de run.

**Preuve par analogie sourcée** (DEV Community 2026, dev.to/yurukusa, exemple d'implémentation
concrète dans un roguelite) : « Stats are data. Names are identity. You need both, but
the name is what makes the data meaningful. [...] When the result screen shows
"[Phantom Executioner]", there's a beat. A recognition moment. *That's what I built.*
That's what this run was. [...] Players now have something to SAY. "I got to Endless as
a Chain Annihilator" is shareable. "I had chain + fork supports" is not. The name converts
a technical state into a social object. »

**Ce qui manque dans la roadmap** : un **NOM DE BUILD post-combat** dérivé de la composition
du plateau. Dans The Pit, c'est trivial à générer depuis `dot_family` (P0.5) + sigil +
présence d'unités spéciales :
- 4+ poison → « DISTILLATEUR DU PUITS »
- 4+ burn → « BRÛLEUR DU PUITS »
- 4+ bleed → « SANG-FROID DU PUITS »
- Build mixte 2+2 → « ALCHIMISTE DU PUITS »
- Sigil anneau + aura → « CERCLE MAUDIT »
- Sigil croix + tank taunt → « CROISÉ MAUDIT »

Ces noms sont **data-driven** (lus de `dot_family` + `shape` + `units` après combat),
**RENDER pur**, ~1 h, et servent deux fonctions :
1. **Enrichissent le Moment du Run** : «  MOMENT DU RUN — LE [BRÛLEUR DU PUITS] A CONSUMÉ 5
   ENNEMIS EN CHAÎNE VIA [NOM_UNITÉ] » → l'unité s'ancre dans l'identité du run, pas en
   dehors.
2. **Rendent le Grimoire II identifiable** : le bestiaire (Chapitre II) peut regrouper les
   découvertes par BUILD ARCHÉTYPE, pas seulement par famille. « 11/15 unités du BRÛLEUR
   découvertes » → goal-gradient direct sur une identité nommée.

**Dans NOS contraintes grimdark** : les noms sont du Puits, pas de héros. Un nom de build
grimdark = un titre sombre et court, jamais une félicitation. « DISTILLATEUR DU PUITS »
est oppressif et cryptique ; « GREAT POISON BUILD » ne l'est pas. RENDER seul.

**Pourquoi le round 6 ne l'a pas proposé** : les rounds précédents ont cherché à enrichir
le SIGNAL du Moment du Run (placement, source, chaîne, P75) mais n'ont pas questionné
l'absence d'**identité nommée du run entier**. C'est un trou orthogonal aux enrichissements.

**Zone sans test → ajouter un test** que le nom de build est correctement dérivé du golden
(composition connue → nom attendu).

### 2.3 DÉSACCORD MODÉRÉ : la roadmap n'a pas de mesure de SATURATION du VRR sur un RUN COMPLET (10 victoires)

**Position de la roadmap** : précondition de mesure du chevauchement des signaux VRR
(boutique × placement × cascade par round, §2.4). Cette précondition est bonne mais
**insuffisante** : elle mesure le CHEVAUCHEMENT au niveau du COMBAT, pas la SATURATION
au niveau du RUN ENTIER.

**La faille** : en 10-15 rounds (run complet), on cumule :
- ~3-5 offres de reliques (1-parmi-3 tous les 3 combats) → VRR low-frequency, high-stakes.
- ~30-50 rerolls totaux → VRR boutique à ~30 % de déclenchement → **9-15 signaux boutique
  par run**.
- ~3-5 déclenchements Moment du Run (P75 = ~25 % des combats, 12-15 rounds) → **3-4 signaux
  cascade par run**.
- ~2-4 signaux « surprise de placement » (post-défaite early) → capped à ~4.
- 1 signal de trace d'impact (au lancement, 1 fois).

**Total sur un run de 10 victoires** : ~17-28 signaux VRR au sens large. Est-ce trop ?
Pas de mesure dans la roadmap.

**Kao et al. 2024 (CHI, nickballou.com/publication/2024-kao-et-al-juicy, relu)** est cité
pour l'anti-cannibalisation au niveau du combat. Mais le même papier documente un effet
plus large : « amplification unexpectedly reduced [all motives], possibly because the tested
condition unintentionally impeded players' sense of agency ». L'amplification EXCESSIVE
réduit l'agence. La roadmap a une règle de priorité Moment > Surprise par combat — mais
pas de règle de cap global sur un run entier.

**Proposition minimale (doc, 0 code)** : définir une **enveloppe de fréquence globale**
pour les signaux VRR sur un run complet. Hypothèse de travail (à valider en playtest) :
≤20 signaux VRR au total sur un run de 10 victoires (toutes sources confondues). Si
les calculs dépassent — couper soit la fréquence boutique, soit élargir le seuil P75.
Ce n'est pas un chiffre gravé : c'est une **intention documentée** à vérifier.

**Source** : Kao et al. 2024 CHI (amplification excessive réduit l'agence) + PSU.com 2025
(VRR fonctionne par rareté relative, pas par fréquence absolue).

### 2.4 DÉSACCORD LÉGER : le Grimoire II (bestiaire, 83 unités) est segmenté par famille mais pas par ARCHÉTYPE DE BUILD — les deux niveaux ne sont pas équivalents

**Position §6.7 de la roadmap** : le Chapitre II est segmenté par famille (« 11/15 unités
poison découvertes » au lieu de 83 unités en bloc). Accord adopté round 6 sur le principe.

**La limite** : la segmentation par famille (15 unités poison) et la segmentation par
**archétype de build** (12 unités du « DISTILLATEUR ») ne correspondent pas. Un archétype
de build mélange souvent 2 familles (poison-4 + choc-2, ou burn-2 + rot-2) et inclut des
unités de soutien (tanks, auras). La progression « 11/15 unités poison » ne reflète pas
la progression réelle du joueur qui joue un build poison + choc.

**Ce qui tient** : la segmentation par famille (15 vs 83) est un progrès nécessaire pour
le goal-gradient (LogRocket 2024 : l'effet s'efface au-delà de ~7 étapes). La limite
est que le **bon niveau de granularité** pour le goal-gradient est l'ARCHÉTYPE DE BUILD
que le joueur joue, pas seulement la famille des unités.

**Proposition (1 heure de spec, 0 code)** : ajouter au Chapitre II une vue secondaire
optionnelle par ARCHÉTYPE (les 6-8 archetypes principaux du jeu, dérivés des build-names
proposés §2.2) — « DÉCOUVERTES DU BRÛLEUR : 7/11 ». Cette vue est secondaire (par défaut
la vue famille) et ne nécessite pas de code moteur (data-only, lus de `dot_family` + les
noms de build §2.2). **Dépend de la Proposition §2.2 ci-dessus** (les archetypes existent
via les noms de build) → à intégrer si §2.2 est adopté.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — NOM DE BUILD post-combat : identité nommée du run (PRIORITÉ 1, RENDER, ~1 h)

**Ce** : dans `arena_draw.lua` ou `scenes/combat.lua` (RENDER, post-combat), après résolution,
lire `shape` + les `dot_family` des unités du build (comptage par famille, P0.5 dépendance)
+ présence d'unités à rôle spécial (`aggro ≥ 40` pour tank, `trigger="combat_start"` pour
aura) pour générer un **nom de build grimdark** affiché sur l'écran post-combat, AVANT le
Moment du Run :

```
Nom de build (règle simple, extensible) :
- ≥4 units dot_family=="burn"  →  "BRÛLEUR DU PUITS"
- ≥4 units dot_family=="poison" → "DISTILLATEUR DU PUITS"
- ≥4 units dot_family=="bleed" →  "SANG-FROID DU PUITS"
- ≥4 units dot_family=="rot"   →  "NÉCROLOGUE DU PUITS"
- ≥4 units dot_family=="choc"  →  "CONDENSATEUR DU PUITS"
- ≥2 + ≥2 (deux familles)      →  "ALCHIMISTE DU PUITS"
- sigil=="croix" + tank taunt  →  "CROISÉ MAUDIT" (override)
- sigil=="anneau" + aura unit  →  "CERCLE MAUDIT" (override)
- sinon                        →  "ARPENTEUR DU PUITS" (fallback)
```

Le nom précède le Moment du Run : « **[BRÛLEUR DU PUITS]** — TA [ASH_MOTH] A CONSUMÉ 5
ENNEMIS EN CHAÎNE ». L'unité-source s'ancre dans l'identité du run.

**Persistance** : stocker le nom dans `grimoire.lua` (déjà prévu pour la méta cross-run,
00-state §2.2) → le Grimoire peut afficher « tes 5 derniers runs : [BRÛLEUR], [ALCHIMISTE],
[DISTILLATEUR]... » = arc de progression d'identité visible.

**Précondition** : `dot_family` doit être posé (P0.5 §3.3). Peut être implémenté dès
que P0.5 est livré, en //. RENDER + IO Grimoire, 0 SIM, 0 invariant de combat.

**Zone sans test → ajouter** : test que la règle de dérivation du nom est correcte sur
le golden (composition connue → nom attendu).

**Chiffre** : environ 8-10 noms de build (5 familles + 2 sigil-spéciaux + 1 fallback
+ possibles combos futurs). Extensible data-only.

**Source** : DEV Community 2026 (build naming = identité, pas data) ; Déclos 2025
(fierté de construction exige que la décision soit perçue comme sienne — le nom la nomme) ;
ROADMAP-draft §2.4 (Moment du Run, déjà adopté) + §6.7 (Grimoire II).

### Proposition B — ENVELOPPE VRR : définir une intention de fréquence globale sur un run (PRIORITÉ 2, doc, ~1 h de spec)

**Ce** : dans la spec P0 (§2.4 + §2.7 + §2.9), ajouter un **tableau d'intention de
fréquence VRR** sur un run de 10 victoires, comme précondition de validation des seuils :

| Source VRR | Fréquence estimée | Fenêtre temporelle |
|---|---|---|
| Boutique (reroll) | ~30 % des rerolls, ~3 rerolls/round → ~9-14 signaux/run | BUILD (continu) |
| Moment du Run | P75 des combats → ~3-4 signaux/run | post-COMBAT |
| Surprise de Placement | post-défaite early → ~2-3 signaux (capped 10 sessions) | post-COMBAT défaite |
| Relique 1-parmi-3 | tous les 3 combats → ~4-5 offres/run | post-COMBAT |

**Intention : total ≤ 20 signaux VRR par run** (hypothèse de travail, à valider). Si les
sims montrent que les seuils actuels dépassent → prioriser boutique (circuit agence directe)
sur les autres en cas de budget saturé.

**Pourquoi une intention** : la simulation mesure les TAUX, pas les ENVELOPPES. Sans
intention documentée, on ne sait pas si « 22 signaux/run » est voulu ou accidentel.
Aligné avec la précondition « tableau d'intention éco » (§7.0 de la roadmap, adopté round
6 pour l'éco) — même logique appliquée aux signaux VRR.

**Source** : Kao et al. 2024 CHI (amplification excessive réduit l'agence — il faut un
plafond, même implicite) ; PSU.com 2025 (VRR fonctionne par rareté relative) ;
ROADMAP-draft §2.4 (précondition de mesure chevauchement déjà adoptée — ce tableau l'étend
au run entier).

### Proposition C — ÉVOLUTION DE LA CONDITION VRR BOUTIQUE : rendre la règle moins prévisible à long terme (PRIORITÉ 2, spec, 0 code avant P0)

**Ce** : avant de coder §2.9, documenter deux PHASES du signal VRR boutique :

**Phase 1 (runs 1-10 environ)** : règle actuelle (rang ≥ `shopTier` OU ≥ 60 % `dot_family`).
Simple, détectable, mais surprenante pour un joueur nouveau. **Acceptable**.

**Phase 2 (runs 10+)** : la roadmap n'en parle pas. Proposition : ajouter un 3e facteur
à la condition — **distance à la 3e copie d'une unité du build** (≥ 60 % d'une famille
ET dans `shopTier` OU à 1 copie d'un triple) → la combinaison est plus difficile à modéliser
pour le joueur. Le signal est rare et contextuellement très fort. `SHOP_SIZE=5` + pool
LOCAL → calculer la distance à la 3e copie est faisable en headless (pas de serveur).

**Ce n'est pas du code maintenant** : c'est une spec de Phase 2 à documenter avant que
le signal soit perçu comme prévisible. L'implémentation Phase 2 peut attendre P3 (équilibrage).
L'intention doit exister AVANT pour ne pas graver la Phase 1 comme définitive.

**Source** : PSU.com 2025 (VRR pur = règle invisible, VRR semi-prévisible = dégénère en
fixe partiel) ; MDPI 2025 (MDPI 2025, mdpi.com/2078-2489/16/10/890 : seuil N≈55 pulls
avant que le pity/rule soit modélisé dans les gacha = analogie limitée mais instructive
sur la demi-vie de la surprise).

### Proposition D — LITIGE #Z : trancher le cold-start du signal spectre AVANT le code (PRIORITÉ 1, design uniquement)

**Ce** : le litige #Z (signal spectre en cold-start, pool local vide) est ouvert depuis
le round 5. Ce round demande de le trancher **avant** d'écrire la spec RENDER de §2.8,
parce que les deux options ont des implications de codage différentes.

**Option 1 (silence)** : N=0 → rien. Propre mais inutile pendant ~5 premiers runs
(le pool local ne s'est pas encore rempli). La session initiation n'a pas de signal pendant
exactement la période où elle est la plus critique (onboarding).

**Option 2 (IA avec formulation distincte)** : compter les combats vs IA (encounters
IA = `aiComp` de `snapstore.lua:serveComp`, identifiables) avec un message distinct :
« LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE — [N] INVOCATION(S) L'ONT
ÉPROUVÉ ». Les IA ne sont **pas présentées comme humaines** (honnêteté). Le mécanisme
de trace d'impact fonctionne quand même : ton build a eu un impact réel (sur l'IA du
froid).

**Position de ce round** : **Option 2 par défaut, avec fallback silencieux si N=0 même pour les IA.**
La raison : l'onboarding est la période la plus critique (Countly 2026 : « les 90 s post-
relance du joueur qui revient ») ; les premières sessions n'ont pas encore de ghosts humains ;
refuser le signal pendant cette période = forcer le joueur à recommencer sans raison
visible de revenir. L'IA n'est pas présentée comme humaine = honnêteté préservée.

**À trancher par l'user** (décision de DA) : est-ce que « LE PUITS A SOUMIS TON BUILD
AUX ÉPREUVES DU VIDE » casse le cryptique ou l'enrichit ? Si la réponse est oui → Option
1 (silence), et accepter l'absence de signal en cold-start.

---

## 4. QUESTIONS OUVERTES (nouvelles ce round, ou mal tranchées)

**Q_R7_1 — Demi-vie du VRR boutique** : à quel nombre de runs le joueur moyen modélise-t-il
la règle de déclenchement du signal boutique (rang ≥ `shopTier` OU ≥ 60 % `dot_family`) ?
Proxy mesurable en playtest : observer à quel run le joueur **commence à anticiper** le
signal (chercher l'offre surlignée avant de reroller). Si < 10 runs → Phase 2 nécessaire
rapidement. **Pas de mesure sim possible (subjectif)** → playtest.

**Q_R7_2 — Nom de build : archétype ou famille ?** La Prop §3 (§2.2 de ce round) propose
des noms dérivés de `dot_family`. La question : est-ce que le nom doit refléter la **famille
majoritaire** (plus simple, toujours valide) ou **l'intention de build** (plus riche, nécessite
de détecter les combos 2+2) ? Si la roadmap adopte le système de types P1 (familles = types,
compteur global), le nom de build peut être directement dérivé du **palier de type actif**
au moment du résultat — ce qui supprime l'ambiguïté. **Dépend de P1.**

**Q_R7_3 — Grimoire par famille ou par archétype ?** La vue par archétype de build (Prop D
§2.4 de ce round) est plus riche mais dépend des noms de build (Q_R7_2). Séquencer :
(1) noms de build → (2) Grimoire II par archétype optionnel. Sinon → Grimoire II par famille
seul (déjà adopté round 6).

**Q_R7_4 — Signal spectre en version locale partiellement peuplée** : en v1 locale avec
FIFO 200 snapshots, si le joueur a joué 5 runs, son ghost est dans le pool avec 4 autres
ghosts. `P(ghost joueur servi dans un match) ≈ 1/5 × (1 - (1-1/5)^N)` = probabilité
non nulle mais faible en early. Le compteur `battles_since_last_session` est-il
empiriquement > 0 après 3-4 jours d'absence ? À vérifier avant de promettre le signal
comme mécanisme de rétention (#Z non tranché).

---

## 5. CHALLENGE CLÉ (résumé)

La couche de rétention de la roadmap v7 est la plus solide à ce stade, avec des ancrages
théoriques corrigés (trace d'impact, Ovsiankina). Ce round identifie un trou d'identité
et deux risques d'atténuation. **Trou d'identité** : le Moment du Run nomme une unité mais
pas un build — sans nom de build, la fierté de construction (Déclos 2025) reste de
l'attribution d'événement, pas d'identité de run, et les 6-8 rounds de travail sur le
signal manquent leur cible psychologique principale. **Premier risque d'atténuation** :
le VRR de boutique tel que spécifié (règle visible) a une demi-vie courte pour les joueurs
expérimentés — il faut une Phase 2 moins prévisible ou accepter explicitement qu'il devient
de l'UI utile après ~10 runs. **Second risque** : il n'existe pas de mesure de saturation
VRR sur un run complet — l'empilement de 17-28 signaux par run est peut-être excessif au
regard de Kao et al. 2024 (amplification excessive réduit l'agence), et mérite une enveloppe
d'intention documentée avant d'implémenter tous les signaux.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 7/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *Boyle et al. 2024 (Nature Sci Rep, Wordle goal gradient & near-miss) : https://www.nature.com/articles/s41598-024-74450-0*
- *Kao et al. 2024 (CHI, Juicy Feedback, amplification paradox) : https://nickballou.com/publication/2024-kao-et-al-juicy/*
- *Nature H&SS 2025 (meta-analyse Zeigarnik & Ovsiankina, weighted resumption = 67%) : https://www.nature.com/articles/s41599-025-05000-w*
- *Yu-kai Chou 2026 (behavioral guide, Zeigarnik vs Ovsiankina) : https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/*
- *PSU.com 2025 (VRR, slot machine psyche) : https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/*
- *MDPI 2025 (Gacha addiction, pity threshold N≈55) : https://www.mdpi.com/2078-2489/16/10/890*
- *Kammonen 2024 (Progression Systems in Roguelite Games) : https://www.theseus.fi/bitstream/10024/881994/2/Kammonen_Eino.pdf*
- *Diva-portal 2026 (Hades 2 vs TBOI meta-progression) : https://his.diva-portal.org/smash/get/diva2:2072480/FULLTEXT01.pdf*
- *Mobile Game Report 2026 (SAP depth, shop sequencing) : https://www.mobilegamereport.com/articles/super-auto-pets-depth-vs-casual-2026*
- *DEV Community 2026 (build naming, identity vs data) : https://dev.to/yurukusa/50-lines-of-code-15-build-names-one-accidental-challenge-mode-1be1*
- *Countly 2026 (Push notifications, lapsed player re-engagement) : https://countly.com/blog/how-to-use-push-notifications-to-bring-lapsed-players-back-to-your-game*
- *AMCIS 2025 (Progress bar design principles, motivation) : https://aisel.aisnet.org/amcis2025/sig_game/sig_game/5/*
- *Nature Sci Rep 2025 (Learning progress, difficulty, fun) : https://www.nature.com/articles/s41598-025-14628-2*
