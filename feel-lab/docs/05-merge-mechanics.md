# Feel Lab — Règles de fusion RÉELLES du jeu (pour fidélité + portage)

> Cartographie read-only de `src/scenes/build.lua` & co. Sert à reproduire la règle dans la démo et à porter
> l'animation plus tard (en lui passant {copies+positions, cible, niveau} au bon endroit).

## Règle
- **3 copies identiques → niveau+1.** Identité = **même `id` ET même `level`**. Cap `MAX_LEVEL = 3`.
- `LEVEL_MULT = { 1.0, 1.8, 3.0 }` (stats brutes ET auras d'adjacence, à la pose ; pas d'amplification en cascade).
- `BENCH_SIZE = 4`. (`build.lua:96-98`)
- **Survivant** = la **1re copie** rencontrée en scannant **board (1..9) puis bench (1..4)** — déterministe, garde sa position.
  Les 2 autres sont consommées. (`checkMerges` `build.lua:603-654`)
- **Cascade** : boucle `while merged do` → re-scanne jusqu'à plus aucune fusion (un niveau-2 obtenu peut compléter un trio).

## Déclencheurs (chemins de fusion)
1. **Achat boutique → pose** sur case/banc vide → `run:buy` → `checkMerges()` (`build.lua:892-917`).
2. **Auto-buy au clic** (`autoBuy`, `build.lua:686-710`) : 1re case/slot libre, sinon →
3. **`buyMergeWhenFull`** (`build.lua:716-738`) : **board+banc PLEINS** et l'achat complète un trio → le **catalyseur acheté ne touche JAMAIS le plateau**, la 1re copie est promue sur place. ⟹ **source = la carte SHOP**.
4. **Déplacement** (drag board↔board / bench) qui crée un trio → `checkMerges()`.
5. **Piédestal** (commandant) : hors graphe, peut libérer une case et déclencher une fusion ailleurs.

## Géométrie (espace DESIGN 1280×720 = virtuel 320×180 ×4)
- **Board 3×3** : centré ~`(640, 304)`, spacing ~26px (resserré selon forme). `self.pos[i]`×4. (`computeLayout build.lua:187-224`)
- **Bench 4 slots** : `SLOT=60, GAP=10, Y=452`, total 270, `x0 = 640-135 = 505` ; slot i centre x ≈ `505 + (i-1)*70 + 30`. (`computeBench build.lua:389-398`)
- **Shop 5 cartes** : barre `{x=16, y=524, w=1248, h=196}`, flex GAP=10. Centre carte = `shopSlots[i]`×4. (`computeShop build.lua:338-364`)
- Pips de niveau : texte `LV1/2/3`, rampe `LEVEL_INK = {gris, jade, or}` en haut-droite de la case (`slot.lua:38,134-142`) ; aussi `badge.levelPips` (`badge.lua:68-86`).

## Animation EXISTANTE (à dépasser)
`build.lua:418-489` — `MERGE_FLY_DUR=0.33` : 2 « âmes » dorées partent des copies consommées, convergent vers le
survivant en **ease-in** (+ traînée + étincelle) ; puis burst de level-up (éclair blanc, double anneau laiton, pop
texte « LVL n » or qui monte) ; + **bounce** du rig à l'impact (`sin(bp·π)·3·(1-bp·0.4)`). **Aucun son.** Basique
2-sources, pas de rythme « ta-ta-ta », pas de shake/hitstop, pas de cascade mise en scène.

## Entrée pour une future animation (ce qu'on lui passerait)
Au point de décision (`checkMerges`, `build.lua:603-643`) on dispose déjà de : `froms` (positions design des 2 copies
consommées via `fxCenterOf(kind,i)`), `sx,sy` (position du survivant), `id`, `lvl = level+1`. ⟹ une anim porte sur
`{ sources = [{x,y}...], target = {x,y}, color, fromLevel, toLevel, originKind }` ; pour le cas shop, une source
porte la position de la **carte boutique** (et un délai d'« aspiration » de la carte).
