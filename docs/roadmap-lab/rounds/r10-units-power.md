# Round 10 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v9, intégré round 9) et de la
> synthèse `round-09.md` depuis la lentille **units-power** — distinction des unités, budget
> de puissance par rang, identité, redondance, trous d'archétype. Round 10/10 — dernier round.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md`, `00-state.md`, `round-09.md`,
> `rounds/r09-units-power.md`, `competitive/*.md` (tous), `src/data/units.lua`
> (intégralité relue, DPS recalculés pour tous les rangs et toutes familles).
>
> **Méthode** : désaccord = recherche web effectuée et citée. Accord → raison mécaniste.
> Tout chiffre cite le fichier+ligne relu ce round.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous
> `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée /
> DA grimdark / pixel art procédural). 32 invariants non touchés.

---

## 0. TL;DR de ce round

**Trois désaccords majeurs, tous ancres sur le code `units.lua` relu ce round :**

1. **Le brouillon (R09 §6.1) diagnostique `skull_colossus` comme un carry burn en collision
   triple. Ce diagnostic est partiellement faux : la comparaison DPS_frappe (0.131 vs ash_maw
   0.100) porte sur le MÉLEE seul et ignore que le burn effect de `skull_colossus` (`dps=4,
   dur=200`) est inférieur à `cinder_cur` rang-2 (`dps=4`) et très en-dessous de `pyre_tender`
   rang-2 (`dps=10`). `skull_colossus` n'est pas un carry burn — c'est un TANK-ENABLER burn
   dont le vrai problème est l'AMBIGUÏTÉ DE NICHE, pas la collision d'identité de famille.**

2. **Le brouillon propose de réorienter `skull_colossus` comme apex choc rang-5 via
   `grant_team{shockChain}`. Cette proposition ignore un conflit thématique dur :
   `skull_colossus` est `family="crane", type="bone"` — un crâne colossal osseux. L'électricité
   (`shockChain`) n'est pas cohérent DA/grimdark avec ce profil. La décision #3 (DA grimdark)
   exige de vérifier la cohérence thématique, pas seulement la faisabilité mécanique.**

3. **Le brouillon ne distingue pas deux propriétés différentes du budget de puissance rang-5 :
   (A) DPS_frappe de la frappe → skull_colossus 0.131 est élevé ; (B) DoT_dps de l'effet →
   skull_colossus burn_dps=4 est bas (niveau rang-1). Ces deux axes sont traités comme un
   même problème dans R09 mais ils ont des remèdes différents. Le confond constitue une
   analyse incomplète qui risque de produire un remède mal ciblé.**

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — Les stat-sticks rang-5 violent le contrat rang-5 (R09 §1.2, adopté round 7)

**Calcul relu ce round** (`units.lua:421-439`) :

```
skull_colossus : rank=5, cost=5, hp=92, dmg=11, cd=84, aggro=40
  effects = { burn{dps=4, dur=200} }       ← 0 grant_team, 0 transform
  DPS_frappe = 11/84 = 0.131

deep_kraken : rank=5, cost=5, hp=84, dmg=12, cd=78
  effects = { poison{dps=4, dur=200} }     ← 0 grant_team, 0 transform
  DPS_frappe = 12/78 = 0.154

vs TOUS les T3 transforms rang-5 légitimes :
  ash_maw, plague_pyre, slow_bleed, marrow_drinker,
  festering, venom_censer, pit_maw, wither_bloom
  → TOUS ont grant_team ou un effet de RÈGLE D'ÉQUIPE
```

**Pourquoi c'est valide pour nos contraintes** : la décision #10 (`cost = rank` → complexité
dans les hauts rangs) implique que rang-5 = transform ou règle d'équipe. Les 8 T3 légitimes
respectent ce contrat. Skull_colossus et deep_kraken ne l'ont pas. Entalto Studios
([entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/)) :
« Build identity must be clear within 2 min ». Un joueur burn qui arrive au shopTier 5 et
voit `skull_colossus` sans `grant_team` visible perçoit une régression de contrat.

**Accord sur le diagnostic structurel de R09 §1.2 : les deux unités doivent recevoir un
effet de rang-5 (grant_team ou transform).** Les désaccords portent sur la NATURE DU PROBLÈME
et le REMÈDE (§2.1 et §2.2 ci-dessous).

### 1.2 ACCORD — Paire de dominance `corruptor`/`bile_spitter` rang-3 (adopté round 8)

**Relu ce round** (`units.lua:62-65` vs `:122-125`) :

```
corruptor   : poison{dps=2, dur=180, weaken=0.06}  DPS_frappe = 6/62 = 0.097
bile_spitter: poison{dps=2, dur=180, weaken=0.10}  DPS_frappe = 5/56 = 0.089
```

`bile_spitter` a weaken 67 % supérieur. `corruptor` a un DPS frappe 9 % plus élevé mais le
weaken est le différentiateur clé à rang-3. **Dominance quasi-stricte de `bile_spitter` sur
l'axe principal (weaken).** Ariely, Loewenstein & Prelec 2003 QJE
([academic.oup.com/qje/article/118/1/73/1917051](https://academic.oup.com/qje/article/118/1/73/1917051)) :
un item dominé dégrade la décision. En pool LOCAL (5 slots, ~18 rang-3), co-occurrence fréquente.
**Accord sans réserve.** Remède : différencier l'axe de `corruptor` (ex. empoisonnement rapide,
dps=3 mais dur=120 « éclair venimeux ») OU retirer de `U.pool`.

### 1.3 ACCORD — `rust_sentinel` rang-4 = enabler rang-2 en déguisement rang-4 (adopté round 8)

**Relu ce round** (`units.lua:425-427` vs `:78-80`) :

```
rust_sentinel: rank=4, shock{add=1, cap=6, dur=150}   DPS = 9/72 = 0.125
stormcaller:  rank=2, shock{add=1, cap=6, dur=150}    DPS = 6/58 = 0.103
```

Op identique, params identiques, seule la stat de base (dmg/cd/hp) diffère. Viole décision
#10 (rang-4 = twist). **Accord maintenu.** Remède : ajouter `chain=1` ou `persist=0.3` pour
un twist minimal de rang-4 (distinct de `arc_warden:chain=2` et `storm_anchor:persist=0.5`).

### 1.4 ACCORD — Désert rang-3 burn : 1 poseur actif (`bellows_priest`) sous le plancher (adopté round 9)

**Relu ce round** — rang-3 burn en `U.pool` :

```
bellows_priest : trigger=on_hit, op=burn  → poseur actif, 1 seul
soot_acolyte   : trigger=combat_start, op=aura_burn_dps → AURA (amplificateur)
```

Le plancher redéfini R09 (≥2 poseurs ACTIFS trigger on_hit) : burn rang-3 = **1** → sous le
plancher. P(bellows_priest visible T3, SHOP_SIZE=5, pool~18 r3) ≈ 27 %, vs bleed r3 P ≈ 61 %.
a327ex ([a327ex.com/posts/super_auto_pets_mechanics](https://a327ex.com/posts/super_auto_pets_mechanics)) :
each tier = new mechanic introduction. **Accord fort sur la définition du plancher.** La question
reste ouverte (voulu vs trou) mais le FAIT est établi sans ambiguïté.

### 1.5 ACCORD — Flag de compatibilité sigil pour les auras rang-3/4 (adopté round 9)

**Calcul ce round sur `shapes.lua`** (adjacences orthogonales) :

```
soot_acolyte, clot_mender, miasma_acolyte, decay_tender
  → trigger=combat_start, target="neighbors"
  carré/croix centre = 4 voisins
  anneau/ligne      = 2 voisins max
  diamant centre    = 3 voisins
  → viabilité ≥3/5 sigils : OUI (carré+croix+diamant = 3)
  → hostile : ligne ET anneau (50 % de valeur perdue)
```

La col J enrichie avec flag actionnable est juste et précondition P1. **Accord.** La précision
R10 : le flag hostile pour la `ligne` est critique SPÉCIFIQUEMENT pour bleed (archétype ligne-intuitif),
ce qui confirme que la spec P1 doit éviter de prescrire `clot_mender` comme aura centrale d'un
palier bleed si le build cible la `ligne`.

### 1.6 ACCORD — Trou rang-5 choc = structurel et bloquant (R09 §3.2, adopté comme #GG)

**Relu ce round** — toutes les unités choc en `U.pool` :

```
r1 : live_wire (1 unité)
r2 : thunderhead, static_swarm, siphon_jelly (3 unités)
r3 : stormlord, storm_anchor (2 unités)
r4 : galvanizer, dynamo_priest, arc_warden, rust_sentinel (4 unités)
r5 : AUCUNE
```

Les 4 autres familles DoT ont chacune 2 unités rang-5 (T3 + croisé). Choc = 0. Un joueur choc
qui atteint shopTier 5 n'a **aucun apex pour sa famille**. Cloudfall StS
([cloudfallstudios.com/blog/2020/11/2](https://www.cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions)) :
chaque archétype doit avoir un choix final qui change la structure des décisions. **Accord plein.**
**Le désaccord porte sur LE REMÈDE proposé (§2.2 ci-dessous).**

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — Le diagnostic DPS de `skull_colossus` mélange DPS_frappe (mélee) et burn_dps (DoT) : le carry burn n'existe pas dans le code

**Ce que le brouillon et R09 disent** (§3.7, §6.1, `rounds/r09-units-power.md §2.1`) :
`skull_colossus` est un « carry burn DPS-0.131 » qui « domine ash_maw (0.100) et
plague_pyre (0.107) en DPS brut », créant une « collision d'identité famille burn ».

**Ce que le code révèle** (`units.lua:421-424`) :

```lua
skull_colossus = { rank=5, hp=92, dmg=11, cd=84, aggro=40,
  effects = { { trigger="on_hit", op="burn", params={dps=4, dur=200} } }
}
```

La comparaison DPS_frappe `0.131 > 0.100` porte sur `dmg/cd` (la **frappe mélée**), pas
sur la contribution burn. La contribution burn réelle de `skull_colossus` est
`burn_dps=4, dur=200` — comparons avec la FAMILLE BURN :

```
burn_dps par famille (lu units.lua) :
  pyre_tender rang-2 : dps=10  (2.5× skull_colossus)
  ash_moth rang-1    : dps=7   (1.75×)
  ash_maw rang-5     : dps=6   (1.5×)
  bellows_priest r3  : dps=6   (1.5×)
  emberling rang-2   : dps=6   (1.5×)
  pyre_herald rang-2 : dps=6   (1.5×)
  zeal_inquisitor r2 : dps=5   (1.25×)
  skull_colossus r5  : dps=4   ← PLUS BAS burn que rang-1 ash_moth (dps=7)
  cinder_cur rang-2  : dps=4   (= identique à skull_colossus)
```

`skull_colossus` a un burn_dps égal à `cinder_cur` rang-2 et inférieur à `ash_moth` rang-1.
**Sa contribution burn est négligeable pour un rank-5.** Ce n'est PAS un carry burn : c'est un
**TANK AVEC BURN RÉSIDUEL**. La comparaison DPS_frappe (mélee) de R09 ne capture pas cela.

**Pourquoi la collision d'identité de R09 est partiellement fausse** : le joueur burn qui sait
lire le code ne prend PAS `skull_colossus` pour son burn (burn_dps=4 << ash_maw burn_dps=6 +
team burnNoDecay). Il le prend pour sa tankeabilité (hp=92, aggro=40) ou ne le prend pas. La
collision réelle est différente : `skull_colossus` **brouille la lisibilité de famille** parce
que son icône/famille (`crane/bone`) suggère un T3 burn alors que son burn est sous-rang.

**Source** : `units.lua:421-424` (burn_dps=4) vs `:100` (ash_moth burn_dps=7) vs `:231-236`
(ash_maw burn_dps=6 + grant_team). Cloudfall StS (ibid.) : « solutions either introduce new
problems or are only useful in a portion of situations ». Un burn_dps=4 au rang-5 n'est utile
dans AUCUNE situation où le joueur cherche à maximiser le burn — ce n'est pas un défaut de
carry, c'est un signal contradictoire.

**Proposition (P-A RECTIFIÉE, §3 ci-dessous)** : le problème de `skull_colossus` est
**l'AMBIGUÏTÉ DE NICHE**, pas la « collision carry burn ». La direction correcte est de
CLARIFIER son rôle de tank-enabler (aggro=40 burn-poseur protecteur) sans le requalifier en
carry et sans changer son burn_dps (qui est cohérent pour un tank secondaire).

### 2.2 DÉSACCORD MODÉRÉ — La proposition d'apex choc via `skull_colossus {grant_team{shockChain}}` ignore la cohérence thématique DA/grimdark (décision #3)

**Ce que le brouillon dit** (ROADMAP-draft §3.7) : réorienter `skull_colossus`
(libéré du rang-5 burn, aggro=40 + HP=92 = « conducteur-terminateur » grimdark) **en apex choc
rang-5** via `grant_team{shockChain}`.

**Ce qui est problématique** (`units.lua:421-424` + décision #3 DA grimdark) :

```lua
skull_colossus = { type="bone", family="crane", ... }
```

`type="bone"`, `family="crane"` — c'est un crâne osseux (mort-vivant, grimdark, résidu d'un
titan). L'archétype choc dans The Pit est `type="arcane"` ou `type="abyss"` + famille électrique
(`arachnid`, `arcane`, `eye`). `grant_team{shockChain}` sur un crâne osseux = incohérence
thématique dure.

**Source vérification `units.lua`** : tous les units choc existants :
```
live_wire     : type=arcane
thunderhead   : type=arcane
static_swarm  : type=abyss
galvanizer    : type=flesh (arachnide = fil électrique)
dynamo_priest : type=arcane
arc_warden    : type=abyss
stormlord     : type=arcane
storm_anchor  : type=arcane
siphon_jelly  : type=abyss
```
Aucun n'est `type=bone`. L'électricité (`shockChain`) sur un crâne osseux `type=bone` brise
la cohérence visuelle-mécanique qui est le « différenciateur » de The Pit (décision #3 :
DA grimdark = thème + mécanique fusionnés).

**Ce qu'il faudrait faire à la place** : créer une **nouvelle unité rang-5 choc** avec
`type=arcane` ou `type=abyss`, thème électrique (ex. `storm_god`, `arc_titan`, `void_conductor`),
grant_team sur l'axe choc. **Libérer `skull_colossus` pour devenir le T3 bone/burn manquant**
(burn sacrificiel à la mort d'allié, P-A R09 améliorée, §3 ci-dessous).

**Verdict** : la proposition « réorienter skull_colossus en apex choc » est DA-invalide.
C'est une analogie mécanique paresseuse (le slot existe, le HP/aggro convient → donc
électricité). Le « pourquoi psychologique » de The Pit (immersion grimdark par cohérence
thème/mécanique) ne transfère pas. **Désaccord formel.**

### 2.3 DÉSACCORD CIBLÉ — La distinction DPS_frappe/DoT_dps n'est appliquée nulle part dans le budget de puissance rang-5 : `deep_kraken` souffre du même problème non documenté

**Ce que le brouillon dit** (§3.7) : `deep_kraken` = stat-stick poison à traiter symétri-
quement à `skull_colossus`, niche proposée « AoE colonne ». Le remède est esquissé mais non
justifié depuis la même analyse two-axis (DPS_frappe vs DoT_dps).

**Calcul relu ce round** (`units.lua:437-440`) :

```lua
deep_kraken = { rank=5, hp=84, dmg=12, cd=78,
  effects = { { op="poison", params={dps=4, dur=200} } }
}
```

```
poison_dps au rang-5 :
  festering rang-5   : dps=2  (+ poisonNoCap team)
  venom_censer rang-5: dps=2  (+ igniteAt=5 burst dps=10)
  deep_kraken rang-5 : dps=4
  ↑ 2× supérieur aux T3 légitimes en DoT dps
  vs
  spore_tick rang-1  : dps=1
  rot_grub rang-2    : dps=2
  corruptor rang-3   : dps=2
```

Ici le constat est **inverse de skull_colossus** : `deep_kraken` a un poison_dps=4 qui EST
supérieur aux T3 légitimes (festering/venom_censer à dps=2). Mais ses T3 légitimes ont leur
valeur dans les **team flags** (poisonNoCap = stacks illimités, igniteAt = détonation), pas
dans le dps brut. Le `deep_kraken` présente donc une vraie confusion : il semble dominer
les T3 en DoT output alors que leur valeur est ailleurs.

**Asymétrie skull_colossus vs deep_kraken** :
- `skull_colossus` : DPS_frappe haut (0.131), DoT_burn bas (dps=4 < ash_maw 6) → tank opaque
- `deep_kraken` : DPS_frappe haut (0.154), DoT_poison haut (dps=4 > festering 2) → confond
  carry poison et transform poison

**Les deux unités ont des problèmes DIFFÉRENTS qui nécessitent des remèdes DIFFÉRENTS** :
- `skull_colossus` : niche ambiguë (tank + burn résiduel trop faible pour être un burn carry) →
  clarifier la niche tank-burn ou élever le burn_dps au niveau rang-5 (ex. dps=8, aggro=30,
  taunt conditionnel)
- `deep_kraken` : confusion carry vs transform (son DoT supérieur aux T3 mais sans team flag)
  → ajouter un mini team flag ou convertir l'effet en quelque chose qui ne concurrence pas le
  DoT brut des T3 (ex. AoE colonne, ou poison+rot croisé)

**Source** : `units.lua:437-440` ; festering `units.lua:259-265` ;
venom_censer `units.lua:267-270`.

---

## 3. Propositions priorisées

### P-A (PRIORITÉ HAUTE, CO-BLOQUANT #GG) — Reformuler le diagnostic `skull_colossus` : AMBIGUÏTÉ DE NICHE, pas COLLISION DE CARRY

**Quoi** : corriger §3.7 du brouillon sur deux points :

1. **Corriger la comparaison DPS** : le « carry burn DPS 0.131 » de R09 porte sur la frappe
   mélée (`dmg/cd`). Il ne prouve pas que `skull_colossus` est un carry burn (son burn_dps=4
   est le plus bas de la famille, en-dessous de rang-1 ash_moth). Le tableau §3.7 doit distinguer
   deux colonnes : `DPS_frappe` (frappe mélée) et `DoT_dps` (effet de statut).

2. **Reformuler le problème** : `skull_colossus` est un **tank-enabler burn** à niche ambiguë,
   pas un carry burn. Son vrai problème : burn_dps=4 << ash_maw(6), bellows_priest(6), pyre_tender(10)
   → son burn est opaque (pas assez fort pour qu'un joueur burn le choisisse pour son burn) +
   aggro=40 sans taunt (moins bon tank que gravewarden/aegis_warden). Il occupe un espace entre
   deux niches sans en dominer aucune.

**Remède PRIVILÉGIÉ** (0 moteur, data) :
```
Option A — CLARIFIER LA NICHE TANK-BURN (burn_dps relevé, aggro maintenu) :
  skull_colossus : burn{dps=8, dur=200} (cohérent avec ash_moth rang-1 dps=7)
                   aggro=40 (rôle tank maintenu, pas carry)
                   → le joueur voit un tank qui brûle fort (pas de confusion avec ash_maw
                     qui a burn{dps=6} + burnNoDecay team)
  Niche claire : "gros mur qui brûle aussi fort que les meilleurs poseurs"
  DA grimdark : un colosse de crânes = chaque attaque est incandescente. Cohérent.

Option B — NICHE SACRIFICIELLE (burn à la mort d'allié, R09 P-A maintenue) :
  skull_colossus : burn{dps=4} → minime ; + on_death_ally{spread_burn frac=1.0, dps=10}
  → nouveau trigger (on_death côté allié, broadcast déjà câblé, 0 moteur)
  Niche claire : "crémateur d'alliés" (mort d'allié = explosion de feu)
  Distinct de ash_maw (burnNoDecay), plague_pyre (mort d'ennemi→burn+poison)
```

**Option A recommandée pour ce round** : elle requiert 1 param change (burn_dps=4→8), coût
minimal, niche immédiatement lisible pour un joueur. Option B reste valide mais requiert plus
de test (golden à revérifier pour le trigger on_death allié).

**REJETER** la proposition de réorientation apex choc (DA-invalide, §2.2).

**Coût** : doc §3.7 enrichi + 1 param change data (`dps=4→8` ou spec Option B). Golden à
vérifier avant commit (burn_dps=8 sur skull_colossus peut déclencher le cap DOT_CAP_MULT=3).

---

### P-B (PRIORITÉ HAUTE, NOUVEAU — CO-BLOQUANT #GG) — Apex choc rang-5 : créer une NOUVELLE UNITÉ thématiquement cohérente

**Ce que le brouillon propose** (§3.7) : réorienter `skull_colossus` en apex choc. Rejeté §2.2.

**Ce qu'il faut à la place** : une **nouvelle unité rang-5 choc** (pas un recyclage). Spec
minimale (data-only, 0 moteur) :

```
NOUVELLE UNITÉ — apex choc rang-5 :
  type = "arcane" OU "abyss" (cohérent avec la famille choc existante)
  family = à choisir (ex. "titan_arc", "void_pulse" — DA grimdark + électrique)
  rank = 5, cost = 5
  hp = 60-70 (carry, pas tank), aggro = 5-10
  dmg = 7, cd = 60-70
  effects :
    { trigger="on_hit", op="shock", params={add=2, volt=6, cap=8, dur=240} }
    { trigger="combat_start", op="grant_team", params={shockChain=true} }
    -- OU pour l'axe D (si #GG → D) :
    { trigger="combat_start", op="grant_team", params={shockAmplify=true} }
  → contrat rang-5 : grant_team = règle d'équipe (comme TOUS les T3 légitimes)
```

**Pourquoi une nouvelle unité et non `skull_colossus`** : le slot rang-5 dans le pool est
actuellement 10 unités pour 5 familles + 2 stat-sticks. Avec les correctifs de `skull_colossus`
(niche tank-burn clarifiée) et `deep_kraken` (niche AoE ou croisé), on passe à 12 rang-5 si
une nouvelle unité choc est ajoutée — ce qui équilibre parfaitement les 5 familles (2 par
famille) + 2 hybrides tank. C'est la seule solution qui maintient la cohérence thématique ET
le contrat rang-5.

**Coût** : spec data (~15 lignes dans `units.lua`) + entrée dans `U.pool` et `U.order`. 0 moteur
si `shockChain` est déjà câblé (`ops.lua:187`) ; ~3 lignes SIM si `shockAmplify` est neuf.

---

### P-C (PRIORITÉ HAUTE, doc §3.7) — Distinguer deux colonnes dans l'audit : DPS_frappe vs DoT_dps, et l'appliquer à TOUS les rang-5

**Quoi** : dans la grille 10-colonnes (A-J) §3.1, ajouter une distinction systématique pour
les rangs-5 entre :
- **(E1) DPS_frappe** = `dmg/cd` (frappe mélee brute)
- **(E2) DoT_dps** = le `dps` parameter de l'effet DoT primaire (si on_hit op=burn/bleed/etc.)
- **(E3) team_flag** = présence ou non d'un `grant_team` ou règle d'équipe

Application au rang-5 actuel :

```
Unit            | E1 DPS_frappe | E2 DoT_dps | E3 grant_team | Verdict
----------------|---------------|------------|---------------|--------
ash_maw         | 0.100         | burn 6     | burnNoDecay   | OK (T3)
plague_pyre     | 0.107         | burn 5     | on_death rule | OK (T3 croisé)
slow_bleed      | 0.093         | bleed 2    | slowEnemies   | OK (T3)
marrow_drinker  | 0.115         | rot conv.  | conditional   | OK (T3 croisé)
festering       | 0.100         | poison 2   | poisonNoCap   | OK (T3)
venom_censer    | 0.103         | poison 2   | burst cond.   | OK (T3 croisé)
pit_maw         | 0.078         | rot 1      | rotEnemies    | OK (T3)
wither_bloom    | 0.083         | rot 2+bleed+poison | —  | OK (T3 croisé multi)
skull_colossus  | 0.131 ↑HIGH   | burn 4 ↓LOW| AUCUN         | PROBLÈME : E1 haut sans E3
deep_kraken     | 0.154 ↑HIGH   | poison 4 ↑ | AUCUN         | PROBLÈME : E1+E2 hauts sans E3
```

Ce tableau montre que skull_colossus a un **E1 haut et E2 bas** (tank avec burn résiduel, niche
ambiguë) et deep_kraken a **E1 ET E2 hauts** (confond avec les T3 légitimes). Les remèdes sont
donc différents par nature.

**Coût** : enrichissement §3.1 tableau, ~30 min doc. Précondition pour les décisions de remède
de P-A et P-B.

---

### P-D (PRIORITÉ MOYENNE, doc §3.7) — Spec de `deep_kraken` : croisé poison-rot ou AoE modifié (non le même remède que skull_colossus)

**Quoi** : §3.7 esquisse pour `deep_kraken` une niche « AoE colonne ». Ce round précise :

```
Option A — CROISÉ POISON-ROT (0 moteur, data) :
  deep_kraken : poison{dps=2, dur=200} + rot{base=2, growth=1, dur=180, capDps=10, maxHpFrac=0.10}
  Niche : « le venin du Kraken empoisonne ET gangrène » (croisé distinct de venom_censer burn)
  → E2 DoT mixte (pas de dominance sur festering/venom_censer sur leur propre axe)
  → 0 grant_team : problème persistant → ajouter un mini-flag

Option B — AoE COLONNE + team mini-flag (0 moteur data si target="column" déjà câblé) :
  deep_kraken : poison{dps=4, dur=200, target="column"}  ← AoE
              + grant_team{poisonNoShield=true}  ← mini-flag (le venin traverse les boucliers)
  Niche : « étreinte du Kraken = tout la colonne se vide »
  DA : tentacules qui enveloppent + enveniment. Cohérent.
  → NOUVEAU target="column" si non câblé (~5 lignes SIM, cf. §3.7 note R09)
```

**Option B recommandée** : elle donne à `deep_kraken` un grant_team minimal (contrat rang-5)
+ une signature d'AoE unique dans la famille poison (festering = durée/cap ; venom_censer =
détonation ; deep_kraken = propagation de colonne + ignore bouclier).

**Coût** : spec doc §3.7 + 1-2 lignes data + ~5 lignes SIM si `target="column"` neuf.

---

### P-E (PRIORITÉ BASSE, doc §3.1) — Audit intra-famille choc rang-4 : la règle P90/P10 est VALIDE mais masque une pseudo-dominance conditionnelle de `galvanizer`

**Ce que R09 dit** (§2.3) : P90/P10 choc rang-4 = 0.172/0.086 = 2.0× (passe ≤3×). Pas de
problème.

**Ce que ce round ajoute** : le ratio 2.0× est VRAI mais ne capture pas la dominance
conditionnelle. Dans un contexte mono-cible (le plus fréquent en early game), `galvanizer`
(bonus_first=6 + shock add=2 + DPS 0.172) domine `dynamo_priest` (transfer=0.5 + DPS 0.086)
sur tous les axes quantifiables. Le `transfer` n'est pertinent que si ≥2 cibles reçoivent du
choc — ce qui requiert que l'adversaire ait plusieurs unités avec DoT actif (pour l'axe D).

**Accord avec R09 P-B** : l'audit galvanizer est conditionnel à l'axe D (#GG). Mais un point
additionnel : en attendant #GG, **documenter explicitement dans §3.1a que `dynamo_priest` est
inutile en axe A/B (mono-cible) et n'est distinctif qu'en axe D multi-cible**. Sinon, en
boutique T4, le joueur prend systématiquement `galvanizer` → dynamo_priest est un dead pick
jusqu'à la décision d'axe.

**Coût** : note doc §3.1a, ~10 min. Non bloquant pour P1.

---

## 4. Questions ouvertes

**Q1 — Après la correction burn_dps de skull_colossus (Option A : dps=8), le golden diverge-t-il ?**

`skull_colossus` est dans `U.pool` et `U.order`. S'il n'apparaît pas dans le scénario golden
(`golden.lua:17`, seed 970156547), la modification est golden-safe. S'il apparaît, rebaseline
explicite requise (invariant #5 de 00-state §6). À vérifier par grep sur le log golden AVANT
de coder. Précondition : `grep "skull_colossus" tests/golden.lua` (lecture seule).

**Q2 — La nouvelle unité apex choc (P-B) doit-elle être dans `U.pool` ou seulement `U.order` ?**

Si dans `U.pool` → apparaît en boutique shopTier 5 (cotes 10 % en T5, 00-state §4.3). Si dans
`U.order` uniquement → réservé aux encounters IA. La décision dépend de l'axe choc (#GG) : si
l'apex est fragile en sans setup (axe D conditionnel), le mettre seulement en `U.order` jusqu'à
CONFIG-CE2. Si robuste (axe A/B), `U.pool` direct.

**Q3 — Le remède Option A de skull_colossus (burn_dps=4→8) le distingue-t-il suffisamment de `pyre_tender` (dps=10) ?**

`pyre_tender` (rang-2, burn_dps=10, cd=72, HP=50, aggro neutre) est le poseur burn le plus
fort. `skull_colossus` avec dps=8, aggro=40, HP=92 serait un tank-burn puissant. Les deux
co-existent si leurs niches sont distinctes : `pyre_tender` = carry glass-cannon burn rapide ;
`skull_colossus` = mur burn lent qui tient long. La distinctivité tient si l'aggro=40 et le
HP élevé font que `skull_colossus` attaque moins souvent mais encaisse plus. À confirmer en sim.

**Q4 — Si `deep_kraken` reçoit `target="column"`, le calcul de `Arena:neighborsOf` couvre-t-il les colonnes ou seulement les voisins orthogonaux ?**

Le ciblage actuel est orthogonal (`Arena:neighborsOf`). Une AoE « colonne » requiert un
ciblage différent : toutes les unités dans la même colonne que la cible. Si ce target n'existe
pas dans l'arène SIM, c'est ~5 lignes SIM. À vérifier dans `src/combat/arena.lua` avant de
spécifier ce remède comme « 0 moteur ».

---

## 5. Ce que ce round confirme, précise, ou conteste vs R09

| Claim R09 (units-power §r09) | Statut R10 |
|---|---|
| skull_colossus = carry burn DPS 0.131 qui domine ash_maw | ⚠️ PARTIELLEMENT FAUX — comparaison porte sur DPS_frappe mélee seul ; burn_dps=4 est en-dessous de rang-2 pyre_tender(10) et ash_maw(6) |
| Collision triple : carry burn / tank / dominance T3 | ⚠️ REFORMULER — le vrai problème est AMBIGUÏTÉ DE NICHE (ni carry burn, ni bon tank avec taunt) |
| Remède : réorienter skull_colossus en apex choc via shockChain | ❌ REJETÉ — incohérence thématique DA (type=bone/family=crane ≠ électricité) |
| Trou rang-5 choc = structurel et bloquant (#GG) | ✅ CONFIRMÉ — 0 unité rang-5 choc dans U.pool |
| Désert rang-3 burn = 1 poseur actif (plancher sous le seuil) | ✅ CONFIRMÉ — bellows_priest seul, soot_acolyte = aura, pas poseur |
| Dominance corruptor/bile_spitter rang-3 | ✅ CONFIRMÉ — weaken 0.06 vs 0.10, op identique |
| rust_sentinel rang-4 = enabler rang-2 déguisé | ✅ CONFIRMÉ — op identique stormcaller |
| Audit galvanizer conditionnel à axe D (#GG) | ✅ CONFIRMÉ ET PRÉCISÉ — dynamo_priest est dead pick axe A/B |
| Flag compatibilité sigil auras rang-3/4 (col J) | ✅ CONFIRMÉ — sigils-MIN = ligne/anneau (2 voisins) pour les 4 auras DoT r3 |
| deep_kraken = même problème que skull_colossus (symétrique) | ⚠️ INCOMPLET — problèmes ASYMÉTRIQUES : skull_colossus burn_dps bas, deep_kraken poison_dps élevé vs T3 (confusions différentes) |

---

## 6. Résumé des apports du round 10 units-power

1. **Correction du diagnostic DPS skull_colossus** : la comparaison DPS_frappe (mélee) n'est
   pas la bonne métrique pour un carry burn. burn_dps=4 de skull_colossus est sous rang-1 →
   il ne menace pas ash_maw, il manque de signal de rôle.

2. **Rejet formel du recyclage apex choc** : skull_colossus (bone/crane) ≠ électrique. Créer
   une nouvelle unité rang-5 choc (type=arcane/abyss) avec le grant_team approprié.

3. **Distinction E1/E2/E3 pour le budget rang-5** : DPS_frappe vs DoT_dps vs grant_team —
   trois axes orthogonaux qui expliquent les deux problèmes différents de skull_colossus et
   deep_kraken.

4. **Remède différencié par unité** : skull_colossus → clarifier niche tank-burn (burn_dps=8
   ou niche sacrificielle) ; deep_kraken → croisé poison-rot ou AoE colonne + mini grant_team.

---

## 7. Index des sources

**Internes (lecture seule du repo jeu, ce round)** :

- `src/data/units.lua` — intégralité relue. Lignes clés :
  - `skull_colossus` : `:421-424` (burn_dps=4, aggro=40, type=bone, family=crane)
  - `deep_kraken` : `:437-440` (poison_dps=4)
  - `ash_maw` : `:231-236` (burn_dps=6 + grant_team burnNoDecay)
  - `pyre_tender` : `:95-97` (burn_dps=10, rang-2)
  - `ash_moth` : `:99-101` (burn_dps=7, rang-1)
  - `corruptor` : `:62-65` / `bile_spitter` `:122-125`
  - `rust_sentinel` : `:425-427` / `stormcaller` `:78-80`
  - Famille choc complète : `:299-334` (rang 1-4, 0 rang-5)
  - Auras rang-3 : `:148-163` (soot_acolyte, clot_mender, miasma_acolyte, decay_tender)

**Sources web vérifiées ce round** :

- [Ariely, Loewenstein & Prelec 2003 — QJE](https://academic.oup.com/qje/article/118/1/73/1917051) :
  item dominé = dégrade la décision. Fonde §1.2 (corruptor/bile_spitter).

- [Cloudfall Studios — Game Design Tips from Slay the Spire (2020)](https://www.cloudfallstudios.com/blog/2020/11/2/game-design-tips-reverse-engineering-slay-the-spires-decisions) :
  « if any choice is obviously the best regardless of context, the designers have failed ».
  Fonde §1.1 (contrat rang-5) et §2.1 (skull_colossus niche ambiguë, pas carry dominant).

- [Entalto Studios — 5 Essential Tips for Roguelite Design](https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/) :
  « Build identity must be clear within 2 min ». Fonde §1.1 (stat-stick = identité opaque).

- [a327ex.com — Super Auto Pets mechanics](https://a327ex.com/posts/super_auto_pets_mechanics) :
  « each tier = introduction to the next mechanic ». Fonde §1.4 (désert rang-3 burn) et §2.1
  (rang-5 sans mechanic nouvelle ≠ contrat de tier).

- [GDC 2019 — Slay the Spire: Metrics Driven Design (Giovannetti)](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf) :
  chaque card/unité doit avoir une niche qui la rend utile DANS UN CONTEXTE PRÉCIS, pas
  universellement. Fonde §2.1 (skull_colossus manque de contexte précis d'usage) et §3 (P-A).

---

*Round 10 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu (units.lua
intégralité relue, DPS frappe et DoT_dps calculés par Python pour tous les rangs). N'édite
que sous `docs/roadmap-lab/`. Piliers respectés : async snapshots / sim déterministe seedée /
DA grimdark / pixel art procédural. 32 invariants non touchés. 0 modification du code du jeu.*
