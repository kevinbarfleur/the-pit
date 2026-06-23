# Round 07 — Critique adversariale : lentille Ranked & Compétitif

> **Lentille** : MMR/ladder, saisons, leaderboards, intégrité async, ce qui pousse à grinder
> le ranked et enchaîner les runs.
>
> **Statut** : round 7/10. Challenge le brouillon v7 (`ROADMAP-draft.md` post-round-6),
> la synthèse `round-06.md` et le document de lentille précédent `rounds/r06-ranked-competitive.md`.
> Les rounds 1-6 ont posé (entre autres sur le ranked) :
> - Grille sans pénalité `+4/+2/+1/0` — motif mis à jour (format run-court + FIFO imparfait)
> - Pool ranked SÉPARÉ (`mode`) + `RANKED_MIN_POOL` progressif (SOFT=3 / HARD=5, clos #T)
> - `slot_tier_composite` matchmaking + fallback descendant 5-étapes
> - Signal pré-run au sub-tier (goal-gradient borné ~7 étapes, Nunes & Drèze 2006)
> - Litige #Y (FIFO de saison : persistance filtrée vs vidage complet), #V (sv) re-lié à #Y
> - Saisons 3-4 sem. sans contenu, 6-8 sem. avec contenu (Fresh Start Effect, Milkman 2014)
> - Fenêtre de grâce « Montée des Ombres » 7 j + persistance filtrée (`wins_at_capture ≥ 3`)
> - Cosmétique DATÉ de fin de saison (urgence émotionnelle)
> - Signal « spectre affronté » (trace d'impact), litige #Z (cold-start : silence vs IA distincte)
> - Contrainte du Jour (daily) gating famille par `win_rate ≥ 0.8×médiane`
> - Contrainte Permanente de Saison §8.0 (P4-light), litige #U ouvert
> - Daily timezone locale v1
>
> **Sources primaires mobilisées ce round** :
> - `ROADMAP-draft.md` v7, `round-06.md`, `rounds/r06-ranked-competitive.md`, `00-state.md`
> - `competitive/{tft,marvel-snap,super-auto-pets,the-bazaar,backpack-battles}.md`
> - The Bazaar ranked updates 2025 : `bazaar-builds.net/patch-1-0-0-mak-is-out-prize-pass-update-daily-ranked-tickets-back-more/`
> - Bazaar matchmaking ghost pool : `thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar`
> - Turnbound (async autobattler avec ghost pool) : `store.steampowered.com/app/3802470/Turnbound_a_bazaar_backpack_auto_battler/`
> - TFT ranked MMR vs LP (hidden MMR / perception) : `immortalboost.com/blog/teamfight-tactics/ranked-system-explained/`
> - Backpack Battles player count actif 2026 : `activeplayer.io/backpack-battles/` (~1 861 actifs)
> - Activision SBMM research (2024 PDF) : `activision.com/cdn/research/CallofDuty_Matchmaking_Series_2.pdf`
> - Call of Duty SBMM deprioritization : `gamedeveloper.com/design/deprioritizing-skill-based-matchmaking-turned-call-of-duty-into-the-bad-place`
> - PMC10839887 : SBMM + perte + churn (maintenu des rounds précédents)
> - Dai, Milkman & Riis 2014 Management Science (Fresh Start Effect — maintenu)
>
> **Garde-fous absolus** : lecture seule du repo. N'édite que sous `docs/roadmap-lab/`.
> Piliers intacts : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
> 32 invariants préservés.

---

## 0. TL;DR du challenge R07

**Cinq angles d'attaque : 2 désaccords fondamentaux, 2 lacunes de spec majeures, 1 question ouverte
à trancher avant le code.**

1. **DÉSACCORD MAJEUR — La roadmap n'a PAS de réponse au problème central du ranked async : le pool
   de ghosts ne représente PAS le skill du joueur qu'il affronte, mais l'état de son build à un point
   précis de sa run.** Le `slot_tier_composite` est une proxy du progrès, pas du skill. Les 6 rounds
   de débat ont traité le ranked comme un problème de _pool size_ (combien de ghosts) et de
   _matchmaking_ (quel composite), sans jamais confronter le problème de validité de la métrique
   centrale : qu'est-ce qu'un « ghost à mon tier » représente vraiment ? Cette lacune conceptuelle
   invalide partiellement la prémisse de justice du ranked.

2. **DÉSACCORD FONDAMENTAL — Le litige #Z (cold-start : silence vs IA avec formulation distincte)
   est sous-estimé comme risque de rétention.** Ce n'est pas un détail UX à « trancher avant le code »
   — c'est le défi de survie de la saison 1. Les runs ranked à S1 SERONT quasi exclusivement contre
   des IA (pool FIFO vide). Le signal « spectre » (§2.8) ne compense pas l'absence de tension compétitive
   réelle. Or le Bazaar a montré qu'un ranked mal peuplé tue la motivation d'y retourner (Steam
   discussions 2025 : « ranked matching might need balancing »). La roadmap traite le cold-start comme
   un cas marginal à gérer ; il faudrait le traiter comme le cas DOMINANT de la saison 1.

3. **LACUNE — Le signal pré-run (§6.11 sub-tier) suppose que le joueur COMPREND ce que le rang
   mesure.** Or la distinction entre `slot_tier_composite` (proxy de progrès) et « niveau de jeu »
   n'est nulle part expliquée. Le TFT ranked a un problème structurel similaire (hidden MMR vs LP
   visible — immortalboost.com 2026 : « That gap creates almost every common ranked question ») qui
   nuit à la perception de justice. Pour The Pit, le problème est amplifié : le score ne reflète
   PAS le skill, il reflète le résultat de runs contre des builds dont la qualité varie selon la
   population du pool.

4. **LACUNE — La progression ranked n'a pas de signal de comparaison INTRA-TIER.** La roadmap
   donne un sub-tier closable en 1-3 runs (accord fort, maintenu), mais elle ne montre PAS où le
   joueur se situe PAR RAPPORT AUX AUTRES joueurs à son tier. Sans ce signal, l'appartenance au
   tier est une progression solitaire, pas une compétition. C'est pourquoi le « why should I grind
   ranked ? » reste non résolu au-delà du sub-tier.

5. **QUESTION OUVERTE NON TRANCHÉE — Le Daily (§6.6 Contrainte du Jour) est-il RANKED ou UNRANKED ?**
   La roadmap ne le précise pas clairement. Si Daily = ranked → les familles sur-représentées dans
   le pool ranked du jour biaiseront le résultat de la contrainte. Si Daily = unranked → la
   contrainte est découplée du MMR et perd son rôle d'intégration méta.

---

## 1. Accords — et POURQUOI ils tiennent à nos contraintes

### 1.1 Grille `+4/+2/+1/0` sans pénalité — ACCORD FORT (maintenu, raisonnement consolidé)

**Accord maintenu.** Le raisonnement r06 (format run-court + FIFO imparfait) est le bon.

**Ce qui consolide cet accord ce round** : la recherche Activision (2024, activision.com/cdn/research/
CallofDuty_Matchmaking_Series_2.pdf) sur la déprioritisation du SBMM montre que les 90 % de joueurs
aux tiers inférieurs sont les plus sensibles aux pertes — et que leur churn s'amplifie si la perte
est perçue comme injuste (matchmaking mal calibré = injustice perçue). Notre FIFO local **ne peut
garantir** la qualité du matchup → une pénalité amplifie le churn sur la quasi-totalité de la base
joueurs (qui sera inévitablement en bas de la courbe en saison 1). Le `+4/+2/+1/0` reste la seule
option compatible avec notre pool imparfait.

**Ce qui ne change pas** : ne plus citer Bazaar 2025 comme validation (il a les pénalités, r06 §1.1).

### 1.2 `RANKED_MIN_POOL` progressif SOFT=3 / HARD=5 — ACCORD FORT

**Accord maintenu.** La règle progressive est correcte. La Fenêtre de Grâce (7 j, mode SOFT) est la
bonne réponse au démarrage de saison.

**Nuance apportée ce round** : le seuil HARD=5 est correct pour l'idéal, mais en **saison 1 avec 0
joueurs**, même SOFT=3 ne sera pas satisfait avant la 3e ou 4e session du joueur. La Fenêtre de Grâce
7 j (en SOFT) est donc le mécanisme **dominant** en saison 1, pas l'exception. L'ordre de priorité
doc doit refléter ça : SOFT est la norme S1, HARD est la cible S2+.

### 1.3 Signal pré-run sub-tier (goal-gradient borné) — ACCORD FORT

**Accord maintenu.** Nunes & Drèze 2006 : efficace si < ~7 étapes. Sub-tier en 1-3 runs = correct.

### 1.4 `slot_tier_composite` matchmaking — ACCORD SUR LA MÉCANIQUE

**Accord sur le mécanisme** (monotone croissant, stable à la capture, plus granulaire que rang pur).
**Mais le §2 ci-dessous ouvre un désaccord sur ce que ce composite mesure vraiment.**

### 1.5 Cosmétique DATÉ de fin de saison — ACCORD FORT

**Accord maintenu.** L'urgence émotionnelle du reset est un besoin réel. Les cosmétiques texte/icône
sont DA-cohérents et zéro-gameplay.

### 1.6 Saisons courtes (3-4 sem. sans contenu) — ACCORD MAINTENU (avec précision)

**Accord maintenu.** Le raisonnement Fresh Start Effect (Milkman 2014) + cadence échelonnée par
contenu est solide. **Précision apportée** : à 3 sem. avec 2-3 runs/sem = 6-9 runs/saison, le joueur
mid-core ne monte que d'un demi-tier. Cela signifie que le signal pré-run (§6.11) montrera souvent
« PROCHAIN GRADE : Forgé — 4 pts » pendant DEUX saisons. Ce n'est pas un problème si le joueur
comprend qu'il progresse (les 4 pts s'accumulent d'une saison à l'autre). **Il faut clarifier que
le score ranked persiste entre saisons** (reset −20 %, pas à 0) pour que le joueur voie sa
progression inter-saisonnière. Ce point manque à la spec §6.3.

### 1.7 Contrainte Permanente de Saison (§8.0) — ACCORD DE PRINCIPE

**Accord de principe** : l'idée de `teamFlag` seedé par la saison pour renouveler la méta ranked est
élégante et async-safe (s'applique à `combat_start` côté résolution, pas dans le snapshot).

**Nuance** : ce mécanisme est en P4-light (entre P2 et P4), mais il est **critique pour la rétention
de la S2**. Si la S1 finit avec un meta stable (et elle finira ainsi, sans reliques G), les joueurs
qui ont atteint leur plateau en S1 n'ont **aucune raison mécanique** de revenir en S2 sinon le reset.
La §8.0 doit être une **priorité visible dans le calendrier P2**, pas une note de bas de page.

---

## 2. Désaccords — avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — Le `slot_tier_composite` mesure le PROGRÈS dans une run, pas le SKILL du build

**Ce que le brouillon v7 §6.4 dit** : `slot_tier_composite` = proxy monotone croissant (slots + tier
courant) comme dimension de matchmaking. Un ghost à « mon tier » = un ghost qui a atteint un niveau
de boutique similaire dans sa run.

**Mon désaccord** : ce composite est une mesure du **progrès dans la run** (combien de rounds joués,
combien de slots ouverts, quel tier de boutique atteint), **pas du skill du build**. Deux joueurs
peuvent avoir le même `slot_tier_composite` et avoir des builds de forces très différentes :

- Un joueur en round 7 avec `shopTier=3` et 7 slots **mais un build incohérent** (pas de synergie de
  type, unités dispersées) aura le même composite qu'un joueur avec un **build poison T2 full-cohérent**.
- La différence de puissance entre ces deux builds peut être **3-5× en win-rate de combat** (données
  de sim : hiérarchie poison > tank > ... > choc, 00-state §2.1 balance-diagnosis).

**Conséquence** : le matchmaking par `slot_tier_composite` peut créer des confrontations perçues
comme très déséquilibrées — un build cohérent T3 mid vs un build dispersé T3 mid. Le joueur au build
cohérent gagne systématiquement contre un même profil de composite. Ce n'est pas de la compétence :
c'est un artefact de la qualité du pool.

**Pourquoi ce n'est pas résolu par `RANKED_MIN_POOL`** : augmenter la taille du pool diversifie les
builds disponibles, mais ne garantit pas que le composite proxy la **force de build réelle**. TFT
résout ce problème grâce à un **lobby de 8 joueurs en direct** où tous les builds sont soumis à la
même économie du même round — l'information est symétrique. Chez nous, chaque ghost a été construit
dans une run DIFFÉRENTE avec une économie DIFFÉRENTE, un adversaire DIFFÉRENT. La seule chose commune
est le `slot_tier_composite`.

**Référence concrète** : le problème de MMR caché vs rang visible dans TFT
(immortalboost.com/blog/teamfight-tactics/ranked-system-explained/ : « the game shows you LP, but
the system actually makes its biggest decisions using MMR. That gap creates almost every common ranked
question ») est analogue mais **inverse** dans The Pit : nous affichons un rang et un composite, mais
le composite ne reflète pas le skill du build. Chez TFT, l'MMR caché est plus précis que le LP
visible. Chez nous, ni le rang ni le composite ne capturent la puissance du build adverse.

**Ce qui est transfert valide vs analogie paresseuse** : on ne peut PAS copier le LP de TFT (LP
reflète l'issue de 8 matchups simultanés dans le même lobby). Ce qu'on peut emprunter est le
**principe d'information exposée sur la qualité de la confrontation** (TFT affiche le MMR approximatif
du lobby en ranked Diamond+). Applied à The Pit : exposer une indication sur la **cohérence du build**
adverse (famille dominante, nombre d'arêtes actives capturées dans le snapshot) **AU MOMENT où le
joueur voit le résultat du combat** — pas avant (spoil) mais après (attribution).

**Ce n'est pas un appel à tout reconstruire.** C'est un appel à reconnaître que `slot_tier_composite`
est un proxy imparfait qui doit être **accompagné d'une communication honnête** (« tu n'affrontes pas
quelqu'un de ton niveau, tu affrontes quelqu'un qui a progressé autant que toi ») et d'une
**amélioration progressive** du proxy (§3.1 ci-dessous).

### 2.2 DÉSACCORD FONDAMENTAL — Le cold-start ranked S1 est le cas DOMINANT, pas marginal

**Ce que le brouillon v7 §6 + round-06 traitent** : le litige #Z (cold-start signal spectre : silence
vs IA-formulation distincte) est présenté comme un détail à trancher. Le FIFO ranked SOFT=3 + fenêtre
de grâce 7 j est présenté comme la solution au démarrage de saison.

**Mon désaccord** : pour un jeu en lancement avec un nombre limité de joueurs, **les runs ranked en
saison 1 seront QUASI-EXCLUSIVEMENT contre des IA** (pool ranked vide pendant les 2-3 premières
semaines, même avec la persistance filtrée). Pourtant, la roadmap n'aborde pas ce que cela fait à la
**proposition de valeur du ranked** : si le ranked = IA en S1, POURQUOI jouer ranked plutôt que
normal ?

**Preuve de la gravité** : le Bazaar Steam (steamcommunity.com/app/1617400/discussions/0/
591780787069850050/ : « ranked is [broken] ») et « ranked matching might need balancing »
(steamcommunity.com/app/1617400/discussions/0/591780152569114689/) révèlent que même un jeu avec
une base joueurs de plusieurs dizaines de milliers a souffert de ranked mal peuplé au lancement.
Notre FIFO 200 local avec **possiblement < 50 joueurs en beta** ne peut pas atteindre un pool ranked
vivant rapidement.

**Ce que la roadmap propose** : la fenêtre de grâce 7 j (SOFT=3) et la persistance filtrée
(`wins_at_capture ≥ 3`) minimisent le problème mais ne le résolvent pas. En S1 avec 30 joueurs
actifs, 10 qui jouent ranked avec `wins_at_capture ≥ 3` = **pool 10**, restreint par tier →
possiblement 0-2 ghosts ranked au bon tier. La fenêtre de grâce maintient SOFT mais le SOFT peut
retomber sur IA.

**La distinction ranked/unranked perd son sens en S1 si les deux modes affrontent principalement
des IA.** La proposition de valeur compétitive s'effondre. Le joueur doit alors grinder ranked pour
des raisons **méta-progressives** (cosmétiques, marques, Grimoire) et non pour la **tension
compétitive** — ce qui est un changement profond de la psychologie du mode, jamais discuté dans les 6
rounds précédents.

**Ce n'est pas un drapeau rouge sur le pilier** (l'async par snapshots reste correct). C'est une
alerte sur la **communication** : le ranked S1 doit être présenté aux joueurs comme un mode de
**progression personnelle avec adversaires fantômes** (et non comme un mode compétitif classique).
Sans cette communication, le joueur découvrira la réalité par lui-même et sera déçu.

**Ce qui est transférable du Bazaar** : Bazaar patch 1.0.0 (bazaar-builds.net/patch-1-0-0, avril 2025)
a réintroduit les tickets journaliers ranked et calibré l'entrée progressive en normal avant ranked
(builds de difficulté croissante) — précisément parce que lancer le ranked trop vite avec un pool mal
peuplé avait nui à la rétention. Le Bazaar avait un backend mondial et a quand même eu ce problème.

### 2.3 DÉSACCORD PARTIEL — Le signal pré-run (§6.11) donne l'horizon mais pas la RAISON DE GRINDER ranked

**Ce que le brouillon v7 §6.11 dit** : signal pré-run = grille + distance sub-tier + signal de pool.
C'est « le manquant #1 ».

**Mon désaccord partiel** : le signal pré-run répond à la question « est-ce que je vais monter ce
run ? ». Il ne répond pas à la question « **pourquoi est-ce que ce run ranked compte plus qu'un run
normal** ? ». L'absence de réponse à cette question crée un syndrome qu'on observe dans d'autres
autobattlers async (discussions Bazaar Steam 2025 : « I don't feel the difference between ranked and
normal ») : le joueur joue ranked par habitude, pas par motivation compétitive.

**Ce qui manque** : un signal d'**identité compétitive** qui différencie le run ranked du run normal
AVANT que le run commence, au-delà des chiffres. Le grimdark peut fournir ça : un mode ranked = «
descente au vrai Puits » vs normal = « répétition » (exemple de framing). Ce n'est pas un appel à
ajouter des mécaniques — c'est un appel à **nommer la différence** dans le framing UI. La mécanique
différente (pool séparé, ghosts humains, progression vers les marques) est déjà là ; elle n'est pas
présentée comme une proposition identitaire distincte.

**Coût** : **0 mécanique**. Modification de l'écran de sélection de mode (§6.11) pour nommer le
ranked avec une **identité**, pas juste une grille de points.

---

## 3. Propositions priorisées

### 3.1 — Améliorer le proxy de matchmaking async : capturer la COHÉRENCE du build en plus du composite — PRIORITÉ 2

**Problème** : `slot_tier_composite` mesure le progrès, pas la force du build (§2.1).

**Proposition** : ajouter une **dimension de cohérence** au composite de matchmaking, calculable
depuis le snapshot sans modifier la structure (compatible 00-state §5 : snapshot `{version, tier,
seed, shape, units={{id, level, col, row}}}`).

La cohérence peut être estimée par **2 signaux déjà présents dans le snapshot** :

**(a) Dominance de famille** = `max_family_count / total_units`. Un build avec 5 unités poison sur 7
a une dominance ~0.71. Un build dispersé : 0.28. Ce signal est calculable par `Units.dotFamily(id)`
(déjà prévu pour P0.5, `dot_family`) sans aucun nouveau stockage.

**(b) Arêtes actives** = proportion de slots occupés adjacents selon le sigil. Calculable depuis
`{shape, units[][col,row]}` → `shapes.lua` → arêtes actives / max arêtes du sigil.

**Composite enrichi (optionnel)** = `slot_tier_composite × (1 + 0.2 × build_coherence)` où
`build_coherence = (dominance + edge_ratio) / 2`. Ce multiplicateur favorise les builds cohérents
vs dispersés — sans exclure les builds wide intentionnels (le wide a un `edge_ratio` naturellement
haut si bien placé).

**Pourquoi c'est optionnel maintenant** : calculer la cohérence du pool entier à chaque serve est
un peu plus coûteux en IO. **En v1 : ne pas modifier le composite** (garder `slot_tier_composite`
tel quel) mais **exposer la cohérence du ghost adverse dans le post-combat** (§2.3 enrichi ranked) —
c'est de la transparence, pas du rééquilibrage. **En v2 (P2+)** : enrichir le composite si les
retours montrent des disparités perçues.

**Coût v1** : `toComp(s)` déjà présent dans `snapshot.lua` → calculer `dot_family` counts +
`edge_count` pour les afficher dans le post-combat ranked (lecture seule, hors SIM, 0 invariant).
**Zone sans test** → test que `toComp` renvoie les counts corrects sur un golden snapshot.

### 3.2 — Définir la PROPOSITION DE VALEUR ranked S1 autour de la progression personnelle, pas de la compétition — PRIORITÉ 1 (AVANT LE CODE)

**Problème** : le ranked S1 sera peuplé quasi exclusivement d'IA (§2.2). L'identité compétitive est
absente (§2.3).

**Proposition** : **trancher la question « ranked S1 = quoi ? » AVANT de coder le mode** (décision
éditoriale, pas code). Deux options :

**(a) OPTION HONNÊTE — Le ranked S1 = « descente contre les Fantômes du Puits »** : assumer que
les adversaires ranked en S1 seront majoritairement des IA, communiquer ça comme une **caractéristique
de la DA** (le Puits peuple ses profondeurs d'IA-Invocations = grimdark cohérent). Les marques
Survivant/Forgé/Ascendant restent des récompenses de progression personnelle. Le ranked ne prétend
pas être du PvP compétitif en S1.

**(b) OPTION DIFFÉRÉE — Le ranked est DÉSACTIVÉ en S1** jusqu'à `RANKED_MIN_POOL_SOFT` satisfait
pendant ≥3 jours consécutifs. En attendant, un **mode « Pré-Ranked »** (unranked avec persistance
des marques) est proposé. Le ranked S1 s'ouvre progressivement — comme Backpack Battles qui
segmente ses rangs par activité.

**Recommandation** : **Option (a)** — l'option (b) crée une frustration pour les early adopters
qui veulent faire partie du lancement compétitif. L'option (a) exploite la DA grimdark pour
transformer la faiblesse (peu de joueurs = fantômes non humains) en caractéristique thématique.

**Coût** : 0 code. 1 décision éditoriale à acter dans `seed/decisions.md` AVANT le code P2 (ranked).
**Modification de la spec §6.5** (signal 🟡 Pool Mince) : ajouter le framing « les Invocations du
Puits répondent à l'appel » plutôt que « run non comptée » — la run EST comptée, mais contre des IA.

**Ce qui change dans la spec §6.11** : le texte pré-run ranked S1 est « LE PUITS S'ÉVEILLE — tes
premiers rivaux sont les Invocations (Fantômes du Puits) » → pas de tromperie, pas de déception.

### 3.3 — Trancher le litige #Z MAINTENANT (signal spectre cold-start) : IA avec framing DISTINCT — PRIORITÉ 1 (bloquant P2)

**Problème** : le litige #Z (cold-start : silence vs IA formulation distincte) reste ouvert depuis
round-06. Il bloque la spec de §2.8 (signal spectre).

**Position argumentée** :

Le **silence** (N=0 → rien) est psychologiquement incorrect pour la **rétention au lancement** :
au lancement, TOUS les joueurs sont en cold-start → TOUS voient le silence → le signal spectre
n'existe PAS pendant les premières sessions → le **moteur de session-initiation est absent** pendant
la phase la plus critique pour la rétention (Countly 2026 : les 90 premières secondes post-relance).

La **formulation IA distincte** (« LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE — [N]
INVOCATION[S] ») préserve :
1. **Honnêteté** : les Invocations ne sont pas présentées comme humaines.
2. **Trace d'impact** : le build a quand même été utilisé par le moteur de sim → l'impact est réel
   (N combats réellement simulés contre le build).
3. **DA grimdark** : le Puits teste ton build contre ses propres créatures = fiction cohérente.
4. **Continuité vers la proposition de valeur S1** (option 3.2a) : si le ranked S1 = Invocations,
   la formulation du spectre pour les IA est **cohérente avec la proposition ranked**.

**Recommandation** : **IA avec formulation distincte** — clôt #Z. AVANT le code §2.8.

**Coût** : 0 mécanique. Texte i18n + condition `if N > 0 AND battles_are_ai THEN "INVOCATIONS"
ELSE "ÂMES"`. `snapstore.lua` track déjà `battles_since_last_session` (IO hors SIM, 0 invariant).
**Zone sans test** (existante) → test que le signal distingue IA vs humain sur un golden de store.

### 3.4 — Ajouter un signal de COMPARAISON INTRA-TIER (onde de position) — PRIORITÉ 3 (P2, lightweight)

**Problème** : §2.3 — la progression ranked est solitaire. Le joueur sait où il en est par rapport
au sub-tier, mais pas par rapport aux autres joueurs à son tier (§0, lacune #4).

**Proposition** : un signal **minimal et grimdark** de comparaison intra-tier, **sans classement**
(pas de leaderboard global — risque FOMO et comparaison destructive pour une petite base de joueurs,
adriancrook.com « leaderboards impact player retention » : « leaderboards that focus on friends
outperform global rankings for retention »).

**Signal** : dans l'écran de fin de run (ou Grimoire), afficher **une phrase** du type : « LE PUITS
T'A ACCORDÉ [RANG]. [X] ÂMES PARMI [Y] ONT FRANCHI CE SEUIL CE CYCLE. » où X = nb de joueurs à ce
rang dans la saison, Y = nb total de runs ranked ce cycle. L'information est **locale** (calculée
depuis le FIFO ranked local, IO hors SIM), grimdark, **non compétitive** (pas de nom, pas de rang
des adversaires) mais **contextualisante** (je ne suis pas seul dans ce rang).

**Garde-fou** : afficher seulement si `Y ≥ RANKED_MIN_POOL_SOFT` (pool suffisant pour que les
chiffres aient du sens). Si Y < SOFT → ne pas afficher (éviter « 2 âmes ont franchi ce seuil »).

**Coût** : lecture du FIFO ranked local + comptage par tier (IO hors SIM, 0 invariant). RENDER,
~1 h. **Zone sans test** → test que les comptes sont corrects sur un FIFO golden.

### 3.5 — Spec explicite du MAINTIEN du score ranked ENTRE saisons (clarification §6.3) — PRIORITÉ 2 (doc)

**Problème** : §1.6 (accord) — à 3 sem./saison, le joueur mid-core monte d'un demi-tier par saison.
Le score ranked persist entre saisons (reset −20 %, pas à 0). Ce point est implicite dans la spec
mais pas explicitement communiqué.

**Proposition** : ajouter dans §6.3 une spec UX **visible** : en fin de saison et au démarrage de la
suivante, le signal de début (§6.11) affiche EXPLICITEMENT : « PUITS S [N] : TU AS CONSERVÉ [X] PTS
DE TA DESCENTE PRÉCÉDENTE. TA PROGRESSION TRAVERSE LES SAISONS. » Cela :
1. Prévient la déception du reset partial (le joueur voit −20 % comme une perte s'il ne sait pas
   que c'est un reset doux).
2. Renforce la valeur de chaque saison (les points comptent à long terme).

**Coût** : lecture de `playerRating` (avant/après reset), RENDER §6.11 pré-run. 0 mécanique,
0 invariant.

---

## 4. Points maintenus tels quels (accord net)

### 4.1 Pool ranked SÉPARÉ + signal 🟢🟡🔴 — MAINTENU

Le pool séparé + 3 états (Vivant/Mince/Silencieux) restent la bonne architecture. La §3.2 de ce
round ajoute un FRAMING au signal 🟡, pas une mécanique nouvelle.

### 4.2 `slot_tier_composite` matchmaking en V1 — MAINTENU (avec amélioration proposée en V2)

La §3.1 ne demande pas de modifier le composite maintenant. V1 : composite existant + cohérence
exposée en post-combat. V2 : composite enrichi si les retours le justifient.

### 4.3 Fenêtre de grâce 7 j « Montée des Ombres » — MAINTENU

Mécanisme correct. §1.2 de ce round précise que cette fenêtre est la norme S1 (pas l'exception).

### 4.4 Cosmétiques datés + log Grimoire — MAINTENU

Architecture confirmée. Le log Grimoire est le vecteur (cohérent avec §2.8 spectre).

### 4.5 Contrainte du Jour gating famille — MAINTENU (avec clarification demandée, §5.1)

Le gating par `win_rate ≥ 0.8×médiane` reste correct. La question de ranked vs unranked (§0, point 5)
doit être tranchée.

### 4.6 Dernier Souffle (§6.10, 1 vie) — MAINTENU

Mécanisme correct. Aucun nouveau challenge.

---

## 5. Questions ouvertes (nouvelles + précisions)

### 5.1 [NOUVEAU litige #BB] — Le Daily (§6.6 Contrainte du Jour) est-il RANKED ou UNRANKED ?

**Position** : la roadmap §6.6 ne le précise pas. Deux options :
- **Daily = UNRANKED** : le joueur joue avec la contrainte sans que le run impacte son score ranked.
  Avantage : la contrainte peut être plus expérimentale (pas de peur de perdre du rang). Inconvénient :
  le Daily perd son lien avec la méta ranked.
- **Daily = RANKED avec pool dédié** : le Daily est un run ranked avec la contrainte du jour. Pool
  de ghosts filtré sur `dailyConstraint` (famille/sigil du jour). Avantage : tension compétitive
  réelle. Inconvénient : si la famille du jour est poison (dominant), le Daily ranked est biaisé.

**Recommandation préliminaire** : Daily = UNRANKED avec leaderboard JOURNALIER séparé (score daily
≠ ranked MMR). C'est le modèle StS Daily : compétition journalière distincte du ranked ladder. La
confusion ranked/daily détruirait le gating par `win_rate` (une contrainte daily ne peut pas attendre
que la famille soit équilibrée en ranked avant de l'activer — le daily doit fonctionner dès la S1,
avant que le pool ranked soit assez grand pour mesurer les `win_rate` par famille).

**Urgence** : à trancher AVANT le code P2 (ranked) — les deux modes partagent la même infrastructure
de run (`state.lua`), il faut savoir dès P2 si le daily est un mode ranked ou séparé.

### 5.2 [PRÉCISION litige #Y] — La persistance filtrée (`wins_at_capture ≥ 3`) crée-t-elle un BIAIS de build ?

**Position** : un ghost avec `wins_at_capture ≥ 3` est un build qui a survécu au round 3 au moins.
**Par définition**, ces builds ont prouvé une cohérence minimale (3 wins = le build fonctionnel
de base). **Le FIFO ranked S1 sera donc biaisé vers les builds cohérents** — ce qui est une propriété
UTILE (le joueur ranked affronte des builds qui « marchent »), pas un bug.

Mais : en S1 avec peu de joueurs, `wins_at_capture ≥ 3` + pool ranked vide → **certains tiers peuvent
n'avoir aucun ghost filtré**. La fenêtre de grâce (SOFT) et les IA comblent ça, mais il faut
documenter explicitement : **les IA ranked sont calibrées sur des builds cohérents** (Encounter IA,
00-state §5 `serveComp` → `aiComp`) pour éviter que les runs ranked S1 soient contre des « builds
aléatoires » IA.

**À ajouter à la spec §6.4bis** : les IA ranked (`aiComp`) sont sélectionnées depuis les Encounters
les plus puissants (non pas `rand()` dans `encounters.lua` mais les builds à la force d'un joueur
établi). 0 code new (les Encounters existent déjà, décision de sélection).

### 5.3 [MAINTENU litige #A] — Mesure `--meta-convergence` sur runs unranked libres (précision r06)

Accord maintenu de r06. À mesurer sur les runs unranked libres (pas de biais de sélection ranked).
Aucune décision nouvelle ce round.

### 5.4 [MAINTENU litige #U] — Contrainte Permanente de Saison : famille à bas win-rate vs sous-représentée

Maintenu ouvert. Données post-P0.5 requises. Aucun nouvel argument ce round.

---

## 6. Démontage des analogies faibles dans la section ranked

### 6.1 — « TFT affiche le LP potentiel → The Pit doit afficher le gain potentiel » (§6.11)

**Analogie partiellement paresseuse.** TFT affiche le LP potentiel **dans un lobby de 8 joueurs
humains en temps réel**. L'incertitude de TFT vient du fait que 7 adversaires humains vont
interagir avec votre build en direct. Le gain LP dépend de votre position finale, qui dépend
d'adversaires réels.

Dans The Pit, le gain ranked (`+4/+2/+1/0`) dépend du **résultat de la run** (10 victoires vs 5
défaites), mais les adversaires sont des **ghosts figés**. L'incertitude n'est pas « vais-je finir
top 4 parmi 8 humains ? » mais « vais-je gagner 10 fois avec mon build contre les builds du pool ? ».
C'est une incertitude de **build**, pas de **placement social**.

**Ce qui tient dans l'analogie** : afficher la grille `+4/+2/+1` + distance sub-tier = exposer
l'enjeu mécanique en pré-run. C'est le bon usage. **Ce qui ne tient pas** : presenter ça comme
la même tension sociale que TFT (« tu vas affronter de vrais humains »). L'écran §6.11 doit rester
**honnête sur la nature async** sans dévaluer la tension (« les builds que tu vas affronter ont
été construits par des joueurs humains qui sont descendus avant toi »).

### 6.2 — « LoL ranked rewards saisonniers = moteur de rétention #1 » (§6.12)

**Analogie trop forte.** LoL est un jeu à identité sociale forte (le rang LoL = statut social).
La récompense saisonnière LoL (icône de profil, border) a de la valeur parce qu'elle EST VISIBLE
par les autres joueurs dans les lobbies et les profils publics.

Dans The Pit (solo dev, local-first, async pur), **personne ne voit ton rang** — il n'y a pas de
lobby social, pas de profil public, pas de « flexing ». La récompense cosmétique de saison a donc
une valeur **mémorielle interne** (je sais que j'ai eu le cosmétique Saison 2) et non **sociale**
(les autres me voient comme un joueur de rang X).

**Ce qui tient dans l'analogie** : la rareté temporelle (non reproductible en S2) + l'arc
« j'ai accompli quelque chose avant que ça disparaisse » (Milkman 2014). Ces éléments restent
valides même sans audience sociale.

**Ce qui ne tient pas** : suppose que le cosmétique a une valeur de signalement social. Dans The
Pit v1, il n'en a pas → il faut calibrer les attentes en conséquence dans la spec §6.12 (pas de
« moteur de rétention #1 » — c'est un **complément** au Fresh Start, pas un driver principal).

---

## 7. Tableau de synthèse des propositions

| Proposition | Section roadmap | Priorité | Coût |
|---|---|---|---|
| Trancher #Z MAINTENANT (IA formulation distincte) | §2.8 | **P1 — BLOQUANT P2** | 0 mécanique, texte i18n |
| Trancher #BB (Daily ranked ou unranked ?) | §6.6 | **P1 — BLOQUANT P2** | Décision éditoriale |
| Spec proposition de valeur ranked S1 (option a : Invocations) | §6.5 + §6.11 | **P1 — AVANT CODE P2** | 0 code, framing |
| Clarifier que le score persiste entre saisons | §6.3 | **P2 — spec** | 0 mécanique |
| Cohérence build dans post-combat ranked (V1) | §2.3 enrichi | **P2** | ~2 h RENDER |
| Signal comparaison intra-tier (onde de position) | §6.8 ou nouveau §6.13 | **P3 — lightweight** | ~1 h RENDER |
| Acter que les IA ranked = builds Encounter puissants | §6.4bis | **P2 — spec** | 0 code, décision sélection |
| Cohérence build dans composite (V2) | §6.4 | **P4 — si besoin** | enrichissement `toComp` |

---

## 8. Récapitulatif des litiges

| # | Litige | Statut R07 |
|---|---|---|
| **#A** | P1 types vs P2 ranked | Maintenu ; mesure sur runs unranked libres (précision r06) |
| **#U** | Saison : bas win-rate vs sous-représentée | Maintenu ouvert (données P0.5) |
| **#V** | `sv` maintenant vs au 1er champ persisté | Re-lié à #Y (r06), différé |
| **#Y** | FIFO ranked entre saisons (persistance filtrée vs vidage) | Maintenu ; §5.2 ce round précise que la persistance filtrée est un AVANTAGE de qualité |
| **#Z** | Signal spectre cold-start — silence vs IA formulation distincte | **RECOMMANDATION : IA formulation distincte (§3.3). À trancher avant le code §2.8.** |
| **#AA** | Seuil VRR boutique (~30 % rerolls) | Maintenu ; calibrer en sim P0 |
| **#BB** | **NOUVEAU** : Daily = ranked ou unranked ? | **Ouvert. Recommandation : unranked + leaderboard journalier séparé. Bloquant P2.** |

**Litiges neufs ce round** : **#BB** (Daily ranked vs unranked).
**Litiges recommandés à clore** : **#Z** (IA formulation distincte, argument mécaniste clair).

---

## 9. Index des sources R07

| Affirmation | Source vérifiée |
|---|---|
| MMR caché vs LP visible TFT = « every common ranked question » | [immortalboost.com — TFT ranked system explained 2026](https://immortalboost.com/blog/teamfight-tactics/ranked-system-explained/) |
| Déprioritisation SBMM CoD : 90 % des joueurs inférieurs churnent plus | [gamedeveloper.com — SBMM deprioritization](https://www.gamedeveloper.com/design/deprioritizing-skill-based-matchmaking-turned-call-of-duty-into-the-bad-place) |
| Activision 2024 : perte perçue injuste amplifie le churn des tiers inférieurs | [activision.com/cdn/research/CallofDuty_Matchmaking_Series_2.pdf](https://www.activision.com/cdn/research/CallofDuty_Matchmaking_Series_2.pdf) |
| Bazaar ranked frustration S1 (pool mal peuplé) | [steamcommunity.com discussions Bazaar 2025](https://steamcommunity.com/app/1617400/discussions/0/591780787069850050/) |
| Bazaar patch 1.0.0 : tickets journaliers ranked réintroduits + onramp progressif | [bazaar-builds.net/patch-1-0-0-mak-is-out-prize-pass-update-daily-ranked-tickets-back-more/](https://bazaar-builds.net/patch-1-0-0-mak-is-out-prize-pass-update-daily-ranked-tickets-back-more/) |
| Bazaar ghost pool : pool ranked séparé + rang ≤ joueur | [thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar](https://www.thebazaargame.net/guides-news/how-does-matchmaking-work-in-the-bazaar) |
| Turnbound : async autobattler avec ghost pool ranked | [store.steampowered.com/app/3802470/Turnbound_a_bazaar_backpack_auto_battler/](https://store.steampowered.com/app/3802470/Turnbound_a_bazaar_backpack_auto_battler/) |
| Leaderboards amis > global pour rétention | [adriancrook.com — leaderboards impact player retention](https://adriancrook.com/how-leaderboards-impact-player-retention/) |
| Backpack Battles : ~1 861 actifs en 2026, 8 rangs | [activeplayer.io/backpack-battles/](https://activeplayer.io/backpack-battles/) |
| Countly 2026 : 90 s post-relance = moment critique | cité round-06 §2.8 (maintenu) |
| Fresh Start Effect (landmarks proches > lointains) | Dai, Milkman & Riis 2014, Management Science (cité rounds précédents) |
| PMC10839887 : perte + matchmaking perçu injuste = churn | cité rounds précédents (maintenu) |

**Sources rounds 1-6 conservées** : Nunes & Drèze 2006 ; Milkman 2014 ; PMC10839887 ; Bazaar
septembre 2025 patch ; Fogg BM ; Ballou et al. 2024 ACM TOCHI ; Kahneman-Tversky (2,3×).

---

*Produit le 2026-06-23. Lentille : ranked-competitive. Round 7/10.*
*Lecture seule du repo (aucun code modifié). N'édite que sous `docs/roadmap-lab/`.*
*Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.*
*32 invariants préservés : toutes les propositions sont RENDER/IO/data hors SIM ou décisions éditoriales.*
*Zones sans test nouvelles signalées : §3.1 (`toComp` cohérence build) ; §3.3 (distinction IA vs humain signal spectre) ; §3.4 (comptes intra-tier).*
*1 litige clos recommandé : #Z (IA formulation distincte). 1 litige neuf : #BB (Daily ranked vs unranked).*
