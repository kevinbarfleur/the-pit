# Application à The Pit — priorités concrètes

> Traduction des techniques disséquées en chantiers actionnables pour The Pit,
> rangés par retour sur investissement (feel gagné / effort). Chaque entrée
> renvoie à la source détaillée et **respecte nos frontières** : tout ce qui suit
> vit côté **PRESENTATION** (`src/render`, `src/ui`, `src/fx`, `src/audio`), lit
> l'état de la SIM, ne le mute jamais, et n'utilise jamais `math.random` global
> en SIM.

Rappel de notre contexte (cf. `CLAUDE.md`) : autobattler roguelite, boucle
build → combat auto → bilan, plateau graphe 3×3, cartes de monstres TCG,
direction grimdark/organique, feedback fort au hover/click/drag.

---

## Tier S — gros feel, effort modéré (à faire en premier)

### 1. Adopter le modèle Cible/Visible (T/VT) pour tout ce qui bouge
**Source** : `techniques/game-feel-juice.md` (Balatro `moveable.lua`).
**Quoi** : chaque entité affichée (monstre sur le plateau, carte de boutique,
panneau) garde une transform *cible* (posée par la logique de présentation) et
une transform *visible* qui l'ease via un ressort `inertie = exp(-rate·dt)`
(indépendant du framerate). On ne dessine jamais la position logique brute.
**Gain** : rien ne se téléporte. Un monstre qui change de case glisse, une carte
achetée rejoint la main en douceur. C'est *la* base de tout le reste.
**Pour nous** : le plateau 3×3 = un conteneur "Major" ; les monstres = "Minor"
soudés avec offset. Secouer/incliner le plateau devient gratuit.

### 2. `juice_up()` sur chaque événement de combat
**Source** : `techniques/game-feel-juice.md`.
**Quoi** : `offset(t) = A·sin(freq·t)·max(0,((dur−t)/dur))^p`. Appliquer un
squash-stretch amorti sur l'acteur ET la cible à chaque : déclenchement de
capacité, dégâts encaissés, soin, mort, achat, level-up.
**Gain** : énorme satisfaction pour ~10 lignes. C'est le geste signature de
Balatro/Dice.
**Pour nous** : brancher sur les events de la SIM de combat déterministe (la SIM
émet "A attaque B", la présentation joue le juice). Régler l'amplitude selon
l'ampleur du coup.

### 3. La trinité d'impact : shake + hitstop + flash, synchronisés
**Source** : `techniques/game-feel-juice.md` (Dice "combo d'explosion").
**Quoi** : sur un gros coup, déclencher *au même instant* : screenshake
(trauma², via `love.math.noise`, pas `random`), un micro-hitstop (0.04–0.12 s),
un flash bref sur la cible, et des particules. La force est scalée par l'ampleur.
**Gain** : le "poids" des coups. Dice scale 7 effets par la force du coup.
**Pour nous** : screenshake en décalant le **conteneur racine** du rendu (gratuit,
cf. Node:translate_container). `Shake:add(0.2)` coup normal, `0.7` critique.

### 4. Tooltips automatiques par hover (glossaire de tags/reliques)
**Source** : `techniques/ui-architecture.md` (Balatro `h_popup`).
**Quoi** : un élément déclare sa définition de tooltip (`h_popup`) ; le moteur le
crée au survol et le détruit à la sortie. Zéro gestion manuelle de visibilité.
**Gain** : nos tags canoniques (`Poison`, `Burn`, `Haste`…) et reliques ont déjà
besoin d'entrées de glossaire Shift. Le hover-popup les affiche sans code dispersé.
**Pour nous** : chaque carte/tag pointe vers son entrée `card_glossary.lua`. À
câbler dans `src/ui`.

---

## Tier A — identité visuelle (donne le "AAA indé")

### 5. Pipeline canvas → post-process dosable (CRT/bloom/vignette léger)
**Source** : `techniques/post-processing.md` (Balatro CRT, Moonring 3-canvas).
**Quoi** : rendre toute la scène dans un canvas, appliquer un shader plein écran
optionnel, blit final scalé. Pour le grimdark : **vignettage** (le `mask` du
CRT), bloom doux sur les sources émissives (sang qui luit, runes, braises),
scanlines quasi nulles, courbure barrel ~0. `glitch` réservé à un event
"corruption".
**Gain** : cohérence et atmosphère immédiates.
**Pour nous** : créer un canvas émissif séparé (uniquement ce qui doit briller) →
bloom séparable demi-résolution, comme Moonring. Garde le coût bas.

### 6. Shaders d'édition de carte pour la rareté / les statuts
**Source** : `techniques/shaders.md` (Balatro foil/holo/polychrome/negative/debuff).
**Quoi** : un reflet animé empilé sur le sprite du monstre selon son rang/rareté
ou un statut (béni, maudit, légendaire chimère). Le shader `debuff` (désaturé +
croix) est parfait pour un monstre **désactivé/scellé**.
**Gain** : lisibilité de la rareté + premium feel, cohérent avec nos rangs
authored (`unit_levels.lua`) et nos chimères légendaires (asset-forge).
**Pour nous** : réutiliser le contrat d'uniforms partagé (texture_details,
dissolve, time désync par ID) ; piloter depuis `src/render/monstercard.lua`.

### 7. Tilt 3D des cartes au survol
**Source** : `techniques/shaders.md` (bloc vertex partagé Balatro).
**Quoi** : pencher le quad de la carte vers le curseur en perturbant la composante
`w` du vertex, + une passe d'ombre parallaxée dessous.
**Gain** : la carte "se soulève" sous la souris. Effet le plus "cher à l'oeil"
pour le moins d'effort. Aligné avec notre exigence de feedback hover fort.
**Pour nous** : envoyer `hovering` (0→1 eased), position souris, `screen_scale`.

### 8. Dissolution/burn partagée pour apparition/destruction de carte
**Source** : `techniques/shaders.md` (Balatro `dissolve_mask`).
**Quoi** : une fonction de dissolution par champ de bruit + liseré de flamme,
réutilisée pour faire **apparaître** (achat, invocation) et **détruire** (mort,
sacrifice) une carte.
**Gain** : transitions de carte organiques, parfaitement raccord avec le thème
"flesh/sacrifice" du visual-overhaul en cours.

### 9. Fond animé procédural grimdark (sans texture)
**Source** : `techniques/shaders.md` (Balatro `background.fs`).
**Quoi** : un shader plein écran "peinture qui tourbillonne" piloté par 3 couleurs
de palette. Mettre 3 teintes sombres (rouge sang, gris-vert organique, noir).
**Gain** : un fond vivant pour la fosse, gratuit (aucun asset), qui respire.

---

## Tier B — finitions qui comptent

### 10. UI déclarative + layout row/column auto
**Source** : `techniques/ui-architecture.md` (Balatro UIBox).
**Quoi** : décrire chaque panneau (boutique, HUD, bilan, codex) comme une table
de noeuds (rows/columns/padding/align) ; le layout se calcule seul.
**Gain** : supprime le calcul de positions en dur, harmonise tous les écrans à
notre niveau de craft (objectif `ui-artisan`), résolution-indépendant.
**Note** : on a déjà des primitives (Frame, cartes). À introduire progressivement
là où on positionne encore à la main.

### 11. Texte vivant (nombres/score qui poppent)
**Source** : `techniques/ui-architecture.md` (Balatro DynaText), Dice `coloured_text`.
**Quoi** : les dégâts/or/PV montent avec un pop par chiffre ; les mots-clés de
tag sont **auto-colorés** dans les descriptions (icon+couleur+nom, jamais couleur
seule — conforme à notre règle de wording).
**Gain** : lisibilité + vie. `coloured_text` de Dice colore automatiquement les
mots-clés reconnus → parfait pour nos tags canoniques.

### 12. Particules d'effets nommés (data-driven)
**Source** : `techniques/particles.md` (Moonring 146 défs), émetteur Balatro.
**Quoi** : déclarer un bestiaire d'effets en **data** (`poison`, `burn`, `heal`,
`summon`…) séparé du moteur, cohérent avec notre pilier DATA/TUNING. Burst maison
léger (carrés colorés) pour l'éclaboussure de dégâts.
**Gain** : effets variés, tunables sans toucher le code, exportables/testables.

### 13. Audio à pitch croissant dans une chaîne
**Source** : `games/balatro.md`, `games/dice-have-no-eyes.md`.
**Quoi** : quand plusieurs capacités/déclenchements s'enchaînent dans un tour, le
SFX monte en pitch à chaque maillon. Variation + priorité pour éviter la bouillie.
**Gain** : la montée sonore satisfaisante des combos, pour presque rien.
**Pour nous** : brancher sur la séquence d'events de combat (`src/audio`).

---

## La carte de déplacement partagée (technique avancée, fort potentiel)

**Source** : `games/dice-have-no-eyes.md` (canvas `rg32f` `displacement`).
Dice maintient un **canvas de déplacement** global où *tout* système tape des
bumps/ondes additives qui s'estompent de ~10 %/frame ; un shader final échantillonne
ce canvas pour distordre l'image. Clic, impact de dé, explosion, scroll, curseur :
tout y contribue. C'est l'effet "liquide/organique" signature.
**Pour The Pit grimdark** : une seule carte de déplacement = ondulations de chair,
ondes de choc d'impact, pulsations de la fosse. Un investissement, mais c'est le
genre d'effet qui définit une identité. À considérer après les Tiers S/A.

---

## Garde-fous (ne pas casser nos frontières)

- Tout ce qui précède est **présentation pure** : aucun de ces systèmes ne doit
  modifier la simulation, ni introduire de non-déterminisme dans la SIM.
- La SIM **émet des events** (déterministes, seedés) ; la présentation les **joue**
  (juice, shake, son, particules). C'est la couture propre (cf. `EventManager`
  Balatro / la séquence de combat).
- `math.random`/`love.math` autorisés **uniquement** côté présentation (shake,
  variation de particules/audio) — jamais en SIM. Moonring le fait exprès.
- Réutiliser nos composants existants (Frame, cartes, glossaire) avant d'inventer.
- Vérifier au screenshot (`love . --shoot=all`) avant de déclarer une UI finie.

## Ordre de bataille suggéré

1. T/VT + `juice_up` (Tier S 1-2) — débloque tout le reste.
2. Trinité d'impact + tooltips hover (Tier S 3-4).
3. Pipeline canvas + post-process léger (A 5).
4. Tilt 3D + éditions + dissolve sur les cartes de monstres (A 6-8).
5. Fond procédural (A 9), puis finitions Tier B au fil de l'eau.
