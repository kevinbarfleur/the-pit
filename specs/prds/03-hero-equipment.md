# PRD-03 — Hero & Equipment

## Goal

Définir le hero V1 (un seul personnage par défaut, identique pour tous), ses stats, et le système d'équipement à 4 slots actifs. Le hero est l'avatar de combat de joueur.

## Non-goals

- Multi-hero choisis par le joueur (V2)
- Personnalisation visuelle du hero (skins, palettes) V1
- Hero level / XP / level-up classique (V1 = pas de level, progression vient des cartes + passives)
- Cosmétiques / skins (V2)
- Gear stats randomisés (V1 = cartes statiques, pas de rolls — cf. PRD-07)
- 8 slots équipés (V1 = 4 actifs, +4 verrouillés progressifs V1.1)

## User stories

- En tant que **nouveau joueur**, j'arrive sur le pit et un hero est déjà créé pour moi (silhouette pixel art au centre du combat).
- En tant que **joueur**, j'équipe une carte dans un slot vide et je vois le hero stats updater (ex. +12 dmg).
- En tant que **joueur**, je swap une carte d'un slot et la stat différentielle est visible (+12 → +18).
- En tant que **joueur**, je vois mes stats hero condensées (HP max, dmg moyen, crit %, focus regen) avant chaque combat.

## Functional spec

### Hero V1

- **Nom** : "the descender" (pas modifiable V1)
- **Sprite** : silhouette pixel art neutre (ou character pre-rigged via `CharacterEngine`)
- **Stats de base** (pas équipé) :
  - HP max : 100
  - Damage base : 6
  - SPD base : 1.0
  - Crit chance : 5%
  - Focus regen : passif neutre (gain Focus seulement par crits)
  - Block : 0%

Stats finales = stats base + somme des contributions cartes équipées + bonus passives.

### Equipment V1

4 slots actifs débloqués dès T+0 :

| Slot | Type principal | Modificateur | Carte exemple |
|---|---|---|---|
| `mainhand` | Weapon | dmg, SPD, crit chance | "Iron Sword" — +12 dmg, SPD 1.0 |
| `body` | Armor | HP max, block | "Stoneward Tunic" — +30 HP, +8% block |
| `head` | Head gear | crit chance, focus regen | "Hollow Crown" — +6% crit, +1 focus regen |
| `charm` | Trinket | proc passif (on-hit, on-crit) | "Stoneward Charm" — on-hit: shield 8 |

Slots **verrouillés V1** (ne s'affichent pas) : `offhand`, `ring`, `relic`, `charm 2`. Débloqués via passives V1.1.

### Equip/unequip flow

- Au start : tous slots vides. Hero combat avec stats base seulement.
- Ajout d'une carte au inventory → si slot vide, **auto-equip silencieux** + log discret en bas écran "equipped: Iron Sword".
- Si slot occupé → loot draft popup (cf. PRD-07) propose le swap explicitement.
- Onglet `[C] Cards` : UI complète equip/unequip/swap manuel.

### Stats display

Avant chaque combat (popup pre-engagement, cf. PRD-06) :
- HP max : `100 + 30 = 130`
- Damage avg : `6 + 12 = 18 / hit`
- Crit chance : `5% + 6% = 11%`
- Focus regen : `+1 by crit, +6 base`
- Block : `8%`

Tooltip détaillé sur hover de chaque stat.

### Combat reset

- HP du hero **reset à HP max** au start de chaque combat (V1 simplification).
- Focus reset à 0 au start de chaque combat.
- Buffs/debuffs persistants entre combats : aucun V1 (V1.5 = certains).

## Technical approach

### Réuse existant

- `src/pixi/CharacterEngine.ts` — sprite state machine idle/attack/hurt déjà rigé
- `src/game/characters/types.ts` — types character rigging déjà définis
- `src/game/characters/palette.ts` — palettes existantes
- `src/game/characters/defs/*` — 12 enemy defs disponibles, peut servir de modèle pour hero def

### À créer

- `src/game/pit/hero.ts` :
  ```ts
  export const HERO_BASE = {
    hpMax: 100,
    damage: 6,
    spd: 1.0,
    critChance: 0.05,
    focusRegen: 0,
    block: 0,
  } as const

  export function computeHeroStats(base, equipped: Equipment, passives: PassiveId[]): HeroStats
  ```
- `src/game/characters/defs/hero.ts` : character def avec sprite + animations (réuse mécanique des enemy defs)
- `src/components/pit/HeroSprite.tsx` : composant pixi pour render hero in-combat
- `src/components/cards/EquipmentPanel.tsx` : UI 4 slots (à utiliser dans `/cards` cf. PRD-07)
- `src/components/cards/StatsPreview.tsx` : preview stats hero avec contributions par source

### Pre-conditions

- Equipment carte schema (cf. PRD-07) doit être finalisé pour que `computeHeroStats` puisse sommer.
- Combat engine (cf. PRD-04) consomme `HeroStats` via `computeHeroStats`.

## Data model

Étend `profiles.cardsEquipped` (cf. PRD-01) :

```ts
cardsEquipped: {
  mainhand?: CardId
  body?: CardId
  head?: CardId
  charm?: CardId
}
```

Pas de stockage des stats finales en DB — toujours dérivé à la volée depuis `cardsEquipped` + passives + base.

## Acceptance criteria

- [ ] Hero apparaît au centre du combat dès D001 sans équipement (stats base)
- [ ] Auto-equip d'une carte dans slot vide met à jour stats display en <100ms
- [ ] Swap explicite remplace la carte précédente, l'ancienne retourne à l'inventaire
- [ ] Stats preview pre-combat affiche stat **finale** + breakdown par source (base / mainhand / body / ...)
- [ ] Hero HP reset à HP max début de chaque combat
- [ ] 4 slots affichés dans `/cards`, slots non-équipables (offhand, ring...) NON visibles V1
- [ ] Hero sprite anime correctement (idle / attack / hurt) en combat (cf. PRD-04)

## Dependencies

- PRD-01 (profile.cardsEquipped schema)

## Open questions

- **Q3.1** Hero V1 = silhouette neutre pixel art ou un des 12 character defs existants (ex `templar.ts`) ? **Reco : créer une silhouette neutre dédiée** pour ne pas spoil les enemy looks.
- **Q3.2** HP reset full chaque combat V1, ou HP persistant entre combats avec heal at rest nodes ? **Reco V1 : reset full**, simplifie. V1.5 = HP persistant + rest nodes.
- **Q3.3** Hero peut-il avoir un **ult / active skill** propre (pas une carte) ? Style Hades / Risk of Rain. **Reco V1 : non**, Focus = unique action volontaire. V2 = considérer.
- **Q3.4** Stats display dans `/cards` onglet : barre comparative équipé vs non-équipé ? **Reco : oui, simple textuel** (`+18 dmg → +24 dmg with new sword`).
