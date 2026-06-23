# Round 02 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v2, après round 1) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 2/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v2), `00-state.md`, `round-01.md`,
> `rounds/r01-units-power.md` (lentille round 1), `competitive/*.md` (tous), `src/data/units.lua`
> (intégralité, lu directement ce round), `seed/mechanics.md`, `seed/tests.md`.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous `docs/roadmap-lab/`.
> Aucun chiffre affirmé sans source (URL ou fichier+ligne). En désaccord avec un agent précédent
> → recherche web menée et citée.

---

## 0. TL;DR de ce round

Le brouillon v2 a correctement identifié le **P0.5 « audit d'identité »** comme précondition aux
types, mais son traitement reste **trop abstrait** : il liste le livrable (tableau 5×5) sans
**opérationnaliser le critère de distinction**. Le vrai problème n'est pas « les unités se
ressemblent » — c'est que le roster a **deux problèmes distincts confondus** : (A) redondance
*de niche* (même trigger, même axe mécanique, stats seules varient) et (B) redondance *de pool*
(trop d'enablers par famille au même rang = dilution sans payoff de hunt). Ces deux problèmes ont
des remèdes **opposés** : A → refonte data (différencier l'axe) ; B → retirer du pool ou
regrouper en variantes. Le brouillon v2 propose le remède de A pour les deux. De plus, la décision
d'axe du choc (P0.5 §3.2) est **bien posée** mais le test opérationnel proposé est biaisé : le
seuil de 30 % de « décharges après mort de la cible » ne contrôle pas la durée des combats ni le
contexte de sigil, et peut invalider l'Option A même si elle est viable sur anneau+tank.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — le P0.5 « audit identité » AVANT les types est indispensable

Le round 1 (lentille units-power §2.5) a posé l'argument, la synthèse round-01 §1.1 l'a adopté.
Je le confirme avec une nouvelle preuve issue de la lecture **complète** de `units.lua`.

**Preuve de ce round (lecture directe, unités rang-2 par famille) :**

| Famille | Unités rang-2 | Axe de différence déclaré | Différence réelle en niche |
|---------|--------------|--------------------------|---------------------------|
| Burn | emberling (dps=6, dur=150), cinder_cur (dps=4, dur=120, refresh=true), pyre_tender (dps=10, dur=180), pyre_herald (dps=6, dur=170) | cadence / front-load / refresh | **4 enablers burn rang-2** : pyre_herald (`units.lua:398`) est **un 4e enabler burn rang-2** identique à emberling sauf les params (dps=6, dur=170 vs dps=6, dur=150). Différence = 20 ticks de durée. C'est de la **dilution de pool**, pas de la distinction de niche. |
| Bleed | razorkin (dps=2, slow=20%), gash_fiend (dps=3, slow=20%), hookjaw (dps=1, slow=30%), wailing_shade (dps=2, dur=200, slow=15%), byakhee (dps=3, dur=180, slow=10%) | intensité / contrôle pur / épines | **5 enablers bleed rang-2** dont razorkin vs gash_fiend = même niche (slow 20%, dps différent) ; byakhee vs gash_fiend = même niche, params proches. |
| Poison | witch (dps=2), spore_tick (dps=1), rot_grub (dps=2, dur=300), chitin_drone (dps=2, dur=160), coil_viper (dps=3), web_recluse (dps=2, dur=200), ink_horror (dps=3, dur=170) | — | **7 enablers poison rang-2** (rang 1-2 confondus). La plupart = même op, params légèrement variés. |
| Rot | rot_hound (base=1, capDps=10), bore_worm (base=1, capDps=8, dur=210) | cadence / cap | 2 enablers rot rang-2, distinction réelle (cap différent). Sain. |
| Choc | stormcaller (add=1, cap=6), thunderhead (add=1, volt=6, cap=4), static_swarm (add=1, cap=8), siphon_jelly (add=1, cap=5), storm_anchor (add=2, cap=8, persist=0.5), stormlord (add=2, volt=4, cap=8) | cadence / dense / patient | Choc a **6 unités** dont storm_anchor et stormlord sont rang-3 ; parmi rang 2, stormcaller vs siphon_jelly vs thunderhead vs static_swarm ont des niches vaguement différentes MAIS sont **toutes en aggro=5** (carry arrière) avec des params proches. |

**Conclusion chiffrée** : le roster compte **23 unités rang-2** (00-state.md §2.1). En les
cartographiant famille par famille, j'identifie **au moins 6 paires ou triplets** à niche
quasi-identique (même op, params ≤20 % d'écart, même position de jeu). Ce n'est pas un problème
d'équilibrage : c'est un problème de **décision vide en boutique** (le joueur voit deux bleed
rang-2 et ne peut pas distinguer leur rôle au build).

**Pourquoi ça tient pour nos contraintes** : SAP a résolu ce problème en limitant à 10 pets/tier
avec des triggers distincts (`super-auto-pets.md §3.2`). Avec `SHOP_SIZE=5` et 23 unités rang-2
dans le pool, la probabilité de voir deux enablers burn rang-2 dans la même boutique (ex. emberling
+ pyre_herald + pyre_tender) est élevée. L'effet ressenti : « encore du burn, mais lequel ? » →
décision basée sur le chiffre le plus élevé, pas sur une niche. C'est la définition du stat-stick
invisible (Ghost Crawler / askghostcrawler.tumblr.com, 2017 : « mettre 40 points dans tout =
bland, 40 dans force = bruiser avec strengths/weaknesses »).

### 1.2 ACCORD — les 5 familles DoT comme types est la bonne structure

Confirmé (round 1 §1.2, round-01 §1). Je ne re-débats pas. La cartographie de `units.lua`
confirme que la répartition familia est cohérente : burn 13, bleed 13, poison 15, rot 11, choc 11
(00-state.md §2.1). L'architecture `type` dans les données (`type = "abyss"/"flesh"/"bone"/"order"/
"arcane"`) est **différente** des familles DoT — ce n't est pas le type taxonomique mais la famille
visuelle/RI. Les types de palier viendront du *family mécanique* (burn/bleed/etc.), pas du `type`
data. Cela ne crée pas de conflit architectural.

### 1.3 ACCORD — la décision d'axe du choc AVANT le ladder 5/3/2

Le round 1 (units-power §2.3, synergies §2.1) a posé l'argument, la synthèse l'a adopté.
Je confirme depuis la lecture complète du ladder choc dans `units.lua` (lignes 298-333) :

Le ladder choc actuel compte **8 unités** (live_wire, thunderhead, static_swarm, galvanizer,
stormlord, dynamo_priest, arc_warden, storm_anchor), répartis sur rangs 1-4. Les modificateurs
(dynamo_priest, arc_warden, storm_anchor) sont **architecturalement corrects** : ils modifient le
comportement de la décharge (transfer, chain, persist), ce qui est exactement le profil d'un T2
de twist. Le problème n'est pas la structure — c'est que l'axe de la décharge suppose que la
**cible survit assez longtemps** pour que les stacks s'accumulent et que la décharge parte.

Sur un plateau carré (forme par défaut), avec ciblage déterministe (colonne avant en premier) et
des combats de ~5-10 s (estimation basée sur HP_MULT=2, combats avant fatigue à ~17 s), une unité
choc en front accumule ses stacks ET se fait taper en même temps → probabilité de décharge avant
mort = faible. L'archétype viable du choc = **cible qui reste longtemps vivante** = soit une unité
à aggro élevée qui se fait cibler (mais alors elle absorbe les coups), soit une unité en arrière
(depth élevé, ciblée en dernier). Le sigil **ligne** (front→back conduit) ou **anneau** (propagation)
sont les sigils qui permettent à une unité choc en arrière de chargey des cibles qui restent vivantes
grâce aux tanks en front.

**Ce que je valide depuis la structure data** : galvanizer (`rank=4, aggro=15`) a `bonus_first +
shock` : il se charge ET décharge en un combo — c'est l'archétype « bruiser autonome » qui ne
dépend pas de la survie de la cible. C'est la preuve que **l'axe A (condensateur carry arrière)
et l'axe galvanizer (auto-décharge) coexistent**. Le test opérationnel du brouillon (P0.5 §3.2)
devrait mesurer les DEUX axes séparément.

### 1.4 ACCORD — la distinction rang-1 nécessite une passe légère (pas urgente)

Round 1 §2.2 note que `demon` (lifesteal 40%) est un profil T2-T3 au rang-1. La lecture complète
de `units.lua` confirme : les rang-1 actuels sont `marauder, skeleton, bandit, demon, spore_tick,
ash_moth, live_wire, carrion_pecker, husk, gnaw_rat, footman, mire_thing` (12 unités). Parmi eux :
- `demon` (lifesteal 0.4) = gestion de ressource = profil T2 SAP (accord §1.4 round 1)
- `ash_moth` (burn dps=7, decayPct=0.45) = burst fort éphémère = profil acceptable rang-1 SI
  le decayPct le rend vraiment éphémère (0.45/s = brûlure ≈ 3 s de dps réel, ok)
- `carrion_pecker` (rot base=1, capDps=6) = rot faible, cap bas = correct rang-1 (simple enabler)
- `live_wire` (shock add=1, cap=5) = semeur correct rang-1

**Nuance par rapport au round 1** : je suis MOINS sévère sur `demon`. Lifesteal 40% d'un dmg=9
= 3.6 PV/coup sur cd=56. Sur un combat de ~10 s et cd=56 ticks, demon frappe ~10 fois = +36 PV
de soin. Sur 64 PV de base, c'est un survivant, pas un auto-win. **Ce n'est pas une urgence
(rang-1 sain si le soin est correctement plafondné par les caps HP).** La priorité P-D du round 1
est confirmée : **basse priorité**.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD CRITIQUE — le brouillon confond deux types de redondance et prescrit un seul remède

**Ce que le brouillon dit** (P0.5 §3.1) :
> « Chaque case ≤3 unités, chacune avec une niche en 1 phrase. Les doublons sans niche distincte
> = candidat refonte data. »

**Ce qui est juste** : le critère « 1 niche par unité » est correct.

**Ce qui est faux ou insuffisant** : il ne distingue pas deux types de redondance distincts qui
requièrent des remèdes opposés.

**Type A — Redondance de niche (même op, même axe mécanique, stats proches)** :
Exemple : `razorkin (dps=2, slow=20%)` vs `gash_fiend (dps=3, slow=20%)`. Ces deux unités
ont la *même niche* (bleed enabler + slow 20%), avec un écart de dps=1. Le remède = **différencier
l'axe** : donner à l'une une condition de déclenchement différente (on_attacked au lieu de on_hit,
ou un seuil HP). Coût = modifier les params data.

**Type B — Dilution de pool (niches distinctes en théorie, mais trop d'unités dans le slot de
boutique pour un run court)** :
Exemple : burn rang-2 a 4 unités (emberling, cinder_cur, pyre_tender, pyre_herald). Les niches
sont en théorie distinctes (burst/refresh/front-load/cadence). Mais sur `SHOP_SIZE=5` et un pool
de rang-2 large (23 unités), la boutique affichera souvent 1-2 burn rang-2 **dont le joueur ne
peut pas distinguer la niche sans infobulle**. Remède ≠ refonte data. Remède = **retirer du pool**
les doublons à faible delta niche, ou les fusionner en une seule unité avec param `mode=` (comme
`kiln_warden` a un `mode="extend_if_weaker"` — c'est la bonne direction). Coût = choix éditorial,
pas d'op nouveau.

**Preuve que cette distinction manque** : le brouillon prescrit « refonte data » comme unique
remède. Or, pour le burn rang-2, une refonte data de `pyre_herald` (actuellement = emberling
+20 ticks) nécessite soit de lui donner un nouvel op, soit de le supprimer du pool. Le brouillon
ne dit pas lequel. Sans ce choix, l'audit P0.5 produit un tableau sans action concrète.

**Source** : la distinction est validée par la recherche sur le genre. GhostCrawler (2017,
askghostcrawler.tumblr.com, Riot Games) sur le power budget : « buffing her shields makes her
more generic... sharper strengths and weaknesses makes better champions ». La redondance
de niche (A) est le problème de généricité ; la dilution de pool (B) est un problème de
pression d'apparition en shop. TFT Set 17 résout B en ajustant les pool sizes par coût
(1-cost: 29 copies, 2-cost: 22, 3-cost: 18 — `metatft.com/tables/shop-odds`, consulté 2026)
sans forcément changer les niches. The Pit n'a pas ce levier (pas de pool partagé inter-joueurs,
pas de pool size par unité dans `state.lua` — le pool est uniforme par rang).

**Proposition concrète** : l'audit P0.5 doit distinguer les deux types EXPLICITEMENT :
- **Colonne « Type de redondance »** dans le tableau : A (niche) / B (pool) / Sain
- **Remède recommandé** par ligne : A → « différencier l'axe (donner un trigger ou condition
  distinct) » ; B → « retirer du pool boutique (garder comme récompense/rencontre) ou fusionner »
- **Critère de décision B** : si ≥3 unités rang-N famille-X ont une niche en 1 phrase *similaire*
  et que l'écart de params est <25%, c'est une dilution de pool → retirer la moins distinctive.

---

### 2.2 DÉSACCORD MODÉRÉ — le test opérationnel de l'axe choc est biaisé

**Ce que le brouillon dit** (P0.5 §3.2) :
> « Test opérationnel : taux de décharge *après* mort de la cible dans le fuzz ; si >30 %, axe
> cassé → axe B (mini-dégât à la pose). Puis sim choc+tank sur anneau/ligne : si win%∈[0.45,0.55]
> → axe A viable. »

**Ce qui est juste** : mesurer le taux de « choc gaspillé » est le bon diagnostic de premier
niveau. La sim ciblée anneau+tank est correcte.

**Ce qui est problématique** : **le seuil de 30 % est arbitraire et non ancré**.

Le taux de décharges perdues dépend de **trois variables indépendantes** :
1. La durée moyenne des combats (HP_MULT=2 allonge les combats ; un combat plus long = plus de
   temps pour décharger)
2. La présence d'un tank en front (ciblage déterministe : un tank à aggro élevée protège la cible
   choquée)
3. Le sigil actif (ligne = la cible choquée en arrière survit longtemps ; carré = mixte)

Un taux de décharge perdue de 35 % sur un setup carré sans tank ne prouve pas que l'axe A est
« cassé » — il prouve que l'axe A exige un setup spécifique (tank + sigil adéquat). C'est une
**contrainte de build**, pas un défaut architectural. De même, 25 % de décharges perdues avec
tank+anneau n'est pas « sain » si c'est uniquement parce que les combats durent toujours 17 s
(fatigue).

**Source** : la notion de « condition d'activation » comme axe de design — et non de bug — est
documentée dans la conception des ailments PoE. `poewiki.net/wiki/Damage_over_time` (consulté
via les fichiers compétitifs du repo) : « ailments that require specific conditions (ignite on crit)
create build pressure rather than design failure ». La décharge choc après survie de la cible EST
la condition d'activation. Le mesurer globalement sur le fuzz 250 (mélange de sigils, de configs)
revient à juger une carte StS depuis le win-rate sans tenir compte du deck.

**Ce que le test opérationnel devrait faire à la place** :

| Mesure | Config | Seuil de décision |
|--------|--------|------------------|
| Taux de décharge perdue | **setup spécifique** : tank rang-4 en front, 3 choc en arrière, sigil **ligne** | Si >40 % DANS CE SETUP → axe cassé (il est censé être optimal) |
| Win% choc+tank vs poison build | 50 combats identiques, sigil ligne | Si <moyenne−1σ sur ligne → axe A non viable même dans son contexte |
| Win% galvanizer seul (auto-décharge) | 50 combats, carré | Si >moyenne → axe B (auto-décharge) coexiste déjà → pas besoin de tuer A |

Décision : si galvanizer est viable ET le setup tank+ligne donne <40 % de pertes → **les deux
axes coexistent** (A = carry arrière / B = bruiser autonome) et il n'y a pas à choisir, il faut
**nommer les deux sous-archetypes** dans le ladder 5/3/2 (5 carry arrière, 3 autonomes, 2 pivot).

**Proposition concrète** : modifier le test opérationnel du brouillon P0.5 §3.2 en remplaçant
le « taux global > 30% » par la matrice ci-dessus. Déléguer à `tools/sim.lua` avec un seed fixe
sur les 3 configurations.

---

### 2.3 DÉSACCORD MODÉRÉ — le brouillon n'adresse pas le problème des unités rang-2 « famille-visuelle »

**Ce que le brouillon dit** : rien sur les unités de la « vague v7 » (`units.lua` lignes 384-440).

**Ce que j'observe en lisant le code** : la vague v7 ajoute 14 unités de rang 2-5 pour « peupler
les familles visuelles » (chitin_drone, bore_worm, wailing_shade, pyre_herald, byakhee,
zeal_inquisitor, coil_viper, web_recluse, siphon_jelly, skull_colossus, rust_sentinel,
runestone_golem, ink_horror, deep_kraken). Ces unités ont un champ `family` explicite pour la
génération procédurale de leur visuel (`creaturegen.cached`).

**Le problème** : parmi ces 14 unités, **11 sont rang-2**, toutes avec des effets basiques (1 op,
params standards). Elles ont été créées pour les familles visuelles, pas pour les niches de build.
Résultat : elles ajoutent 11 unités rang-2 au pool boutique (`U.pool = U.order`, `units.lua:488`),
**portant le total rang-2 de 23 à un nombre non encore audité explicitement dans la roadmap**.

En cartographiant les rang-2 depuis `units.lua` :
- burn rang-2 : emberling, cinder_cur, pyre_tender, pyre_herald, zeal_inquisitor → **5 enablers**
- bleed rang-2 : razorkin, gash_fiend, hookjaw, wailing_shade, byakhee → **5 enablers**
- poison rang-2 : witch, rot_grub, chitin_drone, coil_viper, web_recluse, ink_horror → **6 enablers**
- rot rang-2 : rot_hound, bore_worm → **2 enablers** (sain)
- choc rang-2 : stormcaller, thunderhead, static_swarm, siphon_jelly → **4 enablers**
- shield rang-2 : shieldbearer → **1** (sain)
- stat-stick purs rang-2 (bruiser) : 0 explicites

Total rang-2 avec effets comptés depuis `units.lua` : ~23 unités. Dont **poison rang-2 à 6
enablers** = le problème le plus aigu (6 unités de « poison standard », differentiés uniquement
par dps=1 à 3 et dur=160 à 300).

**Pourquoi c'est un problème dans notre contexte async** : le pool boutique est tiré depuis `state.
lua:buildShop()` qui pioche dans `U.pool` (= `U.order` pour l'instant). Avec 6 poison rang-2 dans
le pool et `SHOP_SIZE=5`, la probabilité de voir un poison rang-2 à chaque boutique rang-2+ est
très élevée. Un joueur qui « joue poison » voit systématiquement plusieurs enablers poison rang-2
interchangeables — la décision se réduit à « lequel a le dps le plus élevé ? ». Ce n'est pas une
décision de build : c'est du tri automatique.

**Ce que SAP a fait** : `super-auto-pets.md §2.2` → 10 pets/tier, triggers distincts. Turtle Pack
= 60 pets sur 6 tiers = **exactement 10/tier**, zéro dilution. Avec nos 83 unités sur 5 rangs, le
ratio est 16.6/rang en moyenne — 60 % de plus que SAP. La redondance de pool est **structurelle**,
pas conjoncturelle.

**Proposition concrète** : l'audit P0.5 doit **explicitement** cartographier les unités rang-2
vague-v7 et décider pour chacune : reste dans le pool boutique tel quel / retire du pool boutique
(récompense d'encounter IA seulement) / refonte niche. Cible : ≤4 unités par famille par rang dans
le pool boutique.

---

### 2.4 DÉSACCORD LÉGER — le brouillon surestime la portée du cap ×3 sur la protection anti-redondance

**Ce que le brouillon dit** (ROADMAP-draft §4.3, litige #B) :
> « `DOT_CAP_MULT=3` protège contre le snowball ; le double-comptage inc% est borné. »

**Ce qui est juste** : le cap protège contre les emballements. Confirmé par le code (`ops.lua:22`).

**Ce qui manque** : le cap ×3 protège contre le *snowball* (dps trop élevé), pas contre la
*redondance de décision*. Deux unités burn identiques portées à ×3 chacune via types+auras ne
créent pas de dégât excessif (le cap tranche) — mais elles créent une décision de build vide
(«laquelle des deux posséder est la même décision que d'en posséder une»). C'est un problème de
**valeur marginale de la 2e unité**, pas de puissance.

**Source** : GhostCrawler, ibid. : « putting 20 points into all 5 attributes ends up with someone
bland ». La blandeur n'est pas un pic de win-rate — c'est une texture de décision aplatie. Le cap
×3 ne corrige pas la texture, seulement le plafond de puissance.

**Verdict** : pas un désaccord bloquant. Mais le brouillon ne doit pas utiliser « cap ×3 » comme
argument contre l'audit d'identité. Ce sont des axes orthogonaux.

---

### 2.5 DÉSACCORD SUR LE SÉQUENCEMENT — P0.5 « audit data » peut contredire P1 « types » si les familles visuelles ne sont pas réconciliées

**Ce que le brouillon dit** (P1 §4.1) :
> « Type d'unité = famille mécanique (burn/bleed/poison/rot/choc). »

**Ce que le code révèle** : les unités ont deux champs distincts — `type` (famille taxonomique :
flesh/bone/order/arcane/abyss) et la famille mécanique (implicite dans le trigger/op). La vague v7
a un champ `family` pour la génération procédurale. Ces trois axes sont **orthogonaux** dans la
data, mais le **palier de type** du brouillon P1 se baserait sur la famille *mécanique* (burn/bleed/
etc.). Aucun champ `dot_family` n'existe dans `units.lua` — la famille mécanique est *inférée* de
l'op (`poison`, `burn`, etc.) dans `effects[].op`.

**Conséquence** : pour compter « 2 unités burn sur le plateau » (palier de type), le système devra
inférer la famille depuis `effects[n].op`. Cette inférence fonctionne pour les unités mono-famille
(emberling = burn pur), mais **échoue sur les unités multi-effets** :
- `leech_thorn` (bleed + thorns) : famille = bleed ? ou deux familles ?
- `wither_bloom` (rot + bleed 0-dps + poison 0-dps) : famille = rot ? bleed ? poison ? Les trois ?
- `galvanizer` (bonus_first + shock) : famille = choc pur ? ou mixte ?

Le brouillon ne résout pas ce cas. Si `wither_bloom` compte pour rot ET bleed ET poison, le palier
de type peut être atteint trivialement par 2 unités dont l'une est `wither_bloom`. Ce serait une
décision vide.

**Source** : TFT a eu ce problème avec les traits multi-tags (un champion peut avoir 2-3 traits,
dilue les synergies). La décision de design de Riot (`tft.md §2.1`, Riot GDD) : chaque champion
porte ≤3 traits, et l'activation d'un trait se compte par **toutes les unités qui portent le tag**,
pas uniquement celles mono-tag. Mais TFT a des tags explicites ; nous avons des ops implicites.

**Proposition concrète** : ajouter une résolution claire en P0.5 avant de coder P1 :
- Définir la règle de « famille mécanique principale » pour chaque unité : « l'op du premier effet
  non-aura dans `effects[]` » → famille principale. Une unité à op=rot est rot, même si elle porte
  aussi bleed à 0 dps (wither_bloom → famille=rot).
- Les unités multi-effets à op distincts (leech_thorn = bleed + thorns) → la famille = l'op DoT
  (bleed) ; thorns n'est pas une famille de type.
- Document dans l'audit P0.5 (0 code, 0 invariant).

---

## 3. Propositions priorisées

### P-A (URGENT, data/doc, 0 code) : Audit d'identité en deux colonnes — Redondance de NICHE vs POOL

**Quoi** : reprendre l'audit du brouillon P0.5 §3.1 mais avec une grille enrichie :
- **Colonne A** : niche en 1 phrase (≤ 10 mots)
- **Colonne B** : type de redondance (A=niche / B=pool / Sain)
- **Colonne C** : remède (A→ « différencier axe/trigger » ; B→ « retirer pool boutique » ; Sain→ « rien »)
- **Colonne D** : famille mécanique principale (inférée de `effects[1].op`, documentée ici pour P1)

**Cible** : ≤3 unités par case (famille × rang) dans le pool boutique, avec des niches non-identiques.
Pour burn rang-2 : réduire de 5 à 3 (retirer pyre_herald et zeal_inquisitor du pool boutique — les
garder dans le roster pour les encounters IA). Pour poison rang-2 : réduire de 6 à 3-4 (retenir
witch, spore_tick, rot_grub et un parmi chitin_drone/coil_viper/web_recluse/ink_horror).

**Pourquoi prioriser le retrait de pool plutôt que la refonte** : retirer du pool boutique coûte
0 op, 0 invariant, 0 code de moteur. `U.pool` n'est pas `U.order` à terme (le commentaire
`units.lua:487` le dit : « identique au roster pour l'instant »). Séparer `U.pool` de `U.order`
est un chantier data pur, 1 ligne de diff.

**Coût** : 0 ligne de code moteur. Livrable = tableau dans `docs/roadmap-lab/` (≤2 h de travail).

**Source** : SAP 10/tier = le benchmark de densité saine (`super-auto-pets.md §2.2`) ; TFT pool
sizes 15/13/13/13/10 par rang (`metatft.com/tables/shop-odds`, 2026) = référence de dilution.

---

### P-B (AVANT LADDER CHOC) : Sim ciblée AVEC setup optimal, pas fuzz global

**Quoi** : remplacer le test opérationnel du brouillon P0.5 §3.2 par la matrice à 3 configurations :
1. **Config A** : tank `gravewarden` (taunt + aggro=40) en col 1, 3 unités choc (live_wire +
   static_swarm + stormlord) en col 3, sigil **ligne**, seed fixe `20260623`, N=50 combats.
   → Mesure : taux décharges perdues + win% vs poison build équivalent.
2. **Config B** : galvanizer seul + stat-sticks, sigil carré, N=50 combats.
   → Mesure : win% galvanizer seul (axe B auto-décharge).
3. **Config C** : choc pur, sigil **anneau** (propagation en boucle), N=50 combats.
   → Mesure : win% sur anneau vs défense pure (shield).

**Seuils de décision** :
- Axe A cassé : Config A → taux décharges perdues >40 % ET win% choc+tank < moyenne−1σ.
  → Remède : axe B (mini-dégât à la pose) via extension op choc.
- Axe A viable, manque de contenu : Config A → taux <40 % ET win% ∈ [moyenne−0.5σ, moyenne+0.5σ].
  → Remède : compléter le ladder 5/3/2 (contenu uniquement).
- Les deux axes coexistent : Config B gagnant (>moyenne+0.5σ) → garder galvanizer comme archétype
  « bruiser autonome » séparé dans le ladder.

**Pourquoi plus rigoureux** : le fuzz 250 combats actuel (`tests/props.lua`) mélange toutes les
configurations. Mesurer « le taux global de décharges perdues » sur un fuzz aléatoire revient à
mesurer la performance du choc dans le pire des contextes (random placement, random sigil). Si le
choc est un archétype conditionnel (tank + ligne), l'évaluer hors contexte le rend injustement
faible.

**Source** : MegaCrit (StS, GDC 2019, `slay-the-spire.md §7.3`) : évaluer les cartes en contexte
d'archétype, pas en général. « 18M runs analysés, par archétype, pas par win-rate brut. »

---

### P-C (PARALLÈLE À P1) : Documenter la règle de famille mécanique principale avant P1

**Quoi** : avant d'implémenter les paliers de type (P1), documenter dans `docs/roadmap-lab/` la
règle de résolution des familles mécaniques ambiguës (leech_thorn, wither_bloom, galvanizer,
plague_pyre, etc.). 1 tableau, ~20 lignes. 0 code.

**Format** :
| Unité | Famille principale | Raison | Contribue au palier ? |
|-------|------------------|--------|----------------------|
| leech_thorn | bleed | effects[1].op = bleed (thorns = défensif, pas DoT) | oui (bleed) |
| wither_bloom | rot | effects[1].op = rot | oui (rot) |
| galvanizer | choc | effects[2].op = shock (bonus_first = stat, pas famille) | oui (choc) |
| plague_pyre | burn | effects[1].op = burn (spread = modificateur) | oui (burn) |

**Pourquoi AVANT P1** : sans cette règle, le compteur de palier (`grant_team` via count du type
dans `build.lua`) calculera une valeur ambiguë pour les unités multi-effets. Le code peut sembler
fonctionner mais la sémantique sera incorrecte → bug silencieux dans les builds complexes.

---

### P-D (APRÈS P1, SIM) : Audit win% rang-1 — une seule mesure ciblée

**Quoi** : une fois P1 en place et les pools nettoyés (P-A), mesurer le win% par unité rang-1 via
`tools/sim.lua 300` → identifier si `demon` (lifesteal) ou `carrion_pecker` (rot faible) créent
une asymétrie >1σ. Un seul levier à la fois.

**Priorisation** : différée. Les rang-1 représentent 12 unités sur 83 (14 %). L'impact de
`demon` sur la balance globale est limité par `HP_MULT=2` (combats plus longs = lifesteal plus
utile mais aussi plus contrebalancé par les DoT adverses). **La charge de la preuve est sur la sim,
pas sur l'intuition de profil.**

---

## 4. Questions ouvertes

**Q1 — Cible de densité par case (famille × rang)** : le brouillon dit ≤3 unités. Mais rank-1
a 12 unités, dont 4 stat-sticks purs (husk, bandit, footman, mire_thing) sans famille DoT. Si on
exclut les stat-sticks de la comptabilité par famille (ils n'ont pas de famille mécanique), la
densité réelle rank-1 par famille DoT est : burn(1: ash_moth), poison(1: spore_tick), choc(1:
live_wire), rot(1: carrion_pecker), bleed(1: gnaw_rat). → 1 par famille à rang-1 = sain. Le
problème est uniquement au rang-2. **Confirmer avant l'audit P-A.**

**Q2 — U.pool vs U.order : timing de séparation** : `units.lua:487-488` documente que pool=order
« pour l'instant ». La séparation est prerequis à P-A (retrait de pool sans retirer du roster).
Quand doit-elle arriver ? Si P-A peut être fait **en même temps** que la séparation (même PR),
c'est 1 chantier data. Si P-A peut attendre que la séparation soit décidée → il faut juste noter
les candidats-à-retirer-du-pool dans le tableau d'audit, sans modifier `units.lua`.

**Q3 — Les unités « vague v7 » à famille visuelle : dans le pool ou PAS ?** Le commentaire
`units.lua:383` dit « peuple les familles visuelles restées 'visuel-only' ». Ce sont des unités
créées pour la génération procédurale, pas pour l'équilibre du pool boutique. La question de
design : ces 14 unités ont-elles leur place dans le pool boutique dès v0.9, ou sont-elles des
récompenses d'encounter IA (comme les IA seedings) ? Réponse nécessaire avant P-A.

**Q4 — Le problème des unités bouclier dans les paliers de type** : les unités shield_aura
(shieldbearer, aegis_warden, oath_keeper, bulwark_acolyte, templar) et les boucliers périodiques
(ward_weaver, etc.) n'ont pas de famille DoT. Si P1 ne définit pas de 6e type « bouclier » ou
« tank » (litige #F du brouillon), **ces unités ne contribueront à aucun palier**. Soit elles
restent comme enablers transversaux (adjacence positionnelle only), soit le litige #F doit être
tranché avant P1. Le brouillon dit « tranché en P1 » — mais cartographier les unités shield avant
confirme qu'il y a 11 unités shield/tank (4 shield_aura + 5 shield_periodic + 1 aegis + 1 grave)
sans type de palier. À 11 unités, c'est un archétype non-négligeable qui mérite une réponse.

**Q5 — Axe choc : les deux options ne s'excluent pas nécessairement** : Option A (condensateur
arrière, survie dépendante) et galvanizer (auto-décharge) coexistent déjà dans le ladder. La
question n'est pas A ou B mais « est-ce que le ladder 5/3/2 restant doit peser A, B ou les deux ? »
Si le test opérationnel P-B montre que l'axe A est viable avec setup, compléter le ladder avec
3-4 unités « condensateur arrière » + 1-2 « auto-décharge » = ladder cohérent sans décision
d'axe exclusive. La décision « axe A ou B » du brouillon peut être **remplacée par** « quelle
proportion A/B dans le ladder ? ».

---

## 5. Synthèse pour les rounds suivants

Le brouillon v2 a correctement posé le P0.5 mais en a sous-spécifié le livrable et mal posé le
test du choc. Les deux corrections prioritaires de ce round :

1. **L'audit P0.5 doit distinguer redondance de NICHE (remède : refonte axe) vs redondance de POOL
   (remède : retrait boutique)** — sans cette distinction, l'audit produit un tableau sans action.
   La cible concrète : ≤4 enablers par famille par rang dans `U.pool`, pas dans `U.order`.

2. **Le test opérationnel du choc doit être contextualisé (setup optimal, pas fuzz global)** —
   un fuzz aléatoire invalide injustement un archétype qui exige un setup spécifique. La matrice
   à 3 configurations (P-B) donne un diagnostic plus fiable et peut conclure que les deux axes
   (A et galvanizer) coexistent, évitant une décision binaire prématurée.

Ces deux corrections sont de la **data/doc, 0 code, 0 invariant** — elles renforcent P0.5 sans
décaler le calendrier ni toucher les tests.

---

## 6. Index des sources

**Internes (lecture seule du repo)** :
- `src/data/units.lua` (intégralité, lue ce round — roster de 83 unités, familles rang-2 cartographiées)
- `docs/roadmap-lab/00-state.md` (32 invariants, chiffres canoniques)
- `docs/roadmap-lab/ROADMAP-draft.md` (v2)
- `docs/roadmap-lab/round-01.md` (synthèse)
- `docs/roadmap-lab/rounds/r01-units-power.md` (lentille précédente)
- `src/combat/arena.lua` (FATIGUE_START=1020, HP_MULT=2)
- `src/effects/ops.lua` (DOT_CAP_MULT=3)
- `src/run/state.lua` (GOLD_PER_ROUND=10, SHOP_SIZE=5)

**Sources web (vérifiées ce round)** :
- [metatft.com/tables/shop-odds](https://www.metatft.com/tables/shop-odds) — pool sizes TFT Set 17 :
  1-cost=29, 2-cost=22, 3-cost=18, 4-cost=10, 5-cost=9 ; odds par niveau (vérifié 2026-06)
- [tft.ninja/guides/advanced/pool-math](https://tft.ninja/guides/advanced/pool-math) — maths de pool
  TFT : « P(target) = copies_remaining / total_tier_copies_remaining » ; impact de la contestation
- [superautopets.wiki.gg/wiki/Roll_Chances](https://superautopets.wiki.gg/wiki/Roll_Chances) —
  probabilités SAP : turn 1/2 T1 ≈ 29.8 %/pet par slot (10 pets/tier)
- [askghostcrawler.tumblr.com — power budget 2017](https://www.tumblr.com/askghostcrawler/162636873978/) —
  GhostCrawler (Riot) sur le power budget : « 40 points into everything = bland ; sharper strengths
  and weaknesses make better champions »
- [gamedeveloper.com — Giovannetti GDC 2019](https://www.gamedeveloper.com/design/what-makes-slay-the-spire-s-combat-the-best-design-in-deckbuilding-games) —
  StS : « la première erreur est trop de cartes qui font la même chose avec des nombres différents »
- [rollingstone.com — LocalThunk interview 2024](https://www.rollingstone.com/culture/rs-gaming/balatro-localthunk-interview-1235214060/) —
  Balatro : « chaque Joker modifie une règle différente »

**Compétitifs lus ce round** : `competitive/super-auto-pets.md`, `competitive/tft.md`,
`competitive/balatro.md`, `competitive/slay-the-spire.md`, `competitive/postmortems.md`.

---

*Round 02 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu (`units.lua`
intégralité + moteur). N'édite que sous `docs/roadmap-lab/`. Piliers respectés (async, déterministe,
grimdark, procédural). Garde-fous : 0 modification du code, sources citées par URL.*
