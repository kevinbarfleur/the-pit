# The Pit — Brainstorm : Diversité des effets & Système de Commandant

> **Date** : 2026-06-23
> **Statut** : EXPLORATION / DESIGN — **aucun code écrit**, rien n'est acté. Ce sont des pistes
> argumentées, des décisions *recommandées* et des forks *ouverts*, pas un cahier des charges figé.
> **Nature** : document de brainstorming **autonome**, destiné à être remis à un game designer humain.
> Il retrace **la genèse de chaque question** (pourquoi/comment elle s'est posée), **les réponses**
> apportées, **la méthode de recherche**, **les résultats** et **les sources**. Rien n'a été omis
> volontairement de la discussion qui l'a produit.
> **Méthode** : conforme à la règle d'or du projet (`CLAUDE.md` §1) — aucune API affirmée de mémoire ;
> l'état des lieux est tiré du **code en main** (refs en Annexe B), la recherche GD est **sourcée**
> (Annexe A).

---

## 0. Comment lire ce document

Deux fils de réflexion se sont croisés au cours de la discussion, **et ils convergent** :

1. **Fil A — Diversité des effets.** Constat : presque tous les effets d'unités sont des *afflictions*
   (DoT). Objectif : enrichir avec des mécaniques **agnostiques des afflictions** (vitesse d'attaque,
   multicast, soins, boucliers, amplification…) pour multiplier les synergies et rendre chaque unité
   compatible avec plusieurs archétypes.
2. **Fil B — Système de Commandant.** Idée neuve : un slot supplémentaire pour une unité *invulnérable
   qui combat et projette une aura d'équipe*. Chaque unité du roster porterait un « bonus de
   commandement ».

**La convergence (§8.3)** : l'aura de commandement est, par nature, *team-wide et build-définissante*
— c'est le **foyer naturel** des mécaniques agnostiques du Fil A. Concevoir les deux, c'est concevoir
le même pool d'effets vu sous deux angles.

Plan : §1-6 = Fil A (question, état des lieux, insight, taxonomie, catalogue, faisabilité moteur).
§7-11 = Fil B (genèse, analyse, raffinements, catalogue de commandants, synergies). §12-13 = recherche
GD et son impact. §14-16 = forks ouverts, risques, prochaines étapes. Annexes A (sources), B (refs
code), C (glossaire).

---

# FIL A — DIVERSITÉ DES EFFETS

## 1. Le point de départ — la question

### 1.1 La frustration initiale (mot pour mot, reformulé)
L'utilisateur, en pleine refonte visuelle, veut profiter de ce chantier pour travailler le **game
design des unités** : diversité des unités, de leurs effets, et du *fonctionnement* de leurs effets.

Le déclencheur précis : un retour récurrent des docs de recherche (`docs/roadmap-lab/`,
`docs/research/progression-economy-prd.md`) disant que **la majorité des effets sont basés sur des
afflictions** — soit ça *pose* une affliction, soit ça la *modifie*, soit ça la *renforce*. « On n'a
presque que ça. »

### 1.2 Pourquoi cette question — le raisonnement de l'utilisateur
Son intuition, exprimée par un exemple :

> « Imaginons une famille de *bêtes* spécialisée dans le *saignement*. Ce n'est pas parce que la
> famille est saignement que **tout le monde** doit faire du saignement à l'intérieur. Je pourrais
> avoir une créature qui fait que **la créature placée derrière elle a un multicast** — à chaque
> attaque, elle tape deux fois très rapidement. Ça n'a rien à voir avec le saignement, mais ça
> *renforce* le saignement (deux fois plus de procs). »

Le point clé qu'il en tire lui-même :

> « L'avantage, c'est que ça rend cette créature **aussi compatible avec d'autres familles**.
> Quelqu'un qui joue Choc, ou Poison, sera *aussi* intéressé par cette créature multicast. »

Donc la demande n'est pas « ajouter des effets », c'est : **ajouter des mécaniques agnostiques des
afflictions, qui créent de la synergie transversale**, pour que les familles deviennent des *thèmes*
(visuel/lore) plutôt que des silos mécaniques, et qu'une unité serve **plusieurs** archétypes.
Exemples qu'il cite : bonus de vitesse d'attaque, régénération de vie, soins passifs.

### 1.3 Ce qui était demandé
1. **Un état des lieux** des effets actuels (« pour qu'on y voie plus clair »).
2. **Une réflexion** sur comment enrichir drastiquement, avec des mécaniques agnostiques.

---

## 2. État des lieux du système d'effets (code en main)

### 2.1 La surface de hooks (ce que le moteur sait déclencher)
Le moteur d'effets (`src/effects/engine.lua`) est **ouvert/fermé** : ajouter un effet = enregistrer un
*op* + poser une ligne de data, **jamais** éditer la boucle de combat. 5 points d'accroche existent :

| Trigger | Quand | Exemples actuels |
|---|---|---|
| `combat_start` | au début (ou résolu au build pour les auras) | `regen`, `shield_aura`, `grant_team` |
| `on_attack` | avant les dégâts, peut modifier `ctx.amount` | `bonus_first` |
| `on_hit` | après dégâts infligés | poison/burn/bleed/rot/shock, `lifesteal`, `strip_shield` |
| `on_attacked` | le défenseur réagit | `thorns` |
| `on_death` | broadcast **différé** aux ennemis du mort | `spread_*`, `frenzy_gain` |

### 2.2 Le vocabulaire d'ops — séparé en deux camps

**AFFLICTIONS (le cœur, surdéveloppé)** — 5 familles + modificateurs :
- `poison` — N stacks + `weaken` (malus de valeur) + `spread` (contagion) + `shieldEat` + `igniteAt`
  (détonation poison→feu).
- `burn` — brûlure décroissante + `refresh` / `extend_if_weaker` / `decayPct`.
- `bleed` — saignement + slow de cadence + `aggravateMult` + `slowScalesMissingHp` + cumul par source.
- `rot` — pourriture qui enfle + ampute les PV max + `passiveRamp` + `amputateHealsMe`.
- `shock` — condensateur ; la décharge (stacks × volt) part à la frappe + `chain` / `transfer` / `persist`.
- Propagation : `spread_burn_on_death`, `spread_rot`, croisé `convert_to_rot`.
- Drapeaux d'équipe (T3) : `grant_team` (burnNoDecay, poisonNoCap, slowEnemies, rotEnemies, pierceHeal,
  invulnT, shockChain, bleedNoExpire, plagueAmp).
- Auras DoT build-résolues : `aura_burn_dps`, `aura_poison_dps`, `aura_rot_growth`, `aura_grant_bleed`.

**AGNOSTIQUE (la portion congrue)** — tout le reste tient en une poignée d'ops :
`bonus_first` (+dégâts 1re frappe), `lifesteal`, `thorns`, `regen`, `strip_shield`,
`frenzy_gain` (relique, on_death), et tout l'axe **bouclier** : `shield_aura` / `shield_caster`
(périodique) / `aura_shield` (reflect / overcharge / radius / cdr).

### 2.3 Les stats/leviers déjà câblés (souvent inertes par défaut)
`arena.lua` consomme déjà, mais **aucune unité ne les distribue largement** :
- `aggro` (ciblage — tank tire le focus), `taunt` (override de ciblage).
- `dmgReduce` (réduction de dégâts d'attaque — relique, inerte).
- `haste` (accélère la cadence — relique WHETSTONE, inerte).
- `secondBreath` (survit 1× à un coup fatal — relique).
- `weaken` (malus de valeur, du poison), `atkSlow` (slow de cadence, du bleed), `regen` (soin/s).

### 2.4 Le diagnostic chiffré (roster ~83 unités)

| Catégorie | Nombre | % |
|---|---|---|
| Posent / modifient / amplifient une **affliction** | ~63 | **~76 %** |
| **Non-affliction** | ~20 | ~24 % |

Et les 20 « non-affliction » se décomposent ainsi :
- **13 = un seul cluster défensif** (boucliers + tank + épines) — bien développé, mais **purement défensif**.
- **3 = stat-sticks** sans effet (`husk`, `footman`, `mire_thing`).
- **4 = les vrais « autres »** : `lifesteal`, `bonus_first` (×2), `regen`.

### 2.5 Le vrai trou
L'espace d'identité **offensive non-affliction** se résume à **`lifesteal` et `bonus_first`**. Il y a
**zéro** unité d'amplification/enabler — exactement la créature « multicast » décrite par l'user.
Aucun multicast, aucune vitesse d'attaque donnée à un voisin, aucun crit, aucune vulnérabilité/marque,
aucun buff de dégâts d'adjacence, aucun execute. **L'intuition de l'user est juste à 100 %.**

### 2.6 Recoupement avec `docs/roadmap-lab/` (passe de recherche n°1)
Une passe sur la boucle nocturne adversariale a été menée. Elle **confirme le diagnostic** mais montre
que ses propres propositions sont surtout **méta**, pas des enablers au niveau unité :
- **Confirmation** : « **~78 % posent un DoT** ; l'archétype *brute basique* n'existe pas (1 unité) »
  (`progression-economy-prd.md` §1). Et : « la signature du jeu (le plateau-graphe) sous-spécifiée,
  aucune relique positionnelle » (`ROADMAP.md` M7).
- **Ce que le lab proposait déjà** (et qui ne couvre PAS l'axe enabler-agnostique de l'user) :
  - *Essaim/largeur* : `swarm_logic` (relique scalante par nombre d'unités), archétype « wide-low,
    triple tout », sigil diamant.
  - *Défense* : `pierceShield` (le bleed traverse les boucliers), réorientation de `hollow_choir`.
  - *Positionnel* : 4 reliques sigil-aware (`axis_pact`, `bloodline`, `ring_hunger`, `horde_pact`),
    surlignage des arêtes, carte de risque (profondeur), « surprise de placement ».
  - *Synthèse inter-familles* : `#FF` aggravation croisée (2 familles co-présentes s'amplifient),
    `resonance_stone`, `venom_covenant`.
  - *Timing* : « Moment du Run » (chaîne d'événements séquentielle visible), « Nom de Build » (identité
    d'archétype, ex. signal « ALCHIMISTE » pour récompenser la diversification).
  - *Économie* : VRR de boutique, barre XP de boutique, signal de relief « contre la mort ».
  - *Choc axe D* : le choc amplifie le 1er tick DoT (`shock_conduit`).
- **Taxonomies du lab** : archétype = famille DoT + sigil + reliques ; modèle de tiers T1/T2/T3 ;
  tension d'archétype (BURN décroît ⇄ ROT croît ; POISON ⇄ SHIELD) ; axe topologique des 5 sigils
  (carré/équilibre, croix/mono-carry, anneau/chaîne, diamant/wide, ligne/conduit) ; garde-fou `#JJ`
  (« tout payoff s'ancre sur une cause **contrôlée par le joueur** — composition/placement — jamais
  sur la cible/l'adversaire »).

**Conclusion du recoupement** : l'axe **enabler agnostique au niveau unité** (multicast/hâte/empower/
vulnérabilité) est **largement absent** du lab → ce qu'on conçoit ici est **additif**, pas redondant.

---

## 3. L'insight central — pourquoi les enablers agnostiques

### 3.1 Affliction = silo ; enabler = multiplicateur
Une affliction n'intéresse qu'une compo de sa famille (silo). Un enabler agnostique (multicast, hâte,
vulnérabilité) **multiplie n'importe quelle source de dégâts** — poison, choc, saignement, vol de vie,
dégâts bruts. Conséquence : **1 enabler ajouté = synergie avec les 5 familles existantes** (surface
combinatoire **×5**, pas +1). C'est le levier à plus haut rendement de tout le game design actuel.

### 3.2 Les familles redeviennent des THÈMES
Cela colle pile à la décision déjà actée « familles = THÈMES, axes type/visuel/mécanique **découplés** »
(cf. mémoire projet, refonte visuelle PHASE 2). Une famille devient un *thème* (lore/visuel), pas une
prison mécanique.

### 3.3 Une unité sert plusieurs archétypes
La boutique devient intéressante pour tout le monde → plus de builds viables, plus de décisions.

---

## 4. La taxonomie proposée (3 axes orthogonaux aux afflictions)
Pour designer sans retomber dans le silo, classer tout effet sur **3 axes indépendants** :

- **VERBE** (ce que ça touche) : Dégâts · **Tempo** (cadence/multicast) · Sustain (soin/bouclier) ·
  Mitigation (armure/esquive) · **Ciblage/Position** · **Amplification** (buff d'autrui) · Économie/méta.
- **PORTÉE** : Soi · **Voisin** (adjacence — la signature « la créature derrière ») · Équipe ·
  Ennemi (1 / colonne / tous).
- **MOMENT** : les 5 triggers existants (+ 2 à ajouter : `on_kill`, `on_threshold` HP).

**Où le roster est concentré** : `{Dégâts-via-affliction × Ennemi × on_hit}`.
**La case vide la plus rentable** : `{Tempo / Amplification × Voisin × *}` — les enablers.

---

## 5. Catalogue de nouvelles mécaniques agnostiques (par priorité)
Ordonné par **rendement synergique × faisabilité**. Les 4 premières = la « colle ».

**Vague A — Amplificateurs (la colle agnostique, à faire en premier)**
| Mécanique | Effet | Pourquoi agnostique |
|---|---|---|
| **Multicast / Écho** | le voisin re-frappe (multiplicateur **entier** de frappes, cf. §9.1) | double **toutes** les procs on_hit |
| **Hâte (aura)** | +cadence au voisin | accélère tout DPS / tout stacker |
| **Vulnérabilité / Marque** | l'ennemi marqué prend +X % de **toutes** sources (frappe ET DoT) | l'« exposition » que toute compo veut |
| **Empower (aura)** | +dégâts plats/% aux frappes du voisin | buff brut universel |

**Vague B — Dégâts conditionnels (identité offensive non-DoT)**
- **Crit / Sauvagerie** (×2 sur RNG seedé), **Execute** (bonus/kill sous seuil PV), **Cleave/
  Éclaboussure** (touche les voisins de la cible), **Focus-fire** (le voisin vise la même cible).

**Vague C — Sustain / défense agnostique**
- Soin-on-kill, aura de soin, overheal→bouclier, **armure plate** (`dmgReduce` existe déjà), esquive,
  **purge** (retire ses propres afflictions = nouvel axe de contre).

**Vague D — Position / on-death / économie (nouveaux axes, plus tard)**
- Repositionnement (pull/swap), death-rattle non-DoT (explose / buff l'équipe / spawn un add),
  scavenger (+or au kill), vétéran (gagne des stats permanentes entre combats s'il survit).

---

## 6. Cartographie de faisabilité moteur
> Demandée explicitement par l'user (« vue ingénierie avant design »). Refs code en Annexe B.

### 6.1 Légende d'effort
- **T0** — déjà 100 % câblé, il manque juste une unité-porteuse → **pure data**.
- **T1** — 1 nouvel op OU 1 branche d'aura, hook + champ + consommation existent déjà → **faible**.
- **T2** — touche la boucle/le ciblage, mais **un template existe déjà** → **moyen**.
- **T3** — nouveau sous-système (rendu/board/run) → **lourd**.

### 6.2 Le tableau

**Tier 0 — gratuit (le moteur consomme déjà le champ)**
| Mécanique | Déjà câblé (preuve) | Il manque |
|---|---|---|
| Armure plate (self) | `arena.lua:257` ampute déjà `dmgReduce` sur `cause="attack"` | une unité avec `dmgReduce` |
| Survie 1× | `arena.lua:274` ressuscite déjà via `secondBreath` | une unité `secondBreath=true` |
| Hâte (self) | `arena.lua:581` applique déjà `(1-haste)` au timer | une unité `haste` |

**Tier 1 — faible (pattern `shield_aura` + couche `Stats`)**
| Mécanique | Déjà câblé | Il manque | Où |
|---|---|---|---|
| Hâte (aura) | `haste` consommé (581) | branche `aura_haste` (bake sur voisin) | `build.lua:499` |
| Armure (aura) | `dmgReduce` consommé (257) | branche `aura_armor` | idem |
| Regen (aura) | `regen` consommé (530+) | branche `aura_regen` | idem |
| Empower (+dmg voisin) | `Stats.resolve` + `hit()` (319) | bake `dmgInc`/`dmgFlat` + 1 ligne `Stats.resolve` | `build.lua` + `arena.lua:319` |
| Vulnérabilité / Marque | `damage()` amplifie déjà par flag (`plagueAmp`, 249-254) | op `mark_vuln` (on_hit) + 2 lignes `damage()` | `ops.lua` + `arena.lua:248` |
| Crit | RNG seedé + `passCondition "chance"` (`engine.lua:29`) | 1 op trivial | `ops.lua` |
| Execute (seuil PV) | `victim.hp/maxHp` lisibles | 1 op | `ops.lua` |
| Soin-on-kill | `on_death` broadcast existe (`frenzy_gain` le prouve) | 1 op qui soigne `ctx.source` | `ops.lua` (faisable **aujourd'hui**) |

**Tier 2 — moyen (un template existe)**
| Mécanique | Template existant | Plomberie nouvelle |
|---|---|---|
| Cleave / Éclaboussure | `dischargeShock` arque déjà vers `neighborsOf` (`arena.lua:352-363`) | op + appel dans `hit()` ; décider si la splash re-proc les on_hit (non, anti-récursion) |
| **Multicast / Écho** | — | re-déclencher un swing + **garde anti-boucle** = la tâche « **work-queue d'effets, budget 256** » déjà inscrite roadmap moteur §12 |
| Focus-fire (aura) | ciblage déterministe (`chooseTarget` 184-209) | tie-break « vise la cible de l'allié X » |
| `on_kill` précis | `damage()` connaît `opts.source` | flag « coup fatal » → trigger dédié |
| `on_threshold` (PV % franchi) | — | check dans `tickDots` ou par-frame |

**Tier 3 — lourd (nouveau sous-système)**
| Mécanique | Pourquoi lourd |
|---|---|
| Summon / spawn mid-combat | `spawn()` ne crée qu'au début ; le render doit gérer l'ajout dynamique |
| Repositionnement | muter `depth/row` → le ciblage suit tout seul, mais x/y de rendu + modèle board à resynchroniser |
| Économie/méta | vit dans `run/state.lua`, pas l'arène ; implications snapshot |

### 6.3 La synthèse moteur
- **~70 % des Vagues A/B/C sont T0-T1** : elles tombent dans deux patterns déjà construits et testés —
  la résolution d'aura `shield_aura` (`build.lua:482-511`) et la couche `Stats` (`stats.lua`).
- **Le keystone à plus haut rendement** : généraliser `build.lua:499-503` en **un seul handler
  `aura_stat`** qui bake n'importe quelle stat nommée (`haste`/`dmgReduce`/`regen`/`dmgInc`) sur les
  voisins. **Un seul ajout débloque toute la famille tempo/sustain/empower** ; changer de sigil
  re-cible automatiquement.
- **Ordre de construction recommandé** :
  1. Généraliser `aura_stat` + brancher `Stats` sur `dmg` → débloque hâte/armure/regen/empower (4 méca, T1).
  2. `mark_vuln` (l'exposition agnostique universelle, T1).
  3. Crit + Execute + Soin-on-kill (3 ops triviaux, T1).
  4. Multicast (work-queue + garde anti-boucle, T2) — le gros morceau, la créature signature.
  5. Cleave, puis le reste à la demande.
- **Golden-safe** : tant qu'aucune unité ne porte ces effets, `mods=nil` → `Stats` renvoie la base ;
  flags `nil` → inertes. Adoption progressive sûre, comme l'a été celle des afflictions.
- **Tâches roadmap moteur §12 directement débloquées** : « Buckets de modifiers (% de stat) » =
  empower/vuln/armure ; « Work-queue d'effets (budget 256) » = multicast/cleave.

---

# FIL B — LE SYSTÈME DE COMMANDANT

## 7. La genèse de l'idée

### 7.1 L'idée brute de l'utilisateur (reformulée fidèlement)
> « Et si on instaurait un système de **chef de troupe / leader / commandant** ? En plus du board
> classique, **un slot supplémentaire** par joueur, positionné à un endroit sympa (à définir). Le
> joueur y place une unité qui **ne prend jamais de dégâts**, mais qui **attaque normalement** comme
> les autres. Par contre elle **propose un bonus particulier**. Quand le board classique est défait, le
> joueur a perdu (le commandant seul ne sert à rien). Ça voudrait dire qu'on ajoute à **chaque unité**
> une caractéristique : **le bonus donné si elle est placée au commandement**. »

### 7.2 Pourquoi l'user la trouve intéressante — le trade-off qu'il a lui-même identifié
> « On serait tenté de prendre une unité super forte et de la mettre au commandement (on se doute que
> son passif sera fort). Sauf que oui et non : si elle est au commandement, elle ne profite **pas** des
> autres passifs/auras du board. Donc c'est un **trade-off**. Un petit tweak qui ne change pas grand
> chose en surface, mais qui donne une **impression de profondeur** bien plus grosse. »

---

## 8. Analyse de design du Commandant

### 8.1 Validation : c'est un mécanisme prouvé
Le pattern « un pouvoir qui définit le build, attaché à un héros/commandant » porte des jeux entiers
(détail + sources en §12) : Hearthstone Battlegrounds (Heroes), Storybook Brawl (Heroes), Mechabellum
(Specialists), TFT (Augments/Legends). **La différence (et la force) de la version de l'user** :
**n'importe quelle unité peut être commandant, et chaque unité porte son propre bonus** → tu ne
dessines pas 6 héros séparés, tu **doubles la surface de design de tout le roster d'un seul champ de
data**. Chaque créature gagne une seconde identité.

### 8.2 Le vrai moteur de profondeur (plus fort que l'argument d'équilibre de l'user)
Son garde-fou « le commandant perd l'adjacence » est correct mais secondaire. Le vrai moteur :

> **Tu dessines pour deux fonctions de valeur en même temps.** Un bon *troupier* (frappe fort, stacke
> du poison) n'est pas forcément un bon *commandant*. Un bon commandant, c'est celui dont l'**aura
> multiplie le mieux le board** — peu importe sa puissance perso.

Donc l'instinct « je promeus ma carry la plus forte » échoue pour une raison plus profonde que « elle
perd l'adjacence » : la valeur d'un commandant **ne dépend pas de sa puissance perso, mais du nombre
d'unités qui profitent de son aura**. Ça **découple** « bonne unité » et « bon leader » = de la vraie
décision de draft.

### 8.3 ⭐ La convergence avec le Fil A
**Le slot de commandement est le foyer naturel des mécaniques agnostiques (§5).** Une aura de
commandement est team-wide et build-définissante — c'est exactement là que vivent : « toute l'équipe a
du multicast / +hâte », « vos frappes posent une marque de vulnérabilité », « toute l'équipe vole de la
vie ». Ces effets sont **médiocres sur une seule unité de board, mais parfaits en aura globale**. Le
slot leur donne une maison. **Les deux fils fusionnent : le pool d'auras de commandement = le pool
d'enablers agnostiques.** On construit les deux d'un coup.

### 8.4 Les forks initiaux (et mes recommandations)
1. **Passif de board conservé en commandement ?** → reco initiale *(non, modes exclusifs)* —
   **révisée plus tard, cf. §9.2**.
2. **Dégâts perso du commandant** → *(modeste/normalisé ; l'aura est la vedette)*.
3. **Slot obligatoire ou optionnel/débloqué ?** → *(débloqué en cours de run, comme les slots ; jouable
   sans au début)*.
4. **Aura sur TOUTES les unités, ou un sous-set « nés pour mener » ?** → *(sous-set curé au début, puis
   extension)*.
5. **L'aura scale-t-elle avec le niveau (duplicatas) du commandant ?** → *(oui, cohérent avec le
   scaling des auras)*.
6. **Le commandant peut-il être affligé/soigné par l'ennemi ?** → *(non : pas de PV → afflictions
   inertes ; mais il reçoit les buffs team-wide de SA propre équipe)*.
7. **Position/visuel du trône** → *(un piédestal distinct, hors du graphe de sigil, pour rendre lisible
   la règle « pas d'adjacence »)*.

**Coût moteur estimé : faible (T1-T2).** Tout existe : invuln (`arena.lua:247` fait déjà `return 0`
pour la fenêtre d'invuln de SACRED SHIELD) ; intouchable (`chooseTarget` 184-209 → ajouter
`and not o.untargetable`) ; aura d'équipe = `grant_team` via `teamFlags` ; condition de victoire (décompte
des vivants `arena.lua:642-647` → filtrer `and not u.isCommander`).

**Fil thématique grimdark (gratuit)** : *« la chose qui mène la descente mais ne saigne jamais — quand
ta chair tombe, le héraut n'a plus personne à commander, et tu chutes avec. »*

---

## 9. Raffinements (les allers-retours de design)

### 9.1 Raffinement #1 — la portée EST l'axe d'équilibrage
**Correction apportée par l'user** : l'aura ne doit **pas** être systématiquement sur toute l'équipe.
Il veut de la **variance** : passifs légers/moyens → toute l'équipe ; passifs **très forts** → **une
seule unité**. Exemple donné : « l'unité en haut à gauche a 100 % de multicast (elle tape deux fois) ».

**Le principe propre qui en découle** :
> **Budget de puissance = magnitude × nombre de cibles.**

| Portée | Puissance autorisée | Exemple |
|---|---|---|
| **Toute l'équipe** | faible/moyenne | « +6 % cadence à tous », « tous regen 1 » |
| **Sous-ensemble conditionnel** | moyenne/forte | « les unités **tier-1** : +50 % », « les unités **niveau 1** : +gros bonus » |
| **Une seule unité** | **très forte** | « l'élue a **×2 multicast** » |

« +1 multicast à toute l'équipe » = broken ; « +1 multicast à UNE unité » = sain. Même effet, scope
opposé → exactement l'intuition de l'user.

**Le multicast en entier (précision de l'user)** : « pas en pourcentage, en **multiplicateur** » — un
nombre de frappes garanti (×1 par défaut, ×2, ×3). **Point crucial pour le moteur** : un multicast
entier garanti est **100 % déterministe** (zéro dé) → rejouable, async-vérifiable. Ça colle pile au
pilier de combat déterministe. « 20 % de chance de re-frapper » introduirait du RNG ; le multicast
entier l'évite. **L'user a choisi la bonne forme.**

**Les commandants conditionnels = des sélecteurs de stratégie** (les 2 exemples de l'user, excellents) :
- **Spécialiste tier-1** : « les tier-1 ont X » → définit un build *reroll-wide* (j'empile des tier-1,
  je les monte en niveau).
- **Spécialiste niveau-1** : « les niveau-1 ont +X » → a l'air faible, mais **génial en fin de partie** :
  en endgame, les monstres du dernier palier sont quasi jamais niveau 2 (3 copies d'une légendaire =
  rarissime). Donc c'est un buff qui ne touche **que** tes plus gros monstres, **tard**. Profondeur
  non-évidente — exactement ce que l'user recherche.

→ Le slot devient un **choix de doctrine** (wide / mono-famille / max-tier / front-tank…). Tu ne
« parques » plus une unité forte, tu **choisis ta stratégie**.

### 9.2 Raffinement #2 — le corps du commandant (pushback sur les modes exclusifs)
**Critique de l'user** (juste) : si on **retire** son affliction à une unité quand elle est
commandant, certaines unités (dont toute la valeur est l'on_hit) **ne servent plus à rien**. Il faut la
considérer comme **une unité de plus qui attaque**. Ses pistes : (a) garder ses effets mais **diviser
ses dégâts par deux** ; (b) ou en faire un **fanal pur** (ne fait que son aura). Il n'a « pas de vision
forte ».

**Précision sur ma reco initiale** : sous « modes exclusifs », une afflicteuse-commandante ne devient
pas « rien » — elle perd son poison de board **mais projette son aura de commandement** (un effet
différent). Donc ce n'est pas zéro. **MAIS** le point de l'user tient : elle perd son *identité de
combat*, et c'est mou.

**Pourquoi « ÷2 les dégâts » n'est pas idéal** : ce n'est **pas uniforme**. Diviser les dégâts nerf une
cogneuse brute mais **ne touche presque pas une afflicteuse** (le poison s'applique à plat, pas en
fonction du dégât). Le nerf passe à côté de la moitié du roster.

**La proposition de synthèse — le knob uniforme = la CADENCE.** Le commandant garde **tout son kit**
(attaque + effets), mais **frappe beaucoup plus lentement** (×1,5–2 sur le cooldown). Un seul chiffre,
qui nerf **proportionnellement les deux** : moins de frappes = moins de dégâts bruts ET moins
d'applications de poison/choc. Bonus thématique : un commandant **ne se bat pas comme un troufion, il
frappe rarement, avec poids — il dirige**.

**Le modèle à deux cadrans orthogonaux** (la structure d'équilibrage retenue) :
- **L'aura** est équilibrée par la **portée** (team = faible / conditionnel = moyen / mono-cible = fort).
- **Le corps** du commandant est équilibré par la **cadence** (il frappe lentement).

Résultat : aucune unité n'est nulle en commandement (elle garde son identité), le DPS-gratuit est
maîtrisé, un seul chiffre à tuner pour le corps. Plus solide que ÷2-dégâts ou que l'aura-only.
*(Variante : certains commandants pourraient être de purs **fanaux** — n'attaquent pas, mais portent une
aura énorme. Levier par-commandant possible ; pour un v1 lisible, garder la règle uniforme « tous
frappent à cadence lente ». Voir aussi le fork A/B/C en §13, fortement influencé par la recherche.)*

### 9.3 Le ciblage mono-cible — par RÔLE, pas par case (sigil-invariant)
**Le problème soulevé par l'user** : avec le système de sigils (qu'il juge « un peu bordélique, à
améliorer »), cibler « l'unité en haut à gauche » obligerait à **prédéfinir, pour chaque commandant ×
chaque sigil**, quelle case est ciblée. Trop de travail. Il **préfère un placement prédéfini** (plus
facile à équilibrer) à un placement laissé au joueur.

**La solution proposée** : ne pas cibler une **case**, cibler un **rôle géométrique** :
- « l'unité **la plus en avant** » (depth minimal — *déjà calculé* : `depth = maxCol - cell.x`)
- « l'unité **la plus en arrière** », « l'unité **au centre** » (le nœud à 4 voisins = case-carry)
- « l'unité **la plus chère / haut-rang** », « la plus basse en PV », « la plus haute en aggro »

Ces rôles se **dérivent automatiquement de la géométrie de n'importe quel sigil** → **zéro table
par-sigil**. Tu définis le commandant **une fois** (« buffe la plus avancée ») et il se résout sur les
5 sigils. C'est **prédéfini comme une règle** (donc équilibrable, ce que l'user veut) **sans** le coût
combinatoire.

**Effet de bord vertueux** : ça **donne enfin un sens fort aux sigils** — la forme décide *qui* est « le
plus avant / au centre », donc *qui* attrape la couronne. L'agence joueur revient par la fenêtre (tu
places ton afflicteuse devant pour qu'elle catch le multicast), mais la règle reste fixe.
**Améliorer les sigils et ajouter les commandants deviennent le même chantier.**

---

## 10. Catalogue de Commandants (16 exemples, 4 groupes)
> Demandé par l'user : « j'en veux pas mal, des plus simples ou plus avancés », avec **synergies
> ancrées sur des unités réelles du roster**. Noms grimdark = placeholders évocateurs. Chiffres =
> placeholders d'équilibrage (à tuner via `tools/sim.lua`).

### A — Doctrines d'équipe *(portée large → effet léger ; simples, « défauts sûrs »)*
| Commandant | Aura | Définit | Synergie roster |
|---|---|---|---|
| **Le Tambour de Guerre** | équipe +8 % cadence | tempo universel | colle agnostique pure : `spore_tick`/`live_wire` posent leurs stacks plus vite — jamais broken |
| **Le Calice de Sang** | équipe +5 % vol de vie | attrition/sustain | double l'identité de `demon` ; tient les bruisers dans les combats longs (`HP_MULT=2`) |
| **Le Maître-Lame** | équipe +2 dégâts plats | brute / **wide** | +2 sur 8 petits ≫ +2 sur 3 gros → couronne les essaims rang-1 (`husk`, `footman`, `gnaw_rat`) |
| **La Litanie Sourde** | équipe +10 % durée d'affliction | colle DoT générale | plus de ticks pour **toutes** les familles à la fois |

### B — Spécialistes *(portée conditionnelle → moyen/fort ; sélecteurs de stratégie)*
| Commandant | Aura | Définit | Synergie roster |
|---|---|---|---|
| **Le Roi des Rats** | unités **tier-1** : +50 % PV & dmg | *reroll-wide* | `spore_tick`/`ash_moth`/`carrion_pecker`/`live_wire` montées niv.3 = une armée *(exemple de l'user)* |
| **L'Aïeul** | unités **niveau 1** : +40 % stats | *late-game max-tier* | tes légendaires (`deep_kraken`, `skull_colossus`, `ash_maw`), jamais niv.2, à fond *(exemple de l'user)* |
| **Le Prophète de Cendres** | les feux de l'équipe ne décroissent plus | mono-**burn** | l'effet d'`ash_maw` porté par le commandant → **libère** `ash_maw` pour le board ; `emberling`/`bellows_priest` = fournaise |
| **Le Vénéfice** | le poison de l'équipe ignore son cap de stacks | mono-**poison** | `festering`-en-aura ; `spore_tick` (cadence rapide) empile sans plafond |
| **Le Maréchal de Front** | colonne avant : +armure · arrière : +dmg | **ligne** | *les « passifs de ligne » différés de la roadmap, portés par un commandant* : `gravewarden` encaisse, `thunderhead`/`witch` cognent |
| **Le Capitaine d'Essaim** | si **6+ unités** : équipe +X | go-wide | rejoint le `swarm_logic` du roadmap-lab |

### C — Couronnes *(portée mono-cible → TRÈS fort ; ciblage par rôle, §9.3)*
| Commandant | Aura | Définit | Synergie roster |
|---|---|---|---|
| **La Couronne d'Échos** | la plus **avancée** : ×2 multicast | un carry hyper-amplifié | double **tous** ses procs ; place `corruptor`/`witch` devant ⚠️ combo à border (§11, §15) |
| **Le Diadème de Fer** | la plus **en arrière** : invulnérable aussi | protège un verre-canon | `thunderhead`/`witch` à l'arrière = DPS garanti **et** intouchable |
| **L'Oraison du Tyran** | la plus **chère** : effets appliqués ×2 | amplifie une légendaire | `deep_kraken` (double poison), `necro_leech` (double amputation) |

### D — Avancés / hors-norme
| Commandant | Aura | Définit | Note |
|---|---|---|---|
| **Le Charognard Couronné** | +1 or / victoire | greed / scaling éco | touche `run/state`, pas le combat — plus lourd (T3) |
| **La Bannière du Bris-Siège** | combat_start : boucliers ennemis ÷2 | **anti-méta** | `strip_shield` en aura d'ouverture → **égalisateur** contre les murs (`templar`/`oath_keeper`/`ward_weaver`) ; respecte le pilier « jamais un gate » |
| **Le Hérault d'Orage** | une décharge choc arque sur +1 cible | croisé shock | `forked-tongue`-en-aura : `live_wire`/`arc_warden` = nettoyage de ligne |

---

## 11. Synergies émergentes (combos profonds, unités nommées)
1. **Couronne d'Échos → `corruptor` (devant) + `miasma_acolyte` (voisin)** : ×2 multicast double la
   pose de stacks **et** de weaken par frappe ; l'aura voisine (+50 % dps poison) amplifie chaque stack
   → snowball. **C'est le combo le plus dangereux** ; les caps existent comme garde-fous
   (`POISON_STACK_CAP=8`, `WEAKEN_CAP=0.40`) — à valider en sim.
2. **L'Aïeul → `deep_kraken`** : ta carry poison de fin de partie devient forte **sans la tripler**.
   Résout pile la frustration « j'ai un top-tier mais jamais niveau 2 ».
3. **Le Maréchal de Front → `gravewarden` (front) + `thunderhead` (arrière)** : doctrine de ligne
   complète, et le **sigil « ligne » trouve enfin son archétype** (rejoint le chantier sigils).
4. **Le Diadème de Fer → `venom_censer` (arrière)** : intouchable, il survit assez longtemps pour armer
   ses détonations poison→feu sur tout le front.
5. **La Bannière du Bris-Siège** comme **contre-méta** : si le méta async se remplit de murs de
   boucliers, ce commandant est l'égalisateur — le rôle « jamais un gate, toujours un égalisateur » des
   reliques.

---

## 12. La recherche game design — méthode, précédents, sources

### 12.1 Méthode
Deux passes de recherche distinctes ont alimenté ce document :
- **Passe n°1 (interne)** : digestion des docs `docs/roadmap-lab/` + `progression-economy-prd.md` pour
  extraire le diagnostic « trop d'afflictions » et les mécaniques non-DoT déjà proposées (résultat
  intégré en §2.6).
- **Passe n°2 (web, sourcée)** : recherche GD sur les systèmes « commandant/héros » d'autobattlers
  comparables, conforme à la règle de vérification du projet. Requête : précédents, principe
  portée×puissance, buffs conditionnels, héros invulnérable/persistant, diversité des picks,
  anti-patterns. Résultats ci-dessous, sources en Annexe A.

### 12.2 Précédents (pouvoir global attaché à un héros/augment)
- **Hearthstone Battlegrounds (Heroes + Hero Powers)** : on choisit un héros ; chacun a un pouvoir
  unique, souvent **1×/tour** (borne structurelle). Deathwing = **+2 ATK à TOUTES les unités** (passif
  board-wide *faible*). Bornage par **Armor 5–20** : les héros plus faibles démarrent avec plus
  d'armure (bouton de tuning). **Le héros ne combat PAS** (il fournit pouvoir + réserve de vie).
- **Storybook Brawl (Heroes)** : ~40+ héros, chacun un **bonus passif** qui change la stratégie (Merlin :
  +1/+2 permanent à une carte par sort ; Cruel-Ella : buff conditionnel aux cartes « evil »).
- **TFT (Augments / Legends / Portals)** : Augments = pouvoirs structurants choisis en partie ; Legends =
  héros qui **garantissent l'accès** à certains Augments ; Portals = variance par partie. Leçon clé en
  §12.6.
- **Dota Underlords (Alliances)** : pas de héros-buff central ; les bonus globaux passent par les
  **Alliances** (paliers 2/4/6/9 — anti-snowball par **seuils de comptage**).
- **Mechabellum (Specialists)** : un Specialist choisi avant le match (crédits/round, déblocages,
  armes orbitales). **Chacun oriente un archétype + a des contre-picks** → diversité.
- **Super Auto Pets** : **aucun héros** — choix assumé de simplicité (contre-exemple notable).
- **Wildfrost (Leader)** : le Leader est une **unité combattante** avec une capacité, mais **il doit
  survivre** : sa mort = run perdu. **Précédent direct** du « le héros reste, sa mort = défaite ».
- **Backpack Battles** : **pas de héros** ; la puissance émerge des **synergies d'adjacence** d'objets.

### 12.3 Principe portée × puissance
- Formalisé côté gamification (Yu-kai Chou, « The Aura Effect ») : la valeur ressentie d'une aura =
  effet **× nombre de cibles**. Corollaire : plus la portée est large, plus l'effet unitaire doit être
  faible. **La frontière de l'aura doit être VISIBLE** (sinon « feel unfair »).
- **Limite** : pas de talk GDC qui l'énonce littéralement « armée = faible / unité = fort ». Le principe
  est **appliqué empiriquement** (HS:BG : Deathwing +2 board-wide vs buffs ciblés bien plus gros), pas
  théorisé dans une source primaire de designer vérifiable.

### 12.4 Buffs globaux conditionnels (tier/tribu/niveau)
- HS:BG et Storybook conditionnent souvent le buff à un sous-ensemble (tribu/évènement) ; bornage par
  **coût en gold/tour** et **gate de condition** (ex. Queen Azshara s'active à 25 ATK de warband).
- Dota Underlords : bonus par tribu, **seuils de comptage** (investir N unités pour débloquer).
- Mechabellum : Specialist ciblé (ex. +range **aux aériens uniquement**) — fort **mais étroit**, payé
  par l'abandon du reste du roster.
- **Anti-cassure récurrent** : le buff conditionnel est fort **mais étroit** (une tribu/un tier), donc
  payé par une perte de flexibilité ; souvent à coût en or par activation.

### 12.5 Héros invulnérable / persistant — et ses pièges
- **Wildfrost** : précédent direct de « leader persistant, mort = défaite ». **Piège documenté** :
  déséquilibre des Leaders aléatoires → les joueurs réclament un **reroll** (certains sont nettement
  supérieurs).
- **Dota 2 Underlord (Atrophy Aura)** : aura qui affaiblit toute l'armée ennemie (−8/16/24/32 %), mais
  **uniquement la *base* damage**, pas le total — pour **éviter l'explosion late-game**. Détail de
  bornage instructif. (Ce héros **n'est pas immortel**.)
- **HS:BG** : le héros **ne participe pas** au combat (l'inverse du design proposé).
- **Constat majeur** : **aucun précédent vérifié** ne fait « **invulnérable + attaque + sur le board** ».
  Les précédents qui laissent un héros infliger des dégâts le **rendent vulnérable** précisément pour
  qu'il ne décide pas seul des combats. Le « immortel-qui-attaque » reste **non corroboré**.

### 12.6 Diversité des picks
- HS:BG : pas d'équilibre parfait reconnu ; outils = **Armor par héros** (tuning) + **offre de
  plusieurs héros au choix** (jamais un héros imposé).
- **TFT — leçon Riot explicite** : garantir l'accès à un Augment via un Legend exige un Augment
  **quasi parfaitement équilibré**, sinon « tu le prends chaque partie » → **méta forcée**. Riot a
  overbuffé des Legends pour les rendre viables, ce qui a aggravé les cas cassés → **ils ont retiré les
  Legends du set suivant**.
- Mechabellum : diversité car chaque Specialist **oriente un archétype** (avec contres) plutôt que
  d'être strictement supérieur.

### 12.7 Anti-patterns documentés
- **« Garantir » un pouvoir fort = méta forcée** (Riot l'a reconnu et supprimé). → **ne pas rendre
  déterministe l'accès au commandant le plus fort**.
- **Interactions combinatoires non bornées** : « Portals × certains Augments ont fait sauter le toit des
  attentes d'équilibrage » → un effet global qui **multiplie** avec d'autres systèmes devient
  ingérable. (Pertinent pour notre multicast × afflicteur × ampli.)
- **Héros aléatoires d'inégale valeur sans reroll** = frustration (Wildfrost).
- **Aura sans frontière visible** = « feel unfair » → montrer la portée/condition.
- **Scaling base vs total** : appliquer un aura global aux dégâts **totaux/finaux** est un classique
  cassé ; l'appliquer à la **base** (comme l'Atrophy Aura) évite l'explosion.

### 12.8 Limites de la recherche (honnêteté)
- (a) Pas de source primaire de designer formalisant noir-sur-blanc « armée=faible / unité=fort » (le
  principe est appliqué, pas théorisé dans une source vérifiable).
- (b) Le wiki Underlords (autobattler) a renvoyé un 403 → pas de confirmation d'un commandant immortel
  dans **ce** jeu précis. **Wildfrost reste le meilleur précédent du « leader persistant dont la mort =
  défaite ».**

---

## 13. Ce que la recherche change pour notre design

### CONFIRME
- **Portée × puissance** (nos 3 paliers, §9.1) — empiriquement validé (HS:BG) + théorisé (Aura Effect).
- **Spécialistes = sélecteurs d'archétype avec contres** (Mechabellum) = nos commandants conditionnels.
  La diversité vient de « chacun oriente un style + a des contres », pas d'un équilibrage parfait.

### AJOUTE — 4 règles à graver
1. **L'aura est liée à la POSSESSION de l'unité** → accès *gaté par la boutique*, jamais garanti.
   Leçon TFT : *garantir* l'accès au pouvoir le plus fort = méta forcée (Legends retirés). Chez nous
   c'est déjà sain — pour jouer « L'Aïeul » il faut avoir **drafté** cette unité. **À ne surtout pas
   casser** en ajoutant un moyen de piocher librement le commandant voulu.
2. **Les auras scalent sur la stat de BASE, jamais sur le total amplifié.** (Underlord Atrophy Aura =
   base damage only, anti-explosion late.) Bonne nouvelle : la couche `Stats` fait déjà ça (`increased`
   = additif sur la base). **Règle : auras en `increased` ; `more` (multiplicatif) réservé aux cas rares.**
3. **La portée doit être VISIBLE** — au survol du commandant, **éclairer les unités affectées** (rejoint
   le surlignage d'arêtes du roadmap-lab).
4. **Slot opt-in / débloqué**, pas imposé (Super Auto Pets prouve qu'un autobattler tient *sans* héros)
   → profondeur *en plus*, à déverrouiller en cours de run, pas un impôt sur le débutant.

### CHALLENGE — l'invulnérable-qui-attaque (le drapeau rouge)
**Aucun précédent vérifié ne fait « invuln + attaque + sur le board ».** Les deux modèles éprouvés
divergent, et chacun *évite* précisément ça : HS:BG (le héros ne combat pas) ; Wildfrost (il combat à
pleine puissance mais **peut mourir**, sa mort = run perdu). Le modèle de l'user (invuln + cadence
lente, §9.2) est un **chemin du milieu inédit** : viable, mais **non éprouvé → il vivra ou mourra par
la sim**.

**Le fork ouvert A/B/C pour le *corps* du commandant** :
| Voie | Précédent | Gain | Coût |
|---|---|---|---|
| **A. Invuln + cadence lente** *(vision de l'user)* | aucun | garde « il combat » **et** immortel | inédit, sim-dépendant ; repli sur B si dégénéré |
| **B. Fanal pur** (n'attaque pas) | HS:BG ✓ | le plus sûr | perd « il combat » |
| **C. Mortel-protégé** (combat plein, peut mourir → mort = défaite) | Wildfrost ✓ | **ajoute du counter-play** (sniper le héraut ennemi) | abandonne l'invuln ; complique le ciblage async |

**Avis** : garder **A** (préserve le fantasme ; `arena.lua:247` la rend triviale), en sachant que c'est
la pièce la plus susceptible de bouger. **C** est tentante : elle troque l'invuln contre un mini-jeu
« protège ton héraut, snipe le sien » — une profondeur que l'invuln *supprime*. (Et la condition de
défaite de Wildfrost = celle de l'user, juste déplacée du board au leader.)

---

## 14. Registre des décisions ouvertes (forks)

| # | Question | Statut | Reco / note |
|---|---|---|---|
| F1 | Corps du commandant : voie A / B / C ? | **OUVERT** (le plus structurant) | A par défaut ; B = repli sûr ; C = counter-play |
| F2 | Passif de board conservé en commandement ? | **Révisé** | Oui, kit complet **+ cadence lente** (§9.2), pas modes-exclusifs |
| F3 | Slot obligatoire ou débloqué ? | Reco | Débloqué en cours de run (opt-in) |
| F4 | Aura sur toutes les unités ou sous-set curé ? | Reco | Sous-set curé d'abord, extension ensuite |
| F5 | Aura scale avec le niveau (duplicatas) ? | Reco | Oui |
| F6 | Commandant affligeable/soignable par l'ennemi ? | Reco | Non (pas de PV) ; reçoit les buffs de SA team |
| F7 | Position/visuel du trône | Reco | Piédestal distinct, hors graphe de sigil |
| F8 | Ciblage mono-cible | **Tranché (reco forte)** | Par **rôle** géométrique, pas par case (§9.3) |
| F9 | Multicast = entier ou % ? | **Tranché** | **Entier** (déterministe) |
| F10 | Amélioration des sigils | Lié | Même chantier que les commandants (§9.3) |
| F11 | Combo multicast × afflicteur × ampli | **À simuler** | LA classe de bug à border (caps existants) |

---

## 15. Risques connus & garde-fous
- **Combo snowball** (Couronne d'Échos × afflicteur × aura d'ampli) : le plus dangereux. Garde-fous =
  les caps existants (`POISON_STACK_CAP=8`, `WEAKEN_CAP=0.40`, `SHOCK_STACK_CAP=8`, `BLEED_DPS_CAP`).
  **À éprouver en sim avant tout déploiement.**
- **DPS gratuit garanti** (invuln) : maîtrisé par la cadence lente (voie A) ; le commandant **ne bloque
  pas** (hors-board, ne soak aucun coup) → il n'ajoute que de l'offense à *sa* course, l'ennemi tue le
  board au même rythme. Borné par « board défait = défaite ».
- **Méta forcée** : éviter tout accès *garanti* au meilleur commandant → l'aura reste **gatée par la
  boutique** (règle §13.1).
- **Explosion late** : auras sur la **base** (`increased`), jamais sur le total (règle §13.2).
- **Lisibilité** : portée d'aura **visible** (règle §13.3) ; slot **opt-in** (règle §13.4).
- **Déterminisme** : multicast entier (zéro RNG) ; crit éventuel via RNG **seedé** uniquement
  (`ctx.arena.rng`) ; tous les `%` via `Stats` (`increased` additif, ordre-indépendant).
- **Snapshot async** : le choix de commandant + son aura doivent être **capturés dans le snapshot**
  (c'est une partie du build). Implication mineure mais à ne pas oublier.

---

## 16. Prochaines étapes suggérées
1. **Trancher F1 (voie A/B/C)** — conditionne la moitié de l'équilibrage du corps du commandant.
2. **Prototyper le keystone moteur** : généraliser `aura_stat` + brancher `Stats` sur `dmg` (débloque
   hâte/armure/regen/empower d'un coup), puis `mark_vuln`. Golden-safe, T1.
3. **Spécifier 4-6 commandants v1** (1 par groupe A/B/C + 1 anti-méta) pour un premier passage en sim.
4. **Brancher `tools/sim.lua`** sur le combo F11 (multicast × afflicteur × ampli) avant d'ouvrir le pool.
5. **Lier au chantier sigils** (§9.3) : les rôles géométriques (front/centre/arrière) donnent leur sens
   aux formes.
6. **(Plus tard)** Le multicast (work-queue budget 256, T2) et les mécaniques T3 (summon, repositionnement,
   économie) à la demande du contenu.

---

## Annexe A — Sources (recherche GD, passe n°2)
- Hearthstone Wiki — Battlegrounds Hero Power : https://hearthstone.wiki.gg/wiki/Battlegrounds/Hero_Power
- Icy Veins — HS:BG Mechanics Guide : https://www.icy-veins.com/hearthstone/hearthstone-battlegrounds-mechanics-guide
- Blizzard Watch — Hero armor balance : https://blizzardwatch.com/2021/12/14/hearthstone-battlegrounds-hero-armor-balance/
- HearthstoneTopDecks — BG Heroes guide : https://www.hearthstonetopdecks.com/guides/hearthstone-battlegrounds-heroes-tier-list-guides/
- GeekWire — Storybook Brawl preview : https://www.geekwire.com/2021/preview-magic-pros-hearthstone-vets-team-card-game-auto-battler-storybook-brawl/
- Storybook Brawl Wiki — Gameplay : https://storybook-brawl.fandom.com/wiki/Gameplay
- Riot /Dev (TFT) — Runeterra Reforged Learnings : https://teamfighttactics.leagueoflegends.com/en-us/news/dev/dev-tft-runeterra-reforged-learnings/
- Esports Tales — Dota Underlords Alliances : https://www.esportstales.com/dota-underlords/alliances-hero-units-synergy-list
- MechaMonarch — Mechabellum Starting Specialists : https://mechamonarch.com/guide/mechabellum-starting-specialists/
- Mechabellum Wiki — Specialists : https://mechabellum.wiki/index.php/Specialists
- CBR — Super Auto Pets vs TFT/BG : https://www.cbr.com/super-auto-pets-autobattler-tft-hearthstone-battlegrounds/
- Wildfrost Wiki — Leaders : https://wildfrostwiki.com/Leaders
- Wildfrost (Steam) — Leader unbalance : https://steamcommunity.com/app/1811990/discussions/0/3826413850816988247/
- Wildfrost (Steam) — Leader reroll suggestion : https://steamcommunity.com/app/1811990/discussions/0/3820783808418182304/
- Liquipedia — Dota 2 Underlord (Atrophy Aura) : https://liquipedia.net/dota2/Underlord
- Casual Game Guides — Backpack Battles synergies : https://casualgameguides.com/walkthroughs/backpack-battles/item-synergies-and-scaling
- Yu-kai Chou — The Aura Effect (Game Technique #9) : https://yukaichou.com/advanced-gamification/the-aura-effect-in-gamification-design-game-technique-9/

> **Passe n°1 (interne, non-web)** : `docs/roadmap-lab/{ROADMAP.md, OPEN-QUESTIONS.md, 00-state.md,
> round-*.md}`, `docs/research/progression-economy-prd.md`, `docs/research/{effects-design.md,
> effects-dot-families.md, balance-sim-design.md, gd-research-result.md}`.

## Annexe B — Références code citées (état des lieux & faisabilité)
- `src/effects/engine.lua` — moteur ouvert/fermé ; `register` (19-24), `passCondition "chance"` (29),
  `run` (38-48).
- `src/effects/ops.lua` — vocabulaire d'ops (afflictions + agnostiques) ; framework payoff (DOT_CAP_MULT,
  BLEED_DPS_CAP).
- `src/effects/stats.lua` — `resolve(base, mods, opts)` = `(base+Σflat)·(1+Σinc)·Π(1+more)` clampé ;
  `increased` additif (déterministe, sans tri) ; `mods=nil` → base (golden-safe).
- `src/data/units.lua` — roster ~83 unités (data pure) ; `aggro`/`taunt`/`haste`/`dmgReduce`/
  `secondBreath` (champs spec).
- `src/combat/arena.lua` — invuln `return 0` (247, SACRED SHIELD) ; `dmgReduce` (257) ; `secondBreath`
  (274) ; `chooseTarget` (184-209) ; `neighborsOf` (216-227) ; `plagueAmp` template vuln (248-254) ;
  `hit()` `ctx.amount=a.dmg` (319) ; `dischargeShock` chain/transfer (342-390) ; `haste` consommé (581) ;
  `on_death` broadcast (626-639) ; décompte des vivants / victoire (642-647) ; `teamFlags` (`grant_team`).
- `src/scenes/build.lua` — résolution d'auras au build (482-511) ; branche à généraliser en `aura_stat`
  (499-503).
- Roadmap moteur (`engine-architecture.md` §12) : « Buckets de modifiers (% de stat) », « Work-queue
  d'effets (budget 256) » = les deux tâches débloquées par ce chantier.

## Annexe C — Glossaire
- **Affliction / DoT** : altération qui inflige des dégâts/effets au fil du temps (burn/bleed/poison/rot/
  shock). Le **silo** que ce document cherche à dé-monopoliser.
- **Enabler agnostique** : effet qui amplifie **n'importe quelle** source (multicast/hâte/vuln/empower) ;
  **multiplicateur** de synergies, indépendant des familles.
- **Multicast (entier)** : nombre **garanti** de frappes par swing (×1 défaut, ×2, ×3). Déterministe
  (pas de probabilité). Chaque frappe re-déclenche les on_hit → multiplie les procs.
- **Portée × puissance** : budget d'équilibrage = magnitude × nombre de cibles. Team → faible ;
  conditionnel → moyen ; mono-cible → fort.
- **Ciblage par rôle** : la cible d'une aura mono-cible est définie par une **propriété géométrique**
  (front/arrière/centre/coût) dérivée du sigil, **pas** par une case fixe → sigil-invariant.
- **Couche `Stats` (increased/more)** : `increased` = % additifs sur la **base** (déterministe) ;
  `more` = % multiplicatifs (rares). Les auras de commandant doivent privilégier `increased`.
- **Golden-safe** : tant qu'aucune unité ne porte un nouvel effet, l'empreinte de régression (golden-log)
  reste inchangée (`mods=nil` → base ; flags `nil` → inertes).
- **`teamFlags` / `grant_team`** : mécanisme existant de drapeaux d'équipe posés à `combat_start` ; le
  véhicule naturel des **auras de commandement** team-wide.
- **Voie A / B / C** : modèles pour le corps du commandant — A (invuln + cadence lente, inédit),
  B (fanal pur, HS:BG), C (mortel-protégé, Wildfrost).
