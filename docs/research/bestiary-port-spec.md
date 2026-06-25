# Bestiary Port Spec — 102-créature roster + combat animations

> **Statut** : SPEC DE PORT (read-only analysis). Pilote l'implémentation **Phase B**.
> **Source autoritaire visuelle** : `docs/generation/generateur-bestiaire.html` (959 l, le NOUVEAU
> générateur). **Index** : `docs/generation/bestiary-dictionary.json` (41 familles / 102 formes).
> **Port actuel (version ANTÉRIEURE du même générateur)** : `src/gen/primgen.lua` (2651 l),
> `src/gen/creaturegen.lua` (1113 l), `src/render/critter.lua` (278 l, idle déjà porté),
> `src/data/units.lua` (83 unités).
> **Golden SIM à préserver** : `1176281181` (`tests/golden.lua`). Tout ici est RENDER/data ;
> seul le champ `rank` (re-tier) touche la SIM, et il est **gated** (cf. §6).
>
> **Vérifié vs supposé** : tout ce qui concerne les fonctions/coords du HTML et du Lua a été LU
> (cité par n° de ligne). `SpriteBatch:setColor` (per-sprite multiply, 0..1 floats, LÖVE ≥11.0)
> vérifié sur love2d.org (cf. Sources). Les *propositions* de re-tier/réconciliation sont marquées
> **[PROPOSÉ]** et les conflits **[CONFLIT]**.

---

## 0. TL;DR (décisions et chiffres clés)

- **Le nouveau générateur EST compatible avec l'API `cachedLive`** (family + hash→arch/palette).
  Mêmes primitives, même anatomie `A`, mêmes signatures `aXxx(g,rnd,p)->A`, même `treat`, même
  `outline`. Le port se fait **par ajout d'archétypes/familles dans les tables `FAMILIES`/`ARCH`** de
  `primgen.lua`, sans toucher la mécanique de résolution.
- **Gap roster** : le Lua a **88 archétypes** mais une version **antérieure**. Il manque **10 builders**
  pour atteindre 102 : les 6 pièces ELDER (`aVoidTyrant`, `aGrubElder`=devourer, `aSkullTitan`,
  `aJuggernaut`, `aVeiledKing`, `aBroodmother`) + les 4 variantes cocon (`aCocoonBrood/Bile/Chrysalis/Ember`).
  Le HTML les fournit clé en main.
- **Gap animations** : `critter.lua` porte **l'idle per-pixel** (`disp`: bob/breathe/sway/legs/flap/
  tentacles/writhe + yeux). Il **manque** les 3 couches de réaction du HTML : **atk** (`atkDisp`+`atkFx`,
  ~18 kinds), **hurt** (`hurtDisp`, 8 kinds), **death** (`deathPix`+`deathFx`, 7 kinds). **C'est LA valeur
  ajoutée** de ce port.
- **Golden-safety — LE PIÈGE #1** : `cachedLive` dérive l'archétype par
  `bucket(hashId("arch."..id), nArch)`. **Augmenter `nArch` d'une famille REBIND tous ses sprites**
  (les unités existantes changeraient de forme et de pixel). Les nouveaux builders ELDER/cocon **doivent
  s'ajouter en GARDANT inchangé `nArch` des familles déjà peuplées par des unités** (cf. §3.3, §6) — sinon
  on casse `tests/gen.lua` (distinction) et le visuel des 83 unités. Le golden **SIM** lui ne bouge pas
  (firewall RENDER), mais le golden **de génération** (déterminisme `tests/gen.lua`) si.
- **Ordre de port** : (1) **animations sur `critter.lua`** d'abord — isolable, validable en galerie,
  zéro impact data/SIM ; (2) **builders manquants + familles ELDER** ensuite, append-only ; (3) **re-tier
  par imposance** en dernier, gated derrière le tier-gating boutique.

---

## 1. Architecture du nouveau générateur (HTML)

### 1.1 Pipeline (identique au port actuel — confirmé)

```
buildGrid(opts):
  rng = mulberry32(seed)              -- (Lua: love.math.newRandomGenerator)
  p   = fam.pals[paletteIndex]        -- palette hex de la famille
  A   = ARCHMAP[arch](g, rnd, p)      -- DESSINE la grille + DÉCLARE l'anatomie A
  fam.treat(g, rnd, p, A)             -- corruption ANCRÉE sur A (jamais flottante)
  outline(g, p.out)                   -- edge-detect 4-voisins -> contour
  -> g (grille hex packée), A, p
```

La grille est un buffer plat `data[y*w+x] = couleurHex|null`, `w=h=64`, plus `eyes:[[x,y,r],…]`
(rempli par `eye()`). Le rendu (`blit`) re-dessine cette grille **par pixel** chaque frame avec un champ
de déplacement (cf. §2). En Lua, `Primgen.generate` bake la grille en `Image` (board/grimoire) et
`Primgen.live` retourne la grille brute pour `critter.lua` (rendu vivant). **Même séquence RNG → même
créature** des deux côtés.

### 1.2 Primitives de construction (HTML l.61-130)

| Catégorie | Primitives | Note |
|---|---|---|
| Base raster | `set`, `ellipse`, `disc`, `line`, `polygon`, `rect` | `disc` a un biais `+r*0.5` (rondeur) |
| Volumes | `mass` (4 bandes + dither hi), `blob` (mou + bumps RNG + reflet os), `tube` (pts→épaisseur var.), `segChain` | `mass`/`blob` = le "gros volume" |
| Membres | `tentacle`, `radTentacle`, `thinBone`, `thinSpineRibs`, `antler`, `bigWing`, `featherWing`, `pincer` | fins, miroitables |
| Détails | `eye` (sclère/iris/pupille + **push dans g.eyes**), `maw`, `growth`, `rstreak`, `mushroomCap`, `crystal`, `ghostBody`, `ringMaw`, `miniBug`, `skullThin`, `skullThin`, `jellyBell`, `halo`, `shield`, `dagger` | `eye` alimente l'overlay animé |
| Dither | `ditherRing` (anneau 1-px sur 2 entre 2 ellipses) | bandes douces |

Le port Lua a **déjà toutes ces primitives** (`primgen.lua` l.61-475 : `mass`, `blob`, `skull`,
`crystal`, `halo`, `featherWing`, `antler`, `jellyBell`, `skullThin`, `pincer`, `bigWing`…). Aucune
primitive nouvelle requise pour atteindre 102.

### 1.3 Anatomie `A` (le contrat structurel)

Chaque builder retourne une table `A` décrivant la structure pour (a) le `treat` (ancrage des détails),
(b) le rendu (`mass[0]` = centre/rayon de respiration, `belly`, `float`) et (c) **les animations**
(`head`, `faceDir`, `mass`, `belly` lus par tous les dispatchers). Champs :

```
A = {
  head    = {x, y, r},          -- tête : pivot de bite/cast/spew/gaze/smite, recoil hurt
  faceDir = [dx, dy],           -- direction d'attaque (lunge/claw/lash/phase…). Défaut [0,-1] = haut
  spine   = [[x,y]…],           -- segments (treatDemon pose des épines dessus)
  limbs   = [[x,y]…],           -- pattes/extrémités (treats divers, treatHung)
  belly   = {x, y},             -- ancre basse (lash, tentacles, drips)
  mass    = [[cx,cy,r]…],       -- volumes : mass[0] = corps principal (breathe/clench/death radial)
  tailBase= {x,y}|null,
  flesh   = bool,               -- pilote treatUndead (trous), DEATH gib vs disintegrate variantes
  float   = bool,               -- pose au sol décollée -> ombre laissée en bas (lévitation)
  halo    = bool,               -- (familles ordre) treatCorrupt dessine l'auréole fêlée
}
```

Le port Lua reproduit ce contrat **à l'identique** (cf. tous les `return { head=…, mass=… }` dans
`primgen.lua`). **Important** : les coords de `A.head`/`A.mass` sont **calées sur le dessin** de chaque
builder — c'est pourquoi les *attaques* `multi`/`engulf` (qui ciblent des coords précises) sont liées à
l'archétype (cf. §2.4).

### 1.4 Structure famille → archétype → forme

`FAMILIES` (HTML l.576-618) = liste ordonnée de 41 entrées :
`{key, name, sub, accent, archs:[formNames], pals:PALETTE[], treat}`. Le Lua (`primgen.lua` l.2321-2415)
a la **même table** (clé→`{pals, treat, archs:[{name,fn}]}`) + `FAMILY_ORDER` (ordre stable). Une forme =
1 nom dans `archs` → 1 builder dans `ARCHMAP`/`ARCH`.

- **41 familles**, **102 formes** (dictionnaire). Tailles d'`archs` : 1 (hydre, kraken, chimere) à 4
  (cocon). `cocon` a **4 formes** (broodsac/bilesac/chrysalis/embersac) — la plus large.
- **5 aliases HTML hors-dictionnaire** dans `ARCHMAP` (107 clés) : `centaur`, `carrionflyer`, `howler`,
  `troll`, `cocoon`. Non listés dans les 102 ; ce sont des builders legacy (le Lua garde `aCentaur` et
  `aCocoon` ; ignorer `troll/carrionflyer/howler` sauf besoin de remplissage).

### 1.5 Palettes (HTML l.481-575)

~41 tables de palettes (1 par famille, souvent 3-5 variantes). Chaque variante :
`{deep, sh, base, hi, bone, eye, eyeDim, out (+scar/wound pour BEAST)}`. La famille pointe une liste
`pals` ; `paletteIndex` = `bucket(hashId("palette."..id), #pals)`. Le Lua a **toutes les palettes**
(`primgen.lua` l. ~30-130, mêmes noms `ELDRITCH/UNDEAD/BEAST/…/AUTOMATON`). La **famille = identité
chromatique** (cf. CLAUDE.md axe Famille). Re-vérifier au port que le Lua ELDER (SHADOW/SKULL/AUTOMATON/
SPECTRE/SPIDER/GRUB/COCOON) a bien la même variante d'index que le HTML pour la pièce maîtresse.

### 1.6 Yeux (HTML l.75, l.110)

`eye(g,x,y,r,p)` dessine l'œil ET pousse `[x,y,r]` dans `g.eyes`. Au rendu, `blit` redessine chaque œil
**par-dessus** la grille déplacée, avec **clignement** (`sin(t*blink+phase)>0.93` → carré sombre) et
**saccade de pupille** (`dart`, offset ±1px). `critter.lua` (l.199-220) **porte déjà** ce comportement.
**Subtilité animation** (l.110) : pendant la mort (`_death.ph>0.3`), les yeux **cessent d'être dessinés**
(le corps se désagrège) — à porter.

---

## 2. Système d'animations — LE CŒUR DU PORT

### 2.0 Comment `gl()`/`disp` composent idle + atk/hurt/death

Le rendu (`blit`, HTML l.83-111) calcule pour CHAQUE pixel `(x,y)` un déplacement `(dx,dy)` via
`disp(x,y)` puis dessine `fillRect((x+dx)*scale, (y+dy)*scale)`. `disp` **somme** les canaux actifs du
profil :

```
disp(x,y) =  Σ idle-channels (bob, breathe, sway, legs, flap, tentacles, writhe)
           + atkDisp(prof._atk,  …)   si une attaque est en cours
           + hurtDisp(prof._hurt, …)  si touché
           (+ deathPix(prof._death,…) appliqué SÉPARÉMENT dans la boucle de blit,
              car il retourne AUSSI un alpha [dx,dy,a])
```

Puis, **après** la boucle de pixels, deux overlays one-shot dessinent des particules :
`atkFx(ctx,…)` (éclat d'arme/projectile) et `deathFx(ctx,…)` (gerbe de sang/ichor/éclats). Les yeux sont
dessinés en dernier. **Le `gl()` cité (l.289) n'est PAS un système d'anim** : c'est un helper local
"glyph line" (trace une rune lumineuse en pointillé eye/eyeDim) DANS un builder ELDER (veiledking/
grubelder). Ne pas confondre avec le pipeline d'anim.

**Constantes de timing du driver** (HTML l.930) — à reprendre en Lua :
`IDLE_DUR=1.3s`, `ATK_DUR=1.05s`, `HURT_DUR=0.45s`, `DEATH_DUR=1.2s`, `DEAD_HOLD=0.7s`. La phase `ph`
passée aux dispatchers ∈ [0,1] (progress de l'évènement). Priorité : **death > hurt > atk > idle** (un
mort n'attaque plus ; un touché interrompt l'attaque — HTML l.932-940).

### 2.1 Enveloppes temporelles partagées (HTML l.717-722, l.832)

```
_sstep(a,b,x)  = smoothstep         (cubique)
_smoo(a,b,x)   = smootherstep       (quintique)
_env(ph)       = [windup, strike]   windup = _sstep(0,0.24)-_sstep(0.24,0.40)   (anticipation brève)
                                     strike = _smoo(0.30,0.44)-_smoo(0.66,0.92) (frappe + retour)
_dscale(x,y,cx,cy,fd,s) = scale anisotrope le long de faceDir (squash&stretch directionnel)
_nrm(v), _h2(x,y) = normalize / hash-bruit déterministe (cohérent par pixel)
_dprog(ph)     = _smoo(0.12,0.82) (progression de désintégration)
```

`atkDisp` lit `wu=windup`, `st=strike` : l'unité **recule un peu (wu) puis jaillit (st)** vers `faceDir`.
Tous portables tels quels (Lua a `math` ; `_h2` = fract(sin·43758.5453), reproductible bit-à-bit en
double IEEE → **snapshot-safe**, comme `bucket`).

### 2.2 `atkDisp` — déplacement d'attaque (HTML l.723-746). Entrées : `(atk, x,y, cx,cy, bellyY, groundY, headSpan, A)`

`atk = {k, pr, ph}` (kind, params, phase). `reach` (défaut 8), `pull` (défaut 3) viennent de `pr`.
**18 kinds** (le dictionnaire `attaque` mappe chaque forme à un kind via `ATK`, HTML l.769-811) :

| kind | enveloppe / effet (résumé) | qui (familles/formes) |
|---|---|---|
| **lunge** | recule (wu·pull) puis bondit en avant (st·reach) + cisaille latérale + squash dir. | slime/ooze/blobmonster, sentinelshield, cutpurse, mantisshrimp, stag, **broodmother** |
| **pounce** | comme lunge mais saute (`-leap`, accroupit `crouch`) : arc vertical | skeletonquad, behemoth, direcat, wolf/hound/jackal, gryphon/hippogriff, centaur |
| **bite** | déformation **locale à la tête** (`f=1-dist/(head.r+8)`) : la gueule happe | bouffi/fleshcrawler, dragon, serpent, insectoid, anglerfish/moray, graboid/leech, coilserpent/cobra/lizard, ratgiant, strider/heron, hydra, maweed, grub, skullking, **devourer** |
| **swing** | bras pivote autour de `(cx, bellyY+1)` avec **lag vertical** (le haut suit) | skeleton, crusader, paladin |
| **claw** | balaie horizontal pondéré par hauteur (`hf²`), légère montée | revenant, fiend, imp, mantis, deepone, harpy, troll, crab, cutthroat/brigand, wendigo |
| **lash** | seul le **bas** (sous belly) fouette en avant, par vague (lag `f*0.16`) | octopus/squid/reef, possessed, jelly/siphon, kraken, vinemaw, **voidtyrant**, chrysalis |
| **cast** | le **haut** se penche en arrière (incantation) ; FX = projectile | idol, cultist/hierophant, automaton, **veiledking** |
| **smite** | tout monte (`-st·4.5`) ; FX = colonne de lumière du ciel | inquisitor/confessor, seraph/throne, reliquary |
| **shard** | pulse radial léger (`(x-cx)*s`) ; FX = éclats projetés en éventail | sentinel, crystalcluster/shardwalker/prism |
| **slam** | la **masse haute** s'écrase (`-wu·7 +st·10`, `hf²`) ; FX = onde de sol | golem, ogre/cyclops, **juggernaut** |
| **surge** | explose vers l'extérieur + ruée `faceDir` + bruit `_h2` (essaim qui gicle) | swarm/hive, ratking |
| **wing** | les **bords** (>bR·0.85) battent (`-wu+st`) + ruée avant ; FX = traînées | byakhee, carrionflyer |
| **engulf** | pixels **aspirés vers `pr.mouth`** (`wu·4 -st·6`) puis avalés ; FX = anneau qui se ferme | broodsac, voidmaw (`mouth=[32,38]`) |
| **spew** | léger pulse + jet à la tête ; FX = nuage de 16 particules en cône | sporewalker/myconid/infectedhost, bilesac, cocoon |
| **gaze** | quasi-statique (`s=st·0.06`) ; FX = rayon depuis la tête | eyeball/eyecluster/eyeswarm, **skulltitan** |
| **phase** | ruée `faceDir` + **ondulation spectrale** (`sin(ph·9+y·0.3)`) | wraith/veiledlady/howler, shade, marionette/hanged |
| **multi** | **N sous-attaques** déphasées (`parts:[{x,y,r,fd,mode,reach,off}]`) : chaque tête/membre mord/balaie indépendamment | **chimera** (5 parts), **embersac** |
| **skitter** | rotation+pulsation radiale des **pattes** (`lf=_sstep(5,11,rayon)` : seules les extrémités), vibration `freq:11` | spider, widow |

**Note multi (HTML l.805)** : `ATK.chimera.parts` = 5 coords **calées sur le dessin** du builder
(2 mâchoires latérales, 1 tête haute, 2 griffes). **embersac** = `{k:'multi'}` (params dans son `ATK`).
→ Au port, `aChimera`/`aCocoonEmber` doivent garder ces coords cohérentes avec leur dessin (sinon les
sous-attaques tapent dans le vide).

### 2.3 `atkFx` — overlay de particules d'attaque (HTML l.747-768)

Fenêtre `sp=_sstep(0.30,0.62,ph)` (n'apparaît qu'à la frappe), `fade=1-_sstep(0.66,0.90)`. Couleurs :
`col=pr.fx||glow||p.eye`, `hot=p.bone`. Dessine des **blocs** (pas de la grille — overlay pur) :
- `cast` : projectile qui file vers `faceDir` (3 blocs en traînée + muzzle).
- `spew` : 16 particules en cône (jet de spores/bile).
- `swing`/`claw` : 1 (ou 4 pour claw) arcs de 9 blocs.
- `slam` : anneau de poussière au sol (rayon `sp·26`).
- `smite` : colonne verticale pointillée du haut de l'écran jusqu'à la tête + halo.
- `gaze` : rayon plein tête→avant (2 épaisseurs).
- `shard` : éventail de 10 éclats.
- `wing` : 6 traînées de plumes.
- `engulf` : anneau de 12 blocs qui **converge** (`r0=22·(1-sp)`).
- `surge` : 14 blocs giclant en cône.
- `multi` : pour chaque part déphasée, 4 blocs au bout.
- `lunge/pounce/bite` (fallback, `sp>0.2`) : 7 éclats d'impact à la tête.
- `skitter` : 5 poussières aléatoires autour des pattes.

### 2.4 `hurtDisp` — réaction aux dégâts (HTML l.817-829). `h={k,ph}`, **MOUVEMENT SEUL** (le HTML n'ajoute aucune teinte)

Décroissance `hit=exp(-ph·4.5)·(1-_sstep(0,0.95,ph))` (secousse amortie ~0.45 s). **8 kinds** (mappés par
**famille** via `HURT`, HTML l.880-888) :

| kind | effet | familles |
|---|---|---|
| **recoil** | recul opposé à `faceDir` (pondéré hauteur) + tremblement | mortvivant, bete, demon, culte, spore, colosse, templier, inquisiteur, bandit, canide, rongeur, echassier, wendigo, pendu, chimere |
| **jelly** | wobble élastique amorti (`_dscale` sur axe Y + cisaille) | gelatine, cocon, larve |
| **clench** | tous les pixels se **contractent vers le centre** (`f2` en couronne) | cephalo, abyssal, meduse, kraken |
| **jolt** | saccade haute fréquence (`cos(ph·26)`) le long de faceDir | insecte, golem, cristal, arachnide, crustace, crane, automate |
| **flinchfly** | les **ailes** (>bR·0.8) battent en panique + tout tombe (`+3·hit`) | aile, seraphin, griffon |
| **kink** | l'**onde** parcourt le corps (`sin(y·0.5-ph·12)`) — vers/reptiles | annelide, reptile, hydre, plante |
| **waver** | scintillement spectral (recul + ondulation, pondéré hauteur) | cauchemar, spectre, ombre |
| **scatter** | les pixels **se dispersent** brièvement dans des directions hash | essaim |

**[CONFLIT avec le port actuel]** : `BODY_ANIM.hurt` de `primgen.lua` (l.2631) ajoute un **flash
rougeâtre** (`tint={1,1-f*0.45,1-f*0.6}`). Le HTML hurt est **mouvement pur, sans teinte** (commentaire
explicite l.816). **[PROPOSÉ]** : au port sur `critter.lua`, suivre le HTML (mouvement seul) — le feedback
de dégâts couleur est déjà porté par le système d'afflictions VFX (cf. memory `affliction-vfx`). Garder un
flash optionnel léger seulement si le créateur le veut à l'écran.

### 2.5 `deathPix` — désagrégation du corps (HTML l.833-860). Retourne `[dx, dy, alpha]`

3 phases : `react` (sursaut `_sstep(0,0.16)`), `frag` (fragmentation `_sstep(0.24,0.74)`), fondu
(`a=1-_sstep(…)`). Chaque pixel part radialement (`ux,uy` depuis le centre) + bruit `_h2` + gravité
(`frag²·g`). **7 kinds** (mappés par **famille** via `DEATH`, HTML l.889-897) :

| kind | signature | familles |
|---|---|---|
| **gib** (défaut) | explosion radiale + retombée gravité | mortvivant, bete, demon, insecte, culte, aile, colosse, templier, inquisiteur, seraphin, griffon, bandit, canide, rongeur, arachnide, crustace, echassier, wendigo, pendu, chimere, plante |
| **disintegrate** | **monte** et s'évapore (`-ri·15`, fondu précoce) — spectral | cauchemar, spectre, ombre, essaim |
| **shatter** | éclats minéraux projetés loin (`7+sc·12`) + gravité | cristal |
| **crumble** | s'effondre vers le bas (gravité dominante `frag²·13`) | golem, crane, automate |
| **unravel** | **se dévide** (onde `exp(-ph·3)·sin`) puis fragmente — vers | annelide, reptile, hydre |
| **splatter** | gicle mou (wobble `_dscale` + retombée) — gélatineux/spores | gelatine, spore, cocon, larve |
| **burstLimp** | **s'affaisse** (`sink`) puis éclate mou — chair molle aquatique | cephalo, abyssal, meduse, kraken |

### 2.6 `deathFx` — gerbe de mort (HTML l.861-878)

Fenêtre `emit=_sstep(0.24,0.6)`, `fade=1-_sstep(0.62,0.92)`, `blast=emit·fade`. Couleurs :
`blood='#7d1426'`, `dark='#34060f'`, `ich=p.eye` (ichor), `base/hi=p.base/p.hi`.
- `gib`/`unravel`/`burstLimp` : 13 éclats sang+ichor + gravité.
- `splatter` : 13 éclats `base/hi` (matière, pas sang).
- `shatter`/`crumble` : 11 éclats clairs (poussière/cristal).
- `disintegrate` : 11 motes qui **montent** (`-_dprog·18`) — âme qui s'échappe.

### 2.7 Rendu : comment porter ça sur `critter.lua` (LÖVE)

`critter.lua` dessine déjà la grille dans un **SpriteBatch** (`pixel()` 1×1 + `setColor` par cellule,
**vérifié** : per-sprite multiply, 0..1 floats, LÖVE ≥11.0). Le port des 3 couches :

1. **atkDisp/hurtDisp/deathPix** → s'ajoutent **dans `makeDisp`/`fillBatch`** : pour chaque cellule, on
   somme le dx,dy idle + (si actif) le dx,dy d'attaque/hurt/mort. Pour la **mort**, l'alpha par cellule
   se multiplie via `b:setColor(r,g,b, alphaDeath)` (le batch supporte l'alpha par sprite — vérifié).
2. **atkFx/deathFx** → overlays one-shot **après** `love.graphics.draw(batch)` dans `paint`, en
   `love.graphics.rectangle("fill", …)` (espace grille, déjà sous le transform). Couleurs = palette `p`
   déjà extraite dans `info()` (ajouter `boneCol`, `baseCol`, `hiCol` au cache).
3. **Yeux** : suppression pendant `_death.ph>0.3` (garde déjà l'overlay, ajouter la condition).
4. **État d'anim** : `critter.lua` est *stateless* (dessine à `t`). Le caller (combat/galerie) doit passer
   un **descripteur d'évènement** : `opts.atk={k,pr,ph}`, `opts.hurt={k,ph}`, `opts.death={k,ph}`.
   Les `k` (kind) viennent de tables portées depuis le HTML : `ATK[form]`, `HURT[family]`, `DEATH[family]`
   — à ajouter dans `critter.lua` (ou mieux, dans `primgen.lua` à côté de `MOTION`, exposées). La **forme**
   (`primArch`) et la **famille** (`primFamily`) sont déjà dans la `def` (`primgen.lua` l.2647) et
   résolues par `cachedLive`.

> **API LÖVE** (toutes vérifiées sur love2d.org/wiki, cf. memory tech-stack) : `SpriteBatch:setColor`
> (per-sprite, 0..1), `SpriteBatch:add`, `love.graphics.draw(batch)`, `love.graphics.rectangle`,
> `love.graphics.push/translate/scale/pop`, `love.timer.getTime()` pour l'horloge `t` (secondes).
> Aucune API nouvelle hors de ce qui est déjà utilisé.

---

## 3. GAP : nouveau générateur vs Lua actuel

### 3.1 `primgen.lua` (archétypes/anatomie) — **88 builders présents, 10 manquants**

**Présents et à jour** (la plupart des 41 familles ont leurs formes). Vérifié : `aGolem`, `aSentinel`,
`aIdol`, `aDragon`, `aChimera`, `aKraken`, `aHydra`, `aOctopus`, etc. — anatomie `A` conforme.

**MANQUANTS (à ajouter depuis le HTML)** — les 10 builders pour atteindre 102 :

| Builder HTML | Forme (dict) | Famille | imp | atk kind | Note de port |
|---|---|---|---|---|---|
| `aVoidTyrant` | voidtyrant | ombre | 10 | lash | silhouette noire massive, yeux flottants |
| `aGrubElder` | **devourer** | larve | 10 | bite | (alias : ARCHMAP `devourer:aGrubElder`) gueule colossale |
| `aSkullTitan` | skulltitan | crane | 10 | gaze | crâne titanesque, orbites-rayon |
| `aJuggernaut` | juggernaut | automate | 10 | slam | carcasse mécanique lourde |
| `aVeiledKing` | veiledking | spectre | 10 | cast | roi voilé, runes `gl()` |
| `aBroodmother` | broodmother | arachnide | 10 | lunge | abdomen+pattes, œufs |
| `aCocoonBrood` | broodsac | cocon | 3 | engulf | (le Lua n'a qu'`aCocoon` générique) |
| `aCocoonBile` | bilesac | cocon | 5 | spew | |
| `aCocoonChrysalis` | chrysalis | cocon | 7 | lash | |
| `aCocoonEmber` | embersac | cocon | 9 | multi | parts hand-tuned |

**Builders legacy divergents dans le Lua** (à NE PAS supprimer — utilisés par les familles peuplées ;
mais à RÉCONCILIER avec les noms canon) : `aTisserand` (≈ widow ?), `aBrute` (≈ behemoth/ogre ?),
`aHellhound` (≈ hound ?), `aSwarmflyer` (≈ carrionflyer ?). **[PROPOSÉ]** : au port, **mapper les noms
canon du dictionnaire** dans `FAMILIES.archs[].name` et router vers le builder Lua existant si visuellement
équivalent, OU adopter le builder HTML canonique. Le **nom de forme dans `archs`** est ce que
`Primgen.archName` expose ; le **builder** est libre tant que la séquence RNG est stable.

### 3.2 `critter.lua` (rendu vivant) — idle OK, réactions absentes

| Couche | HTML | `critter.lua` | À faire |
|---|---|---|---|
| idle `disp` (7 canaux) | l.91-98 | **PORTÉ** (`makeDisp` l.77-107) | rien |
| yeux (blink+dart) | l.110 | **PORTÉ** (l.199-220) | + couper pendant death (`ph>0.3`) |
| `atkDisp` (18 kinds) | l.723-746 | **ABSENT** | porter + table `ATK[form]` |
| `atkFx` (overlays) | l.747-768 | **ABSENT** | porter (rectangles overlay) |
| `hurtDisp` (8 kinds) | l.817-829 | **ABSENT** | porter + table `HURT[family]` |
| `deathPix` (7 kinds) | l.833-860 | **ABSENT** | porter (alpha par cellule via batch) |
| `deathFx` (overlays) | l.861-878 | **ABSENT** | porter |
| profils idle | l.673-715 (`PROF`) | **PORTÉ** (`PROF` l.26-74) | rien (déjà aligné famille→amp/freq) |

> **Note** : `primgen.lua` a un *autre* système d'anim (`BODY_ANIM` idle/attack/hurt, affine
> sprite-entier squash/stretch, l.2613-2636) utilisé par le **rig baké** (board/combat actuels via
> `Rig`). Le port "vivant" (`critter.lua`) est la voie supérieure (per-pixel) ; `BODY_ANIM` reste le
> fallback baké. **[PROPOSÉ]** : basculer combat/galerie sur `critter.lua` + ses réactions (cf. memory
> `combat-animations-chantier`, plan déjà validé pour attack/hurt/death par champ de déplacement).

### 3.3 Compatibilité `cachedLive` — **OUI, mais avec une garde golden critique**

`cachedLive` (`creaturegen.lua` l.1093-1111) :
```
fam       = opts.family or deriveFamily(type, effects, id)   -- les 83 unités ont family= explicite
nArch,nPal= Primgen.familyShape(fam)                         -- = #archs, #pals de la famille
archIndex = bucket(hashId("arch."..id),  nArch)              -- PHI-hash -> index dans archs
palIndex  = bucket(hashId("palette."..id), nPal)
-> Primgen.live{family, archIndex, paletteIndex, seed=hashId(id)}
```

Le nouveau générateur respecte **exactement** cette API : `Primgen.familyShape`, `Primgen.archName`,
`Primgen.live`, `Primgen.def`, `Primgen.WORLD_FIT` inchangés. **MAIS** :

> ⚠️ **`archIndex` dépend de `nArch`.** Si on **ajoute une forme** à une famille déjà référencée par des
> unités (ex. `arachnide` passe de 2→3 archs avec `broodmother`, `larve` 1→2 avec `devourer`, `cocon`
> 1→4, `ombre` 2→3, `crane` 1→2, `automate` 2→3, `spectre` 2→3), **TOUS les `bucket(...,nArch)` changent**
> → les unités de ces familles **changent de sprite** (web_recluse, rot_grub, pit_maw, marrow_drinker,
> skull_colossus, rust_sentinel, wailing_shade… cf. table §4). Ce **ne casse PAS le golden SIM** (firewall :
> la SIM ne lit jamais le sprite) mais **change le visuel** et casse `tests/gen.lua` (déterminisme/
> distinction si les goldens de gén sont figés).

**[PROPOSÉ] — 2 options, golden-safe** :
- **(A) Append-only par famille NEUVE** : créer les ELDER comme nouvelles entrées de `archs` **en queue**
  (`broodmother` en archs[3] de arachnide). Comme `bucket` lit l'id, append ne préserve PAS l'index (PHI
  re-répartit sur nArch+1). → **insuffisant seul.**
- **(B) Pin par unité (recommandé)** : ajouter un champ optionnel **`archIndex`/`arch` explicite** sur les
  unités existantes (ou un override `opts.archIndex` dérivé d'un mapping `id→formName` stable), de sorte
  que **les 83 unités gardent leur forme actuelle** quel que soit `nArch`. Les nouvelles formes ELDER ne
  sont alors atteignables **que** via des unités NEUVES (ou des rangs R5 dédiés) — cohérent avec
  "chimère/ELDER = R5". C'est l'approche déjà actée pour le **family-rebinding** (memory : 83/83 ont
  `family=`, sprites verrouillés golden-neutre). **Étendre la même logique à l'archetype.**

---

## 4. Réconciliation 83 → 102 (unité in-game → forme du roster)

> Les 83 unités de `units.lua` portent `family=` (1:1 avec les 41 familles du dictionnaire — vérifié,
> couverture complète) mais **PAS** de forme : la forme est **dérivée par hash**. La table ci-dessous
> propose un **mapping unité→forme canon** (à PIN, cf. §3.3-B) pour (a) verrouiller le visuel et (b)
> donner sa forme la plus cohérente à chaque unité. Colonne **`forme [PROPOSÉ]`** = la forme du dictionnaire
> la plus alignée mécaniquement/lore. **`new?`** marque les formes du roster non utilisées par une unité
> (réserve pour contenu futur / R5 ELDER).

**Note** : `dotFamily`, `order`, `pool` apparus dans le dump sont des **helpers de module** (pas des
unités) — à ignorer (83 unités réelles).

### 4.1 Mapping par famille (unités existantes → forme canon proposée)

| Unité (id) | rank | family | imp(forme) | **forme [PROPOSÉ]** | Justif. |
|---|---|---|---|---|---|
| skeleton | 1 | mortvivant | 1 | **skeleton** | chaff os, thorns |
| husk | 1 | mortvivant | 2 | **skeletonquad** | chaff, corps |
| gravewarden | 4 | mortvivant | 2 | **revenant** | tank pourri (taunt) |
| aegis_warden | 4 | mortvivant | 2 | **revenant** | (2 sur revenant : OK, hash départage la 2e palette) |
| marauder | 1 | crustace | 3 | **crab** | bruiser pince |
| bandit | 1 | crustace | 3 | **mantisshrimp** | nimble |
| witch | 2 | cocon | 3→? | **broodsac** (NEW) | carry venin (cocon poison) |
| miasma_acolyte | 3 | cocon | 5 | **bilesac** (NEW) | aura poison |
| plague_bearer | 4 | cocon | 7 | **chrysalis** (NEW) | poison fort |
| venom_censer | 5 | cocon | 9 | **embersac** (NEW) | R5 poison → pièce maîtresse cocon |
| demon | 1 | abyssal | 4 | **anglerfish** | leech-leurre |
| arc_warden | 4 | abyssal | 5 | **deepone** | shock |
| static_swarm | 2 | abyssal | 5 | **moray** | shock |
| spore_tick | 1 | spore | 3 | **sporewalker** | poison cadence |
| (— ) | — | spore | 2 | **myconid** (NEW) | réserve |
| (— ) | — | spore | 4 | **infectedhost** (NEW) | réserve |
| live_wire | 1 | oeil | 4 | **eyeball** | shock chaff |
| stormcaller | 2 | oeil | 5 | **eyecluster** | shock |
| thunderhead | 2 | oeil | 3 | **eyeswarm** | shock |
| dynamo_priest | 4 | oeil | 4/5 | **eyecluster** | shock (2e palette) |
| storm_anchor | 3 | cristal | 6 | **crystalcluster** | shock |
| stormlord | 3 | cristal | 6 | **shardwalker** | shock |
| bulwark_acolyte | 3 | golem | 5 | **golem** | shield_aura |
| runestone_golem | 4 | golem | 5 | **sentinel** | shield_aura tank |
| festering | 5 | cauchemar | 8 | **fleshcrawler** | R5 poison (chair) |
| corruptor | 3 | kraken | 9 | **kraken** | poison (seule forme) |
| deep_kraken | 5 | kraken | 9 | **kraken** | R5 (2e palette KRAKEN) |
| rot_grub | 2 | hydre | 8 | **hydra** | poison (seule forme) |
| coil_viper | 2 | reptile | 4 | **cobra** | grant_affliction |
| web_recluse | 2 | arachnide | 3 | **spider** | poison |
| (— ) | — | arachnide | 4/10 | **widow** / **broodmother** (NEW, R5) | réserve / ELDER |
| ink_horror | 2 | cephalo | 6 | **octopus** | poison |
| acid_maw | 3 | cephalo | 5 | **squid** | poison |
| bile_spitter | 3 | plante | 4 | **maweed** | poison |
| (— ) | — | plante | 5 | **vinemaw** | réserve |
| emberling | 2 | demon | 5 | **fiend** | burn |
| wildfire_hound | 4 | demon | 4 | **serpent** | burn |
| ash_maw | 5 | culte | 3 | **possessed** | R5 burn (imp 8) |
| plague_pyre | 5 | culte | 3 | **possessed** | R5 burn (2e palette) |
| bellows_priest | 3 | culte | 3 | **cultist** | burn |
| cinder_cur | 2 | culte | 3 | **cultist** | burn |
| pyre_herald | 2 | culte | 5 | **hierophant** | burn |
| soot_acolyte | 3 | chimere | 9 | **chimera** | aura burn (seule forme) |
| skull_colossus | 5 | crane | 6/10 | **skulltitan** (NEW, imp 10) | R5 → pièce maîtresse |
| zeal_inquisitor | 2 | inquisiteur | 5 | **inquisitor** | burn |
| kiln_warden | 4 | colosse | 7 | **ogre** | burn |
| carrion_pecker | 1 | colosse | 6 | **cyclops** | rot chaff |
| razorkin | 2 | bete | 7 | **behemoth** | bleed |
| hookjaw | 2 | bete | 8 | **dragon** | bleed |
| byakhee | 2 | aile | 5 | **byakhee** | bleed |
| gnaw_rat | 1 | rongeur | 3 | **ratgiant** | bleed chaff |
| galvanizer | 4 | rongeur | 5 | **ratking** | bonus_first |
| siege_breaker | 3 | canide | 4 | **wolf** | strip_shield |
| vein_splitter | 3 | bandit | 3 | **cutthroat** | bleed |
| bloodletter | 4 | echassier | 4 | **strider** | bleed |
| gash_fiend | 2 | echassier | 3 | **heron** | bleed |
| ash_moth | 1 | echassier | 4 | **strider** | burn chaff (2e palette) |
| pyre_tender | 2 | echassier | 3 | **heron** | burn (2e palette) |
| web_recluse | (cf. arachnide) | | | | |
| clot_mender | 3 | wendigo | 7 | **wendigo** | aura bleed |
| leech_thorn | 3 | wendigo | 6 | **stag** | bleed |
| tendon_render | 4 | wendigo | 7 | **wendigo** | bleed (2e palette) |
| slow_bleed | 5 | wendigo | 6 | **stag** | R5 bleed |
| wailing_shade | 2 | spectre | 3 | **wraith** | bleed |
| (— ) | — | spectre | 4/10 | **veiledlady** / **veiledking** (NEW, R5) | réserve / ELDER |
| chitin_drone | 2 | insecte | 3 | **insectoid** | poison |
| footman | 1 | automate | 4 | **automaton** | vanilla |
| rust_sentinel | 4 | automate | 5/10 | **reliquary** | shock (juggernaut = ELDER réservé) |
| bore_worm | 2 | annelide | 5 | **graboid** | rot |
| (— ) | — | annelide | 3 | **leech** | réserve |
| necro_leech | 3 | ombre | 4 | **shade** | rot |
| marrow_drinker | 5 | ombre | 8/10 | **voidmaw** | R5 rot (voidtyrant = ELDER réservé) |
| wither_bloom | 5 | ombre | 8 | **voidmaw** | R5 rot (2e palette) |
| hollow_gut | 4 | gelatine | 4 | **blobmonster** | rot |
| mire_thing | 1 | gelatine | 2 | **slime** | vanilla chaff |
| rot_hound | 2 | larve | 2 | **grub** | rot |
| pit_maw | 5 | larve | 2/10 | **devourer** (NEW, imp 10) | R5 rot → pièce maîtresse |
| blight_spreader | 4 | pendu | 5 | **marionette** | rot |
| decay_tender | 3 | pendu | 5 | **hanged** | aura rot |
| maggot_king | 3 | pendu | 5 | **marionette** | rot (2e palette) |
| patient_worm | 4 | pendu | 5 | **hanged** | rot (2e palette) |
| siphon_jelly | 2 | meduse | 3 | **jelly** | shock |
| plague_doctor | 3 | essaim | 4 | **swarm** | regen (counter) |
| templar | 3 | seraphin | 7 | **seraph** | aura_stat tank |
| shieldbearer | 2 | seraphin | 7 | **throne** | shield_aura |
| mirror_ward | 4 | seraphin | 7 | **seraph** | aura_shield (2e palette) |
| ward_weaver | 4 | seraphin | 7 | **throne** | shield (2e palette) |
| oath_keeper | 4 | templier | 5/7 | **paladin** | shield_aura |
| barrier_savant | 4 | templier | 5 | **crusader** | aura_shield |
| surge_warden | 4 | griffon | 5 | **hippogriff** | aura_shield |

**Bilan réconciliation** :
- **Formes NEW utilisées par des unités existantes (via re-tier R5 surtout)** : broodsac, bilesac,
  chrysalis, embersac (cocon, déjà 4 unités !), myconid/infectedhost (réserve), devourer (pit_maw),
  skulltitan (skull_colossus). → **Le cocon est déjà "saturé" mécaniquement** par witch/miasma/plague_bearer/
  venom_censer : les 4 formes cocon mappent 1:1 → excellent.
- **Formes ELDER en RÉSERVE (aucune unité, ou R5 candidat)** : voidtyrant, veiledking, broodmother,
  juggernaut (4/6 ELDER) — **contenu futur** ou cibles d'un futur R5 dédié. Cohérent avec "ELDER = rare".
- **Formes du roster jamais mécanisées** (réserve d'expansion) : skeleton/quad doublons OK ; toutes les
  formes "humaines pôle order" (paladin/seraph/throne/crusader) sont couvertes ; quelques formes restent
  libres (leech, vinemaw, widow, veiledlady, prism, harpy, jackal/hound, lizard, direcat, imp, reef,
  ooze, mantis…) → **slots pour de nouvelles unités** sans créer d'archétype.
- **Doublons family** (plusieurs unités même famille → départagées par **palette** + forme) : `culte` (5),
  `pendu` (4), `seraphin` (4), `oeil` (4), `wendigo` (4), `mortvivant` (4), `echassier` (4), `cocon` (4),
  `ombre` (3), `abyssal` (3). Le hash palette/forme les distingue déjà ; le PIN (§3.3-B) doit assigner
  des formes/palettes **distinctes** par souci de lisibilité (éviter 2 unités au sprite identique).

---

## 5. Re-tier via imposance (forme → imposance → rank proposé)

`imposance` (1-10) = **potentiel haut-tier**, PAS une assignation de rank (dixit le dictionnaire). Le
projet a **5 rangs** (CLAUDE.md). Mapping de référence **[PROPOSÉ]** :

| imposance | rank proposé | sens | exemples de formes |
|---|---|---|---|
| 1-2 | **R1** (chaff) | mooks, silhouette simple | skeleton(1), cocoon(1), slime/ooze(2), grub(2), myconid(2), revenant(2) |
| 3-4 | **R2** | troupe standard | imp/spider/crab/cultist(3), wolf/eyeball/serpent/mantis(4) |
| 5-6 | **R3** | spécialiste/élite | golem/sentinel/hierophant/byakhee(5), octopus/cyclops/skullking/crystalcluster(6) |
| 7-8 | **R4** | gros / mini-boss | ogre/paladin/seraph/wendigo/chrysalis(7), hydra/dragon/possessed/voidmaw/fleshcrawler(8) |
| 9-10 | **R5 (ELDER)** | légendaire/chimérique | kraken/chimera/embersac(9) ; voidtyrant/devourer/skulltitan/juggernaut/veiledking/broodmother(10) |

**[CONFLITS rank-mécanique ↔ imposance]** — où la forme la plus cohérente diverge du rank actuel de
l'unité. À arbitrer **en faveur du rank mécanique** (le rank est SIM, gated boutique) et **adapter la
forme/palette**, PAS l'inverse :

| Unité | rank actuel | imp de la forme idéale | Conflit | Résolution [PROPOSÉ] |
|---|---|---|---|---|
| carrion_pecker | R1 | cyclops=6 | chaff mécanique mais forme imp 6 | garder R1, **forme moins imposante** (colosse n'a que ogre/cyclops imp 6-7 → prendre la palette la plus "petite", ou réserver carrion_pecker à un autre body ; sinon accepter un R1 trapu mais pas grossi : `scale` reste WORLD_FIT, l'imposance ne change pas l'échelle) |
| hookjaw | R2 | dragon=8 | bleed R2 sur dragon | garder R2 ; **forme behemoth(7) plutôt que dragon(8)** pour éviter "R2 = dragon" |
| razorkin | R2 | behemoth=7 | idem | OK si behemoth, sinon direcat(4) |
| rot_grub | R2 | hydra=8 (seule forme hydre) | hydre n'a QUE hydra imp 8 | **[CONFLIT dur]** : soit accepter "R2 à grande silhouette" (l'échelle ne grossit pas, juste la forme riche), soit **re-router rot_grub vers une autre famille** (larve/annelide) — mais family= est PIN golden. → **garder, l'imposance ≠ échelle in-game** (cf. WORLD_FIT uniforme). |
| corruptor / deep_kraken | R3 / R5 | kraken=9 | R3 sur forme ELDER imp 9 | deep_kraken R5 ✔ ; **corruptor R3 sur kraken imp 9** = [CONFLIT] → accepter (palette différente, échelle uniforme) OU déplacer corruptor (mais family PIN). |
| soot_acolyte | R3 | chimera=9 | chimère n'a QUE chimera imp 9 | R3 sur chimère imp 9 [CONFLIT] → idem kraken : échelle uniforme, palette distincte. |
| ash_maw / plague_pyre | R5 | possessed=8 | R5 mais meilleure forme culte = imp 8 | OK (R5 ≥ imp 8 cohérent ; pas de forme culte imp 9-10). |
| skull_colossus | R5 | skulltitan=10 | ✔ parfait | R5 = skulltitan (NEW). |
| pit_maw | R5 | devourer=10 | ✔ parfait | R5 = devourer (NEW). |
| venom_censer | R5 | embersac=9 | ✔ parfait | R5 = embersac (NEW). |
| marrow_drinker/wither_bloom | R5 | voidtyrant=10 (ELDER) | 2 R5 ombre | l'un sur voidtyrant(10), l'autre sur voidmaw(8) — départage. |

**Principe directeur (résout la majorité des conflits)** : `WORLD_FIT` est **uniforme** (`primgen.lua`
l.2504 : 0.5, échelle nette ×2). **L'imposance pilote le CHOIX DE FORME (richesse de silhouette), pas
l'échelle in-game.** Un "R2 sur hydra" n'écrase donc pas le plateau (il fait la même taille qu'un R1).
La **prestance** de rareté se lit au **cadre de carte + glow** (CLAUDE.md : "le rang se lit d'abord au
cadre, le sprite renforce"). Donc : **mapper imp→rank pour les formes LIBRES** (réserve), et **pour les
unités existantes, choisir la forme dont l'imposance ≈ rank**, en acceptant les rares conflits durs
(familles mono-forme imp 8-9 : hydre, chimere, kraken) car l'échelle ne change pas.

> **[OPTION re-tier "cool ⟹ ELDER"]** (memory `creature-visual-retier`) : si le créateur veut lier
> rareté au "stylé", les formes imp 9-10 deviennent des **candidats R5 prioritaires** et certaines unités
> R3-R4 "trop cool" pourraient monter — mais ça **touche le rank SIM**. À ne faire qu'avec le re-baseline
> golden et l'accord designer (bloque la passe d'équilibrage des command-auras). **Hors scope de ce port
> sauf demande.**

---

## 6. Plan de port ordonné, golden-safe

> **Invariant** : golden SIM `1176281181` **doit tenir**. Tout le rendu est sous le **firewall RENDER**
> (la SIM ne lit jamais sprite/forme/famille). Le seul vecteur SIM est `rank` (re-tier §5) — **gated** :
> ne re-tier que des unités dont le changement de rank est validé en sim, et **re-baseline golden
> sciemment** si on touche une unité du scénario golden (templar/marauder/demon). Les autres étapes sont
> **golden-neutres**.

### Phase B.1 — Animations sur `critter.lua` (isolable, validable galerie) — **golden-neutre**

1. **Tables d'anim** (depuis le HTML) : porter `ATK[form]` (l.769-811), `HURT[family]` (l.880-888),
   `DEATH[family]` (l.889-897) — à placer dans `primgen.lua` (à côté de `MOTION`/`PROF`) et exposer, ou
   dans `critter.lua`. Données pures, append-only.
2. **Enveloppes** : porter `_sstep/_smoo/_env/_dscale/_nrm/_h2/_dprog` (l.717-722, 832) — math pur,
   snapshot-safe.
3. **`atkDisp`** (18 kinds) : ajouter dans `critter.lua` une fn parallèle à `makeDisp` ; sommer son
   `(dx,dy)` par cellule quand `opts.atk` est fourni. Valider d'abord les kinds "simples" (lunge/bite/
   swing/claw/slam/gaze) puis les composites (multi/engulf/skitter).
4. **`hurtDisp`** (8 kinds) + **`deathPix`** (7 kinds, **alpha par cellule** via `batch:setColor(r,g,b,a)`).
5. **`atkFx` + `deathFx`** : overlays `love.graphics.rectangle` **après** `draw(batch)` dans `paint`
   (couleurs = palette `p` du cache : ajouter `boneCol/baseCol/hiCol`).
6. **Yeux** : couper l'overlay pendant `death.ph>0.3`.
7. **Driver** : exposer une mini-machine d'état d'évènement (idle→atk→hurt→death, priorités + durées
   `ATK_DUR=1.05`, `HURT_DUR=0.45`, `DEATH_DUR=1.2`, `DEAD_HOLD=0.7`) — soit dans la galerie pour test, soit
   dans `arena_draw` qui écoute le bus de combat (attaque/hurt/mort déjà émis comme évènements SIM).
8. **Validation** : `luajit -bl src/render/critter.lua` (syntaxe) → `luajit tests/gen.lua` (smoke rendu
   headless reste vert ; `critter` est no-op sans SpriteBatch dans le mock) → `sh tools/check.sh` (golden
   SIM intact, car aucune touche SIM/data) → **inspection visuelle galerie `[g]`** (le seul juge final ;
   l'agent ne lance pas `love .`). Étendre `tests/gen.lua` si on ajoute des noms de parts (ici : aucun, le
   sprite reste monolithique).

> **Pourquoi d'abord** : zéro impact data/SIM, entièrement RENDER, testable en galerie sans toucher au
> roster. Livre la valeur ajoutée (combat vivant) immédiatement.

### Phase B.2 — Builders manquants + familles ELDER/cocon — **golden SIM neutre, golden GÉN sous garde**

1. **PIN d'archetype par unité (§3.3-B)** AVANT d'ajouter des formes : poser sur les 83 unités un
   `arch=<formName>` explicite (ou un mapping `id→formName` consommé par `cachedLive` via
   `opts.archIndex`), de sorte que **`nArch` puisse croître sans rebinder** les sprites existants. Vérifier
   `tests/gen.lua` (distinction) AVANT/APRÈS = identique.
2. **Porter les 10 builders** (`aVoidTyrant, aGrubElder, aSkullTitan, aJuggernaut, aVeiledKing,
   aBroodmother, aCocoonBrood/Bile/Chrysalis/Ember`) depuis le HTML dans `primgen.lua/ARCH` ; les **ajouter
   en queue** des `archs` de leurs familles (`cocon`: remplacer `aCocoon` générique par les 4 ;
   `arachnide`/`larve`/`crane`/`ombre`/`automate`/`spectre`: append l'ELDER).
3. **Réconcilier les noms legacy** (`aTisserand/aBrute/aHellhound/aSwarmflyer`) → renommer en formes canon
   du dictionnaire OU router. S'assurer que `Primgen.archName` retourne les **noms canon** (utilisés par la
   galerie, le grimoire, le bestiaire).
4. **Mettre à jour `tests/gen.lua`** : ajouter une **section de validation par body-plan ELDER** (smoke
   `Primgen.live{family, archIndex}` pour chaque nouvelle forme : grille non vide, `A.mass` présent, pas de
   crash). Étendre `PART_NAMES` n'est PAS requis (sprite monolithique).
5. **Validation** : `luajit -bl primgen.lua` → `luajit tests/gen.lua` (déterminisme + distinction + les
   nouvelles formes rendent) → `sh tools/check.sh` (golden SIM intact). Inspection galerie ELDER.

### Phase B.3 — Re-tier par imposance — **TOUCHE LE rank (SIM), gated**

1. Appliquer §5 **uniquement aux unités hors-scénario-golden** d'abord (golden reste vert sans
   re-baseline). Re-tier = changer `rank` (et éventuellement `cost`) dans `units.lua`.
2. Lancer `luajit tools/sim.lua 400` (équilibrage) après chaque lot ; surveiller le **tier-gating boutique**
   (le rank gouverne l'apparition en boutique — vérifier `src/run/state.lua` / la table de cotes-par-niveau
   si elle existe ; sinon le rank reste cosmétique côté pool).
3. Si on re-tier templar/marauder/demon (scénario golden) : **re-baseline `EXPECTED`** sciemment (comme
   l'historique l.17 le documente : "regénérer si changement VOULU").
4. **Préserver la cohérence mécanique** : effects/commandBonus/aura **inchangés** ; seul rank/cost bouge.
   Le re-tier ne doit jamais transformer un R5 en statcheck (CLAUDE.md : puissance découplée de la rareté).

### Garde-fous transverses (rappel)

- **Append-only RNG** : tout nouveau tirage des builders ELDER reste **interne au builder** (même contrat
  que les existants : `arch.fn(g,rnd,p)` consomme `rnd` dans son corps) → ne perturbe pas la séquence des
  AUTRES unités (chacune a son `rng = newRandomGenerator(hashId(id))`).
- **5 rangs max**, **chimère/ELDER = R5**, **échelle bornée** (WORLD_FIT uniforme : l'imposance ne grossit
  pas le sprite → pas de débordement de plateau).
- **`pairs` interdit** sur tout ce qui influe la génération : `FAMILY_ORDER` et `archs` sont des **listes
  ordonnées** (`ipairs`). Le HTML utilise des objets ; le port Lua doit garder l'ordre (déjà le cas).
- **Firewall** : `critter.lua`/`primgen.lua` rendu = `love.*` autorisé ; aucune lecture par `src/combat`,
  `src/effects`, `src/run`.

---

## 7. Hypothèses & risques signalés

- **[HYP]** Le HTML est une version **plus récente** que le port Lua (il contient les 6 ELDER + 4 cocon +
  `IMPOSANCE` + le moteur atk/hurt/death "v3/v2"). Le Lua n'a NI les ELDER NI le moteur de réactions. Le
  port = "rattraper le HTML". Aucune divergence de *primitive* détectée (toutes présentes en Lua).
- **[RISQUE golden GÉN]** Le piège `nArch`→`archIndex` (§3.3) est le seul vrai danger. Le PIN par unité
  (B.2.1) le neutralise. **Ne pas ajouter de forme à une famille peuplée sans PIN.**
- **[RISQUE perf]** `critter.lua` reconstruit le SpriteBatch **chaque frame** (`fillBatch` : ~300-700
  `setColor+add` par créature). Avec 18 unités à l'écran en combat, c'est ~6-12k ops/frame — acceptable
  (1 draw call/créature) mais à **profiler sur le PC du créateur** (l'export masque les coûts transform).
  Les overlays FX ajoutent ~10-20 `rectangle`/créature pendant les évènements seulement.
- **[CONFLIT mineur]** `BODY_ANIM.hurt` (flash rouge) vs HTML hurt (mouvement pur) : suivre le HTML
  (§2.4). Le feedback couleur est déjà couvert par l'affliction-VFX.
- **[À CONFIRMER designer]** Mapping unité→forme (§4) et conflits rank↔imposance (§5) sont des
  **propositions** : la passe "dédoublonnage + cool⟹ELDER" (memory `creature-visual-retier`) peut les
  réviser ; elle attend 2 listings user et touche le rank SIM (hors scope sauf demande).

---

## Sources (vérifiées)

- `SpriteBatch:setColor` — per-sprite multiply, **0..1 floats en LÖVE ≥11.0** :
  [love2d.org/wiki/SpriteBatch:setColor](https://love2d.org/wiki/SpriteBatch:setColor),
  [love2d.org/wiki/SpriteBatch](https://love2d.org/wiki/SpriteBatch)
- HTML générateur (lu intégralement, cité par n° de ligne) :
  `docs/generation/generateur-bestiaire.html`
- Index roster : `docs/generation/bestiary-dictionary.json` (41 familles / 102 formes)
- Port actuel : `src/gen/primgen.lua`, `src/gen/creaturegen.lua`, `src/render/critter.lua`,
  `src/data/units.lua` (83 unités)
- Golden SIM : `tests/golden.lua` (EXPECTED `1176281181`)
