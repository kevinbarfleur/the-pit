# 04 — Macro progression (1h / 5h / 20h jouées)

## Persona

**Léa, sur 3 semaines.** Joue ~30 min/jour en moyenne. Représente le joueur "engagé mais pas hardcore" — la cible centrale.

## Horizons

### T+1h jouées (cumul)

- `deepest = D015` ± 3
- ~12 cartes possédées, 6-8 équipées
- Scrap accumulé : ~600
- Passifs achetés : 2-3 (Body I, Edge I)
- Premier boss (D010) battu
- Une session de farm (doc 03) déjà vécue
- Sentiment : "découverte". Encore plein de surprises.

### T+5h jouées

- `deepest = D045` ± 10 (2-3 boss battus : D10, D25, D40 — si boss every 15 V1)
- Inventaire saturé (~30 cartes, force à disenchant/fuse — **fonctionnalité requise V1**)
- Scrap : ~3000 cumulé / ~800 en main
- Passifs : 8-12 acquis. Choix de tree commence à se sentir.
- Leaderboard : Léa est à 30% du top. Voit que les top sont à D200+.
- Sentiment : "maîtrise". Sait quand farmer, quand push. Frustration ponctuelle sur murs longs.

### T+20h jouées

- `deepest = D110` ± 30
- Multiples passifs maxés dans 1-2 trees, autres trees partiellement développés
- Scrap : décroissance d'utilité (tout cher à acheter, gains relatifs faibles → "soft wall scrap")
- Cartes : pool stabilisé, focus sur synergies (8 cartes ciblées, fuse pour upgrade)
- Sentiment : "optimisation". La descente continue mais chaque +5 depth coûte 30 min de farm. Engagement risqué de tomber sans payoff visible.

## Courbes de pouvoir

### Power vs Depth (qualitatif)

```
power
  │                           ╱╱─── soft cap (passifs maxés)
  │                       ╱╱╱
  │                   ╱╱╱
  │              ╱╱╱
  │         ╱╱╱
  │    ╱╱╱
  │ ╱╱
  └────────────────────────────────── depth
   D0   D20   D50   D100   D200
```

- Pente raide initiale : chaque passif change le combat
- Plateau autour D80-D120 : passifs au prix où l'incrément se sent peu
- Plateau dur D200+ : c'est un grind pur (top du leaderboard)

### Depth gating attendu

Le joueur "moyen" attend **un mur tous les 8-15 floors**. En dessous : sentiment trop facile. Au-dessus : sentiment de wall infini.

Boss tous les `N` (V1 : N=15 par doc 02 ? À trancher). Le boss est une release valve de progression.

## Déblocages au fil du temps

| Horizon | Débloque |
|---|---|
| T+15min | 2nd carte slot ouvert |
| T+1h | 4 carte slots ouverts (sur 8 max) |
| T+3h | 6 carte slots, premier passif Depth tree |
| T+10h | 8 slots full, accès "fuse cards" (upgrade T0→T1) |
| T+20h | Tous trees ouverts |
| T+50h | (post-MVP) prestige ? |

À noter : pas de déblocage "feature majeure" tardif. V1 = tout est exposé tôt, profondeur vient des nombres et de la stratégie.

## Leaderboard rôle macro

- **Visible dès T+0** (onglet L), même vide.
- Top 100 = ~D300+. Léa au top 1000 vers T+10h.
- Mécanisme social : voir qu'un autre joueur a clear D156 hier soir = motivation à push.
- **Risque** : top players grindent 16h/jour, écart insurmontable, milieu décroche. Cf. doc 07.

## Implications techniques

- Le profil Convex doit tracker beaucoup : `currentDepth, deepestDepth, totalScrap, totalSpent, passivesOwned[], cardsInventory[], cardsEquipped[], lastSeenAt, totalPlayTimeMs`.
- Card fuse system requis dès V1 (sinon inventaire explose à T+5h).
- Scaling de loot/rewards par depth doit être paramétrable (ne pas hardcoder, cf. `rewardScale.ts` existant).
- Leaderboard query doit gérer 10k+ joueurs avec pagination + position du joueur courant (`getRank`).
- Soft cap scrap = mecanique tunée (cost passifs croît). À surveiller via metrics post-launch.

## Frictions potentielles

1. **Soft wall T+20h** : si pas de nouveau contenu (boss différent, mécanique nouvelle), le joueur s'arrête. **Mitigation V1** : leaderboard pousse, V1.1 : plus de boss types.
2. **Inventaire ingérable T+5h** : sans fuse, 30 cartes de tier mixte = chaos. **Mitigation** : ship fuse/disenchant V1.
3. **Top du leaderboard hors d'atteinte** : mid-table décroche. **Mitigation** : leaderboards segmentés (weekly reset ? saison ?). À trancher (doc 08).
4. **Plateau de pouvoir** : passifs achetés ≠ sensation de power-up perceptible. **Mitigation** : chaque passif doit changer un nombre **visible** en combat (ex : crit 12% → 18%, "tu vois la diff").
5. **Pas de sense of completion** sur perpetual descent : pas de "fin". Risque burnout sans goal défini. **Mitigation** : milestones secondaires (titres : "Descender D50", "First Pit Warden", "Collector 50 cards") pour donner des points d'arrêt mentaux.

## Notes design

Le **sweet spot** est T+1h à T+10h. C'est là que la boucle est la plus serrée : push, mur, farm, spend, push. Avant : découverte, après : optimisation longue.

V1 doit prioriser cette tranche. Tout ce qui sert T+20h+ (prestige, deep meta) attend.
