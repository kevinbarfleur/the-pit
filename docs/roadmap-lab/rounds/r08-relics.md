# R08 — Critique adversariale, lentille RELIQUES (round 8/10)

> **Round** : 8/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Sources internes lues ce round** : `src/data/relics.lua` (integrale) ; `00-state.md` ;
> `ROADMAP-draft.md` (brouillon v8, post-round-7) ; `round-07.md` ; `rounds/r07-relics.md` ;
> `docs/research/relics-design.md` ; `competitive/slay-the-spire.md`.
> **Sources web recherchees ce round** : keithburgun.net/pick-1-of-3, wayline.io/blog/roguelike-
> itemization, slaythespire.wiki.gg, switchbladegaming.com, Medium/@JeongHyeonUk, balatrogame
> .fandom.com, grokipedia.com (shared vs local pool), superautopets.wiki.gg.
> **Garde-fou absolu** : lecture seule du repo de jeu. Ce fichier n'edite que
> `docs/roadmap-lab/`. Piliers : async snapshots / sim deterministe seedee / DA grimdark /
> pixel art procedural.

---

## 0. TL;DR — challenge cle (3 phrases)

Le brouillon v8 a resolu les bugs techniques (famines_math, forked_tongue, sacred_shield,
hollow_choir) et a correctement positionne la hierarchie CREATEURS/SHAPERS/COURONNEURS (§4.11).
**Mais il reste deux trous structurels non adresses : (1) la metrique `offer_decision_quality`
est specifiee sans que son interpretation ne soit calibree sur le contexte d'un pool LOCAL a 21
reliques — le seuil « 40 % triviales » peut etre inatteignable ou trop permissif selon la
composition des tiers d'offre, et le brouillon ne distingue pas la trivialite structurelle
(imposee par l'architecture du pool) de la trivialite tunable (corrigeable par les valeurs de
lift) ; (2) aucune relique n'agit comme un SIGNAL D'ENGAGEMENT PRECOCE qui force ou confirme
un pivot vers un archetype dans les 3 premiers rounds — les B sont des amplificateurs post-
engagement, les A sont universels, les C/D/E sont tier-3/4 : en early (plateau 3 slots), le
joueur n'a aucun signal relique qui rende son choix d'archetype IRREVERSIBLE, et c'est
precisement ce cout d'irreversibilite qui donne du poids a la decision (Burgun 2021 ; Wayline
2025).**

---

## 1. Accords — ce qui tient, avec le POURQUOI pour nos contraintes

### 1.1 ACCORD FORT — Hierarchie CREATEURS/SHAPERS/COURONNEURS actee (§4.11)

**Ce que le brouillon acte (round-07.md §1.7 + ROADMAP §4.11)** : Types P1 = CREATEURS
d'identite ; Reliques B = SHAPERS ; Reliques E = COURONNEURS de commit (amplificateurs, pas
createurs) ; Reliques A = FONDATIONS universelles.

**Pourquoi ca tient pour NOS contraintes** : cette hierarchie est mecanistement correcte et
tranche l'ambiguite du round-07. Les reliques E (`forked_tongue`, `everburn`, `open_wounds`,
`plague_communion`) AMPLIFIENT une regle sans la CREER — ce n'est pas un defaut de design,
c'est la consequence du principe #2 (pas de downside, relics-design.md §1). La vraie analogie
StS est les rares non-boss (Dead Branch, Philosopher's Stone — slaythespire.wiki.gg/wiki/Relics,
verifie), pas les boss reliques avec downside.

**Ce qui tient specifiquement en async** : dans un contexte de snapshot async, une relique E
sans downside est PREFEREE — un ghost qui possede `everburn` ne doit pas etre handicape
structurellement (le snapshoter ne sait pas quels adversaires il affrontera ; une relique a
downside pourrait casser un run en mid-game sans recours). Le choix sans downside est une
contrainte de pilier, pas une faiblesse de design. Giovannetti 2018 dit que le downside
fonctionne comme « forced theming » dans un jeu singleplayer — mais le forced theming de The
Pit vient des TYPES P1 (seuil 2/4 qui oriente la composition), pas des reliques. La separation
est propre.

**Ce qui n'est pas encore resolu dans cette hierarchie** : la position des reliques A (stats
plates universelles) dans la sequence de build-definition. Le brouillon les qualifie de
« FONDATIONS sans vote sur l'identite » — ce qui est exact mais masque leur risque de BRUIT
PAR DEFAUT en early (cf. §2.3 de r07-relics.md, desaccord partiellement adopte en §3.5 du
round-07 avec priorite 3). Ce risque de bruit n'est pas encore quantifie.

**Source** : slaythespire.wiki.gg/wiki/Relics (boss vs rares) ; relics-design.md §1 principe
#2 ; round-07.md §1.7 ; Giovannetti gamedeveloper.com 2018.

---

### 1.2 ACCORD FORT — Deprioritisation F + garantie de pertinence B-E (§4.1 + §4.6)

**Pourquoi ca tient** : confirme au round 7 et maintenu. L'argument mathematique est solide
(P(≥1 F parmi 3) ≈ 38 %, soit ~1 offre sur 4 contaminee). Dans un pool LOCAL (pas partage
comme TFT), la contamination est plus dommageable : un joueur ne « concurrence » pas les
autres pour les reliques — il voit le meme pool sur son run, et une F mal cadree a 6 wins
(peak de tension) est du bruit pur. Le remplacement seede est deterministe (invariant #3
reformule) et sans friction visible.

**Point qui tient specifiquement** : le passage F→marchand (P1.5c) est la bonne direction
terminale. Les reliques F (`carrion_ledger`, `black_summons`, `beggars_lantern`) ont
mecaniquement plus de sens comme choix actifs payants (tension or/relique) que comme
recompenses de combat. Leur temporaire demotion dans le pool est un compromis justifie en
attendant P1.5c.

**Source** : 00-state §2.2 (gating tiers, confirme) ; round-07.md §1.1 ; relics.lua:69-73
(3 F en positions 19-21, confirme).

---

### 1.3 ACCORD — `famines_math` option (a) + tri STABLE secondaire par `id` (§4.5, NON-NEGOCIABLE)

**Pourquoi ca tient** : le bug de non-determinisme du `table.sort` Lua non-stable est une
violation directe de l'invariant #2 (decouverte r07-relics §1.3, adoptee round-07.md §3.2).
La correction (cle secondaire `id` alphabetique) est triviale (1 ligne), non discutable, et
conforme au pilier async (meme seed = meme resultat partout).

La confirmation lua.org/manual/5.1/manual.html#5.5 est correcte : « The sort algorithm is
not stable; that is, elements considered equal by the given order may have their relative
positions changed by the sort. » Dans le contexte de snapshots serialisables rejoues
cross-session, tout non-determinisme latent est un bug de classe 1.

**Source** : lua.org/manual/5.1/manual.html#5.5 ; round-07.md §3.2 ; 00-state §6 invariant
#2.

---

### 1.4 ACCORD — Arc temporel ≥1 shaper-mid + ≥1 payoff-late par archetype (§4.8)

**Pourquoi ca tient** : le tableau du round-07 (§4.8) montre que rot (pas de payoff-late) et
choc (pas de shaper-mid) ont des arcs incomplets. Ce n'est pas une question de puissance — c'est
une question de lisibilite de progression. Un joueur qui commit rot en round 3 et monte en tier
boutique T4 sans trouver de relique rot tier-4 croit que son archetype est « mauvais » ou qu'il
a eu de la malchance — alors que c'est un trou de contenu. En async, ce trou est aggrave : un
ghost T4 ennemi qui A une relique rot tier-4 (futur contenu) semblera asymetriquement favorise.

**Ce qui est solidement etabli** : les trous documentés (rot, choc, wide) sont corrects et
justifies. P1.5b les comble. La dependance sur P0.5 (axe D choc decide avant apex choc) est
necessaire et sequencee correctement.

**Source** : ROADMAP-draft §4.8 tableau ; round-07.md §1.2 ; bunnymuffins.lol (augments TFT
timing directionnel, cite round-07).

---

### 1.5 ACCORD — `offer_decision_quality` comme metrique sim (§7.4bis, P0.5)

**Pourquoi ca tient (avec nuances — cf. §2.1 pour les desaccords)** : la metrique est
correcte dans son principe. Keith Burgun (keithburgun.net/pick-1-of-3-is-a-missed-game-design-
opportunity, verifie — texte source dit : « When powers are loosely coupled, the decision is
random/arbitrary and not interesting. When powers are highly coupled with no restrictions,
the choice is obvious and not interesting either ») identifie le probleme reel : ni trop lache
ni trop fort. Le `lift` de win-rate sur les 10 combats suivants est un proxy raisonnable.

**Ce qui tient pour nos contraintes specifiques** : dans un pool LOCAL (pas partage), la
repetition d'offres est plus frequente — sur 4 offres par run × N runs, un joueur voit les
memes combinaisons de reliques. Une metrique de qualite de decision mesures sur N=200 runs
detectera des patterns stables, contrairement a TFT ou le pool partage entre joueurs cree une
variance naturelle.

**Source** : keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity (confirme) ;
00-state §2.2 (pool 21 reliques, gating tiers) ; ROADMAP-draft §7.4bis.

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — Le seuil « < 40 % triviales » de `offer_decision_quality` est un cible arbitraire non calibree sur notre contexte de pool LOCAL

**Claim implicite du brouillon** (§7.4bis) : `< 40 % triviales` + `< 20 % arbitraires` est
la cible de qualite d'offre. Ce seuil est repris de r07-relics §3/Prop-A sans justification
de sa calibration au contexte specifique de The Pit.

**Pourquoi c'est insuffisant — argument en 3 temps** :

**Temps 1 — La trivialite STRUCTURELLE est inevitable** :

Sur les 21 reliques, les 4 A (bloodstone/carapace/aegis/whetstone) sont TOUJOURS bonnes
independamment du build. Si une offre contient une A + deux B non-pertinents, elle sera
triviale (A domine) — mais ce n'est pas un probleme tunable par les valeurs de lift, c'est
la consequence architecturale d'avoir 4 reliques universelles dans un pool de 21. A tier-1
(early), 3 A sur 7 reliques eligibles = 43 % du pool eligible. **P(au moins 1 A dans une
offre de 3 issues de 7 eligibles) = 1 − C(4,3)/C(7,3) = 1 − 4/35 ≈ 88,6 %**. Autrement
dit, ~89 % des offres early contiennent au moins une relique universelle — qui sera souvent
la « meilleure » option par defaut si le build n'est pas engage. **Ce n'est pas la
seule metrique du lift qui resoudra ca.**

Le seuil « < 40 % triviales » sera impossible a atteindre en early STRUCTURELLEMENT (pas
par manque de tuning), et facile a atteindre en late (les A sont diluees dans le pool tier-
4). Une cible uniforme sur l'ensemble du run masque cette heterogeneite temporelle.

**Temps 2 — La definition de « triviale » (lift > 2x) ne capture pas la bonne distinction** :

`lift(choisie) > 2 × max(lift des 2 autres)` mesure si la decision est claire en termes de
win-rate. Mais une decision peut etre SIGNIFICATIVE meme si elle n'est pas close
mathematiquement — par exemple, choisir entre `everburn` (burn no-decay) et `plague_communion`
(multi-affliction +25 %) pour un build burn etabli est une VRAIE decision de direction
meme si le lift de `everburn` est legerement superieur. Burgun lui-meme (ibid.) distingue
decision « interesting » (engaging choice between meaningful alternatives) vs « trivial »
(dominant option) : le lift capture bien le cas trivial, **mais ne mesure pas si l'option
non-triviale offre une ALTERNATIVE DISTINCTE** de direction de build.

Une metrique complementaire manque : la **DIVERGENCE DE CONSEQUENCE** — est-ce que les 3
options de l'offre orientent le build vers des STRATEGIES DIFFERENTES a 5 rounds ? Deux
reliques B de la meme famille ont un lift similaire (les deux amplifient le meme archetype)
mais ne creent aucune tension de direction. Le `lift` les traiterait comme une offre non-
triviale et non-arbitraire alors que c'est une pseudo-decision.

**Temps 3 — La consequence pratique** :

Si le brouillon implemente `offer_decision_quality` tel quel et mesure < 40 % triviales, il
aura VALIDE le systeme sans avoir prouve que les decisions sont reellement meaningfull. Il
est plausible que le systeme satisfasse la metrique par des offres A+B+B (non-triviales au
sens lift mais pseudo-decisions de shaping) tout en laissant ouvert le probleme de Burgun.

**Proposition (cf. §3.1)** : separer la mesure en 3 sous-metriques avec des cibles PAR TIER
D'AVANCEE, et ajouter une mesure de divergence de consequence.

**Source** : keithburgun.net/pick-1-of-3 (ibid. — « interesting decision requires meaningful
alternatives that cost something not to take ») ; calcul hypergometrique (base : 00-state
§2.2, 4 A / 21 reliques, gating tier-1 = 3A+4B = 7 eligibles) ; Wayline.io/blog/roguelike-
itemization (verifie : « the pool should support alternative lines where clusters exist, with
some overlaps but also genuine conflicts that make items mutually exclusive within a build »).

---

### 2.2 DESACCORD — Il manque une relique de PIVOT EARLY : aucune relique disponible en tier-1 ou tier-2 ne rend un choix d'archetype IRREVERSIBLE (ou suffisamment couteux a abandonner)

**Claim implicite du brouillon** : les reliques B (tier-2) « confirment et amplifient l'axe
engage » — leur arrivee en early oriente le build.

**Pourquoi cette lecture est trop optimiste** :

En early (wins=0-1, boutique T1), les reliques eligibles sont : 3 A (tier-1) + 4 B (tier-2).
La garantie de pertinence verifie que si une B est proposee, sa famille est presente sur le
plateau (cf. §4.1, r07-relics §1.1 — correctement adopte). **MAIS la garantie de pertinence
ne rend pas la decision IRREVERSIBLE.** Un joueur qui prend `ember_heart` (burn +30 %) avec
1 burn + 1 bleed + 1 poison sur son plateau a encore 7-9 rounds pour pivoter vers un autre
archetype. L'amplification de 30 % sur une unite ne constitue pas un COUT D'IRRE VERSIBILITE
— il peut vendre son burn et partir vers du poison sans perte strategique significative (la
relique ne le protege pas, elle l'amplifie juste).

**La reference correcte n'est pas StS mais Balatro** (qui est notre reference d'addiction, gd-
research-result.md §2.6) : dans Balatro, prendre un Joker en early qui « s'active a chaque
Flush » ENGAGE le joueur vers les Flush — non par penalite, mais parce que le Joker
reinvestit sa valeur dans les decisions suivantes de draft. La cle : le Joker de Balatro est
une **condition qui monte en valeur SI on continue dans la direction**, pas un boost plat.
(balatrogame.fandom.com/wiki/Guide:General_strategy confirme : « stack Jokers that share a
tag [...] two or more on the same theme trigger a synergy bonus ».)

Nos reliques B (`kings_bowl` +20 %, `ember_heart` +30 %) sont des **boosts plats statiques**
— ils ne s'accumulent pas avec la coherence du build, ils ne deviennent pas plus forts si on
continue dans la direction. Un joueur qui prend `ember_heart` en round 1 avec 1 burn puis
passe a du poison en round 4 a tout simplement « gaspille » 30 % de dmg sur 1 unite, sans
cout de pivot strategique visible. Cela affaiblit la SIGNIFICATION de la decision.

**Ce qui manque** : une relique de PIVOT EARLY (tier-1 ou tier-2 conditionnel) qui SCALE
avec la coherence du build. Pas un downside (contraire au principe #2), mais un effet qui
monte en valeur a mesure que le build s'engage dans la meme direction. Exemple concret
(propre a nos mecaniques) : une relique tier-2 qui donne +5 % d'amplification PAR UNITE du
meme `dot_family` presente sur le plateau (scalante, pas plate). Avec 2 units → +10 % ;
avec 4 units → +20 % ; avec 6 → +30 %. Le joueur qui pivote en round 4 PERD la valeur
accumulee du scaling — c'est un COUT D'IRREVERSIBILITE sans penalite dure.

**Pourquoi ca tient pour nos contraintes** :

- **Deterministe** : la condition se lit de `dot_family` (champ statique, P0.5), pas de RNG.
- **Team-wide** : applicable a toute la compo.
- **Async-safe** : le scaling se calcule au build, pas en combat — snapshotable.
- **Pas de downside** : pas de penalite si le joueur pivote, juste moins de valeur accumulee.
- **Pas une gate** : meme avec 1 unite, la relique donne +5 % (non-nul, utile meme en early).

**Ce qui separe cela des B actuels** : la difference est entre un boost plat (`+30 % burn
pour toujours`) et un boost scalant (`+5 % par unite burn, croissant avec la coherence`). Le
second ENGAGE psychologiquement : le joueur VOIT sa relique monter de valeur avec ses
decisions. C'est la difference entre StS Dead Branch (valeur emergente des cartes) et StS
Akabeko (+8 atk d'ouverture : utile mais plat).

**Note** : cette proposition est distinct de la garantie de pertinence (§4.1) qui adresse
QUELLES reliques sont proposees, pas COMMENT elles engagent le joueur dans le temps.

**Source** : keithburgun.net/pick-1-of-3 (« orientation requires a cost to not committing ») ;
balatrogame.fandom.com/wiki/Guide:General_strategy (synergie de tags = scaling conditionnel) ;
Wayline.io/blog/roguelike-itemization (verifie : « the pool should force alternatives that
are mutually exclusive within a build — this creates real commitment costs ») ; relics-design
.md §1 (principe #2 : pas de downside) ; 00-state §2.2 (gating tiers).

---

### 2.3 DESACCORD PARTIEL — La metrique `offer_decision_quality` est specifiee AVANT la resolution du probleme des reliques A en early, ce qui peut valider un systeme structurellement defectueux

**Claim du brouillon** (§7.4bis) : mesurer `offer_decision_quality` sur le pool actuel (21
reliques) comme BASELINE avant P1.

**Le probleme** : la garantie de pertinence actuelle ne s'applique pas aux reliques A (§4.1 :
« les A sont offertes librement »). Si on mesure la baseline avec des A non-soumises a la
garantie et que le resultat est « < 40 % triviales », on valide un systeme OU les offres non-
triviales sont souvent A+B (non-triviales car A non-pertinente mais universelle). La correction
de la garantie de pertinence pour les rounds early (≤3 wins, r07-relics §2.3/Prop-C, adoptee
au round-07 en priorite 3) CHANGERAIT les resultats de la baseline si implementee avant.

**Consequence** : si la baseline est mesuree AVANT la correction de la garantie early, on
aura deux metriques incomparables (baseline sans correction / post-P1.5a avec correction).
La progression apparente de la qualite de decision pourrait refleter simplement la correction
de la garantie, pas l'ajout de contenu P1.

**Proposition (mineure)** : noter dans le spec de §7.4bis que la baseline doit etre mesuree
sur le pool post-correction-garantie-early (priorite 3 adoptee) — pas sur le pool tel quel.
Ou alternativement, mesurer les deux et documenter le delta comme « gain de la correction
garantie » vs « gain de P1 ». ~2 lignes de note dans la spec, 0 code.

**Source** : round-07.md §3.5 (adoption priorite 3 de la garantie early) ; r07-relics §2.3
(fondement du desaccord).

---

### 2.4 DESACCORD — Le mecanisme de `drought_protection` pour les reliques est toujours absent et non specifier meme en tant qu'intention future

**Claim manquant dans le brouillon** : le brouillon corrects les arcs temporels, garantit la
pertinence, et deprioritise les F — mais ne prevoit nulle part un mecanisme de protection
contre la secheresse d'archetype (drought protection) pour les RELIQUES.

**Pourquoi c'est un trou reel** :

La table de cotes de boutique a un drought protection implicite (les tiers de boutique
filtrent les rangs). Mais pour les RELIQUES, le tirage Fisher-Yates seede (00-state §2.2)
ne comporte aucune accumulation de probabilite en cas de non-vue. Un joueur burn qui ne
voit aucune relique burn en 6 rounds (sur ~4 offres = 2 runs sans relique burn) est dans la
situation equivalent d'un StS player qui n'a pas vu de rare en 8 combats — la frustration
du « unlucky RNG » s'installe.

StS resoud cela par le « rare climb » (+1 % de chance de rare par carte commune vue depuis
la derniere rare — slaythespire.wiki.gg verifie ; competitive/slay-the-spire.md §3.2). Dans
The Pit, l'analogue serait : plus de rounds passes sans une relique de l'archetype dominant
du build (≥60 % de `dot_family`), plus le pool de tirage penche vers cet archetype. Ce n'est
pas tricher — c'est du renforcement variable CONTEXTUELLEMENT ADAPTATIF, comme le rare-climb
de StS.

**Pourquoi ca tient pour nos contraintes** :
- **Deterministe** : le biais peut etre encode comme un poids supplementaire dans le tirage
  seede (`rollRelicChoices` lit le `rng` du run — cf. `state.lua:339`) — le meme seed de run
  donnera toujours le meme biais, car le `dot_family` majoritaire du build est deterministe
  au build.
- **Pas de garantie dure** : pas un pity-timer qui garantit une relique a N offres (le
  brouillon a correctement rejete la pity-garantie explicite, §10 liste des rejets round-07).
  C'est du POIDS SUPPLEMENTAIRE, pas une garantie.
- **Pas un gate** : le joueur qui joue un build diversifie (2+2+2) ne beneficiera pas du
  biais (pas de famille dominante) — c'est coherent (Wayline.io : « biasing the pool toward
  the player's archetype rewards commitment without punishing diversity »).

**Distinction du brouillon actuel** : le brouillon (§4.1) garantit la PERTINENCE d'une B
proposee (si une B est dans l'offre, sa famille est presente). Il ne garantit pas qu'une B
DE L'ARCHETYPE DOMINANT sera DANS l'offre du tout. C'est la difference entre « si tu as une
pomme dans ton offre, elle pousse dans ton jardin » (garantie de pertinence) et « si tu
cultives des pommes depuis 3 rounds, il y a une probabilite progressive qu'une offre en
contienne » (drought protection). Les deux sont necessaires.

**Note sur la priorite** : ce n'est PAS une urgence P0.5 — la garantie de pertinence actuelle
attenúe deja partiellement le probleme. Mais l'absence d'intention documentee pour la
drought protection des reliques est un trou de spec qui pourrait resurgir en P3 quand les
metriques sim montreront des sequences de secheresse d'archetype.

**Proposition** : ajouter une note d'intention dans §4.1 (ou §7.4bis) : « FUTURE P3 —
ajouter un poids cumulatif de drought-protection : si le build a ≥60 % `dot_family` depuis
≥2 offres sans une B/E de cette famille, augmenter le poids de tirage de 20 %/offre manquee
(cap : +60 %, evite la garantie dure). Deterministe : poids lu de l'etat seedé du run. »
0 code maintenant, 3 lignes de spec.

**Source** : competitive/slay-the-spire.md §3.2 (rare-climb verifie) ; slaythespire.wiki.gg/
wiki/Relics (probabilites verifiant la montee progressive) ; Wayline.io/blog/roguelike-
itemization (pool bias = reward commitment) ; Medium/@JeongHyeonUk/designing-fair-rng-in-
roguelikes (verifie : « adaptive probability ensures the player's strategic investments pay
off statistically without guaranteeing outcomes ») ; 00-state §2.2 (Fisher-Yates sans
protection secheresse).

---

### 2.5 DESACCORD PARTIEL — La resolution du litige #CC (`wither_bloom` post-C2) est differee sans specification du critere de tranchement

**Claim du brouillon** (§1.10 round-07 / litige #CC) : `wither_bloom` apres le fix C2
compte 1 famille active (rot) et son role multi-affliction s'effondre. Decision differee a
P1.5b — soit (a) reconcevoir avec dps non-nuls sur bleed/poison, soit (b) accepter comme
rot-T3 cosmetically-affliction.

**Pourquoi le report est risque** :

`wither_bloom` est en `U.pool` et participe aux offres boutique maintenant. Si elle est un
rot-T3 avec slow+weaken cosmétiques (option b), son identite vs `ash_maw` (burns pur) et
`pit_maw` (rot equipe ennemie) est floue — trois T3 pourraient se chevaucher en role sans
que le joueur distingue leur niche (col B de l'audit §3.1). L'option b cree exactement le
probleme de paires de niche que le round-07 a adopte dans la col B (units §2.2).

Si on difere en P1.5b sans criterion, le brouillon entre dans P1 avec une unite dont le
role est « indecis » — et les synergies par TYPE (P1) interagiront avec une unite dont la
`dot_family` (rot) ne capture pas ses effets secondaires bleed/poison. Lors de la spec du
palier-4 rot (§5.2), `wither_bloom` ne contribuera pas au palier bleed ou poison, mais les
joueurs qui l'ont auront l'impression d'un multi-affliction. Ca creer une fausse attribution.

**Proposition** : le critere de tranchement doit etre documente AVANT P1 meme si le code
vient en P1.5b. Critere suggere : « si l'option (a) peut etre validee en sim (dps bleed/
poison non-nuls → interagit avec le palier de type correspondant, verifie en CONFIG-XY), alors
option (a) ; sinon option (b) avec renommage i18n clair ('DISTILLATEUR DE VIDE' — rot pur
avec effets lents/maladie, sans promesse de multi-affliction) + retrait de `U.pool` si trop
proche de `pit_maw`. » ~5 lignes de critere dans la spec P1.5b. 0 code maintenant.

**Source** : round-07.md §1.8 (litige #CC) ; ROADMAP-draft §1 (litige #CC reference) ;
col B §3.1 (paires de niche, detection ≤20 % ecart) ; units.lua (wither_bloom rol
e, relu).

---

### 2.6 DESACCORD MINEUR (sur l'asymetrie B) — Les increments des reliques B sont calibres sur une hierarchie defectueuse mais le doc ne distingue pas les leviers prioritaires

**Claim du brouillon** (§4.8 + §7.4bis) : les 4 B sont `[PH-DEPENDANT]` (reajustes apres
`--poison-frac`/`--no-weaken`). Correctement marque.

**Nuance non adressée** : l'asymetrie actuelle des increments B est :
- `kings_bowl` (poison) : +0.20 inc (CONSERVATEUR — car poison dominant)
- `ember_heart` (burn) : +0.30 inc (genereux — burn faible)
- `weeping_nail` (bleed) : +0.18 inc
- `grave_cap` (rot) : +0.18 inc

La logique est inverse de l'ideal : une famille DOMINANTE (poison) a un inc CONSERVATEUR
pour ne pas l'amplifier davantage — ce qui est correct. Mais les familles FAIBLES (bleed,
rot) ont un inc INFERIEUR a burn (+0.18 vs +0.30), ce qui ne compense pas suffisamment leur
faiblesse relative. Si `--poison-frac` confirme la sur-representation de poison, le premier
levier de correction devrait etre (a) REDUIRE `kings_bowl` davantage ET (b) AUGMENTER
`weeping_nail`/`grave_cap` vers 0.22-0.25. La PRIORITE de calibration est d'abord les
familles faibles (pas burn qui a deja le plus gros inc).

Ce n'est pas un desaccord structurel — le [PH-DEPENDANT] est correct. Mais le brouillon
n'explique pas l'ORDRE d'ajustement en P3, ce qui pourrait mener a tuner burn (le plus
visible) avant de corriger bleed/rot (les moins representees en boutique).

**Proposition (mineure)** : noter dans §4.8 : « ajustement P3 dans cet ordre : (1) reduire
`kings_bowl` si `--poison-frac` confirme sur-puissance ; (2) augmenter `weeping_nail` et
`grave_cap` si `--pool-repr` confirme sous-visibilite bleed/rot ; (3) recalibrer `ember_heart`
en dernier (burn a deja les meilleurs buffs de propagation). » ~3 lignes de priorite, 0 code.

**Source** : relics.lua (valeurs confirmees) ; 00-state §3.1 (hiérarchie poison>tank>...>choc) ;
ROADMAP-draft §4.8 ([PH-DEPENDANT] confirme) ; round-07 §3.1 (adoption #DD : pool-repr avant
poison-frac).

---

## 3. Propositions priorisees

### Prop-A — REFINER `offer_decision_quality` : 3 sous-metriques par tier d'avancee + divergence de consequence (PRIORITE 1, ~15 lignes sim)

**Quoi** : etendre la spec §7.4bis de `offer_decision_quality` avec :

1. **Sous-metrique par tier d'avancee** :
   - Early (wins 0-1) : cible `< 60 % triviales` (structurellement eleve a cause des A —
     acceptable si les non-triviales sont en tension reelle).
   - Mid (wins 2-4) : cible `< 40 % triviales` (le build est plus engage, la garantie de
     pertinence est plus discriminante).
   - Late (wins 5+) : cible `< 30 % triviales` (tier-4, reliques E rares, les decisions
     doivent etre les plus tendues du run).

2. **Sous-metrique de DIVERGENCE DE CONSEQUENCE** : pour chaque offre non-triviale et non-
   arbitraire (la « zone cible »), verifier que les 2+ options viables orientent le build
   vers des `dot_family` DISTINCTES. Mesure : si les 2 options avec le lift le plus proche
   ciblent la meme famille OU sont toutes deux des A → classer l'offre comme « pseudo-
   decision » (non capturee par trivial/arbitraire). Cible : `< 20 % pseudo-decisions`.

3. **Rapporter la proportion d'offres en tension REELLE** = total − triviales − arbitraires −
   pseudo-decisions. Cible globale : `> 35 % d'offres en tension reelle`.

**Cout** : ~15 lignes dans `tools/sim.lua`. 0 invariant. Dans le meme lot P0.5 que CONFIG-PC.

**Pourquoi maintenant et pas en P3** : si la baseline mesure des pseudo-decisions comme des
bonnes decisions, P1 (types) peut les degrader encore sans que la metrique ne le detecte.

**Source** : keithburgun.net/pick-1-of-3 (« interesting = meaningful alternatives that cost
something ») ; Wayline.io (« overlaps and conflicts between clusters ») ; r07-relics §2.1
(metrique originale — etendue ici).

---

### Prop-B — AJOUTER une relique B SCALANTE par coherence de build (tier-2) : la relique de PIVOT EARLY (PRIORITE 2, data + ~10 lignes)

**Quoi** : ajouter une relique tier-2 dont le bonus SCALE avec la coherence du build au lieu
d'etre plat. Nom de travail : `resonance_stone` (ou tout nom grimdark). Mechanique :
`+5 % affliction_inc par unite du meme dot_family sur le plateau` (team-wide). Valeur calculee
au build (champ `resonanceInc` accumule au `R.apply`).

Exemple : build 4 poison → `resonance_stone` donne +20 % poison_inc (equivalant a juste
sous `kings_bowl` +20 %). Build 2 poison → +10 % (moitie moins utile). Le joueur qui pivote
perd le scaling — pas une penalite, juste une valeur non-accumulee.

**Mise en oeuvre** : nouveau op `relic_resonance_inc {baseInc=0.05}` dans `R.apply` — compte
les unites du meme `dot_family` majoritaire, multiplie par `baseInc`. Lu depuis `dot_family`
(prerequis P0.5). ~10 lignes dans `relics.lua` + data.

**Positionnement dans le pool** : offrable tier-2 (early), garantie de pertinence B — sa
famille-cible = la famille majoritaire du build. Pas de gating conditionnel supplementaire
(sa valeur est naturellement conditionnee par la coherence).

**Garde-fou invariant #21** : `applyRelics` ne crash pas — le calcul de `dot_family`
majoritaire renvoie nil si aucun effet DoT → bonus nul (safe).

**Prerequis** : `dot_family` pose sur chaque unite (P0.5 §3.3). Codable en // avec P0.5.

**Pourquoi pas une 5e relique B plate** : le brouillon a deja 4 B plates (une par famille).
Une 5e B plate (ex. `choc_inc`) n'ajoute pas de profondeur de decision — elle amplifie juste
le choc. Une B scalante cree une NOUVELLE DIMENSION de decision : « dois-je prendre la B de
ma famille (+30 % flat) ou la resonance (+5 % × 4 unites = +20 % mais qui croitra si je
continue dans cette direction) ? » — la tension est entre CERTITUDE et CROISSANCE.

**Source** : balatrogame.fandom.com/wiki/Guide:General_strategy (scaling conditionnel par
tags) ; Wayline.io (commitment costs = interesting decisions) ; keithburgun.net/pick-1-of-3
(decision interesting = options avec « cost to not committing »).

---

### Prop-C — SPECIFIER le critere de tranchement #CC (`wither_bloom`) AVANT P1 (PRIORITE 2, doc ~5 lignes, 0 code)

**Quoi** : ajouter dans la spec P1.5b (§1.10 ou §4.11) :

```
Critere de tranchement #CC (a trancher AVANT de coder P1) :
- Option (a) : CONFIG-XY = 1 wither_bloom + 1 poseur bleed + 1 poseur poison vs IA, N=30 ;
  si bleed ET poison se declenchent et interagissent avec leur palier de type respectif
  → option (a) viable → reconcevoir dps bleed/poison non-nuls (wither_bloom = T3 multi-
  affliction veritable, dot_family = rot, contribue aux paliers rot ET via cross-type).
- Option (b) : si sim montre dps trop bas pour le palier → renommer i18n en archetype rot
  pur + retirer de U.pool si ecart < 20 % avec pit_maw (col B §3.1).
```

0 code. 0 invariant. S'insere dans la section litige #CC existante.

**Source** : round-07.md §1.8 ; col B §3.1 (paires de niche detection) ; ROADMAP-draft §5.2
(garde-fou twist #1 — un T3 ne doit pas etre un sous-cas d'un autre).

---

### Prop-D — DOCUMENTER l'intention de DROUGHT PROTECTION des reliques en P3 (PRIORITE 3, doc ~3 lignes)

**Quoi** : ajouter dans §4.1 (garantie de pertinence) ou §7.x (tableau d'intention) :

```
NOTE P3 — DROUGHT PROTECTION RELIQUES (intention a implementer, pas code) :
Si le build a ≥60 % dot_family depuis ≥2 offres sans une B/E de cette famille,
augmenter le poids de tirage seedé de +20 %/offre manquee (cap : +60 %, jamais
une garantie dure — le poids double au max le tirage naturel). Deterministe :
poids calcule depuis l'etat du run seed, pas depuis un compteur externe. Similaire
au rare-climb de StS (slaythespire.wiki.gg/wiki/Mechanics, +1 % par commune vue).
```

0 code. 0 invariant. ~3 lignes de note d'intention. Evite la redécouverte en P3 du probleme.

**Source** : competitive/slay-the-spire.md §3.2 ; slaythespire.wiki.gg ; Medium/@JeongHyeonUk
/designing-fair-rng-in-roguelikes (adaptive probability documentee) ; 00-state §2.2.

---

### Prop-E — SPECIFIER l'ordre de calibration des B en P3 pour eviter le tuning du symptome avant la cause (PRIORITE 3, doc ~3 lignes)

**Quoi** : ajouter dans §4.8 sous `[PH-DEPENDANT]` :

```
Ordre de calibration P3 :
(1) pool-repr → si poison sur-represente → reduire kings_bowl (0.20→0.14-0.16)
(2) pool-repr → si bleed/rot sous-representes → augmenter weeping_nail/grave_cap (0.18→0.22)
(3) recalibrer ember_heart en dernier (burn a l'inc le plus eleve + meilleure propagation)
NE PAS inverser cet ordre (tuner ember_heart visible avant bleed/rot invisibles = biais
de confirmation du symptome, pas de la cause).
```

0 code. ~3 lignes. Previent un anti-pattern de calibration courant.

**Source** : 00-state §2.1 (hiera rchie poison>tank>...>choc, diagnostic equi librage) ;
relics.lua (valeurs confirmes) ; round-07.md §2.3 (pool-repr adoption litige #DD).

---

## 4. Questions ouvertes

### Q1 — La trivialite structurelle des offres early (≥89 % contiennent une A) est-elle acceptable comme feature ou a corriger ?

Si le joueur early prend systematiquement une A (car son archetype n'est pas encore etabli),
les reliques A sont en fait des « orientation-neutral stabilisers » utiles — comme les cartes
« Strike/Defend » du deck de depart dans StS (garantissent une valeur minimale avant
specialisation). Le probleme n'est peut-etre pas la trivialite early en soi, mais le SIGNAL
que la relique envoie sur l'identite du build. Une A avec un nom grimdark fort peut QUAND
MEME contribuer a l'identite de run percue (nom de build §2.4bis — « CROISÉ MAUDIT » avec
`aegis` + tank taunt).

La question est : est-ce que le joueur percoit la prise d'une relique A en early comme une
« decision » (ok, je prends une fondation) ou comme une « absence de decision » (rien de
pertinent pour mon build) ? Cette distinction psychologique est non capturee par le lift seul.

### Q2 — La relique B scalante (Prop-B) conflicte-t-elle avec les paliers de TYPE P1 ?

Si le palier-2 de type (+ 20 % affliction pour sa famille) est implementé en P1, et qu'une
relique B scalante donne +5 % par unite (max +45 % a 9 slots), la cumulabilite devient :
`palier-2 + resonance_stone + relique B plate + aura`. Sur un build complet, le combo peut
depasser le seuil de saturation (§5.2 tableau). A verifier avec le tableau de saturation
AVANT de finaliser `resonance_stone`. La Prop-B depend donc de P0.5 (dot_family) ET du
tableau de saturation (precondition P1).

### Q3 — Avec 22 reliques (si Prop-B est adoptee), les probabilites de pool changent-elles significativement ?

22 reliques au lieu de 21 → P(≥1 F parmi 3) passe de 1 − C(18,3)/C(21,3) ≈ 38.7 % a
1 − C(18,3)/C(22,3) ≈ 35.9 %. Variation mineure. La structure de pool (3 F, 4 A, 4 B, 4 C,
etc.) reste inchangee. A noter seulement si la prop-B est approuvee.

### Q4 — La drought protection des reliques (Prop-D) interagit-elle avec la garantie de pertinence actuelle de facon coherente ?

Si le biais de drought protection favorise une B de la famille dominante, et que la garantie
de pertinence AUSSI l'en fait en verifiant que la famille est presente... les deux couches
se renforcent mutuellement. Risque : une famille dominante (ex. poison ≥60 %) voit ses
reliques B encore plus souvent en offre, aggravant la trivialite (offre triviale poison).
La drought protection doit donc s'activer SEULEMENT si la garantie de pertinence a ETE
satisfaite mais n'a pas produit la bonne B — pas comme doublement de la meme garantie.
A preciser dans la spec Prop-D.

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| Pick 1 of 3 : couplage et tension de decision | keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity (verifie ce round) |
| Pool local vs partage : visibilite archetype | grokipedia.com/page/Auto_battler (verifie ce round — local = plus de repetition d'offres) |
| Roguelike itemization : pool bias reward commitment | wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency (verifie ce round) |
| Balatro : synergies de tags = scaling conditionnel | balatrogame.fandom.com/wiki/Guide:General_strategy (verifie ce round) |
| StS rare-climb (progression probabilite) | competitive/slay-the-spire.md §3.2 ; slaythespire.wiki.gg/wiki/Relics |
| Adaptive RNG (drought protection) | medium.com/@JeongHyeonUk/designing-fair-rng-in-roguelikes (verifie ce round) |
| Boss relics StS avec downside | slaythespire.wiki.gg/wiki/Relics (verifie round 7) |
| Forced theming par downside | gamedeveloper.com/design/how-i-slay-the-spire (Giovannetti 2018) |
| table.sort non-stable Lua | lua.org/manual/5.1/manual.html#5.5 |
| wither_bloom col B paires de niche | round-07.md §1.8 (#CC) + col B §3.1 |
| increments B actuels (verifie) | src/data/relics.lua:27-30 |
| gating tiers early/mid/late | 00-state.md §2.2 ; src/run/state.lua:339 |
| invariant #2 (determinisme) | 00-state.md §6 |
| famille drought : P(vue) poids | 00-state.md §2.2 (Fisher-Yates seede sans protection) |
| Hierarchie CREATEURS/SHAPERS/COURONNEURS | ROADMAP-draft.md §4.11 ; round-07.md §1.7 |

---

## 6. Synthese pour le synthetiseur

**3 challenges cles du round 8 lentille reliques :**

1. **`offer_decision_quality` trop grossiere** : le seuil « 40 % triviales » est uniforme
   alors que la trivialite early est STRUCTURELLE (≥89 % des offres contiennent une A) et
   non-tunable par les valeurs de lift. La metrique doit etre segmentee par tier d'avancee
   ET doit ajouter la « pseudo-decision » (deux B de la meme famille = non-triviale mais
   sans tension de direction). Propositions concretes en Prop-A (15 lignes sim).

2. **Absence de PIVOT EARLY irreversibilisant** : les reliques B plates (+X % flat) n'engagent
   pas le joueur dans une direction de facon progressive — leur valeur ne croit pas avec la
   coherence du build, contrairement aux Jokers de Balatro. Une relique B scalante (`+5 %
   par unite du meme dot_family`) creerait un cout d'irreversibilite POSITIF (sans downside),
   plus en phase avec la philosophie de nos contraintes async et deterministes. Proposition
   concrete en Prop-B.

3. **Drought protection non specifiee** : le Fisher-Yates seede des reliques n'a aucune
   protection contre la secheresse d'archetype (contrairement au rare-climb de StS). L'absence
   d'INTENTION documentee cree un risque de re-decouverte en P3. La Prop-D documenter
   l'intention (3 lignes, 0 code) suffit pour P1.

---

*Redige le 2026-06-23 par l'agent lentille-reliques, round 8/10. Lecture seule du repo de
jeu. N'edite que sous `docs/roadmap-lab/`. Piliers respectes : async snapshots / sim
deterministe seedee / DA grimdark / pixel art procedural. Sources citees par URL ou
fichier+ligne. Rounds lus : r01 a r07-relics.md, round-01.md a round-07.md, ROADMAP-draft.md
(v8), 00-state.md, BRIEF.md, relics.lua (relu integrale ce round), relics-design.md,
competitive/slay-the-spire.md.*

Sources web consultees ce round :
- [Pick 1 of 3 is a missed game design opportunity (Keith Burgun)](http://keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity/)
- [Roguelike Itemization: Balancing Randomness and Player Agency (Wayline)](https://www.wayline.io/blog/roguelike-itemization-balancing-randomness-player-agency)
- [Balatro Wiki — General Strategy Guide (Fandom)](https://balatrogame.fandom.com/wiki/Guide:General_strategy)
- [Designing Fair RNG in Roguelikes (Medium — Jeong Hyeon-Uk)](https://medium.com/@JeongHyeonUk/designing-fair-rng-in-roguelikes-balancing-luck-and-skill-7b967230e961)
- [Slay the Spire Relics Wiki](https://slaythespire.wiki.gg/wiki/Relics)
- [Auto battler — Grokipedia (pool local vs partagé)](https://grokipedia.com/page/Auto_battler)
- [Roguelikes: Agency and Randomness (Tom's Site)](https://thom.ee/blog/what-makes-or-breaks-agency-in-roguelikes/)
