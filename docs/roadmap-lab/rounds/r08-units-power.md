# Round 08 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v8, intégré round 7) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 8/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v8), `00-state.md`, `round-01.md` à
> `round-07.md`, `rounds/r01-units-power.md` à `rounds/r07-units-power.md`,
> `competitive/*.md` (tous), `src/data/units.lua` (intégralité relue ce round, DPS
> recalculés par famille et par rang via Python).
>
> **Méthode** : désaccord = recherche web menée ce round et citée. Analogie = teardown
> mécaniste AVANT d'accepter. Toute affirmation chiffrée cite le fichier+ligne relu ce round.
> Désaccords avec agents précédents → recherche propre effectuée ou calcul direct sur le code.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée /
> DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Trois angles que les rounds 6-7 (axés rank-5 + rank-2) n'ont pas épuisés, calculés ce round sur `units.lua` relu intégralement :

1. **Le brouillon a identifié les paires de niche au rang-2 (5 paires) mais a OUBLIÉ les rangs 3 et 4.** Le rang-3 a une paire de DOMINANCE poison (`corruptor` ≡ `bile_spitter`, identical op, weaken 0.06 vs 0.10 = dominance stricte) et le rang-4 a deux v7 problématiques (`rust_sentinel` = enabler shock au rang des twists ; `runestone_golem` = ambigu tank-support sans identité propre). L'audit colonne B des paires ne peut pas se limiter au rang-2.

2. **Le burn a un DÉSERT DE RANG-3 structural jamais nommé : 5 enablers en rang-2, 1 seul en rang-3 (`bellows_priest`).** La « burn bridge » entre l'early abundance et les twists rang-4 est une unité avec P(visible/boutique T3) ≈ 5.5 %. En async, un build brûleur commis early a une fenêtre de progression mid-game structurellement plus étroite que bleed (3 rang-3) ou rot (2 rang-3). Les rounds précédents ont traité les singletons rang-1 mais JAMAIS la densité rang-3 par famille.

3. **Le brouillon adopte les corrections rang-5 (`deep_kraken`/`skull_colossus`) et l'apex choc avec une efficacité d'implémentation contestable.** L'accord est fondé sur `shockChain` déjà câblé — mais le mécanisme de `shockChain` (`ops.lua:187`) est conçu pour le **rebond de décharge directe**, pas pour la propagation d'amplification DoT de l'axe D. Si l'axe D (`tickDots`) est adopté (P0.5), l'apex choc via `skull_colossus → shockChain` exige une reformulation du mécanisme de rebond qui n'est pas « 0 moteur » — c'est une réécriture conditionnelle dans `tickDots`.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — `deep_kraken`/`skull_colossus` rang-5 bloquants (round 7, §3.7)

Calcul reconduit ce round depuis `units.lua` (lignes 422-440) :

```
skull_colossus : dmg=11/cd=84 = DPS 0.131  (burn on_hit ONLY, aggro=40)
deep_kraken    : dmg=12/cd=78 = DPS 0.154  (poison on_hit ONLY)

vs meilleur T3 transform légitime :
marrow_drinker : dmg=6/cd=52  = DPS 0.115  (convert_to_rot)
```

**L'accord est valide.** DPS brut > tous les T3 transforms, aucune règle d'équipe = violation de la décision #10. Le fondement psychologique tient dans nos contraintes async : un ghost rang-5 avec `deep_kraken × 3` (DPS frappe = 0.462, LEVEL_MULT=3.0) est un mur de DPS sans lecture de counter-play (pas de trigger conditionnel). Le mécanisme de déception est identique au pattern identifié par Giovannetti GDC 2019 ([GDC Vault](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)) : « a rare that does nothing complex is worse than a common with a twist ». **Adopté sans réserve.**

### 1.2 ACCORD — Paires de niche rang-2 (round 7, §3.1 col B/P-B)

Les paires détectées ce round corroborent le calcul du round 7 :
- `pyre_herald`(burn dps=6 dur=170) ≈ `emberling`(burn dps=6 dur=150) — différentiel 9 % dur.
- `wailing_shade`(bleed dps=2 slow=15%) ≈ `razorkin`(bleed dps=2 slow=20%) — différentiel 4% frappe.
- `byakhee`(bleed dps=3 slow=10%) ≈ `gash_fiend`(bleed dps=3 slow=20%) — +violation cross-rank.

**Le fondement psychologique (SAP a327ex : « 1 pet = 1 valeur, sinon l'un est invisible ») tient pour nos contraintes async** : dans un pool LOCAL (≠ TFT partagé), deux enablers quasi-identiques co-apparaissent fréquemment (P(paire co-visible) ≈ 30-40 % en boutique T2 calculée round 7). L'accord est maintenu. **Mais l'audit doit s'étendre au rang-3 (voir §2.1).**

### 1.3 ACCORD — Apex choc rang-5 manquant (round 7, §3.7/P-C)

Confirmé : choc = seule famille sans rang-5 dans `U.pool` (live_wire r1 / 4× r2 / 2× r3 / 4× r4 / 0 r5). **Le fondement design de Giovannetti/Entalto (« every archetype must have a closing move ») transfère bien à nos contraintes** : dans un run de 10 victoires en ranked, un joueur qui commit choc (achète 4+ unités, vise le palier-type-4) et monte au shopTier 5 ne trouve pas d'apex. La déception n'est pas « malchance » mais « absence de design » — invisible à l'utilisateur, corrosif pour le ranked.

**RÉSERVE IMPORTANTE sur la solution proposée (§2.3 ci-dessous)** : l'accord porte sur le PROBLÈME, pas entièrement sur la solution via `shockChain`.

### 1.4 ACCORD — `gnaw_rat` bleed rang-1 = troisième singleton non documenté (round 7, §1.5)

Confirmé (`units.lua:446`) : `gnaw_rat` bleed rang-1 = seul enabler bleed rang-1. Les 5 familles traitées uniformément est la règle correcte. Coût nul, décision documentaire.

### 1.5 ACCORD PARTIEL — `corruptor`/`bile_spitter` comme candidats à l'audit (round 7 ne les mentionne pas explicitement mais la règle colonne-B les couvrirait)

Le round 7 a identifié les paires rang-2 mais **n'a jamais appliqué la règle ≤20 % au rang-3**. Ce round (§2.1) démontre que `corruptor`/`bile_spitter` forment une paire de DOMINANCE au rang-3 — plus grave qu'une simple paire de niche. L'accord est sur la règle; le désaccord est sur son périmètre.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MODÉRÉ — L'audit de paires de niche DOIT s'étendre au rang-3 : `corruptor` vs `bile_spitter` est une paire de DOMINANCE non détectée depuis 7 rounds

**Ce que le brouillon dit** (§3.1 col B, rounds 6-7) : les paires de niche (≤20 % d'écart sur l'axe principal) sont listées pour le rang-2. Le rang-3 n'est pas audité.

**Ce qui est calculé ce round** (`units.lua:63-65` et `:123-125`, relu) :

```lua
corruptor  : rank=3, hp=46, dmg=6, cd=62 — poison{dps=2, dur=180, weaken=0.06}
bile_spitter: rank=3, hp=42, dmg=5, cd=56 — poison{dps=2, dur=180, weaken=0.10}
```

DPS frappe : corruptor = 6/62 = 0.097 ; bile_spitter = 5/56 = 0.089.
**Axe principal identique** : `poison dps=2, dur=180` — différentiel zéro. Seul le paramètre `weaken` diffère : 0.06 vs 0.10. **Ce n'est pas une paire de niche — c'est une paire de DOMINANCE** : `bile_spitter` a un weaken SUPÉRIEUR (0.10 > 0.06) ET son DPS de frappe est seulement 8 % inférieur (acceptable). Un joueur raisonné avec les deux en boutique T3 choisira toujours `bile_spitter` sur la dimension principale.

**Pourquoi c'est plus grave qu'une paire de niche rang-2** : dans une paire de niche (pyre_herald/emberling), les deux unités sont équivalentes — le joueur prend l'un ou l'autre. Dans une paire de dominance, l'une est **strictement meilleure** → `corruptor` est invisible non pas parce que `bile_spitter` occupe la même niche, mais parce qu'il l'occupe **mieux sur chaque dimension**. La probabilité que `corruptor` soit choisi dans une boutique T3 où `bile_spitter` est aussi présent ≈ 0 % (joueur informé). Avec un pool LOCAL, les deux co-apparaissent souvent.

**Source** : Ariely, Loewenstein & Prelec 2003 QJE « Coherent Arbitrariness » ([lien](https://academic.oup.com/qje/article/118/1/73/1917051)) — un item dominé par un concurrent visible sur tous les axes est non seulement non-sélectionné mais **dégrade la décision** (l'item dominant paraît meilleur encore par contraste, renforçant artificiellement un choix). **Ce mécanisme est exactement ce que nous voulons éviter** (décision intéressante ≠ évidente).

**Pour nos contraintes async** : les snapshots ne capturent pas l'info de pool — un ghost avec `corruptor` peut sembler équivalent à `bile_spitter` (même famille, DPS semblable) mais les sims le traiteront correctement. Le problème est **côté joueur dans la boutique**, pas côté sim.

**Proposition** (§P-A) : étendre l'audit colonne B au rang-3 (et rang-4 — voir §2.2). Pour `corruptor`/`bile_spitter` : soit (a) différencier `corruptor` sur un axe orthogonal (ex. : `contagion` au hit, ou dps=3 pour en faire un enabler « frappeur-moyen » distinct de `bile_spitter` « weaken-fort ») ; soit (b) retirer `corruptor` de `U.pool` (le garder en `U.order` pour encounters IA). Option (a) préférée si la décision de cohorte rot_grub/bile_spitter n'excède pas le plancher poison rang-3 ≥2.

---

### 2.2 DÉSACCORD MODÉRÉ — Le rang-4 contient deux v7 problématiques (`rust_sentinel`, `runestone_golem`) jamais audités comme potentiels violateurs de la décision #10 (rang-4 = twists T2 / auras / tanks)

**Ce que le brouillon dit** (§3.1) : l'audit rang-4 cite `galvanizer` (condensateur — §3.1a) et `runestone_golem` (anomalie budget DPS, signalé §3.1b mais traité comme « budget-décision à trancher »). `rust_sentinel` n'est jamais cité dans 7 rounds.

**Ce qui est calculé ce round** (`units.lua:426-432`, relu) :

```lua
rust_sentinel  : rank=4, hp=78, dmg=9, cd=72, aggro=20
                 effects = { on_hit, "shock", add=1, cap=6, dur=150 }
                 DPS=0.125

runestone_golem: rank=4, hp=88, dmg=10, cd=80, aggro=40
                 effects = { combat_start, "shield_aura", neighbors, value=12 }
                 DPS=0.125
```

**`rust_sentinel` = enabler choc simple au rang-4** : `shock add=1 cap=6` est exactement le même op que `stormcaller` (rang-2, `shock add=1 cap=6`, `units.lua:79`) — seuls les params de durée diffèrent (dur=150 vs 150 = identiques !). `rust_sentinel` est un `stormcaller` avec HP=78 (vs 38) et DPS=0.125 (vs 0.103). C'est un **enabler rang-2 en taille rang-4** : il ne pose aucune mécanique nouvelle, juste plus de stats. Cela viole directement la décision #10 (rang-4 = twists T2). Le round 4 a établi que le rang-4 doit contenir des « twists T2, auras, tanks, choc avancé » — `rust_sentinel` n'est ni un twist (même op que rang-2) ni un tank (aggro=20, pas de taunt) ni un choc avancé (cap=6 vs stormcaller cap=6 = identique).

**`runestone_golem` = ambigu tank-support** : `shield_aura value=12` (rang-4) vs `oath_keeper` `shield_aura value=18` (rang-4). C'est une aura MOINS forte que `oath_keeper`, avec DPS=0.125 (vs oath_keeper DPS=0.114) et HP=88 (vs hp=84). **Niches confuses** : `runestone_golem` a plus de HP et DPS mais moins d'aura que `oath_keeper`. Ni l'un ni l'autre n'a taunt. Lequel est le « bon » pour un build bouclier ? La réponse est `oath_keeper` pour l'aura ou `runestone_golem` pour... les stats ? Deux unités dont les niches ne sont pas documentées = deux unités dont l'une est invisible (celui qui fait « moins sur chaque axe attendu »).

**Source** : GhostCrawler WoW Design ([tumblr](https://askghostcrawler.tumblr.com/post/4580765536)) : « a unit should not hold a design role that already exists at a lower tier without adding a new dimension ». `rust_sentinel` = stormcaller rang-4 sans nouvelle dimension. **Le principe transfère dans nos contraintes** (le joueur paye 4 or pour un shock add=1, le même qu'au rang-2 — la déception valeur-complexité de Giovannetti est ici aussi).

**Proposition** (§P-B) :
- `rust_sentinel` : différencier en ajoutant un T2 choc (ex. : `auto-discharge` lent ou `chain=1` au hit) pour justifier le rang-4 **OU** rétrograder en rang-3 (avec stats ajustées). Décision avant P1 (le palier-type choc rang-4 ne doit pas reposer sur un enabler identique au rang-2).
- `runestone_golem` : trancher la niche (aura > oath_keeper = réduire le DPS/HP pour en faire le « pur aura rang-4 » ; ou DPS > oath_keeper = en faire un carry-tank sans aura, renommé). Document seul, 0 moteur, 0 invariant.

---

### 2.3 DÉSACCORD CIBLÉ — L'apex choc `skull_colossus → shockChain` n'est PAS « 0 moteur » si l'axe D (`tickDots`) est adopté en P0.5

**Ce que le brouillon dit** (§3.7, round 7 adopté) : « `shockChain` est déjà entièrement câblé — `ops.lua:187` le consomme, `:276` le pose via `grant_team` → l'apex choc = 0 moteur » ; et : « si l'axe D est adopté (P0.5), le 'rebond' devient propagation d'ampli DoT ».

**Le problème** : ce sont deux affirmations contradictoires qui coexistent sans résolution.

`shockChain` tel qu'il est câblé (`ops.lua:187`) sert le mécanisme de **rebond de décharge directe** : lors d'une décharge (`dischargeShock`), les stacks sautent à un voisin (`chain = p.chain or tf.shockChain`). C'est un rebond de la **décharge burst** (axe A/B du choc — le coup physique amplifié). **Ce mécanisme est incompatible avec l'axe D** (`tickDots`) sans réécriture : l'axe D amplifie un *tick de DoT* (`tick_amplifié = tick × (1 + stacks × N)`), ce n'est pas une décharge burst qui rebondit. Si on adopte l'axe D, le « rebond » de `shockChain` n'a pas de tick DoT à propager — il faudrait ajouter dans `tickDots` une logique de propagation vers les voisins du poseur, ce qui est une **réécriture dans `tickDots`** (= moteur SIM), pas juste de la data.

**Pourquoi c'est important** : le brouillon §3.7 dit « 0 moteur » en référence à l'état **pre-axe-D** (où shockChain rebondit la décharge burst). Mais §3.4 dit que « si l'axe D est adopté, le rebond devient propagation d'ampli DoT ». Ces deux choses ne peuvent pas être « 0 moteur » simultanément — la reformulation de shockChain en propagation de l'ampli DoT **requiert une modification de `tickDots`** (ajout d'un `for voisin in neighborsOf(source)` après l'amplification).

**Source** : l'architecture SIM est définie dans `engine-architecture.md` et le firewall SIM/RENDER dans `tools/check.sh`. Toute modification de `tickDots` ou `arena.lua` = SIM (non RENDER) → viole le prétexte « 0 moteur » du §3.7 et requiert un test (invariant §6, famille choc, vérification `tests/synergies.lua` §22-32).

**Ce qui est « 0 moteur »** : créer l'unité `skull_colossus` en apex choc via `grant_team {shockChain}` SI on reste dans l'axe A/B (burst qui rebondit). C'est 0 moteur parce que shockChain est déjà câblé dans `dischargeShock`. Mais dans ce cas, l'apex choc fonctionne dans **l'ancien axe** (burst) — incompatible avec l'axe D (tick DoT) décidé en P0.5.

**Proposition** (§P-C) : résoudre l'incompatibilité avant P1 :
- **Option 1** : adopter un apex choc qui fonctionne DANS l'axe D — ex. `grant_team {shockAmpMult=1.5}` (amplifie le multiplicateur de l'ampli DoT au tick), ce qui est pur data et 0 moteur SI le multiplicateur est déjà paramétrable dans `tickDots`. À vérifier dans `arena.lua:tickDots`.
- **Option 2** : garder `shockChain` tel quel pour l'apex, mais documenter que l'apex choc utilise l'axe A/B (rebond de décharge) alors que les unités rang-2/4 utilisent l'axe D (ampli tick). **Deux axes distincts coexistent sur la famille choc.** Cela crée de la profondeur (le joueur choisit entre « charger pour amplifier le DoT » vs « charger pour rebondir la décharge ») mais doit être documenté et testé (les deux axes peuvent interagir de façon inattendue avec `DOT_CAP_MULT=3`).
- **Trancher AVANT P1** (le palier-type choc doit savoir sur quel axe il amplifie).

---

### 2.4 DÉSACCORD NOUVEAU — Le burn a un DÉSERT DE RANG-3 : 5 enablers rang-2 pour 1 enabler rang-3 (`bellows_priest`), créant une fenêtre mid-game structurellement plus étroite que les autres familles

**Ce que le brouillon dit** : §3.1 documente les singletons rang-1 (burn, rot, bleed). Il ne documente jamais la **densité par rang des familles** ni les « déserts » mid-game.

**Données calculées ce round** (`units.lua`, recap par famille) :

```
Distribution d'enablers (hors auras, hors tanks, comptage par op-famille) :
  burn   : r1=1  r2=5  r3=1  r4=2  r5=3(1 bloquant) → DÉSERT r3
  bleed  : r1=1  r2=5  r3=3  r4=2  r5=2              → OK
  poison : r1=1  r2=6  r3=2  r4=1  r5=2              → r3 mince + paire dominance
  rot    : r1=1  r2=2  r3=2  r4=3  r5=2              → OK
  choc   : r1=1  r2=4  r3=2  r4=4  r5=0              → APEX MANQUANT
```

**Le burn a 5 enablers en rang-2 (saturé) et 1 seul enabler actif en rang-3 (`bellows_priest`).**

Probabilité de voir `bellows_priest` dans une boutique T3 : avec ~18 unités rang-3 dans le pool, P(≥1 bellows_priest, SHOP_SIZE=5) ≈ 1 - C(17,5)/C(18,5) ≈ 27 %. Comparaison : P(≥1 bleed r3) avec 3 unités bleed rang-3 ≈ 1 - C(15,5)/C(18,5) ≈ 61 %. **Un joueur burn cherche sa progression rang-3 et la trouve 2.3× moins souvent qu'un joueur bleed.** En async (le ghost adverse peut avoir un bleed rank-3 facilement), l'asymétrie de progression mid-game est aussi un problème de représentation dans les pools d'adversaires.

**Pourquoi les rounds précédents ont manqué cela** : les rounds 6-7 ont compté les singletons rang-1 (un seul enabler, P(voir) basse) mais n'ont pas modélisé la **densité par rang** comme critère de bridge entre early et late. La logique était « ≥2 par rang pour le plancher » — mais le plancher ≥2 s'appliquait au rang-2, pas explicitement au rang-3.

**Source** : la logique de « progression visible » est documentée dans le brouillon lui-même (§5.3 : compteur de type visible, goal-gradient) et par SAP ([a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics)) : « each tier serves as an introduction to the next mechanic ». Si rang-3 = « introduction aux twists » et que la famille burn n'a qu'un seul twist rang-3 disponible, la progression burn est perçue comme un plateau mid-game — et dans notre boucle de 10 victoires, le mid-game (rounds 4-7 ≈ shopTier 2-3) est précisément quand les archétypes se consolident.

**Proposition** (§P-D) : documenter le désert rang-3 burn dans l'audit (nouvelle ligne sous §3.1). Décision : voulu (bridge resserré = build burn plus exigeant à poursuivre, grimdark-cohérent) **ou** trou à combler. Si trou : 1 enabler burn rang-3 distinct de `bellows_priest` — ex. un burn + aura d'explosion (différent du hound qui propage à la mort) — suffit pour porter la P à ~45-50 %. Décision data-only, 0 moteur. **À croiser avec la décision de cohorte v7 §3.2 et le plancher ≥2/rang.**

---

## 3. Propositions priorisées

### P-A — Étendre l'audit colonne B au rang-3 : `corruptor` vs `bile_spitter` = paire de DOMINANCE à résoudre (AVANT P1)

**Quoi** : ajouter une ligne « rang-3 » dans l'audit de paires de niche (§3.1 col B). `corruptor`/`bile_spitter` (poison rang-3, même op, weaken 0.06 vs 0.10 = dominance stricte) = candidat prioritaire.

**Décision binaire** :
- (a) Différencier `corruptor` : changer weaken en un axe orthogonal (ex. `contagion`, ou augmenter dps=3 pour en faire l'« empoisonneur rapide » vs `bile_spitter` l'« affaiblisseur lent »). **Niche distincte** = les deux ont une raison d'exister dans le même pool.
- (b) Retirer `corruptor` de `U.pool` (garder en `U.order`). Garde-fou : vérifier qu'après retrait, poison rang-3 a encore ≥1 enabler actif dans le pool (avec `bile_spitter` = oui).

**Coût** : audit + 1 param ou 1 ligne pool. 0 moteur, 0 invariant. **Priorité haute** : une paire de dominance est un dead pick garanti, plus corrosif qu'une paire de niche (laquelle reste une décision 50/50).

---

### P-B — Auditer `rust_sentinel` (rang-4 enabler identique au rang-2) et trancher `runestone_golem` (rang-4 ambigu) dans la décision de cohorte v7 (AVANT P1)

**Quoi** :
- `rust_sentinel` (`units.lua:426`) : shock `add=1 cap=6 dur=150` = même op que `stormcaller` rang-2 (`units.lua:79`, shock `add=1 cap=6 dur=150`). **Violation stricte de la décision #10** (rang-4 = twist, pas enabler) — jamais signalé en 7 rounds. Décision : ajouter un T2 twist pour justifier le rang-4 **OU** rétrograder en rang-3 (stats ajustées). Si rétrograder → libère un slot rang-4 choc pour un vrai twist (ex. `arc_warden chain=2` est un meilleur T2).
- `runestone_golem` : aura=12 (< oath_keeper=18) + DPS=0.125 + aggro=40 (no taunt). Niche ambiguë. Trancher : (a) aura pur (réduire DPS/HP pour clarifier le rôle) ou (b) retirer de `U.pool`.

**Coût** : audit + 1-2 décisions data. 0 moteur, 0 invariant. **Priorité haute** : `rust_sentinel` est une violation de la décision #10 identique aux violations rang-5, jamais détectée parce que personne n'a comparé ses params à ceux de `stormcaller`.

---

### P-C — Résoudre l'incompatibilité axe-D vs shockChain AVANT de coder l'apex choc (DÉCISION BLOQUANTE sur la spec de P1 choc)

**Quoi** : le §3.7 du brouillon dit « 0 moteur » pour l'apex choc via `shockChain`, mais §3.4 dit que l'axe D reformule le « rebond » en propagation d'ampli DoT. Ces deux affirmations ne peuvent pas coexister sans décision explicite.

**Deux options** :
- **(Option 1 — 0 moteur, axe A/B)** : l'apex choc `skull_colossus` utilise `shockChain` comme rebond de décharge burst (axe A/B). Les unités rang-2/4 utilisent l'axe D (ampli tick). Deux axes coexistent sur la famille choc. Documenter explicitement, tester l'interaction `shockChain × axe D` (un build mix peut déclencher les deux).
- **(Option 2 — moteur minimal, axe D cohérent)** : l'apex choc utilise `grant_team {shockAmpMult=1.5}` (ou équivalent paramétrable), amplifiant le multiplicateur de l'axe D. Si `shockAmpMult` n'est pas un paramètre existant dans `tickDots`, c'est une réécriture minimale (1 champ lié, ~5 lignes SIM). Préserve la cohérence de l'axe D pour tout le ladder choc.

**Trancher AVANT P1** (le palier-type choc-4 doit savoir quel axe amplifier). **Si Option 1** : ajouter à `tests/synergies.lua` un test que `shockChain` et l'axe D ne se court-circuitent pas (ex. un stack choc ne déclenche pas deux amplifications). **Coût** : décision de spec (0 code maintenant), test à ajouter si Option 1 choisie.

---

### P-D — Documenter le désert rang-3 burn + décider si c'est voulu ou un trou (AUDIT P0.5)

**Quoi** : dans l'audit §3.1, ajouter une ligne « densité rang-3 par famille » :
- burn r3 : 1 active enabler (`bellows_priest`) sur ~18 rang-3 = P(voir/boutique T3) ≈ 27 % vs bleed ≈ 61 %. Bridge mid-game asymétrique.
- Décision : (a) voulu (progresser burn en mid = challenge cohérent avec la DA grimdark du feu) ; (b) trou = ajouter 1 enabler burn rang-3 distinct (ex. brûlure + `shield-drain` ou `splash_on_death` limité). **Décision data-only, 0 moteur.**

**Priorité** : moyenne. À traiter dans l'audit P0.5 pendant la même session que les singletons rang-1, sans bloquer P-A/P-B.

---

## 4. Questions ouvertes

**Q1 — Le désert rang-3 burn est-il compensé par la densité rang-4 burn (2 twists distincts) ?**

Si un joueur burn monte directement de rang-2 à rang-4 (shopTier 3 → shopTier 4), le désert rang-3 n'est qu'une fenêtre temporaire (~2-3 rounds). Mais si son éco le retient en shopTier 2-3 pendant 4-5 rounds, le désert est perçu comme un plateau. À mesurer : quelle est la durée médiane en shopTier 2-3 par build ? Si < 3 rounds, le désert est bénin. Si > 4 rounds, il est structurel.

**Q2 — `rust_sentinel` est-il en fait classé sous la famille choc dans `U.pool` (choc dense rang-4) ou dans la liste générale ?**

Le code (`units.lua:482`) le place dans le bloc « vague v7 » aux côtés de `skull_colossus`, `runestone_golem`, `coil_viper` — il n'est pas dans la liste des 4 rang-4 choc légitimes (`galvanizer`, `dynamo_priest`, `arc_warden`, + `gravewarden` hors choc). Si `rust_sentinel` **est** compté dans les « 4 rang-4 choc », le ladder choc a en fait **5 unités rang-4** avec un enabler simple parmi elles. À confirmer par lecture de `U.pool` (ligne 488+).

**Q3 — La paire de dominance `corruptor`/`bile_spitter` affecte-t-elle la mesure `--poison-frac` (P0.5) ?**

Si `corruptor` est retiré de `U.pool` (option P-A b), cela réduit les enablers poison rang-3 de 2 à 1. Les deux sims (`--poison-frac` et `--pool-repr`) doivent être lancées APRÈS la décision de cohorte (§3.2), sinon elles mesurent un pool à corriger. C'est un argument pour imposer l'ordre strict `--pool-repr` AVANT `--poison-frac` — le litige #DD en vaut la peine ici : retirer `corruptor` change la représentation rang-3 poison, et simuler avant cette décision = mesurer un pool incorrect.

**Q4 — Y a-t-il d'autres paires de dominance cachées au rang-4 (non-choc) ?**

Ce round a vérifié la famille choc rang-4 et les boucliers rang-4. Les twists DoT rang-4 (burn : `wildfire_hound`/`kiln_warden` ; bleed : `bloodletter`/`tendon_render` ; etc.) ont des axes distincts — pas de paire de dominance évidente. À confirmer dans l'audit §3.1 étendu.

---

## 5. Ce que ce round confirme vs conteste

| Claim du brouillon | Statut R08 |
|---|---|
| `deep_kraken`/`skull_colossus` rang-5 = bloquants | ✅ CONFIRMÉ (calcul DPS relu) |
| Apex choc = 0 moteur via shockChain | ⚠️ PARTIELLEMENT FAUX si axe D adopté — 2 options à trancher |
| Audit paires niche limité au rang-2 | ❌ INSUFFISANT — rang-3 a une paire de DOMINANCE (`corruptor`/`bile_spitter`) |
| `rust_sentinel` non cité = OK rang-4 | ❌ VIOLATION #10 : même op choc que `stormcaller` rang-2 |
| Singletons rang-1 documentés pour 2 familles | ⚠️ INCOMPLET — burn rang-3 = désert (1 enabler actif) jamais documenté |
| `runestone_golem` « anomalie budget à trancher » | ⚠️ INSUFFISANT — niche ambiguë non résolue, non priorisée |

---

## 6. Synthèse pour rounds 9-10

**Priorités restantes units-power pour les 2 derniers rounds :**

1. **P-C (spec) — Trancher axe-D vs shockChain pour l'apex choc** : décision de spec bloquante sur P1 choc. Coût : 0 code, 1 décision documentée.
2. **P-A (data) — `corruptor`/`bile_spitter` rang-3 paire de dominance** : retrait ou différenciation dans la décision de cohorte v7.
3. **P-B (data) — `rust_sentinel` rang-4 = enabler rang-2 déguisé** : ajouter un T2 twist ou rétrograder. Violation #10 non documentée depuis 7 rounds.
4. **P-D (doc) — Désert rang-3 burn** : documenter + décider voulu/trou dans l'audit P0.5.
5. **#DD (lié à P-A) — Ordre `--pool-repr` AVANT `--poison-frac`** : le retrait de `corruptor` justifie maintenant l'ordre strict (mesurer le pool après correction, pas avant).

---

## 7. Index des sources

**Internes (lecture seule du repo, ce round)** :
- `src/data/units.lua` — intégralité relue, DPS calculés par Python (toutes familles, tous rangs)
  - `corruptor` : ligne 63-65 (poison dps=2 weaken=0.06 rang-3)
  - `bile_spitter` : ligne 123-125 (poison dps=2 weaken=0.10 rang-3)
  - `rust_sentinel` : ligne 426-428 (shock add=1 cap=6 dur=150 rang-4 v7)
  - `stormcaller` : ligne 79-81 (shock add=1 cap=6 dur=150 rang-2 — IDENTIQUE à rust_sentinel)
  - `runestone_golem` : ligne 430-432 (shield_aura value=12 rang-4 v7)
  - `oath_keeper` : ligne 351-353 (shield_aura value=18 rang-4 — paire ambiguë avec runestone_golem)
  - `bellows_priest` : ligne 170-172 (burn rang-3, seul enabler actif)
  - `skull_colossus` : ligne 422-425 (burn on_hit rang-5 — apex choc candidat)
  - `deep_kraken` : ligne 438-441 (poison on_hit rang-5 — bloquant)
  - Pool distribution totale : lignes 487-512
- `src/effects/ops.lua:187` (shockChain consommé dans dischargeShock — axe A/B)
- `docs/roadmap-lab/00-state.md` (§2.1 roster, §3.1 familles, décision #10)
- `docs/roadmap-lab/ROADMAP-draft.md` (v8, §3.4 axe-D, §3.7 apex choc, §3.1 col B)
- `docs/roadmap-lab/rounds/r06-units-power.md` + `rounds/r07-units-power.md`
- `docs/roadmap-lab/round-07.md` (§1.2 apex choc, §3.3 forked_tongue shockChain grep)

**Sources web vérifiées ce round** :

- [Ariely, Loewenstein & Prelec 2003 — Coherent Arbitrariness (QJE)](https://academic.oup.com/qje/article/118/1/73/1917051) :
  Un item dominé par un concurrent visible dégrade la décision (renforcement du dominant par contraste). Fonde §2.1 (corruptor/bile_spitter = paire de dominance, non juste de niche).

- [GDC 2019 Giovannetti / MegaCrit — Slay the Spire Metrics](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) :
  « the power of a card must match its complexity ». Fonde §2.2 (rust_sentinel rang-4 = enabler rang-2 = déception valeur-complexité) et §1.1 (deep_kraken/skull_colossus stat-sticks rang-5).

- [GhostCrawler WoW Design Notes](https://askghostcrawler.tumblr.com/post/4580765536) :
  « a unit should not hold a design role that already exists at a lower tier without adding a new dimension ». Fonde §2.2 (rust_sentinel = stormcaller rang-4 sans dimension nouvelle).

- [SAP Mechanics — a327ex.com](https://a327ex.com/posts/super_auto_pets_mechanics) :
  « Each tier serves as an introduction to the next mechanic ». Fonde §2.4 (burn rang-3 desert = porte d'entrée vers les twists rang-4 quasi-fermée au shopTier 3).

- [5 Essential Tips for Roguelite Design — Entalto Studios](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/) :
  « Build identity must be clear within 2 minutes ». Fonde §2.3 (l'apex choc doit avoir un axe clair — axe D ou axe A/B — pour que l'identité de l'archétype soit lisible dès le commitment).

---

*Round 08 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu
(`units.lua` intégralité, DPS calculés par Python sur tous les rangs). N'édite que sous
`docs/roadmap-lab/`. Piliers respectés : async snapshots / sim déterministe seedée /
DA grimdark / pixel art procédural. 32 invariants non touchés. 0 modification du code du jeu.*
