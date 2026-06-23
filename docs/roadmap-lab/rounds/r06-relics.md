# R06 — Critique adversariale, lentille RELIQUES (round 6/10)

> **Round** : 6/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cibles** : `ROADMAP-draft.md` (brouillon #6, integre round 5) + `round-05.md` (synthese) +
> `rounds/r05-relics.md` (critique lentille round 5).
> **Sources internes lues ce round** : `00-state.md` (32 invariants, chiffres, taxonomie),
> `round-05.md` (synthese), `rounds/r05-relics.md`, `ROADMAP-draft.md` §4 (P1.5a) + §7.4 + §8 +
> §9, `src/data/relics.lua` (21 reliques, relu integrale), `BRIEF.md` (mandat).
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Sources citees par URL ou fichier+ligne pour chaque affirmation.

---

## 0. TL;DR — challenge cle en 3 phrases

Le brouillon #6 a progressivement corrige les erreurs de lecture de code (plague_communion,
feeding_frenzy) et identifie les arcs temporels manquants (rot sans payoff-late, choc sans
shaper-mid). **Mais il reste un angle mort majeur non attaque en 5 rounds : les 21 reliques
ne constituent pas encore un systeme coherent de DECISIONS — elles sont un catalogue de buffs
purs sans asymetrie, sans contre-jeu interne, et sans courbe de valeur verifiee par archetype
sur la duree du run.** Deux challenges specifiques : (1) `plague_communion` est gardee "telle
quelle" avec `+25 % flat` mais sa magnitude n'a jamais ete simulee contre un ghost tier-3/4 —
c'est le seul `more` hors-cap du systeme, non borne, sur une cible multi-affliction accessible
des le round 5 via contagion adverse, ce qui en fait potentiellement le relique la plus forte
du pool sans validation ; (2) les 4 reliques B (`kings_bowl/ember_heart/weeping_nail/grave_cap`)
sont marquees `[PH-DEPENDANT]` mais leurs interactions croisees avec les paliers de type P1 ne
sont pas modelisees — un joueur burn peut cumuler `ember_heart` (+30 % inc) + palier-2 type
(+20 % inc) + `everburn` (plus de decay) = stack d'inc qui echappe au cap si un `more` de twist
est pose, sans aucun garde-fou dans la roadmap.

---

## 1. Accords — ce qui tient (avec le POURQUOI pour nos contraintes)

### 1.1 ACCORD FORT — Deprioritisation des reliques F avant le marchand (brouillon §4.6)

**Ce que le brouillon acte** : si un F est tire ET un B-E disponible, remplacer par un B-E via
tir seede additionnel. Calcul hypergéométrique `P(≥1 F en 3) ≈ 0.387` (verifie r02-relics.md §2.5,
base `relics.lua:69-73`).

**Pourquoi l'accord est fort pour NOS contraintes** : en async, le joueur ne peut pas "jouer
autour" d'une relique F pendant le combat — son snapshot est deja capture. Une relique F
(`carrion_ledger` : bond XP ; `black_summons` : +1 tier ; `beggars_lantern` : -1 tier) agit
sur l'etat de run AVANT le prochain combat, pas sur le build en cours. Offrir un F dans les
3 options = proposer une decision d'economie de run dans un contexte de decision de build de
combat, deux niveaux cognitifs distincts (StS les separe architecturalement, slot marchand dedie —
slaythespire.wiki.gg/wiki/The_Merchant, verifie). La contamination est structurelle, pas un
bruit mineur.

**Ce qui tient specifiquement pour nos piliers** : le tir seede additionnel (`rollRelicChoices`
avec un B-E de remplacement) est deterministique — meme seed + meme wins + meme compo = meme
remplacement. L'invariant #3 est preserve si le test est adapte avant le code (`round-05.md §1.10`
l'acte). Aucune friction avec le modele async.

**Source** : `src/data/relics.lua:69-73` (R.order : 3 F confirmes, positions 19-21) ;
slaythespire.wiki.gg/wiki/The_Merchant ; r02-relics.md §2.5 (calcul) ; round-05.md §2.

### 1.2 ACCORD FORT — Arc temporel : critere "≥1 shaper-mid (tier≤3) ET ≥1 payoff-late (tier-4)"
par archetype (brouillon §4.8)

**Ce que le brouillon acte** : le critere ≥2/archetype brut (P<25 %) est insuffisant. Le
gating (`00-state.md §2.2` : early ≤2 wins = tier≤2, mid 2-4 = tier≤3, late 5+ = tier≤4)
cree des arcs temporels que le critere brut ignore. Tableau acte : rot sans payoff-late ❌,
choc sans shaper-mid ❌, wide sans rien ❌.

**Pourquoi l'accord est fort** : la comparaison sourcee par le brouillon (TFT augments —
`bunnymuffins.lol/augment-guide-for-set-13/`) est mecanistiquement JUSTE, et le pourquoi
transfere a nos contraintes. Dans TFT, les augments "directionnels" (shaper-mid equivalents)
a 2-1/3-2 orientent le build AVANT qu'il soit engage ; les payoffs en late couronnent un commit
de plusieurs rounds. La distinction n'est pas cosmétique : un archétype sans shaper-mid = le
joueur construit "en aveugle" pendant 5 combats sans signal de renforcement ; un archetype sans
payoff-late = le joueur plafonne au tier-3 quand les ghosts adverses (tier-3/4 selon
`snapstore.lua:serve`) ont des reliques tier-4. Les arcs incomplets ne sont pas equivalents
aux arcs complets en environnement async, precis√©ment PARCE QUE le joueur n'a pas de feedback
live — le snapshot adverse affronte au round 7 peut etre radicalement superieur sans que le
joueur ait eu l'occasion d'equiper son arc late.

**Ce qui tient pour nos piliers** : le gating reste deterministique (seed + wins → tirage) ;
le critere "≥1 mid ET ≥1 late" est purement documentaire et ne touche aucun invariant.

**Source** : `00-state.md §2.2` (gating) ; `src/data/relics.lua:25-67` (tiers) ;
bunnymuffins.lol/augment-guide-for-set-13/ ; round-05.md §1.10 (adoption) ; ROADMAP-draft §4.8.

### 1.3 ACCORD — `second_breath` reste universelle tier-3 (non conditionnee)

**Pourquoi l'accord tient** : `relics.lua:47` (`op="relic_second_breath"`, tier=3). Le round 3 a
correctement demonte l'analogie "conditionner comme une boss-relic StS" — dans StS, le downside
d'une boss-relic est NEGATIF et IMMEDIAT (force le joueur a construire autour, meme sans la
condition remplie). Une condition NEUTRE sur `second_breath` ("≤4 unites OU front-row") n'a aucun
effet coercitif : le joueur la prend de toute facon. Tier-3 est le seul garde-fou necessaire.
Pour nos contraintes async : `second_breath` (`secondBreath=true`, lu par `Arena:damage`) est
deterministe, elle ne depend d'aucun etat externe au snapshot. Elle n'a pas besoin de condition.

**Confirmation externe 2026** : dans Slay the Spire 2, les reliques defensives universelles
restent non conditionnees (sts2front.com/mechanics/ : "Akabeko's equivalent gives flat ATK bonus,
no conditions"). Le modele "tier=garde-fou" est la norme du genre.

**Source** : `src/data/relics.lua:47` ; r03-relics.md §2.4 ; pixelnitro.com/slay-the-spire-2-
relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/ (reliques defensives STS2).

### 1.4 ACCORD — `forked_tongue` : gating conditionnel (≥1 unite choc au build, dès 3 wins)

**Ce que le brouillon acte** (`ROADMAP-draft.md §4.7`) : `forked_tongue` (tier-4, SHAPER-MID
piege en LATE a 5+ wins) → gating conditionnel "offerte dès 3 wins SI le build a ≥1 unite choc"
(`minBuiltChoc`, champ data verifie a `rollRelicChoices`).

**Pourquoi l'accord tient** : le probleme est reel. Une relique qui ORIENTE vers le choc ne peut
pas arriver apres que le joueur a "subi" 5 combats sans orientation choc — il a deja investi dans
une autre famille. TFT positionne ses augments "directionnels" au 2-1 (avant que le build soit
engage, Riot GDC 2022). Le gating conditionnel resout le probleme sans descendre le tier, ce qui
est correct (choc = axe avance, tier-4 est justifie). La condition `minBuiltChoc` est data-only
(lu de la compo courante a `rollRelicChoices`), **deterministique si elle passe le meme RNG de
run** — invariant #3 reformule en "seed+wins+compo" (deja acte en P1.5a §4.1).

**Un garde-fou supplementaire** (non documente dans le brouillon) : il faut s'assurer que la
condition `minBuiltChoc` est evaluee depuis la compo au MOMENT de l'offre (pas a `combat_start`)
— sinon un joueur qui vend son unite choc apres le tirage garde une offre incoherente. Detail
d'implementation, mais 1 ligne de test suffit.

**Source** : `src/data/relics.lua:51-52` (`forked_tongue : shockChain=1`) ;
bunnymuffins.lol/augment-guide-for-set-13/ (augments directionnels 2-1/3-2) ; round-05.md §1.10
(adoption) ; ROADMAP-draft §4.7.

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR — `plague_communion` (+25 % flat) = le seul `more` hors-cap du systeme, sans simulation de magnitude ni borne

**Claim du brouillon** (`ROADMAP-draft.md §4.2`) : `plague_communion` est gardee "telle quelle"
(payoff multi-affliction sur la CIBLE, `afflictionCount(target.dots) >= 2` → `plagueAmp=0.25`).
Litige #J requalifie en "3 questions de tuning (sim)" a traiter ulterieurement.

**Pourquoi c'est une insuffisance critique NON resolue** :

La roadmap acte que `plagueAmp` est un `more` **hors-cap** (`arena.lua:252` : "post-cap", verifie
round-04.md §1.1). `DOT_CAP_MULT=3` (`ops.lua:22`) borne l'OUTPUT du tick DoT, pas le `more` de
`plagueAmp`. **Sur un build burn qui produit un tick base=4, cap=12 (×3) : +25 % more = 15 —
hors-cap, mais la difference n'est que 3 dmg.** Mais sur un build poison avec `festering`
(`poisonNoCap`, `ops.lua:22` leve le cap de stacks), N stacks × dps : si `festering` leve le cap
de stacks et `plague_communion` amplifie le tick resultant hors-cap, le combo peut produire des
ticks massifs sur une cible avec >8 stacks. C'est la seule interaction `more` + `poisonNoCap`
dans le systeme et elle n'est PAS simulee.

**Accessibilite concrete du seuil ≥2 familles sur une CIBLE** : le seuil est "sur la cible",
pas sur le build. La contagion (`contagion`, `ops.lua:135-140`) propage des stacks poison aux
voisins ACTIFS — une cible voisine d'une unite bleed/burn peut recevoir poison par contagion
ET etre deja exposee a burn adverse. Dans un combat a 6 vs 6 (tier-4/5), `afflictionCount(cible)
>= 2` se declenche FACILEMENT, potentiellement des le round 5-6 via le mix de familles adverses.

**Consequence pour le pool tier-4** : `plague_communion` (tier-4) est l'une des 4 reliques
tier-4. Si elle est systematiquement dominante (facile a declencher via contagion adverse +
`festering` combo), elle n'est pas un "payoff de build multi-affliction" — elle est une relique
flat-buff sur la progression naturelle du jeu, et `everburn`/`open_wounds`/`forked_tongue` lui
sont inferieures par accessibilite du seuil. **Une relique tier-4 "meilleure par defaut" dans
un tirage 1-parmi-3 detruit la decision de l'offre.**

**Ce qui est faux dans l'argument du brouillon** : la comparaison `bloodstone` (+14 % more,
tier-1, inconditionnel) vs `plague_communion` (+25 % more, tier-4, conditionnel) est presentee
comme justifiant la magnitude. Mais `bloodstone` applique son `more` sur TOUTES les attaques
TOUJOURS, tandis que `plague_communion` applique +25 % sur TOUS les degats (frappe + DoT) quand
la condition est remplie. Sur une cible multi-affliction en mid-late, `plague_communion` outperform
`bloodstone` de facon non-lineaire parce que les DoT tiquent continuellement pendant toute la duree
de l'exposition, pas seulement a la frappe. La comparaison est **non-homogene** (frappe ponctuelle
vs ticks continus).

**Proposition** : avant de "garder telle quelle" la magnitude, simuler CONFIG-PC :
- `build poison (N=4, festering) + plague_communion` vs `build poison (N=4, festering)` sans relic,
  N=50, seed `20260623`, seuil win% cible [0.55, 0.65] (relique tier-4 = avantage sans etre
  dominante). Si win% > 0.70 → reduire `plagueAmp` a 0.15 OU ajouter une borne
  `if plagueAmp > 0 then ... end` conditionnee a `afflictionCount >= 2 AND NOT poisonNoCap`
  (eviter le combo `festering`+`plagueAmp` hors-cap).

**Source** : `src/data/relics.lua:57-58` (plagueAmp=0.25, tier=4) ; `src/combat/arena.lua:252`
(plagueAmp = more post-cap, verifie round 4) ; `src/effects/ops.lua:22` (DOT_CAP_MULT=3,
poisonNoCap leve stacks) ; `src/effects/ops.lua:135-140` (contagion propagation) ;
ROADMAP-draft §4.2 (comparaison bloodstone/plague_communion). Slay the Spire boss relics with
"more" multipliers are simulated before release — gamedeveloper.com/design/gdc-2019-the-slay-the-
spire-approach-to-game-balance ("we run 18 million simulated runs per balance patch").

### 2.2 DESACCORD — L'empilement inc% (reliques B + paliers types + auras) n'est pas modele en P1.5a, le `[PH-DEPENDANT]` est insuffisant

**Claim du brouillon** (`ROADMAP-draft.md §4.8 + §7.4`) : les inc des reliques B sont marques
`[PH-DEPENDANT]` ; le double-comptage inc% (litige #B) est "borne par le cap ×3 pour l'output"
(confirme §5.2) ; le "twist de palier 4 = `more` a borner separement" est acte.

**Pourquoi c'est insuffisant — l'empilement est modelisable MAINTENANT** :

La formula `(base+Σflat)(1+Σinc)·Π(1+more)` (`stats.lua`) + le cap ×3 sur OUTPUT (pas sur inc)
laisse la zone de danger ouverte sur un BUILD CONCRET que l'on peut calculer sans sim :

**Build burn (rang-2/3, tier boutique 3)** :
- `ember_heart` (B, tier-2) : `burnInc=0.30`
- Palier type burn-2 (P1, §5.2) : `increased=0.20` (PH)
- Aura `warmth_emitter` (rang-2, `burnInc=0.25` si presente au build) : `increased=0.25`
- **Total inc = 0.30 + 0.20 + 0.25 = 0.75**
- Twist burn-4 (P1, §5.2) : `more=?` (non specifie, "borner separement")
- **Base tick burn-4 : dps=4 → tick = `(4 + 0)(1 + 0.75) × (1 + more)` = 7 × (1 + more)**
- Cap burn : `4 × 3 = 12` (output cap) → si `more = 0.80`, tick = 7 × 1.80 = 12.6 > cap → borne a 12.

OK : dans ce build, le cap tient. Mais **`burn` absorbe le bouclier** (`arena.lua:432` : burn non
`ignoreShield`, verifie round 4) → l'output effectif est reduit par les boucliers adverses.
**En presence de `sacred_shield` adverse (invulnT), les ticks burn deviennent inoffensifs pendant
30 ticks.**

**Build poison (rang-2/3, tier boutique 3)** :
- `kings_bowl` (B, tier-2) : `poisonInc=0.20`
- Palier type poison-2 (P1) : `increased=0.20` (PH)
- Aura `miasma_acolyte` (`poisonInc=0.50`, rang-2) : `increased=0.50`
- **Total inc = 0.20 + 0.20 + 0.50 = 0.90**
- Tick poison (dps=2 par stack, N stacks) : `(2 × N)(1 + 0.90)` → **ignoreShield** (decisive)
- **Cap output : `2 × N × 3 = 6N`** (cap). A 8 stacks (SHOCK_STACK_CAP=8 pour les stacks
  de shock mais poison a son propre cap), `(2×8)(1.90) = 30.4` → borne a `2×8×3 = 48` (OK, le
  cap est sur le MULTIPLICATEUR de stacks, pas la valeur). **L'aura seule depasse le cap si
  N=10+** (avec `festering`/`poisonNoCap`).

**Le probleme n'est pas le double-comptage ordinaire, c'est la COMPOSITION de 3 sources d'inc de
la meme famille** sur un seul build : relique B + palier type + aura adjacente. Sur 9 slots, avoir
une aura + une unite engagee + une relique B de la meme famille est PROBABLE des le tier-3. Le
brouillon dit "borne par le cap ×3" mais le cap sur l'OUTPUT du tick ne borne pas l'inc total —
il borne le **resultat APRES application de l'inc**. Si le cap est bas par rapport a la base
attendue, il "ecrase" la profondeur (l'inc ne sert plus a rien) ; si le cap est trop haut, le
build est sur-puissant. **Le brouillon ne precise pas la VALEUR du cap par famille**, or
`BLEED_DPS_CAP=12` (`ops.lua:28`) est separe de `DOT_CAP_MULT=3` (`ops.lua:22`) —
les familles n'ont pas toutes le meme systeme de cap.

**Proposition actionnable** : avant P1, documenter pour chaque famille DoT :
1. La **borne theorique totale** = `base_max × DOT_CAP_MULT` (ou `BLEED_DPS_CAP` selon la famille)
2. Le **seuil d'inc sature** = valeur d'inc au-dela de laquelle le cap est toujours atteint
   (la profondeur du systeme s'ecrase) : `seuil = (cap / base_min) - 1`. Ex. burn : base=1 dps,
   cap=3, seuil=2 → toute inc > 200 % = inutil au-dela de cap. Avec inc=0.75, on est LOIN
   du seuil. Mais avec `festering` + `plague_communion` + inc=0.90 sur poison sans cap de stacks,
   le seuil peut etre atteint sur les unites T3.
3. Marquer `[SATURATION_RISK]` les familles dont la stack d'inc depasse 1.0 en combinaison
   naturelle B+type+aura, **avant de specifier les valeurs des paliers de type (P1)**.

**Source** : `src/effects/stats.lua` (formule) ; `src/effects/ops.lua:22-28` (caps) ;
`src/combat/arena.lua:432` (burn absorbe bouclier) ; `src/data/relics.lua:27-29` (inc B) ;
ROADMAP-draft §5.2 (paliers type, valeurs PH) ; litige #B (ROADMAP-draft §12.2).

### 2.3 DESACCORD — `famines_math` : le litige #O n'est toujours pas tranche dans le brouillon v6, et la deadline "P1.5a" est une decision BLOQUANTE

**Claim du brouillon** (`ROADMAP-draft.md §4.5 + §9`) : `famines_math` → litige #O "a trancher
avant P1.5a" ; option (a) preferee "tes 3 unites les plus couteuses +30 % dmg / +20 % HP".
Jalon v0.9.3 = "P1.5a data pure, dont `famines_math` #O".

**Pourquoi "trancher en P1.5a" est trop tardif — l'interaction avec l'economie de slot est
CODEE maintenant** :

`famines_math` (`relics.lua:34-35` : `relic_few_units {max=3, dmgInc=0.30, hpInc=0.20}`) evaluat
`if n <= 3 then` a `R.apply`. Les grants de slots (`state.lua:50` : `SLOT_GRANT_ROUNDS={2,...,7}`,
6 grants totaux 3→9) proposent un slot par round de 2 a 7. **Le joueur qui prend `famines_math`
au round 3 (1re offre possible a ~2 wins) doit refuser 4 des 6 grants suivants** pour maintenir
le bonus — soit une perte de 4 × 3 or (si `SLOT_DECLINE_GOLD=3`) = +12 or mais aussi une perte
de capacite d'achat de rang-3/4 (3-4 slots = impossible de poser un carry et un tank
simultanement, sauf en compo tall). La relique n'est pas "anti-growth" par nature — elle est
**incompatible avec le cadeau de slot de base que LE JEU OFFRE AUTOMATIQUEMENT** chaque round.
Ce n'est pas un choix stratégique : c'est un conflit entre la mecanique de grant (passive) et la
condition de la relique (active), qui rend le joueur ADVERSE A SA PROPRE PROGRESSION par defaut.

**L'option (a) "tes 3 unites les plus couteuses" elimine ce conflit** correctement — le joueur
peut avoir 7 slots et le bonus s'applique aux 3 unites les plus couteuses de la compo, peu importe
la taille. Elle preserve l'identite tall sans l'anti-incentive.

**Mais la decision a une CONSEQUENCE SUR LES TESTS qui n'est pas mentionnee** : `R.apply`
(`relics.lua:77-106`) utilise `local n = #comp` pour evaluer la condition. La version (a) "les
3 plus couteuses" necessite de TRI de la compo par `spec.cost` (ou `spec.rank`) dans `R.apply`,
qui est aujourd'hui une iteration `ipairs` sans tri. Ce n'est pas un nouveau moteur, mais c'est
une modification de `R.apply` et donc une modification de `tests/relics.lua` (#18-21) : le test
#21 ("applyRelics ne crash pas quelle que soit la liste") doit verifier le tri par cout. Ce detail
n'est pas documente dans le jalon v0.9.3.

**Proposition** : (a) Trancher #O AVANT P1.5a (pas "en P1.5a") — la decision modifie `R.apply`
et les tests ; si on entre en P1.5a avec le code courant, la garantie B-E (§4.1) sera
implementee avec `famines_math` dans un etat indefini. (b) Specifier dans le ticket P1.5a :
"si option (a) adoptee, `R.apply` : tri `comp` par `spec.cost or spec.rank` decroissant, garder
les 3 premiers ; adapter test #21".

**Source** : `src/data/relics.lua:34-35` + `77-94` (R.apply, evaluat `n = #comp`) ;
`src/run/state.lua:50` (SLOT_GRANT_ROUNDS) ; round-04.md §1.3 (litige #O) ; ROADMAP-draft §4.5
+ §9 (jalon v0.9.3).

### 2.4 DESACCORD PARTIEL — `hollow_choir` (pierceHeal) est une relique tier-3 sans archetype distinct ni contre-jeu lisible dans le systeme actuel

**Ce que le brouillon ne mentionne PAS** (`ROADMAP-draft.md §4`, `00-state.md §2.2`) :
`hollow_choir` est listee en taxonomie C (paliers/payoffs) mais elle n'a pas recu de critique
directe en 5 rounds.

**Analyse depuis `relics.lua:37-38`** :
```lua
hollow_choir = { id = "hollow_choir", op = "relic_add_effect", tier = 3,
  params = { effect = { trigger = "combat_start", op = "grant_team", params = { pierceHeal = 0.40 } } } }
```
Le `grant_team` pose `pierceHeal=0.40` a `combat_start` (teamFlag). Cela signifie que les
afflictions de l'equipe **percent 40 % des soins ennemis** (regen, heal-on-kill, etc.). Mais
dans le systeme actuel (`00-state.md §2.1`) : **regen = 1 seule unite** (`plague_doctor`).
Heal-on-kill = 0 unite dans le roster. Les boucliers ne sont pas des "soins" au sens de `pierceHeal`
(ils absorbent des degats, pas des HP). **`hollow_choir` est une relique qui contre un archetype
qui n'existe pas encore dans le roster.** C'est un contre-jeu spectre.

**En environnement async**, le ghost adverse peut avoir `plague_doctor` (regen), mais c'est 1
unite sur 83 — `P(adversaire avec regen significatif) ≈ tres faible`. L'utilite de `hollow_choir`
est donc quasi-nulle en v0.9/v0.10, et deviendra pertinente seulement si heal-on-kill et regen
sont etendus (hors-scope actuel selon `00-state §7`).

**Pourquoi c'est un probleme de distribution de valeur** : une relique tier-3 inutile dans 95 %
des matchups n'est pas un "egalisateur" (pilier CLAUDE.md §2 : "egalisateur de matchup, jamais
un gate") — c'est du bruit dans le pool. Pire, en gating tier≤3, elle contamine les offres mid
avec une option sans valeur effective, reduisant la qualite de l'offre 1-parmi-3.

**Proposition** : Ajouter `hollow_choir` a la liste de "pool-A candidates" (retrait de `U.pool`
en attendant que le roster ait ≥3 unites avec regen/heal-on-kill). Cela fait 4 reliques a
re-evaluer pour le pool (les 3 F deja deprioritisees + `hollow_choir`). Documente dans P1.5a
comme "relique en avance sur le contenu". Zero code, zero invariant.

**Source** : `src/data/relics.lua:37-38` (hollow_choir pierce_heal=0.40) ; `00-state.md §2.1`
(regen=1 unite, heal-on-kill=0) ; pilier CLAUDE.md §2 (egalisseur) ; r05-relics.md §2.6
(approche counter-relic, Prop-E : "lire le log post-combat" — hollow_choir est l'inverse, un
counter PRE-COMBAT d'un archetype inexistant).

### 2.5 DESACCORD PARTIEL — `sacred_shield` (invulnT<30) est documentee comme tier-3 defensif mais son interaction avec le ciblage deterministe n'est pas analysee

**Ce que le brouillon ne dit pas** sur `sacred_shield` (`relics.lua:45-46`) :
```lua
sacred_shield = { id = "sacred_shield", op = "relic_add_effect", tier = 3,
  params = { effect = { trigger = "combat_start", op = "grant_team", params = { invulnT = 30 } } } }
```
`invulnT=30` signifie 30 ticks d'invulnerabilite a `combat_start` — soit 0.5 s a 60 fps. Dans
la boucle de combat, les unites tick leurs cooldowns et appliquent les DoT initiaux dans les
premiers ticks. **30 ticks a 60 fps = 0.5 s d'invulnerabilite.** Le cooldown minimal d'une unite
rang-1 est ~5-6 s (`cd ≈ 300-360 ticks`). Une unite ne peut pas frapper dans les 30 premiers
ticks — `invulnT=30` protege d'exactement 0 attaques normales.

**Mais** : les `dots` commencent a tiker a `combat_start` (si applies par effet). Si une unite
a un effet `trigger="combat_start"` qui applique un DoT, `invulnT=30` bloque ces 30 ticks de DoT
initial — soit 0.5 s de ticks bloques. Pour un `burn dps=4`, 30 ticks = 0.5 s × 4 dmg ≈ 2 dmg
bloques. Marginal. `invulnT=30` est **fonctionnellement quasi-nul** au tick-rate 60 fps actuel
(`FATIGUE_START=1020 ticks`, soit ~17 s — `invulnT=30` = 2.9 % du combat).

**Si `invulnT` est en secondes et non en ticks, le calcul change** : 30 secondes > FATIGUE_START
(17 s) = invulnerabilite sur tout le combat = relique brisee. **Il faut verifier l'unite de
`invulnT` dans `arena.lua` avant de documenter cette relique comme tier-3 defensif.**

**Proposition** : grep `invulnT` dans `src/combat/arena.lua` (lecture seule, rien a modifier)
pour confirmer l'unite. Si c'est des ticks a 60 fps, noter que `sacred_shield` a `invulnT=30`
est quasi-inerte et documenter en P1.5a comme "valeur a ajuster : `invulnT` [PH] — cible 60-120
ticks (1-2 s) pour etre visible". Si c'est des secondes, signaler bug et plafonner.

**Source** : `src/data/relics.lua:45-46` ; `00-state.md §3.2` (boucle : FATIGUE_START=1020 ticks
~17 s @ 60 fps) ; grep `invulnT` a verifier (`arena.lua`, non lu ce round — zone sans garantie).

---

## 3. Propositions priorisees

### Prop-A — Simuler `plague_communion` (+25 % more hors-cap) vs un build poison+festering AVANT de figer sa magnitude (PRIORITE 1, sim)

**Quoi** : creer CONFIG-PC dans les 4 configs de sim du brouillon (§3.4) :
- **Config PC** : `build = {festering × 2, plague_bearer, chitin_drone} + plague_communion`, plateau
  carré, `N=50`, seed `20260623`. Adversaire : ghost tier-3 snapstore ou equipe IA de rang-3/4.
- **Metriques** : win%, tick-damage/combat, pourcentage de combats ou `afflictionCount(cible) >= 2`
  se declenche (= seuil d'activation reelle). Si win% > 0.70 ou activation > 80 % des combats →
  `plagueAmp` a reduire a 0.15 OU ajouter exception `NOT poisonNoCap`.
- **Option scalante (c) (idee a l'etude, brouillon §4.2)** : `plagueAmp = f(afflictionCount_cible)`
  (2=+20 %, 3=+30 %, 4+=+40 %) — a tester dans Config PC-bis si la magnitude flat est trop haute.
  Avantage : la relique "pousse" vers plus d'afflictions sur la cible, non pas vers un seuil binaire.

**Cout** : ~20 lignes de sim (extension de la matrice 4-configs) + golden inchange (Config-PC est
une nouvelle config, pas une modification du golden). 0 invariant. **Precedent : Giovannetti GDC 2019
(MegaCrit) : "on simule 18 millions de runs par patch" — une magnitude non validee par sim est une
dette de balance, pas un PH.**

**Source** : `src/data/relics.lua:57-58` (plagueAmp=0.25) ; `src/effects/ops.lua:22` (poisonNoCap) ;
ROADMAP-draft §4.2 ; gamedeveloper.com/design/gdc-2019-the-slay-the-spire-approach-to-game-balance
(approche sim MegaCrit).

### Prop-B — Modeler la saturation d'inc par famille AVANT de specifier les valeurs des paliers de type (PRIORITE 1, doc pre-P1)

**Quoi** : avant P1 (v0.10), produire un tableau de 5 lignes (une par famille DoT) :

| Famille | `base_dps` median | Cap output | Seuil inc sature | Inc naturel max (B+aura) | Marge pour palier type |
|---------|-------------------|------------|------------------|--------------------------|------------------------|
| Burn    | 3                 | 9 (×3)     | 200 %            | 0.30+0.25=0.55           | 145 % avant saturation |
| Bleed   | 2                 | 12 (cap fixe)| 500 %          | 0.18+0.20=0.38           | 462 % avant saturation |
| Poison  | 2 (×N stacks)     | 6N (×3)    | 200 %            | 0.20+0.50=0.70           | 130 % avant saturation |
| Rot     | 2                 | 6 (×3)     | 200 %            | 0.18+0.15=0.33           | 167 % avant saturation |
| Choc    | burst (burst_DPS_eq) | §3.4a | n/a           | 0 (pas de B choc)        | 100 % entier disponible|

*(Valeurs PH indicatives — a calculer depuis `units.lua` + caps `ops.lua`.)*

Cela permet de specifier les paliers de type P1 (`+20 % inc palier-2`) sans risquer de saturer une
famille deja a 0.70 d'inc (poison : marge=130 % avant saturation → +20 % palier-2 OK, +40 % palier-4
twist = risque si la base est haute).

**Cout** : doc ~15 lignes. 0 code. Peut etre produit par `tools/sim.lua` ou calcule manuellement.

**Source** : `src/effects/stats.lua` (formule) ; `src/effects/ops.lua:22-28` (caps) ;
`src/data/relics.lua:27-29` (inc B) ; litige #B (ROADMAP-draft §12.2).

### Prop-C — Trancher #O (`famines_math`) AVANT P1.5a ET specifier la modification de `R.apply` et du test #21 (PRIORITE 1, doc + 1 ligne code)

**Quoi** : (1) Acte formellement l'option (a) "tes 3 unites les plus couteuses +30 % dmg / +20 % HP"
avant d'entrer en P1.5a. (2) Ajouter au ticket P1.5a :
- `R.apply` modification : `table.sort(comp, function(a,b) return (a.cost or a.rank or 0) > (b.cost or b.rank or 0) end)` avant la boucle `ipairs`, selection des 3 premiers seulement ;
- Adapter test #21 (`tests/relics.lua`) : verifier que le sort ne crash pas sur une compo de 1 ou 2 unites (edge-case tall extreme) ;
- Verifier que `n = #comp` est remplace par `local n_active = math.min(3, #sorted_comp)` dans la condition (eviter de bufffer les unites rang-0 si elles existent).

**Cout** : ~5 lignes code + adaptation test #21 (1 assert). 0 invariant de SIM.

**Source** : `src/data/relics.lua:77-94` (R.apply, n=#comp) ; `src/run/state.lua:50`
(SLOT_GRANT_ROUNDS) ; round-04.md §1.3 (#O) ; ROADMAP-draft §4.5.

### Prop-D — Ajouter `hollow_choir` aux candidats pool-A (retrait provisoire du pool boutique) (PRIORITE 2, doc)

**Quoi** : dans P1.5a, documenter `hollow_choir` comme "relique en avance sur le contenu" :
- Retirer de `U.pool` (meme principe que `barrier_savant/mirror_ward/surge_warden` → pool-A, acte
  brouillon §3.1) ;
- Conserver dans `R.order` pour les encounters IA qui peuvent avoir des unites avec regen ;
- Reintegrer au pool quand ≥3 unites avec regen/heal-on-kill sont dans le roster.

**Cout** : 1 ligne data (`relics.lua` : exclure de `R.order_pool` si ce champ est cree par
pool-A — sinon, note documentaire seulement). 0 invariant.

**Source** : `src/data/relics.lua:37-38` ; `00-state.md §2.1` (regen=1 unite) ;
ROADMAP-draft §3.2 (pool-A shield-renforts) — logique analogue.

### Prop-E — Verifier l'unite de `invulnT` dans `arena.lua` et documenter `sacred_shield` comme "[PH] valeur a regler" (PRIORITE 2, doc)

**Quoi** : grep `invulnT` dans `src/combat/arena.lua` (lecture seule). Documenter en P1.5a :
- Si ticks (60 fps) : noter que `invulnT=30` = 0.5 s = quasi-inerte, cible 60-120 ticks.
- Si secondes : signaler comme bug de valeur, borner a 1-2 s.
- Ajouter au tableau de tuning P3 (avec les autres PH).

**Cout** : verification grep + 3 lignes doc. 0 code, 0 invariant.

**Source** : `src/data/relics.lua:45-46` ; `00-state.md §3.2` (boucle, FATIGUE_START=1020 ticks).

---

## 4. Questions ouvertes

### Q1 — `plague_communion` : option (c) scalante sur le seuil reel (`afflictionCount` cible) ou +25 % flat garde apres sim ?

La roadmap "garde telle quelle" mais acte la sim comme action ulterieure. Ce round suggere que
la sim est **BLOQUANTE** (pas optionnelle) avant P1.5a ou P3. Si la sim montre win% > 0.70 avec
`festering`, la magnitude doit baisser — et dans ce cas, faut-il preferer la version scalante (c)
(plus elegant mais plus complexe a tester) ou simplement reduire `plagueAmp` a 0.15-0.18 ?

**Critere de reponse** : sim CONFIG-PC (Prop-A). Si activation > 80 % des combats tier-3+ et
win% > 0.65 → option (c) scalante preferee (rend la progression non-lineaire vers le commit
multi-affliction). Sinon → reduire flat.

### Q2 — `hollow_choir` devrait-elle etre reorientee pour counter les BOUCLIERS au lieu des soins ?

`pierceHeal=0.40` (40 % des soins percent) est inutile sans regen/heal adverse. Mais
"pierce des BOUCLIERS" (`pierceShield`) serait un counter-jeu valide du systeme actuel (6 porteurs
`shield_aura` + 5 `shield_caster`, cf. `00-state §2.1`). C'est un counter-jeu lisible, non-dominant
(ne detruit pas les tanks, reduit leur enveloppe temporairement). Ce serait la premiere relique
de counter-jeu actif, orthogonal aux 4 defensives existantes.

**Critere de trancher** : croiser colonne (I) de l'audit 9-col (§3.1) — "contre quoi optimal" —
pour identifier si le counter-bouclier comble un trou reellement present dans la meta (P0.5, apres
audit). Decision P1.5a.

### Q3 — Quelle est la densite de decisions reelles dans l'offre 1-parmi-3 aux tiers-3/4 ?

Tiers-3/4 au round 5+ : pool eligible = 4 C + 4 D + 4 E = 12 reliques, dont 4 tier-3 et 4 tier-4.
En retirant les F (deprioritises), les reliques potentiellement quasi-inertes (`hollow_choir`
conditionnelle) et les reliques `[PH-DEPENDANT]` dont la magnitude est incertaine (4 B), combien
d'offres tier-3/4 sont des VRAIES decisions ? **Si la reponse est ≤ 2 sur 3 en average, le pool
manque de contenu de qualite en mid-late.** Mesurable par sim (compter les offres tier≤4 dont au
moins 2 options ont un lift de co-occurrence > 0).

### Q4 — La relique de "contre-jeu meta" (Prop-E de r05-relics) est-elle toujours deferree a P3 apres l'analyse de `hollow_choir` ?

Si `hollow_choir` est recadree en counter-bouclier (Q2), elle remplit partiellement ce role.
La question du DA (#X dans les litiges brouillon) reste ouverte : "le Puits subi vs appris" —
mais le Grimoire et le post-combat "pourquoi" impliquent "appris". Si Q2 → oui, `hollow_choir`
recadree = relique de contre-jeu light (tier-3, pas conditionnee au log post-combat) qui resout
la lacune sans toucher la SIM (reinsertion dans le pool).

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| `plagueAmp=0.25` more hors-cap (post-cap) | `src/combat/arena.lua:252` (verifie round 4) |
| `DOT_CAP_MULT=3` borne output, `poisonNoCap` leve stacks | `src/effects/ops.lua:22` (verifie round 4) |
| Formule inc : `(base+Σflat)(1+Σinc)·Π(1+more)` | `src/effects/stats.lua` |
| `BLEED_DPS_CAP=12` separe de `DOT_CAP_MULT` | `src/effects/ops.lua:28` |
| `hollow_choir` : pierceHeal=0.40, tier-3 | `src/data/relics.lua:37-38` (relu ce round) |
| `sacred_shield` : invulnT=30, tier-3 | `src/data/relics.lua:45-46` (relu ce round) |
| `famines_math` : `n <= 3`, R.apply | `src/data/relics.lua:34-35 + 90-94` (relu ce round) |
| SLOT_GRANT_ROUNDS : rounds 2-7, 6 grants | `src/run/state.lua:50` (verifie round 4-5) |
| Regen = 1 unite, heal-on-kill = 0 | `00-state.md §2.1` |
| Gating reliques : tier ≤ wins | `00-state.md §2.2` ; `src/run/state.lua:339` |
| Contagion propagation voisins | `src/effects/ops.lua:135-140` (verifie round 5) |
| TFT augments directionnels early vs payoffs late | bunnymuffins.lol/augment-guide-for-set-13/ |
| Sim MegaCrit 18M runs par patch (balance) | gamedeveloper.com (GDC 2019, Giovannetti) |
| StS reliques defensives universelles non conditionnees | slaythespire.wiki.gg/wiki/Relics |
| StS marchand separe (slot dedie, pas d'offre relique de boutique) | slaythespire.wiki.gg/wiki/The_Merchant |
| STS2 reliques defensives universelles encore non conditionnees | pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/ |
| Pilier egalisateur, jamais gate | CLAUDE.md §2 ; relics.lua commentaire entete |
| pool-A (barrier_savant/mirror_ward/surge_warden) | ROADMAP-draft §3.1 colonne (H) ; round-05.md §1.12 |
| litige #B (inc% borné cap output, pas inc total) | ROADMAP-draft §12.2 + §5.2 |
| litige #J (plague_communion gardee, 3 questions de tuning) | round-05.md §2 ; ROADMAP-draft §4.2 |
| litige #O (famines_math anti-growth) | round-04.md §1.3 ; ROADMAP-draft §4.5 |

---

*Redige le 2026-06-23 par l'agent lentille-reliques, round 6/10. Lecture seule du repo de jeu.
N'edite que sous `docs/roadmap-lab/`. Piliers respectes : async snapshots / sim deterministe
seedee / DA grimdark / pixel art procedural. Sources citees par URL ou fichier+ligne.
Rounds precedents lus : r01-relics.md a r05-relics.md, round-01.md a round-05.md,
ROADMAP-draft.md (brouillon #6), 00-state.md, BRIEF.md, relics.lua (relu integrale ce round).*

Sources consultees ce round :
- [Slay the Spire Relic Tier List (Destructoid)](https://www.destructoid.com/slay-the-spire-relic-tier-list-all-relics-rated/)
- [Slay the Spire Boss Relics Ranked (Unduel)](https://unduel.com/slay-the-spire/list/the-best-boss-relics)
- [STS2 Boss Relic Guide (BrokenBuilds)](https://brokenbuilds.gg/slay-the-spire-2/guides/slay-the-spire-2-act-1-neow-boss-relic-guide)
- [STS2 Ancients Guide (NeonLightsMedia)](https://www.neonlightsmedia.com/blog/slay-the-spire-2-all-ancients-relics-guide)
- [STS2 Afflictions (sts2front.com)](https://sts2front.com/mechanics/afflictions/)
- [STS2 Status Effects (sts2.wiki)](https://sts2.wiki/status-effects/)
- [TFT Augment Guide Set 13 (BunnyMuffins)](https://bunnymuffins.lol/augment-guide-for-set-13/)
- [GDC 2019 Slay the Spire Balance Approach (GameDeveloper)](https://www.gamedeveloper.com/design/gdc-2019-the-slay-the-spire-approach-to-game-balance)
- [StS Relics Wiki (slaythespire.wiki.gg)](https://slaythespire.wiki.gg/wiki/Relics)
- [StS The Merchant (slaythespire.wiki.gg)](https://slaythespire.wiki.gg/wiki/The_Merchant)
- [Pixelnitro STS2 Relics Guide 2026](https://pixelnitro.com/slay-the-spire-2-relics-spreadsheet-guide-to-all-items-new-mechanics-and-beta-meta-2026/)
- [Progression Systems in Roguelites - Kammonen (Theseus.fi)](https://www.theseus.fi/bitstream/10024/881994/2/Kammonen_Eino.pdf)
