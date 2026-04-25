# 03 — Grind session (farm un floor pour débloquer)

## Persona

**Léa, 5 jours dans.** Profil : `deepest = D023`, bloquée à D023 depuis 3 sessions. Inventaire : 14 cartes, 8 équipées (slots full). Scrap : 412. Torche : 5/5. Décide de farmer.

## Walkthrough minute par minute

### T+0:00 — Décision farm

Land sur `/`. Voit que D023 résiste. Au lieu de re-tenter, scroll up dans le map. Visualise les floors D015-D022 qui sont **clear-replayable** (icône distincte : node grisé mais cliquable, contour fin).

> *Mental* : "j'ai besoin de cartes pour passer D023. je farm les elites du chunk d'avant."

### T+0:30 — Re-engage un node clear

Click un node combat à D018 (clear, replayable). **Confirmation UI** : "ce floor est déjà clear. loot dégradé (×40%). engager ?". Léa accept.

> *Mental* : "ok le jeu me dit que c'est moins rentable, normal."

### T+1:00 — Combat re-run

Combat se joue. Ennemi identique au premier passage (même seed → même monstre). Léa win facilement (elle est plus forte qu'à D018 il y a 5 jours). Reward : 3 cartes proposées, mais le pool est annoncé "tier ↓" (pas T0/T1, max T2). Choisit 1.

> *Mental* : "ok ça aide pour completer la collection."

### T+2:00 — Choix de chemin farm

Pour rentabiliser le farm, choisit les nodes elite (drops T0/T1 même en re-run, mais plus durs). Clear l'elite à D019. Drop : 1 carte T1. Bonne.

### T+5:00 — Scrap accumule

Après 4-5 re-runs, accumule scrap (les combats donnent toujours scrap, peut-être à taux dégradé). Total : 487. Achète passive Edge II : +6% damage. **Friction** : le passif s'active immédiatement, ou seulement à la prochaine descente ? V1 : immédiatement.

### T+7:00 — Push retour

Remonte à D022, push vers D023. Combat boss / elite à D023. Cette fois, win. D024 : nouveau territoire, exciting.

### T+10:00 — Mur suivant

D026 : nouveau mur. Séquence de retreat. **Friction** : Léa réalise qu'elle va devoir re-farm D018-D023 (ou similaire). Ça commence à sentir le grind.

### T+15:00 — Sortie

Quitte. Mood : satisfaction d'avoir progressé de D023→D024, mais conscience que la prochaine session sera 80% farm.

## Décisions du joueur dans cette session

- (active) Quel floor farmer (loot dégradé mais accessible vs neuf mais bloqué)
- (active) Quel type de node prioriser (combat = scrap, elite = T0/T1, treasure = ?)
- (active) Quand stop farm et re-tenter le mur
- (active) Sequence d'achats passifs (HP first ? damage first ?)
- (passif) Pool de cartes dégradé selon état du floor

## Implications techniques

- Node state : `cleared-replayable` distinct de `cleared-dead`. V1 : tous les clear sont replayable.
- Loot dégradé = multiplier sur le pool de cartes ET sur les rewards (scrap, drops). À implémenter dès la V1.
- Floor seed reproductible : même node → même ennemi à chaque re-run. Pas de re-roll côté monde.
- Tracking côté serveur des `times-cleared` par node (pour dégradation progressive ?) **OU** dégradation flat à 1er clear (V1 simpler).
- Passive achetée = effect appliqué immédiatement, recalcul stats hero à la volée.
- Map navigation : scroll vertical, le node "current" est visuellement marqué, mais clic sur un autre node l'engage si reachable.

## Frictions potentielles

1. **Grind trop long** = sensation de mur permanent. **Mitigation** : courbe de loot dégradé + scrap suffisamment généreuse pour que farm 5 nodes débloque souvent +1 mur.
2. **Pas de variété en farm** = même monstre, même seed, même combat → ennui. **Mitigation** : (a) variation aléatoire mineure (modifiers proc), (b) elites tournent différents enemy types par chunk, (c) events random sur replays.
3. **Pas clair pourquoi on grind** = si le joueur ne voit pas qu'il a besoin de plus de power, il push uselessly. **Mitigation** : enemy a un "threat tier" visible avant combat (ex : ★★★★ vs hero ★★) — laisse le joueur juger.
4. **Decision paralysis** sur quel passif acheter = trop d'options trop tôt. **Mitigation** : V1 = tree progression linéaire (Body I → Body II → Body III avant Body IV), pas de branching arbitraire.
5. **Replayability dégradée trop punitive** = farm devient inutile si rewards ×0.1. **Mitigation** : ×0.4 V1, à tuner par feedback. Garder elites/boss à 100% (ou cooldown).

## Notes design

Le grind doit être **un choix** du joueur, pas une obligation cachée. Le jeu doit toujours montrer 2-3 voies (push, farm, spend) et le joueur arbitre. Si grind est l'unique option, c'est un échec design.

Cf. Slay the Spire qui n'a *pas* de farm (run-based) vs Melvor qui a *que* du farm (pas de mur). The Pit doit être au milieu : farm utile mais pas obligatoire 80% du temps.
