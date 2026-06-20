# The Pit — Modèle d'escalade par paliers (T1/T2/T3) : le MOULE des familles d'effets

> Recherche 2026-06 sous la Règle d'or (sources primaires + Exa, citées par URL). **Périmètre :**
> le **framework de paliers** (enabler → twist → transform) et son **imbrication avec nos signatures**
> (adjacence, duplicatas 3→niveau). Les familles concrètes (DoT, choc, shield, aggro, vitesse) sont
> traitées par d'autres agents — ce document fournit le **gabarit réutilisable** à remplir pour chacune.
> Lectures liées : `gd-research-result.md` (adjacence, duplicatas), `engine-architecture.md` (effet =
> `{trigger, op, params}`), `combat-model-decision.md` (ciblage déterministe, exposition-sigil).

---

## TL;DR

- La **« règle des 3 paliers »** du créateur est validée et alignée sur un vocabulaire de design établi.
  Renommage proposé : **T1 = ENABLER** (amorce une condition/altération), **T2 = TWIST** (enabler + UNE
  interaction qui crée un payoff local), **T3 = TRANSFORM/KEYSTONE** (redéfinit l'archétype, débloque une
  compo atypique). C'est exactement le couple **enabler / payoff / bridge** de la théorie deckbuilder
  (Command Zone, communauté Slay the Spire) et le **keystone** de PoE.
- **Le ratio 5/3/2 par famille est globalement bon, mais à corriger : vise 5 T1 / 3 T2 / **1-2** T3.**
  Raisons sourcées : (a) la complexité **doit** se concentrer dans peu de cartes (NWO de MTG ; commons =
  « une seule chose ») ; (b) un T3 = un **point de bascule** : 2 par famille suffisent et **un seul fort
  T3 par famille** réduit le risque de « meta résolue ». 5/3/2 reste acceptable si le 2ᵉ T3 est un
  *transform latéral* (oriente vers une AUTRE famille) plutôt qu'un 2ᵉ finisher de la même.
- **Template T1/T2/T3** (puissance, complexité, condition, rôle dans la courbe de run, pièges) fourni
  §3 — c'est le moule à copier-coller par famille.
- **Catalogue d'archétypes transposables** (§4) : ~10 patterns de TWIST (T2) et ~9 de TRANSFORM (T3)
  applicables à *n'importe quelle* famille, chacun mappé sur nos triggers/ops existants.
- **Imbrication signatures** (§5) : **les T1/T2 scalent par niveau** (3→copies, modèle SAP/TFT),
  **les T3 ne scalent PAS leur effet de bascule** (le niveau renforce les *stats*, pas le déclencheur) —
  garde-fou anti-snowball. **L'adjacence peut conditionner un twist** (le voisin = la cible du payoff),
  mais un T3 ne doit **jamais** dépendre d'une seule case précise (fragile au changement de sigil).

---

## 1. La règle des 3 paliers : formalisée et challengée

### 1.1 Le vocabulaire établi (ce que le créateur a réinventé, et qui le valide)

Le cadre « classique → twist → légendaire transform » recoupe **mot pour mot** une taxonomie connue du
design de jeux à synergies. Trois sources primaires convergentes :

- **Slay the Spire / deckbuilders — « Set-Up » vs « Pay-Off ».** Game Developer (postmortem Neurodeck,
  qui cite explicitement « a taxonomy commonly used in the Slay The Spire community ») :
  > « A "set-up" card is a card you might want to play for its effect alone, but that also allows a chain
  > reaction with other cards… Set-ups do not exist "by themselves", but are tied to specific pay-offs. »
  > « A "pay-off" card offers a strong synergy with a particular set of set-ups… you are rewarding the
  > player for performing a set of specific actions. »
  > « We call a group of set-up and pay-off cards that work together an **archetype**. »
  (https://www.gamedeveloper.com/design/archetypes-in-deckbuilding-games)
- **Command Zone / Commander — enabler / payoff / enhancer + bridge.** Un *enabler* crée la condition,
  un *payoff* la récompense, un *bridge* fait les deux à la fois.
  > « Enablers create the conditions… Payoffs reward those conditions… A common problem is running too
  > many enablers and not enough payoffs (your engine runs but doesn't kill). »
  > « Cards that serve as both enabler and payoff are especially valuable because they fill two roles. »
  (https://commanderdeckmaker.com/learn/card-roles/enablers ,
  https://spellweave.app/guides/card-synergy , https://magicthegatheringauthority.com/synergy-and-combo-identification)
- **Path of Exile — Keystone = le « transform ».** Un keystone n'ajoute pas des stats, il **change une
  règle du personnage** (avantage massif + contrepartie), et **définit un archétype entier**.
  > « Keystones are build-changing, character-defining points that often provide a massive amount of
  > power, with a downside… the core of character-building. »
  (https://mobalytics.gg/poe-2/guides/passive-skill-tree)
  Exemples canoniques : *Chaos Inoculation* (vie → 1, immunité chaos → tout le build devient Energy
  Shield), *Avatar of Fire* (100% des dégâts convertis en feu), *Resolute Technique* (jamais de miss,
  jamais de crit). (https://www.poewiki.net/wiki/Keystone , https://poetrades.net/path-of-exile-passive-skill-tree/)

**Mapping retenu pour The Pit :**

| Palier créateur | Nom de design | Rôle | Analogue sourcé |
|---|---|---|---|
| **T1 « classique »** | **ENABLER (set-up)** | applique l'effet brut, amorce une condition | set-up StS, enabler Command Zone, common MTG « une seule chose » |
| **T2 « twist »** | **TWIST (payoff local)** | enabler + 1 interaction qui consomme/exploite la condition | pay-off StS, bridge (enable+payoff), uncommon MTG |
| **T3 « légendaire transform »** | **TRANSFORM / KEYSTONE** | redéfinit l'archétype, débloque une compo atypique/clutch | keystone PoE, boss-relic StS, mythic « gros effet » MTG |

> **Exemples du créateur, re-typés :** « poison qui se transmet à un allié au contact de la cible
> empoisonnée » = **TWIST** (contagion par contact, cf. §4.A) ; « la brûlure transfère le poison »
> = **TRANSFORM** (conversion d'altération, cf. §4.B). Cohérence parfaite avec la taxonomie.

### 1.2 La courbe enabler → payoff → carry (la dynamique de run)

La théorie deckbuilder insiste : **enablers et payoffs sont co-dépendants**, et le ratio compte
(« trop d'enablers = le moteur tourne sans tuer ; trop de payoffs = des cartes mortes en main »,
Command Zone). Transposé à un run d'autobattler, ça donne un **arc temporel** :

- **Début de run (peu de slots, tier bas)** : on a surtout des **T1**. Ils doivent être *jouables seuls*
  (tempo immédiat) car le payoff n'est pas encore là — exactement comme les « cheap $1/$2 champions
  carry the early rounds » en TFT (https://gangles.ca/2024/07/07/balatro-auto-chess/) et les pets Tier 1
  de SAP, « pretty weak and could be replaced later » (https://superautopets.fandom.com/wiki/Tiers).
- **Milieu de run** : les **T2** arrivent et **convertissent** l'accumulation des T1 en valeur (le payoff
  rend rétroactivement les T1 « bons »). C'est le moment « set-up → pay-off » qui donne son identité à la
  compo.
- **Fin de run (plateau plein, sigil choisi)** : un **T3** **transforme** la compo — soit en finisher
  explosif au seuil de stacks, soit en *pivot* qui rend légal un archétype impossible autrement
  (la carry). En TFT : « turning out a $5 hypercarry » vs « level up stacks of $2 champions ».

**Implication de design (à respecter par famille) :** un T1 sans aucun T2/T3 dans le pool = une altération
qui ne « paie » jamais (frustrant) ; un T3 sans T1/T2 = un payoff orphelin qui ne se déclenche pas. **Une
famille n'est jouable que si elle a au moins un T1 ET un payoff atteignable** (T2 ou T3).

### 1.3 Le ratio 5/3/2 : verdict

**Verdict : bon instinct, à ajuster vers 5 T1 / 3 T2 / 1-2 T3, le 2ᵉ T3 devant être un *transform
latéral* et non un 2ᵉ finisher.** Trois arguments sourcés :

1. **La complexité DOIT se concentrer dans peu de pièces.** MTG « New World Order » : on ne supprime pas
   la complexité, on la **contient à moins de cartes par ouverture**. Commons (= nos T1) doivent faire
   « une seule chose » :
   > « Your card should do one thing… Sometimes it should even be a vanilla creature. This is the
   > number-one area where designers fail. » (https://magic.wizards.com/en/news/making-magic/common-knowledge-2011-04-18)
   > « The higher you are in comprehension/board complexity, the higher the rarity… being complex makes a
   > card go up in rarity. » (https://magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12)
   ⟹ majorité de T1 simples, minorité de T3 complexes = pyramide saine. **5/3/2 respecte la pyramide.**

2. **La distribution de rareté réelle des TCG penche ~50/25/12.5 (commons/rares/epics).** Hearthstone :
   ratio commons:rares:epics:legendaries ≈ **4:2:1:1** (50% / 25% / 12.5% / 12.5%)
   (https://blizzpro.com/2016/04/15/hearthstone-sets-and-card-pool-part-2-rarities-class-and-neutral-cards/).
   Rapporté à 10 unités/famille, ça suggère **≈ 5 / 2-3 / 1-2** — **5/3/2 est dans la fourchette.** Mais
   note HS : « most top-level players include only a handful of legendaries… a deck composed entirely of
   legendary cards is ineffective and cumbersome » (https://hearthstone.wiki.gg/wiki/Rarity). Les
   transforms doivent rester **rares à l'usage**, pas juste rares à l'obtention.

3. **Un T3 est un point de bascule ; 2 par famille = risque de « meta résolue » SI les deux pointent au
   même endroit.** Deux finishers de la même famille = redondance qui durcit le combo auto-gagnant.
   La parade : faire du 2ᵉ T3 un **transform latéral** (« toutes vos unités DoT gagnent aussi *choc* »
   → pivote vers une autre famille). Cela **multiplie les compos** au lieu de sur-armer une seule — fidèle
   au principe « échanger une topologie, pas de la puissance » (`combat-model-decision.md`) et à la
   diversité-méta de **Ludus** (faible σ de win-rate = méta saine ;
   https://ojs.aaai.org/index.php/AAAI/article/view/21550).

> **Décision recommandée :** **5 T1 / 3 T2 / 2 T3**, contrainte : **exactement 1 T3 « finisher » + 1 T3
> « pivot latéral »** par famille. Si une famille n'a pas de pivot naturel, descendre à **1 T3** plutôt
> que doubler le finisher. (Le créateur garde son 5/3/2 ; on ne contraint que la *nature* des 2 T3.)

---

## 2. Tier-unlock & courbe de run (cadrage SAP, à brancher sur notre éco)

Référence directe pour « la complexité arrive progressivement » : **Super Auto Pets** déverrouille un
**tier de boutique tous les 2 tours** (tier X au tour 2X−1 ; T1 au tour 1 → T6 au tour 11), et **monter
de niveau offre une unité du tier supérieur** (power spike sur tours impairs).
(https://superautopets.wiki.gg/wiki/Pets , https://superautopets.wiki.gg/wiki/The_Basics ,
https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/)

**Notre adaptation (cohérente avec `gd-research-result.md` : leveling = déblocage de slots) :**
- Les **paliers d'EFFET T1/T2/T3** sont orthogonaux aux **paliers de SLOT**. Mais on **gate la rareté
  d'apparition** des T2/T3 sur la progression de run (un T3 ne devrait pas tomber au tour 1). Modèle SAP :
  « in the late-game you may not find many tier-6s because all the other tiers dilute the pool »
  (https://www.youtube.com/watch?v=pm1VpWt7LMA) — la dilution rend les T1 faciles à *upgrader* (3 copies)
  et les T3 précieux. **Ne PAS** rendre les T3 plus *fréquents* en fin de run au point de banaliser la
  bascule.
- **Garde-fou snowball (autochess).** L'avantage précoce s'auto-renforce (resources→victoires→resources ;
  https://www.gamedeveloper.com/design/autochess-market-status-and-design-analysis). Conséquence pour les
  paliers : **les T3 ne doivent pas être un 2ᵉ axe de snowball**. Un T3 obtenu tôt qui scale sans plafond
  = curbstomp. ⟹ T3 = **bascule plafonnée** (§5.3), pas accélérateur exponentiel.

---

## 3. LE TEMPLATE T1/T2/T3 (le moule à remplir par famille)

> Copie ce bloc pour chaque famille (DoT, choc, shield, aggro, vitesse…). Chaque palier = **critères de
> design** + **forme data** (`{trigger, op, params}`, cf. `engine-architecture.md`) + **pièges**.

### 3.1 Gabarit (à dupliquer)

```
## Famille : <NOM>  (condition centrale : <stack/altération/état que la famille produit>)

### T1 — ENABLER  (×5)   « applique l'effet, amorce la condition »
- Puissance        : faible-moyenne, AUTONOME (jouable seul, tempo immédiat).
- Complexité       : 1 ligne, 1 effet (NWO : « do one thing »). Zéro condition ou condition triviale.
- Condition        : aucune (ou « on_hit » nu).
- Rôle dans le run : début ; remplissable ; cible des duplicatas (3→niveau scale les STATS + l'amorce).
- Data type        : { trigger=<on_hit/on_cooldown_ready/...>, op=apply_status, params={status=<X>, stacks=n} }
- Variété (×5)     : varier le TRIGGER et la CIBLE, pas l'effet (single / column_front / on_attack / …).
- PIÈGES           : (a) T1 qui a déjà une condition = c'est un T2 déguisé ; (b) 5 T1 identiques au
                     trigger près = pool plat ; (c) T1 trop fort autonome = personne ne cherche le payoff.

### T2 — TWIST  (×3)   « enabler + UNE interaction qui consomme/exploite la condition »
- Puissance        : moyenne, CONDITIONNELLE (forte si la condition est là, médiocre sinon).
- Complexité       : 2 lignes max ; 1 condition + 1 op supplémentaire. UN seul axe d'interaction.
- Condition        : présence de la condition de la famille (cible empoisonnée, voisin shocké, stacks≥k).
- Rôle dans le run : milieu ; PAYOFF local ; convertit l'accumulation T1 en valeur.
- Data type        : { trigger=<…>, condition={kind=has_status,status=<X>}, op=<§4.A pattern>, target=<…> }
- Variété (×3)     : 3 patterns DISTINCTS du catalogue §4.A (p.ex. contagion / overkill / écho-voisin).
- PIÈGES           : (a) 2 ops d'interaction = trop complexe (→ T3) ; (b) payoff inconditionnel = c'est un
                     T1 boosté, pas un twist ; (c) twist qui scale en boucle = candidat combo cassé.

### T3 — TRANSFORM / KEYSTONE  (×1 finisher + ×1 pivot latéral)
- Puissance        : haute MAIS bascule, pas inflation brute (PoE : « build-changing », avec contrepartie
                     ou seuil). Effet « splashy » lisible (mythic MTG : « players must understand it »).
- Complexité       : board-complexity élevée OK, comprehension-complexity MODÉRÉE (le joueur doit
                     comprendre la bascule). 1 transformation centrale, idéalement 1 seul nombre/seuil.
- Condition        : seuil de stacks, OU sigil/adjacence (jamais 1 case précise), OU « toutes unités X ».
- Rôle dans le run : fin ; débloque une compo atypique / clutch ; définit l'archétype.
- Data type (2 saveurs) :
    • FINISHER : { trigger=on_status_applied/threshold, condition={stacks>=K}, op=<payoff explosif §4.B> }
    • PIVOT    : { trigger=combat_start, op=grant_effect, params={to="all_type:<Y>", effect=<autre famille>} }
- PIÈGES           : (a) T3 = simple +stats énorme → power creep, pas une bascule ; (b) T3 dépendant d'une
                     case fixe → cassé par swap de sigil ; (c) 2 finishers même famille → meta résolue
                     (cf. §1.3) ; (d) T3 qui scale par niveau son DÉCLENCHEUR → snowball (cf. §5.3).
```

### 3.2 Critères transverses (les « 3 axes de complexité » de MTG, appliqués)

MTG distingue **comprehension** (lisibilité au 1er regard), **board** (états à suivre), **strategic**
(profondeur de décision). Règle : la rareté monte avec comprehension/board, **pas forcément** avec
strategic (https://magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12). Pour nous :

| Axe | T1 ENABLER | T2 TWIST | T3 TRANSFORM |
|---|---|---|---|
| **Comprehension** (lisible vite) | très haute (1 ligne) | haute (1 condition) | **modérée-haute** (la bascule doit se comprendre — mythic, pas head-scratcher) |
| **Board** (états à suivre) | faible | moyenne (1 état croisé) | élevée OK (la compo entière y réagit) |
| **Strategic** (décision) | faible | moyenne | très haute (redéfinit le plan) |
| **Power** (taille d'effet) | petit | moyen, conditionnel | grand mais **borné/bascule** |

> Détail crucial pour nos **reliques cryptiques** (pilier #2) : une relique-T3 cryptique a une
> comprehension *volontairement* basse à la découverte, puis devient lisible une fois inscrite au
> Grimoire. Le **1-parmi-3** (fragments candidats) s'applique surtout aux **T2/T3** (les T1 sont trop
> simples pour soutenir 3 hypothèses crédibles). Cf. `gd-research-result.md` §2.4.

---

## 4. CATALOGUE d'archétypes transposables (le cœur réutilisable)

> Patterns **agnostiques de la famille** : remplace `<X>` par DoT/shock/shield/aggro/haste/… Chacun est
> mappé sur nos triggers/ops (`engine-architecture.md` §7). « Adj » = exploite notre adjacence-graphe.

### 4.A — Archétypes de TWIST (T2) : enabler + 1 interaction

| # | Pattern | Description générique | Trigger / op (The Pit) | Précédent sourcé |
|---|---|---|---|---|
| **T2-1** | **Contagion par contact** | la cible affligée de `<X>` transmet `<X>` à une unité qui la touche/voisine | `on_attacked`/`on_adjacency` → `apply_status` à `neighbors` | XCOM 2 poison « spreads to adjacent units » (https://www.gameslearningsociety.org/wiki/does-poison-wear-off-xcom-2/) ; Wartales **Toxic Miasma** « applies 1 Poison per stack to all adjacent units at end of turn » (https://game.wiki/wartales/toxic-miasma) ; WoW **Corrupted Blood** « spreads to nearby » (https://warcraft.wiki.gg/wiki/Corrupted_Blood_(debuff)) |
| **T2-2** | **Propagation à la mort** | quand une unité affligée de `<X>` meurt, `<X>` saute aux ennemis proches (radius/colonne) | `on_death` (cond: has `<X>`) → `apply_status` à `column_front`/`neighbors` | PoE **Contagion** « if an enemy dies while affected, the debuff spreads to nearby enemies » + spread-stack scaling « 100% more dmg per spread, up to 300% » (https://www.poewiki.net/wiki/Contagion , https://poe2db.tw/Contagion) ; StS **Corpse Explosion** |
| **T2-3** | **Conversion d'overkill** | les dégâts/valeur EXCÉDENTAIRES (surkill, surheal, surbouclier) se reversent ailleurs | `on_overkill`/`on_shield_absorb` → `op` redirigé (dmg/heal/shield) à un allié/voisin | trigger `on_overkill` déjà dans notre taxonomie (`engine-architecture.md` §7) ; SAP overflow patterns |
| **T2-4** | **Écho sur voisin (Adj)** | l'effet `<X>` se **répète** sur/par le voisin adjacent (multicast localisé) | `on_cast` → relance `op` ciblé `neighbors` (budget anti-boucle) | Batomon **Stellagon/Puffloon** multicast adjacent ; The Bazaar « use the item to the right » (`gd-research-result.md` §1.2) |
| **T2-5** | **Refresh sur trigger** | un événement (kill, hit, heal) **rafraîchit/prolonge** la durée ou le cooldown de `<X>` | `on_kill`/`on_hit` → `op=refresh_status`/`reduce_cooldown` | PoE Contagion « refresh their durations » on spread ; cooldown-reset patterns |
| **T2-6** | **Seuil mineur (mini-threshold)** | à `k` stacks de `<X>`, un **petit** bonus se débloque (pas une bascule) | `on_status_applied` (cond: stacks==k) → `op` modeste | MTG threshold « single number, single transformation… sweet spot » (https://magic.wizards.com/en/news/making-magic/i-want-threshold-your-hand-or-possibly-my-artifacts-2010-10-18) |
| **T2-7** | **Consommation (spend)** | l'unité **consomme** les stacks de `<X>` sur la cible pour un burst proportionnel | `on_attack` (cond: has `<X>`) → `op=consume_status` + `deal_damage*=stacks` | StS **Bane** « attacks a second time if Poisoned » ; consume-poison patterns (https://slay-the-spire.fandom.com/wiki/Poison) |
| **T2-8** | **Amplification croisée (Adj)** | un voisin d'un autre TYPE booste l'effet `<X>` (synergie inter-famille locale) | `on_adjacency_change` → bucket `increased` sur l'op du voisin | Batomon Geminiss (shield aux voisins) ; bonus par type (`gd-research-result.md`) |
| **T2-9** | **Riposte/réflexion** | subir un coup en présence de `<X>` renvoie `<X>` ou des dégâts à l'attaquant | `on_attacked` → `apply_status`/`deal_damage` à `source` | thorns/Envenom (op `thorns` déjà existant) |
| **T2-10** | **Stockage différé (charge)** | chaque application de `<X>` met une charge ; libérée à un événement (mort/seuil) | `on_status_applied` → `add_charge` ; `on_death`/`combat_end` → `release` | The Bazaar charge mechanics ; SAP **Worm of Sand**/accumulateurs |

### 4.B — Archétypes de TRANSFORM / KEYSTONE (T3) : redéfinit l'archétype

| # | Pattern | Description générique | Forme (The Pit) | Précédent sourcé |
|---|---|---|---|---|
| **T3-1** | **Conversion d'altération** | convertit `<X>` en `<Y>` (poison→feu, choc→gel, etc.) — ouvre une compo hybride | `on_status_applied` → `transmute(X→Y)` ; OU keystone « tout `<X>` compte comme `<Y>` » | **L'exemple du créateur** (« la brûlure transfère le poison ») ; PoE **Avatar of Fire** « 100% of damage converted to Fire » (https://poetrades.net/path-of-exile-passive-skill-tree/) ; Glacial Hammer phys→cold |
| **T3-2** | **« Toutes unités de type X gagnent l'effet »** (pivot latéral) | un keystone diffuse `<X>` à toute une famille/type → débloque l'essaim | `combat_start` → `grant_effect` à `all_type:<Y>` | SAP **Dragon** « Tier-1 friend bought → give friends +stats » ; TFT traits team-wide ; keystone PoE diffusant une règle |
| **T3-3** | **Payoff explosif au seuil de stacks** (finisher) | à `K` stacks de `<X>` (seuil élevé), détonation / multiplicateur massif | `on_status_applied` (cond: stacks>=K) → `op` burst, **plafonné** | MTG threshold (gros payoff au seuil) ; PoE Contagion spread-cap 300% ; StS **Catalyst** (double poison) |
| **T3-4** | **Trade-off keystone (sacrifice)** | énorme bonus `<X>` CONTRE une contrepartie structurelle (perd la vie/le ciblage/la défense) | passif `combat_start` : `op` buff massif + `op` malus | PoE **Chaos Inoculation** (vie→1) / **Resolute Technique** (no crit) / **MoM** — « massive power with a downside » (https://mobalytics.gg/poe-2/guides/passive-skill-tree , https://www.poewiki.net/wiki/Resolute_Technique) |
| **T3-5** | **Redirection globale** | tout `<X>` du plateau se concentre sur 1 porteur (ou se redistribue) → carry ou tank ultime | `on_status_applied` (n'importe qui) → reroute vers `holder` | PoE **Necromantic Talisman** « amulet bonuses apply to Minions instead » ; redirection d'aggro (`combat-model-decision.md` §5) |
| **T3-6** | **Inversion de règle** | `<X>` qui nuisait devient bénéfique (ou la condition s'inverse) | keystone qui flip le signe d'un op/bucket | PoE **Pain Attunement** (low-life = +dmg) ; StS **Corruption** (skills coûtent 0, s'exhaustent) |
| **T3-7** | **Propagation en chaîne illimitée** (finisher AoE) | `<X>` se propage de proche en proche **sans plafond de cibles** (mais budget anti-boucle) | `on_death`→spread récursif via work-queue (budget 256, `engine-architecture.md` §6.4) | PoE Contagion chain ; StS **Electrodynamics** « Lightning hits ALL enemies » ; Profane Bloom chain |
| **T3-8** | **Fusion d'archétypes (Adj/sigil)** | en présence d'une **forme de sigil** donnée, deux familles fusionnent en un effet nouveau | `sigil_change`/`combat_start` (cond: shape==S) → effet composite | sigils = topologie-archétype (`gd-research-result.md` §1.3) ; keystone gated par contexte |
| **T3-9** | **Économie de l'altération** | `<X>` génère une ressource (or/charge/spawn) au lieu (ou en plus) de dégâts | `on_status_applied`/`on_kill` (cond: has `<X>`) → `op=gain_resource` | SAP econ pets ; StS **The Specimen** (transfère le poison du mort) |

> **Comment remplir une famille :** prends 3 patterns **distincts** de 4.A pour tes T2, et 1 finisher +
> 1 pivot de 4.B pour tes T3. Évite de prendre 2 patterns qui font « la même chose » (p.ex. T2-1 contagion
> contact ET T2-2 contagion mort dans la même famille = redondant ; garde-en un, ou différencie le déclencheur).

---

## 5. Imbrication avec nos signatures : ADJACENCE × DUPLICATAS × PALIERS

### 5.1 Duplicatas (3 copies → niveau) : qui scale, qui ne scale PAS

Notre règle (`gd-research-result.md` §1.5) : 3 copies → niveau (max 3), **stats ET buffs d'adjacence
scalent**. Modèle SAP/TFT confirmé : « a higher-Level Pet has a more powerful ability » ; les valeurs
montent L1/L2/L3 (ex. SAP Ant donne +1/+2/+3 selon le niveau ; https://superautopets.wiki.gg/wiki/The_Basics).

**Règle de scaling par palier (garde-fou anti-snowball) :**

| Palier | Le niveau scale… | …mais PAS | Justification |
|---|---|---|---|
| **T1 ENABLER** | les stats + la **magnitude** de l'amorce (stacks appliqués, valeur du buff) | — | modèle SAP : l'effet brut monte L1/L2/L3. Sain : amorce plus de matière pour les payoffs. |
| **T2 TWIST** | les stats + la **magnitude du payoff** (dégâts du burst, taille de l'écho) | la **portée**/le nombre de cibles de l'interaction | on amplifie l'effet, pas la *combinatoire* (sinon explosion). |
| **T3 TRANSFORM** | **uniquement les stats** de l'unité porteuse | le **SEUIL**, la **bascule**, le **nombre de cibles** du transform | **clé anti-meta-résolue** : un T3 niveau 3 ne doit pas déclencher *plus tôt* ni *plus large*. La bascule est binaire, pas une rampe. (autochess snowball : https://www.gamedeveloper.com/design/autochess-market-status-and-design-analysis) |

> **Pourquoi.** Si le *déclencheur* d'un T3 scalait par niveau (seuil K qui baisse, radius qui grandit),
> le joueur qui *hit* 3 copies tôt obtiendrait un finisher anticipé + élargi = double snowball (resources
> → victoires → resources). En figeant la bascule et en ne scalant que les stats, **le T3 reste un choix
> de compo, pas un accélérateur exponentiel** — cohérent avec « le T3 = bascule plafonnée » (§2).

### 5.2 Adjacence (le voisin buffe) : peut-elle débloquer/conditionner un twist ?

Oui — **l'adjacence est le support naturel du conditionnel T2**, mais avec une frontière nette pour les T3 :

- **T2 PEUT être conditionné par l'adjacence** (recommandé) : « si un voisin porte `<X>`, alors… »,
  « l'effet se répète sur le voisin » (T2-4), « un voisin d'un autre type amplifie » (T2-8). C'est notre
  signature positionnelle (Batomon : « augmente les alliés **adjacents** » ; UI surligne les voisins,
  `gd-research-result.md` §1.2). L'adjacence rend le twist **placement-skillful** sans règle nouvelle.
  L'aura d'adjacence est **état dérivé**, recalculée sur `on_place/on_move/sigil_change`
  (`engine-architecture.md` §6.6) — donc le twist se re-cible gratuitement quand on change de forme.

- **T3 ne doit JAMAIS dépendre d'UNE case précise.** Un transform câblé sur « slot #4 » casse au moindre
  swap de sigil (les cases changent). Un T3 peut dépendre d'un **archétype topologique** (« en sigil
  anneau », T3-8) ou d'un **type** (« toutes les unités DoT », T3-2), **pas** d'une coordonnée. Règle
  d'archi déjà posée : auras stockées en termes **topologiques** (`to="neighbors"`), jamais « slot #4 »
  (`engine-architecture.md` §6.6). Le T3 hérite de cette règle.

- **L'adjacence comme « enabler de payoff » :** un voisin T1 (amorce) + un porteur T2 (payoff) sur des
  cases adjacentes = le **bridge** matérialisé spatialement. La **case centrale (4 voisins)** devient le
  slot naturel d'un **T2/T3 payoff** nourri par 4 amorces T1 — c'est le « build autour du centre »
  (`gd-research-result.md` §1.3), maintenant relié aux paliers.

### 5.3 Garde-fous anti « meta résolue » (synthèse, sourcés)

Objectif : **diversité de compos, aucun combo auto-gagnant** (Ludus : faible σ de win-rate / haute
entropie = méta saine ; https://ojs.aaai.org/index.php/AAAI/article/view/21550).

1. **Un seul T3 « finisher » par famille** ; le 2ᵉ T3 est un pivot latéral (§1.3). Évite l'empilement
   de finishers redondants (HS : « a deck of all legendaries is cumbersome »).
2. **Bascule plafonnée, jamais exponentielle.** Tout T3-finisher a un **cap** (PoE Contagion : +300% max ;
   threshold MTG : un seul nombre). Pas de boucle non bornée (Batomon a dû nerfer le multicast/shock en
   boucle ; `gd-research-result.md` §1.9). Notre work-queue impose déjà un **budget 256**.
3. **Le niveau (duplicatas) ne scale pas le déclencheur d'un T3** (§5.1). Anti double-snowball.
4. **Conditionnalité = counterplay.** Un payoff conditionnel (T2/T3) a une **fenêtre de contre** : retirer
   la condition (strip de statut), couper l'adjacence (AoE colonne), tuer l'amorce avant le payoff. Les
   contres sont à livrer **en parallèle** des transforms (`combat-model-decision.md` §5 : AoE/strip/
   furtivité dès le jour 1). « You can't force an archetype… pivot if the game gives you other pieces »
   (https://alienfusiongenerator.com/slay-the-spire-relic-synergy-calculator/).
5. **Tension de seuil bien réglée.** MTG threshold : « if too easy, the payoff is boring ; if too hard,
   players abandon the mechanic… one number tends to provide plenty of interaction »
   (https://magic.wizards.com/en/news/making-magic/i-want-threshold-your-hand-or-possibly-my-artifacts-2010-10-18).
   ⟹ régler K (le seuil de stacks d'un T3-3) **empiriquement via `tools/sim.lua`** (σ/entropie de
   win-rate), pas à l'intuition.
6. **Valeur conditionnelle dans le temps (l'arc de run).** Une carte forte tôt doit faiblir tard (et
   vice-versa) pour empêcher une compo unique de dominer toute la run : « a card very valuable early may
   not be valuable later » (http://www.cogwrightgames.com/blog/2017/2/26/conditionalvalue ;
   https://gangles.ca/2024/07/07/balatro-auto-chess/). T1 = tempo tôt ; T3 = scaling tard.
7. **Diversité par dilution, pas par fréquence.** Garder les T3 rares à l'usage (dilution du pool SAP),
   pas un T3 par combat. Cela force des **chemins de build multiples** plutôt qu'un seul payoff évident.

---

## 6. Checklist de validation (par famille remplie)

Avant d'acter une famille, vérifier :

- [ ] **5 T1** autonomes (jouables seuls), ≤ 1 ligne, variés par **trigger/cible** (pas par effet).
- [ ] **3 T2** = 3 patterns **distincts** de §4.A, chacun conditionné par la condition de la famille.
- [ ] **1 T3 finisher** (bascule **plafonnée**) **+ 1 T3 pivot latéral** (vers une autre famille) ; ou 1 seul T3 si pas de pivot naturel.
- [ ] Au moins **un payoff atteignable** (T2 ou T3) pour chaque T1 (pas d'amorce orpheline).
- [ ] **Scaling par niveau** : T1/T2 amplifient leur magnitude ; **T3 ne scale que les stats** (seuil/bascule figés).
- [ ] **Aucun T3 câblé sur une case précise** (uniquement type ou archétype-topologique de sigil).
- [ ] Le palier **comprehension** respecte la pyramide (T1 limpide → T3 lisible-mais-board-complexe).
- [ ] Un **contre** existe pour le payoff dominant (strip de statut / AoE colonne / tuer l'amorce).
- [ ] Passé au **`tools/sim.lua`** : σ de win-rate basse / entropie haute (pas d'outlier).

---

## 7. Questions ouvertes (à trancher)

1. **Ratio T3 :** acter **2 T3 (1 finisher + 1 pivot)** comme standard, ou **1 T3** par défaut + 2 seulement
   pour les familles « phares » ? (Recommandation : 1 finisher partout, pivot optionnel.)
2. **Gate de rareté des T2/T3 sur la run :** brancher l'apparition des paliers d'effet sur le tier
   d'éco/le niveau (façon SAP tier-unlock), ou sur la **rareté de relique** (le T3 = relique cryptique
   rare) — ou les deux ?
3. **Le 1-parmi-3 cryptique** s'applique-t-il **uniquement aux T2/T3** (les T1 sont trop simples pour 3
   hypothèses) ? (Recommandation : oui.)
4. **Inter-familles :** un T3-pivot (« unités DoT gagnent choc ») crée une **dépendance entre deux pools
   de familles** — l'accepte-t-on en V1 (richesse) ou le diffère-t-on (surface de test) ?
5. **Seuils K** des finishers : valeurs de départ à fixer par **`tools/sim.lua`** une fois ≥ 2 familles
   remplies (besoin d'une matrice de matchups réelle).

---

## 8. Index des sources (primaires d'abord)

**Taxonomie enabler/payoff/transform**
- Game Developer — « Archetypes in deckbuilding games » (set-up/pay-off StS, définition d'archétype) — https://www.gamedeveloper.com/design/archetypes-in-deckbuilding-games
- Command Zone framework (enabler/payoff/enhancer) — https://commanderdeckmaker.com/learn/card-roles/enablers
- Spellweave — enablers/payoffs/engines — https://spellweave.app/guides/card-synergy
- MTG Authority — enabler/payoff/**bridge** + synergy vs combo + redundancy ratio — https://magicthegatheringauthority.com/synergy-and-combo-identification

**Keystones / transforms (PoE)**
- PoE2 passive tree / keystones (build-defining) — https://mobalytics.gg/poe-2/guides/passive-skill-tree
- PoE Wiki — Keystone (liste, statut depuis unique) — https://www.poewiki.net/wiki/Keystone
- PoE passive tree guide (table keystones : CI, Avatar of Fire, Resolute Technique, Vaal Pact…) — https://poetrades.net/path-of-exile-passive-skill-tree/
- Resolute Technique (no crit → ailments) — https://www.poewiki.net/wiki/Resolute_Technique
- Mind Over Matter — https://www.poewiki.net/wiki/Mind_Over_Matter

**Rareté / complexité / ratios (le 5/3/2)**
- MTG « Common Knowledge » (commons = une seule chose ; NWO ; « two of » rule) — https://magic.wizards.com/en/news/making-magic/common-knowledge-2011-04-18
- MTG « Quite the Rarity » (3 axes de complexité ; complexité → rareté ; mythic = lisible+gros) — https://magic.wizards.com/en/news/making-magic/quite-rarity-2018-03-12
- MTG « Common Courtesy » (73% commons définissent le set ; scaling complexity by rarity) — https://magic.wizards.com/en/news/making-magic/common-courtesy-2002-06-10
- Hearthstone rarity (critères : complexité, NPE ; legendaries = handful) — https://hearthstone.wiki.gg/wiki/Rarity
- BlizzPro — distribution réelle des raretés HS (≈ 4:2:1:1) — https://blizzpro.com/2016/04/15/hearthstone-sets-and-card-pool-part-2-rarities-class-and-neutral-cards/

**Threshold / payoff au seuil**
- MTG « I Want to Threshold Your Hand » (sweet-spot ; un seul nombre ; linéarité des threshold) — https://magic.wizards.com/en/news/making-magic/i-want-threshold-your-hand-or-possibly-my-artifacts-2010-10-18
- TFT trait breakpoints (spike vs flat breakpoints, identité de compo) — https://www.emblemcomp.gg/guides/understanding-trait-breakpoints
- TFT « Building Around a Carry » (carry/secondary, item-holder, 2-star spike) — https://tft.ninja/guides/team-comps/carries

**Contagion / spread (twist T2-1/T2-2/T3-7)**
- XCOM 2 poison « spreads to adjacent friendly units » — https://www.gameslearningsociety.org/wiki/does-poison-wear-off-xcom-2/
- Wartales **Toxic Miasma** (poison à tous les adjacents/tour) — https://game.wiki/wartales/toxic-miasma
- PoE **Contagion** (spread-on-death + scaling par spread, cap 300%) — https://www.poewiki.net/wiki/Contagion , https://poe2db.tw/Contagion
- WoW **Corrupted Blood** (contagion de proximité, durée pleine au spread) — https://warcraft.wiki.gg/wiki/Corrupted_Blood_(debuff)
- Slay the Spire **Poison** (consume/spread payoffs : Bane, Specimen, Catalyst) — https://slay-the-spire.fandom.com/wiki/Poison

**Courbe de run / tier-unlock / scaling**
- SAP Pets (tier X au tour 2X−1 ; level-up → tier supérieur) — https://superautopets.wiki.gg/wiki/Pets
- SAP The Basics (niveaux L1/L2/L3, ability plus forte) — https://superautopets.wiki.gg/wiki/The_Basics
- SAP tier guide (T1 faible → T6 fort, dilution du pool) — https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/ , https://superautopets.fandom.com/wiki/Tiers
- Balatro & Auto Chess (power curve, high/low builds, pivot anti-meta) — https://gangles.ca/2024/07/07/balatro-auto-chess/
- Conditional value (valeur d'une carte varie dans l'arc de partie) — http://www.cogwrightgames.com/blog/2017/2/26/conditionalvalue

**Anti-meta-résolue / équilibrage**
- Ludus (équilibrage autobattler ; diversité = faible σ / haute entropie de win-rate) — https://ojs.aaai.org/index.php/AAAI/article/view/21550
- Autochess design analysis (snowball : resources→victoires→resources) — https://www.gamedeveloper.com/design/autochess-market-status-and-design-analysis
- StS relic synergy (contexte ; « can't force an archetype, pivot ») — https://alienfusiongenerator.com/slay-the-spire-relic-synergy-calculator/

> Voir aussi (interne) : `gd-research-result.md` (adjacence, duplicatas, sigils), `engine-architecture.md`
> (effet = `{trigger, op, params}`, triggers §7, auras §6.6, work-queue/budget §6.4),
> `combat-model-decision.md` (ciblage déterministe, exposition-sigil, aggro/contres).
