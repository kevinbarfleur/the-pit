# 07 — Frictions & risks (analyse critique)

> Mon take honnête sur où ce design risque de mal tenir. Je joue mentalement à The Pit en tirant sur les patterns de jeux que je connais. Chaque section = un risque concret + mon estimation de gravité + mitigation possible.
>
> **État `iteration` post-review** : les gravités ont été re-gradées après audit par 2 agents externes (cf. doc 09). Re-grade sumarisé en bas du doc, et 5 risques additionnels (R10-R14) ajoutés.

## Mes références mentales

Pour chaque friction je m'appuie sur des cas observés :
- **Idle pur** : Melvor Idle, NGU Idle, Ant Colony, Cookie Clicker — joueurs qui "click and forget"
- **Roguelite tendu** : Slay the Spire, Hades, Balatro — runs bornés, choix par run
- **Browser MMO** : OGame, Travian — leaderboards, asynchrone, top inaccessible
- **Idle-roguelite hybrides** : Bitburner, Loop Hero — proche du genre cible
- **Auto-battler** : TFT, Backpack Battles — combat passif observé

The Pit emprunte à chacun, ce qui crée **des conflits de pattern**.

---

## Risque 1 — Le mur de scaling devient un mur de grind opaque

**Pattern** : OGame, idles maths-driven. Le joueur sent que push = impossible, mais ne sait pas combien il faut farmer.

**Scénario The Pit** : Léa à D025, retreat 4× contre l'enemy à D025. Achète passifs, retente, échoue encore. **N'a pas de signal** indiquant "il te manque X% de damage" ou "farme 5 floors et retente".

**Gravité : 8/10**. C'est *le* risque numéro 1 du genre.

**Mitigation** :
- Affichage explicite du **threat tier** par enemy avant engagement (★★★ vs hero ★★)
- Après 3 retreats consécutifs, popup discret : "tu sembles bloqué — voici tes options"
- Préview damage estimée pré-combat (DPS hero vs HP enemy → X seconds to win)

---

## Risque 2 — Combat auto-battler trop passif après 5h

**Pattern** : Backpack Battles, TFT — les premières heures sont intenses (build, choix), puis on regarde l'écran sans rien faire pendant les combats.

**Scénario The Pit** : Léa à T+5h. Sait équiper, combat se résout en 8s, elle ne touche jamais Focus, regarde la barre HP descendre.

**Gravité : 7/10**. Si combat = juste regarder, le jeu glisse vers idle pur. Or l'idle pur ne marche que si le **macro** a beaucoup de décisions.

**Mitigation** :
- Combats faciles (player power >> enemy) → **skip-to-end** avec preview du résultat. Évite l'ennui.
- Combats serrés → animation + Focus utile. Le joueur sent la tension.
- V1.1 : event-cards qui demandent input mid-combat (carte rare avec choix popup).

---

## Risque 3 — Leaderboard infinie crée une élite injoignable

**Pattern** : OGame, Travian, Cookie Clicker leaderboards. Les top players grindent 16h/jour (ou bot), les milieu-de-tableau abandonnent en voyant l'écart impossible.

**Scénario The Pit** : Léa à T+20h, deepest D110. Top du leaderboard = D850. Décrochage psychologique : "même si je grind 100h, je ne rejoindrai jamais."

**Gravité : 6/10**. Important pour la rétention long terme, moins pour V1 launch.

**Mitigation** :
- **Saisons / weekly resets** sur un leaderboard secondaire (top depth this week). Le all-time reste, mais le weekly est compétitif.
- Affichage centré sur le joueur (top 10 + ton rang ± 5) plutôt que top 100.
- Achievements / titres au lieu de leaderboard pur ("D100 Diver", "Pit Warden Slayer × 50").

---

## Risque 4 — "Perpetual descent" enlève la satisfaction du clear

**Pattern** : Slay vs Diablo. Slay donne une **fin de run** explicite (ascension complete, victoire). Diablo n'en donne pas (pas de fin), et compense par des seasons/paragon levels.

**Scénario The Pit** : Léa, J+15. Pas de fin, pas de "victory screen". Elle joue tous les jours mais ne peut pas se dire "j'ai fini The Pit". **Risque de burnout sans payoff émotionnel**.

**Gravité : 7/10**. Le genre est inhabituel (idle-roguelite sans run), peu de précédents qui marchent.

**Mitigation** :
- **Milestones explicites** : chaque +50 depth = écran cinétique unique ("you have reached the Vein layer"). Pas un game over, mais un moment marqué.
- Boss à intervalles fixes (D10, D25, D50, D100, D250...) avec **video / animation cosmétique unique** par boss.
- V1.1 : "Ascensions" — mode dur déblocable post-D100 qui remet le joueur à 0 avec bonus permanent (= soft prestige).

---

## Risque 5 — Onboarding zéro-tutoriel décourage les non-roguelite players

**Pattern** : Slay the Spire — onboarding par friction acceptable car niche établie. Mais **The Pit cible Twitch**, audience plus large.

**Scénario The Pit** : utilisateur Twitch curieux clique le lien, atterrit, voit le pit, ne comprend rien, ferme l'onglet en 30s. **Bounce rate élevé**.

**Gravité : 6/10**. Bloquant uniquement si l'audience est large. Si tu cibles roguelite-natifs, moins critique.

**Mitigation** :
- Pas de modal lourd, mais **un seul tooltip ambient** sur le node initial : "click to descend" (disparaît après premier clic).
- Premier combat **garanti winnable** (enemy easy, hero pleine HP).
- 3 messages contextuels max sur les 5 premières minutes (event, Focus, retreat).

---

## Risque 6 — Économie scrap à double tranchant

**Pattern** : NGU Idle, Melvor — économie qui se brise (scrap inflation après T+50h, plus rien à acheter).

**Scénario The Pit** : Léa à T+30h, scrap 50k cumulé, tous passifs accessibles achetés, ne fait que stocker. **Sans sink**, le scrap perd valeur.

**Gravité : 5/10**. Pour V1 court terme : ok. Pour live game : à surveiller.

**Mitigation** :
- Passifs en couches (Body I → X, exponentiel) → toujours un coût hors d'atteinte
- Sink secondaire : reroll de loot, "consommables" pour push (pot de heal pre-combat, scout potion qui révèle 2 floors)
- V1.1 : prestige reset scrap mais donne meta-currency

---

## Risque 7 — Floor seed reproductible = farm prévisible donc ennuyeux

**Pattern** : Melvor — kill 10000 du même monstre. Ennui repetitive.

**Scénario The Pit** : Léa farm D018 combat node 5×. Même monstre, même IA, même drops range. Auto-pilote rapide.

**Gravité : 4/10**. C'est l'objectif (idle), mais peut friser le grind moche.

**Mitigation** :
- Re-roll mineur côté monstre (modifiers : "enraged" +20% HP / -10% dmg, "swift" +20% spd)
- Events random même sur floors clear (5% chance d'event surprise)
- Drops non-déterministes (pool est fixe mais le tirage est random)

---

## Risque 8 — Browser tab discarding casse l'engagement

**Pattern** : Tout jeu browser. Chrome ferme l'onglet quand mémoire pression. Joueur perd la session.

**Scénario The Pit** : Léa joue, change d'onglet pour Slack, revient 10 min plus tard, l'onglet est mort. État OK (Convex persiste), mais reload visible.

**Gravité : 3/10**. État serveur, donc recoverable. Mais UX dégrade.

**Mitigation** :
- Service worker pour persister l'onglet (V1.1)
- Reload silencieux : si reload < 5s après tab focus, restaure l'écran exact (depth, scroll position) sans flash.
- Audio de "bienvenue de retour" si reload détecté (subtil, donne sense of place).

---

## Risque 9 — Auto-equip vs déséquip frustration

**Pattern** : Diablo / loot games — auto-equip prend une décision pour le joueur, parfois mauvaise.

**Scénario The Pit** : Léa a un super charm équipé, drop un charm T0. Auto-equip swap → perdu la synergie. Frustration.

**Gravité : 4/10**. Petit mais cumule.

**Mitigation** :
- Auto-equip **uniquement si slot vide** (jamais swap auto). Sinon popup explicite.
- Visualisation diff (+12 dmg, -3% crit) au popup swap.

---

## Synthèse — où concentrer l'attention V1

Top 3 risques pour V1 launch :

1. **Mur opaque** (R1, **9/10** post-review) → ship "threat tier" et "estimated DPS" dès V1
2. **Pas de payoff long-terme** (R4, **8/10** post-review) → ship milestones explicites D10/D25/D50/D100 + cérémonies boss + reconsider prestige V1.5
3. **Onboarding zéro** (R5, **7/10** post-review) → ship 3-5 tooltips contextuels, premier fight winnable, **first aha moment <60s**

Top 3 pour V1.5/V2 :

4. **Leaderboard inaccessible** (R3, **7/10** post-review) → percentile + tier + cohorte V1, seasons V2
5. **Combat passif** (R2, **6/10** post-review) → speed control x1/x2/x4 V1, audit Focus usage
6. **Cheating leaderboard** (R10, nouveau, **7/10**) → Convex authoritative + anomaly detection V1

Monitor only V1 :

7. Économie scrap (R6) → instrument scrap balance
8. Tab discarding (R8) → résolu si Convex sync OK
9. Top burnout (R12, nouveau) → seasons V2

---

## Risques additionnels post-review (R10-R14)

Identifiés par audit externe. Détail complet dans doc 09.

### R10 — Cheating sur leaderboard infini (gravité 7/10)

`deepestDepth` comme seul score = aimant à tricheurs (macros 24/7, multi-account, scrap exploits). **Mitigation V1** : Convex authoritative + rate limits + anomaly detection (gain depth +50/5min impossible) + shadow ban silencieux.

### R11 — Coût Convex à l'échelle (gravité 5/10)

Combat 4Hz × N joueurs concurrents = mutations Convex coûteuses à scale. **Plan B** : combat client-side avec hash/replay validation. **Action V1** : instrumenter coût/joueur dès le début.

### R12 — Burnout top players (gravité 6/10)

Top à D850+ : chaque +1 depth = +24h grind. Pattern OGame fleeters. Sans seasonal reset, churn assuré post-D90. **Mitigation V2** : seasons trimestrielles + achievements lateraux + prestige cycle. **V1** : architecturer pour permettre seasons sans rebuild.

### R13 — Audience Twitch ≠ idle audience (gravité 5/10)

Streamers cherchent contenu visuel + chat-interactif. Idle browser = peu naturel pour stream. **Pistes V1** : Twitch chat overlay du descent, vote modifier de replay, donate scrap au streamer.

### R14 — Coût cognitif terminal aesthetic (gravité 4/10)

Terminal-first = niche, opaque pour Twitch large. **Mitigation** : terminal-themed + sprites 2D lisibles + colors juicy + animations. Pas terminal pur.

---

## Re-grade synthétique (post-review)

| # | Risque | Originale | Consolidée | Source |
|---|---|---|---|---|
| R1 | Mur opaque | 8 | **9** | A1+A2 priorité absolue |
| R2 | Combat passif | 7 | **6** | A2 mitigé par speed |
| R3 | Leaderboard | 6 | **7** | A1+A2 sous-évalué |
| R4 | Pas de payoff perpetual | 7 | **8** | A1+A2 sous-évalué |
| R5 | Onboarding zéro | 6 | **7** | A1+A2 D1 killer |
| R6 | Scrap | 5 | 5 | confirmé |
| R7 | Farm prévisible | 4 | 4 | mitigation modifiers |
| R8 | Tab discard | 3 | **2** | si Convex OK |
| R9 | Auto-equip | 4 | 4 | toggle V1 |
| R10 | Cheating | — | **7** | nouveau |
| R11 | Coût Convex | — | 5 | nouveau |
| R12 | Burnout top | — | 6 | nouveau |
| R13 | Twitch ≠ idle | — | 5 | nouveau |
| R14 | Cognitif terminal | — | 4 | nouveau |
