# Round 06 — Critique adversariale : lentille rétention-addiction

> **Lentille** : variance vs agence, high-roll, near-miss sous agence, méta-progression
> Grimoire, one-more-run.
>
> **Inputs lus** : `BRIEF.md`, `00-state.md`, `ROADMAP-draft.md` (v6, intégré round 5),
> `round-05.md` (synthèse), `rounds/r0{1,2,3,4,5}-retention-addiction.md`,
> `competitive/balatro.md`, `competitive/slay-the-spire.md`, `competitive/super-auto-pets.md`,
> `competitive/hades.md`, `competitive/the-bazaar.md`, `competitive/postmortems.md`.
>
> **Recherche web menée ce round** :
> - Ballou et al. 2024 (ACM TOCHI, SDT HCI Games Research : Unfulfilled Promises) :
>   https://dl.acm.org/doi/full/10.1145/3673230 — arxiv : https://arxiv.org/html/2405.12639
> - Ballou 2024 (blog : SDT in Video Games, Misconceptions about Basic Psychological Needs) :
>   https://nickballou.com/blog/sdt-in-video-games-basic-needs-misunderstandings/
> - PMC 2024 (Möller, Kornfield & Lu : Competition and Digital Game Design — SDT) :
>   https://pmc.ncbi.nlm.nih.gov/articles/PMC12412733/
> - Nature Humanities and Social Sciences Communications 2025 (méta-analyse Zeigarnik & Ovsiankina) :
>   https://www.nature.com/articles/s41599-025-05000-w
> - GameAnalytics Mobile Gaming Benchmarks 2025 (rétention D1/D7/D30) :
>   https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks
> - PSU.com 2025 (Variable Ratio Reinforcement, Slot Machine Psyche, gaming engagement) :
>   https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/
> - arXiv 2025 (Self-Presence, Social-Presence, Basic Psychological Need Satisfaction in Social VR) :
>   https://arxiv.org/pdf/2602.12764
> - Switchblade Gaming 2026 (Best Auto-Battler Games ranked by Skill Ceiling and Match Length) :
>   https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/
> - ResetEra community (meta-progression roguelikes knowledge vs power discussion) :
>   https://www.resetera.com/threads/do-you-like-meta-progression-in-your-roguelikes-roguelites.1341955/
> - Helpshift 2026 (Re-Engagement Campaigns for Mobile Games, lapsed player prompt timing) :
>   https://www.helpshift.com/blog/re-engagement-campaigns-for-mobile-games/
>
> **Posture adversariale** : les rounds 1-5 ont construit une couche de rétention cohérente.
> Ce round 6 attaque TROIS HYPOTHÈSES DE TRANSFERT qui n'ont pas été challengées en profondeur :
> (A) La SDT appliquée aux ghosts async tient-elle vraiment — le besoin de relatedness peut-il
> être satisfait par un adversaire non-humain figé ? (B) Le Zeigarnik appliqué au Grimoire
> repose-t-il sur une preuve solide ou sur une citation incomplète d'un effet controversé ?
> (C) Le VRR du Moment du Run est-il le bon mécanisme principal, ou masque-t-il un problème
> plus fondamental de one-more-run dans une boucle build-spectateur ?
>
> **Garde-fou** : lecture seule du code du jeu. N'édite que sous `docs/roadmap-lab/`.
> **Piliers respectés** : async par snapshots, sim déterministe seedée, DA grimdark,
> pixel art procédural. 32 invariants préservés.

---

## 0. Position de l'agent

Les rounds 1-5 ont produit cinq mécanismes de rétention bien ancrés. Ce round 6 ne
les démonte pas en bloc. Il challenge THREE PILLARS D'ARGUMENTATION que la roadmap
a importés de la littérature sans démonter le transfert dans nos contraintes spécifiques :

1. **SDT-Appartenance via ghost** : la proposition §2.8 repose sur l'hypothèse que voir
   « 3 joueurs ont affronté ton spectre » satisfait le besoin de relatedness de la SDT.
   La littérature SDT sur les jeux en 2024-2025 critique massivement ce transfert automatique.

2. **Zeigarnik → silhouette du Chapitre III** : l'argument cite Zeigarnik pour justifier que
   le Chapitre III (Abysses) doit être visible dès P2 en silhouette. La méta-analyse 2025
   (Nature H&SS) trouve que « the Zeigarnik effect lacks universal validity ». Le fondement
   tient-il encore ?

3. **VRR 20-30 % + Moment du Run** : la roadmap cible ~25 % de déclenchements en se basant
   sur Hopson 2001. Mais le VRR du Moment du Run est-il vraiment ce qui crée le one-more-run
   — ou est-ce un signal de mid-session qui ne suffit pas dans une boucle où le joueur est
   SPECTATEUR du combat ?

---

## 1. ACCORDS — ce qui tient, avec le pourquoi précis dans NOS contraintes

### 1.1 Accord fort : le signal « spectre affronté » est le meilleur levier de session initiation disponible, MALGRÉ les limites de la SDT-relatedness

**Accord avec round 5 §1.5 / ROADMAP-draft v6 §2.8.**

Je maintiens la proposition même en contestant son ancrage SDT (§2.1 ci-dessous). Voici
pourquoi le signal tient par un autre mécanisme :

**Ce qui fonctionne vraiment** (pas la SDT-relatedness, qui est fragile) : le signal active un
mécanisme plus primitif de **réciprocité et d'identité persistante**. La psychologie
comportementale identifie que l'information sur l'impact de ses actions passées (même figées)
génère une **amorce comportementale** qui incite à agir à nouveau. Dans notre contexte :
- Le snapshot = une action passée (construire un build).
- « N âmes l'ont affronté » = preuve que cette action a eu un impact réel.
- L'amorce = « mon action passée vit encore → agir à nouveau ».

Ce mécanisme est distinct de la relatedness (besoin d'appartenance sociale) et plus robuste dans
un contexte solo-compétitif sans interaction directe. Il n'exige pas que le joueur se sente
« connecté » aux autres joueurs — juste que son action passée ait eu une trace.

**Source** : Countly 2026 (Push Notifications for Player Re-Engagement) — « The first 90
seconds after a lapsed player relaunches the game is a critical moment-of-return » — identifie
que le prompt de retour doit être **immédiatement visible au lancement**, et qu'il doit
concerner **l'identité persistante du joueur** (progression, impact, trace), pas un événement
social abstrait. Notre signal « spectre affronté » est exactement ça, visible au menu.
https://countly.com/blog/how-to-use-push-notifications-to-bring-lapsed-players-back-to-your-game

**Dans NOS contraintes async** : le signal est local-first, 0 serveur, 0 live — cohérent avec
tous les piliers. Coût ~2h RENDER. L'accord porte sur la VALEUR du mécanisme, pas sur le
fondement SDT.

### 1.2 Accord fort : la validation des distributions temporelles VRR AVANT de coder les deux signaux (anti-cannibalisation)

**Accord avec round 5 §1.6 / ROADMAP-draft v6 §2.4.**

Kao et al. 2024 (CHI) est une source solide. La proposition de mesurer `P(chain_len≥P75 ET
edge_missed≥1 | round_i)` avant de coder est saine — c'est de la discipline de méthode, pas de
la sur-ingénierie. Le coût est ~0.5h sim pour éviter de construire deux signaux qui se sabordent.

**Dans NOS contraintes** : la sim headless existe, la métrique `chain_len` est extractible du
bus JSONL. C'est une précondition légitime. Maintenu sans réserve.

### 1.3 Accord fort : le link streak-loss → post-combat actionnable (pas qu'un chiffre d'or)

**Accord avec round 5 §1.7 / ROADMAP-draft v6 §2.3.**

L'asymétrie psychologique de la perte (Kahneman-Tversky, ~2.3×) combinée au fait que l'or
de streak arrive APRÈS la défaite (trop tard dans le cycle de correction) est un vrai problème.
Le signal qui pointe un SLOT exposé + peu d'arêtes actives est actionnable et ne viole aucun
pilier.

**Nuance** : le signal grimdark doit pointer une DÉCISION, pas diagnostiquer un état. La
formulation « ton architecture de mort mérite d'être repensée + slot X = angle mort » est
bonne. **Garde-fou DA** : ne jamais dire « tu aurais dû » (moralisateur dans le grimdark) ;
dire « LE PUITS A ENREGISTRÉ TA FAIBLESSE » (révélation plutôt que conseil).

### 1.4 Accord conditionnel fort : le Grimoire 3 chapitres comme arc de méta-progression de CONNAISSANCE

**Accord avec rounds 1-5 / ROADMAP-draft v6 §6.7.**

Le principe « méta-progression de connaissance plutôt que de puissance » est bien ancré et
cohérent avec nos piliers (simulation déterministe = builds répétables = la connaissance s'accumule
vraiment). La structure 3 chapitres (Afflictions / Essences / Abysses) donne un arc visible.

**MAIS le fondement Zeigarnik est faible** (§2.2 ci-dessous). L'accord porte sur la valeur du
Grimoire indépendamment de Zeigarnik — il tient via un autre mécanisme que je propose (voir §3.1).

### 1.5 Accord fort : seuil P75 sur 1000 seeds aléatoires (non les 250 seeds fixes du fuzz)

**Accord avec rounds 4-5 / ROADMAP-draft v6 §2.4.**

Le biais de l'échantillon déterministe des 250 seeds fixes est réel. P75 sur 1000 seeds
variées pour le seuil de chaîne du Moment du Run est correct. Maintenu.

---

## 2. DÉSACCORDS — ce qui est faible, mal sourcé ou non étayé dans NOS contraintes

### 2.1 DÉSACCORD FORT : l'ancrage SDT-relatedness du signal « spectre affronté » est invalide dans notre contexte — mais le SIGNAL RESTE VALIDE PAR UN AUTRE MÉCANISME

**Position §2.8 de la roadmap** : le signal d'appartenance async satisfait le besoin de
relatedness SDT (Möller, Kornfield & Lu 2024).

**Pourquoi cet ancrage spécifique est problématique :**

**Ballou et al. 2024 (ACM TOCHI, « SDT and HCI Games Research: Unfulfilled Promises »,
arxiv.org/html/2405.12639)** — la revue la plus complète à ce jour (259 papiers examinés) —
trouve que : (1) « Unfulfilled promises » = les claims causaux de la SDT appliqués aux jeux
restent empiriquement non testés dans la littérature publiée ; (2) sur 259 papiers, la
relatedness est traitée dans seulement 59.85 % d'entre eux, et les effets causaux de la
conception du jeu sur la relatedness sont les moins documentés des trois besoins ; (3) « all
of the above posited causal relations remain empirically untested in published SDT literature ».

Ce qui nous concerne directement : **la proposition que « voir que son ghost a été affronté »
satisfait le besoin de relatedness de la SDT est précisément le genre d'affirmation causale que
Ballou identifie comme non étayée**. La relatedness SDT est définie comme la connexion à d'autres
personnes, le sentiment d'appartenance à un groupe, d'être accepté. Un ghost figé qu'un inconnu
a affronté sans que les deux joueurs aient eu connaissance l'un de l'autre est **l'analogue le
plus distant possible de la relatedness** — c'est de la trace, pas de la connexion.

**PMC 2024 (Möller et al., le même papier cité par la roadmap, pmc.ncbi.nlm.nih.gov/articles/
PMC12412733/)** dit explicitement : « Studies have frequently ignored relatedness need satisfaction »
— ce n'est pas une validation que les ghosts async satisfont la relatedness, c'est un constat
d'absence d'étude. La roadmap inverse la charge de preuve.

**Ce qui reste valide** : le signal tient via un mécanisme différent (§1.1 : réciprocité et
identité persistante) qui n'a pas besoin de la SDT-relatedness. Le signal est bon, son ancrage
théorique est faible. **Proposition** : remplacer la justification SDT-relatedness par l'ancrage
« amorce comportementale sur l'identité persistante » dans la spec §2.8.

**Impact concret** : aucun changement de code. Juste reformuler le WHY de la spec pour éviter
de bâtir des décisions UX futures sur un fondement empiriquement fragile (ex : « le joueur
devrait voir le nom des joueurs qui ont affronté son ghost » — non : si la valeur n'est pas la
connexion sociale mais la trace d'impact, l'anonymat grimdark est préférable).

### 2.2 DÉSACCORD MODÉRÉ : l'effet Zeigarnik utilisé pour justifier la « silhouette du Chapitre III » manque de fondement depuis 2025

**Position §1.16 / §6.7 de la roadmap** : le Chapitre III (Abysses) doit exister en silhouette
dès P2 car « Zeigarnik ne fonctionne que sur un horizon visible mais fermé ».

**Ce que la recherche 2025 dit :**

**Nature Humanities and Social Sciences Communications 2025 (méta-analyse Zeigarnik &
Ovsiankina, nature.com/articles/s41599-025-05000-w)** — méta-analyse de toutes les études sur
les deux effets — conclut : « a 2025 systematic review and meta-analysis found no memory
advantage for unfinished tasks but found a general tendency to resume tasks. The authors
concluded that the Ovsiankina effect represents a general tendency, whereas the Zeigarnik
effect lacks universal validity. »

**La distinction est importante pour notre cas :**
- **Zeigarnik** (les tâches inachevées sont mieux mémorisées que les achevées) → **invalidé**
  comme effet universel.
- **Ovsiankina** (tendance à reprendre les tâches interrompues) → **tient** comme tendance
  générale.

Ce que la roadmap cite comme « Zeigarnik » est en réalité plus proche de l'**Ovsiankina** :
« la silhouette fermée crée une tension de reprise ». C'est donc le bon mécanisme invoqué, mais
par le mauvais nom. L'argument peut être remonté sur une base plus solide.

**Ce qui tient vraiment** : la silhouette du Chapitre III est justifiée non par Zeigarnik mais
par le mécanisme de **closure partielle** (visible + verrouillé = tension de reprise = Ovsiankina).
Le **Goal Gradient Effect** (Nunes & Drèze 2006, déjà cité dans la roadmap pour le sub-tier
ranked) est une justification plus solide que Zeigarnik pour cette situation : voir une cible
à horizon fini déclenche l'accélération de la motivation pour l'atteindre.

**Proposition** : dans la spec §6.7, remplacer la citation Zeigarnik par Goal Gradient / Ovsiankina.
Le MÉCANISME (silhouette dès P2) reste juste ; la SOURCE théorique change. Coût : 1 phrase de
spec. L'action de dev reste identique.

### 2.3 DÉSACCORD MODÉRÉ : le Moment du Run (VRR ~25 %) est un mécanisme de MILIEU DE SESSION qui ne crée pas le one-more-run dans une boucle spectateur

**Position §2.4 de la roadmap** : le Moment du Run (VRR à ~25 % des combats) est le mécanisme
central de rétention.

**La faille structurelle que la roadmap n'adresse pas :**

Dans Balatro, le VRR est un mécanisme d'**agence directe** : le joueur FAIT l'action (choisit
les cartes, voit le score exploser). La récompense variable est liée à une décision active.
Dans The Pit, le joueur est SPECTATEUR du combat. Le Moment du Run se déclenche POST-COMBAT
quand le joueur LIT le résumé du bus. Ce n'est pas du VRR au sens opérant du terme — c'est
de la **narration rétrospective d'un événement qu'il n'a pas joué**.

**Pourquoi c'est important pour le one-more-run :**

La littérature VRR (PSU.com 2025, JCOMA 2024) distingue deux effets :
- **VRR sous agence** : chaque pull est une décision → l'incertitude est « au bout du geste ».
- **VRR narré** : on raconte ce qui s'est passé → la récompense est lue, pas vécue.

Le one-more-run de Balatro vient du premier (« je relance parce que je veux faire l'action »).
Notre Moment du Run produit au mieux le second (« c'était bien de lire ça »). **Les deux ne
sont pas psychologiquement équivalents en terme de motivation de relance.**

**Ce qui crée vraiment le one-more-run dans NOS contraintes :**

Après 5 rounds de débat, la roadmap a bien construit la rétention INTRA-RUN (le joueur qui
joue continue de jouer). Mais le one-more-run dans une boucle build-spectateur vient d'un
mécanisme différent : **l'anticipation de la prochaine décision de BUILD, pas du prochain
combat**. Dans Super Auto Pets (notre référence), le VRR est dans la BOUTIQUE, pas dans le
combat — le joueur relance pour voir quelles unités seront proposées, pas pour voir le prochain
combat automatique.

**Preuve par analogie sourcée (Switchblade Gaming 2026, Best Auto-Battler Games 2026,
switchbladegaming.com/strategy-games/best-auto-battler-games-2026/)** : l'article identifie
comme facteur #1 de rétention dans les autobattlers « the build phase unpredictability — what
will the shop offer me ? » — pas la phase de combat. Les jeux morts (Dota Underlords,
Storybook Brawl) ont tous essayé de rendre le combat plus spectaculaire ; les jeux vivants
(SAP, TFT) ont rendu la phase BOUTIQUE plus imprévisible.

**Proposition** : il manque dans la roadmap un mécanisme de VRR explicitement ancré sur la
BOUTIQUE — pas les reliques (qui sont les récompenses du run), mais la BOUTIQUE elle-même.
Le « reroll gratin » (voir 5 nouvelles unités après un reroll) devrait avoir son propre signal
de surprise d'offre. Voir §3.2.

### 2.4 DÉSACCORD LÉGER : la condition de désactivation de la Surprise de Placement est SOUS-SPÉCIFIÉE et risque de débrayer trop tôt pour le profil passif

**Position §2.7 de la roadmap** : désactivée quand `grimoire:hasLearnedAdjacency()`.
Le round 5 a ouvert Q_R5_1 sans la trancher (désactivé après ≥5 arêtes sur ≥3 combats).

**Le risque concret :**

Un joueur passif (profil 2, round 5) qui déclenche 5 arêtes par accident sur 3 combats
(parce que le plateau de départ a une configuration naturellement adjacente) verra la Surprise
disparaître avant d'avoir APPRIS que le placement est une décision. Le critère « ≥5 arêtes
activées » est une MESURE DE QUANTITÉ, pas une mesure d'APPRENTISSAGE.

**Critère alternatif plus robuste** : désactivé quand le joueur a activé une arête
INTENTIONNELLEMENT — c'est-à-dire quand il a déplacé une unité (drag depuis sa position
actuelle vers une autre) en build, ET que ce déplacement a activé une arête. Le bus JSONL
encode les drags. Ce n'est pas infaillible (le joueur peut déplacer par accident), mais
c'est moins faux que le critère quantitatif pur.

**Source** : Digital Thriving Playbook (SDT for Multiplayer Games, Autonomy Need Satisfaction) :
« autonomy satisfaction requires that the player perceives their choices as causal, not just
that choices occurred. » L'apprentissage de l'adjacence nécessite que le joueur perçoive
que c'est SA décision qui a activé l'arête.

---

## 3. PROPOSITIONS PRIORISÉES (concrètes, chiffrées, ancrées sur nos ressources)

### Proposition A — Refonder l'ancrage théorique de §2.8 : « trace d'impact » remplace « SDT-relatedness » (~0h, doc uniquement)

**Ce** : dans la spec §2.8, remplacer la justification SDT-relatedness (Möller et al.) par
l'ancrage « amorce comportementale par trace d'impact persistante » :
- Fogg Behavior Model : prompt externe + motivation de l'impact = initiation de session.
- Identité persistante : le snapshot = action passée vivante → prime to act.
- Non-social mais identitaire : ne requiert pas que le joueur « se sente connecté » aux
  adversaires — juste que son build ait eu une trace.

**Pourquoi prioritaire** : aucun coût de code, mais prévient de mauvaises décisions UX
dérivées (ex : « montrer les noms des joueurs pour augmenter la relatedness » — ce n'est
pas l'axe, ça rompt le grimdark). Le signal reste identique (N = combats depuis la dernière
session) mais son SENS est différent : ce n'est pas « tu as des amis », c'est « ton passage
dans le Puits a laissé une marque ».

**Formulation grimdark alternative à §2.8** : « LE PUITS GARDE MÉMOIRE DE TON BUILD — [N]
ÂME[S] Y ONT AFFRONTÉ SON ÉCHO DEPUIS TON DÉPART ». Le mot « spectre » est bon ; « âme » pour
l'adversaire renforce l'asymétrie anonyme (grimdark, pas social).

**Litige #Z (NOUVEAU)** : en cold-start (N=0 silencieux, Q_R5_2), accepter le silence ou
déclencher sur les IA avec formulation différente ? **Proposition** : déclencher sur les IA
avec formulation distincte — « LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE — [N]
INVOCATION[S] ». L'IA n'est pas présentée comme un humain (honnêteté), mais l'impact reste
concret. **À trancher avant le code.**

### Proposition B — VRR de BOUTIQUE : signal « offre exceptionnelle » dans le reroll (~2h RENDER)

**Ce** : dans `build.lua` (RENDER, pas SIM), quand un reroll produit une offre contenant une
unité de rang ≥ `shopTier` ou une unité dont l'identité `dot_family` correspond à ≥ 60 % du
build actuel (champ `dot_family` de P0.5), déclencher un signal discret — « LE PUITS ATTIRE
TON ATTENTION » + légère pulsation de l'offre concernée.

**Pourquoi cette priorité :**

Le VRR du Moment du Run est de la narration post-hoc. Le VRR de boutique est de l'agence directe
— le joueur a décidé de reroller, il voit le résultat immédiatement. C'est le mécanisme
psychologique correct pour le one-more-run dans une boucle d'autobattler :
- SAP (notre référence) : le tirage de la boutique est la source de surprise principale.
- TFT (competitive reference) : « what did I get in the shop ? » est la question qui lance chaque round.
- Autobattler 2025 (Switchblade Gaming) : le facteur #1 de rétention = l'imprévisibilité de la boutique.

**Coût** : RENDER pur, ~2h. Lire `shopTier` depuis `state` (hors SIM). Comparer `dot_family`
des unités de l'offre vs `dot_family` des unités du plateau. **0 invariant. Zone sans test →
test que le signal se déclenche pour la bonne unité sur un golden de build connu.**

**Garde-fou DA** : le signal est DISCRET (pulsation, pas fanfare) — le Puits attire l'attention,
ne célèbre pas une trouvaille. La surprise reste à vivre, pas annoncée. **Jamais actif sur le
premier shop d'un round** (sinon le joueur apprend à attendre le signal avant d'acheter).

**Complémentarité avec le Moment du Run** : le VRR boutique est en BUILD (agence directe,
décision active) ; le Moment du Run est post-COMBAT (narration). Les deux sont temporellement
distincts et psychologiquement complémentaires. Pas de cannibalisation (les mécanismes
d'agence directe et de narration rétrospective sont traités par le cerveau dans des circuits
différents — PSU.com 2025, VRR in modern gaming).

**Seuil [PH]** : « rang ≥ `shopTier` ou ≥ 60 % de `dot_family` match ». À calibrer via sim sur
N=100 builds (target : ~30 % des rerolls déclenchent le signal — Hopson 2001 : 20-30 % optimal).

### Proposition C — Refonder l'arc Grimoire via Goal Gradient + Ovsiankina, pas Zeigarnik (~0h, doc)

**Ce** : dans la spec §6.7, remplacer la citation Zeigarnik par :
- **Ovsiankina effect** (méta-analyse Nature 2025) : « a general tendency to resume interrupted tasks ».
  La silhouette du Chapitre III crée une interruption visible → tendance à résumer.
- **Goal Gradient** (Nunes & Drèze 2006) : « closer to goal = higher motivation ». La silhouette
  avec « ??? synergies » + un progress indicator (X/Y du Chapitre II complété) active le goal
  gradient vers le Chapitre III.

**Pourquoi ce n'est pas que du doc :** la distinction Zeigarnik/Ovsiankina change la SPEC du
Chapitre III en silhouette. Si c'est Zeigarnik (mémoire d'inachevé), la silhouette doit être
mémorable → design riche. Si c'est Ovsiankina (reprise d'interrompu), la silhouette doit donner
envie de REPRENDRE → le Chapitre III doit sembler déjà commencé, pas juste annoncé.

**Conséquence concrète** : le Chapitre III en silhouette (P2) devrait montrer 1-2 synergies
en « ??? » avec une structure reconnaissable (ex. « [SIGIL ANNEAU] × [POISON] → ??? »), pas
juste un titre verrouillé. Ça donne l'impression que quelque chose a déjà été interrompu —
ce qui est le déclencheur Ovsiankina.

### Proposition D — Critère de désactivation de la Surprise de Placement : déplacement intentionnel plutôt que quantité d'arêtes (~0h, spec)

**Ce** : dans la spec §2.7, remplacer `grimoire:hasLearnedAdjacency()` par :
`grimoire:hasMovedForAdjacency()` — vrai quand le joueur a effectué ≥3 drags intentionnels
(unité déplacée depuis sa position vers une autre) qui ont chacun activé ≥1 arête nouvelle sur
le sigil actif.

**Implémentation** : le bus JSONL encode déjà `{source, cell.x, cell.y, cause}` pour les
événements de build. Lire les drags (`cause = "player_move"`) depuis le log de session. En
`build.lua` (RENDER), après chaque placement, calculer si l'arête nouvelle activée l'était
avant. `grimoire.lua` mémorise le compteur cross-run. **~1h RENDER, 0 SIM, 0 invariant.**

**Pourquoi intentionnel > quantitatif** : un plateau de 5 unités sur le sigil carré a 6 arêtes
possibles — on peut en activer 5 sans jamais DÉPLACER une unité (juste les placer dans un ordre
naturel). La Surprise de Placement doit disparaître quand le joueur déplace POUR activer une
arête, pas juste quand il en a accumulé assez par hasard.

**Litige #Y (NOUVEAU)** : faut-il distinguer le profil passif (qui ne déplace jamais) du profil
engagé (qui déplace souvent) ? Si le profil passif ne déclenche jamais le critère, la Surprise
ne se désactive jamais et devient du bruit après 20 runs. **Mitigation** : cap dur à 10 sessions
indépendamment du critère d'intentionnalité. À valider en playtest.

---

## 4. QUESTIONS OUVERTES (nouvelles ce round)

**Q_R6_1 — Ancrage SDT vs ancrage « trace d'impact »** : si l'on abandonne SDT-relatedness
pour « amorce comportementale par trace d'impact », quelles autres décisions de la roadmap
reposent sur des affirmations SDT-relatedness non testées ? **À auditer** : §6.7 (Grimoire
comme satisfaction de compétence — la compétence SDT est la mieux documentée des trois ;
accord maintenu) ; §6.11 (moteur pré-run ranked — ancré sur le Goal Gradient, pas la SDT ;
accord maintenu).

**Q_R6_2 — VRR boutique vs Moment du Run : lequel crée le ONE-MORE-RUN ?** La roadmap traite
le one-more-run comme une conséquence des signaux intra-session. Mais dans une boucle
build-spectateur, le déclencheur de relance est probablement la DERNIÈRE DÉCISION de build
du run : « je voulais essayer X, je n'ai pas pu — je relance ». Ce mécanisme (l'intention
non-réalisée du build) n'est pas traité par la roadmap. Proche de l'Ovsiankina (intention
interrompue), mais côté BUILD, pas Grimoire. **À investiguer en P0 via un simple compteur :
combien de runs se relancent <30s après la fin vs >5min** (mesure de l'impulsion de relance).

**Q_R6_3 — Zeigarnik-Ovsiankina pour le Grimoire : valide côté BESTIAIRE ?** Le Chapitre II
(Essences = 83 unités, bestiaire) est plus grand que le Chapitre I (reliques). Si le joueur
a vu 40/83 unités, est-ce que le Goal Gradient fonctionne sur un si grand pool ? La recherche
(LogRocket 2024 Goal Gradient UX) suggère que l'effet s'efface quand la cible paraît trop
lointaine (~7 étapes, déjà cité pour le sub-tier ranked). 83 unités = 83 étapes → pas de goal
gradient direct. **Mitigation** : segment le bestiaire par famille (ex. « 11/15 unités poison
découvertes » — la cible est 15, pas 83). Propose une spec fractionnée du Chapitre II.

**Q_R6_4 — Le signal VRR boutique est-il DA-compatible avec le grimdark ?** « Le Puits attire
ton attention » sur une bonne offre risque de rendre l'adversité du Puits contradictoire (le
Puits te GUIDE vers les bonnes choses vs le Puits = oppressif/cryptique). **Réponse provisoire** :
le signal doit être formulé comme une menace ou une résistance, pas une aide. « LE PUITS
RÉSISTE À TA FAIBLESSE — [UNITÉ] S'IMPOSE » — l'offre te force la main, elle ne t'aide pas.
Cohérent avec la DA grimdark.

---

## 5. CHALLENGE CLÉ (résumé)

La roadmap v6 a une couche de rétention intra-session rigoureuse. Ce round identifie deux
faiblesses critiques de fondement et un trou mécaniste. Premier : l'ancrage SDT-relatedness
du signal « spectre affronté » est fragilisé par la méta-critique 2024 (Ballou, ACM TOCHI) et
par la nature même du ghost async — ce n'est pas de la connexion sociale, c'est de la trace
d'impact, et la spec doit le nommer ainsi. Deuxième : le Moment du Run est un mécanisme de
narration rétrospective post-combat, pas de VRR sous agence directe — pour une boucle
build-spectateur, le one-more-run naît de l'anticipation de la prochaine BOUTIQUE, pas du
prochain combat, et la roadmap n'a pas de signal VRR ancré sur la boutique (Proposition B).
Troisième : le Zeigarnik utilisé pour la silhouette du Chapitre III est invalide comme
universellement cité depuis la méta-analyse 2025, mais l'Ovsiankina (reprise d'interrompu)
tient et change légèrement la SPEC de la silhouette : montrer quelque chose de déjà commencé,
pas juste d'annoncé.

---

*Rédigé le 2026-06-23. Lentille : rétention-addiction (variance vs agence, high-roll,
near-miss sous agence, méta-progression Grimoire, one-more-run). Round 6/10 du roadmap-lab.
Lecture seule du repo. N'édite que sous `docs/roadmap-lab/`. Garde-fous : piliers
async/déterministe/grimdark/procédural préservés, 32 invariants non touchés.*

*Sources web vérifiées ce round :*
- *Ballou et al. 2024 (SDT HCI Games, Unfulfilled Promises) : https://dl.acm.org/doi/full/10.1145/3673230 + https://arxiv.org/html/2405.12639*
- *Ballou 2024 (SDT Misconceptions blog) : https://nickballou.com/blog/sdt-in-video-games-basic-needs-misunderstandings/*
- *PMC 2024 (Möller, Kornfield, Lu — Competition and Digital Game Design) : https://pmc.ncbi.nlm.nih.gov/articles/PMC12412733/*
- *Nature H&SS 2025 (méta-analyse Zeigarnik & Ovsiankina) : https://www.nature.com/articles/s41599-025-05000-w*
- *GameAnalytics 2025 Mobile Benchmarks (D1/D7/D30 retention) : https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks*
- *PSU.com 2025 (Variable Ratio Reinforcement in gaming) : https://www.psu.com/news/the-slot-machine-psyche-how-variable-ratio-reinforcement-drives-modern-gaming-engagement/*
- *Switchblade Gaming 2026 (Best Auto-Battler Games 2026) : https://www.switchbladegaming.com/strategy-games/best-auto-battler-games-2026/*
- *Countly 2026 (Push Notifications, lapsed player re-engagement) : https://countly.com/blog/how-to-use-push-notifications-to-bring-lapsed-players-back-to-your-game*
- *LogRocket 2024 (Goal Gradient Effect in UX) : https://blog.logrocket.com/ux-design/goal-gradient-effect/*
- *Kao et al. 2024 (CHI, Juicy Feedback, sense of agency) : https://nickballou.com/publication/2024-kao-et-al-juicy/*
- *Nunes & Drèze 2006 (Goal Gradient Hypothesis) : https://www.researchgate.net/publication/239776073*
