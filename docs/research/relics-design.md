# Reliques — design & implémentation (chantier 2026-06)

> Doc autoritaire du système de reliques. Révise le **pilier #2** du CLAUDE.md : on PASSE d'un modèle
> *cryptique à déduire* (1-parmi-3 + leurres + identification) à un modèle **LISIBLE** (effet affiché
> clairement). On garde l'**ambiance** (nom évocateur + flavor) et la **collection** (Grimoire), on retire
> l'**énigme** (leurres/observation). Décision actée avec l'user (2026-06).

## 1. Principes (garde-fous)

1. **Lisible, pas cryptique.** Une carte de relique = `NOM` + ligne d'effet *évocatrice mais claire avec le
   chiffre* + `flavor` (ambiance pure). On comprend en ~2 s. Pas de leurres, pas de phase d'identification.
   Modèle Slay the Spire.
2. **Aucune relique ne handicape la suite de la partie.** Rien de **persistant cross-combat** sur les unités
   d'un joueur. Les reliques n'agissent qu'**intra-combat** (+ buffs de stats au build). → *Necrosis Eternal*
   (amputation permanente sur le run) **rejetée**. Toute amputation/altération meurt avec le combat.
3. **Égalisateur, pas portail.** Une relique fait *pencher* un matchup pour un build committé — jamais un
   gate à 100 %. Validation au `tools/runsim.lua` : OK si elle incline, pas si elle efface un counter.
4. **Chaque relique a un foyer.** Si on ne peut pas nommer « *ce build veut ça* », c'est du remplissage.
5. **Team-wide.** Les reliques s'appliquent à TOUTE la compo du joueur (pas de micro par unité).
6. **Déterministe.** Aucune relique n'introduit de RNG en combat (async-vérifiable, replay-safe).

## 2. Acquisition & méta (v1)

- **Récompense 1-parmi-3** tous les 3 combats gagnés (cérémonie type relique de boss) — `rollRelicChoices(3)`.
  Le choix « quelle relique parmi 3 » est conservé (bon choix StS) ; ce sont les **leurres par relique** qui
  disparaissent. Pas d'achat à l'or en v1 (les reliques ne concurrencent pas les unités).
- **Grimoire = collection** : repensé d'un *codex de déduction* en *vitrine des reliques rencontrées* +
  leur lore. `Grimoire.learn(id)` au **grant** (plus à l'identification). Persistant cross-run (méta).
- **Tout visible d'emblée** : pas de déblocage progressif des chiffres en v1.

## 3. Substrat moteur (vérifié en source — où chaque relique se branche)

| Prise | Permet | Détail vérifié |
|---|---|---|
| `R.apply(comp, relic)` (mutation de spec au BUILD) | +PV plats, +% atk, **+affliction `*Inc`**, **+défense**, conditionnels comptés | mute `spec.hp/dmg/poisonInc/…` ; `makeUnit` (arena:102) copie ces champs sur l'unité |
| ops `ampDps(base, ctx.source.*Inc)` | **+% dégâts d'affliction** | burn/poison lisent déjà `*Inc` (ops:66,119) ; **bleed/rot à étendre** (miroir, ~4 lignes) |
| `relic_add_effect` d'un `{trigger="combat_start", op="grant_team", …}` | **règles d'équipe** (pierceHeal, frenzy, invuln) | réutilise `teamFlags` (arena:144) + l'op `grant_team` (ops:248) — zéro nouveau code de POSE |
| hooks **gated** dans `Arena:damage` (arena:230) | défense (`dmgReduce`), invuln (`invulnUntil`), survie (`secondBreath`) | nil → inerte = **golden-safe** |
| lecture gated dans le tick regen (arena:477) | pierce-heal (anti-sustain) | les dots portent `.source` → on lit le `teamFlags` de l'afflicteur |
| broadcast `on_death` (arena:566) | frenzy/rally au kill | déjà différé hors-réentrance |
| `RunState` | éco/méta (différé) | SIM-pur |

**makeUnit copie déjà** `poisonInc, burnInc` (arena:117) → j'ajoute `bleedInc, rotInc, dmgReduce` (+ flags).

## 4. Taxonomie (du plus simple au plus original)

- **A — Stats plates** (universelles) : +PV, +% atk, -% dégâts subis, +vitesse d'attaque*. *(attaque-vitesse =
  plomberie cooldown → vague ultérieure.)*
- **B — Amplis conditionnels** : +% **affliction** (poison/burn/bleed/rot), +% par **famille**, +position
  (avant/arrière). **Le cœur build-shaping.**
- **C — Paliers / payoffs** : « si 4+ partagent une affliction → perce les soins » (Hollow Choir, anti-sustain),
  « ≤3 unités → +% » (Famine's Math, *tall*), snowball au kill (Feeding Frenzy → payoff bruiser).
- **D — Défensives / tech** : survie à 1 PV 1×/combat (Second Breath), ignore 1ʳᵉ affliction, **0,5 s d'invuln
  d'ouverture** (Sacred Shield).
- **E — Transformatives** (intra-combat) : choc rebondit (Forked Tongue), burn ne décroît plus / se propage à
  la mort, poison sans cap, bleed n'expire plus, 2+ afflictions → +dégâts (Plague Communion).
- **F — Globales / événements** : rally à la mort d'un allié, explosion du 1ᵉʳ mort (spread), +dégâts/seconde.
- **G — Topologie / sigils** *(DIFFÉRÉ — chantier dédié)* : ajoute une arête au sigil, centre buffe tout,
  adjacence diagonale, 6ᵉ sigil. Le plus signature ET le plus cher.

**Reliques maudites** (effet + contrepartie) : **hors v1** (en tension avec le principe #2). Option ultérieure.

## 5. Carte archétype → relique (intégration + problèmes ouverts réglés)

| Archétype | Relique | Règle un problème ouvert ? |
|---|---|---|
| Poison (apex) | spread/portée (latéral, **pas** +dps brut) | adoucit l'apex sans le casser |
| **Burn** (faible) | Everburn + Hollow Choir | **burn vs tank/regen** ✅ |
| Bleed | Open Wounds / perce-armure | tempo durable |
| Rot | +% rot + spread-à-la-mort (intra-combat) | tueur de tank (dosé) |
| **Shock** | Forked Tongue (rebond) | **fragilité shock** ✅ |
| Tank | Second Breath / taunt instrippable | le mur |
| **Bruiser** | Feeding Frenzy (snowball) | **payoff bruiser** ✅ |
| **Tall** | Famine's Math | **viabilité tall** ✅ |
| Wide | Swarm Logic | récompense le large |
| Duplicatas | Apex Predator | récompense le leveling |

## 6. Plan de vagues (chacune verte + sim'd + commit)

- **Vague 1 — cœur lisible + amplis (CE CHANTIER)** : simplifier le système (retirer leurres/identification),
  plomberie `*Inc` bleed/rot + `dmgReduce`, et **7 reliques** : `bloodstone` (+%atk), `carapace` (+PV),
  `aegis` (-%dégâts), `kings_bowl` (+poison), `ember_heart` (+burn), `weeping_nail` (+bleed), `grave_cap` (+rot).
  Mesure : un archétype committé + son ampli incline un mauvais matchup (burn inclus).
- **Vague 2 — paliers** : Hollow Choir (pierceHeal), Famine's Math (tall), Feeding Frenzy (kill-snowball).
- **Vague 3 — défensives/globales** : Sacred Shield (invuln 0,5 s), Second Breath, rally.
- **Vague 4 — transformatives** : Forked Tongue, Everburn, Plague Communion…
- **Vague UI** (après icônes du pixel-art-master) : carte lisible (effet+flavor+icône), rangée type StS
  au-dessus du shop + hover, écran Grimoire-collection.
- **Différé** : G (topologie/sigils), reliques maudites, achat à l'or, attaque-vitesse.

## 7. Modèle de données (v1, lisible)

```lua
-- src/data/relics.lua : R[id] = { id, op, params, tier? }  (PLUS de realKey/decoys)
-- i18n : relic.<id>.name / relic.<id>.effect / relic.<id>.flavor
-- run : self.relics = { { id }, ... }   (PLUS de candidates/observed/identified)
```

Ops `R.apply` : `relic_flat_hp`, `relic_more_dmg` (existants) + `relic_affliction_inc {family, inc}`,
`relic_dmg_reduce {frac}`, `relic_add_effect` (existant, sert les team-rules via `grant_team`).
