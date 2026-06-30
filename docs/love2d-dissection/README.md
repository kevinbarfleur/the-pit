# Love2D Dissection — Reverse-engineering visuel de jeux LÖVE commerciaux

> But: disposer d'une **bibliothèque de référence interne** pour reproduire, dans
> The Pit, le niveau visuel / feel / UX des meilleurs jeux LÖVE du marché.
>
> Ce dossier est rédigé pour être lu par un agent (ou un humain) qui **n'a PAS
> accès au code source des jeux**. Tout ce qui est nécessaire pour reproduire un
> effet est recopié ici : shaders GLSL complets, patterns Lua annotés, schémas
> d'architecture, recettes "comment refaire ça".

---

## Provenance et statut légal

Ces notes ont été produites en extractant localement les archives `.love` des
jeux installés via Steam sur la machine de l'auteur, **pour étude personnelle**.

- Le code source complet des jeux **n'est pas** versionné ici. Seuls des
  **extraits représentatifs** (shaders, fonctions clés) sont cités à titre
  pédagogique, avec attribution.
- Objectif: apprendre les **techniques**, pas copier le contenu. Les valeurs,
  assets, textes et données de gameplay des jeux restent leur propriété.
- À n'utiliser que comme inspiration / référence technique pour The Pit.

Jeux disséqués (tous LÖVE / Love2D) :

| Jeu | Genre | Pourquoi c'est une référence |
|-----|-------|------------------------------|
| **Balatro** | Roguelike deckbuilder | Le mètre-étalon du "juice" carte : shaders foil/holo/polychrome, moteur d'animation à ressorts, feedback omniprésent |
| **Arco** | Tactical RPG pixel-art | Pixel-art sublime, ECS maison (`ferris`), météo/ambiance, combat simultané lisible |
| **Dice Have No Eyes** | Roguelike de dés | Juice extrême (ripple, bloom, bulge, chromatic aberration), peu de fichiers donc très lisible |
| **Moonring** | Dungeon crawler old-school | Post-processing CRT/bloom, système de particules data-driven, palette/recolour shaders |
| **Mudborne** | Cozy sim pixel-art | Moteur maison `tngine`, shaders d'eau/glace/neige/outline, intégration Tiled |

---

## Comment utiliser ce dossier

1. **Tu veux un effet visuel précis** (foil, bloom, CRT, eau, outline, dissolve…)
   → `techniques/shaders.md` (catalogue GLSL complet, multi-jeux).
2. **Tu veux du "game feel"** (ressorts, tween, screenshake, hitstop, particules)
   → `techniques/game-feel-juice.md`.
3. **Tu veux structurer une UI** (arbre de noeuds, layout, tooltips, focus)
   → `techniques/ui-architecture.md`.
4. **Tu veux comprendre un jeu en entier** → `games/<jeu>.md`.
5. **Vue comparative rapide** → `00-overview.md`.

Chaque doc `games/<jeu>.md` suit le même plan : architecture → boucle de rendu →
shaders → animation/juice → UI/UX → particules/audio → "ce qu'on vole pour The Pit".

---

## Index

- [`00-overview.md`](00-overview.md) — tableau comparatif technique des 5 jeux
- **Jeux**
  - [`games/balatro.md`](games/balatro.md)
  - [`games/arco.md`](games/arco.md)
  - [`games/dice-have-no-eyes.md`](games/dice-have-no-eyes.md)
  - [`games/moonring.md`](games/moonring.md)
  - [`games/mudborne.md`](games/mudborne.md)
- **Techniques (transversal, prêt à reproduire)**
  - [`techniques/shaders.md`](techniques/shaders.md) — catalogue de shaders GLSL
  - [`techniques/game-feel-juice.md`](techniques/game-feel-juice.md) — ressorts, tweens, shake, hitstop
  - [`techniques/ui-architecture.md`](techniques/ui-architecture.md) — arbres de noeuds, layout, tooltips
  - [`techniques/particles.md`](techniques/particles.md) — systèmes de particules
  - [`techniques/post-processing.md`](techniques/post-processing.md) — pipeline canvas, CRT, bloom
- **Application à The Pit**
  - [`apply-to-the-pit.md`](apply-to-the-pit.md) — priorités concrètes pour notre projet

---

## Méthodologie d'extraction (reproductible)

Les jeux LÖVE Windows sont des `.exe` "fusionnés" : l'archive `.love` (un ZIP)
est concaténée à la fin du binaire `love.exe`. On l'extrait ainsi :

```python
# Python: zipfile gère les ZIP préfixés (il scanne le End-Of-Central-Directory
# en partant de la fin et corrige les offsets). .NET ZipArchive échoue (lit 0 entrée).
import zipfile
with zipfile.ZipFile(r"C:\...\Balatro.exe") as z:
    z.extractall("out/balatro")
```

Indices qu'un jeu est en LÖVE : présence de `love.dll`, `lua51.dll`,
`SDL2.dll`/`SDL3.dll`, `OpenAL32.dll` dans le dossier d'install.
