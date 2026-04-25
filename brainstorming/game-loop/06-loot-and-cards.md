# 06 — Loot & cards

## Persona

**Léa, après son 50e combat.** Inventaire : 22 cartes. 8 équipées. 14 dans le bag.

## Modèle de carte

Chaque carte = un **item équipable** (pas une carte one-shot type Slay). Persistante, drop par les ennemis, équipée dans un des 8 slots, modifie les stats hero ou ajoute un keyword/proc.

```
┌────────────────────────┐
│  ◆◆◇◇◇        T1       │  ← tier
│                        │
│   STONEWARD CHARM      │  ← name
│                        │
│   +12% block           │  ← stat
│   on hit: shield 8     │  ← active proc
│                        │
│   [BODY · CHARM]       │  ← slot tags
└────────────────────────┘
```

### Tiers

| Tier | Couleur | Drop frequency global | Stat range | Origine |
|---|---|---|---|---|
| **T0** Bone (basic) | bone | 60% | low | combat trash |
| **T1** Iron | gild | 30% | medium | combat / elite |
| **T2** Etched | amber | 8% | high | elite / boss |
| **T3** Obsidian | violet | 1.8% | very high + unique passive | boss |
| **T4** Pit-touched | red | 0.2% | unique mechanic | deep boss / ascensions |

### Slots

- `mainhand` (1) — weapon, damage type
- `offhand` (1) — secondary weapon / shield
- `body` (1) — armor, HP
- `head` (1) — focus regen / crit
- `charm` (2) — proc passifs
- `ring` (1) — utility (luck, scrap%)
- `relic` (1) — meta passifs

V1 : commence avec **3 slots débloqués** (mainhand, body, charm). Autres slots débloquent via passifs (Body II → +1 charm, Edge II → ring, etc.).

## Pool de cartes

V1 ship avec **30 cartes** définies (10 par mainhand/offhand/body, à répartir). Pool est :
- **Ouvert dès le départ** (pas de débloquages séquentiels)
- **Filtré par depth** : floor depth détermine pool de tiers possibles. Ex : D1-D10 = T0/T1 only. D11-D25 = T0/T1/T2. D25+ = +T3 rare.
- **Dégradé sur replay** : si floor déjà clear, pool descend d'un tier max (cf. doc 03).

## Drop UI (post-combat)

```
┌──────────────────────────────────────────────────────┐
│  TAKE ONE                                            │
│                                                      │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐         │
│  │ STONEWARD│   │ HOLLOW   │   │ ASH-ETCHED         │
│  │  CHARM   │   │  BOW     │   │   BAND             │
│  │   T1     │   │   T0     │   │   T1               │
│  │ +12% blk │   │ +8 dmg   │   │ +5% scrap          │
│  └──────────┘   └──────────┘   └──────────┘         │
│                                                      │
│  [skip] [reroll · 1 ✦]                               │
└──────────────────────────────────────────────────────┘
```

3 cartes proposées. Player choisit 1 (ou skip avec petit scrap reward).

Reroll coûte 1 Shard (`✦` ressource rare, drop boss). Cap 1 reroll par combat.

Si bag plein (cap V1 = 30 cartes ?), force à fuse ou disenchant 1 carte avant accept.

## Equip flow

Quand carte ajoutée à bag :
- **Auto-equip** si slot vide.
- **Sinon** popup "swap with X ? (current)" — show diff stats.
- **Sinon** carte stockée bag, equip plus tard via `[C] Cards`.

## Fuse / disenchant

V1 minimal :
- **Fuse** : 3 cartes du même nom + tier → 1 carte +1 tier (max T3 V1, T4 inaccessible par fuse).
- **Disenchant** : 1 carte → scrap (T0 = 5, T1 = 12, T2 = 30, T3 = 80, T4 = 250).
- Pas de re-roll de stats. Cartes sont des items définis, pas randomized stats.

## Décisions du joueur

- (active) Choix dans le draft 3-en-1 (synergie vs power vs nouveauté)
- (active) Equip ou stocker
- (active) Fuse ou disenchant (long terme)
- (active) Reroll ou pas (économie shards)
- (passif) Pool généré par depth + state du floor

## Implications techniques

- `cards/data.ts` : registry de 30 cartes statiques. Schema strict.
- Loot generator : `generateLoot(depth, floorState, count = 3)` → renvoie 3 cartes du pool, dégradé si replay.
- Inventory côté Convex : `cardsOwned: Card[]`, `cardsEquipped: Record<Slot, CardId | null>`.
- Equip mutation : `equipCard(playerId, cardId, slot)` — validates card.slotTags includes slot.
- Fuse mutation : `fuseCards(playerId, cardIds[3])` — validates same name+tier, removes 3, adds 1 next-tier.
- Bag cap V1 : 30. Au-delà, force decision avant nouveau drop.

## Frictions potentielles

1. **Pool 30 cartes trop petit** à T+10h = inventory full de doublons. **Mitigation** : fuse permet de "cleaner". V1.1 ship 60-100 cartes.
2. **Force-decide bag plein** = interrompt le flow combat → loot. **Mitigation** : popup compact, action 1-clic (fuse auto si possible).
3. **Choix draft trop opaque** (cartes T0 vs T1, lequel best?) = paralyse. **Mitigation** : tier visible + ranking visuel (étoiles). Tooltip détail à hover.
4. **Reroll mécanisme inutile si Shards rares** = feature morte. **Mitigation** : drop shards plus que prévu OU activer reroll via scrap (50 scrap = 1 reroll).
5. **Slots progressifs frustrants** = "j'ai un super charm mais pas de slot pour le mettre". **Mitigation** : ouvrir 4 slots par défaut V1 (mainhand, body, head, charm). Garder 3-4 slots locked = motivation passifs.
6. **Pas de "build identity"** = chaque drop force un swap incrémental. **Mitigation V1.1** : cartes set / synergies de keyword (3 cartes "blood" = +bonus cumulé).

## Notes design

Le loot doit donner **"oh tiens, à voir si je swap"** régulièrement, sans **"raah encore un T0 inutile"** trop souvent. Cible : ~30% des drops sont strict-upgrades à équipement actuel, ~30% sont latéraux (synergie possible), ~40% sont disenchant/fuse.

Pas de "trash drops" — V1 garde 100% des drops fuse/disenchantable, pas de loot vendor pur.
