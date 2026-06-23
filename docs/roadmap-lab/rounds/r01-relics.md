# R01 — Critique adversariale : lentille RELIQUES

> **Round** : 1/10. **Lentille** : les 21 reliques — impact, build-defining, archetypes,
> equilibre, lisibilite, niveau de boutique.
> **Cible** : `ROADMAP-draft.md` (brouillon #1, 2026-06-23). Round initial — pas d'agent
> precedent a contester directement ; on attaque le brouillon depuis la lentille reliques.
> **Garde-fou absolu** : lecture seule du repo. Ce fichier n'edite que `docs/roadmap-lab/`.
> Piliers : async snapshots / sim deterministe seedee / DA grimdark / pixel art procedural.
> Toute affirmation de design cite sa source (URL ou fichier+ligne).

---

## 0. TL;DR — challenge cle en 3 phrases

Le brouillon traite les reliques comme un chantier de "qualite P3" (polish apres types et
ranked), mais **le pool de 21 reliques contient des problemes structurels qui ne se resolvent
pas par calibration sim** : des archétypes entiers sont non-adresses (choc, wide, tall), et
les reliques les plus puissantes (E/F tier 4) n'ont pas de condition d'activation — elles
deviennent des pick-auto independants du build, ce qui est l'exact oppose du "build-defining".
Le brouillon emprunte le vocabulaire de StS ("1 regle modifiee") mais ne verifie pas si les
21 reliques actuelles respectent ce critere. Ma critique principale : **reclasser la passe de
qualite reliques de P3 a P1bis** (avant ou avec les synergies de type, pas apres), parce que
des reliques qui ne shapen pas les builds vident la promesse de choix de chaque offre 1-parmi-3.

---

## 1. Accords — ce qui tient pour NOS contraintes

### 1.1 Le modele lisible (pivot 2026-06) — ACCORD FORT

Le brouillon retient le pivot vers les reliques lisibles (`relics-design.md §1`, decision #7
de `00-state.md §1`). Ce pivot est correct et bien etaye. La comparaison avec StS tient ici :
le principe psychologique derriere les reliques de StS n'est pas le mystere (les reliques communes
sont toutes visibles et explicites : wiki slaythespire.wiki.gg/wiki/Relics), c'est la **lisibilite
immediate de l'impact sur le build**. Le joueur voit "Akabeko : +8 atk au 1er tour" et sait
immediatement si ca entre dans sa build en cours. C'est le meme principe que notre modele.

Pourquoi ca tient pour The Pit : le modele async implique que le joueur ne voit jamais son
build jouer en live (le combat est spectateur). La lisibilite pre-combat est donc le seul
moment ou le joueur peut evaluer une relique — un effet cryptique n'a aucune chance d'etre
compris correctement. Le pivot lisible est non-negociable.

**Source** : slaythespire.wiki.gg/wiki/Relics (consulte 2025) ; decision #7 `00-state.md §1`.

### 1.2 Le gating par avancee (early→mid→late) — ACCORD CONDITIONNEL

Le brouillon retient le gating : early (0-1 win) → tier ≤ 2 ; mid (2-4) → ≤ 3 ; late (5+)
→ ≤ 4. Ce principe est correct dans son intention (eviter que le joueur recoive une relique
E/F transformative au round 1 avant d'avoir un build coherent). La source psychologique tient :
le "near-miss sous agence" de StS (slay-the-spire.md §3.2) exige que la relique soit percue
comme meritee et contextuelle.

**Le conditionnel** : le gating actuel ne garantit pas qu'une relique gated ≤ tier 2 soit
pertinente pour le build en cours. On peut recevoir `thornguard` (epines d'equipe, tier 2)
avec un build poison pur — c'est un choix de "quelle poubelle prendre". Ce n'est pas du gating
qui cree du sens.

### 1.3 Le tirage 1-parmi-3 Fisher-Yates seede — ACCORD TOTAL

Le mecanisme de tirage (invariant #3 : meme seed+wins → meme offre) est une force architecturale
du systeme. Le fait que le tirage soit seede et reproductible permet des discussions communautaires
("quelle relique aurais-tu prise a ce round ?") — analogue a la seed publique de Balatro
(balatro.md §4.2) et du Daily Climb de StS (slay-the-spire.md §7.3). C'est un avantage que le
brouillon note correctement pour le Daily Seede (§5).

Pourquoi ca tient : le determinisme est pilier #2 et invariant #1-5. Le tirage seede Fisher-Yates
ne conflicte avec aucun pilier.

### 1.4 Le decline → +3 or — ACCORD

La consolation `DECLINE_RELIC_GOLD = 3` est validee par le Bazaar (the-bazaar.md §5.4) comme
"consolation prize psychologiquement important". Elle transforme "je n'ai pas voulu aucune des 3"
en "j'ai eu de l'or pour chercher autre chose". A 10 or/round et reroll a 1 or, 3 or = 3 rerolls
— c'est substantiel mais pas dominant. Le ratio semble bien calibre.

---

## 2. Desaccords — ce qui est faible, manquant ou faux dans le brouillon

### 2.1 DESACCORD MAJEUR : la passe de qualite reliques est classee trop tard (P3)

**Claim du brouillon** (§6.5) : "auditer les 21 reliques pour que les plus memorables
modifient une regle [...] apres que les types et le ranked existent". Priorite P3.

**Pourquoi c'est un probleme** : le brouillon lui-meme affirme que les reliques doivent etre
"build-defining" (§6.5, citant Balatro §5.3). Mais si les reliques restent en etat [PH] — avec
des valeurs non calibrees et des archetypes non couverts — pendant tout P0-P2, CHAQUE offre
1-parmi-3 sera une "dead choice" (tft.md §V5 : "1 seule option pertinente = choix factice").
Un systeme ranked construit sur des offres de reliques creuses ne peut pas mesurer le skill
de build — il mesure la chance d'avoir recu une relique pertinente.

**La logique de sequencement du brouillon se retourne contre elle-meme** : le brouillon place
le ranked en P2 avec l'argument que "les synergies de type enrichissent le contenu AVANT qu'on
demande au joueur d'enchaîner 100 runs" (§1). La meme logique s'applique aux reliques : une
relique 1-parmi-3 qui ne shapen pas le build vide l'espace de decision bien avant que le ranked
soit en place.

**Evidence directe dans le code** : `relics.lua` ne contient aucune relique pour :
- L'archetype **wide** (go-wide, 6-9 unites sur le plateau) : `swarm_logic` est cite dans
  `relics-design.md §5` comme relique pour cet archetype, mais **elle n'est pas dans les 21**.
- L'archetype **choc** : `forked_tongue` (rebond de choc) existe (tier 4, E) mais est gated
  ≤ 4 en late seulement ; pas de relique choc tier 2-3.
- L'archetype **bouclier pur** (shield-tank sans DoT) : aucune relique n'amplifie directement
  les boucliers (shield_aura, shield_caster) au build.
- L'archetype **poison apex** tel qu'il existe (15 unites dans le pool) : `kings_bowl` incline
  deja le matchup mais avec `inc = 0.20` vs `ember_heart` a `0.30` — le poison qui est deja
  l'archetype dominant est amplifie le moins fort des 4 amplis B. Ce desequilibre de valeurs
  est une dette de calibration, mais il revele aussi l'absence d'un axe de design : pourquoi
  le poison a-t-il besoin d'un ampli si c'est deja l'apex ? Et s'il n'en a pas besoin, le
  slot `kings_bowl` ne devrait-il pas etre occupe par quelque chose qui adresse un archetype
  sous-represente ?

**Source** : `src/data/relics.lua` (lecture directe, 2026-06-23) ; `relics-design.md §5`
(archetype → relique mapping). Voir aussi `00-state.md §2.2` : "taxonomie (vagues 1-4) [...].
G — topologie/sigils = DIFFERE".

### 2.2 DESACCORD : les reliques E/F (tier 4) ne sont pas build-defining — elles sont pick-auto

**Claim implicite du brouillon** (§6.5) : enrichir les reliques "T3 simplifies" pour qu'elles
"modifient une regle". Les reliques E existantes (`forked_tongue`, `everburn`, `open_wounds`,
`plague_communion`) sont presentes comme des reliques transformatives build-defining.

**Pourquoi c'est incorrect** :

`plague_communion` (si 2+ afflictions actives → +25% de tous les degats d'equipe) est un
pick-auto pour TOUTE equipe mixte. 83 unites couvrent 5 familles DoT — avoir 2+ afflictions
actives en combat est la norme, pas l'exception. Cette relique n'active pas un archetype, elle
buffait toujours. Ce n'est pas une "regle modifiee", c'est un "+25% de degats" conditionnel
que presque toute composition active.

`everburn` (les feux ne decroissent jamais) est build-defining pour burn, ce qui est correct.
Mais elle est gated tier 4 / late. Un joueur burn ne peut la recevoir qu'apres 5 wins. C'est
6+ combats avec un build burn en transition sans le payoff de la relique signature. La courbe
d'engagement de ce build est plate jusqu'au late.

`second_breath` (chaque unite survit 1x a 1 PV) est une defensive pure — pick-auto aussi en
late. Elle ne shapen pas le build, elle allonge tous les combats uniformement.

**La reference StS ici est mal appliquee dans le brouillon** : dans StS, les boss-reliques
(les plus puissantes, analogues aux tier 4) ont un **downside calibre** qui FORCE un archetype
(slay-the-spire.md §2.2 : "Busted Crown pushes toward a small efficient deck"). Le downside
est le mecanisme qui rend la relique build-defining. Les reliques E/F de The Pit n'ont aucun
downside, ce qui est une decision actee (`relics-design.md §1` principe #2 : "aucune relique
ne handicape"). Mais alors, sans downside, une relique tier 4 doit etre **conditionnelle a
un archetype specifique** pour eviter d'etre pick-auto. Les reliques E actuelles ne satisfont
pas cette condition sauf `everburn` et `open_wounds`.

**Source** : slay-the-spire.md §2.2 (psychologie des boss-reliques avec downside) ;
`src/data/relics.lua` lignes 51-61 (reliques E actuelles) ; `relics-design.md §1` principe #2.

### 2.3 DESACCORD : la garantie de composition de l'offre est trop faible comme formulee

**Claim du brouillon** (§6.4) : "garantir qu'au moins 1 des 3 reliques offertes est de tier
A ou B (stat plate / ampli basique) — pas 3 reliques E/F inutilisables pour le build courant".

**Insuffisant** : une relique tier A ou B peut etre aussi "morte" qu'une tier E si elle
n'adresse pas le build courant. `kings_bowl` (+20% poison) pour un build bleed pur est une
poubelle aussi surement que `plague_communion`. La garantie "au moins 1 de tier ≤ 2" est une
garantie de tier, pas de pertinence pour le build.

**Ce qui est necessaire** : une garantie de PERTINENCE, pas seulement de tier. Le brouillon
cite HS:BG ("au moins 1 trinket a cout ≤2", hs-battlegrounds.md §8.3) mais sans demontrer
que la logique survit — dans HS:BG, les trinkets bas tier sont quasi-universellement utiles
(stats brutes). Dans The Pit, meme les reliques tier 1 sont contextuelles (`aegis` est inutile
si votre strategie est d'aller vite avant que l'adversaire ne vous touche).

**La solution du brouillon est une amelioration necessaire mais pas suffisante.** Elle doit
etre coompletee par un mecanisme de drought protection archetype (propose par slay-the-spire.md
§3.4 : "augmenter progressivement le poids des reliques pour l'archetype dominant du joueur")
pour etre vraiment impactante.

**Source** : slay-the-spire.md §3.4 (drought protection contextualise) ; hs-battlegrounds.md
§8.3 ; `src/data/relics.lua` (lecture de la distribution des archetypes couverts).

### 2.4 DESACCORD : les reliques F (runOp) sont des archétypes a part entiere non-traitees

**Claim implicite du brouillon** : les reliques F (`carrion_ledger`, `black_summons`,
`beggars_lantern`) sont citees comme partie du pool mais ne sont pas challengees sur leur
design.

**Probleme** : ces 3 reliques agissent sur l'**economie du run** (`runOp`), pas sur le combat.
Elles sont qualitativement differentes des A-E — prendre `black_summons` (tier 4, +1 tier de
boutique) est une decision economique, pas une decision de build. Ce n'est pas un "foyer
d'archetype" au sens de `relics-design.md §1` principe #4 ("Si on ne peut pas nommer ce build
veut ca, c'est du remplissage").

Or en pratique :
- `black_summons` est un pick-auto en mid-game pour tout le monde car monter de tier ouvre
  l'acces aux rangs 4-5 qui contiennent les unites carries.
- `carrion_ledger` (bond d'XP +6) est un pick-auto en early pour tout le monde si la boutique
  n'est pas encore au tier optimal.
- `beggars_lantern` (cotes 1 tier plus bas) a un foyer defensif identifiable : le joueur qui
  veut maxer les unites bas-rang pour les duplicatas. Mais meme ce foyer est fragile — le joueur
  qui monte en tier boutique pour fuir les bas-rangs n'a aucune raison de prendre cette relique.

Ces 3 reliques sont economiques utiles, mais leur presence dans le pool 1-parmi-3 dilue les
offres de build-shaping. Dans StS, les reliques de shop (analogues : Membership Card, Chemical X)
sont dans un **slot separe** du shop (3e slot toujours une relique shop) pour ne pas entrer en
competition avec les reliques de build (slay-the-spire.md §2.1). La seule relique StS de shop
qui "compete" avec les reliques de build est le fait de choisir d'aller au shop ou non — et ce
choix est spatial (pathing), pas un tirage 1-parmi-3.

**Proposition** : les reliques F devraient etre dans un canal distinct de l'offre 1-parmi-3,
ou constituer un slot garanti (ex. : une des 3 reliques offerte est toujours une runOp si on
n'en a pas encore, les 2 autres sont des reliques de build). Cette separation preserve l'espace
de decision build-shaping sans supprimer l'axe economique.

**Source** : slay-the-spire.md §2.1 (slot shop fixe pour reliques de shop) ;
`relics-design.md §1` principe #4 ; `src/data/relics.lua` lignes 63-66.

### 2.5 DESACCORD PARTIEL : le cap ×3 et le double-comptage (litige #B du brouillon)

**Claim du brouillon** (§3.2, Litige #B) : "les types DoT creent-ils un double comptage avec
les amplis d'affliction (reliques B) et les auras d'acolytes existantes ? A simuler avant de
figer les valeurs."

Ce litige est correctement identifie comme ouvert. Mais il manque un chiffre crucial pour
evaluer la gravite du probleme. En lisant le code (`ops.lua:22` : `DOT_CAP_MULT = 3`) et la
formule de `stats.lua` :

```
dps_final = (base + Σflat) × (1 + Σincreased) × Π(1+more)
```

L'aura `miasma_acolyte` bake `poisonInc` sur ses voisins. La relique `kings_bowl` ajoute
`inc = 0.20`. Ces deux `increased` s'additionnent (formule : `Σincreased` = additif). Si un
joueur a `miasma_acolyte` en adjacence (disons `poisonInc = 0.30` bakee sur le voisin) et
prend `kings_bowl` (`poisonInc += 0.20`), le voisin a maintenant `(1 + 0.50)` en increased.
Avec `DOT_CAP_MULT = 3` et `base dps = 8`, le cap est `8 × 3 = 24`. Avec inc = 0.50, on est
a `8 × 1.5 = 12` — bien sous le cap. Le probleme n'est pas le cap mais la **puissance
marginale de la relique B une fois qu'une aura est en place** : `kings_bowl` dans ce contexte
passe le dps de 12 a 12 (puisque l'aura a deja mis a 12) si le cap s'applique en valeur
absolue, ou de `8 × 1.3 = 10.4` a `8 × 1.5 = 12` (gain +1.6 dps). Ce gain est reel mais
modeste — la relique n'est pas overpowered en presence d'une aura.

**Le vrai probleme de double-comptage vient des reliques E avec les synergies de type proposes**
(P1 du brouillon). Si un palier de type burn 4 accorde un `increased` de 20% supplementaire, et
que `ember_heart` ajoute 30%, et que `soot_acolyte` en adjacence bakee 40%, on peut atteindre
`(1 + 0.90)` en increased avant le cap. Avec base dps = 8 : `8 × 1.9 = 15.2` vs cap 24.
Toujours sous le cap, mais proche a 3 niveaux de buff combines. Ce scenario est seulement
possible au T3 boutique avec une build tres committee — ce qui est exactement quand le cap doit
etre atteint pour signaler un combo tres fort. Le cap × 3 est donc sain comme anti-snowball.

**La vraie question non-posee** : `plague_communion` (+25% de TOUS les degats) est une
relique `relic_add_effect` qui pose `plagueAmp = 0.25`. Ce flag est-il soumis au cap × 3 ?
En lisant `ops.lua`, `plagueAmp` amplifie les degats en `damage()` via un multiplicateur
direct — ce n'est PAS un `increased` dans `stats.lua`. Il contourne donc le cap. Si plague_communion
est pris en plus d'un `increased` au cap (via aura + relique B), le multiplicateur `plagueAmp`
s'applique en dehors du cap. Ce pourrait etre un exploit latent.

**Source** : `src/effects/ops.lua` (DOT_CAP_MULT = 3, ligne 22) ; `src/effects/stats.lua`
(formule de resolve) ; `src/data/relics.lua` lignes 57-61 (plague_communion) ; ce point
**necessite verification en code** avant de finaliser §3.2.

---

## 3. Propositions priorisees — ce que la lentille reliques recommande au brouillon

### P0 — Passe de completude archetype (1-2 semaines de design data, zéro code nouveau)

**Probleme** : archetypes non-adresses dans les 21 reliques actuelles.

**Actions specifiques** :
1. **Wide** : ajouter `swarm_logic` (mentionne dans `relics-design.md §5` mais absent de
   `relics.lua`). Effet lisible candidate : "Si l'equipe a ≥ 6 unites : chaque unite gagne
   +1 PV et +X% dmg par unite au-dessus de 5" [PH valeurs]. Archetype : go-wide sur anneau
   ou diamant (sigils a 8-12 aretes, CLAUDE.md §3 tableau sigils). Tier 3.
2. **Bouclier amplifie** : une relique qui amplifie les auras de bouclier (ex. "+50% de la
   valeur de bouclier baked sur les voisins") pour distinguer l'archetype tank-shield du
   tank-taunt. Tier 2.
3. **Choc mid-tier** : une relique choc tier 2-3 qui adresse la "fragilite choc" sans attendre
   `forked_tongue` tier 4 (ex. "+N volt par stack a la decharge" ou "les stacks de choc ne
   decroissent pas si la cible ne reçoit pas de coup pendant X s"). La hiérarchie diagnostiquee
   poison > tank > ... > choc (`00-state.md §7.1`) a besoin d'un levier mid-game, pas seulement
   d'un levier late.

**Cout** : data-only, testable via `tools/sim.lua` avant d'ajouter au pool. N'affecte aucun
invariant de test existant (les reliques sont hors du golden #5 par design gated).

**Source** : `relics-design.md §5` (archetype → relique mapping incomplet) ; `00-state.md §7.1`
(dette "ladder choc 5/3/2") ; CLAUDE.md §3 (sigils et archetypes).

### P1 — Separer le canal des reliques F (runOp) du pool de build

**Probleme** : les reliques F (economiques) diluent les offres build-shaping.

**Action** : structurer l'offre 1-parmi-3 comme suit :
- Si le joueur n'a pas encore de relique runOp : l'une des 3 est toujours une runOp (garanti).
- Sinon : les 3 sont des reliques de build (A-E).
- Cette contrainte doit etre deterministe (appliquee avant le Fisher-Yates seede, invariant #3).

**Alternative plus simple** : separer entierement en deux pools et proposer au marchand (tous
les N combats) une relique runOp en plus de l'offre normale 1-parmi-3. Cette option s'aligne
avec la "marchand tous les 3 combats" mentionne dans `00-state.md §7` (non encore implemente).
Le marchand vendrait des runOp (et peut-etre des reliques A-B de tier bas) ; l'offre 1-parmi-3
normale se concentre sur les B-E.

**Source** : slay-the-spire.md §2.1 (slot shop fixe hors competition avec reliques de build) ;
`00-state.md §7` (marchand /3 combats, TODO).

### P2 — Ajouter un drought protection archetype pour l'offre reliques

**Probleme** : le Fisher-Yates seede est equitable mais pas contextuel. Un joueur
qui a 70% d'unites burn peut ne voir aucune relique burn pendant 3 offres consecutives.

**Action** : implementer un weight-modifier sur le pool de reliques base sur la composition
en cours. Si la composition a X% d'unites d'un type (calculable depuis `build.units` au
moment de `rollRelicChoices`), augmenter progressivement le poids des reliques de ce type
dans le tirage. Ce n'est pas garantir la relique — c'est augmenter sa probabilite comme le
"rare climb" de StS (slay-the-spire.md §3.2).

**Garde-fou invariant** : ce mecanisme doit rester deterministe. Le weight-modifier doit etre
calcule depuis l'etat de run seede (pas de capture d'etat non-seede). Invariant #3 (meme
seed+wins → meme offre) : **ce mecanisme viole potentiellement l'invariant #3 si le weight
depend de la composition actuelle** (qui peut etre differente selon les actions du joueur
avec le meme seed). Il faut soit :
- Tirer le weight depuis l'etat de run purement seede (pas la composition), ou
- Accepter que l'invariant #3 soit reformule : "meme seed + meme composition a ce round →
  meme offre" (ce qui est plus correct du point de vue du replay).
Cette modification **exige un test adapte AVANT l'implementation**.

**Source** : slay-the-spire.md §3.2 ; `tests/relics.lua` (invariant #3 dans `seed/tests.md §6`).

### P3 — Conditionner les reliques E tier 4 pour les rendre build-defining

**Probleme** : `plague_communion` et `second_breath` sont des picks-auto independants du build.

**Action** : retravailler les reliques E non-conditionnelles :
- `plague_communion` : changer la condition de "2+ afflictions actives" (trop facile) a "si
  l'equipe a ≥ 4 unites partageant une meme affliction" (aligne avec les paliers de type
  P1 du brouillon). Cela en fait une synergie explicite avec les types DoT.
- `second_breath` : ajouter une condition de build ("seulement si la compo a ≤ 3 unites",
  creant une synergie avec `famines_math` pour l'archetype tall, ou "seulement pour les
  unites en front-row" pour creer une synergie avec le placement).
- Verifier que `plagueAmp = 0.25` dans `arena.lua:damage` est soumis au cap ×3 global ou
  document explicitement comme etant hors-cap (cf. §2.5 ci-dessus).

**Cout** : data-only (params des reliques existantes, pas de nouveau code). Necessite de
mettre a jour les tests de synergies reliques (`tests/relics.lua`, invariants #18-21).

**Source** : slay-the-spire.md §2.2 (scope conditionnel des boss-reliques comme remplacement
du downside) ; `relics-design.md §4-E` ; `00-state.md §3` (cap DOT_CAP_MULT).

### P4 — Retablir l'amplification de la relique B pour le choc

**Probleme** : aucune relique B pour le choc (`shockInc`). Les 4 reliques B couvrent burn,
bleed, poison, rot — mais pas shock.

**Action** : ajouter une 5e relique B pour shock. Effet candidat : "+X stacks de choc poses
a chaque frappe" ou "+X% volt de decharge" [PH]. Tier 2. La hiérarchie
poison > tank > ... > choc ne peut pas etre corrigee uniquement avec le "ladder choc 5/3/2"
(contenu d'unites) si aucune relique n'incline le matchup pour un build choc engage.

**Verification a faire en code** : l'op `relic_affliction_inc` supporte-t-il `family = "shock"` ?
Les ops de choc ne sont pas amplifie par `*Inc` de la meme maniere que les DoT (le choc est
un condensateur, pas un dps continu). Il faudrait peut-etre un op specifique
`relic_shock_inc { volt_mult }` qui augmente le `volt` des unites choc au build. Ce point
**necessite une verification de plomberie avant d'etre une proposition actee**.

**Source** : `seed/mechanics.md §2.6` (modele choc, `volt`-based) ; `src/effects/ops.lua`
(relic_affliction_inc) ; `00-state.md §7.1` ("ladder choc" comme levier different).

---

## 4. Questions ouvertes

1. **Litige #B (brouillon §3.2)** : `plague_communion.plagueAmp` est-il soumis au cap ×3
   de `DOT_CAP_MULT` ? Si non, c'est un exploit potentiel en interaction avec les buffs
   increased. Necessaire de verifier dans `arena.lua:damage` AVANT de finaliser P1 (types).

2. **Reliques F dans un canal separe** : le marchand /3 combats (`00-state.md §7`) est le
   canal naturel pour les runOp. Mais le marchand n'est pas encore code — quel est le cout
   d'implementer le canal separe dans l'offre 1-parmi-3 en attendant ? Cela implique de
   modifier `rollRelicChoices` de maniere deterministe.

3. **wide vs diamant** : l'archetype wide est servi par le sigil diamant (CLAUDE.md §3 :
   "go-wide / essaim"). Si `swarm_logic` est conditionnelle (≥ 6 unites), elle ne devient
   pertinente qu'apres l'ouverture de 6 slots (round 4-5 minimum, `MAX_GRANTS = 6` sur
   rounds 2-7). Le gating naturel de la relique est donc par nombre de slots, pas par wins.
   Faut-il ajouter ce parametre au gating de l'offre (proposer swarm_logic seulement si le
   joueur a ≥ 5 slots ouverts) ? Sinon, c'est une relique receivable au round 3 qui est
   encore sans effet.

4. **Choc et plomberie shockInc** : l'architecture ops supporte-t-elle un `relic_affliction_inc`
   pour shock, ou faut-il un op dedie ? Cette verification technique bloque la proposition P4.

5. **Echelle des archetypes dans les reliques** : avec 83 unites et 5 familles DoT + bouclier +
   tank + bruiser + choc, combien de reliques sont necessaires pour qu'un joueur engage une
   famille specifique ait toujours au moins 1 relique pertinente parmi ses 3 offres ? Avec
   21 reliques dans le pool et 5 familles DoT + 4 autres archetypes, la distribution garantit
   statistiquement combien de reliques relevantes en 3 picks ? Ce calcul doit etre fait pour
   justifier le nombre final de reliques dans le pool.

6. **Reliques G (topologie/sigils)** : le brouillon les classe en P4 (v0.12). Mais si les
   synergies de type P1 sont alignees sur les sigils (anneau → propagation, croix → mono-carry,
   etc.), les reliques G renforcent cette logique de maniere naturelle. Faut-il au moins
   concevoir 1-2 reliques G prototypes en meme temps que les types pour valider la coherence
   du systeme ?

---

## 5. Index des sources

| Affirmation | Source |
|-------------|--------|
| StS boss-reliques avec downside / scope conditionnel | slay-the-spire.md §2.2 ; slaythespire.wiki.gg/wiki/Relics |
| Rare climb / drought protection contextualise | slay-the-spire.md §3.2 |
| "1 regle modifiee" = build-defining | balatro.md §5.3 ; rogueliker.com/balatro-interview/ |
| Dead choices en offre de reliques (TFT) | tft.md §V5 |
| Garantie de composition (HS:BG) | hs-battlegrounds.md §8.3 |
| Pool separe ranked/normal ; pools de ghosts | the-bazaar.md §8.4, §9.4 |
| Slot shop separe (StS) | slay-the-spire.md §2.1 |
| Cap × 3 (anti-snowball) | `src/effects/ops.lua:22` (DOT_CAP_MULT = 3) |
| Formule de modificateurs | `src/effects/stats.lua` |
| 21 reliques (liste complete) | `src/data/relics.lua` |
| Archeytpes non-adresses | `relics-design.md §5` ; `src/data/relics.lua` |
| Hierarchie poison > choc | `00-state.md §7.1` ; the-pit-balance-diagnosis (memoire) |
| Gating offre reliques | `00-state.md §2.2` ; `src/run/state.lua` (`rollRelicChoices`) |
| Invariants reliques #18-21 | `seed/tests.md §6` |
| plagueAmp hors-cap potentiel | `src/data/relics.lua` lignes 57-61 ; `src/combat/arena.lua:damage` |
| Decline +3 or (consolation prize) | `00-state.md §4.1` (DECLINE_RELIC_GOLD = 3) ; the-bazaar.md §5.4 |

---

*Redige le 2026-06-23 par l'agent lentille-reliques (roadmap-lab round 1). Lecture seule du
repo de jeu. Edite uniquement sous `docs/roadmap-lab/`. Piliers respectes : async snapshots /
sim deterministe seedee / DA grimdark / pixel art procedural. Sources citees par URL ou
fichier+ligne pour chaque affirmation de design.*
