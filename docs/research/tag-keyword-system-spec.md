# Mechanic TAG (keyword) System — SPEC

> The Pit · autobattler async grimdark · LÖVE 11.5 · pixel-art procédural.
> **Status: SPEC** (design + architecture + UX mockup). PAS d'implémentation ici.
> Author: **ui-artisan**. Golden **1176281181** doit tenir (ce chantier est **RENDER + data-additif**,
> **ne touche jamais la SIM** : `src/combat`, `src/board`, `src/effects` lus, pas modifiés).

## 0. Vision (mots de l'user, traduits)

- Chaque effet/mécanique devient un **mot-clé COLORÉ** dans le texte affiché, lié à une mécanique — comme
  les mots-clés de **Path of Exile / MTG / Hearthstone**. Une future **wiki / glossaire in-game** les explique.
- Au **survol** d'un monstre (la fiche d'unité existante), maintenir **SHIFT** ouvre un **second popup à
  DROITE** de la fiche, qui explique **TOUS les tags présents sur ce monstre** (glossaire par-unité).
- But : nos nombreux effets ont des mécaniques pas toujours expliquées ; les tags rendent chaque mécanique
  **lisible** et **wiki-ready**.

---

## 1. CE QUI EXISTE DÉJÀ (survey — règle d'or §1.b : réutiliser, ne pas réinventer)

Le projet a **déjà 70 % du système**. Le « registre de mots-clés » de l'user **existe** pour les afflictions.
On l'**étend** ; on ne le recrée pas.

| Brique existante | Fichier | Ce qu'elle fait | Verdict |
|---|---|---|---|
| **Registre de mots-clés** | `src/ui/keywords.lua` | Source UNIQUE des afflictions : `{key, color, name(i18n), blurb(i18n)}` + `OP_AFFLICTION` (op→clé) + `applied(unit)` (liste ordonnée des afflictions d'une unité, lue de `unit.effects`) + `icon(key)` (bake lazy mémoïsé) | **ÉLARGIR** : c'est exactement le registre voulu, mais limité aux 5 afflictions. On le généralise en registre de TAGS. |
| **Chip (pastille keyword)** | `src/ui/chip.lua` | `[icône 8×8][LABEL][valeur]` + liseré coloré par la famille, fond `panelDeep`. `Chip.width/draw/row`. Léger (1px liseré, pas de biseau). | **RÉUTILISER tel quel** pour les lignes du glossaire (swatch = mini-chip). |
| **Palette afflictions** | `src/ui/theme.lua` (`Theme.c`) | Couleurs canoniques : `poison 0x93c12f`, `bleed 0xd8475e`, `burn 0xe0792e`, `rot 0xa86fc4`, `shock 0xf2d24a`, `regen`, `shield`, + auras agnostiques `armor`(steel) / `empower`(ember) / `haste`(gold) / `echo`(bloodL), + `Theme.types` (flesh/order/bone/arcane/abyss). | **SOURCE DE VÉRITÉ des couleurs de tag.** On NE crée aucune couleur neuve sans nécessité. |
| **VFX de combat = mêmes teintes** | `src/render/arena_draw.lua:691` | `CAUSE_COL = { burn=c.burn, bleed=c.bleed, poison=c.poison, rot=c.rot, shock=c.shock }` | **Confirme** : la couleur de tag DOIT être la couleur VFX (un poison vert dans l'arène = un tag POISON vert). Cohérence garantie. |
| **Icônes 8×8 data-only** | `src/render/affliction_icons.lua` | Grilles `{bleed, poison, burn, rot, shock}` (caractères = teintes abstraites o/d/m/h, teintées par famille au bake). Partagées combat + chips. | **Réutiliser** ; les NOUVEAUX tags qui veulent une icône en ajoutent une grille ici (ou tag sans icône = pip/lettre). |
| **Fiche monstre (le tooltip de l'user)** | `src/render/monstercard.lua` | `MonsterCard.draw(view, palette, id, anchorX, anchorY, t, opts) -> {x,y,w,h}`. Mesure-avant-dessin, hauteur dérivée du contenu, suit le curseur + rebond bords. Dessine déjà une **rangée de chips d'affliction** via `Keywords.applied` + `Chip.draw`, et **colore les valeurs inline** dans la couleur de l'affliction (`drawDescLine` + `tokenizeValues`). Retourne sa boîte. | **C'est LE point d'ancrage du popup Shift** (sa boîte `{x,y,w,h}` donne où coller le glossaire à droite). |
| **Hook de survol** | `src/scenes/build.lua:drawTooltip(id, boardSlot)` (≈3142) + bloc de dispatch (≈2530-2535) | Le build appelle `MonsterCard.draw(...)` et garde la boîte ; `drawBoardInspectorExtra` colle DÉJÀ un panneau sous la fiche (modèle d'ancrage à reproduire à DROITE). `self.mx/self.my` = curseur design ; `self.t/60` = horloge. | **C'est ici qu'on branche le Shift-popup.** |
| **Colorisation inline existante** | `monstercard.lua:tokenizeValues` + `drawDescLine` | Colore déjà les **nombres** d'une ligne dans la couleur de l'affliction primaire. | **Étendre** en colorisation par **token de mot-clé** (cf. §4). |
| **i18n** | `src/i18n/en_ext.lua` (additif anti-conflit) | Porte déjà `kw.poison.name`/`kw.poison.blurb` … `kw.shock.*`, `kw.role.tank/carry/bruiser`, `kw.chimera`. | **Étendre** : toutes les clés de TAG vivent ici (`kw.*`). |
| **Clé d'événement** | `src/combat/arena.lua` émet `affliction_applied`, `spread`, `amped` ; ops dans `src/effects/ops.lua` | Le moteur d'effets : 23 ops enregistrées (`poison/bleed/burn/rot/shock/regen/thorns/strip_shield/grant_team/convert_dot/crit/execute/grant_vuln/cleave/heal_on_kill/purge/aura_stat`…). | **C'est la TABLE D'OPS** dont on dérive `op→tags` (§3). |
| **aura_stat → kind UI** | `src/scenes/build.lua:1912-1918` | Mappe DÉJÀ `dmgReduce→armor`, `atkInc→empower`, `haste→haste`, `multicast→echo` avec couleurs `c.armor/c.empower/c.haste/c.echo`. | **Aligner les tags structurels dessus** (mêmes id, mêmes couleurs) : zéro divergence. |

**Conclusion du survey.** Le « registre + chips + colorisation inline + fiche qui retourne sa boîte » existe.
Le travail est : (a) **généraliser `keywords.lua`** d'« afflictions » à « TAGS » (toutes catégories), (b) ajouter
un **registre op→tags** pour calculer le tag-set d'une unité sans éditer la data, (c) une **colorisation par
token de mot-clé** dans les descriptions, (d) **un seul nouveau composant** : le **glossaire Shift** ancré à
droite de la fiche.

---

## 2. TAXONOMIE DES TAGS (le set complet)

**33 tags**, 6 catégories. Chaque tag = `{ id, name (clé i18n), color (token Theme.c), blurb (clé i18n),
category, icon? }`. **Couleur = réutilisée** de la palette existante partout où elle existe ; les NOUVELLES
teintes (rares) sont notées « NEW » et tirées de tokens déjà présents (discipline de palette, aucun hex inventé).

Convention d'id : `snake_case`, stable (= clé mécanique). Clés i18n : `kw.<id>.name`, `kw.<id>.blurb`.

### 2.1 — Afflictions (9)  · couleur = la teinte VFX de la famille

| id | name | color (Theme.c) | category | icon | blurb (1 ligne) |
|---|---|---|---|---|---|
| `poison` | POISON | `poison` (vert) | affliction | ✓ | Stacking venom — DoT that also weakens the victim's blows. *(existe)* |
| `bleed` | BLEED | `bleed` (cramoisi) | affliction | ✓ | Open wounds — light DoT that slows the victim's attacks. *(existe)* |
| `burn` | BURN | `burn` (braise) | affliction | ✓ | Searing fire — heavy DoT that fades as the flames die down. *(existe)* |
| `rot` | ROT | `rot` (violet) | affliction | ✓ | Necrosis — DoT that also eats the victim's maximum life. *(existe)* |
| `shock` | SHOCK | `shock` (jaune) | affliction | ✓ | Charge — stacks pile up, then discharge to amplify the next hit. *(existe)* |
| `contagion` | CONTAGION | `rot` | affliction | — | An affliction spreads a weaker copy to the target's neighbors. *(op `poison` p.spread, `plague_bearer`)* |
| `propagation` | PROPAGATION | `burn` | affliction | — | When an afflicted enemy dies, the affliction leaps to its neighbors. *(`spread_burn_on_death`, `spread_rot`)* |
| `conversion` | CONVERSION | `rot` | affliction | — | A strike turns one affliction into another (e.g. bleed → rot). *(`convert_to_rot`, `convert_dot`)* |
| `aggravate` | AGGRAVATE | `bleed` | affliction | — | The affliction bursts harder when the victim acts. *(`bloodletter` aggravateMult)* |

### 2.2 — Défense (5)

| id | name | color | category | icon | blurb |
|---|---|---|---|---|---|
| `shield` | SHIELD | `shield` (bleu) | defense | — | A pool of armor absorbed before life — most afflictions ignore it. *(existe : `c.shield`)* |
| `heal` | HEAL | `regen` (vert tendre) | defense | — | Restores life on a trigger (on kill, on hit). *(`heal_on_kill`, lifesteal)* |
| `regen` | REGEN | `regen` | defense | — | Restores a little life every second of combat. *(op `regen`)* |
| `thorns` | THORNS | `steel` (acier) | defense | — | Returns damage to attackers, ignoring shields. *(op `thorns`)* |
| `taunt` | TAUNT | `gold` | defense | — | Forces the enemy front to strike this unit. *(unit `taunt=true`, `aegis_warden`)* |

### 2.3 — Offense (6)

| id | name | color | category | icon | blurb |
|---|---|---|---|---|---|
| `execute` | EXECUTE | `blood` (sang) | offense | — | Hits low-life enemies far harder. *(op `execute`)* |
| `crit` | CRIT | `bloodL` (sang clair) | offense | — | A chance to strike for multiplied damage. *(op `crit`)* |
| `cleave` | CLEAVE | `blood` | offense | — | The strike splashes onto the target's neighbors. *(op `cleave`)* |
| `strip_shield` | STRIP | `steel` | offense | — | The strike dissolves part of the target's shield. *(`strip_shield`, acid_maw `shieldEat`)* |
| `vulnerable` | VULNERABLE | `ember` (braise) NEW-réutil. | offense | — | The target takes increased damage for a short time. *(`grant_vuln`, `markEnemiesVuln`)* |
| `weaken` | WEAKEN | `poison` | offense | — | The victim deals reduced damage (carried by venom). *(poison `weaken`)* |

### 2.4 — Structurel (5)  · aligné sur `aura_stat → kind` existant (build.lua:1912)

| id | name | color | category | icon | blurb |
|---|---|---|---|---|---|
| `aura` | AURA | `gold` | structural | — | A passive bonus radiating to adjacent allies, baked at build. *(auras d'adjacence)* |
| `commander` | COMMANDER | `brassS` (laiton reflet) | structural | — | Rules from the pedestal: an untargetable buff over the whole pack. *(`commandBonus`)* |
| `whisper` | WHISPER | `ink3` (sourdine) | structural | — | A hidden affinity, glimpsed only in the lore. *(murmures — cf. brainstorm)* |
| `multicast` | ECHO | `echo` (=`bloodL`) | structural | — | The unit strikes an extra time per swing. *(`multicast` ; UI kind `echo`)* |
| `haste` | HASTE | `haste` (=`gold`) | structural | — | Faster attack cadence. *(`haste` ; UI kind `haste`)* |

> Note : `empower`(atkInc → +dmg) et `armor`(dmgReduce) existent déjà comme **kinds de chip** (couleurs
> `c.empower`/`c.armor`). Ils sont des **effets d'aura** plus que des mécaniques nommées « wiki » ; on les
> garde comme chips d'aura (déjà branchés) et on **n'en fait pas des tags de glossaire** au lancement (sinon
> on inonde le popup de buffs numériques). À promouvoir en tags plus tard si l'user le veut (juste 2 lignes).

### 2.5 — NOUVEAUX AXES (grosse update à venir) (8)

Ces tags sont **déclarés maintenant** (registre + i18n + couleur), mais **inertes** tant que les ops/champs
correspondants n'existent pas. Déclarer tôt = la wiki est complète, et le jour où l'op arrive, le tag
s'allume tout seul (mapping op→tag déjà prêt).

| id | name | color | category | icon | blurb |
|---|---|---|---|---|---|
| `summon` | ENGEANCE | `arcane` (=`0xa05a8c`) NEW-réutil. type | newaxis | — | Spawns lesser creatures into the pit during combat. |
| `faint` | FAINT | `rot` | newaxis | — | Triggers an effect the moment this creature dies. |
| `mimicry` | ECHO-FORM | `arcane` | newaxis | — | Copies the shape or power of another creature. |
| `ahead` | AHEAD | `ember` | direction | — | Affects the ally/enemy directly in front. |
| `behind` | BEHIND | `shield` | direction | — | Affects the ally directly behind. |
| `above` | ABOVE | `haste` (=gold) | direction | — | Affects the ally directly above on the sigil. |
| `below` | BELOW | `bleed` | direction | — | Affects the ally directly below on the sigil. |
| `type` | TYPE | (par-type, cf. ci-dessous) | type | — | Flesh / Bone / Arcane / Abyss / Order — the creature's nature. |

**Tags de TYPE** (5, dérivés de `Theme.types`, déjà colorés + pippés) : `type_flesh` (color `Theme.types.flesh.color`),
`type_bone`, `type_arcane`, `type_abyss`, `type_order`. Le **pip de type** (`Theme.types[t].pip` : bar/cross/
diamond/star/disc) fait office d'icône (déjà dessiné par `ui/draw.lua`). Ce sont les seuls tags où l'icône
= un **pip procédural**, pas une grille 8×8.

> Les 4 tags **directionnels** sont une famille : un effet ciblant `role:front` / un voisin orienté porte le
> tag de direction correspondant. Au lancement, seul `ahead`/`above`/etc. lié à `target=role:*` est dérivable ;
> les autres restent déclarés-inertes.

**Total : 9 afflictions + 5 défense + 6 offense + 5 structurel + 8 nouveaux axes = 33 tags**, plus **5 tags de
type** (sous-famille de `type`) = **38 entrées de registre**. ~14 réutilisent une couleur affliction/aura
existante ; **0 hex nouveau** (tout vient de `Theme.c` ou `Theme.types`).

---

## 3. DATA MODEL (où vivent les tags, comment on les calcule)

**Principe directeur** : la data d'unité (`src/data/units.lua`) ne doit **rien éditer** dans le cas commun.
Les tags se **dérivent des ops** déjà présentes. Un override explicite reste possible pour les cas qu'aucune
op ne capture (lore-only whisper, direction).

### 3.1 — Le registre (généraliser `src/ui/keywords.lua`, NE PAS créer de doublon)

`keywords.lua` **devient** le registre de TAGS. On garde l'API actuelle (rétrocompat : `Keywords.afflictions`,
`Keywords.applied`, `Keywords.icon` restent) et on **ajoute** la couche tag :

```lua
-- src/ui/keywords.lua (ÉTENDU — pas un nouveau fichier)
Keywords.tags = {            -- [id] = { name, color, blurb, category, icon? }
  poison = { name="kw.poison.name", color=C.poison, blurb="kw.poison.blurb", category="affliction", icon="poison" },
  ...                        -- les 38 entrées de la §2
}
Keywords.categoryOrder = { "affliction", "defense", "offense", "structural", "direction", "newaxis", "type" }
Keywords.tag(id)             -- -> descripteur | nil
Keywords.tagName(id)         -- -> i18n(name) (fallback id:upper())
Keywords.tagBlurb(id)        -- -> i18n(blurb) (fallback "")
Keywords.tagColor(id)        -- -> Theme.c color | C.muted
```

Les `Keywords.afflictions` actuels deviennent une **vue** des entrées `category=="affliction"` (ou restent en
double table mince pointant le même descripteur). `Keywords.icon(id)` marche déjà via les grilles
`affliction_icons` ; pour un tag de type, `icon` renvoie nil et le rendu retombe sur le **pip** (cf. §5).

### 3.2 — Le mapping op→tags (le cœur « zéro édition de data »)

Un seul fichier de mapping, **pur** (testable headless), qui dit quels tags une op fait apparaître :

```lua
-- src/core/tags.lua  (PUR, zéro love.* — couche partageable, sous le firewall côté lecture)
-- Pourquoi src/core et pas src/ui : c'est de la DONNÉE mécanique (lue par tests, potentiellement par le log),
-- pas du rendu. keywords.lua (UI) consomme ce mapping pour composer les chips/glossaire.
local OP_TAGS = {
  poison        = { "poison" },                 -- + "weaken" si params.weaken>0, + "contagion" si params.spread (cf. dériveur)
  bleed         = { "bleed" },
  burn          = { "burn" },
  rot           = { "rot" },
  shock         = { "shock" },
  regen         = { "regen" },
  lifesteal     = { "heal" },
  heal_on_kill  = { "heal" },
  thorns        = { "thorns" },
  strip_shield  = { "strip_shield" },
  crit          = { "crit" },
  execute       = { "execute" },
  cleave        = { "cleave" },
  grant_vuln    = { "vulnerable" },
  convert_to_rot= { "conversion", "rot" },
  convert_dot   = { "conversion" },             -- + p.to (la famille cible) via dériveur
  spread_burn_on_death = { "propagation", "burn" },
  spread_rot    = { "propagation", "rot" },
  aura_stat     = {},                           -- dérivé du `params.stat` (cf. STAT_TAGS) + "aura"/"commander"
  grant_team    = {},                           -- dérivé des flags (markEnemiesVuln→vulnerable, shockChain→shock, …)
}
-- aura_stat : on réutilise EXACTEMENT le mapping kind de build.lua:1912 (source unique) :
local STAT_TAGS = { multicast="multicast", haste="haste",
  poisonInc="poison", burnInc="burn", bleedInc="bleed", rotInc="rot" }
  -- dmgReduce/atkInc → chips armor/empower (pas des tags de glossaire au lancement, cf. §2.4 note)
```

**Dériveur** `Tags.forEffect(e)` (params-sensible) : lit `e.op`, fusionne `OP_TAGS[e.op]`, puis ajoute les
tags conditionnels selon `e.params` (`weaken>0 → weaken`, `spread → contagion`, `convert_dot.to → famille`,
`aura_stat.stat → STAT_TAGS`, etc.). C'est la **seule** logique « intelligente » ; tout le reste est table.

### 3.3 — Tag-set complet d'une unité (union)

```lua
Tags.forUnit(U)  -- -> liste ORDONNÉE (catégorie puis ordre canonique), dédupliquée :
  -- 1. ∪ Tags.forEffect(e)            pour e ∈ U.effects
  -- 2. ∪ Tags.forEffect(U.commandBonus) + "commander"   si U.commandBonus
  -- 3. + tag de TYPE                   "type_"..U.type    (toujours présent)
  -- 4. + "taunt"                       si U.taunt
  -- 5. + "aura"                        si une de ses ops est une aura d'adjacence (combat_start aura_stat target=neighbors/role:*)
  -- 6. + tags directionnels            dérivés du `target` (role:front→ahead, …) — déclarés, partiellement inertes
  -- 7. + "whisper"                     si Whispers.has(U.id)  (registre murmures, quand il existera ; lore-only)
  -- 8. ∪ U.tags = {...}                OVERRIDE explicite (échappatoire pour ce qu'aucune op ne capture)
```

`Tags.forUnit` **remplace/élargit** `Keywords.applied` (qui ne voyait que les afflictions). On **garde**
`Keywords.applied` (rétrocompat `monstercard`/tests) en le ré-implémentant comme `filter(Tags.forUnit(U),
category=="affliction")`.

### 3.4 — i18n

Tout dans `src/i18n/en_ext.lua` (additif). Pour chaque tag : `kw.<id>.name` (CAPS court, ≤10 char marge i18n)
+ `kw.<id>.blurb` (≤ ~90 char, 1 ligne mécanique). Les 10 clés afflictions/role existent déjà. **~56 nouvelles
clés** (28 tags × name+blurb) à ajouter. Tout texte passe `i18n.t` ; fallback = `id:upper()` / `""`.

### 3.5 — Pourquoi ce découpage (firewall)

- `src/core/tags.lua` = **donnée mécanique pure** (zéro `love.*`) → testable headless, lisible par le log/wiki
  export plus tard. **Lit** `units`/ops mais ne **modifie rien** → golden intact.
- `src/ui/keywords.lua` = **présentation** (couleur, icône bakée, nom i18n) → consomme `tags.lua`.
- `monstercard.lua` + le nouveau popup = **rendu** → consomment `keywords.lua`.
- **Aucune ligne dans `src/combat`/`src/board`/`src/effects`** n'est touchée. Le mapping op→tag est une
  **lecture** parallèle, pas une dépendance de la sim.

---

## 4. COLORISATION DES MOTS-CLÉS DANS LE TEXTE

Objectif : dans une description (« Strikes **poison**: 2 dmg/s for 3s. Poison ignores **shields**. »), les mots
mécaniques apparaissent **colorés** dans la teinte de leur tag. Deux approches ; on **recommande le markup à
tokens** (déterministe, i18n-propre, pas de faux positifs).

### 4.1 — RECOMMANDÉ : markup à tokens dans l'i18n

Les chaînes i18n portent des **tokens** `[poison]`/`[shield]`/… que le renderer résout en mot coloré :

```
["unit.witch.passive_desc"] = "Its strikes [poison] the target: 2 dmg/s for 3s. [poison] ignores [shield]."
```

- Token `[id]` → on imprime le **nom localisé du tag** (ou un libellé inline donné) dans `Keywords.tagColor(id)`.
- Forme étendue `[id|texte affiché]` quand le mot dans la phrase ≠ le nom du tag (conjugaison, casse) :
  `[poison|poisons]`, `[shield|shields]`. Le renderer colore `texte affiché`, la mécanique pointée reste `id`.
- **Auteur unique** : c'est l'auteur i18n qui pose les tokens (contrôle total, zéro faux positif, traduisible :
  une autre langue place ses tokens où sa grammaire l'exige).

**Renderer** = généralisation de `monstercard.drawDescLine` (qui colore déjà les *valeurs*). Nouveau passe :
1. `parseTokens(line)` → liste de runs `{ text, color }` (texte hors-token = `baseCol` ; nombres = couleur de
   l'affliction primaire comme aujourd'hui ; `[token]` = couleur du tag).
2. dessin run-par-run à la `drawDescLine` (police LISIBLE de contenu, cf. ci-dessous), wrap mesuré AVANT dessin
   (`Font:getWrap` sur le texte **dé-tokenisé** pour ne pas casser le retour à la ligne).
3. la **1re occurrence** d'un tag à icône peut être préfixée de sa mini-icône 8×8 (comme `drawDescLine` le fait
   déjà pour l'affliction primaire) — option, à ne pas surcharger.

### 4.2 — Repli : post-pass de détection (NON retenu par défaut)

Scanner la ligne et colorer tout mot ∈ `{noms de tags}`. **Rejeté** au lancement : faux positifs (« shield »
dans une phrase qui ne parle pas du tag), fragile à l'i18n, casse-tête de casse/pluriel. On garde l'option en
réserve pour des textes legacy non-tokenisés (dégradation gracieuse : si aucun token, on rend la ligne unie
exactement comme aujourd'hui → **rétrocompat totale**, aucune description existante ne casse).

### 4.3 — Police (contrainte projet, NON négociable)

Le **corps** de description = police **lisible** (`Theme.body` Spectral, ou legacy `Theme.read` Pixel Operator
**≥12px**), **jamais Silkscreen** pour du texte courant (cf. `feedback-legible-font-for-content`). Les **noms
de tag** en CAPS courts peuvent être en `Theme.label` (Space Mono) **dans les chips/le glossaire** ; mais
**inline dans la prose**, on garde la police du corps (juste recolorée) pour ne pas hacher la lecture. La
couleur fait le travail, pas un changement de fonte au milieu d'une phrase.

---

## 5. LE GLOSSAIRE SHIFT — UX + MOCKUP ASCII

**Comportement.** Au survol d'une unité (fiche affichée), **tant que** `love.keyboard.isDown("lshift","rshift")`
est vrai, un **second panneau** apparaît **collé à droite** de la fiche, listant **tous les tags de l'unité
survolée**, groupés par catégorie, chacun = swatch coloré + nom + blurb 1-ligne. Relâcher Shift → il disparaît.
**Poll par-frame** (pas d'edge-tracking) : `love.keyboard.isDown(...)` renvoie vrai si l'un des deux Shift est
tenu *(API vérifiée 11.5 — cf. Sources)*. Un **hint** discret « ⇧ keywords » s'affiche en pied de fiche quand
Shift n'est pas tenu (découvrabilité).

**Ancrage.** `MonsterCard.draw` **retourne déjà** sa boîte `{x,y,w,h}`. Le popup se pose à
`x = box.x + box.w + GAP`. **Clamp écran** : si `x + Wglossary > Draw.W`, on bascule à **gauche** de la fiche
(`x = box.x - Wglossary - GAP`) ; si la fiche occupe déjà la gauche (curseur près du bord droit, fiche rebondie
à gauche), on superpose sous la fiche en dernier recours. `y = box.y` (aligné en haut), clampé `≥4` et
`y + h ≤ Draw.H`.

**Overflow.** Si la liste dépasse la hauteur dispo → **conteneur scrollable + clip** (`Draw.scissor` reconverti
via `view`, jamais de scissor écran brut), molette = offset clampé chaque frame, fade + thumb (cf.
`feedback-scrollable-containers`). **Jamais** de débordement de fenêtre.

**DA.** Même chrome que la fiche : `Panel.draw` (dégradé `stone800→stone900` + liseré `iron` + éclat haut),
titres de section via `Dividers.text` (label inscrit entre filets `iron`), chaque ligne = un **mini-chip**
`Chip.draw` (swatch icône/pip + nom coloré) suivi du blurb en `Theme.body` ink2. **Tout dessiné dans
`Draw.begin/finish`** (espace design ; jamais coords écran brutes — cf. `feedback-draw-transform-…`).

### 5.1 — Mockup ASCII (popup à DROITE de la fiche)

```
        ┌──────────────────────────┐   ┌──────────────────────────────────────┐
        │  THE FOUR-MAWED CREEPER ◆ │   │  KEYWORDS · THE FOUR-MAWED CREEPER    │  ← titre (Cinzel, ink)
        │ ┌──────────────────────┐  │   ├──────────  AFFLICTIONS  ─────────────┤  ← Dividers.text
        │ │      (portrait)      │  │   │ ▣ POISON   Stacking venom — DoT that  │  ← chip vert + blurb (Spectral ink2)
        │ │                      │  │   │            also weakens the victim's  │
        │ └──────────────────────┘  │   │            blows.                      │
        │  ● ELDER          ◆◆◆◆◆   │   │ ▣ CONTAGION  Spreads a weaker copy to │  ← chip (teinte rot)
        │ ─────── STATS ──────────  │   │              the target's neighbours. │
        │  HP 36   DMG 13   CD 1.2s │   │ ▣ WEAKEN   The victim deals reduced   │  ← chip (teinte poison)
        │ ────── ABILITIES ───────  │   │            damage (carried by venom). │
        │ [▣POISON 2dps·3s]         │   ├──────────  STRUCTURAL  ──────────────┤
        │  Lingering Venom          │   │ ⬗ COMMANDER  Rules from the pedestal: │  ← chip (laiton)
        │  Its strikes ▣poison the  │   │              an untargetable buff over│
        │  target: 2 dmg/s for 3s.  │   │              the whole pack.          │
        │  ▣Poison ignores ▢shield. │   │ ✦ AURA     A passive bonus radiating  │  ← chip (or)
        │ ─── AT COMMAND ─────────  │   │            to adjacent allies.        │
        │  All the pit's venoms     │   ├──────────    TYPE     ───────────────┤
        │  curdle the darker.       │   │ ✦ ARCANE   Flesh / Bone / Arcane /    │  ← pip arcane (étoile)
        │  ⇧ keywords               │   │            Abyss / Order — its nature.│
        └──────────────────────────┘   │  ░░░ scroll thumb if overflow ░░░     │  ← clip + thumb si trop long
         ^ la fiche existante           └──────────────────────────────────────┘
           (MonsterCard, inchangée)       ^ NOUVEAU panneau (le seul à coder)
                                            collé à box.x+box.w+GAP, clampé écran
```

Légende swatches : `▣` = chip à icône bakée (affliction), `⬗`/`✦`/`▢` = chip à pip/lettre (structurel/type/
défense sans grille 8×8). Les couleurs réelles sont celles du tag (§2). Inline dans la prose de la fiche, les
mots `▣poison`/`▢shield` sont les mots **colorés** (§4) — le glossaire ne fait que les **déplier**.

### 5.2 — Layout du panneau (espace design, échelle 8pt)

- `Wglossary ≈ 260` (un peu > fiche pour loger blurb 2-3 lignes ; composer à **70 %** marge i18n).
- `PAD 14`, interbloc `GAP 8`, air autour d'un titre de section `SECTION_GAP 12` (cohérent `monstercard`).
- Par tag : `chipH 16` + blurb wrap mesuré (`Font:getWrap(blurb, Wglossary - PAD*2)`), `lineH = bodyFont:h+2`.
- **Hauteur dérivée du contenu** (somme mesurée AVANT dessin) ; si > hauteur écran dispo → `Hglossary` clampée
  + ScrollView (clip+offset+thumb). Catégories vides masquées (pas de titre orphelin).
- Ordre des catégories = `Keywords.categoryOrder` (affliction → defense → offense → structural → direction →
  newaxis → type) : le squint test donne « ce que ce monstre FAIT » d'abord, sa « nature » en dernier.

### 5.3 — Juice & son (PLUS TARD, à l'implémentation — pas maintenant)

L'ouverture/fermeture du popup (fade/slide-in court, ease-out ≤150 ms) passe par **game-feel-engineer** ; un
**cue sonore** discret (grain de pierre / page de grimoire, pitché down) par **sound-designer**. **Co-invoqués**
dès qu'on implémente l'interaction (règle projet : « feedback = mouvement + son ensemble »). **Ici = spec** :
le panneau est défini statique ; on laisse les hooks (`open/close` events) prêts à brancher.

---

## 6. RÉPARTITION DU TRAVAIL (engine vs UI)

### 6.1 — love2d-engineer (data / mécanique, sous le firewall, golden-safe)

1. **`src/core/tags.lua`** (NOUVEAU, pur) : `OP_TAGS` + `STAT_TAGS` + `Tags.forEffect(e)` (params-sensible) +
   `Tags.forUnit(U)` (union ordonnée §3.3). Zéro `love.*`. Réutilise le mapping kind d'`aura_stat` de
   `build.lua:1912` comme **source unique** (extraire la table si besoin pour ne pas la dupliquer).
2. **i18n** (`src/i18n/en_ext.lua`) : ~56 clés `kw.<id>.name` + `kw.<id>.blurb` pour les 28 tags non encore
   présents (afflictions/role déjà là). Texte EN, ≤10 char pour les noms, blurb 1 ligne.
3. **Tests** (`tests/` — `headless` ou un `tags.lua` dédié) : `Tags.forUnit` déterministe + couverture
   (chaque op du roster mappe ≥1 tag ; chaque unité a ≥ son tag de type) + **toute clé `kw.*` traduite**
   (étendre le test de couverture i18n existant). **Golden 1176281181 doit rester identique** (lecture seule).
4. **(Optionnel, futur)** exposer `Tags.forUnit` au logger/export wiki (`tools/`) — hors scope lancement.

### 6.2 — ui-artisan (rendu — mon domaine, `src/ui/` + `src/render/monstercard.lua`)

1. **Étendre `src/ui/keywords.lua`** : table `Keywords.tags` (38 entrées §2) + `tag/tagName/tagBlurb/tagColor` +
   `categoryOrder` ; `Keywords.applied` ré-implémenté via `Tags.forUnit` filtré afflictions (rétrocompat).
   `Keywords.icon` étendu pour retomber sur le **pip** (type) quand pas de grille 8×8.
2. **Colorisation à tokens** : `parseTokens` + généraliser `monstercard.drawDescLine` pour résoudre `[id]` /
   `[id|texte]` en runs colorés (§4). Dégradation gracieuse (pas de token → ligne unie comme aujourd'hui).
3. **NOUVEAU composant glossaire** : `src/ui/tagglossary.lua` →
   `TagGlossary.draw(view, cardBox, unitId, t) -> box`. Panel + Dividers + lignes mini-chip + blurb, hauteur
   mesurée, **clamp écran** (droite→gauche→dessous), **ScrollView clip+thumb** si overflow. Tout dans
   `Draw.begin/finish`. Réutilise `Chip`, `Panel`, `Dividers`, `Keywords`.
4. **Branchement** dans `src/scenes/build.lua` : après `MonsterCard.draw` (qui retourne `box`), si
   `love.keyboard.isDown("lshift","rshift")` → `TagGlossary.draw(self.view, box, id, self.t/60)`. Ajouter le
   hint « ⇧ keywords » en pied de fiche (dans `monstercard` ou en surimpression build). **Tester au
   screenshot sur le PC de l'user** (« le PC de l'user fait foi ») avant de déclarer fait.
5. **`tests/ui.lua`** : smoke de `TagGlossary.draw` sous le mock LÖVE + logique pure de `parseTokens`
   (round-trip tokens → runs) + `Keywords.tag*`.
6. **Hooks juice/son** : laisser des points d'entrée open/close ; **co-inviter game-feel-engineer +
   sound-designer à l'implémentation** (pas au spec).

### 6.3 — Prototype d'abord (process §1)

Avant de généraliser : **prototyper le LOOK du glossaire en isolation** (écran-showcase / `gallery`, ou
directement sur une unité riche en tags comme `witch`/`plague_doctor`/`corruptor`), 2-3 variantes (densité,
icône-vs-pip, hauteur de blurb), **valider au screenshot par Kévin**, PUIS brancher. On ne câble pas un système
sur un look non validé.

---

## 7. CONTRAINTES & DÉFINITION DE « FAIT »

- **Golden 1176281181 tient** (RENDER + data-additif ; `src/combat`/`src/board`/`src/effects` lus, pas touchés).
- **Tout dans `Draw.begin/finish`** (espace design 1280×720) ; jamais de coords écran brutes ; texte/sprite
  nearest + positions planchées.
- **Police lisible** pour le contenu (Spectral/Pixel Operator ≥12px) ; Space Mono CAPS courts pour les noms de
  tag dans chips/glossaire uniquement ; **pas Silkscreen** pour la prose.
- **Scrollable + clippé** sur overflow ; **jamais** de débordement fenêtre.
- **i18n** pour tout texte (`kw.*` dans `en_ext.lua`) ; composer à 70 % (marge i18n 30 %) ; mesurer
  (`Font:getWrap`) avant de dessiner.
- **Couleurs = palette existante** (`Theme.c`/`Theme.types`) — 0 hex inventé ; tag = teinte VFX de la
  mécanique (cohérence combat ↔ fiche ↔ glossaire « même artiste »).
- `sh tools/check.sh` **VERT** + **luacheck-clean** (zéro global, `local` partout, un module = une table).
- **Validé par Kévin en jeu** (screenshot sur son PC), juice + son ajoutés à l'implémentation
  (game-feel-engineer + sound-designer co-invoqués).

---

## 8. SOURCES (API vérifiées — règle d'or §1.a)

- **LÖVE `love.keyboard.isDown`** — `anyDown = love.keyboard.isDown(key1, key2, …)`, **vrai si l'une** des
  touches est tenue ; constantes Shift = `"lshift"` / `"rshift"`. Permet le poll par-frame du glossaire en un
  appel. <https://love2d.org/wiki/love.keyboard.isDown> · <https://love2d.org/wiki/KeyConstant> (cible 11.5).
- Architecture interne vérifiée par lecture des sources du dépôt (§1) : `keywords.lua`, `chip.lua`, `theme.lua`,
  `monstercard.lua`, `build.lua` (drawTooltip/dispatch/aura_stat→kind), `affliction_icons.lua`, `ops.lua`,
  `arena_draw.lua` (`CAUSE_COL`), `en_ext.lua`.
