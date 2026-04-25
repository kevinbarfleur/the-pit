# 01 — First session (0 → 10 min)

## Persona

**Léa, 27, marketing manager.** Découvre The Pit via un stream Twitch. Joue à Slay the Spire et Balatro. N'a jamais touché à un idle. Browser, pas de compte créé.

## Walkthrough minute par minute

### T+0:00 — Arrivée

Land directement sur `/` qui est **le pit lui-même** (pas de hub écran, pas de splash). Topbar en haut : `the pit · stranger`. Menubar : `[D] Pit  [P] Passives  [C] Cards  [X] Codex  [L] Leaderboard`. Zéro modal d'onboarding.

Le viewport montre un map vertical de nodes connectés par chaînes pixel-art. **Un seul node est mis en évidence** : l'entrée du pit, à profondeur D001, avec un torche qui pulse. Tout le reste est sombre / locked.

> *Mental* : "ok c'est où je clique ?"

### T+0:10 — Premier clic

Léa clique le node éclairé. Zoom continu vers l'intérieur. Apparition d'un personnage par défaut (le seul disponible — pas de character select V1) au centre. En face : un ennemi simple (rat, archer, ou chien). Un compteur "torche : 5/5" visible.

> *Mental* : "ah ok je joue cette silhouette".

### T+0:20 — Premier combat

Combat démarre automatiquement. Action meters tickent. Premier coup d'épée s'enclenche, hit, l'ennemi recule. Léa voit deux icônes en bas : `[Space] Focus` (charge à 0%) et un slot de carte vide.

Combat dure ~25s. Hero gagne. Petit fade. Reward popup : 3 cartes proposées, prendre 1.

> *Mental* : "oh c'est du Slay style, ok j'aime."

### T+0:50 — Premier loot

Trois cartes affichées. Aucune équipée encore. Léa choisit la mieux nommée. Le UI montre **où elle va** (slot mainhand). Pas de tutoriel, juste le résultat visible.

### T+1:00 — Retour map

Zoom out. Le node est maintenant `cleared`. Trois nouveaux nodes apparaissent en dessous (depth D002), chacun avec un picto (combat, event, shop). Léa peut aussi remonter mais le node d'entrée est gris (clear, replayable but no incentive yet).

### T+1:30 — Deuxième combat

Click un node combat D002. Combat plus dur. Léa essaie le bouton Focus → consomme 50% jauge → trigger immédiat de la carte main → gros hit. Win.

### T+3:00 — Premier event

Click un node event D003. Texte court (3 lignes) + 2 choix. Pas de stats visibles, juste des verbes ("écouter le murmure", "passer"). Choix 1 : +5 scrap, -1 HP max permanent (durant cette descente seulement ? ou perma ? **friction**).

### T+5:00 — Premier mur

D006 ou D007 : combat trop dur, hero meurt à 0 HP. **Que se passe-t-il ?** Pas de "game over". Écran : "tu te retires. retour à D004." Garde toutes les cartes, toutes les torches dépensées. Friction : Léa se demande si elle a perdu.

### T+8:00 — Découverte des onglets

Clique `[P] Passives`. Vue claire : 4 trees (Body / Edge / Pact / Depth), tous à 0. Compteur scrap visible. Une upgrade à acheter pour 50 scrap. Léa en a 38. Retour au pit.

### T+10:00 — Continue

Continue à pousser. Pas encore boss en vue. Sort du jeu en se disant "je reviens demain".

## Décisions du joueur dans cette session

- (active) Quel node prendre à chaque branche
- (active) Quelle carte garder du draft
- (active) Quand utiliser Focus dans un combat
- (active) Quand se retirer volontairement
- (passif) Action meters tickent seuls, hero attaque seul
- (passif) Pas de choix de hero V1

## Implications techniques

- `/` doit afficher le pit directement (pas de hub écran)
- Premier état utilisateur = profil créé silencieusement (anon UUID localStorage), Convex insert
- Combat engine doit tourner avant carte loot (pas de bootstrap "deck builder" requis)
- Floor 1 doit avoir un ennemi facile **garanti** (seed du first floor non aléatoire OU pool restreint)
- "Retreat" en cas de défaite = state transition, pas un game over
- L'icône torche doit être présente dès le début, même si on ne l'utilise pas activement (foreshadow)

## Frictions potentielles

1. **Pas d'onboarding explicite** = certains joueurs n'oseront pas cliquer. **Mitigation** : node initial très saillant (pulse, glow), tout le reste dimmé.
2. **"Retreat" pas clair** = le joueur croit avoir perdu sa progression. **Mitigation** : popup de retreat dit explicitement "tu gardes tes cartes".
3. **Choix d'event sans stats visibles** = frustration "j'ai pas vu venir". **Mitigation** : afficher au moins les *catégories* d'effet (gain / perte / risque).
4. **Pas de feedback de progression** dans les 5 premières minutes. Pas de niveau, pas de level-up. Juste profondeur + cartes. **Mitigation** : la profondeur D001→D006 est elle-même un score visible / leaderboard.
5. **Premier mur trop tôt** (D006) ou trop tard (D015) = soit décourage, soit ennuie. À calibrer.
