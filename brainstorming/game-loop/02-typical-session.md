# 02 — Typical session (J+2, 0 → 15 min)

## Persona

**Léa, 2 jours plus tard.** Profil : `deepest = D008`, `currentDepth = D006` (s'est retirée hier soir). Inventaire : 7 cartes, 3 équipées. Scrap : 124. Torche : 3/5 (pas full reset).

## Walkthrough minute par minute

### T+0:00 — Reprise

Land sur `/`, le pit. Le map est zoomé sur `D006` (= currentDepth). Topbar : `the pit · descender_4f7` (UUID slug), pills `D006 · 124 ◆ · 12 ⌗ · 3 ✦ · 3/5 ☩`.

Notification banner top : `welcome back. while you were away: +28 scrap (offline mining)`. Léa clique `dismiss`. Pas de claim modal lourd.

> *Mental* : "ok je suis pile où je m'étais arrêtée."

### T+0:30 — Re-equip / preview

Léa clique `[C] Cards`. Voit son inventaire (7 cartes). Trois équipées dans les slots mainhand/body/charm. Quatre dispo. Elle swap une carte de body pour une plus tankée qu'elle n'avait pas vue hier. Retour pit.

### T+1:00 — Push deeper

Click le node D006 (pas encore clear) ou un voisin D007 directement (le map permet skip si chemin existe). Combat. Win, +1 carte choisie. Continue.

D008 → boss skipped (no boss avant D010 V1). D009 combat. D010 → **boss visible**. Premier boss visuel : une silhouette plus grosse, animation d'idle plus lourde.

> *Mental* : "le boss. on tente."

### T+3:30 — First boss attempt

Click D010. Combat boss. ~60s. Léa perd à 30% HP du boss. Retreat à D008. Loot perdu **dans cette tentative** (pas de drop si défaite contre boss).

> *Mental* : "ok je reviens."

### T+5:00 — Décision : push ou farm

Léa a deux options visibles :
- (a) Re-tenter D010 immédiatement (gratuit en torches ? coûteux ? **friction** — règle pas claire)
- (b) Farmer D006-D009 pour des cartes meilleures
- (c) Acheter une passive avec scrap

Elle choisit (c). Click `[P] Passives`. Scrap : 162 (a gagné en chemin). Achète "Body I : +10 HP max" pour 80 scrap.

### T+6:00 — Re-tente le boss

Retour pit. Click D010. Combat plus serré. Win cette fois — boss meurt avec 4 HP de Léa restants.

Reward boss : popup spécial. Pas de choix, juste "you receive : T1 Boss Card — Pit Warden Crown". Auto-équipée si slot vide, sinon à choisir.

> *Mental* : "ok premier boss down. ça doit s'accélérer là."

### T+8:00 — Nouveau chunk

D011-D020 = nouveau chunk. Visuels légèrement différents (palette plus froide, ennemis plus mécaniques). Léa pousse.

Hit un mur autour D013. Trois retreats successifs. Frustration commence.

### T+12:00 — Pivot grind

Décide de descendre à D008 (clear) pour farm. **Question UI** : comment elle navigate vers un floor déjà clear ? Scroll up dans le map ? Slider de profondeur ? Click sur un node ancien le reset-il ? **Friction** — voir doc 03.

### T+14:00 — Sortie

Lassée par le mur. Quitte. Reviendra plus tard.

## Décisions du joueur dans cette session

- (active) Re-equip stratégie avant push
- (active) Push vs farm vs spend-scrap
- (active) Tentative boss avec HP/équipement actuels
- (active) Quel passif acheter en premier
- (passif) Map généré, ennemis seedés
- (passif) Offline reward auto-claimé

## Implications techniques

- État de session restauré depuis Convex (currentDepth, deepestDepth, équipement, scrap)
- Map généré à partir du seed + currentDepth, lazy par chunk de 20
- Offline reward calculé serveur-side au login, pas client-side
- Boss à D10 doit avoir un drop garanti distinct du pool standard
- Re-tentative boss après défaite : règle à trancher (cooldown ? coût torches ?)
- Navigation back dans le map = état "scroll up" ou "selected node = old node"

## Frictions potentielles

1. **Mur de progression** D013 typique — moment critique : le joueur peut pivoter (farm) ou abandonner. **Mitigation** : un signal UI explicite "tu sembles bloqué, voici tes options" (subtil — un tooltip).
2. **Re-tentative boss après échec** = règles vagues. Si gratuit infini → trivial. Si coûte 1 torche par essai → punitif. **À trancher** (doc 08).
3. **Navigation arrière dans le map** = pas évident pour un joueur Slay-style habitué à un sens unique. **Mitigation** : tutorial visuel après le premier mur ("tu peux remonter. clique un floor clear pour le re-runner").
4. **Offline reward trop léger** (28 scrap après 2j) ou trop riche (cap 8h × 25% × longue session = +2000 scrap) = soit ennuie soit casse la perception de la session active. **Calibrage critique**.
5. **Boss V1 unique** (Pit Warden à D10, puis ?) = une fois battu, plus de moment marquant avant longtemps. **À combler** par boss intermédiaires ou mini-boss elite.
