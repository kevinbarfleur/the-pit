# 08 — Open questions

> Questions design pas tranchées après les docs 01-07. Chaque entry = la question + les options + ma recommandation V1.
>
> **État `iteration` post-review** : recommandations révisées suite à audit par 2 agents externes. Reco originale + reco consolidée listées quand divergent. Voir doc 09 pour la synthèse.

## Q1 — Que se passe-t-il quand le hero "meurt" en combat ?

**Options** :
- (a) **Retreat auto** : retour au floor précédent, garde tout (cartes, scrap), pas de pénalité.
- (b) **Retreat avec coût** : -1 torche, retour précédent, garde tout.
- (c) **Retreat avec perte** : retour précédent, perd 50% du scrap collecté lors de cette session active.
- (d) **Kick to surface** : retour à D001, garde équipement.

**Recommandation V1** : (b). La torche devient l'unique "punition" du wipe. Suffisamment léger pour ne pas frustrer, suffisamment réel pour être un coût.

**Implication** : torche capée à 5 V1, regen 1 par 30 min offline ou 1 par 5 floors clear actifs. Si 0 torche → forcé à attendre / clear faciles avant nouveau combat.

---

## Q2 — Boss : à quels intervalles ?

**Options** :
- (a) Tous les 10 (D10, D20, D30...) — fréquent, risque de monotonie
- (b) Tous les 15 (D15, D30, D45...) — équilibré
- (c) Tous les 25 (D25, D50, D75...) — rare, chaque boss = événement
- (d) Variable : D10, D25, D50, D100 (escalation logarithmique)

**Recommandation V1** : (d) avec un seul boss visuel V1 répété (Pit Warden) à D10 et D25. V1.1 ship plus de variétés.

**Implication** : map gen doit placer boss aux profondeurs fixes, garantir convergence des paths.

---

## Q3 — Death sur boss : pénalité spéciale ?

**Options** :
- (a) Identique au death normal (Q1)
- (b) Boss verrouillé pendant cooldown 5 min après wipe
- (c) Boss verrouillé jusqu'à ce que le joueur clear N nodes alentour
- (d) Coût torche × 3 par tentative boss

**Recommandation V1** : (c) + 1 torche. Force le joueur à grind un peu avant retry, sans timer punitif.

---

## Q4 — Floor replay : dégradation progressive ou flat ?

**Options** :
- (a) **Flat ×0.4** dès le 1er replay (simple)
- (b) **Progressive** : 1er replay ×0.6, 2e ×0.4, 3e+ ×0.2
- (c) **Cooldown** : un floor clear ne peut être replay qu'après 30 min réel
- (d) **Pas de dégradation** sur drops, juste sur scrap

**Recommandation V1** : (a). Simplicité. Tracker `times-cleared` est P2.

---

## Q5 — Comment scrap se compare à shards (✦) ?

**Options** :
- (a) Scrap = soft (commun, achete passifs), Shards = hard (rare, reroll loot)
- (b) Scrap unique, shards renamed/abandonnés
- (c) Shards = monnaie post-boss only, achète perks distincts

**Recommandation V1** : (a). Garde shards comme ressource luxury (rare).

**À trancher** : drop rate shards. V1 propose : 1 shard par boss + 1% chance par elite. Cap inventaire 99.

---

## Q6 — Inventaire cap : hard cap ou soft warning ?

**Options** :
- (a) **Hard cap** 30 cartes : force decision avant nouveau drop
- (b) **Soft warning** : pas de cap, mais UI orange à >30
- (c) **Cap croissant** par passifs ("Cellar I : +10 cap")

**Recommandation V1** : (a). Force fuse/disenchant comme verbe actif.

---

## Q7 — Twitch login obligatoire ?

**Options** :
- (a) **Anonymous + Twitch optionnel** (V1 actuel) : UUID local, leaderboard non-Twitch nameless
- (b) **Twitch obligatoire** : requiert auth pour jouer
- (c) **Anonymous-only** : pas de Twitch V1

**Recommandation V1** : (a). Onboard frictionless, Twitch login = unlock du leaderboard public + badge.

---

## Q8 — Save state : qui pousse ?

**Options** :
- (a) Convex source of truth, client read-only après mutation
- (b) Client garde un cache LocalStorage pour reload offline, sync avec Convex au focus
- (c) Hybrid : combat client-side (4Hz local), résolution + state push à Convex au end-of-combat

**Recommandation V1** : (c). Combat fluid local, validation + persist au combat-end.

**Risque** : anti-cheat. Convex valide en re-running le combat avec le seed serveur, doit matcher hash client.

---

## Q9 — Skip combat (auto-resolve) — disponible quand ?

**Options** :
- (a) Jamais (tout combat doit être joué)
- (b) Combats où player.power > enemy.power × 2 (auto-resolve avec animation rapide)
- (c) Player toggle "auto skip when easy" (option settings)
- (d) Toujours skipable, perd un % de loot si skip

**Recommandation V1** : (a) — tous les combats jouent. V1.1 : (b) auto pour replay clear floors.

---

## Q10 — Mobile / responsive : V1 ou V2 ?

**Options** :
- (a) Desktop-first V1, mobile pas testé
- (b) Mobile-friendly V1 (responsive minimum, controls touch)
- (c) Mobile-first V1 (target Twitch chat audience)

**Recommandation V1** : (a). Desktop only. Mobile = V2 si feedback le demande.

---

## Q11 — Death = reset depth ou pas ?

Cette question revient explicitement au modèle "perpetual descent" (memoire) :

> **Memoire dit** : "currentDepth, deepestDepth — pas de run, perpetuelle descente."

Ça implique que `currentDepth` ne reset jamais sauf cas spécifique. Mais si joueur peut re-monter via map navigation, alors `currentDepth` doit suivre la position actuelle dans le map. Donc :

**Modèle V1** :
- `currentDepth` = position actuelle dans le map (peut descendre OU monter via re-engage)
- `deepestDepth` = max ever atteint (jamais décroit)
- **Death (Q1)** = retreat 1 floor up, donc `currentDepth` -1.

Cohérent. Pas de "run" object. Confirmé.

---

## Q12 — Offline mining : quoi exactement ?

**Spec CLAUDE.md** : 8h cap, 25% rate, no depth, no boss, no rare/T0 first drops.

**Question concrète** : qu'est-ce que le joueur gagne offline ?

**Options** :
- (a) Scrap only (les T0 cartes drops mais sont auto-disenchant en scrap → simple)
- (b) Scrap + cartes T0 brutes (limit de 5 max)
- (c) Scrap + 1 carte tirée pool depth-restricted

**Recommandation V1** : (a). Évite la complexité d'inventory offline. Joueur revient à un scrap bonus, pas un loot.

---

## Q13 — Quand débloquer "Cards" / "Codex" / "Leaderboard" tabs ?

**Options** :
- (a) Tout débloqué dès T+0 (même si vide)
- (b) Cards à T+0, Codex après 1er event, Leaderboard après 1er boss
- (c) Tout après T+15 min de jeu

**Recommandation V1** : (a). Pas de drip-feed UI V1. Onglets vides ok.

---

## Items à valider avec utilisateur (toi)

- ✋ **Q1, Q3, Q4** : système de pénalité au death (torche, cooldown boss, replay dégradation). Choix de gameplay impact.
- ✋ **Q2** : intervalle des boss + scope (1 boss visuel répété V1 ou plusieurs ?).
- ✋ **Q5** : utilité concrète des shards V1.
- ✋ **Q9** : skip combat = jamais V1, ou auto-easy V1 ?
- ✋ **Q11** : confirmer le modèle "currentDepth = position courante, deepestDepth = max".

Les autres (Q6-Q8, Q10, Q12-Q13) ont des défauts pragmatiques que je propose de garder sauf objection.

---

## Révisions post-review (2 agents externes)

Détail complet dans doc 09. Synthèse des changements ici.

### Reco changée — Q3 (death sur boss)

**Originale** : verrouillage boss + clear N nodes + 1 torche.
**Consolidée** : **coût torche majoré (×2-3) + cooldown 30 min réelles**. Pas de verrouillage logique.
**Raison** : verrouillage = anti-pattern OGame, double-pénalité avec Q1. Cooldown réel force préparation sans frustrer.

### Reco changée — Q9 (skip combat)

**Originale** : jamais V1.
**Consolidée** : **speed control x1/x2/x4 dès V1**. Auto-skip sur trivial-replays V1.5 (player.power > 3× enemy threshold). Jamais skip sur boss / first clear.
**Raison** : forcer à regarder un combat trivial = corvée post-T+5h. Tous les auto-battlers réussis (Path of Achra, TFT, Backpack Battles) ont du speed control — c'est une attente de genre.

### Reco changée — Q13 (tabs)

**Originale** : tout débloqué T+0.
**Consolidée** : **progressive disclosure**. Pit + Cards (vide) + Codex à T+0. Leaderboard apparaît au 1er boss D10 (animation "you're on the board"). Help docs montrent tout avec "unlock at DN" pour les non-débloqués.
**Raison** : voir leaderboard sans score = R3 hopelessness immédiate. Progressive disclosure = best practice onboarding (cf. R5).

### Reco changée — Q4 (replay degradation)

**Originale** : flat ×0.4.
**Consolidée** : **flat ×0.4 V1 + instrumentation** des comportements de farm. Si abus détecté (top players spam) → switch progressif (×0.4 → ×0.20 → ×0.10) en patch.
**Raison** : pragma simplicité V1, ouverture au tuning par data.

### Reco changée — Q8 (save state)

**Originale** : hybride client/Convex (combat client-side, validation push end-of-combat).
**Consolidée** : **Convex source-of-truth full**. Client = optimistic UI uniquement. Combat 4Hz validé serveur (mutations atomiques OU batch hash validation).
**Raison** : leaderboard infini = aimant à tricheurs (R10 nouveau). Hybride = vulnérabilité. Non-négociable.

### Reco changée — Q6 (inventaire)

**Originale** : hard cap 30, force decision avant nouveau drop.
**Consolidée** : **hard cap 30 + auto-sell quand full** (préfère scrap-back au blocage). Log clear "auto-sold 3 items for 18 scrap". Tuner par data.
**Raison** : blocage drop = friction administrative (R9 cousin). Auto-sell = sink scrap régulier (R6).

### Confirmé sans changement

- **Q1** : retreat -1 floor + coût torche (validé par les 2 agents)
- **Q2** : boss D10/D25/D50/D100 logarithmique (validé) — A2 ajoute "considérer mini-bosses D5/D17/D37 pour densifier"
- **Q5** : scrap soft, shards hard (validé)
- ~~**Q7** : anonymous + Twitch optionnel~~ **OVERRIDE user (post-PRD)** : **Twitch login obligatoire** dès `/auth`. Trade-off accepté : +friction onboarding (mitigation `/auth` ultra-épurée), mais leaderboard 100% identifié + simplification anti-cheat + UX cohérente Twitch audience.
- **Q10** : desktop V1, mobile-readable au minimum (validé)
- **Q11** : currentDepth/deepestDepth (validé)
- **Q12** : scrap only offline (validé)

### Slots de départ — décision séparée

**Originale** (doc 06) : 3 slots V1.
**Consolidée** : **4 slots V1** (mainhand, body, head, charm).
**Raison** (A1) : 3 = build trop pauvre, 4 = sweet spot expression. Garde 4 slots locked = motivation passifs.

---

## Nouvelles questions ouvertes (post-review)

- ✋ **Q14** : Hardcore mode optionnel (permadeath + leaderboard séparé) — V1 ou V2 ?
- ✋ **Q15** : Daily seed challenge Slay-style — V1 ou V2 ?
- ✋ **Q16** : Layers narratifs / biomes (Surface 0-25, Shaft 26-75, Caverns 76-150...) — V1 ship 1 biome ou 2 ?
- ✋ **Q17** : Mini-bosses intermédiaires (D5, D17, D37) entre les boss majeurs — V1 ou V2 ?
- ✋ **Q18** : Prestige V1.5 ou V2 ? L'absence est un risque structurel (R4+R12). Architecture du code prévoit déjà le greffer.
- ✋ **Q19** : Seasons soft-reset trimestrielles dans la roadmap — V2 explicite ?
