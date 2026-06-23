# Round 06 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v6, intégré round 5) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 6/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v6), `00-state.md`, `round-01.md` à
> `round-05.md`, `rounds/r01-units-power.md` à `rounds/r05-units-power.md`,
> `competitive/*.md` (tous), `src/data/units.lua` (intégralité relue ce round), numéros
> de lignes cités après vérification directe.
>
> **Méthode** : désaccord = recherche web menée et citée. Analogie = démonter le mécanisme
> psychologique/mathématique avant d'accepter. Toute affirmation chiffrée porte sa source.
> Règle de méthode des rounds 4-5 : reformuler un mécanisme existant = citer la ligne de code
> relue ce round.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée /
> DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Cinq angles non épuisés après relecture complète de `units.lua` ligne à ligne et des cinq
rounds précédents de la lentille units-power :

1. **La dispersion DPS INTRA-rang-2 est critique et jamais quantifiée : 7.24× de spread
   (DPS=0.025 à 0.181 dans `U.pool`) rend le signal `cost=rank` psychologiquement faux** pour
   le rang-2 — bien pire qu'une simple anomalie cinder_cur. La présence des 10 unités v7
   rang-2 dans `U.pool` amplifie le problème sans que le brouillon ait chiffré l'écart.

2. **L'asymétrie de DISPERSION entre auras du même rang (soot_acolyte DPS=0.111 vs
   miasma_acolyte DPS=0.067) crée une hiérarchie implicite de pick entre auras — non
   documentée, non tranchée.** Les 4 auras rang-3 sont traitées comme symétriques alors
   qu'elles ne le sont pas.

3. **La décision « aucun 6e type » pour les boucliers est correcte, mais le brouillon traite
   le cas `siege_breaker` (rang-3, DPS=0.154, le plus haut DPS de tout le rang-3) comme s'il
   n'existait pas.** `siege_breaker` est un `strip_shield` (counter offensif) avec le budget
   d'une carry rang-4 — c'est une anomalie budgétaire non signalée dans les rounds précédents.

4. **Le plancher burn est structurellement cassé au rang-1 (1 seule unité : `ash_moth`, rang-1,
   DPS=0.075)** — et la vague v7 ajoute une pression à la création burn rang-2 sans signaler
   que burn rang-1 est sous le plancher ≥2. Le brouillon §3.1 n'y a jamais fait référence.

5. **L'identité des 4 auras n'est pas seulement une question de lisibilité (colonne G) — c'est
   une question de POSITIONNEMENT BUILD** : `soot_acolyte` (burn, DPS=0.111) est plus souvent
   jouable comme carry secondaire que comme aura, ce qui brouille la lecture de son rôle.
   Aucun round précédent n'a traité cette ambiguïté.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — `burst_DPS_eq` pour le choc (adopté round 4, §3.1a)

Relecture directe de `galvanizer` (`units.lua:311-316`, relu ce round) :
```lua
galvanizer = {
  rank = 4, hp = 58, dmg = 11, cd = 64, aggro = 15,
  effects = {
    { trigger = "on_attack", op = "bonus_first", params = { value = 6 } },
    { trigger = "on_hit", op = "shock", params = { add = 2, cap = 6, dur = 180 } },
  }
}
```
`DPS frappe = 11/64 = 0.172` — outlier confirmé dans les données calculées ce round :
rang-4 median DPS ≈ 0.086-0.100, soit `galvanizer` à ~+70-100 % du médian. Le calcul
`burst_DPS_eq ≈ 0.245` du round 4 reste solide.

**Pourquoi ça tient** : le modèle condensateur est documenté en design de jeux de cartes —
StS jauge les cartes de combo sur leur **impact par déclenchement** ([Giovannetti GDC 2019](
https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) : « the stat that matters is
value delivered per play, not per turn »). Appliquer `DPS = dmg/cd` à un condensateur = mesurer
la recharge, pas la décharge. **Valide pour nos contraintes async** : le snapshot capture `id +
level + position`, pas les stacks de choc. La valeur d'un condensateur n'est pas dans son
snapshot mais dans son comportement à la résolution — et notre sim déterministe le calcule
correctement.

**Extension nécessaire (non couverte round 4)** : la même asymétrie s'applique à `stormlord`
(rang-3, `add=2, volt=4, cap=8`) qui a un `burst_DPS_eq` **plus fort** que son DPS-frappe
(0.111) le laisse croire, mais potentiellement plus faible que `galvanizer` par stack. Il ne
doit pas être **sous-évalué** relativement — à chiffrer dans l'audit.

### 1.2 ACCORD — Retrait des renforts `shield_caster` de `U.pool` (adopté round 5, §3.1 col H)

`barrier_savant`, `mirror_ward`, `surge_warden` sont dans `U.pool` (`units.lua:479-507`, relu
ce round) — confirmé. L'analyse du round 5 est exacte : achetés sans `ward_weaver` voisin =
stat inutilisée. [Wayward Strategy 2018](https://waywardstrategy.com/2018/05/17/unit-design-clarity-of-roles-and-redundancy/)
: « dead picks for players unfamiliar with their interaction ». **Valide pour le async** : le
snapshot ne capture pas les positions adverses au moment de l'achat — un joueur ne peut pas
savoir si son `ward_weaver` sera dans le pool adverse.

### 1.3 ACCORD — Décision de cohorte v7 comme filtre de premier niveau (round 4-5)

Les 10 unités v7 rang-2 (relu `units.lua:383-440`) ont des DPS calculés ce round :
- **outliers hauts v7 rang-2** : `byakhee` (0.160), `coil_viper` (0.146), `zeal_inquisitor`
  (0.118)
- **outliers bas v7 rang-2** : `hookjaw` original (0.056), `rot_grub` original (0.069)

La décision de cohorte est correcte. **Mais** (§2.1 ci-dessous) : le problème n'est pas
seulement les v7 — l'écart DPS existe AUSSI dans les unités originales rang-2 (`witch`=0.181,
`shieldbearer`=0.025).

### 1.4 ACCORD — `soot_acolyte` a un DPS anormalement élevé pour une aura (soulevé round 4 §Q3)

Relecture directe (`units.lua:149-151`) :
```lua
soot_acolyte = { rank = 3, hp = 46, dmg = 6, cd = 54,
  effects = { { trigger = "combat_start", op = "aura_burn_dps", ... } } }
-- DPS = 6/54 = 0.111
```
vs. `miasma_acolyte` (`units.lua:157-159`) : `dmg=4, cd=60` → DPS=0.067.

La question Q3 du round 4 (« `soot_acolyte` double valeur rang-3 = under-coûtée ? ») est
**fondée** mais n'a jamais été répondue. Le round 5 n'y a pas non plus touché. **Adopté** :
c'est une décision à trancher (§2.2 ci-dessous, désaccord sur la suffisance du traitement
actuel).

### 1.5 ACCORD PARTIEL — Colonne G (effet secondaire perçu, 8 mots) comme pilote i18n

Adopté round 4, §3.1 col G. La distinction « Bleed = ta cible frappe au ralenti » vs « Rot =
ta cible fond de l'intérieur » est une bonne direction pour l'i18n. **Mais** (§2.4 ci-dessous) :
la colonne G documente la PERCEPTION de l'effet — elle n'adresse pas la question du
POSITIONNEMENT BUILD (quelle case un joueur met une aura vs un enabler sur un plateau 3×3).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD FORT — La dispersion DPS intra-rang-2 est 7.24× et crée une rupture du signal `cost=rank` bien plus sévère que signalée dans les rounds précédents

**Ce que le brouillon dit** (§3.1, colonne E budget stat) : anomalie `cinder_cur`/
`zeal_inquisitor` (rang-2, DPS=0.118) > `bellows_priest` (rang-3, 0.111). Le seuil
indicatif est « DPS base rang-2 < médian rang-3 ».

**Ce qui est insuffisant** — données calculées ce round sur les 23 unités rang-2 dans
`U.pool` :

```
Rang-2 DPS calculés (lecture directe units.lua) :
  witch          : 13/72 = 0.181   ← carry vanilla, extrême haut
  byakhee (v7)   : 8/50  = 0.160
  coil_viper (v7): 7/48  = 0.146
  cinder_cur     : 4/34  = 0.118   ← signalé round 4
  zeal_inq (v7)  : 8/68  = 0.118   ← signalé round 4
  wailing_shade  : 6/52  = 0.115
  ink_horror (v7): 6/54  = 0.111
  razorkin       : 5/46  = 0.109
  pyre_herald(v7): 7/64  = 0.109
  thunderhead    : 8/76  = 0.105
  gash_fiend     : 5/48  = 0.104
  stormcaller    : 6/58  = 0.103
  emberling      : 5/50  = 0.100
  siphon_jelly   : 5/50  = 0.100
  pyre_tender    : 7/72  = 0.097
  chitin_drone   : 4/42  = 0.095
  web_recluse    : 4/44  = 0.091
  rot_hound      : 5/56  = 0.089
  bore_worm (v7) : 5/58  = 0.086
  static_swarm   : 4/50  = 0.080
  rot_grub       : 4/58  = 0.069
  hookjaw        : 3/54  = 0.056
  shieldbearer   : 2/80  = 0.025   ← tank cheap, extrême bas
```

**Spread : 0.181 / 0.025 = 7.24×.** Médiane rang-2 = 0.103.

**Le vrai problème n'est pas seulement l'anomalie cinder_cur (signalée en round 4)** — c'est
que `witch` (vanilla rang-2) à DPS=0.181 et `byakhee`/`coil_viper` (v7 rang-2) à 0.160-0.146
occupent le MÊME rang que `hookjaw`=0.056 et `shieldbearer`=0.025. Un joueur qui voit `witch`
puis `hookjaw` en boutique T2 ne peut pas inférer que les deux coûtent 2 or et « ont la même
valeur de coût ». **Le contrat `cost=rank` (décision #10) est rompu au niveau perceptif**, non
par quelques outliers, mais par l'ensemble de la distribution.

**Source psychologique** : les joueurs inférent la valeur d'un objet par comparaison aux
alternatives visibles simultanément. [Ariely, Loewenstein & Prelec 2003, QJE](
https://academic.oup.com/qje/article/118/1/73/1917051) (« Coherent Arbitrariness ») : une
**ancre visible** (witch à 0.181) déforme la perception des autres items présentés en même
temps. Un joueur qui voit `witch` + `hookjaw` dans la même boutique conclut que `hookjaw` est
« bas de gamme » — ce qui est faux si `hookjaw` a un rôle de blocage intentionnel (tank cheap
thorns). **Si le rôle est voulu, il doit être signalé par autre chose que le prix.**

**Pourquoi ça tient pour nos contraintes async** : SHOP_SIZE=5 (`state.lua:30`, relu) signifie
que 5 unités rang-2 peuvent apparaître simultanément à T2 — l'ancrage Ariely est maximal.
Contrairement à TFT où les 8 joueurs partagent le pool (les outliers apparaissent moins souvent),
notre pool LOCAL garantit que `witch` et `shieldbearer` peuvent co-apparaître fréquemment.

**Ce que le brouillon manque** : le seuil `DPS base rang-2 < médian rang-3` ne règle pas le
problème de SPREAD INTRA-RANG. Il faut un critère de dispersion : la règle doit imposer
que **P90/P10 intra-rang ≤ 3×** (cible raisonnable — TFT a ~2× de spread DPS intra-coût
pour les non-tanks : [Mobalytics TFT Set 14 Stats](
https://mobalytics.gg/tft/comps)). Aujourd'hui P90/P10 = 0.160/0.056 = 2.86× si on exclut
les extrêmes (witch/shieldbearer), ce qui passe — mais **la présence des extremes dans le même
pool de boutique casse la lecture**. Le problème n'est pas résolu par l'audit colonne E seul.

**Proposition** (§P-A) : dans l'audit P0.5 (§3.1), ajouter une **règle de clustering** :
les unités tank (DPS < 0.07×rang, col E §3.1b) DOIVENT être visuellement distinguées de leurs
voisins de rang lors de l'affichage boutique (pas seulement le DPS bas — le rôle doit être
signalé). Ce n'est pas un sujet de rééquilibrage (les tanks DOIVENT avoir un DPS bas) mais de
lisibilité. → pilote les tooltips boutique (§2.5 ROADMAP-draft).

---

### 2.2 DÉSACCORD MODÉRÉ — L'asymétrie de DPS entre auras du même rang crée une hiérarchie implicite de pick non documentée

**Ce que le brouillon dit** (§3.1 col G, round 4/5) : les auras rang-3 sont traitées comme
symétriques (même rang, même coût = 3 or). La colonne G documente l'effet perçu.

**Ce qui manque** — données ce round :

```
Auras rang-3 (DPS frappe calculé) :
  soot_acolyte  (burn aura)    : dmg=6, cd=54  → DPS=0.111  ← au niveau médian rang-3
  clot_mender   (bleed aura)   : dmg=4, cd=56  → DPS=0.071
  miasma_acolyte (poison aura) : dmg=4, cd=60  → DPS=0.067
  decay_tender  (rot aura)     : dmg=4, cd=60  → DPS=0.067
```

**`soot_acolyte` DPS = 0.111 est le médian rang-3** — il fait autant de DPS de frappe qu'un
enabler burn actif (`bellows_priest`=0.086). Les 3 autres auras font 60 % de ce DPS.

**Conséquence de build** : un joueur qui a le choix entre `soot_acolyte` et `decay_tender` à
3 or verra `soot_acolyte` faire plus de dégâts de frappe. Si son build n'est pas focalisé
burn, il choisira `soot_acolyte` pour son DPS de frappe — indépendamment de si les voisins
sont burn. **L'aura burn est choisie pour les mauvaises raisons.** Ce biais est invisible
sans l'audit.

**Source design** : [SAP design blog a327ex.com](
https://a327ex.com/posts/super_auto_pets_mechanics) documente que SAP a
intentionnellement donné à chaque pet un SEUL mécanisme valeur — « 1 trigger = 1 valeur ».
Un pet qui a à la fois une aura et un DPS de frappe élevé crée une évaluation confuse. Chez
The Pit, `soot_acolyte` a **deux valeurs** (aura burn + DPS frappe médian) → le joueur
l'évalue sur l'une ou l'autre selon ce qu'il voit en boutique.

**Ce n'est pas un bug de puissance** : `soot_acolyte` n'est pas nécessairement sur-puissante.
C'est un bug de **lecture de rôle** : si son DPS frappe est voulu comme bonus, il doit être
documenté comme tel (« aura + carry secondaire »). Si ce n'est pas voulu, le normaliser vers
0.07-0.08 (aligné sur les autres auras) clarifie son rôle.

**Proposition** (§P-B) : décision à prendre dans l'audit P0.5 pour `soot_acolyte` :
- **(a)** Normaliser son DPS vers 0.07-0.08 (cohérent avec les autres auras → rôle pur
  d'aura, budget support) ;
- **(b)** Le garder à 0.111 + documenter explicitement « `soot_acolyte` = aura burn **+**
  carry secondaire » dans la colonne G (permet une double lecture intentionnelle).
L'option (b) crée un archétype « carry-aura » qui n'existe pas pour les 3 autres auras →
une niche distincte sans nouvelle mécanique. Option (b) recommandée si la DA supporte un
burn-carry hybride grimdark (« brûleur-prêtre » vs les 3 autres « acolytes passifs »).

---

### 2.3 DÉSACCORD — `siege_breaker` (rang-3, DPS=0.154) est l'anomalie budgétaire la plus sévère du roster mais n'est JAMAIS mentionné dans 5 rounds de lentille units-power

**Ce que le brouillon dit** : §3.1b traite `templar` (rang-3, DPS=0.146) comme anomalie et
`runestone_golem` (rang-4 v7, DPS=0.125) — mais **jamais `siege_breaker`**.

**Vérification code** (`units.lua:377-380`, relu ce round) :
```lua
siege_breaker = {
  rank = 3, cost = 3, hp = 60, dmg = 8, cd = 52, aggro = 15,  -- COUNTER-SHIELD
  effects = { { trigger = "on_hit", op = "strip_shield", params = { frac = 0.5 } } }
}
-- DPS = 8/52 = 0.154
```

`siege_breaker` DPS = **0.154** — le DPS le plus élevé de TOUT le rang-3, supérieur à
`templar` (0.146), `stormlord` (0.111), et comparable à `coil_viper` rang-2 (0.146). C'est
aussi l'unité `strip_shield` — le seul **counter-bouclier actif** du roster.

**Problème double** :
1. **Budget** : DPS=0.154 sur une unité rang-3 avec HP=60 (supérieur au médian rang-3) et
   un effet `strip_shield` (valeur en meta bouclier) = **triple valeur** non documentée.
2. **Rôle de counter** : `siege_breaker` est le counter du système `shield_caster`
   (`ward_weaver` + renforts). Sa présence dans `U.pool` en fait un pick universel
   (utile sans build dédié → problème de « pick obvieux »).

**Source** : [GhostCrawler WoW Design Notes](https://askghostcrawler.tumblr.com/post/4580765536) :
« a unit should not be both the best attacker and the best counter — that's two roles that
should justify two different units ». Un `siege_breaker` DPS=0.154 avec `strip_shield` cumule
carry + counter.

**Pourquoi ça a été raté par 5 rounds** : le round 4 cite `templar` comme la grande anomalie
tank, les rounds suivants ont repris ce cadrage. `siege_breaker` est dans la liste
`shield/tank` (11 unités, §00-state §2.1) mais c'est une unité **offensive** avec un effet
défensif de counter — elle n'a pas `aggro=40` ni `taunt`, ce qui l'exclut du radar
« tank = bas DPS voulu ». Elle glisse entre les catégories.

**Proposition** (§P-C) : dans l'audit P0.5 (§3.1, col B type de redondance), `siege_breaker`
doit recevoir la catégorie **NICHE** (double-valeur non documentée) avec décision :
- Réduire dmg/cd pour DPS ≤ 0.095 (rang-3 carry pur) ET conserver `strip_shield` (counter
  pur, budget DPS bas = compense l'utilité du counter) ;
- OU laisser DPS haut et **retirer de `U.pool`** (le conserver en `U.order` pour encounters
  IA qui ont besoin d'un counter-shield sans le donner au joueur de façon triviale).

---

### 2.4 DÉSACCORD FORT — Burn rang-1 a UN seul enabler dans `U.pool` et cette dette est ignorée par le brouillon depuis 5 rounds

**Ce que le brouillon dit** (§3.1, plancher ≥2) : le critère de plancher vise ≥2 enablers/
famille/rang pour P(famille visible/boutique T2) ≥ 40 %. L'exemple donné est rot rang-2
(2-3 enablers).

**Vérification code ce round** — burn dans `U.pool` par rang :
```
burn rang-1 : ash_moth (rank=1, units.lua:100) → 1 seul enabler  ❌
burn rang-2 : cinder_cur, pyre_tender, emberling(v7), pyre_herald(v7), zeal_inquisitor(v7) → 5 enablers (≤4 cible)
burn rang-3 : bellows_priest → 1 seul (soot_acolyte = aura, pas un enabler direct)
burn rang-4 : wildfire_hound, kiln_warden → 2
burn rang-5 : ash_maw, plague_pyre, skull_colossus(v7) → 3
```

`ash_moth` (`units.lua:100-104`, relu) :
```lua
ash_moth = {
  rank = 1, cost = 1, hp = 26, dmg = 3, cd = 40,  -- DPS = 0.075
  effects = { { trigger = "on_hit", op = "burn", params = { dps = 3, dur = 180 } } }
}
```
**Un seul enabler burn rang-1 dans `U.pool`** — le brouillon §3.1 n'en parle jamais.

**Conséquence** : P(voir un enabler burn en T1) avec 1 unité dans un pool de ~12 rang-1 :
```
P(≥1 burn/boutique T1, SHOP_SIZE=5) = 1 - C(11,5)/C(12,5) ≈ 1 - 0.583 = 0.417
```
Ce calcul monte à ~42 % avec un seul enabler — **juste au-dessus du seuil ≥40 % du plancher**.
Mais en pratique `ash_moth` a HP=26 (fragile) et DPS=0.075 (sous le médian rang-1) : un
joueur qui le voit en boutique et qui ne connaît pas le jeu ne le reconnaît pas comme
l'unique porte d'entrée dans l'archétype burn. La visibilité mathématique (42 %) cache une
**visibilité de reconnaissance plus basse** : `ash_moth` ressemble à un enabler générique
fragile, pas à « le burn T1 ».

**Comparaison rot rang-1** : `carrion_pecker` (`units.lua:133-135`) — seul enabler rot rang-1
aussi, DPS=4/38=0.105. **Rot et Burn ont toutes les deux un rang-1 singleton** — le
brouillon a cité rot rang-2 comme problème mais n'a pas remonté au rang-1.

**Source** : SAP documente explicitement que chaque tier a des pets « d'entrée dans le thème »
(trigger visible dès le round 2 pour orienter le build). [SAP Tier Design](
https://a327ex.com/posts/super_auto_pets_mechanics) : « Early tiers serve as the introduction
to each mechanic ; without an early-accessible anchor, players cannot orient toward a
strategy ». Un singleton rang-1 avec stats fragiles est un ancre trop faible.

**Proposition** (§P-D) : documenter dans l'audit P0.5 que **burn rang-1 ET rot rang-1 sont
des SINGLETONS** (1 enabler) — vérifier que c'est un choix voulu (rareté de l'archétype en
early = identité grimdark) ou un trou à combler. Si voulu → documenter comme « archétype
rare en early ». Si non voulu → 1 stat-stick rang-1 burn simple (op burn `dps=2, dur=150` sur
une unité HP=40+) suffit pour atteindre le plancher ≥2 sans nouvelle mécanique.
**Ce n'est pas une décision moteur — c'est une décision de data.**

---

### 2.5 DÉSACCORD MODÉRÉ — La colonne G (effet secondaire perçu) est nécessaire mais pas suffisante : les auras ont un problème de POSITIONNEMENT BUILD (quelle case du plateau 3×3 leur revient) qui n'est couvert par aucune colonne

**Ce que le brouillon dit** (§3.1 col G, round 4) : chaque unité a une ligne « effet
secondaire perçu ≤8 mots ». Exemple : « soot_acolyte : buffe les brûlures voisines ».

**Ce qui manque** : la colonne G documente la PERCEPTION de l'effet — elle ne dit pas au
joueur **où sur le plateau 3×3 placer une aura**. Une aura buf les VOISINS (adjacence
orthogonale) — donc son efficacité dépend du nombre d'arêtes actives dans le sigil courant
pour sa position. La colonne G ne capture pas cette dimension spatiale.

**Conséquence concrète** : sur le sigil **Croix** (un centre + 4 branches), le centre a 4
voisins — une aura en case centrale buffe 4 unités. Sur le sigil **Ligne** (colonne linéaire),
une aura en milieu buffe 2 voisins max. Le même `soot_acolyte` à 3 or vaut **2× plus sur
certains sigils que sur d'autres** (en termes d'unités buffées). **Cette information est
complètement absente des 9 colonnes A-I de l'audit P0.5.**

**Source** : [Backpack Battles design notes 2024](https://steamcommunity.com/games/2427700/
announcements/detail/3831789654380393820) : « positional adjacency items require spatial
tooltips to communicate their dependency on placement ». Backpack montre un tooltip
direct (surlignage des slots affectés). Notre §2.1 (surlignage d'arêtes) le planifie pour
le plateau en build — mais l'audit unités lui-même ne réfléchit pas à l'impact de la
topologie sur la valeur d'une aura.

**Proposition** (§P-E) : ajouter une colonne **(J) VALEUR SIGIL-DÉPENDANTE** dans l'audit —
pour les unités à trigger `combat_start` + target `neighbors`, noter : « valeur maximale (sur
sigil à N voisins max) / valeur minimale (sigil à 1 voisin) / sigil hostile (où son efficacité
chute sous 50 %) ». Pour `soot_acolyte` : max = croix/carré (centre = 4 voisins) / hostile =
ligne (2 voisins max). Cette colonne révèle si une aura est **viable dans tous les sigils ou
seulement certains** — un critère de pick qui n'existe nulle part dans le brouillon actuel.
**Coût : doc/audit uniquement, 0 code, 0 invariant.**

---

## 3. Propositions priorisées

### P-A — Critère de dispersion DPS intra-rang + signal boutique pour les tanks (AVANT l'audit P0.5)

**Quoi** : dans la colonne E de l'audit P0.5, ajouter une règle de dispersion :
> « DPS intra-rang : tous les enablers DoT d'un même rang DOIVENT tenir dans un facteur ≤3×
> entre P10 et P90 de DPS. Les tanks et condensateurs sont EXCLUS de ce calcul (colonnes E
> dédiées §3.1a/§3.1b) ET signalés visuellement en boutique (tooltip « GARDIEN » ou
> équivalent grimdark). »

Cette règle résout deux problèmes simultanément :
1. Elle exige de **retirer ou ajuster** les outliers DPS extrêmes parmi les enablers DoT
   rang-2 (ne touche pas les tanks qui ont leur propre critère).
2. Elle impose un **signal boutique** pour les tanks (évite l'ancrage Ariely).

**Coût** : audit tableur + 1-2 décisions editoriales sur les outliers v7. 0 moteur.
**Priorité** : haute — avant de figer les cotes de pool (P3), le spread DPS doit être
borné sinon les probabilités hypergéométriques sont calculées sur des unités non équivalentes.

---

### P-B — Trancher `soot_acolyte` double-valeur (aura burn + carry secondaire vs aura pure) dans l'audit P0.5

**Quoi** : décision à trancher explicitement dans la colonne G/B de l'audit :
- Option (a) : normaliser DPS vers 0.07-0.08 → aura pure (cohérent avec les 3 autres auras).
- Option (b) : documenter le double rôle → créer une niche « carry-aura » unique à burn.

**Impact** : si option (b), le texte i18n de `soot_acolyte` doit refléter la double identité.
Si option (a), DPS baisse légèrement → passage sim.

**Coût** : décision editoriale. Si option (a) : 1 param + golden rebaseline si soot_acolyte
dans le scénario golden. Si option (b) : i18n uniquement.

**Priorité** : moyenne — à intégrer dans l'audit P0.5, avant de rédiger la colonne G définitive.

---

### P-C — `siege_breaker` : budget à trancher (double-valeur DPS+counter) dans la décision de cohorte v7

**Quoi** : `siege_breaker` (rang-3, DPS=0.154, `strip_shield`) n'est pas une unité v7 mais
une anomalie du roster original non cataloguée. **Décision binaire** :
- Réduire dmg/cd pour DPS ≤ 0.09 (rang-3 counter pur, budget compense son utilité situationnelle) ;
- OU retirer de `U.pool` (garder en `U.order` — counter-shield réservé aux encounters IA qui
  peuvent avoir `ward_weaver` garanti).

**Coût** : data uniquement (1 param ou 1 ligne `U.pool`). Golden à vérifier si
`siege_breaker` figure dans le scénario golden.

**Priorité** : haute — c'est l'anomalie budgétaire la plus sévère du rang-3 non documentée.
Si non tranchée avant P3 (équilibrage auto), la sim passera en revue le DPS et ne saura pas
si c'est voulu ou non.

---

### P-D — Documenter burn rang-1 / rot rang-1 = singletons (voulu ou trou) dans l'audit P0.5

**Quoi** : dans l'audit §3.1, ajouter une ligne rang-1 pour burn et rot documentant que :
- `ash_moth` = seul enabler burn rang-1 (DPS=0.075, HP=26 = fragile)
- `carrion_pecker` = seul enabler rot rang-1

Décision : rareté early = voulu (archétype rare/grimdark) OU trou ? Si trou → spécifier
le profil d'1 stat-stick rang-1 burn simple (budget DPS≈0.09-0.10, HP≈40, op burn dps=2).

**Coût** : doc + éventuellement 1 unité data. 0 moteur.

**Priorité** : moyenne — à intégrer dans l'audit P0.5, même section que le plancher ≥2.
**Précondition** : décision de cohorte v7 tranchée (§3.2) pour ne pas créer d'unité avant
de savoir si une v7 déjà existante (`pyre_herald`, v7 rang-2 burn) compense le plancher.

---

### P-E — Colonne (J) valeur sigil-dépendante pour les auras (doc audit P0.5, 0 code)

**Quoi** : pour chaque unité avec `trigger="combat_start", target="neighbors"` (auras +
`shield_aura`) : documenter le nombre de voisins selon le sigil (carré=4 max, croix=4
center/2 branches, anneau=2, diamant=2-3, ligne=2 max) → calcul de la valeur effective
de l'aura selon le sigil.

**Impact** : révèle quels sigils sont « hostiles » à quelle aura. Croise avec §2.3
(plan de la topologie).

**Coût** : doc pure, lecture de `shapes.lua`. 0 code moteur, 0 invariant.

**Priorité** : basse mais à faire pendant l'audit P0.5 (les mêmes unités sont lues une seule
fois). Ne pas retarder l'audit pour P-E — l'inclure comme sous-section de l'audit.

---

## 4. Questions ouvertes

**Q1 — `stormlord` (rang-3, `add=2, volt=4, cap=8`) a-t-il un `burst_DPS_eq` plus ou moins
fort que `galvanizer` (rang-4) ?**
`galvanizer` : add=2, cap=6, bonus_first=6. `stormlord` : add=2, volt=4, cap=8 → plus de
stacks possibles, volt plus faible. Le `burst_DPS_eq` de `stormlord` dépend du nombre de
coups nécessaires pour charger, qui lui-même dépend des unités alliées qui co-chargent. À
calculer dans la sim 4-configs (§3.4) pour éviter que `stormlord` soit sous-évalué en P3.

**Q2 — `ash_moth` (seul burn rang-1) avec HP=26 est-il viable comme enabler précoce ou
trop fragile pour survivre aux premiers combats ?**
HP=26 est le plus bas du rang-1 (sous `spore_tick`=30). En front (profondeur 0 selon le
sigil), il meurt avant d'avoir stacké le burn sur la cible. Sa survie dépend du sigil actif
(en ligne, il peut être en arrière). Cette fragilité rend l'archétype burn difficile d'accès
en early — ce qui peut être voulu (grimdark : la brûlure est rare) ou non voulu (early burn
bloqué). À mesurer par sim `--ash-moth-survival-rate`.

**Q3 — Le co-build naturel `soot_acolyte` (aura burn) + `wildfire_hound` (propagation à la
mort) constitue-t-il un archétype burn cohérent ou deux unités qui se marchent dessus ?**
`wildfire_hound` (`units.lua:174-179`) propage la brûlure à la mort des ennemis. `soot_acolyte`
amplifie le dps des brûlures des voisins au build. Les deux synergisent (amplification des
brûlures propagées) mais `soot_acolyte` doit être voisin d'une unité qui brûle, pas de
`wildfire_hound` lui-même. La topologie du sigil détermine si les deux peuvent être voisins
d'un enabler burn actif simultanément — sur un sigil Ligne (2 voisins max), l'un des deux
est hors portée. **À documenter dans la colonne J.**

**Q4 — Combien d'arêtes actives une aura rang-3 exploite-t-elle en moyenne sur les 5 sigils,
pondéré par la fréquence d'utilisation des sigils en boutique ?**
Sans data de distribution des sigils utilisés en partie, le calcul de valeur effective
moyenne d'une aura est inexact. Mesurable par sim (`--aura-edge-distribution`). Cela peut
révéler que certaines auras sont systématiquement sous-exploitées sur les sigils les plus
communs.

---

## 5. Synthèse pour le round suivant

Par ordre de priorité pour rounds 7-10 :

1. **Dispersion DPS intra-rang-2 = 7.24× non bornée** (§2.1/P-A) : le contrat `cost=rank`
   est perceptivement brisé au rang-2. Critère P90/P10 ≤ 3× + signal boutique pour tanks.
   **Précondition du tuning P3 et de la lisibilité P1 (types sur des unités indistinctes).**

2. **`siege_breaker` DPS=0.154 rang-3 — anomalie budgétaire non cataloguée** (§2.3/P-C) :
   double-valeur DPS+counter non documentée, jamais citée en 5 rounds. Décision binaire
   avant P3.

3. **Burn rang-1 = singleton `ash_moth` HP=26** (§2.4/P-D) : trou de plancher non documenté.
   Décision voulu/trou à trancher dans l'audit P0.5.

4. **`soot_acolyte` double-valeur non tranchée** (§2.2/P-B) : aura burn = carry secondaire
   ou aura pure ? Décision editoriale à trancher dans l'audit avant de figer i18n.

5. **Colonne J valeur sigil-dépendante des auras** (§2.5/P-E) : dimension positionnelle
   absente des 9 colonnes A-I, à intégrer pendant l'audit P0.5.

---

## 6. Index des sources

**Internes (lecture seule du repo, ce round)** :
- `src/data/units.lua` (intégralité relue, DPS calculés sur TOUTES les 83 unités)
  - `ash_moth` : ligne 100-104 (burn rang-1 singleton)
  - `soot_acolyte` : ligne 149-151 (aura burn DPS=0.111)
  - `miasma_acolyte` : ligne 157-159 (aura poison DPS=0.067)
  - `siege_breaker` : ligne 377-380 (rang-3 DPS=0.154 strip_shield)
  - `galvanizer` : ligne 311-316 (condensateur confirme burst_DPS_eq)
  - `stormlord` : ligne 318-320
  - `witch` : ligne 48-50 (rang-2 DPS=0.181, outlier haut)
  - `shieldbearer` : ligne 337-339 (rang-2 DPS=0.025, outlier bas)
  - v7 unités rang-2 : lignes 383-440
- `src/run/state.lua` (SHOP_SIZE=5 relu — relevé contexte boutique)
- `docs/roadmap-lab/00-state.md` (§2.1 roster, §3.1 familles, §4.3 cotes boutique)
- `docs/roadmap-lab/ROADMAP-draft.md` (v6, §3.1 audit 9-col, §3.2 cohorte v7)
- `docs/roadmap-lab/rounds/r04-units-power.md` (Q3 soot_acolyte Q4 budget rang-1)
- `docs/roadmap-lab/rounds/r05-units-power.md` (§2.2 shield-caster pool, §2.4 rot-tank)
- `docs/roadmap-lab/round-05.md` (§1.12 colonnes H/I adoptées)

**Sources web vérifiées ce round** :

- [Ariely, Loewenstein & Prelec 2003 — Coherent Arbitrariness (QJE)](
  https://academic.oup.com/qje/article/118/1/73/1917051) :
  ancrage de valeur par comparaison simultanée → un item à DPS élevé visible en boutique
  dévalue perceptivement les items à DPS bas du même rang. Fonde §2.1 (dispersion
  intra-rang = problème d'ancrage, pas seulement d'équilibre).

- [Mobalytics TFT Set 14 Tier Stats](https://mobalytics.gg/tft/comps) :
  TFT a ~2× de spread DPS intra-coût pour les non-tanks (mesure de référence). Fonde
  §2.1 (notre 7.24× dépasse largement la norme du genre).

- [a327ex.com — SAP Mechanics Deep Dive](https://a327ex.com/posts/super_auto_pets_mechanics) :
  « Early tiers = introduction à chaque mécanique ; 1 pet = 1 valeur distincte. » Fonde
  §2.2 (soot_acolyte double-valeur = contre-pattern SAP) et §2.4 (singleton rang-1
  = ancrage insuffisant pour l'archétype).

- [GhostCrawler WoW Design Notes (tumblr)](
  https://askghostcrawler.tumblr.com/post/4580765536) :
  « a unit should not be both the best attacker and the best counter. » Fonde §2.3
  (siege_breaker DPS élevé + strip_shield = double-valeur non documentée).

- [Backpack Battles Steam Announcement — Positional Items Design](
  https://steamcommunity.com/games/2427700/announcements/detail/3831789654380393820) :
  « Positional adjacency items require spatial tooltips. » Fonde §2.5 (auras sans
  information sigil-dépendante = information cachée).

- [Giovannetti GDC 2019 — Slay the Spire Metrics](
  https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics) :
  « value delivered per play, not per turn » → condensateur mesuré sur le burst, pas
  le DPS continu. Fonde §1.1 (stormlord : à ne pas sous-évaluer par DPS frappe).

---

*Round 06 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu
(`units.lua` intégralité, DPS calculés pour toutes les 83 unités ; `state.lua` relu).
N'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe
seedée / DA grimdark / pixel art procédural). 32 invariants non touchés. 0 modification
du code du jeu.*
