# The Pit — Brainstorm : Les Murmures (couche cachée d'affinités)

> **Date** : 2026-06-23
> **Statut** : EXPLORATION / DESIGN — **aucun code écrit**, rien d'acté.
> **Lien** : ce document est la **suite directe** de
> [`commanders-and-effect-diversity-brainstorm.md`](./commanders-and-effect-diversity-brainstorm.md).
> Il en constitue la **3e couche**. Le premier doc couvre (1) la diversité des effets agnostiques et
> (2) le système de Commandant. Celui-ci ajoute (3) **les Murmures** : une couche **cachée** d'affinités
> de lore. À lire après le premier pour le contexte (état des lieux du moteur, refs code, pilier
> déterministe, Grimoire/Bestiaire, Chronique de combat).
> **Nature** : brainstorm autonome, retrace la genèse de l'idée, le débat qui l'a façonnée, le contrat
> de design, et une **analyse concrète du roster**.

---

## 0. La trinité d'identité par unité

Chaque unité de The Pit porte désormais **trois couches** distinctes, qui servent trois motivations :

| Couche | Visibilité | Sert | Statut |
|---|---|---|---|
| **1. Passif / capacité** | claire, affichée | l'optimiseur (theorycraft de base) | existant |
| **2. Bonus de commandement** | claire, choisie | le stratège (doctrine) | brainstorm — doc #1 |
| **3. Murmure** (affinité cachée) | **cachée**, découverte | l'explorateur / l'amoureux du lore | **ce document** |

Le theorycraft « public » repose sur les couches **1 et 2** (clair, lisible — c'est le socle). La
couche **3** est un **easter egg** : elle ne remplace rien, elle *enrichit*. C'est le point central du
débat qui a produit ce doc (§1).

---

## 1. La genèse — et le débat qui a façonné les règles

### 1.1 L'idée de l'utilisateur
> « Chaque unité aurait une **troisième capacité, cachée** par rapport à sa description et son lore. En
> lisant la description, on ne l'apprendrait pas — il faudrait le **comprendre**, ce serait très
> subtil : par exemple, telle unité a +10 % de stats si elle est à côté de telle autre, parce qu'elles
> sont de la même famille ou qu'elles ont une histoire ensemble. Et ça pour **chaque** unité. »

### 1.2 Le drapeau rouge initial (et pourquoi il était mal cadré)
Première réaction : danger, c'est le **modèle cryptique-à-déduire + leurres** déjà **retiré** en 2026-06
(`CLAUDE.md` §2 : *« pas fan des leurres, trop compliqué pour pas grand-chose »*).

**Le contre-argument de l'user (juste)** : le drapeau rouge visait à empêcher que **TOUT** le
theorycraft soit cryptique. Il ne propose **pas** de revenir au tout-cryptique : il ajoute **une couche
de spice par-dessus des fondations claires**, un easter egg que les gens ne remarqueront pas tout de
suite, et qui se révèle **dans les logs**. Ça ne bouleverse pas une partie.

**Position révisée (acceptée)** : la distinction tient. Les objections initiales (contre-courant de la
lisibilité, feel-unfair async, déduction qui collapse en wiki, vecteurs intunables, surcharge de
lecture) **tombent** une fois posé que : (a) le socle reste clair, (b) ça se révèle dans le **Journal**
(la Chronique de combat existe déjà), (c) c'est **loggé donc tunable en sim**, (d) ça n'entre pas dans
la décision de build. **La seule réserve ferme conservée** devient le contrat §2.1 ci-dessous.

---

## 2. Le contrat de design (les règles, issues du débat)

### 2.1 ⚖️ Plafonné à du *spice* — sinon ça GRADUE en visible
> **La couche cachée ne porte JAMAIS un effet assez fort pour qu'on veuille *construire autour*. Tout
> effet de cette force-là doit graduer en couche visible (passif ou commandement).**

Pourquoi : à la seconde où un truc caché devient *build-defining*, on retombe dans la dépendance au
wiki. Le doute de l'user (« ça ne rendra pas une team forte… ou alors peut-être que si ») est lui-même
le signal d'alarme : **si la réponse est « si », l'effet ne doit plus être caché.**

### 2.2 Bande de magnitude
- **~10 % de stat** (buff continu léger), **OU**
- **un effet ponctuel one-shot** : quelque chose qui n'arrive **qu'une seule fois** dans le combat (un
  sursaut, une étincelle), par opposition au passif qui tourne en continu. « Pas trop fort, mais sympa
  et **visible quand même**. »
- Tout est **testable en sim de masse** (`tools/sim.lua`) : on repère le trop-fort / pas-assez-fort.

### 2.3 🔒 Cryptique JUSQUE DANS LE LOG (la précision clé de l'user)
Le Murmure se révèle dans le Journal, **mais sans jamais donner la vraie valeur**. Exemple de l'user :
si une unité fait +10 % de dégâts en présence d'une autre, le Murmure **ne dit pas** « +10 % de
dégâts ». Il reste **cryptique** :

> *« Il semblerait que, par la présence de [Y], [X] ait été renforcé… »*
> *« [X] frappe avec une fureur nouvelle quand [Y] est là. »*

→ **Les vraies valeurs restent cachées ; seul le designer les connaît.** Le joueur *sent* qu'un lien
s'est noué, sans en lire la fiche technique. (Implémentation à deux canaux : §4.)

### 2.4 Découvrable par OBSERVATION, pas par déduction
On ne demande pas au joueur de *déduire* le Murmure d'un texte d'ambiance (c'était le piège du
tout-cryptique). On le laisse **tomber dessus** : il joue, le Murmure se déclenche, le Journal le
**signale** (cryptiquement). La découverte communautaire (wiki, partage) devient une *feature*
d'easter egg, pas un bug.

### 2.5 Tunable — deux canaux de log
- **Canal DEV (event-log JSONL, `tools/eventlog.lua` + `sim.lua`)** : porte les **vraies valeurs**
  (magnitude, source, partenaire) → attribution, drapeaux d'outliers (métriques P3), équilibrage.
  *Seul le designer / les outils le lisent.*
- **Canal JOUEUR (Chronique / Journal)** : ne rend qu'un **murmure cryptique**, sans chiffre (§2.3).

### 2.6 Tout seedé + snapshoté (déterminisme — exigence de l'user)
- Toute RNG d'un Murmure (ex. chance d'esquive) passe par le **RNG seedé injecté** (`ctx.arena.rng`),
  **jamais** le global → rejouable à l'identique.
- Les Murmures sont des **données statiques par id d'unité** → un snapshot qui capture les ids capture
  les Murmures **gratuitement**. Il faut juste s'assurer que les Murmures d'un **ghost se déclenchent
  aussi** pendant le combat rejoué (les deux camps). « Tout est fait confondu — les easter eggs aussi. »

---

## 3. Taxonomie des Murmures

### 3.1 Murmures de lignée (DUO)
Une affinité entre **deux unités précises**, justifiée par le lore : **même famille** (céphalopodes, morts,
constructs…) ou **histoire commune** (la sorcière et son démon, le soufflet et le bûcher). Déclencheur
typique : **présence sur le terrain** ou **adjacence**.

### 3.2 Murmures solitaires (SOLO-CONDITIONNEL)
Une propriété qui s'active sur **position** ou **état** de l'unité seule. Exemple de l'user : *« certaines
unités sont lâches — si elle est le plus au fond possible, elle a 5–10 % de chance d'esquive. »*
Déclencheurs : position (front/fond), solitude (seule de son type / de sa colonne), seuil de PV, durée
de combat, mort d'un voisin.

### 3.3 Les déclencheurs (tous dérivables de l'état existant)
| Déclencheur | Dérivé de | Coût moteur |
|---|---|---|
| Présence d'une unité X sur le terrain | scan de `self.units` à combat_start | nul |
| Adjacence à X | `board:neighbors` (build) ou `arena:neighborsOf` (combat) | existant |
| Position front / fond | `depth` (déjà calculé : `maxCol - cell.x`) | nul |
| Seule de son type / colonne | scan filtré | nul |
| Seuil de PV | `hp / maxHp` | nul |
| Durée de combat | `self.t` | nul |
| Mort d'un voisin / d'un ennemi | trigger `on_death` (existe) | existant |
| Chance (esquive) | `ctx.arena.rng:random()` (seedé) | nul (hook esquive à ajouter, cf. §7) |

---

## 4. Le format de l'événement « Murmure » (cryptique)

Le bus émet un événement riche ; **deux abonnés le rendent différemment** :

```
bus:emit("murmur", {
  key      = "<clé i18n du murmure>",   -- ex. "pact_witch_demon"
  source   = <unité>,                    -- X (bénéficiaire)
  partner  = <unité|nil>,                -- Y (duo) ou nil (solo)
  verb     = "<catégorie vague>",        -- pour le phrasé cryptique côté joueur
  -- CANAL DEV uniquement (jamais affiché au joueur) :
  trueKind = "stat_inc"|"dmg"|"dodge"|"resist"|"feed",
  trueValue = 0.10,                      -- la vraie magnitude (sim/event-log)
})
```

- **Catégories de verbe vague** (côté joueur, jamais de chiffre) : `renforcé` (stat ↑) · `frappe plus
  fort` (dégâts) · `se dérobe` (esquive) · `endure` (résistance) · `se repaît` (vol de vie / festin).
- Le Journal pioche un **phrasé poétique** par catégorie (i18n : `whisper.<key>.cryptic`), interpole les
  **noms** des unités, **jamais** la valeur.
- L'event-log dev garde `trueKind/trueValue` pour l'attribution et l'équilibrage. **Golden-safe** : aucun
  abonné SIM ne change l'issue au-delà de l'effet lui-même (comme `affliction_applied`).

---

## 5. Analyse du roster — propositions concrètes

> Noms de Murmures = placeholders évocateurs. Effets = **spice** (≤ ~10 % ou ponctuel), à tuner en sim.
> Réfs unités = ids réels de `src/data/units.lua`. Chaque ligne respecte le contrat §2.

### 5.1 Murmures de lignée (DUO), regroupés par « cercle » thématique

**🔥 Le Cercle de la Forge** (culte du feu)
| Paire | Justification lore | Effet caché (spice) | Déclencheur |
|---|---|---|---|
| `bellows_priest` ↔ `pyre_tender` | le soufflet attise le bûcher | 1re brûlure posée par la paire = **ponctuel** plus intense | adjacence |
| `kiln_warden` ↔ `pyre_herald` | le four et son héraut | +10 % durée de brûlure entre eux | adjacence |
| `ash_moth` ↔ tout `burn` | la phalène tourne autour de la flamme | +10 % stat tant qu'un feu est actif | présence d'un feu |

**🪱 La Cour Nécrotique** (pourriture / essaim / mort)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `maggot_king` ↔ `carrion_pecker` | le roi des asticots et les charognards, même cour | +10 % vitesse d'enflure du rot du roi | présence |
| `blight_spreader` ↔ `maggot_king` | le fléau sert son roi | propagation **ponctuelle** un peu plus large à 1 mort | présence + on_death |
| `gravewarden` ↔ `husk`/`skeleton` | le gardien veille sur ses morts | +10 % armure | adjacence à un mort-vivant |
| `gnaw_rat` ↔ `husk` | les rats nichent dans la charogne | +10 % cadence | adjacence |
| `bore_worm` ↔ `necro_leech`/`patient_worm` | les vers de la décomposition | +10 % rot | présence |

**🐙 Le Conclave Abyssal** (céphalopodes / kraken)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `deep_kraken` ↔ `ink_horror`/`corruptor`/`acid_maw` | le léviathan et sa couvée | la couvée : +10 % stat près du kraken | présence du kraken |
| `ink_horror` ↔ `corruptor` | l'encre et la corruption | +10 % dps poison entre eux | adjacence |

**🩸 Le Pacte** (sorcellerie)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `witch` ↔ `demon` | la sorcière a invoqué le démon ; le contrat tient | **ponctuel** : 1er sang du démon = petit sursaut de venin de la sorcière | adjacence |

**🗡️ Les Hors-la-loi**
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `marauder` ↔ `bandit` | la bande : les brigands chassent en meute | +10 % dégâts (hardiesse du nombre) | adjacence |

**⛪ L'Ordre Dévoyé** (ironie grimdark : même la « foi » pourrit dans le Puits)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `zeal_inquisitor` ↔ `templar`/`oath_keeper` | la même foi (corrompue) | +10 % stat (zèle partagé) | adjacence |
| `plague_doctor` ↔ un afflicteur allié | le médecin étudie la peste | +10 % regen près d'un poseur d'affliction | présence |

**⚡ Le Chœur d'Orage**
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `stormcaller` ↔ `live_wire`/`thunderhead` | l'appeleur et le courant vivant | +10 % cap/durée de charge | présence |
| `storm_anchor` ↔ `stormlord` | l'ancre tient l'orage du seigneur | +10 % persistance | adjacence |

**⚙️ Les Rouages** (constructs)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `rust_sentinel` ↔ `footman`/`runestone_golem` | les machines se reconnaissent, opèrent en formation | +10 % stat | adjacence à un construct |

**👁️ Les Ailés / le Culte de l'Indicible** (Lovecraft)
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `byakhee` ↔ `pyre_herald`/`soot_acolyte` | la monture porte le célébrant entre les étoiles | +10 % cadence (la monture s'élance) | adjacence à un robe/culte |
| `venom_censer` ↔ un robe/culte | l'encensoir balancé dans le rite | +10 % dps poison en rituel | adjacence |

**👻 Les Spectres**
| Paire | Justification lore | Effet caché | Déclencheur |
|---|---|---|---|
| `wailing_shade` ↔ un autre `bone`/spectre | les fantômes hantent à plusieurs | **ponctuel** : 1er cri = petit slow bonus | présence |

### 5.2 Murmures solitaires (SOLO-CONDITIONNEL)

| Unité | Nom | Condition | Effet (spice) | Lore |
|---|---|---|---|---|
| `bandit` | **Le Lâche** | la plus au fond (depth max) | **5–10 % d'esquive** (RNG seedé) | un voleur ne meurt pas en première ligne *(exemple de l'user)* |
| `gnaw_rat` | **Couard** | la plus au fond | 5 % d'esquive | la vermine fuit le danger |
| `ash_moth` | **Phalène** | un feu actif sur le terrain | +10 % stat | attirée par la flamme |
| `marauder` | **Tête de Charge** | tout devant (depth 0) | +10 % dégâts | le berserker mène l'assaut |
| `gravewarden` | **Dernier Rempart** | seule survivante de sa colonne de front | +10 % armure | le serment du dernier mur |
| `skull_colossus` | **Le Titan Solitaire** | aucune autre unité `bone`/`crane` | +10 % stat | un colosse n'a besoin de personne |
| `patient_worm` | **Patience** | après ~N s de combat | +10 % stat | le ver attend son heure |
| `storm_anchor` | **L'Ancre** | la plus au fond | +10 % persistance de charge | l'ancre tient la tempête |
| `hollow_gut` | **Le Glouton** | à la mort d'un ennemi proche | **ponctuel** : petit soin | il se repaît des chairs |
| `husk` | **Vaisseau Creux** | à la mort d'un allié | +10 % stat (cumul borné) | la coquille absorbe le défunt |
| `demon` | **Festin** | sous ~30 % de PV | +10 % vol de vie | l'acharnement du damné |

---

## 6. Exemples de phrasés cryptiques (Journal)
*(le joueur voit ça ; jamais de chiffre — cf. §2.3)*
- *« Un murmure parcourt les rangs : par la présence du **Démon**, la **Sorcière** semble plus venimeuse… »*
- *« Le **Soufflet** attise quelque chose. Le **Bûcher** brûle d'un éclat nouveau. »*
- *« Le **Bandit** s'efface dans l'ombre — un coup l'a manqué. »* *(esquive)*
- *« Le **Colosse** se dresse, seul de son espèce, et se sent… plus grand. »*
- *« Les rouages du **Sentinelle de Rouille** s'alignent sur ceux du **Fantassin**. »*
- *« Quelque chose lie le **Kraken** à sa couvée. Elle frappe avec plus d'assurance. »*

---

## 7. Faisabilité moteur (légère)
- **Données** : un module `src/data/whispers.lua` (registre id → descripteur de Murmure
  `{ kind = "lineage"|"solo", trigger, condition, op, params, key }`), séparé de `units.lua` pour
  garder ce dernier *pur mécanique* et rendre les Murmures **curatables**. Les chaînes cryptiques vivent
  en i18n (`whisper.<key>.cryptic`).
- **Résolution** : par le même moteur d'effets (registre d'ops, `Effects.run`). Présence/adjacence =
  résolues à combat_start comme les auras ; position/seuil/durée = lues au tick ; mort = `on_death`.
- **Nouveaux hooks partagés avec le doc #1** : `on_threshold` (PV %) et un **hook d'esquive** (un flag
  lu dans `damage()` qui, sur un roll seedé, **annule** une frappe entrante — jumeau binaire de
  `dmgReduce`). Ce sont exactement les extensions déjà listées (doc #1 §6, roadmap moteur §12).
- **Déterminisme** : toute chance via `ctx.arena.rng` ; conditions = fonctions pures de l'état seedé →
  rejouable. **Snapshot** : gratuit (Murmures = data par id) ; vérifier que les deux camps les
  déclenchent au replay.
- **Golden-safe** : tant qu'aucune unité ne porte de Murmure (ou que le registre est vide), zéro
  émission → empreinte inchangée. Adoption progressive (rollout par vagues, pas les 83 d'un coup).

---

## 8. Garde-fous & risques
- **Magnitude creep** → la règle de **graduation** §2.1 : si un Murmure devient build-around, il passe en
  couche visible.
- **« Feel-bad » de ne jamais rien découvrir** → le murmure doit être **assez visible dans le Journal**
  pour que la découverte arrive ; la Chronique (P1 livré) est le bon endroit. Le Bestiaire **peut**
  garder une trace « tu as *pressenti* un lien » **sans** le détailler (reste cryptique).
- **Équilibrage** → la sim lit les **vraies valeurs** (canal dev) et sort les drapeaux d'outliers ; un
  duo caché cassé se voit.
- **Jamais requis pour gagner** → c'est du spice ; une partie se joue parfaitement sans connaître un
  seul Murmure.
- **Interaction avec les couches 1-2** → un Murmure peut renforcer un combo déjà fort (l'user l'admet) ;
  c'est *acceptable tant que ça reste petit* — le contrat §2.1 borne précisément ça.

---

## 9. Forks ouverts
| # | Question | Reco / note |
|---|---|---|
| M1 | Révélation : log-only à vie, ou trace au Bestiaire ? | **Log-only** + trace *cryptique* au Bestiaire (« lien pressenti », sans valeur) |
| M2 | Positif-only, ou tradeoffs savoureux autorisés ? | **Ouvert à tout** (l'user) — mais sous contrat §2.1 |
| M3 | Combien pour un v1 ? | Sous-set **curé** (les cercles les plus iconiques : Forge, Pacte, Conclave, Hors-la-loi), pas les 83 |
| M4 | Nom du système | **Murmures** (validé) ; sous-types : **Murmures de lignée** (duo) / **Murmures solitaires** (solo) |
| M5 | Magnitude exacte de la bande | ~10 % stat / 1 effet ponctuel — à figer puis **tuner en sim** |
| M6 | Esquive : binaire (annule la frappe) ou réduction ? | Binaire (lisible) — nouveau hook (§7) |

---

## 10. Prochaines étapes
1. **Figer le contrat de magnitude** (§2.2) et le **format d'événement `murmur`** (§4, deux canaux).
2. **Curer 8–12 Murmures v1** parmi §5 (mix lignée + solitaire) pour un premier passage en sim.
3. **Ajouter les hooks partagés** (`on_threshold`, esquive) — communs avec le doc #1.
4. **Brancher `sim.lua`** sur l'attribution des Murmures (canal dev) pour vérifier le plafond « spice ».
5. **Écrire les phrasés cryptiques** en i18n (le ton compte autant que la mécanique).
6. **(Plus tard)** Étendre par vagues vers le reste du roster, golden-safe.

---

## Annexe — Références
- **Doc lié** : `docs/research/commanders-and-effect-diversity-brainstorm.md` (couches 1-2 ; état des
  lieux moteur, refs code détaillées, pilier déterministe, Grimoire/Bestiaire).
- **Systèmes existants réutilisés** : Chronique de combat / Journal (P1 livré, modèle `chronicle.lua`) ;
  event-log JSONL (`tools/eventlog.lua`) ; bus d'événements (`src/core/bus.lua`) ; RNG seedé
  (`arena.rng`) ; snapshot async (`src/net/snapshot.lua`) ; Grimoire/Bestiaire
  (`src/core/grimoire.lua`, codex 2 onglets) ; sim de masse (`tools/sim.lua`, métriques P3).
- **Roster analysé** : `src/data/units.lua` (~83 unités ; types flesh/bone/order/arcane/abyss ; familles
  visuelles insecte/annelide/spectre/culte/aile/inquisiteur/reptile/arachnide/meduse/crane/automate/
  golem/cephalo/kraken/mortvivant/rongeur/gelatine).
- **Hooks à ajouter (partagés doc #1)** : `on_threshold`, hook d'esquive — cf. roadmap moteur
  (`engine-architecture.md` §12).
