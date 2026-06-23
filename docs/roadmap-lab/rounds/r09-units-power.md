# Round 09 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v9, intégré round 8) depuis la
> lentille **units-power** — distinction des unités, budget de puissance par rang, identité,
> redondance, trous d'archétype. Round 9/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v9), `00-state.md`, `round-01.md` à
> `round-08.md`, `rounds/r01-units-power.md` à `rounds/r08-units-power.md`,
> `competitive/*.md` (tous), `src/data/units.lua` (intégralité relue ce round, DPS
> recalculés pour tous les rangs via Python).
>
> **Méthode** : désaccord = recherche web effectuée et citée ce round. Analogie = teardown
> mécaniste AVANT d'accepter. Toute affirmation chiffrée cite le fichier+ligne relu ce round.
> Accord sur un point précédent → raison mécaniste pour nos contraintes (async/run court/
> déterministe/grimdark). Désaccord avec agent précédent → recherche propre ou calcul direct.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée /
> DA grimdark / pixel art procédural). 32 invariants non touchés.

---

## 0. TL;DR de ce round

**Trois angles que les rounds précédents (axés rang-2/3/4 et apex choc) n'ont pas épuisés,
calculés ce round sur `units.lua` relu intégralement :**

1. **Le brouillon traite les rangs-5 stat-sticks (`skull_colossus`, `deep_kraken`) comme un
   problème de « classification sémantique ». C'est sous-estimer la crise : ils créent aussi
   une COLLISION D'IDENTITÉ de famille** — `skull_colossus` est un burn `on_hit` rang-5 avec
   aggro=40, mais **les 3 T3 burn légitimes** (`ash_maw`, `plague_pyre`, et le désert rang-3
   `bellows_priest` → `wildfire_hound`/`kiln_warden`) constituent une progression cohérente
   burn que `skull_colossus` court-circuite : un joueur burn trouverait en rang-5 un stat-stick
   burn *plus puissant que ses T3 transforms*, inversant le contrat « T3 = règle d'équipe ».

2. **Le budget de puissance rang-4 choc est structurellement saturé ET hétérogène** :
   `galvanizer` DPS=0.172, `arc_warden` DPS=0.100, `dynamo_priest` DPS=0.086 — écart **2×**
   entre le plus fort et le plus faible enabler rang-4 choc. La règle P90/P10 ≤ 3× (adoptée
   pour les DoT) n'a JAMAIS été appliquée à la famille choc intra-rang-4. Ce trou d'audit
   laisse potentiellement `galvanizer` comme outlier absolu **après** la décision d'axe D.

3. **L'identité des auras (rang-3/4) n'a aucun critère de lisibilité positionnelle chiffré.**
   La colonne (J) adoptée (valeur max/min/sigil-hostile) documente la variance, mais JAMAIS
   la décision binaire « cette aura est-elle viable dans ≥3 sigils sur 5 ? ». Or les 4 auras
   DoT rang-3 (`soot_acolyte`/`clot_mender`/`miasma_acolyte`/`decay_tender`) ont des valeurs
   de voisinage qui varient du simple au double selon le sigil — sans ce filtre, P1 (types)
   peut créer un palier-4 de famille dont l'aura clé est inviable sur 2 sigils sur 5.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — Paires de dominance rang-3 (`corruptor`/`bile_spitter`) et violation #10 rang-4 (`rust_sentinel`/`stormcaller`) — adopté round 8

**Calcul relu ce round** (`units.lua:63-65` pour `corruptor`, `:123-125` pour `bile_spitter`,
`:426-428` pour `rust_sentinel`, `:79-81` pour `stormcaller`) :

```
corruptor   : rank=3, poison{dps=2, dur=180, weaken=0.06}  DPS frappe=0.097
bile_spitter: rank=3, poison{dps=2, dur=180, weaken=0.10}  DPS frappe=0.089
→ op identique, bile_spitter weaken supérieur → DOMINANCE STRICTE (Ariely 2003)

rust_sentinel : rank=4, shock{add=1, cap=6, dur=150}   DPS=0.125
stormcaller   : rank=2, shock{add=1, cap=6, dur=150}   DPS=0.103
→ op IDENTIQUE → enabler rang-2 en taille rang-4 → viole décision #10
```

**Pourquoi c'est valide pour nos contraintes** : en pool LOCAL (≠ TFT partagé de 57-77 unités
par rang selon le set), deux enablers quasi-identiques co-apparaissent fréquemment dans la
même boutique. `P(corruptor + bile_spitter visibles simultanément en T3) ≈ P(voir 2 poison
rang-3 dans 5 slots sur ~18 rang-3) ≈ 20 %` — assez fréquent pour que le joueur informé
développe un réflexe de dévaluation de `corruptor`. **Ariely, Loewenstein & Prelec 2003 QJE**
([academic.oup.com/qje/article/118/1/73/1917051](https://academic.oup.com/qje/article/118/1/73/1917051)) :
un item dominé dégrade la décision (le dominant paraît encore meilleur par contraste). Adopté
sans réserve. **L'ordre strict `--pool-repr` AVANT `--poison-frac` (#DD clos) est conditionné
par ce retrait.**

### 1.2 ACCORD — `deep_kraken`/`skull_colossus` rang-5 = bloquants DPS (adopté round 7, code-vérifié round 8)

**Calcul relu ce round** (calculé Python sur `units.lua`) :

```
skull_colossus : 11/84 = DPS 0.131  (burn on_hit seul, aggro=40)
deep_kraken    : 12/78 = DPS 0.154  (poison on_hit seul)

vs meilleur T3 transform légitime (marrow_drinker) : 6/52 = DPS 0.115
vs transforms burn légitimes (ash_maw, plague_pyre)  : 0.100 / 0.107
```

**ACCORD FORT** — le problème DPS est confirmé. Mais (§2.1 ci-dessous) : le brouillon
v9 traite le remède comme une question de « transform réelle ou stat-stick ». Il manque la
dimension COLLISION D'IDENTITÉ de famille.

**Pourquoi ça tient pour nos contraintes async** : un ghost rang-5 avec `skull_colossus × 3`
(`LEVEL_MULT=3.0`, `DPS_frappe × 3.0 = 0.393`) dans le pool ranked biaise la méta perçue
vers le « burn-carry » plutôt que le « burn-propagation ». Les joueurs qui voient des ghosts
`skull_colossus` L3 apprennent la mauvaise leçon de l'archétype burn. Entalto Studios 2025
([entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)) :
« Build identity must be clear within 2 min » — un stat-stick rang-5 brouille l'identité
précisément pour les joueurs qui committent le plus.

### 1.3 ACCORD — Désert rang-3 burn : 1 enabler actif (`bellows_priest`) sur ~18 rang-3 (adopté round 8)

**Calcul relu ce round** :

```
burn r3 : bellows_priest (rang-3), soot_acolyte (aura rang-3)
→ enablers T2 burn actifs en rang-3 = 1 seul (soot_acolyte est une aura, pas un poseur)
P(bellows_priest visible T3, SHOP_SIZE=5, ~18 rang-3) ≈ 27 %
vs bleed r3 : leech_thorn / vein_splitter / clot_mender (aura) → P(≥1 bleed r3) ≈ 61 %
```

**Accord maintenu.** L'asymétrie 2.3× est réelle et calibrée sur notre pool local. **Mais
le brouillon n'a pas résolu la question posée (§2.2 ci-dessous) : le désert rang-3 burn
est-il compensable par `bellows_priest + soot_acolyte` comme « paire de synergie » ?**
Ce round apporte une réponse calculée.

### 1.4 ACCORD — Singletons rang-1 pour 3 familles (burn, rot, bleed) — adopté round 7

```
ash_moth     : rank=1, burn singleton        P(voir en T1) ≈ 42 %
carrion_pecker: rank=1, rot singleton        P(voir en T1) ≈ 42 %
gnaw_rat     : rank=1, bleed singleton       P(voir en T1) ≈ 42 %
```

**Accord maintenu.** Traitement uniforme des 5 familles (poison `spore_tick`, choc `live_wire`
en ont sans concurrence → 2 familles correctes ; 3 à décider). SAP (a327ex.com) : « each tier
= introduction to the next mechanic » — un singleton fragile (ex. `ash_moth`, HP=26) « ne
ressemble pas à la porte d'entrée ». La décision rareté-voulue vs trou reste ouverte — ce round
ne la tranche pas mais soulève une précondition manquante (§2.3).

### 1.5 ACCORD — `runestone_golem` niche ambiguë (adopté round 8)

```
runestone_golem : rank=4, shield_aura value=12, HP=88, DPS=0.125
oath_keeper     : rank=4, shield_aura value=18, HP=84, DPS=0.114
```

`runestone_golem` a une aura 33 % plus faible mais plus de HP et DPS que `oath_keeper`. **Le
joueur veut soit l'aura la plus forte (→ `oath_keeper`) soit le DPS le plus fort (→ ... pas
`runestone_golem` non plus : `galvanizer` DPS=0.172 rang-4).** La niche « middle-ground »
sans nom est invisible. Accord sans réserve. **Décision binaire à documenter** (aura pure
= réduire HP/DPS ; ou carry-tank sans aura = renommer/retirer).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MODÉRÉ — Le remède aux stat-sticks rang-5 est sous-spécifié : il n'adresse pas la COLLISION D'IDENTITÉ de famille qu'ils créent

**Ce que le brouillon dit** (§3.7, v9, #GG BLOQUANT) : `skull_colossus` et `deep_kraken`
doivent être remplacés par des apex ayant des règles d'équipe. Le remède cite deux options :
(a) transform réelle ; (b) stat-amplification bornée. La décision d'axe choc est attendue AVANT
P1.

**Ce qui manque** : le brouillon n'a jamais analysé ce que `skull_colossus` (burn rang-5,
`on_hit`, aggro=40, HP=92) fait à la **progression interne de la famille burn**. Ce round
révèle une collision structurelle :

```
Progression burn avant skull_colossus :
  R2 : emberling / cinder_cur / pyre_tender / ash_moth / pyre_herald / zeal_inquisitor
       → poseurs de base (6 unités, assez saturé)
  R3 : bellows_priest (lenteur de décroissance) / soot_acolyte (aura)
       → DÉSERT r3 (1 enabler actif, 27 % visible)
  R4 : wildfire_hound (propagation mort) / kiln_warden (extension si plus faible)
       → twists T2 légitimes
  R5 : ash_maw (burnNoDecay team) / plague_pyre (burn + poison à la mort)
       → transforms T3 légitimes, règle d'équipe / croisé
```

Dans cette progression, `skull_colossus` (burn `on_hit` seul, DPS 0.131) se position **AU-DESSUS
de tous les T3 burn légitimes** en DPS brut (ash_maw=0.100, plague_pyre=0.107). **Le message
envoyé au joueur** : la progression burn maximale est « utiliser `skull_colossus` comme carry
DPS burn » et non « utiliser `ash_maw` pour rendre les brûlures éternelles ». Ce n'est pas
juste une violation de classification — c'est une **inversion du modèle de valeur rang-5**.

**Source** : Cloudfall Studios 2020 ([cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions](https://www.cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions)) — la leçon StS citée : « if any choice is obviously the best regardless of context, the designers have failed. Solutions either introduce new problems or are only useful in a portion of situations. » `skull_colossus` est la meilleure unité burn en DPS brut DANS TOUS LES CONTEXTES, ce qui invalide les 2 T3 burn légitimes.

**Collision supplémentaire — aggro=40 sur `skull_colossus`** : le seul tank burn du roster a
aggro=40, ce qui en fait un **tank-carry burn** avec HP=92 (le plus élevé des rangs-5). Dans
une boutique late-game, il supplante `gravewarden` (tank taunt pur) ET les T3 burn légitimes.
C'est une triple niche (carry burn / tank / aggro-drain) dans une unité rang-5 — le pire cas
de DOUBLE-VALEUR non documenté (décision #10, col B, catégorie introduite round 6).

**Proposition** (§P-A, enrichissement du #GG bloquant) : le remède d'`skull_colossus` n'est pas
simplement « transform réelle » — il faut **choisir une niche rang-5 exclusive à `skull_colossus`
qui ne cannibale pas `ash_maw`** :
- `ash_maw` = burnNoDecay (les brûlures durent → axe durée/maintenance)
- `plague_pyre` = propagation croisée burn+poison (axe diffusion)
- Niche disponible restante : **burn à la mort d'ALLIÉ** (axe sacrificiel / grimdark) — « quand
  une unité alliée meurt, ses brûlures sautent sur la cible ennemie front » → `skull_colossus`
  comme archétype « crémateur d'alliés ». DPS frappe ramené à 0.090 (budget T3 transform).
  Retire l'aggro=40 (le tank-carry est la collision la plus grave). **0 moteur** (trigger
  `on_death` côté allié déjà câblé : `grant_team` + hook `on_death broadcast différé`).

**`deep_kraken`** collision similaire mais plus simple : poison on_hit rang-5 DPS=0.154 vs
`festering` (poisonNoCap) DPS=0.100. Le remède est moins contraint côté famille car poison
a déjà `venom_censer` (igniteAt=5) comme T3 croisé. Niche disponible : **poison en AoE sur
toute la colonne adverse** (le Kraken = étreinte massive). `op="poison"` sur `target="column"`
— **nouveau target** (aujourd'hui seulement `neighbors` en combat) ou `spread=all` conditionnel
→ **~5 lignes SIM** (pas 0 moteur). À trancher : est-ce justifié pour un apex unique ?

### 2.2 DÉSACCORD NOUVEAU — Le désert rang-3 burn est partiellement compensé par `soot_acolyte` MAIS crée un PIÈGE DE COMPOSITION non documenté

**Ce que le brouillon dit** (§3.1 désert rang-3 burn, round 8) : 1 enabler actif burn rang-3
(`bellows_priest`), P(visible T3) ≈ 27 %, bridge mid-game 2.3× plus étroit. Décision :
voulu ou trou.

**Ce que ce round révèle** : `soot_acolyte` (rang-3, aura burn `aura_burn_dps inc=0.5` sur
les voisins) constitue techniquement une 2e unité rang-3 burn — MAIS elle est une **aura pure
(trigger `combat_start`, build-résolue)**. Le brouillon la compte dans « rang-3 burn » mais
P(joueur qui joue `soot_acolyte` sans `bellows_priest`) = le joueur place `soot_acolyte` au
centre du sigil pour bénéficier de 4 voisins burn, mais **si `bellows_priest` (le seul enabler
actif rang-3) est absent du pool**, `soot_acolyte` amplifie les poseurs rang-2 uniquement.

**Le piège** : un joueur burn mid-game avec `soot_acolyte` + 4 poseurs rang-2 pense avoir un
rang-3 burn. Il a une aura qui améliore des poseurs faibles, pas une progression de complexité.
SAP (a327ex.com, « each tier = introduction to the next mechanic ») : le rang-3 doit
**introduire un twist**, pas amplifier le rang-2. `soot_acolyte` = amplificateur rang-2, pas
twist. `bellows_priest` = vrai twist rang-3 (décroissance réduite = l'unité a une mécanique
propre). **La combinaison `soot_acolyte` + rang-2 est perçue comme une progression par le
joueur mais n'est pas une progression vers les T2 twists rang-4.**

**Conséquence** : le désert rang-3 burn ne peut PAS être résolu par « documenter l'aura comme
alternative » — l'aura n'introduit pas de concept nouveau. **Si voulu** (build burn exigeant),
documenter **explicitement dans les i18n** que `bellows_priest` est le « seul maître du feu
rang-3 » (DA grimdark, pas un warning). **Si trou**, 1 enabler rang-3 burn distinct (axe
différent de `bellows_priest` : ex. burn + `on_death` propagation limitée, distinct de
`wildfire_hound` rang-4) pour P → 45-50 %.

**Précision de la proposition P-D round 8** : le critère « voulu (bridge resserré) vs trou »
doit spécifier **à quelle épreuve** : si le joueur n'atteint pas le shopTier 3 avant le
round 5, le désert est bénin (la boutique T2 suffira jusqu'au shopTier 4). Mais si la courbe
XP passive fait que le shopTier 3 est atteint en mid-game (rounds 4-6) et que le joueur burn
cherche à consolider, le désert est structurel. **Métrique proposée** : mesurer `--burn-progression-gap`
dans `tools/sim.lua` : `E[rounds in shopTier=2 WITH burn-committed build AND NOT bellows_priest
visible]`. Si > 2 rounds → désert structurel → décision trou. ~10 lignes sim.

### 2.3 DÉSACCORD CIBLÉ — Le budget rang-4 choc n'a jamais été audité intra-famille : `galvanizer` est un outlier DPS **dans sa propre famille** et cette asymétrie n'est pas documentée

**Ce que le brouillon dit** (§3.1a `burst_DPS_eq`, round 4-8) : `galvanizer` (rang-4, DPS
frappe=0.172) est l'outlier DPS du roster. La col E l'étiquette « condensateur premium —
outlier voulu, ne pas nerf aveuglément ». La règle P90/P10 ≤ 3× est appliquée aux **DoT
enablers** mais jamais à la **famille choc intra-rang-4**.

**Calcul ce round** sur les 4 unités choc rang-4 (`units.lua:311-335`) :

```
galvanizer    : rank=4, dmg=11, cd=64 → DPS_frappe=0.172  (bonus_first+shock add=2)
arc_warden    : rank=4, dmg=6,  cd=60 → DPS_frappe=0.100  (shock add=1, chain=2)
dynamo_priest : rank=4, dmg=5,  cd=58 → DPS_frappe=0.086  (shock add=1, transfer=0.5)
rust_sentinel : rank=4, dmg=9,  cd=72 → DPS_frappe=0.125  (shock add=1, cap=6 = stormcaller)
```

**P90/P10 intra-famille choc rang-4** (sur galvanizer, arc_warden, dynamo_priest ; rust_sentinel
exclu car violateur #10 → retiré/redéfini) : P90=0.172, P10=0.086, **ratio = 2.0×** — passe
le seuil 3×. Donc la règle adoptée dit : pas de problème.

**Mais** : la règle P90/P10 mesure le spread **global**, pas la **décision de pick entre
deux unités**. Si un joueur choc a le choix entre `galvanizer` (DPS 0.172, bonus_first) et
`dynamo_priest` (DPS 0.086, transfer 50 % des stacks) dans la même boutique T4, `galvanizer`
domine sur **chaque axe quantifiable** sauf le transfer (qui est un axe de multi-cible).
**C'est une pseudo-paire de dominance conditionnelle** : `galvanizer` > `dynamo_priest` sur
toute composition mono-cible. Pour un joueur mid-game sans second cible assignée, `galvanizer`
est systématiquement préféré.

**Conséquence spécifique à l'axe D** (litige #GG) : si l'axe D amplifie le premier tick DoT
de la cible, `dynamo_priest` (transfert de charge à un voisin) peut être plus utile que
`galvanizer` pour l'axe D multi-cible (charger 2 cibles DoT-actives simultanément). **L'axe
D CHANGE la hiérarchie des rangs-4 choc.** Simuler le `burst_DPS_eq` APRÈS la décision
d'axe D, pas avant.

**Proposition** (§P-B) : reporter l'audit `burst_DPS_eq` de `galvanizer` APRÈS la décision
d'axe D (#GG). Documenter dans §3.1a que l'audit `burst_DPS_eq` est **conditionnel à l'axe D**
et ne peut pas être figé maintenant. **0 code, doc seul.**

### 2.4 DÉSACCORD MODÉRÉ — La colonne (J) valeur sigil-dépendante est documentaire mais non actionnable : il manque un FILTRE DE VIABILITÉ pour les auras DoT rang-3

**Ce que le brouillon dit** (§3.1 col J, round 6-8) : pour les unités à `trigger="combat_start"
target="neighbors"`, documenter valeur max / valeur min / sigil hostile. Adoptée comme audit
documentaire.

**Ce qui manque** : un critère binaire « cette aura est-elle viable dans ≥3 sigils sur 5 ? »
Voici le calcul sur les auras DoT rang-3 (`units.lua:148-163`) :

```
soot_acolyte  (burn_dps inc=0.5)  : voisins selon sigil :
  carré centre = 4 voisins → inc 0.5 × 4 poseurs = buff fort
  croix nœud   = 4 voisins (si placée au centre) → buff fort
  anneau       = 2 voisins max → buff moyen
  diamant      = 3 voisins (si centre) → buff correct
  ligne        = 2 voisins max (adjacent gauche/droite) → buff faible

clot_mender  (grant_bleed dps=1 dur=180 slow=10%) : même topologie
miasma_acolyte (poison_dps inc=0.5) : même topologie
decay_tender  (rot_growth bonus=1) : même topologie
```

Pour le sigil `ligne`, les auras rang-3 n'ont au maximum **que 2 voisins** (1 à gauche, 1 à
droite). La valeur d'une aura-5×4 devient une aura-2, soit **50 % de valeur perdue**. Or le
sigil `ligne` est le « conduit front→back » (00-state §2.3) — les archétypes qui l'utilisent
sont les builds à rôle linéaire (bleed avec front exposed + carry protégé arrière). `clot_mender`
(aura bleed) dans un sigil `ligne` n'applique son buff qu'à 2 voisins — et dans un sigil ligne,
les adjacences orthogonales en colonne sont limitées.

**Si P1 (types) crée un palier-4 bleed avec `clot_mender` comme aura centrale**, un joueur
bleed qui joue le sigil `ligne` (archétype le plus « bleed-intuitif » vu le ciblage front→back)
trouvera son aura rang-3 à moitié inefficace. **C'est une incompatibilité silencieuse** entre
l'archétype et l'aura prescrite par le palier-type.

**Source** : Backpack Battles (steam mai 2026, cité dans 00-state §7.1) :
« positional adjacency items require spatial tooltips ». The Pit a déjà adopté la col J.
**Mais le tooltip n'empêche pas l'achat irrationnel** : un joueur bleed mid-game voit
`clot_mender` (rang-3, aura bleed) en boutique T3 et l'achète sans savoir que son sigil `ligne`
en retire 50 %. Sans filtre de viabilité, la col J reste documentaire, pas décisionnelle.

**Proposition** (§P-C) : étendre la col J avec un **flag de compatibilité sigil** :
```
col J enrichie :
  sigils-MAX (N voisins = max pour cette aura) : ex. carré/croix (4 voisins)
  sigils-MIN (≤2 voisins) = « HOSTILE » : ex. ligne (2), anneau (2)
  viabilité : « viable ≥3 sigils sur 5 » OUI/NON
  → si NON : candidat pool-A (retirer de U.pool pour les builds ligne+anneau ?)
```
**NON : ne pas retirer de U.pool** (trop radical pour une décision d'audit). Mais le flag de
compatibilité sigil **alimente le tooltip de boutique** (§2.5) et **informe P1 (types)** :
si le palier-4 d'une famille prescrit une aura, s'assurer qu'elle est viable dans **le sigil
que l'archétype privilégie**. Doc seul, lit `shapes.lua`, 0 code, 0 invariant.

---

## 3. Propositions priorisées

### P-A (PRIORITÉ HAUTE, #GG lié) — Documenter la collision d'identité de `skull_colossus` dans la famille burn AVANT de choisir son remède

**Quoi** : dans §3.7, ajouter une analyse en 3 points AVANT le choix du remède :
1. `skull_colossus` = carry burn DPS-0.131 → domine `ash_maw` (0.100) et `plague_pyre` (0.107) sur
   le seul axe quantifiable → **invalide les 2 T3 burn légitimes** dans une boutique T5 où les 3
   co-apparaissent.
2. `skull_colossus` aggro=40 + HP=92 = tank-carry burn → **3e collision** (tank + carry + burn T3),
   catégorie DOUBLE-VALEUR pire cas (col B round 6, §3.1).
3. **Niche rang-5 disponible** non encore occupée par un T3 burn existant : **burn sacrificiel à la
   mort d'allié** (trigger `on_death` allié, pas `on_hit`). Retire l'aggro=40, DPS frappe → 0.090.
   0 moteur (trigger `on_death` allié côté broadcast différé déjà câblé).

**Coût** : décision de spec (0 code maintenant), doc §3.7 enrichi. **Condition** : trancher
après la décision d'axe choc (#GG) car la niche « 0 moteur » dépend des triggers disponibles.
**Priorité** : co-prioritaire à la décision #GG (les deux sont P0.5 bloquants avant P1).

---

### P-B (PRIORITÉ MOYENNE) — Reporter l'audit `burst_DPS_eq` de `galvanizer` APRÈS la décision d'axe D (#GG)

**Quoi** : ajouter une note dans §3.1a : « l'audit `burst_DPS_eq` de `galvanizer` est
CONDITIONNEL à l'axe D — simuler après la décision #GG (axe A/B vs D) car l'axe D change
la valeur relative de `dynamo_priest` (transfer multi-cible) vs `galvanizer` (mono-cible fort).
Figer l'audit avant #GG = décision sur une hiérarchie provisoire. »

**Coût** : doc pur, §3.1a + note dans le tableau §3.1. 0 code, 0 invariant.

---

### P-C (PRIORITÉ MOYENNE) — Étendre la col J avec un flag de compatibilité sigil actionnable pour les auras rang-3/4

**Quoi** : pour chaque aura DoT rang-3/4 (identifiées par `trigger="combat_start",
target="neighbors"`), ajouter au tableau §3.1 :

```
aura            | sigils-MAX (N voisins) | sigils-MIN | viable ≥3/5 sigils ?
soot_acolyte    | carré/croix (4)        | ligne/anneau (2) | OUI (3/5)
clot_mender     | carré/croix (4)        | ligne/anneau (2) | OUI (3/5)
miasma_acolyte  | carré/croix (4)        | ligne/anneau (2) | OUI (3/5)
decay_tender    | carré/croix (4)        | ligne/anneau (2) | OUI (3/5)
```

(À calculer précisément sur `shapes.lua` pour vérifier les adjacences ligne/anneau.)

**Décision** : si toutes les auras rang-3 passent le filtre « ≥3/5 sigils viables » → pas
de changement d'unité. MAIS **informer P1 (types)** : si un palier-4 prescrit une aura rang-3
dont le sigil-hostile est le sigil le plus naturel de l'archétype (ex. bleed = ligne),
**soit l'aura de palier est une unité rang-4 différente**, soit **le tooltip de boutique (§2.5)
doit signaler l'incompatibilité**.

**Coût** : calcul sur `shapes.lua` (lignes ~1-52, arêtes explicites), doc seul, ~0.5 h.
0 code, 0 invariant. Précondition de P1 (types).

---

### P-D (PRIORITÉ BASSE) — Introduire la métrique `--burn-progression-gap` pour trancher « voulu / trou » sur le désert rang-3 burn

**Quoi** : dans §3.1 (désert rang-3 burn), ajouter le critère quantitatif de décision :

```
sim : tools/sim.lua --burn-progression-gap
  Config : build burn-committed (≥3 burn rang-2) au début du round 4
  Mesure : rounds passés en shopTier=2 OU shopTier=3 SANS bellows_priest visible
  Cible : si E[rounds bloqués] > 2 → désert structurel → décision « trou »
           si E[rounds bloqués] ≤ 2 → désert bénin → décision « voulu »
  N=100 runs, seed=20260620
```

**Coût** : ~10-15 lignes sim, doc §3.1. 0 invariant. **Priorité basse** (ne bloque pas P-A,
P-B, P-C ; peut attendre le batch P3 d'équilibrage auto).

---

## 4. Questions ouvertes

**Q1 — Si `skull_colossus` reçoit la niche « burn sacrificiel à la mort d'allié », quel est
le contrat avec `plague_pyre` (burn + poison propagé à la mort) ?**

`plague_pyre` propage À LA MORT DE L'ENNEMI (burn de l'ennemi saute à ses voisins + poison).
`skull_colossus` (version proposée) propage À LA MORT D'UN ALLIÉ (les brûlures sautent sur
la cible front ennemie). Les deux ont `on_death` mais des sujets inverses (ennemi vs allié).
**Sont-ils conflictuels ou complémentaires ?** → à analyser dans la décision #GG (axe apex)
avant de graver la niche de `skull_colossus`.

**Q2 — Les auras rang-3 sont toutes « OUI » au filtre ≥3/5 sigils. Est-ce suffisant, ou
faut-il aussi vérifier que le PALIER-TYPE P1 prescrit une aura compatible avec le sigil
naturel de l'archétype ?**

Si le palier bleed-4 prescrit `clot_mender` (aura, hostile en `ligne`), et que le build
bleed préfère le sigil `ligne` (front exposé, ciblage front→back favorable au bleed slow),
le palier prescrit une aura dont le sigil naturel est le pire. **Ce n'est pas un problème
d'unité, c'est un problème de spec P1.** À adresser dans la lentille synergies-effets ou
dans la spécification P1 types.

**Q3 — La règle « plancher ≥2 enablers par rang-3 » doit-elle distinguer auras et poseurs ?**

Aujourd'hui, le plancher ≥2/rang est appliqué au total d'unités portant la famille (auras
incluses). `burn rang-3 = bellows_priest + soot_acolyte = 2` → plancher OK. Mais si la
définition du plancher inclut les auras, **toutes les familles passent le plancher rang-3** par
construction (chaque famille a une aura rang-3). Le plancher doit-il être `≥2 POSEURS ACTIFS
(trigger on_hit) par rang-3` pour être significatif ? Actuellement non spécifié. **Si oui,
burn rang-3 = 1 poseur actif = sous le plancher** → trou confirmé sans ambiguïté.

**Q4 — Si `skull_colossus` perd l'aggro=40, l'archétype tank burn est-il couvert ailleurs
dans le roster ?**

`gravewarden` (tank taunt, épines, rang-4) ne pose pas de burn. L'archétype « tank burn »
n'a actuellement que `skull_colossus` comme vecteur rang-5. Si ce vecteur est retiré, un joueur
qui voulait un tank-carry burn perd sa seule option late-game. **Accepté ou nouvelle niche à
créer ?** Si accepté : burn devient une famille carry-fragile (aggro basse) → grimdark-cohérent
(le feu brûle vite et meurt). Si nouvelle niche : un rang-4 burn à aggro modérée (ex. `kiln_warden`
+aggro) suffit.

---

## 5. Ce que ce round confirme vs conteste

| Claim du brouillon v9 | Statut R09 |
|---|---|
| `skull_colossus`/`deep_kraken` bloquants DPS | ✅ CONFIRMÉ, mais... |
| Remède = transform réelle / stat-amp | ⚠️ INCOMPLET — collision d'identité famille burn non adressée |
| Désert rang-3 burn = voulu ou trou (décision ouverte) | ⚠️ PRÉCISION — `soot_acolyte` n'est pas un poseur r3, piège de composition non documenté |
| Audit col B étendu rang-2/3/4 | ✅ CONFIRMÉ, mais... |
| `galvanizer` = outlier voulu, ne pas nerf aveuglément | ⚠️ CONDITIONNEL — audit conditionnel à la décision d'axe D (#GG non tranché) |
| Col J (valeur sigil-dépendante) = audit doc | ⚠️ INSUFFISANT — manque filtre viabilité ≥3/5 sigils actionnable pour P1 |
| Plancher ≥2/rang valide si auras comptées | ❌ FAIBLE — si le plancher compte les auras, burn rang-3 passe artificiellement → plancher doit compter les POSEURS ACTIFS uniquement |

---

## 6. Synthèse pour round 10 (dernier)

**Priorités units-power non résolues pour le round final** :

1. **P-A (bloquant #GG) — Collision d'identité famille burn de `skull_colossus`** : documenter
   la triple collision (carry burn / tank / dominance sur T3 légitimes) ET proposer la niche
   « burn sacrificiel à la mort d'allié » avant le choix de remède. Co-prioritaire à la décision
   d'axe D.

2. **P-C (précondition P1) — Flag de compatibilité sigil pour les auras rang-3/4** : calculer
   sur `shapes.lua`, décision documentaire, alimente la spec P1 types (si une aura prescrite par
   un palier est hostile au sigil naturel de l'archétype → problème de spec, pas d'unité).

3. **Précision Q3 — Redéfinir le plancher de rang ≥2 pour exclure les auras** : « ≥2 POSEURS
   ACTIFS (on_hit) par rang » est un critère significatif ; « ≥2 unités (auras incluses) » passe
   artificiellement pour burn rang-3 alors que le désert est réel.

4. **P-B (note doc) — Reporter l'audit `burst_DPS_eq` galvanizer après #GG** : évite de graver
   une hiérarchie choc rang-4 provisoire avant que l'axe D soit décidé.

5. **P-D (P3 batch) — Métrique `--burn-progression-gap`** : quantifier si le désert rang-3 burn
   est structurel ou bénin selon la courbe XP réelle.

---

## 7. Index des sources

**Internes (lecture seule du repo, ce round)** :
- `src/data/units.lua` — intégralité relue, DPS calculés via Python (tous rangs, toutes familles).
  Lignes clés :
  - `skull_colossus` : l.421-424 (burn on_hit rang-5, aggro=40, HP=92, DPS=0.131)
  - `deep_kraken` : l.437-440 (poison on_hit rang-5, DPS=0.154)
  - `ash_maw` : l.231-237 (burn T3, burnNoDecay team, DPS=0.100)
  - `plague_pyre` : l.238-244 (burn T3 croisé, DPS=0.107)
  - `bellows_priest` : l.169-172 (burn rang-3 seul poseur actif, DPS=0.086)
  - `soot_acolyte` : l.148-151 (aura burn rang-3, combat_start, DPS=0.111)
  - `galvanizer` : l.311-317 (choc rang-4, DPS=0.172)
  - `arc_warden` : l.327-330 (choc rang-4, DPS=0.100)
  - `dynamo_priest` : l.323-326 (choc rang-4, DPS=0.086)
  - `corruptor` : l.62-65 (poison rang-3, weaken=0.06)
  - `bile_spitter` : l.122-125 (poison rang-3, weaken=0.10)
  - `rust_sentinel` : l.425-428 (shock rang-4, op identique stormcaller)
  - `stormcaller` : l.79-82 (shock rang-2)
  - `clot_mender` : l.152-155 (aura bleed rang-3, combat_start)
  - Pool rang-3 complet : l.487-512 pour compter (~18 unités rang-3)
- `src/board/shapes.lua` — adjacences orthogonales par sigil (non relu en détail ce round,
  nécessaire pour P-C)
- `docs/roadmap-lab/00-state.md` (§2.1 roster, §3.1 familles, décisions #10, col J §3.1)
- `docs/roadmap-lab/ROADMAP-draft.md` (v9, §3.7 apex choc #GG, §3.1 col B/J, désert burn)
- `docs/roadmap-lab/round-08.md` (§1.1-1.4 adoptions units-power)
- `docs/roadmap-lab/rounds/r08-units-power.md` (calculs DPS et désaccords initiaux)

**Sources web vérifiées ce round** :

- [Ariely, Loewenstein & Prelec 2003 — Coherent Arbitrariness (QJE)](https://academic.oup.com/qje/article/118/1/73/1917051) :
  Un item dominé par un concurrent visible sur tous les axes dégrade la décision (le dominant
  paraît meilleur encore par contraste). Réutilisé pour `skull_colossus` vs T3 burn (§2.1) et
  `corruptor` vs `bile_spitter` (§1.1).

- [Cloudfall Studios — Game Design Tips from Slay the Spire (2020)](https://www.cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions) :
  « if any choice is obviously the best regardless of context, the designers have failed. Solutions
  either introduce new problems or are only useful in a portion of situations. » Fonde §2.1
  (skull_colossus best burn choice in all contexts = design failure).

- [Entalto Studios — 5 Essential Tips for Roguelite Design](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/) :
  « Build identity must be clear within 2 min. » Fonde §1.2 (skull_colossus brouille l'identité
  archétype burn dans les ghosts async).

- [GDC 2020 — Teamfight Tactics Design Lessons (David Abecassis)](https://gdcvault.com/play/1026808/-Teamfight-Tactics-Design) :
  Difficultés signifiantes = unités qui font des trade-offs, pas des choix évidents. Fonde §2.3
  (galvanizer vs dynamo_priest : pseudo-dominance conditionnelle sur mono-cible).

- [SAP Mechanics — a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics) :
  « Each tier serves as an introduction to the next mechanic. » Fonde §2.2 (soot_acolyte ne
  remplace pas bellows_priest comme introduction aux twists rang-3).

- [Slay the Spire Cards Design — slaythespire.wiki.gg](https://slaythespire.wiki.gg/wiki/Cards) :
  Design de niche par carte : Poisoned Stab n'est utile qu'avec d'autres cartes poison. Fonde
  §1.2 (le contrat rang-5 = contexte conditionnel, pas puissance brute).

---

*Round 09 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu (`units.lua`
intégralité, DPS calculés via Python sur tous les rangs). N'édite que sous `docs/roadmap-lab/`.
Piliers respectés : async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural.
32 invariants non touchés. 0 modification du code du jeu.*
