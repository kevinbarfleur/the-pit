# R07 — Critique adversariale, lentille RELIQUES (round 7/10)

> **Round** : 7/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cible principale** : `ROADMAP-draft.md` (brouillon #7, integre round 6) + `round-06.md` +
> `rounds/r06-relics.md`. **Sources internes lues ce round** : `src/data/relics.lua` (integrale,
> relu ce round) ; `00-state.md` ; `ROADMAP-draft.md §4` (P1.5a, 21 reliques) ; `§5.2` (twists
> de palier de type) ; `BRIEF.md` ; `round-06.md §1-3` ; `r06-relics.md`.
> **Garde-fou absolu** : lecture seule du repo de jeu. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.

---

## 0. TL;DR — challenge cle (3 phrases)

Six rounds de critique ont resolu les problemes de lecture de code (`plague_communion`,
`feeding_frenzy`, `famines_math`), identifie les arcs temporels manquants et les dead picks
(`hollow_choir`, `sacred_shield`). **Mais le brouillon #7 ne tranche toujours pas la question
la plus fondamentale du systeme de reliques : la densite de VRAIES DECISIONS dans l'offre
1-parmi-3 est inconnue et potentiellement insuffisante — sur 21 reliques, 3 F sont
deprioritisees, 1 est pool-A, 1 est quasi-inerte, 4 B sont [PH-DEPENDANT] : il reste
potentiellement 12 reliques de valeur etablie sur 21, soit ~57 %, mais la composition des
3 offres simultanees par tier n'est jamais analysee comme un systeme de decisions au sens de
Keith Burgun (couplage trop lache = choix arbitraire, trop fort = choix evident).** Deuxieme
challenge : le brouillon positionne les reliques E transformatives (forked_tongue, everburn,
open_wounds, plague_communion) comme des "payoffs-late" tier-4, mais aucune d'elles ne
DEFINIT un archetype dans le sens ou une unite rang-3 le fait — elles augmentent un
archetype existant, elles ne le creen pas ; cette distinction a un impact direct sur le
moment d'acquisition optimal et sur la question de si le systeme de reliques peut porter seul
l'identite de build ou s'il doit etre subordonne aux synergies par TYPE (P1).

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes)

### 1.1 ACCORD FORT — Deprioritisation F + garantie de pertinence B-E (§4.6 + §4.1)

**Ce que le brouillon acte** : les 3 reliques F (`carrion_ledger`/`black_summons`/`beggars_lantern`)
sont deprioritisees dans le pool (remplacees par un B-E si disponible) ; la garantie de
pertinence verifie que si une B-E est dans les 3 offres, sa famille-cible est presente dans la
compo du joueur.

**Pourquoi ca tient pour NOS contraintes** : l'argument de contamination de pool est solide et
specifique a notre architecture. Dans notre systeme, l'offre 1-parmi-3 arrive tous les 3 combats
(invariant du run) et represente la seule recompense de build — pas de chemin sur une carte, pas
de coffre alternatif comme dans StS (slaythespire.wiki.gg/wiki/Map_Generation). Contaminer une
offre sur 4 avec une decision de niveau "economie de run" (les F) quand le joueur est en mode
"composition de combat" cree une charge cognitive heterogene confirmee par la theorie de la
charge cognitive (Sweller 1988, cite dans Wayline.io/blog/roguelike-itemization-balancing-
randomness-player-agency : "mixing decision layers in a single interface creates cognitive
dissonance that reduces engagement"). **En async, le joueur n'a aucun feedback live pour
corriger ; une offre mal cadree a 6 wins (pic de tension) = un round de progression gache
sans possibilite de rattrapage.**

La dependance causale `rollRelicChoices(n)` → `rollRelicChoices(n, compo)` implique une
modification de l'invariant #3 qui doit etre specifiee AVANT le code — le brouillon le note
correctement.

**Source** : `src/data/relics.lua:69-73` (R.order, 3 F confirmes) ; `src/run/state.lua:339`
(signature actuelle sans compo) ; Wayline.io/blog/roguelike-itemization (charge cognitive) ;
slaythespire.wiki.gg/wiki/Map_Generation (canaux paralleles de recompense StS).

### 1.2 ACCORD FORT — Arc temporel ≥1 shaper-mid + ≥1 payoff-late par archetype (§4.8)

**Ce que le brouillon acte** : le critere ≥2/archetype brut est insuffisant ; le tableau de
couverture identifie rot (pas de payoff-late), choc (pas de shaper-mid), wide (rien) comme
des arcs incomplets a combler en P1.5b.

**Pourquoi ca tient** : l'argument de cadence de renforcement est specifiquement valide en
async. Dans TFT (bunnymuffins.lol/augment-guide-for-set-13), les augments de mid-2 et mid-4
(equivalents de nos shapers-mid) arrivent avant que le joueur soit "locked in" sur un
archetype — le joueur peut encore pivoter. Dans The Pit, en async, le joueur ne sait pas
quel ghost il affrontera au round 8 ; s'il n'a pas de payoff-late pour son archetype et que
le snapshot adverse en a un, l'ecart de puissance est invisible jusqu'a la defaite. Le shaper-
mid permet au joueur de **valider son pari** sur l'archetype avant d'etre trop engage.

L'absence de payoff-late pour rot est particulierement critique : rot est positionne comme le
counter des tanks (amputation HP max, cf. 00-state §3.1 colonne I), mais sans relique late qui
amplifie ce counter, le build rot devient strategiquement inferieur aux builds qui ont un bonus
de commit au tier-4. C'est un "plafond de verre" d'archetype.

**Source** : bunnymuffins.lol/augment-guide-for-set-13 (augments directionnels timing) ;
`00-state.md §2.2` (gating early/mid/late) ; `src/data/relics.lua:25-67` (tiers confirmes).

### 1.3 ACCORD — #O CLOS : `famines_math` option (a) "3 plus couteuses" (§4.5)

**Pourquoi ca tient** : le conflit anti-progression est reel et code-ancre. L'option (a)
preserve l'identite "tall" (peu d'unites fortes) sans creer une friction permanente avec les
SLOT_GRANT_ROUNDS automatiques. La modification `R.apply` (tri par cout) est minimale et la
spec est correcte. **Un point a confirmer : le tri doit etre STABLE** (deux unites de meme
cout doivent rester dans leur ordre original) — `table.sort` en Lua n'est pas stable
(reference : lua.org/manual/5.1/manual.html#5.5). Si deux unites rang-3 sont presentes, le
tri instable peut produire des resultats differents selon l'ordre d'insertion → **le tri doit
etre secondairement par `id` (alphabetique) pour garantir le determinisme exige par
l'invariant #2**. C'est une ligne de code supplementaire dans la spec.

**Source** : `src/data/relics.lua:34-35` (famines_math code) ; `src/run/state.lua:50`
(SLOT_GRANT_ROUNDS) ; lua.org/manual/5.1/manual.html#5.5 (table.sort non-stable).

### 1.4 ACCORD — `sacred_shield` quasi-inerte, valeur [PH] a regler (§4.9)

**Code-verifie en round 6 par le synthetiseur** : `invulnT=30` = 30 ticks = 0,5 s = quasi-
nul (2,9 % du combat). Cible 60-120 ticks. Ce n'est pas un bug de signe, c'est une valeur
a regler. L'accord est direct.

**Nuance non mentionnee** : a 120 ticks (2 s), les unites de cooldown court (rang-1, cd≈180-
240 ticks) auront eu le temps de s'approcher de leur premier coup mais pas encore frappe.
L'invulnerabilite a 120 ticks bloquerait le premier hit de chaque unite adverse — **c'est
un avantage lisible et visible, pas juste quelques ticks de DoT**. La cible 60-120 ticks est
correcte. La **valeur haute (120)** est recommandee pour que le signal soit percu comme une
relique defensive reelle et non un buff symbolique.

**Source** : `src/data/relics.lua:45-46` ; `src/combat/arena.lua:247, 58` (verifie
round 6) ; `00-state.md §3.2` (FATIGUE_START=1020 ticks, ~17 s).

### 1.5 ACCORD — `hollow_choir` pool-A (counter d'un archetype inexistant) (§4.10)

**Pourquoi ca tient** : la logique est identique aux boucliers passifs (§3.1 col H) : une
relique qui counter un archetype absent du roster est du bruit, pas un egalisateur. Le pool-A
est la bonne decision provisoire. L'option de reorientation en `pierceShield` est
interessante mais correctement differee a P1.5b (dependance de la colonne I de l'audit).

**Nuance** : si `hollow_choir` est reorientee en `pierceShield`, son tier-3 est bien calibre
pour un counter-bouclier LEGER (non dominant) — mais il faut verifier que `pierceShield` n'est
pas un doublon fonctionnel avec le twist bleed-4 `bleedPierceShield` (§5.2). Les deux
reducent les boucliers mais par des mecanismes differents (un flat, l'autre par tick) — ce
n'est pas un doublon si les niveaux d'activation et de magnitude different significativement.
A croiser avec la colonne F de l'audit (§3.1).

**Source** : `src/data/relics.lua:37-38` ; `00-state.md §2.1` (regen=1 unite) ; §5.2
(bleedPierceShield specifie, ROADMAP-draft §5.2).

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — La qualite de decision de l'offre 1-parmi-3 n'est JAMAIS mesuree ni meme specifiee comme objectif

**Claim implicite du brouillon** : la garantie de pertinence (§4.1) + la deprio des F (§4.6)
+ l'arc temporel (§4.8) = un systeme de reliques qui offre des decisions significatives.

**Pourquoi c'est insuffisant** : ces trois mesures corrigent des problemes de CONTENU du pool
(mauvaises reliques proposees), pas la QUALITE DE DECISION de l'offre. La difference est
fondamentale.

Keith Burgun (keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity, verifie) :
"When powers offered in a 'pick 1 of 3' choice are loosely coupled, the decision will be
random/arbitrary and not interesting. When powers are highly coupled with no restrictions on
picking, the choice is obvious and not interesting either." L'analyse s'applique directement
a notre systeme :

**Cas 1 — couplage trop lache (offre incoherente)** : un joueur build poison voit `aegis`
(defense plate, +15 % dmg reduit) + `ember_heart` (burn +30 %) + `forked_tongue` (choc).
Les trois sont "pertinentes" au sens du brouillon (aegis = A, donc libre ; ember_heart =
famille non presente mais legale ; forked_tongue = tier-4). Aucune ne cible son build.
Resultat : la garantie de pertinence est satisfaite formellement mais l'offre n'a AUCUNE
tension de decision. Le joueur prend `aegis` par defaut et passe a autre chose.

**Cas 2 — couplage trop fort (offre triviale)** : un joueur build poison au round 7 (4+ wins)
voit `kings_bowl` (poison +20 %) + `plague_communion` (multi-affliction +25 % ) + `second_breath`
(survie). Si son build est mono-poison etabli, `kings_bowl` est dominante par defaut →
decision triviale. La garantie de pertinence a genere une offre trop evidente.

**La metrique manquante** : le brouillon vise une "decision de build" mais ne specifie jamais :
(a) combien d'offres 1-parmi-3 ont exactement 1 option dominante (triviales) vs exactement 0
(arbitraires) vs 2-3 options en tension reelle ? ; (b) est-ce que la distribution est
acceptable ? La reponse n'est pas dans le brouillon.

**Proposition** : ajouter une METRIQUE DE QUALITE D'OFFRE a la matrice sim P0.5 — pour N
builds (seed fixe) a chaque round d'offre : calculer le `lift` (co-occurrence win-rate) de la
relique choisie vs les 2 non-choisies sur 50 combats suivants. **Si lift(choisie) > 2 × max(lift
des non-choisies) sur > 60 % des offres → decision triviale trop souvent.** Cible : < 40 %
d'offres triviales (au moins 2 reliques viables par offre). C'est une extension de ~10 lignes
sur `tools/sim.lua` qui produit deja des metriques de co-occurrence.

**Source** : keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity (couplage et
decision quality) ; `tools/sim.lua` (lift de co-occurrence deja code, ROADMAP-draft §0 diff 5
"lift de co-occurrence detceur de combos casses") ; Wayline.io/blog/roguelike-itemization
("pool should support alternative lines where everything works well together, but between
clusters some overlaps and conflicts exist") ; `00-state.md §2.2` (pool 21 reliques, gating).

### 2.2 DESACCORD — Les reliques E (transformatives) tier-4 ne sont pas "build-defining" au sens strict : elles amplifient sans creer l'identite

**Claim du brouillon** (§4.7-4.8) : les reliques E (`forked_tongue`, `everburn`, `open_wounds`,
`plague_communion`) sont des "payoffs-late tier-4" qui "couronnent un commit" — analogues aux
boss relics de StS qui definissent le build.

**Pourquoi cette analogie est paresseuse** : les boss relics de StS (slaythespire.wiki.gg/wiki/
Relics, verifie : cf. competitive/slay-the-spire.md §2.1) ont un DOWNSIDE explicite qui
FORCE la construction autour d'elles — Ectoplasm (+1 energie, plus d'or) oblige un deck
autonome ; Fusion Hammer (+1 energie, pas de forge) oriente vers un deck final. **Le downside
elimine des options et concentre l'identite** (Giovannetti gamedeveloper.com 2018 : "Since
we are a single player card game, we don't have to worry about opponents — the downside
functions as a forced theming").

Nos reliques E n'ont aucun downside (principe §2 relics-design.md : "aucune relique ne
handicape"). Elles amplifient un archetype EXISTANT sans le redefinir. Le joueur build burn
qui obtient `everburn` (burn ne decroit plus) n'est pas force de changer son build — il
amplifie juste son burn actuel. La decision est : "est-ce que ca aide mon build actuel ?" →
presque toujours oui si le joueur est en burn. C'est un **palier de commit, pas un
definisseur d'archetype**.

**La consequence concreto** : dans le systeme actuel, les reliques E sont des "upgrades de
qualite" au lieu de "pivots de direction" — ce qui est coherent avec le principe "pas de
downside" mais REDUIT la tension de la decision. Un joueur qui hesite entre `everburn` et
`plague_communion` en possedant un build burn doit evaluer : "est-ce que je veux aller en
mono-burn ou diversifier mes familles ?" C'est une bonne decision — mais elle n'existe que
si le joueur a DEJA les familles en question.

**Ce qui est faux dans le brouillon** : qualifier les reliques E de "build-defining" identiques
aux boss relics StS. La vraie analogie StS serait les reliques RARES non-boss (Dead Branch,
Philosopher's Stone) qui amplifient un axe sans forcer un pivot — soit le tier "commun/rare"
de StS, pas le tier boss. La decision de prendre un `everburn` ressemble davantage a
"prendre un Frozen Egg (StS, amplification d'un type de carte)" qu'a "prendre Fusion Hammer
(StS, changement de strategie fondamentale)".

**Ce n'est pas necessairement un probleme** : si le systeme de TYPES (P1) fournit les vrais
pivots (s'engager dans burn vs bleed vs poison = vraie decision d'identite early), les
reliques E peuvent legimitement jouer le role d'amplificateurs late. Mais la roadmap doit
RECONNAITRE cette position et ne pas presenter les E comme "build-defining" au meme sens
que StS — sinon P1 (types) est une duplication fonctionnelle de ce que les E sont censes
faire, ce qui cree une ambiguite de design.

**Proposition** : clarifier la position des reliques E dans le doc : "payoff-late = AMPLIFICATEUR
d'archetype etabli (pas CREATEUR)" ; les types P1 = "CREATEURS d'identite (paliers 2 et 4) " ;
les reliques E = "couronne du commit au-dela des types". Cela implique que les types P1 doivent
etre implementes AVANT que les reliques E soient considerees "correctement soutenues" — ce
qui est deja l'ordre prevu mais dont la logique n'est pas explicitement formulee dans le brouillon.

**Source** : slaythespire.wiki.gg/wiki/Relics (boss relics avec downside, confirme) ;
competitive/slay-the-spire.md §2.2 (psychologie du downside) ; Giovannetti gamedeveloper.com
2018 (forced theming) ; relics-design.md §1 (principe #2 : pas de downside) ; `src/data/
relics.lua:51-58` (les 4 E, relu).

### 2.3 DESACCORD PARTIEL — La categorie A (stats plates) est trop presente et risque de dominer les offres early par defaut

**Situation actuelle** : 4 reliques A (`bloodstone`, `carapace`, `aegis`, `whetstone`) + la
garantie de pertinence ne s'applique PAS aux A (§4.1 : "les A sont offertes librement").
4 A sur 21 reliques = ~19 % du pool. Au tier-1 (early, wins=0-1), seules les reliques tier≤2
sont eligibles : 3 A (tier=1 : bloodstone, carapace, whetstone) + 4 B (tier=2). **7 reliques
eligibles en early.** Une offre de 3 = combinaison de 3 parmi 7, soit C(7,3)=35 combinaisons
possibles. Si 3 A + 4 B et la garantie B-E ne s'applique pas aux A, une offre tout-A (3 A
sur 3) est possible, avec probabilite approximative C(3,3)/C(7,3) = 1/35 ≈ 2.9 %. Marginal
mais non nul.

**Probleme plus profond** : les A sont des buffs plats universels (pas de type-cible) qui
TOUJOURS aident. En early (wins=0-1), le joueur n'a pas encore etabli son archetype —
`bloodstone` (+14 % dmg) est presque toujours bon, `aegis` (-15 % dgts subis) aussi. Si la
garantie de pertinence ne s'applique pas aux A, une offre A+B ou meme A+A+B en early peut
mener le joueur a PRENDRE LE A PAR DEFAUT (toujours utile, archetype pas encore defini)
et IGNORER le B qui orienterait son build.

**Ce qui est faux dans le brouillon** : presenter la garantie de pertinence comme suffisante
pour assurer la qualite de decision early. Un B de burn en early n'est pas "pertinent" si
le joueur n'a pas encore decide de jouer burn — la garantie verifie la PRESENCE de la
famille sur le plateau (au moins une unite burn), mais un plateau de 3 unites early peut
avoir 1 burn, 1 bleed, 1 poison → la garantie est satisfaite pour les 3 familles
simultanement → l'offre propose un B arbitraire qui n'oriente pas vraiment.

**Preuve de la tension** : en early (plateau 3 slots, T1), la famille "majoritaire" est
souvent 1/3 ou 2/3 — pas encore etablie. Offrir `ember_heart` (burn B) quand le joueur a
1 burn + 1 bleed + 1 poison ne l'ORIENTE pas vers burn, ca CONFIRME son axe burn actuel a
33 %. La garantie de pertinence "vide" les B de leur pouvoir de shaper en early exactement
quand ils en ont le plus besoin (keithburgun.net ibid. : "orientation requires the player
to have something to lose by not committing" — et en early, rien n'est perdu par ne pas
committer).

**Proposition** (nuancee, pas un changement de systeme) : dans la garantie de pertinence,
pour les rounds ≤ 3 wins, ajouter une condition "si la famille B proposee est ≥ 50 % de
la compo OU si le joueur a deja achete cette famille au moins 2 fois" pour qualifier le B
comme pertinent. Cela empeche que la garantie soit satisfaite trivialement en early. C'est
une condition data-only dans `rollRelicChoices`. Livrable P1.5a, pas P0.5 (non bloquant).

**Source** : keithburgun.net/pick-1-of-3 (l'orientation require un cout d'opportunite) ;
`00-state.md §4.3` (cotes T1=100 % rang-1, le joueur voit peu d'unites diverses en early) ;
ROADMAP-draft §4.1 (garantie de pertinence, limite actuelle : "au round ≤4, plateau = rang-1
de la famille commune → la garantie confirme le 1er axe", drapeau Q4 deja ouvert mais non
resolu).

### 2.4 DESACCORD — `forked_tongue` reste fonctionnellement indefinie meme apres le gating conditionnel

**Claim du brouillon** (§4.7, note de fin) : `forked_tongue` ("le choc rebondit sur 1 ennemi")
reste "fonctionnellement indefinie jusqu'a la resolution de #G (axe D)" — puis "la
reformulation de forked_tongue est la PREMIERE tache de P1.5a des que #G est tranche en P0.5".

**Pourquoi cette dependance est mal specifiee** : `forked_tongue` pose `shockChain=1` via
`grant_team` (`relics.lua:51-52`). La roadmap dit que si "axe D = decharge sur tick DoT",
le "rebond" = "propagation d'ampli DoT, pas rebond electrique". Mais `shockChain` est LU
par quoi exactement dans `arena.lua` ? Si `shockChain` n'est pas encore lu par une op
dans le code (la recherche du round 6 ne mentionne pas de grep confirmatif de `shockChain`
comme lu), alors `forked_tongue` est une relique tier-4 qui pose un flag sans effet —
non pas un bug, mais un placeholder non documente comme tel.

**Ce que le brouillon ne dit pas** : si `shockChain=1` est deja lu quelque part dans le
code (meme comme stub), ou si c'est un flag en attente d'une op a creer. La distinction
est importante : si c'est un stub, `forked_tongue` est silencieuse en jeu et son gating
conditionnel (minBuiltChoc) est du code mort. Si ce n'est pas lu du tout, c'est une
relique brisee en production.

**Proposition** : avant P1.5a, grep `shockChain` dans `arena.lua` (lecture seule) pour
confirmer si le flag est consomme. Si non : noter `forked_tongue` comme "tier-4 inerte
jusqu'a P0.5/P1.5a (shockChain non implementee)" dans le tableau de tuning P3. Si oui :
documenter ou et comment. Cette verification est ~2 minutes de grep, pas un chantier.

**Source** : `src/data/relics.lua:51-52` (`shockChain=1`) ; ROADMAP-draft §4.7 (note de
fin) ; 00-state §8 "zones sans garde-fou de test" — le comportement de `forked_tongue` en
combat n'est pas couvert par un test.

### 2.5 DESACCORD PARTIEL — Le "tableau de saturation d'inc" (§5.2) est necessaire mais son applicabilite aux reliques B est sous-estimee pour bleed et rot

**Claim du brouillon** (§5.2 garde-fou twist #3) : produire un tableau de saturation par
famille avant de specifier les paliers de type. Accord sur le principe (adopte de r06-relics
§2.2). Mais le tableau propose en r06-relics §3/Prop-B montre que bleed et rot ont des
marges tres larges (bleed : seuil inc sature = 500 %, marge = 462 % avant saturation) —
ce qui risque de creer une fausse impression de "marge de manoeuvre illimitee" pour ces
familles.

**Ce qui est sous-estime** : bleed a `BLEED_DPS_CAP=12` (`ops.lua:28`) comme cap ABSOLU
(pas un multiplicateur de base). Si `base_dps` d'un bleed rang-2 est 2, le cap est 12 →
le joueur peut empiler `weeping_nail` (0.18) + palier-2 (0.20) + aura (0.20 hypothetique)
= 0.58 d'inc → tick = 2 × (1 + 0.58) = 3.16 par tick, loin du cap de 12. OK.
Mais si le bleed T3 a `dps=6` (comme `razor_fiend` selon `units.lua` non relu ce round),
alors tick = 6 × 1.58 = 9.48, proche du cap 12. **Le seuil de saturation est DIFFERENT
selon le rang de l'unite**, pas seulement selon la famille. Le tableau par famille masque
cette heterogeneite intra-famille.

**Proposition** : le tableau de saturation doit specifier le seuil PAR RANG, pas seulement
par famille. Pour bleed : rang-2 (dps=2) : cap=12 → seuil = (12/2)-1 = 500 % (marge enorme) ;
rang-3 (dps=6, supposons) : cap=12 → seuil = (12/6)-1 = 100 % (marge: si inc naturel=0.58,
reste = 42 % avant saturation — beaucoup plus serre). Les valeurs concretes
dependent des stats relues dans `units.lua` — mais la structure du tableau doit prevoir
cette granularite. 5 lignes supplementaires dans le tableau de saturation, 0 code, 0 invariant.

**Source** : `src/effects/ops.lua:28` (BLEED_DPS_CAP=12, fixe) ; `src/effects/ops.lua:22`
(DOT_CAP_MULT=3, multiplicatif) ; r06-relics.md §2.2/Prop-B (tableau propose).

---

## 3. Propositions priorisees

### Prop-A — METRIQUE DE QUALITE D'OFFRE : mesurer la densite de decisions reelles dans le 1-parmi-3 (PRIORITE 1, sim ~10 lignes)

**Quoi** : etendre `tools/sim.lua` avec une metrique `offer_decision_quality` :
- Pour N=200 runs (seeds aleatoires, meme seed que les metriques existantes), a chaque
  offre de relique (tous les 3 combats, ~4 offres/run), calculer le `lift` de win-rate
  de chaque relique de l'offre sur les 10 combats suivants (deja dans le code de `lift`
  de co-occurrence).
- **Proportion d'offres "triviales"** = lift(1re relique) > 2 × max(lift des 2 autres).
- **Proportion d'offres "arbitraires"** = std_dev(lift des 3) < 0.02 (pas de difference
  significative entre les 3).
- **Cible** : < 40 % triviales + < 20 % arbitraires = > 40 % d'offres avec 2-3 options
  en tension reelle.

**Coût** : ~10 lignes sim. 0 invariant. Prerequis : P0.5 (dot_family pour les B). A faire
en meme temps que CONFIG-PC (§3.9 ROADMAP-draft).

**Pourquoi P0.5 et pas P3** : si la qualite d'offre est faible (< 40 % de decisions reelles),
P1 (types) peut la degrader encore (les paliers de type rendent les reliques B de la meme
famille encore plus triviales). Connaitre la baseline AVANT P1 permet de specifier les twists
pour qu'ils diversifient les decisions, pas les homogeneisent.

**Source** : keithburgun.net/pick-1-of-3 (decision quality theory) ; `tools/sim.lua` (lift
co-occurrence existe, cf. ROADMAP-draft §0 diff 5) ; ROADMAP-draft §3.9 (matrice sim existante,
CONFIG-PC, s'y insere naturellement).

### Prop-B — CLARIFIER la position des reliques E (amplificateurs, pas createurs) dans la hierarchie build-definition (PRIORITE 2, doc ~10 lignes)

**Quoi** : ajouter dans §4 P1.5a une section "Position des reliques dans la hierarchie de
build-definition" :
- **Types P1 = CREATEURS d'identite** (paliers 2 et 4, oriente le build sur 5-9 rounds).
- **Reliques B = SHAPERS** (inc par famille, confirme et amplifie l'axe engage).
- **Reliques E = COURONNEURS de commit** (transforment une regle, payoff du commit total).
- **Reliques A = FONDATIONS** universelles (pas de vote sur l'identite).

Cette hierarchie rend explicite que : (a) les reliques E SEULES ne definissent pas l'identite
d'un run, elles la COMPLETENT ; (b) P1 (types) est la couche qui fait les vraies decisions
de direction ; (c) les reliques E sont correctement positionnees en tier-4 (post-commit).

**Cout** : ~10 lignes de doc. 0 code. 0 invariant. A integrer dans le ticket P1.5a.

**Source** : slaythespire.wiki.gg (boss relics vs rares — distinction createur/amplificateur) ;
competitive/slay-the-spire.md §2.2 ; Giovannetti gamedeveloper.com 2018 (forced theming = le
downside cree l'identite).

### Prop-C — GARANTIE DE PERTINENCE RENFORCEE pour les rounds ≤3 wins : condition de majorite ou d'historique d'achat (PRIORITE 3, doc + ~3 lignes code)

**Quoi** : dans `rollRelicChoices(n, compo)` (§4.1), ajouter une condition supplementaire pour
les rounds early (wins ≤ 3) : un B est qualifie comme "pertinent" seulement si sa famille
represente ≥ 50 % de la compo OU si le joueur a achete ≥ 2 unites de cette famille (info
disponible depuis la compo au build). Sinon, le B est traite comme un A (offert librement,
sans garantie). Cela empeche la garantie d'etre satisfaite trivialement par un B de la
famille "minoritaire" en early.

**Cout** : ~3 lignes dans `rollRelicChoices`. 1 modification de la condition de pertinence.
Test #3 a adapter AVANT le code (invariant #3 reformule).

**A noter** : cette proposition est de PRIORITE 3 (non bloquante). La garantie actuelle
est meilleure que pas de garantie. Cette amelioration peut attendre P1.5a.

**Source** : keithburgun.net/pick-1-of-3 ("orientation requires commitment") ; ROADMAP-draft
§4.1 (risque degenere Q4, deja ouvert) ; `00-state.md §4.3` (cotes T1 = 100 % rang-1 → peu
de diversite early).

### Prop-D — GREP `shockChain` dans `arena.lua` avant de finaliser le gating conditionnel de `forked_tongue` (PRIORITE 2, verification ~2 min)

**Quoi** : grep `shockChain` dans `src/combat/arena.lua` (lecture seule). Resultat :
- **Si trouve** : documenter ou le flag est consomme + preciser que `forked_tongue` est
  "partiellement fonctionnelle" (le rebond existe) → le gating conditionnel (§4.7) est
  justifie.
- **Si non trouve** : noter `forked_tongue` comme "relique tier-4 silencieuse (shockChain
  non implementee)" dans le tableau de tuning P3 + ajouter a la "zone sans garde-fou de
  test" (00-state §8).

**Cout** : grep ~2 min. Doc ~3 lignes. 0 code, 0 invariant. Prerequis naturel de P1.5a.

**Source** : `src/data/relics.lua:51-52` ; 00-state §8 (zones sans test) ; ROADMAP-draft §4.7
(dependance non resolue).

### Prop-E — TABLEAU DE SATURATION PAR RANG (pas seulement par famille) pour bleed et les familles a cap fixe (PRIORITE 2, doc ~5 lignes supplementaires)

**Quoi** : etendre le tableau de saturation (§5.2 precondition P1) avec une colonne "rang-3
representatif" en plus du "rang-2 median", specifiquement pour bleed (cap fixe `BLEED_DPS_CAP=12`)
et toute famille dont le cap ne scale pas lineairement avec la base. Cela revele les points
de saturation differents selon le rang de l'unite la plus forte du build.

**Cout** : ~5 lignes dans le tableau de saturation existant (§5.2). Lire `dps` des unites
bleed rang-3 dans `units.lua` (reunion des valeurs au build). 0 code, 0 invariant.

**Source** : `src/effects/ops.lua:28` (BLEED_DPS_CAP=12, fixe) ; r06-relics §2.2/Prop-B
(tableau propose, structure a etendre).

---

## 4. Questions ouvertes

### Q1 — Quelle est la proportion reelle d'offres "triviales" dans le pool actuel (pre-P1) ?

La metrique `offer_decision_quality` (Prop-A) doit etre executee sur le pool actuel (21
reliques, pre-P1) pour obtenir une baseline. Si la proportion de decisions triviales est
deja < 40 %, P1 (types) peut etre specifie normalement. Si > 60 %, les types doivent etre
concus pour DIVERSIFIER les decisions reliques, pas seulement amplifier. La reponse change
les contraintes de specification de P1.

### Q2 — `forked_tongue` est-elle silencieuse en jeu actuellement ?

Si `shockChain=1` n'est pas consomme dans `arena.lua`, les joueurs qui obtiennent
`forked_tongue` ont une relique tier-4 sans effet. Dans le pool async (snapshots servent
des builds avec des reliques), c'est une asymetrie de valeur invisible — un ghost qui a
`forked_tongue` n'a PAS un avantage reel si la relique est silencieuse. Le joueur adverse
qui l'a ne le sait pas. Dans un systeme async, les reliques silencieuses contaminent la
perception du pool (le joueur croit que son adversaire avait un avantage reel inexistant).
→ A verifier AVANT P0.5.

### Q3 — Est-ce que la hierarchie "B = shaper, E = amplificateur" tient apres les types P1 ?

Avec les types P1, un palier-4 burn (`burnIgnoreShield`) est fonctionnellement similaire
a `everburn` (tous deux transforment une regle de burn). La difference : le palier est active
par le NOMBRE d'unites, la relique est activee par la POSSESSION de la relique. Si le joueur
a le palier-4 burn ET `everburn`, il a deux modificateurs de regle burn → est-ce que ca
cree de la profondeur (combo) ou de la redondance (double-buff) ? Cette question doit etre
explicitement resolue dans la spec P1 avant de coder les twists.

### Q4 — Le systeme de reliques peut-il porter seul l'identite de build en l'absence de types P1, ou est-il structurellement dependant de P1 pour creer des decisions de direction ?

La question est : si P1 est retarde, est-ce que les reliques actuelles (21 reliques, les B en
particulier) suffisent a creer 3-4 identites de run distinctes dans un run de 10 victoires ?
La reponse est probablement non (les B sont des amplificateurs, pas des createurs) — ce qui
signifie que les reliques SEULES ne sont pas un systeme de build-defining suffisant, et que
P1 est un prerequis de fun, pas juste une amelioration de contenu.

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| Pick 1 of 3 = couplage et qualite de decision | keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity (verifie ce round) |
| Itemisation et charge cognitive mixte | Wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency (verifie) |
| Boss relics StS avec downside (Ectoplasm, Fusion Hammer) | slaythespire.wiki.gg/wiki/Relics (verifie) ; competitive/slay-the-spire.md §2.1 |
| Forced theming par downside (Giovannetti 2018) | gamedeveloper.com/design/how-i-slay-the-spire (cite dans competitive/slay-the-spire.md) |
| table.sort non stable en Lua | lua.org/manual/5.1/manual.html#5.5 |
| BLEED_DPS_CAP=12 (cap fixe, distingue de DOT_CAP_MULT) | `src/effects/ops.lua:28` |
| DOT_CAP_MULT=3 (multiplicatif) | `src/effects/ops.lua:22` |
| hollow_choir : pierceHeal=0.40, tier-3 | `src/data/relics.lua:37-38` (relu ce round) |
| forked_tongue : shockChain=1, tier-4 | `src/data/relics.lua:51-52` (relu ce round) |
| famines_math : relic_few_units max=3 | `src/data/relics.lua:34-35, 90-94` (relu ce round) |
| sacred_shield : invulnT=30 @ 60 fps | `src/data/relics.lua:45-46` + `arena.lua:58,247` (verifie round 6) |
| plague_communion : plagueAmp=0.25 more hors-cap | `src/data/relics.lua:57-58` + `arena.lua:252` (verifie round 4) |
| R.order : 21 reliques, 3 F en positions 19-21 | `src/data/relics.lua:69-73` (relu ce round) |
| Gating early/mid/late par wins | `00-state.md §2.2` ; `src/run/state.lua:339` |
| table.sort non-stable = non-deterministe | lua.org/manual/5.1/manual.html#5.5 |
| lift co-occurrence existant dans sim | ROADMAP-draft §0 diff 5 (lift implementé, confirme) |
| TFT augments directionnels timing | bunnymuffins.lol/augment-guide-for-set-13 (cite dans round-06.md) |
| Zones sans test (forked_tongue) | `00-state.md §8` |
| Principe "pas de downside" reliques | `docs/research/relics-design.md §1, principe #2` |

---

## Synthese round 7 (pour le synthetiseur)

Le systeme de reliques a resolu ses problemes techniques (plague_communion sim, famines_math,
hollow_choir, sacred_shield, arcs temporels). **Le challenge non resolu de round 7 porte sur
trois axes** : (1) la QUALITE DE DECISION de l'offre 1-parmi-3 n'est pas mesuree (Prop-A,
sim bloquante en P0.5) ; (2) la POSITION des reliques E dans la hierarchie "createurs vs
amplificateurs" est mal formulee — les E ne sont pas "build-defining" au sens StS, ce qui
a des consequences sur la priorite de P1 types (clarification doc, Prop-B) ; (3) un bug
de DETERMINISME est possible dans la spec de famines_math (table.sort instable sur egalite
de cout — 1 ligne de code supplementaire dans la spec, non-negociable).

---

*Redige le 2026-06-23 par l'agent lentille-reliques, round 7/10. Lecture seule du repo. N'edite
que sous `docs/roadmap-lab/`. Piliers respectes : async snapshots / sim deterministe seedee / DA
grimdark / pixel art procedural. Sources citees par URL ou fichier+ligne. Rounds lus : r01 a
r06-relics.md, round-01.md a round-06.md, ROADMAP-draft.md (#7), 00-state.md, BRIEF.md,
relics.lua (relu integrale ce round), relics-design.md, competitive/slay-the-spire.md.*

Sources web consultees ce round :
- [Pick 1 of 3 is a missed game design opportunity (Keith Burgun)](http://keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity/)
- [Roguelike Itemization: Balancing Randomness and Player Agency (Wayline)](https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency)
- [Augments Augmented — TFT design philosophy (Riot)](https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/augments-augmented/)
- [Slay the Spire Relics Wiki](https://slaythespire.wiki.gg/wiki/Relics)
- [GDC 2019 Slay the Spire balance (gamedeveloper.com)](https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder)
- [Designing for Mastery in Roguelikes (Grid Sage Games 2025)](https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/)
- [Lua 5.1 manual — table.sort](https://www.lua.org/manual/5.1/manual.html#5.5)
- [TFT Augment Guide Set 13 (BunnyMuffins)](https://bunnymuffins.lol/augment-guide-for-set-13/)
