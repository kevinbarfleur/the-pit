# The Pit — Choc (amplification), couche de modificateurs de stats, aggro/taunt concret

> Recherche 2026-06 sous la **Règle d'or** : aucune mécanique affirmée sans source primaire citée
> (URL). Couvre trois sujets **couplés** : **(A)** le **CHOC** comme amplification de dégâts
> accumulée ; **(B)** la **couche de modificateurs de stats** empilables (la fondation de A *et*
> des malus type poison −25 %) ; **(C)** l'**aggro/taunt** concret (valeurs, effets, contres).
> Le fil rouge : A et C ne sont que des **clients de B**. On construit B en premier, A et C en
> découlent comme de la pure data `{trigger, op, params}`.
>
> Périmètre voisin (autres agents) : DoT burn/bleed/poison-tick (agent 1), frameworks de synergie
> + paliers (agent 3), counterplay/sim (agent 4). Ce document reste sur **choc / modificateurs / aggro**.
> Réfs internes : `engine-architecture.md` (§6.5 buckets — déjà esquissés, ici on les *spécifie*),
> `combat-model-decision.md` (§5 aggro 2 couches — ici on *chiffre*), `arena.lua`, `ops.lua`, `units.lua`.

---

## 0. TL;DR (décisions proposées)

1. **B — La couche de modificateurs** : implémenter le bucket PoE/Last-Epoch
   `final = clamp( (base + Σflat) · (1 + Σincreased) · Π(1 + more) )`. Les `increased` **s'additionnent
   entre eux** (commutatif ⇒ ordre-indépendant ⇒ **déterministe gratuit**) ; les `more` sont **rares**
   et multiplicatifs. C'est l'unique primitive qui rend `dmg`, `valeur de shield`, `cd`, `aggro` et
   **`damage_taken`** modifiables par des effets empilables. Sources : PoE *Damage* / *Stat*, Last Epoch
   *Increased, Added, and More* (citées §B).
2. **A — Le choc** = une **stat `damage_taken` increased** alimentée par des **stacks** qui
   **s'accumulent, plafonnent et décroissent**. On prend le **modèle de stacking de Last Epoch (Shred :
   stacke, cap, décroît, additif)** — *pas* le shock PoE qui **ne stacke pas** — mais on garde de PoE la
   **courbe à exposant < 1** comme anti-explosion. 1 stack = `+k %` de dégâts subis, plafonné, additif
   avec les autres increased. Sources : PoE *Shock*, Last Epoch *Shred Armor* / *Shock*, StS *Vulnerable*.
3. **C — Aggro/taunt** : garder l'archi **déjà câblée** (`chooseTarget` : depth → taunt → aggro →
   tie-break). Donner des **valeurs** (chaff ~10, carry ~5, **tank ~40**, taunt = flag dur). Les effets
   **modifient l'aggro via B** (porte-étendard `+aggro` aux voisins ; carry furtive `−aggro`). Contres :
   **strip d'aggro** (op `set_stat aggro 0`), **AoE/colonne** qui ignore le guard, **furtivité**
   (`aggro = 0` tant que conditions). Modèle de menace WoW (taunt = set-to-top ; multiplicateurs
   multiplicatifs ; Fade/Vanish/Tricks). Tout reste **0 hasard** (l'aggro est une stat triée, pas un dé).

---

## 1. Pourquoi B d'abord (et pas A ou C)

Le brief liste trois demandes, mais elles partagent **une seule** primitive manquante. Aujourd'hui le
moteur ne sait faire qu'**écraser** une valeur ou y **ajouter un flat** au moment du hook
(`ctx.amount = ctx.amount + p.value`, cf. `ops.lua:bonus_first`). Dès qu'on veut :

- « le poison réduit la **valeur** des capacités de 25 % » (un shield de 15 → 11.25) — un `increased` négatif sur la stat *shield* ;
- « la cible choquée prend **+X %** de dégâts » — un `increased` sur la stat *damage_taken* ;
- « le porte-étendard donne **+aggro** aux voisins » — un `flat`/`increased` sur la stat *aggro* ;

… il faut **une stat qui agrège plusieurs contributions empilables de façon déterministe**. C'est
**B**. A (choc) et C (aggro) deviennent alors **deux jeux de data** qui poussent dans B. **Construire A
ou C sans B = re-coder trois fois le même empilement à la main** (le piège « dans 3 mois on ne peut plus
rien ajouter » de `engine-architecture.md` §2.3).

---

## 2. (B) LA COUCHE DE MODIFICATEURS DE STATS — la fondation

### 2.1 Comment les ARPG structurent les modifs (sources primaires)

**Path of Exile** — formule de base des dégâts :

> `Damage = (Base + Added) × Increased × More × …`
> - **Increased** : « All applicable sources of increased damage **stack additively** (e.g. two +10 %
>   modifiers add together to make 20 %: 100 % + 10 % + 10 % = 120 %). »
> - **More** : « All unique sources of more damage are **multiplicative** with each other (110 % × 110 %
>   = 121 %). » « More Damage is usually more effective than Increased Damage, due to **diminishing
>   returns** from stacking increased modifiers. »
> Source : PoE Wiki, *Damage → Damage calculation* — <https://www.poewiki.net/wiki/Damage>

**Path of Exile** — généralisé à **toute** stat (pas seulement les dégâts) :

> `stat_total = (Σ added) × (1 + Σ increased − Σ reduced) × Π(1 + more) × Π(1 − less)`
> « You **add** the various increased/reduced effects together into a single multiplier… whereas you
> **multiply** the base stat by each more/less effect in turn. » Les `_final` (more/less) portent un
> suffixe d'ID dédié.
> Source : PoE Wiki, *Stat → Flat, additive and multiplicative stats* — <https://www.poewiki.net/wiki/Stat>

**Last Epoch** — même structure, énoncé pédagogique (notre patron d'implémentation) :

> 1. `(5 + 2 + 3) = 10` — d'abord **tous les added** se totalisent.
> 2. `(1 + 0.05 + 0.3 + 0.1) = 1.45` — ensuite **tous les increased** se totalisent (+1).
> 3. `10 × 1.45 = 14.5` — le total added × le total increased.
> 4. `14.5 × (1+0.05) × (1+0.3) × (1+0.1) = 21.77` — puis **chaque more séparément**.
> « Note that the more sources are **not added together first**, which would result in a different
> number (21.03 vs 21.77). »
> Source : Last Epoch Tools, *Combat Mechanics → Increased, Added, and More* —
> <https://www.lastepochtools.com/guide/section/increased_added_and_more>

**Ordre d'application des dégâts-subis** (PoE 2, identique en esprit à PoE 1) — c'est le stage qui nous
intéresse pour le choc et le poison-malus :

> Step 5 — Damage Taken Modifiers, dans cet ordre :
> 1. **Flat** Damage Taken (rare).
> 2. **Increases/Reductions** to Damage Taken **summed together** before applying (ex. *Wither* **et
>    *Shock*** sont ici, additifs entre eux).
> 3. **More/Less** to Damage Taken, **multiplicatifs**.
> Source : Mobalytics PoE 2, *Full Order of Operations Damage & Defence* —
> <https://mobalytics.gg/poe-2/guides/damage-defence-calc-order>

**Slay the Spire** — confirme l'**ordre flat-avant-multiplicateur** et le **déterminisme entier** :

> « **Strength** (flat, +1/stack) is applied **before** multiplicative effects like **Vulnerable**
> (1.5×). Ex. : 2 Strength + Strike sur cible Vulnerable = `(6+2)×1.5 = 12`, pas `(6×1.5)+2 = 11`. »
> Sources : StS Wiki *Vulnerable* — <https://slaythespire.wiki.gg/wiki/Vulnerable> ; Spire-Codex
> *Combat Mechanics* — <https://beta.spire-codex.com/mechanics/combat-mechanics>

**Synthèse des sources** : tout le monde converge sur **`(base + Σflat) · (1 + Σincreased) · Π(more)`,
flat→increased→more, increased additif, more rare et multiplicatif**. C'est exactement la formule
**déjà esquissée** dans `engine-architecture.md` §6.5 — ce document la **promeut en spécification**.

### 2.2 L'archi minimale et déterministe pour notre moteur

**Principe** : une stat n'est plus un nombre, c'est une **valeur de base + des contributions empilées**,
résolue **à la demande** par une fonction pure. On ne **mute jamais** `u.dmg` en place (ça casserait le
recalcul d'aura déjà acquis, cf. §6.6 de l'archi : « aura = dérivée, jamais mutée »).

```lua
-- src/effects/stats.lua  (NOUVEAU — couche SIM pure, zéro love.*)
-- Une stat modifiable = un base + 3 buckets. ORDRE-INDÉPENDANT par construction :
--   flat et increased s'ADDITIONNENT (commutatif) ; more se MULTIPLIENT (Π commutatif).
-- => le résultat ne dépend JAMAIS de l'ordre d'itération => déterminisme GRATUIT (pas de tri requis).
local M = {}

-- mods : liste de contributions { kind="flat|increased|more", stat="dmg|shield|cd|aggro|damage_taken|...",
--                                 value=number, [src=id] }  -- src = pour l'event-log/débogage seulement
-- base : nombre. clampMin/clampMax : bornes optionnelles. Renvoie un nombre.
function M.resolve(base, mods, stat, clampMin, clampMax)
  local flat, inc, more = 0, 0, 1
  if mods then
    for i = 1, #mods do                 -- for i=1,#t : JIT-friendly, jamais pairs (déterminisme §10)
      local m = mods[i]
      if m.stat == stat then
        local k = m.kind
        if     k == "flat"      then flat = flat + m.value
        elseif k == "increased" then inc  = inc  + m.value      -- ex. -0.25 = "réduit de 25%"
        elseif k == "more"      then more = more * (1 + m.value)
        end
      end
    end
  end
  local v = (base + flat) * (1 + inc) * more
  if clampMin and v < clampMin then v = clampMin end
  if clampMax and v > clampMax then v = clampMax end
  return v
end
return M
```

**Comment ça s'enregistre sans casser l'existant** :

- Une unité gagne un champ `mods = {}` (liste, défaut vide). Les auras d'adjacence, le choc, le poison-
  malus, l'aggro-buff **poussent des lignes dedans** au lieu de muter une stat. Recalcul des
  contributions d'aura/build aux mêmes hooks qu'aujourd'hui (`combat_start`/`on_place`…), **2 passes**
  (reset → accumuler en lisant le base → appliquer), cf. archi §6.6.
- Le calcul de dégâts (`arena.lua:hit`/`damage`) lit **`M.resolve`** au lieu des champs bruts. La stat
  `damage_taken` devient le **point d'entrée du choc** (voir §A.4). **Rétro-compat** : une unité sans
  `mods` ⇒ `M.resolve(base, nil, …) = base` ⇒ comportement v0 inchangé.
- **Aucune édition de la boucle de combat** : ajouter un modificateur = pousser une ligne de data + (si
  besoin) un op. C'est l'ouvert/fermé déjà en place pour les effets.

**Nouveaux ops** (`src/effects/ops.lua`) — le vocabulaire qui *écrit* dans `mods` :

```lua
-- pousse une contribution persistante sur la cible (durée optionnelle gérée au tick, comme poison)
Ops.add_mod = function(ctx, p)               -- p = { to="self|victim|neighbors", stat, kind, value, dur? }
  local u = resolveTarget(ctx, p.to)         -- self/victim direct ; neighbors résolu au build (graphe)
  u.mods = u.mods or {}
  u.mods[#u.mods+1] = { stat = p.stat, kind = p.kind, value = p.value, src = ctx.source.id, dur = p.dur }
end

-- met une stat à une valeur (override dur) : sert au STRIP d'aggro et à la furtivité (§C)
Ops.set_stat = function(ctx, p)              -- p = { to, stat, value }
  resolveTarget(ctx, p.to)[p.stat .. "_override"] = p.value   -- lu en priorité par l'accesseur
end
```

**Anti-explosion (sourcé)** : (a) les `increased` s'additionnent (pas de produit d'increased) → pas
d'empilement exponentiel ; (b) les `more` sont **rares** (réservés aux reliques signature) ; (c) `clamp`
final (ex. `damage_taken` plafonné à +200 %) ; (d) on garde les **nombres entiers** au moment d'appliquer
les dégâts (`math.floor(v + 0.5)`) → pas de dérive flottante, golden-logs stables (archi §8.6). PoE
elle-même borne ainsi : « More is usually more effective… due to diminishing returns from stacking
increased » (la structure *décourage* l'empilement plat infini). Source : PoE *Damage* (ci-dessus).

### 2.3 Le malus du créateur (« poison −25 % de la valeur des capacités ») exprimé dans B

```lua
-- "Le poison ronge : -25% à la valeur des capacités de la cible." (shield 15 -> 11.25 -> floor 11)
-- C'est un INCREASED NÉGATIF sur la stat visée, posé en data, sans toucher la boucle.
{ trigger="on_hit", op="add_mod",
  params={ to="victim", stat="shield_value", kind="increased", value=-0.25, dur=180 } }
-- resolve(15, mods, "shield_value") = (15 + 0) * (1 + (-0.25)) * 1 = 11.25  -> appliqué floor = 11
```

Note : le **tick** du poison (DoT dégâts/s) est le périmètre de l'**agent 1** ; ici on ne traite que le
**volet « modificateur de stat »** (la corrosion de valeur), qui est un pur client de B.

---

## 3. (A) LE CHOC — amplification de dégâts accumulée et déterministe

### 3.1 Ce que fait le shock dans Path of Exile (source primaire)

> « Shock is a debuff that **increases damage taken**… Shock's default **maximum effect is 50 %**
> [PoE 1 ; **100 %** en PoE 2]. Its base duration is **2 seconds**. »
> **Magnitude liée à la taille du coup** : `E = ½ · (D / T)^0.4 · (1 + M)` où `D` = dégâts (de foudre)
> du coup, `T` = seuil d'ailment de la cible (≈ sa vie max), `M` = increased effect of shock (0 par
> défaut). L'**exposant 0.4 < 1 = rendements décroissants** : il faut **100 % du seuil** en un coup pour
> le shock max de 50 %, mais seulement **~17.7 %** pour 25 %.
> **Increased Damage Taken** : « additive with other sources of increased Damage Taken, such as Wither. »
> **NE STACKE PAS** : « Shock normally does **not** stack ; multiple shocks can exist… but **only the
> strongest** will apply its increase to damage taken. »
> Sources : PoE Wiki *Shock* — <https://www.poewiki.net/wiki/Shock> ; PoE 2 Wiki *Shocked* —
> <https://www.poe2wiki.net/wiki/Shocked> ; Mobalytics *Shock Explained (PoE 2)* —
> <https://mobalytics.gg/poe-2/guides/shock>

**Conséquence pour nous** : le shock PoE est **un seul gros debuff non-cumulatif** dont la *magnitude*
varie. Le créateur veut l'inverse : un **choc qui s'accumule** (« prend PLUS de dégâts selon le choc
accumulé »). On ne copie donc **pas** le non-stacking de PoE ; on prend son **exposant < 1** (anti-
explosion) et son **additivité** dans le bucket damage-taken, mais le **stacking** vient d'ailleurs.

### 3.2 Le modèle de stacking : Last Epoch Shred (source primaire)

> **Shred Armor / Resistance Shred** : « Reduces armor/resistance, **increasing damage taken** from hits.
> Duration **4 seconds**. **Max stacks** : 20 (pour Shred résistance ; armor = −100 par stack). Resistance
> Shred **reduces resistance by 5 %** (2 % vs boss/joueur) et **stacke jusqu'à 20 fois**, additif. »
> « can be **dispelled** with cleanse. »
> Sources : Last Epoch Tools *Shred Armor* — <https://www.lastepochtools.com/ailments/armour_shred> ;
> *Shock* (LE) — <https://www.lastepochtools.com/ailments/shock> ; Dev Blog *Overhauling Defenses* —
> <https://forum.lastepoch.com/t/overhauling-defenses-in-last-epoch/25081>

> **Confirmation du pattern « stacke jusqu'à un cap, additif »** : « Shred basically functions… as a
> temporary debuff… which also has a **stack limit of 20 stacks**. » — Forum LE, *penetration/shred* —
> <https://forum.lastepoch.com/t/question-on-penetration-shred/30320>

### 3.3 Le modèle de magnitude/durée : StS Vulnerable (source primaire) — le « contre-modèle » simple

> **Vulnerable** : « Receive **50 % more damage** from Attacks for X turns. Each point of Vulnerable
> **increases how many turns** the debuff is active. » La **magnitude est FIXE** (1.5×), les **stacks =
> durée** (compteur qui décroît de 1/tour), multiplicatif, **déterministe et entier**.
> Source : StS Wiki *Vulnerable* — <https://slaythespire.wiki.gg/wiki/Vulnerable> ; Spire-Codex (ci-dessus).

Deux philosophies opposées dans les sources :
- **PoE / Last Epoch** : *stacks = magnitude* (plus de stacks = plus de dégâts subis), durée fixe par stack.
- **StS** : *stacks = durée*, magnitude fixe.

**Notre choix (pour « choc accumulé ») = le modèle stacks=magnitude (Last Epoch)**, car le créateur veut
explicitement « **PLUS** de dégâts selon le choc **accumulé** ». On garde la **durée glissante** (chaque
application rafraîchit) et le **plafond** de StS/LE comme garde-fous.

### 3.4 Le modèle de choc retenu (déterministe, additif, plafonné, décroissant)

**État** porté par l'unité : `u.shock = { stacks = N, remaining = frames }` (même forme que `u.poison`
déjà géré au tick dans `arena.lua`, donc **zéro nouveau système de tick**).

| Paramètre | Valeur (placeholder) | Justification sourcée |
|---|---|---|
| **Increased dmg-taken par stack** | `+6 %` (0.06) | échelle entre StS (+50 % d'un coup) et LE (+5 %/stack) ; petit pour rester tunable |
| **Plafond de stacks** | `8` (⇒ +48 % max) | LE plafonne à 20 ; on vise plus bas (combats courts) ; cap = anti-explosion #1 |
| **Hard-cap damage_taken** | `+200 %` au clamp final | PoE 2 cap le shock à +100 % ; on borne *tout* le bucket damage-taken (archi §6.5 clamp) |
| **Décroissance** | durée glissante **180 f (~3 s)**, refresh à chaque hit | PoE shock 2 s, LE shred 4 s ; entre les deux |
| **Application** | **additive** dans le bucket `damage_taken`, additive avec les autres increased | PoE : « additive with other sources of increased Damage Taken » |
| **Courbe (option avancée)** | gain par stack `floor(k · n^0.4)` au lieu de linéaire | reprend l'exposant 0.4 de PoE = rendements décroissants si on veut durcir l'anti-explosion |

**Comment ça modifie le calcul de dégâts** — le choc n'est qu'**une source `increased` sur la stat
`damage_taken`**, lue par `arena.lua:damage` via `M.resolve` :

```lua
-- dans Arena:hit, AVANT d'appeler :damage — on calcule le multiplicateur de dégâts-subis de la cible.
-- base damage_taken = 1.0 ; le choc et tout autre debuff y poussent des "increased".
local dtMods = target.mods                 -- + une ligne synthétique pour le choc actif :
-- (le choc vit dans target.shock ; on l'injecte comme increased au moment du coup)
local shockInc = target.shock and (target.shock.stacks * 0.06) or 0
local dmgTaken = (1.0) * (1 + shockInc + sumIncreased(dtMods, "damage_taken"))  -- additif (PoE)
dmgTaken = math.min(dmgTaken, 3.0)         -- clamp +200%
ctx.amount = ctx.amount * dmgTaken          -- puis shield absorbe, etc. (pipeline inchangé en aval)
```

- **Additif, pas par-stack-multiplicatif** : 4 stacks = +24 % (pas `1.06^4`). C'est le choix de PoE
  (« additive ») et **ce qui évite l'explosion exponentielle** demandée par le brief.
- **Déterministe** : `stacks` est un entier muté par des hits déterministes ; aucun dé. La décroissance
  est un compteur de frames (pas-fixe). `M.resolve` est ordre-indépendant.
- **Plafonné deux fois** : cap de stacks (8) **et** clamp du bucket (+200 %).

**Ops du choc** (data pure) :

```lua
-- applique/rafraîchit N stacks de choc (cap interne). Géré au tick comme le poison (décroissance).
Ops.apply_shock = function(ctx, p)           -- p = { stacks=1, dur=180, cap=8 }
  local v = ctx.victim
  local s = v.shock
  if not s then s = { stacks = 0, remaining = 0 }; v.shock = s end
  s.stacks    = math.min((s.cap or p.cap or 8), s.stacks + (p.stacks or 1))
  s.remaining = p.dur or 180                  -- refresh glissant (toute nouvelle appli prolonge)
end
```

Décroissance au tick (à ajouter à côté du bloc `u.poison` existant dans `arena.lua:update`) :
```lua
if u.shock then
  u.shock.remaining = u.shock.remaining - frameDt
  if u.shock.remaining <= 0 then u.shock = nil end   -- expire d'un bloc (simple) ; option : -1 stack/intervalle
end
```

### 3.5 Famille « amplification » — RÈGLE DES 3 PALIERS (~10 unités, esquisse)

Noms EN, pseudo-descripteurs, **chiffres placeholders** (à tuner via `tools/sim.lua`). Toutes poussent
dans la **même stat `damage_taken`** via `apply_shock`/`add_mod` ⇒ elles se **synergisent** nativement
(plus de sources de choc = la cible fond plus vite, mais **plafonnée**).

**T1 — fondations (5)** : appliquer un peu de choc, fiable.
1. **Sparkmaw** — `{trigger="on_hit", op="apply_shock", params={stacks=1, dur=180}}` — 1 stack/coup. Le « stacker » de base.
2. **Galvanic Sigil** *(relique de slot)* — `{trigger="combat_start", op="add_mod", params={to="neighbors", stat="shock_power", kind="increased", value=0.5}}` — les voisins appliquent +50 % de stacks de choc (synergie d'adjacence).
3. **Conductor** — `{trigger="on_attack", op="apply_shock", params={stacks=1}}` puis dégâts : **frappe la cible déjà choquée** pour +flat (condition `target_shocked`). Récompense le set-up.
4. **Brittle Mark** — `{trigger="on_hit", op="add_mod", params={to="victim", stat="damage_taken", kind="increased", value=0.10, dur=120}}` — un mini-vulnerable plat (style StS), distinct du choc (se cumule additivement avec lui).
5. **Static Veil** *(défensif)* — `{trigger="on_attacked", op="apply_shock", params={stacks=1, to="source"}}` — choque qui te frappe (thorns d'amplification, pas de dégâts).

**T2 — amplificateurs (3)** : démultiplient le choc existant.
6. **Stormcaller** — `{trigger="on_hit", op="apply_shock", params={stacks=2}}` + `condition={kind="chance",value=0.5}` n/a (zéro hasard en combat) → plutôt `condition` contextuelle « si la cible a déjà ≥3 stacks » pour un palier de skill. Gros stacker conditionnel.
7. **Ruinous Toll** — `{trigger="on_hit", op="add_mod", params={to="victim", stat="shock_per_stack", kind="increased", value=0.5}}` — **augmente la valeur de chaque stack** sur la cible (de +6 % à +9 %/stack) : amplifie l'amplification (à clamp).
8. **Overload Sigil** *(relique de slot)* — relève le **cap de stacks** des alliés adjacents de 8 → 12 ; data `add_mod stat="shock_cap" kind="flat" value=4 to="neighbors"`.

**T3 — signatures (2)** : effets « more » rares (multiplicatifs) ou conversions, à fort impact.
9. **Cataclysm Engine** — `{trigger="on_hit", op="add_mod", params={to="victim", stat="damage_taken", kind="more", value=0.25, dur=120}}` — **+25 % MORE** de dégâts subis (multiplicatif, rare = T3). Se compose multiplicativement par-dessus tout le choc additif.
10. **Sundered Crown** *(relique signature)* — convertit les stacks de choc en **exposure permanente du combat** : à 8 stacks, pose `damage_taken increased +30 %` qui **ne décroît plus** (`dur=nil`) jusqu'à la fin du combat. Le « payoff » de l'archétype full-choc.

> Profil d'archétype : **T1 stacke, T2 amplifie la valeur/le cap, T3 ajoute du `more` rare ou verrouille
> l'amplification**. La diversité vient du fait que toutes écrivent dans la **même** stat `damage_taken`
> mais à des **buckets différents** (flat/increased/more) et avec des **conditions** différentes (cible
> déjà choquée, voisinage, défensif). **Anti-explosion** garanti par le cap de stacks + le clamp du bucket.

---

## 4. (C) AGGRO / TAUNT CONCRET

### 4.1 Le modèle de menace (source primaire WoW) — ce qu'on emprunte / ce qu'on rejette

> **WoW threat** : « Each NPC has a **threat table** ; the unit toward the **top** is the target. »
> **Taunt** : « **Sets threat equal to the highest** player on the target's threat list » + force le focus
> (override dur, durée courte). **Tank multipliers** : « 5.0× threat modifier (Defensive Stance…) » et
> « when two or more factors apply, they stack **multiplicatively** without diminishing returns. »
> **Stickiness** : pour ravir l'aggro il faut **110 %** (mêlée) / **130 %** (distance) du tank — « once
> they lose aggro it becomes very challenging to regain it. »
> **Strips** : *Fade* « sets threat to 0 for the duration » ; *Vanish* « removes from threat lists » ;
> *Tricks of the Trade / Misdirection* « temporarily **transfer** threat » ; *Soulshatter* « reduces
> threat by 90 % ».
> Sources : Warcraft Wiki *Threat* — <https://warcraft.wiki.gg/wiki/Threat> ; *Aggro* —
> <https://warcraft.wiki.gg/wiki/Aggro> ; classic-warrior *Threat Mechanics* —
> <https://github.com/magey/classic-warrior/wiki/Threat-Mechanics>

**On EMPRUNTE** : (a) taunt = **set-to-top / override dur** (déjà notre flag) ; (b) l'aggro est une
**stat triée** (la plus haute focus) ; (c) les **strips** (mettre à 0, transférer) comme contres ; (d)
les **multiplicateurs** d'aggro passent par le bucket B.

**On REJETTE** : le **compteur de menace live** WoW (threat qui s'accumule pendant le combat avec
seuils 110/130 %). Raison déjà actée dans `combat-model-decision.md` §5 : « **pas** le match-top+1 MMO
(pas de compteur de menace live) » — ça introduit de l'**historique d'état dépendant du timing**, plus
dur à rendre déterministe/async-vérifiable et à lire. Notre aggro est une **stat statique du build**
(modifiée par placement/auras/reliques), **pas** une accumulation par dégâts. C'est le modèle
**Honkai/Xenoblade (aggro = stat)** déjà cité, pas le modèle WoW (aggro = compteur).

### 4.2 Valeurs et archétypes proposés (placeholders)

L'aggro est **inerte aujourd'hui** (tout à 0). Proposition de baseline (à tuner via `tools/sim.lua`
quand les plateaux se remplissent — cf. dette connue `combat-model-decision.md` §6) :

| Archétype | `aggro` base | `taunt` | Rôle |
|---|---|---|---|
| **Tank / Guardian** | **40** | `false` (taunt = via relique/cap) | tire le focus dans sa colonne ; encaisse |
| **Bruiser** (marauder) | 15 | false | encaisse un peu, garde la carry plus longtemps |
| **Standard** (skeleton, bandit) | 10 | false | baseline neutre |
| **Carry / Glass** (witch, demon) | **5** | false | **veut être ignorée** ; se place à l'arrière ET baisse son aggro |
| **Taunt-relic porteur** | (variable) | **true** quand actif | override dur, **rare**, via relique/sigil |

> Rappel `chooseTarget` (déjà codé, `arena.lua:107`) : **colonne avant** (depth) → **taunt** (override)
> → **aggro max** → tie-break **row haut→bas** puis slot. Donc l'aggro ne **re-trie que dans la colonne
> atteignable** : elle **redistribue qui encaisse, jamais combien au total** (principe d'or
> `combat-model-decision.md` §5). Un tank à l'arrière ne protège rien tant que sa colonne n'est pas le
> front — **placement + aggro = une seule décision** (le 2ᵉ axe).

### 4.3 Les effets qui MODIFIENT l'aggro (via la couche B)

Tout passe par `add_mod` / `set_stat` sur la stat `aggro` — **aucune nouvelle plomberie**, c'est de la
data. L'accesseur d'aggro dans `chooseTarget` lira `M.resolve(u.aggro_base, u.mods, "aggro")` (ou
l'`aggro_override` s'il existe).

```lua
-- Porte-étendard (banner) : +aggro aux voisins -> il "aspire" le focus autour de lui. (synergie d'adjacence)
{ trigger="combat_start", op="add_mod",
  params={ to="neighbors", stat="aggro", kind="flat", value=20 } }

-- Carry furtive : -aggro sur elle-même -> sort de la priorité de ciblage tant qu'elle a des alliés devant.
{ trigger="combat_start", op="add_mod",
  params={ to="self", stat="aggro", kind="flat", value=-8 } }

-- Provocation (relique de taunt) : pose le flag dur sur le porteur au début du combat.
{ trigger="combat_start", op="set_stat", params={ to="self", stat="taunt", value=true } }
```

### 4.4 Les CONTRES (cohérents avec « zéro hasard en combat »)

Le brief demande explicitement strip / AoE-qui-ignore-le-guard / furtivité. Tous **déterministes** :

1. **Strip d'aggro** — `{trigger="on_hit", op="set_stat", params={to="victim", stat="aggro", value=0}}`
   (ou `taunt=false`). Inspiré de WoW *Fade* (« sets threat to 0 ») / *Soulshatter*. Annule le mur de
   tank pour le reste du combat.
2. **AoE / frappe de colonne qui ignore le guard** — une attaque taguée `ignoreGuard=true` qui, dans
   `chooseTarget`, **saute l'étape taunt** (et frappe la vraie cible la plus profonde). C'est l'analogue
   de l'assassin TFT (« bypass-position ») mais **borné** : il ignore le *guard*, pas la *colonne*
   (préserve l'invariant front/back async, cf. §5 de la décision). Donné comme **option de relique
   rare**, jamais baseline.
3. **Furtivité** — `aggro = 0` **conditionnel** : `{trigger="combat_start", op="set_stat",
   params={to="self", stat="aggro", value=0}}` tant qu'un allié vit devant (condition `has_ally_front`).
   Modèle WoW *Vanish* (retiré des tables) / carry furtive. La carry **disparaît** du ciblage jusqu'à ce
   que son écran tombe.
4. **Anti-taunt « saut de ligne »** *(rare, T3)* — relique façon assassin : autorise une unité à cibler
   **une colonne plus profonde** une fois le front taunté vidé plus vite. À livrer **avec** son contre
   (re-placement), conformément à la règle « aucun bypass-position sans contre positionnel » (décision §3).

> **Pièges à éviter** (sondés par le harnais, cf. décision §5) : mur **max-aggro indéboulonnable** (⇒
> toujours fournir un strip + un AoE-ignore-guard), **aggro-taxe obligatoire** (chaque build forcé d'en
> prendre), **aggro inerte** (combats trop courts pour qu'elle compte). Le principe d'or reste : l'aggro
> **échange une topologie de focus, pas de la puissance**.

---

## 5. Impact sur l'existant & ordre d'implémentation (sans casser)

1. **`src/effects/stats.lua` (NOUVEAU)** — `M.resolve(base, mods, stat, clampMin, clampMax)`. Couche SIM
   pure, testable headless. Rien d'autre n'en dépend encore ⇒ ajout non destructif.
2. **`arena.lua`** — (a) lire `M.resolve` pour `dmg`/`damage_taken`/`aggro` au lieu des champs bruts ;
   rétro-compat : `mods=nil` ⇒ valeur de base ⇒ **golden-log inchangé** tant qu'aucune unité n'a de mod ;
   (b) bloc de décroissance `u.shock` à côté de `u.poison` (même pattern de tick) ; (c) accesseur d'aggro
   dans `chooseTarget`. **Aucune nouvelle branche `if kind == …`** : tout est data.
3. **`ops.lua`** — ajouter `add_mod`, `set_stat`, `apply_shock`. Chacun = ~5 lignes pures. L'op n°50 ne
   casse pas le n°1 (contrat `ctx` seul), cf. `engine-architecture.md` §6.2.
4. **`units.lua` / futures reliques** — les ~10 unités d'amplification + les valeurs d'aggro = **pure
   data** ajoutée aux `effects` (et un champ `aggro`/`taunt`, déjà lu par `makeUnit`).
5. **Tests** — étendre `props.lua` (invariant : `damage_taken` clampé, `stacks ≤ cap`, aggro ≥ 0 après
   strip), `golden.lua` (scénario choc figé), `tools/sim.lua` (part de dégâts attribuée au choc via
   l'event-log `cause`/`effect`, σ/entropie inchangées hors archétype amp). **Test déterminisme
   double-run** couvre l'ordre-indépendance de `M.resolve` automatiquement.

**Déterminisme préservé** : `M.resolve` n'itère que des arrays en `for i=1,#t` (jamais `pairs`), additif
donc ordre-indépendant ; le choc est un entier muté par des hits déterministes ; aucun `math.random`.
Conforme aux règles anti-spaghetti §10 de l'archi.

---

## 6. Tableau de synthèse (mécanique → expression data → impact calcul)

| Mécanique | Famille | Expression `{trigger, op, params}` | Nouvel op/état | Impact sur le calcul |
|---|---|---|---|---|
| **Bucket de stat** | B | (interne) | `stats.lua:resolve` | `final = clamp((base+Σflat)(1+Σincr)Π(more))` ; ordre-indépendant ⇒ déterministe |
| **Poison −25 % shield** | B (malus) | `add_mod victim shield_value increased -0.25` | `add_mod` | `(15)(1−0.25)=11.25` → floor 11 |
| **Choc (1 stack)** | A | `apply_shock victim {stacks=1,dur=180}` | `apply_shock` + `u.shock` | `+6 %` increased dmg-taken/stack, additif, cap 8, clamp +200 % |
| **Choc — valeur/stack** | A (T2) | `add_mod victim shock_per_stack increased +0.5` | (lit par accesseur) | chaque stack passe de +6 % à +9 % |
| **Choc — MORE rare** | A (T3) | `add_mod victim damage_taken more +0.25` | `add_mod` | ×1.25 multiplicatif par-dessus l'additif |
| **Porte-étendard +aggro** | C | `add_mod neighbors aggro flat +20` | `add_mod` | les voisins montent dans le tri `chooseTarget` |
| **Carry furtive −aggro** | C | `add_mod self aggro flat −8` (ou `set_stat aggro 0` cond.) | `add_mod`/`set_stat` | sort de la priorité de ciblage |
| **Taunt (override dur)** | C | `set_stat self taunt true` | `set_stat` | re-trie DANS la colonne (étape 2 de `chooseTarget`) |
| **Strip d'aggro** | C (contre) | `set_stat victim aggro 0` | `set_stat` | annule le tank pour le combat |
| **AoE ignore-guard** | C (contre) | attaque `ignoreGuard=true` | flag d'attaque | saute l'étape taunt, garde la colonne |

---

## 7. Questions ouvertes (à trancher avant de coder)

1. **Choc : stacks=magnitude (LE, retenu) vs stacks=durée (StS)** ? Le brief penche pour *magnitude
   accumulée* → LE. Confirmer qu'on ne veut pas le compteur-durée plus simple de StS.
2. **Décroissance du choc** : expiration en bloc (simple, retenu) vs **−1 stack par intervalle** (plus
   organique, un poil plus de code) ?
3. **`damage_taken` : clamp à +200 %** — bon plafond ? PoE 2 plafonne le seul shock à +100 % ; nous
   bornons *tout* le bucket. À valider en sim.
4. **Aggro = stat statique (retenu) vs léger compteur** (un hybride « +aggro quand l'unité agit ») ? Le
   statique est plus déterministe/async-safe ; à confirmer.
5. **`more` sur damage_taken** réservé aux T3 uniquement (garder la rareté du multiplicatif) ?

---

## 8. Index des sources (primaires d'abord)

- **PoE — Shock** (formule `½·(D/T)^0.4·(1+M)`, cap 50 %, ne stacke pas, additif) —
  <https://www.poewiki.net/wiki/Shock>
- **PoE 2 — Shocked** (cap 100 %, magnitude 20 % base, additif avec damage-taken) —
  <https://www.poe2wiki.net/wiki/Shocked> ; Mobalytics — <https://mobalytics.gg/poe-2/guides/shock>
- **PoE — Damage** (`(Base+Added)×Increased×More`, increased additif, more multiplicatif, diminishing) —
  <https://www.poewiki.net/wiki/Damage>
- **PoE — Stat** (formule générale toute-stat, ordre d'application) — <https://www.poewiki.net/wiki/Stat>
- **PoE — Vulnerability** (increased phys taken = additif avec autres damage-taken, multiplicatif vs attaquant) —
  <https://www.poewiki.net/wiki/Vulnerability>
- **PoE 2 — Order of Operations** (étage damage-taken : flat → increased sommés → more) —
  <https://mobalytics.gg/poe-2/guides/damage-defence-calc-order>
- **Last Epoch — Increased, Added, and More** (patron d'implémentation pas-à-pas) —
  <https://www.lastepochtools.com/guide/section/increased_added_and_more>
- **Last Epoch — Shred Armor / Shock / Resistances** (stacking : cap 20, additif, décroît, dispellable) —
  <https://www.lastepochtools.com/ailments/armour_shred> · <https://www.lastepochtools.com/ailments/shock> ·
  <https://www.lastepochtools.com/guide/section/resistances> ·
  <https://forum.lastepoch.com/t/overhauling-defenses-in-last-epoch/25081> ·
  <https://forum.lastepoch.com/t/question-on-penetration-shred/30320>
- **Slay the Spire — Vulnerable / Weak** (multiplicatif fixe, stacks=durée, flat avant multiplicateur, entier) —
  <https://slaythespire.wiki.gg/wiki/Vulnerable> · <https://slaythespire.wiki.gg/wiki/Weak> ·
  <https://beta.spire-codex.com/mechanics/combat-mechanics>
- **WoW — Threat / Aggro** (taunt = set-to-top override, multiplicateurs multiplicatifs, strips Fade/Vanish/Tricks) —
  <https://warcraft.wiki.gg/wiki/Threat> · <https://warcraft.wiki.gg/wiki/Aggro> ·
  <https://github.com/magey/classic-warrior/wiki/Threat-Mechanics>
- Réfs internes : `engine-architecture.md` (§6.5 buckets, §6.6 auras, §10 anti-spaghetti),
  `combat-model-decision.md` (§5 aggro 2 couches, principe d'or), `src/combat/arena.lua`,
  `src/effects/ops.lua`, `src/data/units.lua`.
