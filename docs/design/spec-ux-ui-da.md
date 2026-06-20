# The Pit — Spécification UX / UI / Direction Artistique

> **Document de spec produit** — brief de handoff destiné au **product designer** (qui produira
> wireframes, maquettes et design docs) **et au directeur artistique**. Il décrit *ce qu'il faut
> concevoir*, à partir du jeu réel (code à l'appui) et de la vision cible.
>
> - **Statut du jeu** : prototype jouable (boucle build ↔ combat ↔ run roguelite), visuels en
>   grande partie *placeholder*.
> - **Périmètre** : état actuel **+** vision complète. Chaque bloc est marqué
>   **`[IMPLÉMENTÉ]`** (existe dans le code, à habiller/raffiner) ou **`[À CONCEVOIR]`** (cible,
>   pas encore codée).
> - **Brief permanent du jeu** : `CLAUDE.md` (racine). Recherches de design : `docs/research/`.
>   Conventions pixel art : `docs/pixel-art/conventions.md`.
> - **Langue produit** : anglais par défaut (i18n) ; ce document est en français.

---

## Table des matières

1. [Le jeu en bref](#1-le-jeu-en-bref)
2. [Contraintes techniques transverses (la « boîte » du design)](#2-contraintes-techniques-transverses)
3. [Direction artistique & identité visuelle](#3-direction-artistique--identité-visuelle)
4. [Architecture de navigation & flux d'écrans](#4-architecture-de-navigation--flux-décrans)
5. [Spécification écran par écran](#5-spécification-écran-par-écran)
6. [Design system — bibliothèque de composants UI](#6-design-system--bibliothèque-de-composants-ui)
7. [Catalogue des inputs & interactions](#7-catalogue-des-inputs--interactions)
8. [Catalogue des effets à mettre en scène (combat)](#8-catalogue-des-effets-à-mettre-en-scène)
9. [Sprites & créatures (DA + génération procédurale)](#9-sprites--créatures)
10. [Systèmes signature à anticiper (vision)](#10-systèmes-signature-à-anticiper)
11. [Accessibilité & lisibilité](#11-accessibilité--lisibilité)
12. [Livrables attendus du designer (checklist priorisée)](#12-livrables-attendus-du-designer)
13. [Annexes](#13-annexes)

---

## 1. Le jeu en bref

**The Pit** est un **autobattler multijoueur asynchrone**, grimdark cryptique. On *descend Le Puits*.
Univers **Cthulhu × Path of Exile × Dark Souls** : sale, sanglant, mystérieux.

**Boucle de jeu** : phase **BUILD / boutique** (le joueur achète des unités, les place sur un
plateau-graphe mutable, choisit une géométrie) → **COMBAT auto** (spectateur, déterministe) →
résultat → round suivant. Une **run** = atteindre **10 victoires** avant **5 défaites**.

**Quatre piliers** (à garder en tête pour tout choix de design) :

1. **Simplicité de gestion → profondeur émergente.** Pas de timer, gestion d'équipe simple
   (réf. Super Auto Pets). La profondeur naît de l'**adjacence** sur le plateau, pas de règles
   empilées.
2. **Reliques cryptiques (signature).** Les effets ne sont **pas écrits** : on les *déduit*,
   on les *observe* en combat, puis on les *verrouille* dans un **Grimoire** persistant
   (méta-progression par la connaissance, façon *Return of the Obra Dinn*). `[À CONCEVOIR]`
3. **Multijoueur asynchrone par snapshots (« ghosts »).** Jamais de duel en direct : on affronte
   des instantanés figés de builds réels (ou une IA au démarrage). Pas de netcode, pas de lobby,
   pas de timer. `[À CONCEVOIR]`
4. **Direction artistique = différenciateur.** Le thème + quelques subtilités suffisent à rendre
   un genre connu original.

> Le designer ne dessine pas seulement des écrans : il met en scène une **descente** et une
> **enquête**. Le ton (grimdark, cryptique) prime sur la lisibilité « propre » de l'autobattler
> classique — mais sans jamais sacrifier la compréhension du combat.

---

## 2. Contraintes techniques transverses

Ces contraintes sont **non négociables** : tout le design doit tenir dedans. Source : `conf.lua`,
`main.lua`, `docs/research/love2d-tech.md`.

| Contrainte | Valeur | Implication design |
|---|---|---|
| **Résolution monde (virtuelle)** | **320 × 180 px** | C'est la grille réelle où vivent plateau, créatures, FX. Tout le « jeu » est minuscule : chaque pixel compte. Maquetter d'abord en 320×180. |
| **Fenêtre par défaut** | 1280 × 720 (redimensionnable, min 320×180) | — |
| **Scale** | **entier uniquement** (×4 par défaut), **letterbox** centré | Pas de demi-pixel. Les espacements doivent être pensés en pixels virtuels entiers. |
| **Texte d'UI** | dessiné en **résolution native** (par-dessus le canvas), pas dans le canvas 320×180 | Le texte peut être **net et plus fin** que les pixels du monde. Deux échelles cohabitent : monde pixelisé + UI nette. |
| **Filtre** | `nearest` partout (zéro interpolation) | Pixel art dur, aucun flou. Pas de dégradés lisses dans le monde (les dégradés se font par dithering/rampes). |
| **MSAA** | désactivé | Bords nets. |
| **Frame rate** | **pas de temps fixe 60 FPS** (tick = 1/60 s) | Les timings d'anim se comptent en **frames** (ex. attaque = 35 frames ≈ 0,58 s). |
| **Couleurs** | floats **0..1** (RGBA) | Convention de toute valeur de couleur fournie ici. |
| **Combat déterministe** (RNG seedé) | même seed → bataille identique | UX : **replay gratuit** (`[r]`), pas de hasard à « subir », résultats vérifiables. À exploiter (bouton replay, future galerie de combats). |
| **i18n** | tout texte affiché = **clé** (`t(key, vars)`), fichier `src/i18n/en.lua` | **Aucun texte en dur** dans les maquettes : prévoir des **longueurs variables** (FR/DE plus longs), interpolation `{var}`. Les libellés ci-dessous citent la clé i18n. |
| **Visuels procéduraux** | tout est généré par code (grilles + palette + rig), **zéro asset dessiné** | Le designer fournit des **specs/références**, pas des PNG finaux : grilles de pixels, rampes de palette, formes. Voir §9. |

**Pipeline de rendu par frame** (`main.lua`) :
`monde → canvas virtuel 320×180` → `blit en scale entier + letterbox` → `overlays UI en résolution
native` (noms, nombres, HUD) → `HUD debug (titre, FPS, hint)`.

---

## 3. Direction artistique & identité visuelle

### 3.1 Mood

Grimdark **eldritch**. Références : Lovecraft (géométrie *fausse*, indicible), Path of Exile
(Wraeclast crasseux, sang), Dark Souls (lore dans les objets, mélancolie). Mots-clés :
**sale, sanglant, cryptique, désaturé, oppressant, organique**. Jamais : brillant, propre, « fantasy
colorée », fluo. `docs/pixel-art/conventions.md`

### 3.2 Palette « Wraeclast » `[IMPLÉMENTÉ]`

La palette est un **dictionnaire `caractère → couleur`** (32 teintes) porté du bestiaire de
référence (`src/core/palette.lua`). C'est le **vocabulaire chromatique** du monde : chaque sprite est
écrit avec ces lettres. Principes (théorie Slynyrd) : **majuscule = teinte claire**, **minuscule =
ombre du même ton**, hue-shift par cran, **saturation jamais extrême**, **désaturation globale**.
Contour obligatoire en `K` (noir grimdark).

Rampes sémantiques clés (table complète en [annexe A](#annexe-a--palette-wraeclast-complète)) :

- **Peau/chair** : `I → A → P` (clair) / `i a p d` (ombres)
- **Sang/plaie** : `R` (vif) → `r` (séché) → `H` (grumeleux, presque noir)
- **Métaux** : `Y/T` or, `B` argent, `C` cuivre, `S` os
- **Élémentaire / factions** : `V/v` mystique violet, `E/e` & `G/g` poison vert, `D` chair démon,
  `M/m` magenta cryptique, `O/o` orange exotique
- **Noirs/ombres** : `K X x F` (du fond de grotte au contour)

> **À concevoir** : étendre cette palette en **rampes par faction** (voir §3.5) et en **variantes
> de biome** (le Puits est la seule ambiance actuelle). Toute nouvelle teinte = 5–7 paliers
> luminosité + hue-shift, ajoutés à `palette.lua`.

### 3.3 Langage couleur de l'UI `[IMPLÉMENTÉ — à formaliser]`

L'UI utilise déjà un code couleur implicite, à **formaliser en tokens** (voir §6.1). État actuel :

| Rôle | Couleur (float) | Usage actuel |
|---|---|---|
| Texte « or » (principal) | ~`(0.78, 0.72, 0.60)` | titres, libellés |
| Texte dim | ~`(0.40, 0.34, 0.30)` | hints, FPS, désactivé |
| Hover | jaune `(0.85, 0.74, 0.32)` | slot/élément survolé |
| Valide / cible de drop | vert `(0.42, 0.78, 0.40)` | slot où déposer une unité |
| Danger / adjacence | rouge `(0.63, 0.16, 0.14)` | voisins surlignés, arêtes actives, action de combat |
| Désactivé | gris très sombre `(0.09–0.12, …)` | bouton non disponible |
| Vie (HP) | rouge `(0.63, 0.16, 0.14)` | barre de vie |
| Bouclier | bleu pâle `(0.45, 0.70, 0.95)` | barre de bouclier (overlay) |
| Or (victoire) | `(0.72–0.78, 0.64–0.68, 0.30–0.32)` | bandeau VICTORY / ASCENSION |
| Rouge (défaite) | `(0.70, 0.22, 0.20)` | bandeau DEFEAT |

### 3.4 Typographie `[À CONCEVOIR]`

Actuel : police LÖVE par défaut (bitmap système) rendue en résolution native. **À concevoir** :
une **police bitmap thématique** (lisible à petite taille, esprit manuscrit/gravé pour coller au
Grimoire). Spécifier : graisse(s), hauteur de cap, jeux de glyphes (accents pour i18n FR/DE),
chiffres (très utilisés : stats, or, nombres flottants).

### 3.5 Factions / types comme système visuel `[À CONCEVOIR]`

Le code définit **5 types** d'unités : `flesh`, `order`, `bone`, `arcane`, `abyss`
(clés `type.*`). La vision de design les rattache à des **factions cthuloïdes** (Culte, Noyés,
Engeance, Pestiférés…). **À concevoir** : un **code couleur + silhouette + motif par faction** (la
palette a déjà les rampes : violet arcane, vert poison, rouge démon/abyss, os, or/ordre). Ce code
doit être lisible à la fois sur la créature, sur sa carte boutique, et dans les bonus de synergie
par type.

### 3.6 Géométrie non-euclidienne comme motif

Signature thématique : la **forme du plateau** (sigil) *est* une géométrie blasphématoire. Le design
des sigils (croix, anneau, diamant, ligne) doit *se sentir* différent — pas un simple réarrangement
de cases, mais des **topologies** dont les arêtes (liens de synergie) sont visibles et expressives.

---

## 4. Architecture de navigation & flux d'écrans

### 4.1 Machine à états actuelle `[IMPLÉMENTÉ]`

```
            ┌─────────────────────────── nouvelle run ───────────────────────────┐
            │                                                                      │
        [RUNOVER] ◄──── run terminée (10 victoires OU 0 vie) ──── [BUILD] ──FIGHT──► [COMBAT]
            │                                                        ▲                  │
        click/[r]                                                    └── click (après ──┘
            │                                                            résultat),
            └────────────────────────────────────────────────────────  round suivant
                                                                         (plateau conservé)
```

- **BUILD** est **persistant** entre rounds (le plateau reste) ; boutique & or se renouvellent.
- **COMBAT** et **RUNOVER** sont créés/détruits à la volée.
- Transitions pilotées par un `host` (`main.lua`) : `goto(scene)`, `finishCombat(win)`, `newRun()`.

### 4.2 Inventaire des écrans

| Écran | Statut | Section |
|---|---|---|
| HUD global (persistant, debug + run) | `[IMPLÉMENTÉ]` | §5.1 |
| **BUILD** (plateau + boutique + éco) | `[IMPLÉMENTÉ]` | §5.2 |
| **COMBAT** (spectateur auto) | `[IMPLÉMENTÉ]` | §5.3 |
| **RUNOVER** (fin de run) | `[IMPLÉMENTÉ]` | §5.4 |
| **Menu principal / titre** | `[À CONCEVOIR]` | §5.5 |
| **Écran pré-combat** (présentation du ghost adverse) | `[À CONCEVOIR]` | §5.6 |
| **Choix de relique 1-parmi-3** (post-victoire) | `[À CONCEVOIR]` | §5.7 |
| **Grimoire** (codex de reliques cryptiques) | `[À CONCEVOIR]` | §5.8 |
| **Onboarding / tutoriel** (sandbox) | `[À CONCEVOIR]` | §5.9 |
| **Paramètres** (audio, langue, accessibilité) | `[À CONCEVOIR]` | §5.10 |

---

## 5. Spécification écran par écran

> Format : **rôle → layout/zones → composants → états & feedback → données affichées → actions →
> manques à concevoir**. Les coordonnées sont en **pixels virtuels (320×180)**, telles que dans le
> code. Le designer peut les retravailler, mais elles donnent l'échelle réelle et les contraintes
> de place.

### 5.1 HUD global (overlay, toutes scènes) `[IMPLÉMENTÉ]`

- **Rôle** : chrome de debug + état de run, en résolution native.
- **Coin haut-gauche** : `THE PIT — {scene}` (y≈12), `FPS {n}` (y≈30), `{hint} — [esc] quit` (y≈46).
- **Bandeau de run** (haut-centre, projeté depuis ~(160, 8)) :
  `GOLD {gold}   LIVES {lives}/{max}   WINS {wins}/{target}   ROUND {round}   LEVEL {level} ({slots}/{maxslots})`
  (clé `ui.hud`). Indicateur **streak** conditionnel (`WIN/LOSS STREAK x{n}`) si ≥ 2.
- **À concevoir** : transformer ce HUD debug en **HUD diégétique** (or = pièces gravées, vies =
  bougies/yeux qui s'éteignent, progression 10 victoires = jauge de descente dans Le Puits). Séparer
  clairement le HUD *joueur* (toujours visible) du HUD *debug* (masquable).

### 5.2 Écran BUILD `[IMPLÉMENTÉ]` — l'écran le plus riche

**Rôle** : cœur de la décision. Acheter, placer, organiser la géométrie, gérer l'éco, lancer le combat.

**Zones (de haut en bas)** :

1. **Bandeau de run** (HUD, §5.1) + **titre du sigil** centré : `{label} — {archetype}`
   (ex. `NOVICE'S SQUARE — VERSATILE`, clés `shape.*`).
2. **Plateau-graphe** (zone centrale haute) : origine `BOARD_OY = 60`, centré sur x=160,
   **9 slots**, espacement 26 px. Forme déterminée par le **sigil actif**.
3. **Boutique** (panneau bas) : à partir de `y = 146` (hauteur ~34 px), fond sombre, séparée par
   un trait. **5 cartes** de 31×28 px (`x = 5 + (i−1)·33`, y=149).
4. **Boutons éco** (au-dessus/à droite de la boutique) : **REROLL** (172,149,44×12),
   **LEVEL** (172,163,44×12), **FIGHT/COMBAT** (222,150,92×26).

**Composants & états** :

- **Slot de plateau** (carré ~22×22) :
  - *déverrouillé / vide* : bordure neutre `(0.32,0.28,0.36)` ;
  - *survolé* : bordure jaune ; *cible de drop* (drag actif) : bordure verte ;
  - *voisin du slot survolé* : bordure rouge (= **prévisualisation d'adjacence**) ;
  - *verrouillé* (slots non débloqués par le niveau) : fond plus sombre, bordure éteinte, inerte.
  - *occupé* : la **créature** est rendue (rig animé idle), légèrement au-dessus de la case (+9 px).
- **Arête de graphe** (lien entre 2 slots déverrouillés) : trait « rough » 1 px, neutre
  `(0.28,0.24,0.32,0.7)` ; **rouge actif** `(0.63,0.16,0.14,0.9)` quand une extrémité est survolée.
- **Carte boutique** : fond selon état (*vendue* très sombre / *abordable* normal / *survolée+abordable*
  éclairci) ; bordure dorée si abordable, grise sinon ; **sprite de créature** scalé ~0,7× ; **coût**
  (clé `ui.cost`, ex. `3g`).
- **Boutons** : voir §6.2 (états enabled / disabled / hover / max).
- **Infobulle** : voir §6.6.

**Données affichées** : stats d'unité (HP/DMG/CD), type, nom & passif (via infobulle) ; or, vies,
victoires, round, niveau, slots ; coût des offres ; coût de reroll/niveau.

**Actions** (détail des inputs en §7) : acheter (drag boutique→slot), déplacer/échanger
(drag slot→slot), vendre (drag slot→hors plateau), reroll, monter de niveau (débloque un slot),
changer de sigil (`s`), lancer le combat (FIGHT).

**À concevoir** :
- **Hiérarchie visuelle** claire entre les 3 zones (plateau = scène, boutique = inventaire, éco =
  contrôles). Le tout dans 320×180 : densité forte, attention au *crowding*.
- **Lisibilité de l'adjacence** : rendre les **arêtes** belles et thématiques (veines, fils, runes)
  et le surlignage des voisins évident — c'est le cœur mécanique.
- **Identité visuelle distincte par sigil** (5 formes, §8.4).
- **Visualisation des synergies** : quand une unité est buffée par ses voisins (bouclier d'aura,
  futur shock/poison de voisinage), le montrer (icône, halo, ligne colorée). `[À CONCEVOIR]`
- **Duplicatas** (3 copies → niveau) : indicateur d'étoiles/paliers sur l'unité et la carte.
  `[À CONCEVOIR]` (mécanique prévue, étape #2).
- **Slots verrouillés** : communiquer *comment* les débloquer (LEVEL) ; transformer le déblocage en
  moment de descente (la grille « s'ouvre »).

### 5.3 Écran COMBAT `[IMPLÉMENTÉ]`

**Rôle** : spectacle auto-résolu, déterministe. Aucun input pendant (sauf `[r]` replay, clic en fin).

**Mise en scène** :
- **Décor** (`src/fx/background.lua`) : gradient vertical (sombre en haut → rougeâtre en bas),
  **18 stalactites** au plafond, **halo de braise** diffus, **halo rouge pulsant** (la gueule du
  Puits, bas-centre), **44 particules de poussière** qui descendent. Ambiance « caverne qui respire ».
- **Deux camps** : joueur à **gauche** (facing →), IA/ghost à **droite** (facing ←). Placement
  dérivé de (colonne, rangée) : `CENTER (160,96)`, `FRONT_GAP 18`, `COL_GAP 24`, `ROW_GAP 30`.
  Le **front** (colonne avancée) est ciblé en premier (voir §8.2).
- **Étiquette adverse** (haut-centre) : `vs {name}` (ex. `vs FALLEN PATROL`).

**Feedback de combat existant** (les hooks visuels, voir §8.1) :
- **Barre de vie** : 18 px de large, rouge ; **bouclier** en surcouche bleu pâle ; fond sombre.
  Positionnée au-dessus de la tête.
- **Nombres flottants** : `-{val}` au-dessus de la cible, montent et s'effacent (~40 frames) ;
  **rouge** (dégâts normaux) ou **vert** (poison).
- **Impact** : étincelle orange (cercle qui grandit, ~12 frames) au point de contact.
- **Traînée d'arme** : ligne or pâle pendant le swing (30–65 % de l'anim).
- **Ombres** au sol ; **fade-out** à la mort.
- **Anims de rig** : `idle`, `attack` (35 frames), `hurt` (30 frames, flash rouge).

**Bandeau de résultat** (après un court délai) : overlay semi-noir + `VICTORY` (or) / `DEFEAT`
(rouge) + hint `[click] back to build   [r] replay`.

**À concevoir** :
- **Lisibilité à 9v9** : à terme jusqu'à 9 unités par camp dans 320×180. Prévoir hiérarchie (qui
  agit, qui meurt), peut-être un **ralenti** / mise en avant des moments clés.
- **Cooldown lisible** : `[À CONCEVOIR]` — aujourd'hui le cooldown n'a **pas** d'indicateur visuel.
  Concevoir une jauge/teinte « prêt à frapper ».
- **Statuts (DoT) sur l'unité** : aujourd'hui seuls les **nombres** trahissent un poison (couleur).
  Concevoir des **icônes/auras de statut** (burn/bleed/poison/rot/shock/regen, voir §8.3).
- **Mise en scène des passifs** (lifesteal, thorns, aura) et des **types/factions**.
- **Journal de combat** `[À CONCEVOIR]` : la vision prévoit un log lisible (« X reçoit poison ×3 »).
  Le bus d'événements le permet déjà côté données.
- **Bouton replay / contrôle de vitesse** comme features de première classe (déterminisme).

### 5.4 Écran RUNOVER `[IMPLÉMENTÉ]`

**Rôle** : clôturer la run (ascension ou chute), inviter à recommencer.
- Même décor que le combat ; overlay central semi-noir.
- **Résultat** : `ASCENSION` (or, victoire) ou `THE PIT KEEPS YOU` (rouge, défaite) — clés `runover.*`.
- **Stats** : `{wins} wins — {losses} losses`, `{rounds} rounds — level {level}`.
- **Action** : clic ou `[r]` → nouvelle run.
- **À concevoir** : en faire un **moment narratif** (descente réussie vs avalé par Le Puits),
  amorce de **méta-progression** (reliques nouvellement identifiées au Grimoire, débloquages),
  récap de la run (build final, combats marquants).

### 5.5 Menu principal / titre `[À CONCEVOIR]`

N'existe pas (le jeu démarre directement en BUILD). À concevoir : écran-titre (logo *The Pit*,
ambiance), entrées **Jouer / Grimoire / Paramètres / Quitter**, état du compte (méta-progression,
nombre de reliques identifiées).

### 5.6 Écran pré-combat (ghost adverse) `[À CONCEVOIR]`

Lié au multijoueur async : avant le combat, présenter l'**instantané adverse** (nom/rang/build,
sigil), sans lobby ni timer. Le joueur peut *scouter* puis lancer. Doit s'intégrer entre BUILD et
COMBAT (ou en surimpression de fin de BUILD).

### 5.7 Choix de relique 1-parmi-3 `[À CONCEVOIR]`

Récompense (post-victoire / jalon). **3 fragments candidats** présentés ; effet **cryptique** (texte
d'ambiance, pas l'effet brut). Choisir équipe la relique ; l'effet réel se **révèle à l'usage**.
Pilier signature — voir §10.1.

### 5.8 Grimoire `[À CONCEVOIR]`

Codex **persistant cross-run** des reliques. Interface de **galerie/manuscrit** : entrées cryptiques
(non identifiées) vs entrées **verrouillées** (identifiées → lore lisible définitivement, façon
*Obra Dinn* : manuscrit → imprimé). Voir §10.1.

### 5.9 Onboarding / tutoriel `[À CONCEVOIR]`

Sandbox progressive : expliquer plateau 3×3 + adjacence, cooldowns + ciblage déterministe,
boutique/éco. S'appuyer sur le **déblocage progressif des slots** comme rampe de complexité
naturelle (on commence à 3 slots).

### 5.10 Paramètres `[À CONCEVOIR]`

Audio (volumes), **langue** (i18n déjà prêt), accessibilité (voir §11), affichage (scale, plein
écran), réinitialisations.

---

## 6. Design system — bibliothèque de composants UI

> Objectif : un **kit cohérent** réutilisable sur tous les écrans. Décrire chaque composant avec ses
> **états** et ses **tokens** (couleur/espacement) plutôt qu'au cas par cas.

### 6.1 Tokens (à formaliser) `[À CONCEVOIR depuis l'existant]`

Couleurs : voir §3.3. À nommer en tokens (`color.text.primary`, `color.state.hover`,
`color.state.valid`, `color.state.danger`, `color.hp`, `color.shield`, `color.win`, `color.loss`…).
Échelles d'espacement en **pixels virtuels entiers**. Rayons : aucun (angles durs, pixel art).

### 6.2 Boutons `[IMPLÉMENTÉ]`

- **Primaire — FIGHT/COMBAT** (clé `ui.fight`) : grand (92×26), rouge sang quand actif, plus clair
  au survol ; **désactivé** (aucune unité placée) en gris/teinte éteinte.
- **Secondaires — REROLL / LEVEL** (petits, 44×12) : marron quand abordables, gris si non
  abordables ; **LEVEL** affiche son **coût dynamique** (`ui.level_up {n}`, coût = 4+niveau, soit
  5→10) ou `ui.level_max` (`MAX LEVEL`) si niveau 7.
- États requis pour tout bouton : *default / hover / pressed / disabled / (coût affiché)*.

### 6.3 Cartes

- **Carte boutique** `[IMPLÉMENTÉ]` (31×28) : sprite + coût + états (abordable / non / survolée /
  vendue). À enrichir : **type/faction**, **rareté** (`[À CONCEVOIR]`, pool actuellement uniforme),
  aperçu d'effet.
- **Carte unité (détail)** `[À CONCEVOIR]` : version agrandie pour inspection (stats complètes,
  passif, niveau/duplicatas).
- **Carte relique** `[À CONCEVOIR]` : cryptique (texte d'ambiance) vs identifiée (effet lisible).

### 6.4 Slot de plateau `[IMPLÉMENTÉ]`

États : *verrouillé*, *vide*, *survolé*, *cible de drop valide*, *voisin surligné*, *occupé*.
(Couleurs en §5.2.) À concevoir : état *invalide* (drop refusé), état *source de drag* (slot vidé),
feedback **duplicata/niveau**.

### 6.5 Arête de graphe (lien d'adjacence) `[IMPLÉMENTÉ]`

États : *neutre* / *actif* (extrémité survolée). À concevoir : variantes par **type de synergie**
(bouclier, shock, poison…), et un rendu thématique (organique/runique) cohérent avec chaque sigil.

### 6.6 Infobulle / tooltip `[IMPLÉMENTÉ]`

~196 px de large, ~75 px de haut ; apparaît au survol d'une unité (plateau **ou** boutique) ;
décalée du curseur (+14, +6) avec **anti-débordement** (repli à gauche/au-dessus). Contenu :
`NOM (TYPE)` (`ui.unit_header`), `HP {h}  DMG {d}  CD {c}` (`ui.unit_stats`), nom du passif, description
du passif (multi-lignes). À concevoir : style thématique, hiérarchie typo, gestion des longues
descriptions i18n, futures lignes (synergies actives, duplicatas).

### 6.7 Barres & jauges

- **Barre de vie** `[IMPLÉMENTÉ]` (18 px, rouge) + **bouclier** (overlay bleu).
- **Jauge de cooldown** `[À CONCEVOIR]` (cf. §5.3).
- **Jauge de progression de run** `[À CONCEVOIR]` (10 victoires / 5 vies, en « descente »).

### 6.8 Overlays / bandeaux `[IMPLÉMENTÉ]`

Bandeau de résultat (VICTORY/DEFEAT), overlay de fin de run. À standardiser (overlay semi-noir +
titre + sous-texte + hint d'action).

### 6.9 Indicateurs de statut (icônes DoT) `[À CONCEVOIR]`

Jeu d'icônes pour les 6 familles (burn/bleed/poison/rot/shock/regen) + passifs notables, à poser
sur l'unité et/ou près de la barre de vie, avec compteur de stacks. Voir §8.3.

### 6.10 HUD chips `[IMPLÉMENTÉ — à habiller]`

Or / vies / victoires / round / niveau / slots / streak. À transformer en éléments diégétiques
(§5.1).

---

## 7. Catalogue des inputs & interactions

### 7.1 Souris `[IMPLÉMENTÉ]`

- **Hover** (BUILD) : surligne slot (jaune) + **voisins** (rouge, prévisualisation d'adjacence) ;
  déclenche l'**infobulle** sur unité/offre.
- **Drag & drop** — 3 flux :
  1. **Acheter** : presser une carte boutique abordable et non vendue → l'unité suit le curseur →
     relâcher sur un **slot vide déverrouillé** = achat + placement (débit de l'or). Relâcher
     ailleurs = annulation (l'offre reste).
  2. **Déplacer / échanger** : presser une unité placée (le slot d'origine se vide) → relâcher sur
     un autre slot déverrouillé : si occupé = **échange** (swap), sinon = déplacement.
  3. **Vendre** : relâcher une unité **hors plateau** = vente (remboursement partiel, 50 %).
- **Feedback de drop** : slot cible valide en **vert** pendant le drag.
- **Clic** : COMBAT → en COMBAT (après résultat) avance vers BUILD ; en RUNOVER → nouvelle run.
- **Hit-tests** : slot = rayon ~14 px autour du centre ; carte boutique = rectangle.

### 7.2 Clavier `[IMPLÉMENTÉ]`

| Touche | Contexte | Action |
|---|---|---|
| `s` | BUILD | changer de sigil (cycle carré→croix→anneau→diamant→ligne) |
| `r` | COMBAT | **replay** (rejoue avec la même seed) |
| `r` | RUNOVER | nouvelle run |
| clic | COMBAT (fin) / RUNOVER | continuer / nouvelle run |
| `echap` | global | quitter |

**À concevoir** : raccourcis complémentaires (reroll, level, lancer combat, freeze boutique),
schéma de contrôle documenté, support manette éventuel.

### 7.3 Conversions de coordonnées

L'UI native projette ↔ le monde virtuel (`toVirtual` / `project`). Implication : **les hitboxes
suivent le layout virtuel** ; toute maquette doit fournir des zones cliquables en pixels virtuels.

---

## 8. Catalogue des effets à mettre en scène

> C'est le **gros morceau visuel** du combat. Le designer doit donner un **traitement visuel** à
> chaque effet : sur l'unité (icône/aura), sur la barre, et via le nombre flottant. Tout est piloté
> par des **événements déterministes** (le bus) : ce sont les *hooks* du feedback.

### 8.1 Hooks de feedback — événements du bus `[IMPLÉMENTÉ]`

| Événement | Charge utile | Feedback visuel actuel | À enrichir |
|---|---|---|---|
| `spawned` | liste des unités | (re)construction des rigs | apparition/intro |
| `attack` | l'attaquant | anim `attack` + traînée d'arme | telegraph par type d'unité |
| `hit` | attaquant, cible | anim `hurt` + impact orange | impact selon arme/élément |
| `damage` | `{target, source, cause, raw, absorbed, hp, overkill, poison, hpAfter, shieldAfter}` | nombre flottant rouge / **vert si poison** | couleur/style **par `cause`** (burn/bleed/poison/rot/thorns), crit, overkill |
| `death` | la cible | (fade-out) — **non câblé visuellement** | mort spectaculaire selon faction |

`cause` possible : `attack`, `burn`, `bleed`, `poison`, `rot`, `thorns`. **Recommandation** : un
code couleur de nombre flottant **par cause** (pas seulement poison).

### 8.2 Modèle de combat à rendre lisible `[IMPLÉMENTÉ]`

- **Cooldown par entité** (timer en frames → l'unité frappe). Petits nombres. `[À CONCEVOIR]` :
  l'afficher.
- **Ciblage 100 % déterministe** (zéro dé) : **colonne avant** ennemie → override **taunt** →
  **aggro** la plus haute → tie-break **haut→bas** puis slot. Le joueur doit pouvoir *anticiper qui
  frappe qui* → concevoir un éventuel **indicateur de cible** / lignes de visée. (Aggro & taunt
  câblés mais inertes pour l'instant.)
- **Front/back** dérivé de la colonne : la **première colonne se vide avant** que la suivante soit
  ciblée. La forme du sigil change le profil d'exposition.

### 8.3 Familles de statuts (DoT & altérations) `[IMPLÉMENTÉ — feedback à concevoir]`

6 familles + passifs. Pour **chacune**, concevoir : **icône**, **couleur**, **aura/particule sur
l'unité**, **rendu du tick** (nombre flottant), **indicateur de stacks**, **fin d'effet**.

| Famille | Identité mécanique (résumé) | Pistes visuelles | Palette |
|---|---|---|---|
| **Burn** (brûlure) | 1 instance, garde la plus forte, **décroît** dans le temps ; touche le bouclier. Burst qui s'éteint. | flammèches, lueur orange qui faiblit | `D O o R` |
| **Bleed** (saignement) | 1 instance, **ralentit la cadence** (slow) ; ignore le bouclier. Contrôle/tempo. | gouttes/traînées de sang, swing visiblement ralenti | `R r H` |
| **Poison** | **N stacks** indépendants (max 8) ; option **weaken** (malus de valeur, cap 40 %) ; ignore le bouclier. | brume verte, symbole toxique, compteur de stacks | `E e G g` |
| **Rot** (pourriture) | 1 instance qui **enfle** (cap), **ampute les PV max** (permanent) ; ignore le bouclier. Investissement long terme. | chair qui se décompose, **barre de vie qui rétrécit** (maxHp réduit) | `g n m` (verts/bruns/violacés) |
| **Shock** (choc) | **N stacks**, **amplifie les dégâts reçus** (cap ×2) ; modifie la prise de dégâts. | arcs/éclairs, aura crépitante, flash amplifié à l'impact | `B b C` (froids) ou `M` |
| **Regen** (régénération) | soin/seconde, **contre les DoT**. | particules de soin montantes, lueur douce | `S P T` |

Passifs/ops complémentaires à signaler visuellement : **bonus_first** (premier coup renforcé),
**lifesteal** (drain → soin de l'attaquant), **thorns** (renvoi de dégâts, ignore bouclier),
**shield_aura** (bouclier posé aux **voisins** au début du combat — visible **dès le BUILD**).

> Détails mécaniques exacts (valeurs, durées, stacking) : `docs/research/effects-dot-families.md`,
> `effects-design.md`, et `src/effects/ops.lua`. Le designer n'a pas besoin des chiffres pour le
> *look*, mais doit respecter l'**identité** de chaque famille (burst vs contrôle vs cumul vs
> long-terme vs amplification vs soin).

### 8.4 Sigils (formes de plateau) `[IMPLÉMENTÉ]`

5 formes, **9 slots chacune**, 1 forme = 1 archétype. À concevoir : **identité visuelle forte par
forme** (le plateau doit *se sentir* différent) + rendu des **arêtes** propre à chaque géométrie.

| Sigil (clé) | Archétype | Topologie / adjacence |
|---|---|---|
| `carre` (Novice's Square) | versatile | 3×3 orthogonal — centre 4 voisins, bord 3, coin 2 |
| `croix` (Cross) | mono-carry | centre 4 voisins, branches isolées |
| `anneau` (Ring) | chaîne/propagation | boucle fermée, chaque case 2 voisins |
| `diamant` (Diamond) | go-wide / essaim | adjacence répartie (2–3) |
| `ligne` (Conduit) | conduit | linéaire, propagation début→fin |

### 8.5 Synergies & adjacence `[partiellement IMPLÉMENTÉ]`

Le buff de **voisinage** existe déjà (aura de bouclier du Templier, résolue au BUILD selon la forme).
À concevoir : la **lisibilité** de toutes les synergies d'adjacence (qui buffe qui, de combien) en
BUILD **et** en combat, + les **bonus par type/faction** (vision).

---

## 9. Sprites & créatures

> Double objet : (a) **brief DA** pour le designer ; (b) cadrage de la **génération procédurale**
> de sprites que l'équipe technique mettra en place (les visuels actuels sont en grande partie des
> *placeholders*).

### 9.1 Pipeline visuel `[IMPLÉMENTÉ]`

`grille de caractères` → `Sprite.bake(grille, palette)` → `Image` (filtre nearest, bakée **une
fois**) → assemblée par le **moteur de rig** (scene-graph sur la matrix stack) → animée → rendue.
(`src/core/sprite.lua`, `src/core/rig.lua`, `src/render/arena_draw.lua`.)

### 9.2 Anatomie d'une créature `[IMPLÉMENTÉ]`

- **Format** : table de strings, 1 caractère = 1 pixel, colorisé par la palette ; l'espace =
  transparent.
- **Parts nommées** (convention) : `head, torso, armBack, armFront, weapon, legs, tail`. Une part
  absente est ignorée (pas de crash) — ex. la Sorcière n'a pas de `legs` (robe), le Démon pas de
  `weapon` (griffes).
- **Tailles observées** : head 8×8 à 11×11, torso ~8×10, legs ~9×5, bras/arme 3×7 à 5×8.
- **Pivots** : point d'ancrage de chaque part (rotation/scale) ; `at` = où le pivot se place dans le
  parent (z-order = ordre de la liste `rig`).
- **Facing** : le camp de droite est miroir (scale x = −1) ; les anims jouent toujours « vers
  l'avant ».

### 9.3 Animations `[IMPLÉMENTÉ]`

`idle` (boucle : respiration, léger balancement), `attack` (35 frames : windup → strike à ~50 % →
recovery), `hurt` (30 frames : knockback + flash rouge). Anims **custom** possibles par créature
(Squelette = tremblement d'os, Sorcière = bâton/robe qui ondulent). Timing en **frames**.
À concevoir : `death`, telegraphs d'attaque, variations par faction, anims liées aux statuts.

### 9.4 Roster & état des visuels `[IMPLÉMENTÉ — majoritairement placeholder]`

- **24 unités** dans le roster/pool boutique (`src/data/units.lua`).
- **6 créatures avec visuel dédié** (`src/data/creatures.lua`) : **Marauder, Skeleton, Templar,
  Bandit, Witch, Demon**.
- **18 unités en sprite de repli** (`U.spriteOf` réutilise une des 6 ci-dessus) : spore_tick,
  corruptor, emberling, razorkin, rot_hound, stormcaller, plague_doctor, cinder_cur, pyre_tender,
  ash_moth, gash_fiend, hookjaw, leech_thorn, bile_spitter, rot_grub, carrion_pecker, maggot_king,
  necro_leech. **→ visuels dédiés à produire.**
- Types : `flesh` (chair), `order` (ordre), `bone` (os), `arcane` (arcane), `abyss` (abysse).

### 9.5 Brief génération procédurale `[À CONCEVOIR — piloté technique]`

Cible : générer des créatures « jamais vues, difformes » (cohérent avec l'eldritch) sans artiste.
Entrée envisagée : *type/faction + rareté + effets mécaniques portés*. Process : générer les grilles
des parts, choisir une **rampe de palette** par faction, garantir le **contour `K`** et l'absence de
pixels orphelins, baker + tester le rendu/anim. Sortie : data compatible `creatures.lua`. Le designer
fournit : **règles de silhouette par faction**, **rampes de palette**, **do/don't** de forme, et un
**jeu de références** (plusieurs exemples par faction) pour cadrer le générateur.

### 9.6 Au-delà des créatures `[À CONCEVOIR]`

Props/objets (reliques, sigils sur le plateau), **biomes** alternatifs (le Puits est la seule
ambiance), particules avancées (feu, éclairs), éventuels shaders (glow/distortion — actuellement
aucun). Tout suit le même pipeline (grille/code + palette + nearest).

---

## 10. Systèmes signature à anticiper (vision)

### 10.1 Reliques cryptiques & Grimoire `[À CONCEVOIR — pilier #2]`

- **1-parmi-3** : l'infobulle de relique montre des **fragments candidats** (texte d'ambiance,
  *pas* l'effet brut) ; le vrai effet se **révèle à l'usage/observation** ; candidats randomisés par
  run.
- **Verrouillage** : une fois identifiée (par déduction + observation, façon *Obra Dinn* « règle des
  trois »), la relique devient **lore lisible de façon permanente** au niveau du **compte**
  (connaissance = méta-progression).
- **Grimoire** : codex persistant, **manuscrit interactif** (pas un wiki) : entrées cryptiques vs
  identifiées (manuscrit → imprimé). Anti-brute-force.
- **Implications UX** : éviter la frustration « ID aléatoire » — toujours un **indice déductible** +
  un **feedback observable** clair en combat. Effets parfois **contextuels** (dépendent du voisin/de
  la forme) pour rester intéressants après identification.

### 10.2 Multijoueur asynchrone (ghosts) `[À CONCEVOIR — pilier #3]`

On affronte des **snapshots** figés (unités + positions + **sigil** + seed), servis par
progression/rang/version ; **IA de seed** au démarrage (cold-start ; encounters actuels :
`fallen_patrol`, `drowned_choir`, `brood`). **Pas de lobby, pas de timer, jouable hors-ligne.**
UX : présentation du ghost (§5.6), pas d'attente, victoire « méritée » (pas d'excuse lag).

### 10.3 Duplicatas & leveling `[À CONCEVOIR — étape #2]`

- **3 copies → niveau** (max 3) : stats **et** buffs d'adjacence scalent. UI : indicateur de
  paliers, fusion visible.
- **Leveling = déblocage de slots** (on démarre à 3, vers 9) : rampe de complexité + sens
  économique. UI : la grille « s'ouvre » au fil de la descente.

### 10.4 Économie (valeurs actuelles = placeholders d'équilibrage) `[IMPLÉMENTÉ]`

Or fixe/round = **10** ; reroll = **1** ; boutique = **5** offres ; vies = **5** ; objectif =
**10** victoires ; slots **3 → 9** ; niveau **1 → 7** (coût 4+niveau) ; +1 vie au round **3** si
perte précoce ; streaks (cap **3**) ; revente **50 %**. Le designer doit prévoir une UI **robuste
aux changements de chiffres** (ils bougeront via l'équilibrage `tools/sim.lua`).

---

## 11. Accessibilité & lisibilité

- **Daltonisme** : ne pas coder l'info uniquement par la couleur (statuts, factions, états de slot).
  Doubler par **icône/forme/motif**. Critique vu la palette désaturée et le rouge/vert poison.
- **Lisibilité petite échelle** : tout vit en 320×180. Tester les composants à l'échelle réelle ;
  privilégier silhouettes nettes et contrastes suffisants malgré le grimdark.
- **Texte** : i18n → prévoir longueurs variables ; taille minimale lisible ; éviter les pavés
  (infobulles, descriptions de passif).
- **Charge cognitive** : le combat peut devenir dense (9v9 + DoT) — hiérarchiser, permettre le
  **replay** et un éventuel **ralenti**.
- **Pas de dépendance au temps réel** (async, déterministe) : avantage d'accessibilité à préserver
  (aucun timer de pression).

---

## 12. Livrables attendus du designer

> Proposition de priorisation. À ajuster avec l'équipe.

**P0 — Fondations DA & design system**
- [ ] Mood board / planche d'ambiance grimdark eldritch (valider le ton).
- [ ] **Tokens** UI (couleurs nommées, espacements, états) à partir de §3.3 / §6.1.
- [ ] **Police bitmap** thématique (glyphes + chiffres + accents i18n).
- [ ] Rampes de palette par **faction** (extension de Wraeclast) + règles de silhouette.

**P1 — Écrans existants (habillage)**
- [ ] **BUILD** : hiérarchie des 3 zones, plateau + arêtes + surlignage d'adjacence, cartes
      boutique enrichies, boutons éco, HUD run diégétique.
- [ ] **COMBAT** : jauge de cooldown, icônes/auras de statut, indicateur de cible, journal de
      combat, contrôles replay/vitesse.
- [ ] **RUNOVER** : moment narratif + récap.
- [ ] **Identité visuelle des 5 sigils** + rendu des arêtes par forme.

**P2 — Catalogue d'effets**
- [ ] Jeu d'**icônes de statut** (burn/bleed/poison/rot/shock/regen) + stacks.
- [ ] Traitement visuel **par cause** des nombres flottants ; mise en scène des passifs
      (lifesteal/thorns/aura/bonus_first).
- [ ] Visualisation des **synergies d'adjacence** et **bonus par type**.

**P3 — Créatures & génération procédurale**
- [ ] Références par faction (silhouettes, do/don't) pour cadrer le générateur.
- [ ] Brief des **18 unités placeholder** → visuels dédiés.
- [ ] Anim `death`, telegraphs, variations.

**P4 — Systèmes signature**
- [ ] **Grimoire** (galerie/manuscrit, manuscrit→imprimé) + écran **choix de relique 1-parmi-3**.
- [ ] **Pré-combat ghost** (multijoueur async).
- [ ] **Duplicatas** (indicateur de paliers/fusion) + déblocage de slots.
- [ ] **Menu principal**, **onboarding**, **paramètres**.

---

## 13. Annexes

### Annexe A — Palette « Wraeclast » complète

Source : `src/core/palette.lua`. `caractère → hex → rôle`. Majuscule = clair, minuscule = ombre.

| Char | Hex | Rôle | Char | Hex | Rôle |
|---|---|---|---|---|---|
| `K` | 0x05030a | contour / noir grimdark | `r` | 0x4a1810 | sang foncé |
| `F` | 0x110a14 | fond sombre / ombre | `H` | 0x240808 | sang très foncé (grumeleux) |
| `I` | 0x8a8278 | peau base | `V` | 0x4c2a5e | tissu/mystique violet |
| `i` | 0x44403c | ombre peau | `v` | 0x281438 | violet sombre |
| `A` | 0x6a605a | peau moyenne | `Y` | 0x7e6428 | or / métal doré |
| `a` | 0x342e36 | ombre peau forte | `y` | 0x3e3010 | or sombre |
| `P` | 0xa68872 | peau claire / lumière | `T` | 0xc4a04a | or clair |
| `p` | 0x6a4c3a | peau shadow | `L` | 0x6c4a2a | cuir / brun moyen |
| `d` | 0x301c10 | brun très foncé | `l` | 0x2c1808 | cuir sombre |
| `N` | 0x4a2c1a | brun moyen / os usé | `n` | 0x1e0e08 | brun sombre |
| `C` | 0x6890a0 | cuivre / métal froid | `c` | 0x2c4858 | cuivre sombre |
| `X` | 0x1c1620 | noir profond | `x` | 0x0c0810 | noir ultra-foncé |
| `S` | 0xa89070 | os / squelette | `s` | 0x60503c | os sombre |
| `B` | 0x90a8b8 | argent / métal brillant | `b` | 0x405468 | argent sombre |
| `D` | 0x6a1410 | chair démon (rouge) | `R` | 0x8a2c20 | sang / plaie (vif) |
| `O` | 0x7a3818 | orange / peau exotique | `o` | 0x3c1808 | orange sombre |
| `E` | 0x6e7c4a | poison vert (olive) | `e` | 0x383e22 | vert poison sombre |
| `G` | 0x4a5e30 | vert / plante | `g` | 0x2a3a18 | vert putrescent sombre |
| `M` | 0x7a3850 | magenta cryptique | `m` | 0x3c1828 | magenta sombre |

### Annexe B — Constantes de référence (échelle réelle)

- **Affichage** : monde 320×180 ; scale ×4 ; tick 1/60 s.
- **Plateau (BUILD)** : `BOARD_OY=60`, centre x=160, espacement 26.
- **Boutique** : panneau y=146 (h~34) ; 5 cartes 31×28, `x=5+(i−1)·33`, y=149.
- **Boutons** : FIGHT 222,150,92×26 ; REROLL 172,149,44×12 ; LEVEL 172,163,44×12.
- **Infobulle** : ~196×75, offset (+14,+6), anti-débordement.
- **Combat (placement)** : centre 160,96 ; FRONT_GAP 18 ; COL_GAP 24 ; ROW_GAP 30.
- **Anims** : attack 35 frames ; hurt 30 frames ; swing connecte à ~50 %.
- **Feedback** : barre de vie 18 px ; nombre flottant ~40 frames ; impact ~12 frames.
- **Éco** : or/round 10 ; reroll 1 ; offres 5 ; vies 5 ; objectif 10 ; slots 3→9 ; niveau 1→7
  (coût 4+niveau) ; +1 vie round 3 ; streak cap 3 ; revente 50 %.

### Annexe C — Références (ce qu'on en retient pour l'UX/DA)

- **Super Auto Pets** — gestion simple, pas de timer, or fixe/round, lifecycle vies/victoires.
- **TFT** — leveling = déblocage + odds, duplicatas/merge.
- **Backpack Battles** — adjacence spatiale = moteur de synergies ; async par snapshots.
- **The Bazaar** — matchmaking par paliers (≈ nos buckets de progression).
- **Return of the Obra Dinn** — déduction + verrouillage (manuscrit → imprimé) = modèle du Grimoire.
- **Dark Souls / Tunic / Outer Wilds** — lore par les objets, connaissance = progression.
- **Path of Exile** — buckets de modificateurs (flat/increased/more), familles de DoT par axe.
- **Balatro** — re-thème radical sans casser la mécanique ; faisabilité Lua + LÖVE.

### Annexe D — Fichiers sources (traçabilité)

| Domaine | Fichier(s) |
|---|---|
| Scènes / UI | `main.lua`, `src/scenes/{build,combat,runover}.lua` |
| Plateau / sigils | `src/board/{board,shapes}.lua` |
| Économie / run | `src/run/state.lua` |
| Effets / combat | `src/effects/{engine,ops,stats}.lua`, `src/combat/{arena,place}.lua`, `src/core/bus.lua` |
| Données | `src/data/{units,creatures,encounters}.lua`, `src/i18n/en.lua` |
| Visuel | `src/core/{palette,sprite,rig}.lua`, `src/render/arena_draw.lua`, `src/fx/background.lua` |
| DA / recherche | `docs/pixel-art/conventions.md`, `docs/research/*.md` |

---

> **Maintenance** : ce document décrit l'état au prototype actuel + la cible. Quand un système
> `[À CONCEVOIR]` est implémenté, le repasser en `[IMPLÉMENTÉ]` et mettre à jour les valeurs.
> Les chiffres d'équilibrage (éco, effets) sont des **placeholders** et bougeront.
