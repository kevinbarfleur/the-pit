# Feel Lab — Recherche #4 : Sound Design d'UI grimdark

> Pourquoi l'actuel sonne « candy/Balatro », et comment le rendre dark-fantasy / dégueulasse / cauchemardesque.
> Le **moteur** `synth.lua` n'a besoin d'aucune modif — tout est dans les **recettes** de `sfx.lua`.

## Les 4 fautes « candy » (diagnostic)
1. **Registre trop aigu** (hover 520 / tick 1200 / pop 880 / coin 990 Hz). Le « sombre » vient de l'énergie
   **sous 250-500 Hz** + coupe au-dessus de 2-3 kHz.
2. **Glissandos ASCENDANTS**. Le « frequency code » (Ohala) : **pitch montant = joie/soumission ; descendant =
   dominance/menace**. En grimdark, tout descend (`slide < 0`).
3. **Ondes pures, zéro crasse** : aucun `drive/crush/detune/sub/lp`. Ce sont les 5 outils qui « salissent ».
4. **`success` = accord MAJEUR ascendant** (le « victoire Mario »). Grimdark = **mineur / dissonant / descendant**.

## Leviers (avec valeurs)
| Levier | Candy | Grimdark | Valeur |
|---|---|---|---|
| Registre | aigu | grave | énergie 250-500 Hz, couper >2-3 kHz |
| Direction pitch | montant | **descendant** | `slide < 0` |
| Intervalles | quinte/tierce maj | **m2 / triton / dim** | semis `{0,+1}` `{0,+6}` `{0,+3,+6}` |
| Harmonicité | nette | **inharmonique** | `detune` 0.01-0.05 |
| Saturation | propre | **drive** | 1.5-2.5 (tanh) |
| Lo-fi | 16-bit | **crush** | 4-6 bits |
| Filtrage | large | **passe-bas** | `lp` 0.4-0.55 (fonctionnel), plus pour ambiance |
| Réverb | sèche | **caverne** | `cavern{delay 0.06-0.10, taps 3-4, decay 0.5}` (moments forts seulement) |
| Volume | fort | **retenu** | master 0.45-0.55, vol −30 %, hover quasi inaudible |
| Attaque | sèche | **adoucie** | `a ≥ 0.008-0.012` sur les sons tenus (anti-agressif) |

## Textures organiques (toutes faisables avec synth.lua)
- **Chair/squelch/succion** : `squelch{from,to}` (bruit à cutoff balayé) + `drive`. Sens du balayage = sens du geste.
- **Os qui craque** : `noiseHit{dur 0.03, lp 0.2, drive 2, r 0.01}` (attaque dure + saturation).
- **Pierre/donjon** : `noiseHit{lp 0.7}` **dans `cavern()`** (écho du Puits).
- **Goutte/suintement** : sine à pitch très descendant `tone{freq 600, slide -2000, lp 0.3}`.
- **Gargouillis/drone** : `tone` + `vib` lent (0.5-3 Hz, 0.3-1 demi-ton) + `sub` 0.4-0.8 ; empiler des intervalles dissonants.

## Réfs jeux (takeaways)
- **Path of Exile / Wraeclast** (même univers) : clic = mini-crunch organique + métal **saturé**, *jamais une note* ;
  PoE2 évite délibérément le tonal en combat. → `press` = noise + square grave saturé, pas une sine.
- **Diablo II** : le son donne **poids/physicalité/clarté** > mélodie. `coin/pickup` = grain réel (verre/métal terni).
- **Darkest Dungeon** (Lovecraft) : UI = bruits **diégétiques de matière** (parchemin, pierre, métal), pas des tons synthé.
- **Dark Souls** : menus **sobres**, graves, peu nombreux ; le « gros » son réservé aux boss-moments (victoire/défaite).
- **Silent Hill** : crasse **industrielle/rouillée** = signature (drive/crush/métal filtré). `error` = grincement rouillé descendant.
- **Blasphemous / Hollow Knight / Dead Cells** : **minimalisme** + économie de feedback (le contre-pied de « trop intense »).

## Les 6 changements à fort impact (appliqués dans les packs)
1. Inverser les `slide` (descendants). 2. Baisser d'une octave (cibler 120-360 Hz). 3. Ajouter crasse (`drive`+`lp`,
retirer `harm`). 4. `success`/`ladder` en mineur + un `defeat` qui chute. 5. `pickup/drop` en `squelch`, `coin`
terni. 6. **Restraint** (master ~0.5, vol −30 %, `a ≥ 0.01` sur les sons tenus, `cavern` réservé aux gros moments).

## Pièges
- Le **volume/restraint** est la cause #1 du « trop intense ». - Attaques trop sèches = agressif. - Tout n'a pas
besoin de son (si le hover a déjà un glow fort, son son peut être quasi nul). - Garder la **lisibilité** malgré la
crasse (transitoire clair, `lp ≤ 0.55` et `drive ≤ 2.5` sur les sons fonctionnels). - `cavern()` est coûteux →
moments forts uniquement. - Le beating sub-grave (detune/m2/triton <200 Hz) est **voulu pour error/arcane**, **à
éviter** sur les sons neutres fréquents (sinon malaise + fatigue).

Sources : SoundCy (*dark sound*/*unease*) · *Film Music Theory* (triton/dim/m2) · Ohala/Cook (frequency code) ·
Beat Kitchen (detune/beating) · Tsugi (*scary sounds*, squelch/granular) · A Sound Effect (horror SFX, Returnal) ·
PoE / Diablo II / Darkest Dungeon / Dark Souls / Silent Hill / Blasphemous / Dead Cells (postmortems & analyses) ·
GameJuice & F. Lins (UI restraint, attaque ≥10 ms, anti-répétition).
