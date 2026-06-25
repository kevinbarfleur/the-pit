# Re-tier résiduel + audit statique des command-auras — prép Phase C

> **Statut** : DESIGN (zéro code). Préparation **Phase C** (tuning data-driven des 83 command-auras).
> Ne fixe **aucune valeur de tuning finale** — celles-ci sortiront des sims (P1/P3/P7 de la méthodo).
> Ce doc tranche **deux questions statiques** : (A) reste-t-il des mismatches rang↔forme à corriger
> maintenant que B.2 a PIN les formes ? (B) les 83 `commandBonus` respectent-ils les caps, et **quels
> combos** la sim devra surveiller ?
>
> **Vérifié vs supposé** (CLAUDE.md §1.a) :
> - Les 83 unités ont un champ **`arch=` explicite** (lu dans `src/data/units.lua`) — le mapping
>   forme↔unité est **figé en data**, pas hypothétique. La table A croise `arch=` RÉEL vs `imposance`
>   du dictionnaire (`docs/generation/bestiary-dictionary.json`, lu).
> - Les **caps moteur** sont lus dans le code (pas la spec) : `arena.lua` (`ATK_INC_CAP=1.5` l.40,
>   `VULN_INC_CAP=0.5` l.41, `HIT_DMG_CAP_MULT=7` l.42, `MULTICAST_MAX=3` l.43, **`HASTE_CAP=0.40` l.48**,
>   **`DMG_REDUCE_CAP=0.60` l.49**, `SHOCK_STACK_CAP=8` l.34, `WEAKEN_CAP=0.40` l.32) ; `ops.lua`
>   (`DOT_CAP_MULT=3` l.22, `poisonNoCap`→cap 99 l.65) ; `build.lua` (`STAT_INC_CAP`). `Primgen.WORLD_FIT=0.5`
>   uniforme (`primgen.lua` l.2735).
> - **Table `DESIGNED` déjà codée** : `tools/runsim.lua` l.34-36 (6 counters voulus). La Partie B la
>   raffine pour le contexte command-aura.
>
> **Découverte qui simplifie tout** : la **dette V0** de `command-auras-rollout-spec.md` (« haste/dmgReduce
> sans cap de lecture ») est **RÉSOLUE** — `HASTE_CAP`/`DMG_REDUCE_CAP` existent dans `arena.lua`. Donc les
> stats « sans cap » de la spec sont désormais **toutes cappées** sauf `lifesteal` et `regen` (cf. §B.1).

---

## TL;DR (décisions)

- **Partie A — re-tier : par DÉFAUT, NE RIEN CHANGER.** B.2 a aligné forme↔rang via le PIN d'`arch`.
  `WORLD_FIT` est **uniforme** → l'imposance ne grossit pas le plateau, elle se lit au **cadre + glow** de
  carte. Les « conflits » §5 (rot_grub→hydra imp8, corruptor→kraken imp9, soot_acolyte→chimera imp9) sont
  des **familles mono-forme** : l'unité ne PEUT pas porter une forme moins imposante de sa famille, mais
  comme l'échelle est uniforme **ce n'est pas un problème de lisibilité de plateau**. Changer un `rank` =
  toucher la **SIM gated** (boutique + balance) → re-valider en sim. **Verdict : 0 changement de rang
  recommandé.** 3 cas marginaux listés « si jamais », tous à risque balance, tous repoussés post-P3.
- **Partie B — caps : AUCUN `commandBonus` ne dépasse un cap en solo.** Le risque est le **cumul**
  (aura + effet perso + relique + aura d'adjacence) vers un cap, et la **convergence** (trop d'unités sur
  le même levier). 4 watchlists : (1) `dmgReduce` (16/83 ≈ 19 % — convergence « murs ») ; (2) `lifesteal`/
  `regen` (**seuls leviers SANS cap de lecture** — non-terminaison/sustain ingérable) ; (3) `multicast ×
  afflicteur × ampli-école` (snowball historique, 3 sources possibles) ; (4) `markEnemiesVuln` + amplis
  d'école qui s'empilent vers `DOT_CAP_MULT`/`VULN_INC_CAP`. Table `DESIGNED` étendue de 6 → 9 entrées.

---

# PARTIE A — Revue de RE-TIER (rangs vs imposance/coolness)

## A.0 Le cadre qui tranche (rappel des invariants)

Trois faits rendent le re-tier de rangs **quasi-inutile** :

1. **`WORLD_FIT=0.5` uniforme** (`primgen.lua` l.2735, vérifié). Toutes les créatures occupent la **même
   empreinte** sur le plateau. L'`imposance` du dictionnaire pilote la **richesse de silhouette** (nombre
   de membres, détails, masse dessinée), **PAS** l'échelle in-game. Un « R2 sur hydra (imp 8) » ne déborde
   donc pas le plateau : il fait la taille d'un R1.
2. **La rareté se lit au CADRE + GLOW**, pas à la taille (CLAUDE.md : « le rang se lit d'abord au cadre,
   le sprite renforce »). B.2 a ajouté la 2e couche : **les R5 portent maintenant les formes les plus
   imposantes de leur famille** (skull_colossus→skulltitan imp10, pit_maw→devourer imp10, marrow_drinker→
   voidtyrant imp10, venom_censer→embersac imp9, festering→fleshcrawler imp8, deep_kraken→kraken imp9). Le
   problème visuel #2 de l'user (« ELDER pas assez stylées ») est **résolu côté forme**.
3. **`rank` est SIM et gated boutique.** Le `rank` gouverne (a) l'apparition en boutique (cotes par niveau,
   à venir) et (b) tous les ciblages `tier:N` (galvanizer/footman/gnaw_rat ciblent `tier:1`). Changer un
   rang = changer **et** le gating **et** le pool de cibles d'auras conditionnelles → impact balance à
   re-valider. CLAUDE.md **découple explicitement puissance et rareté**. L'user a tranché : imposance =
   **hint bypassable**, pas une assignation.

> **Conséquence** : on ne re-tier QUE si le gain « rareté-coolness » est **net** ET le risque balance
> **faible**. Aucun cas du roster ne satisfait les deux. Détail ci-dessous.

## A.1 Mismatches résiduels — audit des 83 (arch réel vs imposance)

J'ai croisé le `arch=` réel de chaque unité (units.lua) avec l'`imposance` de sa forme (dictionnaire).
**Deux types de mismatch** possibles : (M1) rang BAS sur forme imp 9-10 « légendaire » ; (M2) R5 sur forme
peu imposante. Résultat :

### M1 — rang bas (R1-R3) portant une forme imposante (imp ≥ 8)

| Unité | rank | `arch` réel | imp | Cause | Verdict |
|---|---|---|---|---|---|
| **rot_grub** | **2** | hydra | **8** | famille `hydre` = **mono-forme** (hydra imp8 seule) | **GARDER** — forcé par la famille ; échelle uniforme ⟹ pas de débordement ; cadre R2 lit la rareté |
| **corruptor** | **3** | kraken | **9** | famille `kraken` = **mono-forme** (kraken imp9 seule) | **GARDER** — idem ; 2e palette KRAKEN distingue de deep_kraken (R5) |
| **soot_acolyte** | **3** | chimera | **9** | famille `chimere` = **mono-forme** (chimera imp9 seule) | **GARDER** — idem ; aura burn = support, R3 cohérent mécaniquement |
| **hookjaw** | **2** | behemoth | **7** | choix de PIN (bête imp7) | **GARDER** — imp7 ≠ « légendaire » ; behemoth < dragon(8) déjà évité |

Les trois M1 « durs » sont **structurels** (familles à 1 seule forme imp 8-9 : hydre, kraken, chimère). On
**ne peut pas** leur donner une forme moins imposante sans changer leur `family` (qui est PIN golden-neutre).
Comme l'échelle est uniforme, **l'imposance riche ne nuit pas** : elle donne juste une jolie silhouette à
une unité de rang moyen. C'est **acceptable et même souhaitable** (de la variété visuelle dans les rangs
bas). **Aucune promotion recommandée.**

### M2 — R5 sur forme peu imposante (le vrai risque pour « ELDER stylées »)

| Unité R5 | `arch` réel | imp | Suffisant ? |
|---|---|---|---|
| skull_colossus | skulltitan | **10** | ✔ apex famille crâne |
| pit_maw | devourer | **10** | ✔ apex famille larve |
| marrow_drinker | voidtyrant | **10** | ✔ apex famille ombre |
| venom_censer | embersac | **9** | ✔ apex famille cocon |
| deep_kraken | kraken | **9** | ✔ apex famille kraken (mono) |
| festering | fleshcrawler | **8** | ✔ apex famille cauchemar |
| **ash_maw** | possessed | **8** | ✔ apex famille culte (pas de imp9-10 culte) |
| **plague_pyre** | possessed | **8** | ✔ (2e palette possessed ; culte plafonne à imp8) |
| **slow_bleed** | stag | **6** | ⚠ **le seul R5 « faible » côté forme** (wendigo plafonne : wendigo imp7 > stag imp6) |
| wither_bloom | voidmaw | **8** | ✔ |

**Un seul cas notable : `slow_bleed` R5 sur `stag` (imp 6).** La famille `wendigo` n'a que 2 formes (wendigo
imp7, stag imp6) ; les deux autres R5 wendigo-adjacents (clot_mender, tendon_render) sont R3-R4 et portent
**wendigo** (imp7). Donc le seul R5 de la famille porte la **moins** imposante des deux formes.

→ **Recommandation (RENDER-only, golden-neutre, PAS un re-tier)** : **ré-assigner `slow_bleed` à `arch="wendigo"`**
(imp7) et basculer tendon_render (R4) sur `stag` (imp6). C'est un **swap de `arch=` dans la data**, **zéro
impact SIM** (firewall RENDER : la SIM ne lit jamais `arch`), **golden inchangé**. C'est le **seul ajustement
forme↔rang que je recommande**, et il n'est PAS un changement de rang. (À porter dans la passe RENDER, pas
en Phase C.)

## A.2 Conflits mono-forme signalés (§5) — trancher

La spec §5 listait rot_grub/corruptor/soot_acolyte comme « [CONFLIT dur] ». **Tranché : ACCEPTER, ne PAS
promouvoir.** Raison unique et suffisante : **`WORLD_FIT` uniforme**. Le conflit n'existait que sous
l'hypothèse « imposance ⟹ échelle in-game » — qui est **fausse** dans ce moteur. La forme riche est un
**bonus visuel** sur une unité de rang moyen, lu correctement parce que le **cadre de carte** (R2/R3) porte
la rareté. Promouvoir rot_grub R2→R4 « parce que hydra est imposant » serait :
- un **changement SIM gated** (rot_grub apparaîtrait moins tôt en boutique, déséquilibrant l'early poison) ;
- une **rupture du découplage** puissance/rareté (CLAUDE.md) ;
- inutile, puisque le débordement de plateau redouté **n'existe pas**.

## A.3 Table de re-tier — recommandation finale (DÉFAUT = GARDER)

| Unité | rang actuel | rang proposé | Justif. | Risque gating |
|---|---|---|---|---|
| **TOUTES (83)** | (actuel) | **GARDER** | forme↔rang déjà alignée par B.2 ; échelle uniforme ; rareté au cadre | n/a |
| slow_bleed | R5 | **GARDER R5** (mais swap `arch`→wendigo, RENDER-only) | seul R5 sur forme faible ; corrigé sans toucher le rang | **nul** (RENDER) |
| rot_grub | R2 | GARDER (ne pas promouvoir) | mono-forme hydre imp8 ; uniforme | promotion = casse early poison |
| corruptor | R3 | GARDER | mono-forme kraken imp9 ; palette distingue de deep_kraken | promotion = redondance avec deep_kraken R5 |
| soot_acolyte | R3 | GARDER | mono-forme chimère imp9 ; aura-support R3 cohérent | promotion = sur-coûte un support |

**Hypothèse signalée** : si l'user veut *malgré tout* lier rareté↔coolness (option « cool ⟹ ELDER » de
`creature-visual-retier`), alors rot_grub/corruptor/soot_acolyte (formes imp8-9) deviendraient candidats
R4-R5 — mais **ça touche le rank SIM**, exige un **re-baseline golden** + une **re-validation P3 complète**,
et **bloque la Phase C des command-auras** (la matrice de counters change si les rangs changent). **Hors
scope de cette prép.** Je tranche : **ne pas l'ouvrir avant que la Phase C command-aura soit close.**

---

# PARTIE B — Audit STATIQUE des 83 command-auras (prép Pass 3)

> Le tuning sera **data-driven** (sims P1/P3/P7). Ici : conformité aux caps + watchlist des cumuls/
> convergences + table `DESIGNED` raffinée. Comptages faits sur `src/data/units.lua` (83 unités, lu).

## B.1 Conformité aux caps — distribution réelle des leviers de commandement

Distribution des 83 `commandBonus` par levier (comptée sur la data réelle, **diffère légèrement** des
estimations §4.1 de la spec, qui tablait sur ~84 et des replis non encore tranchés) :

| Levier (`stat`/flag) | Cap de lecture | Nb unités | Magnitude observée | Sous le cap en SOLO ? |
|---|---|---|---|---|
| `dmgReduce` (team/role) | **`DMG_REDUCE_CAP=0.60`** | **16** | 0.04–0.08 team ; **0.20** role:front (gravewarden) | ✔ très loin du cap |
| `haste` (team) | **`HASTE_CAP=0.40`** | **10** | 0.04–0.08 | ✔ |
| `atkInc` (team/role/tier) | `ATK_INC_CAP=1.5` | **9** | 0.07 team ; 0.10–0.14 role/tier | ✔ |
| `regen` (team) | **AUCUN** ⚠ | **8** | 1–3 (entiers) | n/a (pas de cap — cf. risque) |
| `lifesteal` (team) | **AUCUN** ⚠ | **5** | 0.05–0.06 | n/a (pas de cap — cf. risque) |
| `poisonInc` (team) | `DOT_CAP_MULT=3` (output) | **6** | 0.16–0.22 | ✔ (cap sur l'output DoT) |
| `rotInc` (team) | `DOT_CAP_MULT=3` | **5** | 0.18–0.22 | ✔ |
| `burnInc` (team) | `DOT_CAP_MULT=3` | **5** | 0.18–0.22 | ✔ |
| `bleedInc` (team) | `DOT_CAP_MULT=3` | **4** | 0.18–0.22 | ✔ |
| `statInc` (tier:1/level:1) | `STAT_INC_CAP` | **4** | 0.14–0.30 | ✔ (baké, cappé au build) |
| `multicast` (role:front) | **`MULTICAST_MAX=3`** | **2** (maggot_king, hookjaw) | 1 | ✔ (entier) |
| `grant_team` transforms | flag-spécifique | **~14** | flags bornés | ✔ (cf. B.1.2) |
| `markEnemiesVuln` | `VULN_INC_CAP=0.5` (lecture) | **3** (corruptor, coil_viper, stormcaller) | 0.10–0.12 | ✔ |

> **Total > 83** car les ~14 `grant_team` recouvrent des unités déjà comptées comme afflicteurs ; ce qui
> compte : **aucun `commandBonus` ne dépasse son cap en solo**. Le cap se joue au **cumul**.

### B.1.1 Constat n°1 : la dette V0 est résolue — mais 2 leviers restent SANS cap

La spec command-aura tablait sur « haste/dmgReduce sans cap » (RISQUE #1) et recommandait `HASTE_CAP`/
`DMG_REDUCE_CAP`. **Vérifié dans `arena.lua` : ces deux caps EXISTENT** (l.48-49, lus en l.781 et l.373).
**RISQUE #1 partiellement neutralisé.** Restent **deux leviers de commandement sans cap de lecture** :

- **`regen`** (8 unités : plague_doctor, oath_keeper, ward_weaver, static_swarm, wailing_shade, rot_grub,
  mire_thing, + demon-adjacent). Lu en `arena.lua` (~tick de soin) **sans `math.min`**.
- **`lifesteal`** (5 unités : demon, carrion_pecker, hollow_gut, siphon_jelly, + lifesteal-adjacent). Lu
  en `hit()` (~l.377) **sans `math.min`**.

Ces deux-là ne menacent **pas la terminaison** (contrairement à haste≥1.0 qui ferait timer≤0), mais
peuvent créer un **sustain ingérable** vs builds sans pénétration de soin → **combats non-conclus** (à
détecter par fuzz `props.lua`) ou **gate de durée**. **Contrés** par `rot` (ampute maxHp), `pierceHeal`
(flag hollow_choir) — donc **pas une dette bloquante**, mais **à instrumenter** : la Phase C doit logger
`regen`/`lifesteal` cumulés et vérifier la terminaison sous le pire empilement (cf. watchlist W2).

### B.1.2 Constat n°2 : les `grant_team` transformatifs sont déjà bornés par leur handler

Les flags `grant_team` (ops.lua l.281-298, lu) sont **idempotents** (`max()` pour la plupart) ou booléens.
Aucun cumul explosif **entre commandants** (un seul piédestal). Le risque est le cumul **commandant × unité-
board × relique** du **même flag** :
- `poisonNoCap` (festering board + festering/plague_bearer commandant) → lève le cap de stacks à **99**
  (ops.lua l.65). C'est **voulu** (apex poison), mais c'est le seul flag qui **désactive un cap dur** →
  **watchlist W3**.
- `markEnemiesVuln` (corruptor/coil_viper/stormcaller commandant) **+** `grant_vuln` on_hit (corruptor/
  stormcaller unité) **+** `seers_mark` (relique) → s'**additionnent en flat** sur `vulnInc` AVANT le cap
  `VULN_INC_CAP=0.5` à la lecture. **Sûr** (cappé), mais à 3 sources la marque est **toujours au plafond**
  → la vuln devient « gratuite » globalement → **watchlist W4**.

### B.1.3 Empilements vers un cap (aura + effet perso + relique)

| Axe | Sources empilables | Cap | Pire cumul plausible | Sous le cap ? |
|---|---|---|---|---|
| **atkInc** | maggot_king aura (0.20) + zeal_inquisitor aura (0.12) + commandant atkInc team (0.07) + relique `blood_banner` | `ATK_INC_CAP=1.5` | ~0.4–0.6 | ✔ large marge |
| **multicast** | maggot_king/hookjaw cmd (1) + hookjaw unité aura (1) + `echo_crown` relique (1) | `MULTICAST_MAX=3` | 1+1+1 = **3** | ✔ **pile au cap** (voulu, test C6 existant) |
| **dmgReduce** | templar cmd team (0.08) + templar unité aura (0.12) + `aegis`/`tide_caller` relique + leech_thorn aura (0.06) | `DMG_REDUCE_CAP=0.60` | ~0.30–0.45 | ✔ mais **se rapproche** → W1 |
| **vulnInc** | markEnemiesVuln cmd (0.12) + grant_vuln on_hit (0.15) + `seers_mark` (0.5 ?) | `VULN_INC_CAP=0.5` | additif → clampé 0.5 | ✔ (toujours au plafond) → W4 |
| **poison output** | poisonInc cmd (0.22) + miasma_acolyte aura (0.5) + `kings_bowl` relique (~0.20) | `DOT_CAP_MULT=3` | ×~1.9 base | ✔ (cap ×3) → W3 si `poisonNoCap` ouvert |
| **haste** | bellows_priest cmd (0.08) + bellows_priest aura (0.12) + `whetstone` relique (~0.15) | `HASTE_CAP=0.40` | ~0.35 | ✔ **frôle** → W2 |

**Conclusion B.1 : aucun axe ne dépasse son cap**, mais **dmgReduce et haste frôlent** leur cap au pire
cumul, et **poison output peut saturer ×3** si `poisonNoCap` est posé. Ces 3 axes sont les **cibles
prioritaires** de la sim P3/P7.

## B.2 Risques signalés (de la campagne) — unités porteuses + combos à surveiller

### W1 — Convergence `dmgReduce` (« murs ennuyeux »)

**16/83 ≈ 19 %** des command-auras réduisent les dégâts (le plus gros bloc). La spec craignait la
**convergence** (trop d'unités → mur infranchissable = gate, scénario `tide_caller TANK 100%` déjà observé
en relicsim). **Porteurs `dmgReduce` (16)** :

> templar, skeleton (0.05), leech_thorn (0.06), web_recluse (0.06), storm_anchor (0.06), shieldbearer (0.06),
> bulwark_acolyte (0.06), husk (0.04), aegis_warden (0.08), rust_sentinel (0.08), runestone_golem (0.08),
> barrier_savant (0.08), mirror_ward (0.08), surge_warden (0.08), **gravewarden (0.20 role:front)**.

- **Combo à surveiller (P3 matrice all-tank)** : un board défensif + commandant `dmgReduce team 0.08` +
  relique `aegis`/`tide_caller` + aura `templar/leech_thorn` → `damage(cause=attack)` peut tomber sous le
  seuil de percée. `DMG_REDUCE_CAP=0.60` **borne** (le mur reste battable), mais **frôle**. **Métrique** :
  win% du matchup all-tank ≤ +2σ ; TTK non-divergent (pas de combat non-conclu).
- **god-roll candidat P7** : gravewarden cmd (dmgReduce role:front **0.20**) + gravewarden/aegis_warden unité
  (taunt) + relique `carapace` → l'avant-garde devient quasi-intouchable. **Borné** (0.60 cap + 1 cible),
  mais à inspecter (le taunt force le focus dessus → si elle est imperçable, le board derrière est gratuit).

### W2 — `haste` (terminaison) + `regen`/`lifesteal` (sustain sans cap)

- **`haste` (10)** : bellows_priest (0.08), bandit/spore_tick/live_wire (0.05), cinder_cur/byakhee/bore_worm
  (0.06), ash_moth (0.04). **Cappé `HASTE_CAP=0.40`** → **pas de timer≤0** (terminaison garantie). Combo
  `bellows_priest cmd + bellows_priest aura + whetstone` ≈ 0.35 → **frôle 0.40**. **Métrique P8** : timer
  d'attaque reste > 0 sous le pire cumul (régression déterministe).
- **`regen` (8)** + **`lifesteal` (5)** : **SEULS leviers SANS cap de lecture** (cf. B.1.1). **Combo à
  surveiller (props.lua fuzz)** : oath_keeper cmd (regen 3) + ward_weaver board + `second_breath` relique
  vs un build à faible DPS et sans pénétration → **combat non-conclu**. **Métrique** : 0 combat non-terminé
  sur le fuzz ; si non-terminaison → c'est la **dette V0-bis** (ajouter un soft-cap `regen`/`lifesteal` ou
  une fatigue ~17 s, déjà prévue CLAUDE.md). **Contre intentionnel** : rot/`pierceHeal` (à confirmer en P3).

### W3 — `multicast × afflicteur × ampli-école` (le snowball historique F11)

Le combo le plus dangereux (priorité #1 de la spec §6.3), maintenant avec **3 accès au multicast** :
- `maggot_king` **ou** `hookjaw` commandant (multicast role:front 1) **×** `hookjaw` unité (aura role:front 1)
  **×** `echo_crown` relique (multicast role:front 1) = **3 sources → cap MULTICAST_MAX=3** (1+1+1, **pile**).
- Si l'unité au front est un **afflicteur** (witch/corruptor/venom_censer) **×** une **aura ampli-école**
  voisine (miasma_acolyte poisonInc) **×** un **commandant ampli-école** (witch/venom_censer poisonInc team)
  → chaque sous-coup re-pose un poison **amplifié ×3** + re-applique la marque vuln.
- **Garde-fous en place** (vérifiés) : `MULTICAST_MAX=3`, `DOT_CAP_MULT=3` (output poison cappé),
  `WEAKEN_CAP=0.40`, `HIT_DMG_CAP_MULT=7` (chaque sous-coup borné ×7 dmg base), `SHOCK_STACK_CAP=8`.
  **MAIS** `poisonNoCap` (festering/plague_bearer) **lève le cap de stacks à 99** → le DoT/s reste cappé
  ×3 mais le **nombre de stacks** explose → DPS cumulé fort. **C'est l'intersection god-roll n°1 à
  sur-échantillonner (P7).**
- **Candidats god-roll P7 (à construire délibérément)** :
  1. `venom_censer` (cmd poisonInc team 0.22) + front=witch + `echo_crown` + `kings_bowl` + festering board
     (`poisonNoCap`) + miasma_acolyte adjacent.
  2. `maggot_king` (cmd multicast role:front) + front=corruptor (poison+vuln) + soot_acolyte/miasma adjacent.
  3. `arc_warden`/`stormlord` (cmd shockChain) + front=thunderhead (volt6) + storm_anchor (persist) →
     décharge chaînée.
- **Métrique P7/P8** : `lift < ~1.6` ; TTK p10 **stable** (pas de 1-swing) ; multicast effectif **≤ 3** ;
  combat **conclut**. **Ordre** : tester **AVANT** de considérer tout buff d'ampli-école.

### W4 — `markEnemiesVuln` ubiquité

**3 commandants** posent `markEnemiesVuln` (corruptor 0.12, coil_viper 0.10, stormcaller 0.10) **+** 2 unités
posent `grant_vuln` on_hit (corruptor, stormcaller) **+** relique `seers_mark`. Additif avant `VULN_INC_CAP
=0.5`. **Sûr** (cappé), mais à plusieurs sources la marque est **systématiquement au plafond** → la vuln
devient un acquis global plutôt qu'un choix. **À surveiller (P3)** : la vuln-team ne doit pas, combinée à un
ampli-école, faire **gagner sous le coût** un build poison vs un build qui devrait le contrer. **Pas un
risque de cap** (clampé), un **risque de banalisation** (érode la décision d'enabler).

## B.3 Table `DESIGNED` (counters intentionnels) — confirmer/raffiner

La table existe déjà (`tools/runsim.lua` l.34-36, **6 entrées**). Elle est **correcte mais incomplète** pour
le contexte command-aura (la marque vuln + le strip-shield créent des counters **voulus** que le moteur de
sim ne doit PAS flagger). **Raffinement proposé (6 → 9)** :

```lua
-- COUNTERS DESIGNÉS (attaquant > défenseur = ATTENDU -> jamais flaggé).
local DESIGNED = {
  -- existants (vérifiés, à conserver) :
  ["rot>tank"]   = true,  -- rot ampute maxHp -> ronge le mur (anti-tank par design)
  ["poison>tank"]= true,  -- DoT ignore l'armure d'attaque -> perce le tank
  ["burn>tank"]  = true,  -- idem
  ["shock>tank"] = true,  -- décharge ignore le bouclier -> perce le tank
  ["bleed>bruiser"] = true, -- slow + DoT use le bruiser (faible sustain)
  ["tank>bruiser"]  = true, -- le mur soak le bruiser sans DoT
  -- AJOUTS pour le contexte command-aura / anti-méta (counters VOULUS, sinon faux positifs) :
  ["bleed>tank"] = true,  -- NOUVEAU : bleed est aussi un DoT -> perce le tank (cohérent avec poison/burn/rot>tank)
  ["antishield>shield"] = true, -- NOUVEAU : siege_breaker/acid_maw (stripEnemyShield) vs builds bouclier (anti-méta VOULU)
  ["antiheal>sustain"]  = true, -- NOUVEAU : plague_doctor purge / rot pierceHeal vs builds regen/lifesteal (le contre-DoT EST censé gagner)
}
```

**Justifications** :
- **`bleed>tank`** : la table actuelle a poison/burn/rot/shock > tank mais **PAS bleed**, alors que bleed
  est un DoT qui ignore l'armure d'attaque exactement comme les autres. **Omission probable** — à confirmer
  en P3 (si bleed bat tank > 60 % sous coût, c'est **voulu**, pas un bug). *Hypothèse signalée* : si la sim
  montre que bleed ne perce PAS le tank (slow ≠ amputation), retirer cette ligne. À trancher par la donnée.
- **`antishield>shield`** : siege_breaker + acid_maw (commandant `stripEnemyShield`) sont des **anti-méta
  intentionnels** vs les builds bouclier (ward_weaver/oath_keeper/aegis_warden). Sans cette entrée, le
  moteur flaggerait un counter **voulu**. Nécessite que `runsim.lua` ajoute un archétype « antishield » à
  `ARCH_COMP` (sinon inerte — à implémenter en P3).
- **`antiheal>sustain`** : plague_doctor (purge poison bornée) + tout porteur `pierceHeal` sont censés
  **gagner** vs les builds regen/lifesteal (W2). Counter voulu → ne pas flagger.

> Ces 3 ajouts **ne touchent que `tools/runsim.lua`** (data de sim, hors SIM de combat, golden-neutre). Les
> 2 derniers exigent d'ajouter les archétypes « antishield » / « sustain » aux compos de référence (P3).

---

# WATCHLIST PRIORITAIRE — ce que la Phase C doit surveiller EN PREMIER

> Ordre = priorité d'instrumentation. Chaque ligne mappe à un scénario de la méthodo
> (`balance-psychology-and-sim-methodology.md §4`).

| # | Watch | Unités / combos | Cap concerné | Scénario sim | Seuil d'alerte |
|---|---|---|---|---|---|
| **W3** | **multicast × afflicteur × ampli-école × poisonNoCap** | venom_censer/witch cmd + front afflicteur + echo_crown + miasma_acolyte + festering board | `MULTICAST_MAX=3`, `DOT_CAP_MULT=3`, `poisonNoCap`→99 stacks | **P7** (god-roll explorer, importance sampling) + **P8** (régression caps) | `lift>1.6` ; TTK p10 1-swing ; combat non-conclu ; 1 combo monopolise la queue |
| **W2a** | **haste cumulé (terminaison)** | bellows_priest cmd + bellows_priest aura + whetstone | `HASTE_CAP=0.40` | **P8** (déterministe, 1 seed) | timer d'attaque ≤ 0 (NON-TERMINAISON — priorité absolue) |
| **W2b** | **regen/lifesteal SANS cap (sustain ingérable)** | oath_keeper/ward_weaver/static_swarm cmd + reliques sustain vs low-DPS | **AUCUN** ⚠ | **P0/props.lua** (fuzz terminaison) | combat non-conclu > 0 → dette V0-bis (soft-cap ou fatigue) |
| **W1** | **convergence dmgReduce (murs)** | all-tank board + dmgReduce cmd + aegis/tide_caller + gravewarden role:front 0.20 | `DMG_REDUCE_CAP=0.60` | **P3** (matrice all-tank) + **P7** (gravewarden front) | win% all-tank > +2σ ; gate (mur infranchissable) ; gagne sous coût hors DESIGNED |
| **W4** | **markEnemiesVuln ubiquité** | corruptor/coil_viper/stormcaller cmd + grant_vuln unité + seers_mark | `VULN_INC_CAP=0.5` | **P3** (counters) + **P1** (invest) | vuln-team + ampli fait gagner SOUS le coût un build qui devrait être contré |
| **W5** | **statInc conditionnel mal-tuné** | galvanizer (tier:1), deep_kraken (level:1), skull_colossus/wither_bloom (tier:1 0.30) | `STAT_INC_CAP` | **P1** (invest contextualisé) | déjà nerfé 0.50→0.14/0.15 car >+2σ EARLY ; re-vérifier que le payoff reste TARDIF (pas un buff early) |

**Notes de méthode pour la Phase C** (tirées de la méthodo, à ne pas réinventer) :
- **Juge suprême = win-rate contextualisé par investissement** (`compcost`) : ne flagger QUE ce qui gagne
  **sous son coût**, **hors `DESIGNED`**. Un board cher (apex + reliques) qui atomise un board pauvre = **sain**.
- **1 seul levier varié par itération**, reste figé, **même seed batch**, `report.json` diff-é.
- **Un seul piédestal** ⟹ les 83 auras sont un **menu, pas une somme** : elles ne s'additionnent jamais
  entre elles. Le power-creep vient du **cumul avec relique + aura d'adjacence + effet perso**, pas du nombre
  d'auras. C'est ce cumul (W1-W4) que la sim cible, pas chaque aura isolée.
- **W5 déjà traité partiellement** : galvanizer (0.50→0.14) et deep_kraken (0.40→0.15) ont **déjà** été
  nerfés (commentaires data) car >+2σ EARLY (tier:1/level:1 = tout le board tôt). **Re-confirmer** que le
  payoff reste tardif après les autres ajustements (un nerf ailleurs peut les re-déséquilibrer).

## Hypothèses tranchées (signalées)

1. **`arch=` est figé en data sur les 83 unités** → le mapping forme↔unité de la Partie A est factuel, pas
   spéculatif (contrairement aux propositions §4 de `bestiary-port-spec`, antérieures au PIN v7).
2. **`bleed>tank` est un counter VOULU** (omission de la table actuelle) — à confirmer par P3 ; retirer si
   la donnée montre que bleed ne perce pas le tank.
3. **Les 2 leviers sans cap (regen/lifesteal)** ne sont PAS une dette bloquante (contrés par rot/pierceHeal)
   mais doivent être **instrumentés** (W2b) ; si non-terminaison observée → soft-cap/fatigue (V0-bis).
4. **Aucun re-tier de rang recommandé** ; le seul ajustement forme↔rang (slow_bleed→wendigo) est **RENDER-
   only, golden-neutre, hors Phase C**.
5. **Option « cool ⟹ ELDER » NON ouverte** : elle toucherait le rank SIM, exigerait re-baseline golden +
   re-validation P3, et **bloquerait** la Phase C command-aura. À reporter après clôture de la Phase C.
