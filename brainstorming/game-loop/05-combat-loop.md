# 05 — Combat loop (tick par tick)

## Persona

**Léa, en plein combat à D012.** Hero équipé : épée T1, armure T0, charm T1, focus slot vide. HP : 80/120. Ennemi : "Hollow Archer" T1, HP : 95.

## Format combat (rappel design)

- **Auto-battler** : ni hero ni ennemi ne sont contrôlés directement.
- **Action meters** par carte (côté hero) et par enemy.
- **Tick rate 4Hz** (250 ms par tick). Sert d'unité serveur.
- **Slots équipés** : 8 max. Chaque slot a son propre meter qui se remplit selon SPD de la carte.
- **Focus** : ressource depletable (max 100). +5 par hit critique. Le joueur peut consommer 50 Focus pour trigger immédiat d'une carte (skip de la jauge).
- **Pas de positioning V1** (pas de lanes, pas de range).

## Walkthrough tick-par-tick (60 ticks = 15s)

### Setup (T+0s, tick 0)

Affichage :
- En haut : enemy sprite + HP bar 95/95 + "intent : strike (heavy)"
- Au centre : 2 sprites face à face
- En bas : 8 card slots horizontaux (3 équipés colorés, 5 vides grisés). Chaque slot équipé montre une mini-jauge meter (vide à 0%).
- À droite : Focus orb (0/100), HP hero 80/120, nom de l'ennemi.

### Tick 0-12 (T+0s à T+3s) — premiers swings

```
tick  meter sword  meter charm  enemy meter  events
0     [          ] [          ] [          ]  
4     [▓▓▓       ] [▓▓        ] [▓▓        ]  
8     [▓▓▓▓▓▓    ] [▓▓▓▓      ] [▓▓▓▓      ]  
12    [▓▓▓▓▓▓▓▓██] [▓▓▓▓▓▓    ] [▓▓▓▓▓▓    ]  sword fires! -18 to enemy
```

Sword's meter remplit en 12 ticks (3s à SPD 1.0). Trigger → animation hit → -18 enemy HP. Meter reset à 0.

### Tick 14-20 (T+3.5s à T+5s) — enemy strike

```
tick  meter sword  meter charm  enemy meter  events
14    [▓         ] [▓▓▓▓▓▓▓▓▓ ] [▓▓▓▓▓▓▓▓▓ ]
18    [▓▓▓       ] [▓▓▓▓▓▓▓▓██] [▓▓▓▓▓▓▓▓██]  charm fires! +shield 12 (passive proc)
20    [▓▓▓▓      ] [          ] [██████████]  enemy fires! -22 hero (shield absorbs 12, -10 net)
```

Charm équipé "stoneward charm" a un trigger passif : quand prêt, applique shield à hero. Si shield existait au moment du hit, absorbe damage.

### Tick 24-30 (T+6s à T+7.5s) — premier crit

```
tick  meter sword  meter charm  enemy meter  events
24    [▓▓▓▓▓▓▓▓██] [▓▓▓       ] [▓▓        ]  sword fires! -22 (CRIT!) → +5 focus
```

Crit roll (10% base + bonuses passifs). Trigger flash visuel. Focus orb 0 → 5.

### Tick 32-44 (T+8s à T+11s) — joueur engage Focus

Léa observe : enemy HP 55/95, hero HP 70/120, focus 35/100. Voit que la sword va trigger dans 6 ticks. Décide d'attendre.

À tick 40, son sword atteint 100% naturel. Hit -18. Enemy 37/95.

Crit chain au tick 44 → +10 focus, focus 50/100.

### Tick 50 (T+12.5s) — Focus burst

Léa appuie `[Espace]`. Trigger immediat de la **prochaine carte la plus avancée**. C'est le sword (à 30% naturel). Force à 100% → hit -22 (regular). Enemy 15/95.

Focus 50 → 0.

> *Mental* : "j'aurais dû attendre que charm proc. tant pis."

### Tick 56-60 (T+14s) — finishing

Tick 56 : enemy fires → hit hero -18, hero 52/120.
Tick 60 : sword fires natural → -18 (crit roll échoue). Enemy 0/95. **Defeated.**

Combat terminé : 15s, hero à 52/120 HP. **Reward popup** : 3 cartes + 18 scrap.

## Décisions du joueur dans un combat

- (active) Quand consommer Focus (timing optimal : carte presque prête vs carte high damage)
- (active) **Avant combat** : choix de l'équipement (mais combat lui-même = pas de swap V1)
- (active) Retraite manuelle si situation désespérée (`R` pour escape — ramène au floor avec HP réduit)
- (passif) Tout le reste

## Implications techniques

- `engine.tick(dt)` côté client à 4Hz (250 ms simulation step). Server validation à un rate équivalent ou ralenti (anti-cheat via reseed serveur).
- Card data : `{ id, name, type, baseSpd, baseDmg, baseCrit, keywords[], passive?, active? }`. Type `passive` (auto-trigger sur meter full) vs `active` (consomme Focus).
- Enemy data : `{ id, hp, intents: [{ name, baseSpd, baseDmg, special? }] }`. Intent visible avant trigger.
- Action meter : float [0,1] par slot, `meter += spd * dt`. Trigger à >= 1.0 reset à 0.
- Focus : int [0, 100], +5 par crit, +10 par crit chain. Spend 50 = trigger next-most-advanced card.
- Combat resolution serveur-side au final : state hash envoyé pour validation.
- Animations : CharacterEngine déjà rigué (idle / attack / hurt). Combat reuse direct.

## Frictions potentielles

1. **Combat trop lent** (15-30s par fight) = pesant si pas tendu. **Mitigation** : si player.power >> enemy.power (ex : retours sur floor clear), accélération auto (tick 8Hz pour ce combat) ou skip-to-end avec cliff de loot.
2. **Combat trop rapide** = aucune décision, juste regarder. **Mitigation** : équilibrer SPD pour garantir au moins 1-2 décisions Focus par combat normal.
3. **Focus trop punitif** (timing) = joueur se sent forcé d'attendre passivement. **Mitigation** : V1 = Focus simple "trigger next ready card", pas de mini-jeu de timing.
4. **Animations / lisibilité** : 8 meters + intent + HP + focus = beaucoup à regarder. **Mitigation** : V1 limite slots équipés à 4 (visuels), 8 nominaux. Augmente progressivement.
5. **Auto-battler ennuyeux à long terme** = joueur regarde passivement. **Mitigation** : Focus + retreat sont les outils actifs. Si insuffisant, V1.5 = card swap mid-combat (consume torch).

## Notes design

Le combat est **active enough to require attention**, mais **pas demanding** (pas d'APM Slay). Cible idéale : 4-6 décisions par combat (placement Focus, retreat ou pas, timing crit chain).

Cf. Banner Saga (auto avec breakthroughs) > pure auto-chess (passif). Le combat doit rester regardable mais pas optionnel.

## Boss combat (différences)

- Durée : 60-120s.
- Multiple intents par boss, rotation visible.
- Phases (enemy HP < 50% = comportement change).
- Pas de Focus burst trivial → boss a immunités ou anti-crit windows.
- Loot garanti unique si win, rien si retreat ou wipe.
