# 09 — Consolidation post-review (2 agents externes)

> Doc de synthèse après review par 2 agents externes (un avis design, un audit avec sources). État : `consolidation`. Devient la **source de vérité** post-review pour la game loop. Les docs 01-08 restent comme matériau d'origine.

## Convergences fortes

Les deux agents convergent sur 6 points critiques. Les ignorer = échec V1 documenté.

| Sujet | Reco consolidée | Origine |
|---|---|---|
| **Threat tier / predicted depth** | Indicateur permanent visible. DPS estimé, threat ★ pré-combat, popup options après 3 retreats. | A1, A2 (R1 priorité absolue) |
| **Speed control combat** | x1 / x2 / x4 dès V1 (pas skip pur, mais speed up). | A2 doc 5 ; A1 push pour skip trivial-replays |
| **Milestones explicites** | Cérémonies à D10 / D25 / D50 / D100 + animation boss + lore drop. Pas optionnel. | A1, A2 (R4 mitigation) |
| **Onboarding non-bloquant** | 3-5 tooltips contextuels au moment où la mécanique apparaît. Pas de modal tutoriel. Premier combat **garanti winnable**. | A1, A2 (R5 = D1 retention) |
| **Leaderboard tiered + nearby** | Percentile prominent + bandes nommées (Surface / Shaft / Caverns / Abyss / Deeppit) + nearby ±5. All-time secondaire. | A1, A2 (R3) |
| **Authoritative Convex** | Convex = source unique de vérité. Client = optimistic UI uniquement. Anti-cheat critique pour leaderboard infini. | A2 (Q8 challengé) |

## Désaccords avec mes recos initiales

### Q9 — Skip combat

**Originale** : "Jamais V1".
**Consolidée** : **Speed control x1/x2/x4 V1**. Auto-skip trivial-replay V1.5 (quand player.power > 3× enemy threshold). Jamais skip sur boss / first clear.
**Raison** : forcer à regarder un combat trivial post-T+5h = corvée. Auto-battlers réussis (Path of Achra, TFT, Backpack Battles) ont tous du speed control. C'est une attente de genre.

### Slots de départ

**Originale** : 3 slots V1 (mainhand, body, charm).
**Consolidée** : **4 slots V1** (mainhand, body, head, charm).
**Raison** (A1) : 3 slots = build trop pauvre pour ressentir l'expression. 4 = sweet spot, garde 4 slots locked = motivation passifs.

### Q13 — Tabs dès T+0 ?

**Originale** : Tout débloqué T+0.
**Consolidée** : **Progressive disclosure**.
- T+0 : Pit + Cards (vide) + Codex
- T+1er node clear : tooltip "Cards" expliqué
- T+1er boss D10 : Leaderboard tab apparaît avec animation "you're on the board"
- Help docs montrent toutes features avec "unlock at D5" pour celles non débloquées
**Raison** : R5 onboarding. Voir leaderboard sans avoir de score = R3 hopelessness immédiate.

### Q4 — Replay degradation

**Originale** : Flat ×0.4.
**Consolidée** : **Flat ×0.4 V1** + instrumentation comportement de farm. Si abus détecté (top players spam un node) → switch progressif (×0.4 → ×0.20 → ×0.10) en patch.
**Raison** : pragma simplicité V1, ouverture au tuning par data.

### Q3 — Death sur boss

**Originale** : Verrouillage boss + clear N nodes.
**Consolidée** : **Coût torche majoré (×2-3) + cooldown 30 min réelles**. Pas de verrouillage logique.
**Raison** (A2) : verrouillage = OGame anti-pattern. Cooldown réel = force préparation sans frustrer.

## Nouveaux risques (R10-R14)

Identifiés par A2, validés.

### R10 — Cheating sur leaderboard infini (gravité 7/10)

Leaderboard `deepestDepth` comme seul score = aimant à tricheurs.
- Macros / bots qui jouent 24/7 (légalement)
- Multi-account exploit
- Scrap exploits via edge cases combat

**Mitigation V1** : authoritative Convex + rate limits + anomaly detection (gain depth +50 en 5min impossible) + shadow ban silencieux.

### R11 — Coût Convex à l'échelle (gravité 5/10)

Combat 4Hz × 1000 joueurs concurrents = 4000 mutations/sec. Pricing Convex scale linéairement.
**Plan B** : combat client-side avec hash/replay validation Convex (compromis perf vs anti-cheat).
**Action V1** : instrumenter coût/joueur dès le début, alerte si > X seuil.

### R12 — Burnout top players (gravité 6/10)

Top players à D850+ : chaque +1 depth coûte +24h grind. Pattern OGame fleeters. Sans seasonal reset, churn assuré.
**Mitigation V2** : seasons soft-reset trimestrielles + achievements lateraux + prestige cycle.
**Action V1** : architecturer le code pour permettre seasons sans rebuild.

### R13 — Audience Twitch ≠ idle audience (gravité 5/10)

Streamers cherchent contenu visuel + chat-interactif. Idle browser = peu naturel pour stream. Risque que la viralité Twitch ne se matérialise pas.
**Pistes** : Twitch chat integration (vote modifier, donate scrap, predict depth) ; boss event communautaire viewer-driven.
**Action V1** : intégration Twitch chat lite (chat overlay au stream du descent).

### R14 — Coût cognitif terminal aesthetic (gravité 4/10)

Terminal-first = niche. Magnifique pour devs, opaque pour Twitch large.
**Mitigation** : terminal-themed mais avec sprites 2D lisibles, colors juicy, animations. Pas terminal pur.

## Re-grade des risques originaux

Basé sur convergence des deux agents.

| # | Risque | Originale | Consolidée |
|---|---|---|---|
| R1 | Mur opaque | 8/10 | **9/10** (priorité absolue) |
| R2 | Combat passif après 5h | 7/10 | **6/10** (mitigé par speed + prep dense) |
| R3 | Leaderboard inaccessible | 6/10 | **7/10** (sous-évalué) |
| R4 | Pas de payoff perpetual | 7/10 | **8/10** (sous-évalué — milestones obligatoires) |
| R5 | Onboarding zéro | 6/10 | **7/10** (D1 retention killer) |
| R6 | Économie scrap | 5/10 | 5/10 (correct V1, monitor) |
| R7 | Farm prévisible | 4/10 | 4/10 (mitigation modifiers V1) |
| R8 | Tab discarding | 3/10 | 2/10 si Convex sync OK |
| R9 | Auto-equip frustration | 4/10 | 4/10 (toggle + log + pin V1) |
| R10 | Cheating leaderboard | — | **7/10** (nouveau) |
| R11 | Coût Convex échelle | — | 5/10 (nouveau) |
| R12 | Burnout top | — | 6/10 (nouveau) |
| R13 | Twitch ≠ idle audience | — | 5/10 (nouveau) |
| R14 | Coût cognitif terminal | — | 4/10 (nouveau) |

**Top 3 priorités V1** (cumul gravité × actionnable) : R1, R4, R5.

## Invariants V1 (non-négociables)

1. **Le seul score = `deepestDepth`** (cohérence R3)
2. **Convex authoritative** pour state critique (anti-cheat R10, recovery R8)
3. **Twitch login obligatoire** avant gameplay (overrides ancien Q7 anonymous-first — décision user). Page `/auth` ultra-épurée pour minimiser friction R5.
4. **Active descent > offline mining** strict (8h@25%, scrap only)
5. **Pas de pay-to-win** (préserve crédibilité leaderboard)
6. **Predicted depth indicator** omniprésent (R1)
7. **Speed control x1/x2/x4** dès V1 (R2)
8. **Milestones D10/D25/D50/D100** avec cérémonie (R4)
9. **Onboarding contextuel non-bloquant** post-login (R5)
10. **Browser-only desktop V1**, mobile-readable (Q10)

## Décisions stratégiques

### À acter immédiatement

1. **Reconsidérer prestige pour V1.5** sérieusement — l'absence est un risque structurel, pas une feature. Architecture du code prévoit le greffer.
2. **Seasons soft-reset dans la roadmap V2 explicite** — sinon R3+R12 cumul tuent D90+ retention.
3. **Authoritative Convex full** — non négociable.
4. **Onboarding = chantier #1** V1.
5. **Instrumentation D0** : metrics shippent avec V1, pas après.
6. **Patch hebdomadaire post-launch** modèle Backpack Battles.

### Ouvertes (à valider avec toi)

- **Hardcore mode optionnel** (permadeath + leaderboard séparé) V1 ou V2 ?
- **Daily seed challenge** Slay-style V1 ou V2 ?
- **Layers narratifs / biomes** (Surface 0-25, Shaft 26-75, Caverns 76-150...) — V1 ship 1 biome ou 2 ?
- **Mini-bosses intermédiaires** (D5, D17, D37) entre les boss majeurs V1 ?

## Sprint roadmap V1 (consolidée — 16 semaines)

### Sprint 1 — Foundations (4 sem)
- Combat 4Hz authoritative Convex
- Anonymous + Twitch login optionnel
- `currentDepth/deepestDepth` model + Convex schema
- Hub + biome 1 (D0-D25)
- Inventory cap 30 + auto-equip + log + pin
- **Predicted depth indicator** (R1 mitigation P1)
- **Speed control x1/x2/x4** (R2 mitigation)
- 4 slots équipés V1

### Sprint 2 — Core loop (4 sem)
- Boss D10, D25 + cérémonies (R4)
- Floor replay flat ×0.4 + 3 modifiers random (R7)
- **Onboarding contextuel** non-bloquant (R5 P1)
- Cards system (30 cartes V1)
- Codex + Cards tabs avec progressive disclosure (Q13)
- Offline scrap simulation (Q12)
- visibilitychange → flush state (R8)

### Sprint 3 — Engagement (4 sem)
- Leaderboard percentile + tier system + cohort (R3)
- Daily seed challenge optionnel
- Milestone celebrations animées D10/D25/D50/D100 (R4)
- Lore drops + biome 2 unlock (D26-D75)
- Twitch integration light (chat overlay)
- Anomaly detection + rate limits (R10)

### Sprint 4 — Polish & retention (4 sem)
- Auto-skip trivial combat (Q9 V1.5)
- Help docs in-game contextual
- Mobile-readable (Q10)
- Achievements lateraux pour top (R12)
- A/B test onboarding variants
- Instrumentation analytics complète

### V2 backlog (priorité décroissante)
1. **Seasonal soft-reset leaderboard** (R3, R12) — critique
2. **Prestige system** (R4, R12) — architecture déjà prête
3. **Hardcore mode** (Q11 variant)
4. **Mobile playable** full
5. **Co-op asynchrone / echoes** (Dark Souls-like)
6. **Twitch chat interactive deep** (vote modifiers, donate scrap)

## Variables tuner post-launch

| Variable | Range | Métrique pilote |
|---|---|---|
| Scrap accumulation rate | 0.5×–2× | Time-to-first-upgrade < 5min |
| Floor replay penalty | flat ×0.4 → progressif | Farm session length |
| Boss intervals | log [10,25,50,100] | Boss kill rate par cohorte |
| Inventory cap | 20–50 | Auto-sell rate |
| Offline cap | 4–12h, 20–35% | D2/D7 retention |
| Torch cost retreat | 1–3 base, ×N depth | Death rate |
| First mob kill TTI | <30s | D1 retention |
| First boss TTI | <90 min | D7 retention |

## Métriques à instrumenter dès V1

- **Funnel D0/D1/D7/D30** par cohorte (anonymous, twitch-logged)
- **Depth distribution** : où cratèrisent les joueurs
- **Time-to-first-boss-kill**
- **Session length distribution**
- **Retreat vs death rates par depth**
- **Scrap accumulation curves**
- **Combats où Focus utilisé** (R2 audit)
- **Floor replay frequency par node** (R7 abus detection)

## Sources et lectures clés

Issu de l'audit A2 :
- GDC Vault — Quest for Progress: Math of Idle Games (Pecorella)
- Game Developer — Postmortem: Loop Hero
- Yu-kai Chou — Leaderboard design Octalysis
- Solsten — D1/D7/D30 retention benchmarks
- Game Developer — Never trust the client (cheat prevention)
- Browser Games of Yesteryear (OGame analysis)

À consulter avant specs implémentation : Pecorella GDC + Loop Hero postmortem.
