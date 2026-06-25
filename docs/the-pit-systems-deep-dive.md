# The Pit — Profondeur & diversité des systèmes

> Présentation détaillée de l'overhaul des effets, des pouvoirs, de l'équilibrage et des
> simulations. Tout ce qui suit est **ancré dans le code réel** (valeurs exactes citées au
> `fichier:ligne` quand utile). Quand une fiche en jeu affiche un chiffre périmé, je donne **le
> chiffre du code** (la source de vérité du gameplay) — voir l'annexe « strings à corriger ».
>
> État au jalon **v0.9**. Beaucoup de valeurs sont des **placeholders d'équilibrage** assumés
> (à tuner via `tools/sim.lua`) ; je le signale partout où c'est le cas.

---

## TL;DR — la profondeur en une page

**Une seule grammaire pour TOUT.** Afflictions, auras d'adjacence, commandements, reliques et
murmures sont tous le **même objet de données** : `{trigger, op, params}`. Un effet ne « vit »
jamais dans la boucle de combat — il est lu par un registre d'ops. Conséquence : la profondeur ne
vient pas de cas particuliers empilés, mais de la **combinatoire** d'un petit nombre de briques qui
se composent. Ajouter un pouvoir = une ligne de data, jamais une exception dans le moteur.

**Six strates de décision se superposent à chaque partie :**

1. **Le passif personnel** (par unité) — 6 familles d'affliction + effets agnostiques + tanks/boucliers.
2. **Le positionnement** — plateau-graphe 3×3, front/back, ciblage 100 % déterministe.
3. **Les auras d'adjacence** — le voisin buffe le voisin (résolu au build via le graphe).
4. **Le commandant** — une unité au piédestal, intouchable, qui donne une aura à toute l'équipe.
5. **Les reliques** — 34 amplificateurs team-wide, offerts 1-parmi-3, collectionnés au Grimoire.
6. **Les murmures** — une couche cachée de *spice* lore, plafonnée, jamais déterminante.

**L'asymétrie qui fait tourner l'équilibrage.** Le **choc** inflige ses dégâts **par frappe** (un
condensateur qui se décharge à chaque coup) ; les **DoT** (poison/feu/saignement/pourriture) tickent
**par le temps**. Donc tout ce qui multiplie la **fréquence de frappe** (multicast, chaîne, hâte)
fait exploser le choc de façon **super-linéaire**, mais ne change presque rien aux DoT. C'est *la*
ligne de faille de l'équilibrage — et la raison de la plupart de nos décisions de tuning.

**Le « broken » est borné, pas interdit.** 14 caps moteur (`MULTICAST_MAX=3`, `HASTE_CAP=0.40`,
`DOT_CAP_MULT=4`, `HIT_DMG_CAP_MULT=7`…) garantissent qu'aucune combinaison ne casse la
terminaison ou ne devient littéralement infinie. À l'intérieur de ces bornes, une compo
sur-investie **peut** atomiser l'adversaire — et les sims montrent que ça arrive ~**6,7 %** du
temps au sommet. Rare, mais atteignable : c'est le fantasme qui fait relancer.

---

## Partie I — Les six strates en détail

### Strate 1 — Le passif personnel (la « voix » de chaque unité)

83 unités, chacune avec un passif clair. Le cœur, ce sont les **6 familles d'affliction**, et le
point génial est qu'elles ne se ressemblent **pas** — chacune a sa propre physique :

| Famille | Comment elle marche (code réel) | Ce qui la rend unique |
|---|---|---|
| **Poison** | Liste de **stacks indépendants** (axe « nombre »), cap **8** (→**99** avec `poisonNoCap`). Ignore le bouclier. Porte un **malus de valeur** (`weaken`, cappé **−40 %**) qui affaiblit ce que la cible produit. | Scale par **accumulation** + sabote l'attaque ennemie. |
| **Brûlure** | Instance **unique**, garde la plus forte, **décroît de 30 %/s** (sauf `burnNoDecay`). **N'ignore PAS le bouclier** (le feu lèche l'enveloppe). | Burst chaud mais **éphémère** — il faut l'entretenir. |
| **Saignement** | Instance unique mais **dps = Σ par source distincte** : une *équipe* de saigneurs compose, un saigneur **isolé rampe à peine**. Cap **12 dps** (qui enfle avec l'ampli). Pose un **slow de cadence**. | Récompense la **masse** ; punit le solo. |
| **Pourriture** | dps **croissant** tant qu'on l'entretient (cap 10). **Ampute les PV max** (plancher 1) + **nécrose anti-tank** (ronge ∝ PV max, jusqu'à **−45 %**) + **coupe les soins de 80 %**. | L'**anti-gros-mur** : détruit la barre de vie, pas juste la remplit de dégâts. |
| **Choc** | **Condensateur** : la pose **charge** des stacks (cap 8), **zéro dégât** à la pose. Se **décharge par frappe** (`stacks × VOLT_PER_STACK=3`), ignore le bouclier, puis se vide. | Le seul effet **par-frappe** → scale avec la **fréquence** (voir Strate 2 & Partie IV). |
| **Épines / Regen / Lifesteal** | Renvoi de dégâts à l'attaquant (ignore bouclier) ; soin/tick ; vol de vie. | Le tissu défensif/sustain. |

**Ordre de tick déterministe** (le même à chaque replay, base du multijoueur async) :
`vuln → brûlure → saignement → poison → pourriture → choc → regen`.

**Exemples de passifs qui ne sont pas que « pose un DoT » :**
- `corruptor` (THE DROWNED BEAK) : poison **+ marque de vulnérabilité** (`grant_vuln +15 %`) → la
  cible prend plus de **tout**, pas juste de son poison.
- `venom_censer` (THE EMBER-SAC) : poison qui **détone en feu** quand la cible atteint **5 stacks**
  (`igniteAt=5` → burst de brûlure 10 dps). Un poison qui se transforme en bombe.
- `bloodletter` (DAGGERBEAK) : saignement qui **éclate quand la cible agit** (`aggravateMult=2.0`) —
  plus l'ennemi attaque, plus il saigne.
- `galvanizer` (THE KNOTTED SIX) : `bonus_first` (un gros premier coup) **+** charge de choc → un
  bruiser qui frappe fort ET électrise.

### Strate 2 — Le positionnement (la forme EST le champ de bataille)

Le plateau est un **graphe 3×3** (9 slots), avec une **adjacence orthogonale explicite** (définie en
arêtes, pas dérivée des coordonnées). Le **centre a 4 voisins** (la case carry), les bords 3, les
coins 2. On **démarre à 3 slots** ouverts (un cluster central connexe) et on en débloque jusqu'à
**9** en montant de niveau.

> **État actuel honnête** : 5 sigils existent dans le code (carré / croix / anneau / diamant / ligne),
> chacun favorisant un archétype — mais ils sont **gelés sur le carré** (`Board.SIGILS_PAUSED=true`,
> décision user « trop compliqué à équilibrer pour l'instant », **réversible** en un flag). Donc tout
> le positionnement ci-dessous se joue **sur le carré**, qui est déjà très riche.

**Le ciblage est 100 % déterministe — zéro dé** (indispensable pour vérifier un combat async) :

```
colonne AVANT ennemie (depth min)  →  override TAUNT  →  AGGRO la plus haute  →  tie-break haut→bas
```

- Le **`depth`** dérive de la **géométrie** : `depth = maxCol − x`. Front = exposé en premier.
- L'**aggro** est **active** : `tank ≈ 40` tire le focus, `carry ≈ 5` est protégé, standard 10.
- Le **taunt** (`gravewarden`, `aegis_warden`) **force** le ciblage sur lui.

**La conséquence de design la plus profonde : les buffs sont positionnels.** Beaucoup d'auras ciblent
`role:front` ou `role:back`. Donc **où** tu places décide **qui** est buffé :
- `thunderhead` commande `atkInc` sur **`role:back`** → récompense le carry **protégé** à l'arrière.
- `maggot_king` & la relique `echo_crown` donnent `multicast` à **`role:front`** → pour en profiter,
  ton carry doit être **le plus avancé**… donc **exposé**. Risque ↔ récompense, gravé dans la grille.

C'est ça, le skill de placement : tu ne choisis pas juste « tank devant, carry derrière », tu
arbitres **quel buff va sur quelle unité** selon la colonne où tu la poses.

### Strate 3 — Les auras d'adjacence (le voisin buffe le voisin)

Résolues **au build** (bakées via le graphe du sigil, **zéro op en combat** → l'arène reste autonome).
L'UI **dessine les liens** : survol d'une case → arêtes **en or** vers les voisins buffés, **chips
chiffrés** au milieu de chaque arête (la valeur concrète), couleur par type (poison/feu/saignement/
pourriture/bouclier). Tu **vois** ta synergie se câbler.

Exemples réels :
- `soot_acolyte` (THE THREE-HEADED PYRE) : `aura_burn_dps +50 %` aux voisins → un **semeur** qui
  démultiplie la brûlure de ses voisins sans rien poser lui-même.
- `maggot_king` : `aura_stat atkInc +20 %` aux voisins → une **forge** d'empower local.
- `aegis_warden` (THE PALE STAG) : `shield_aura +10` aux voisins **+ taunt** → un mur qui **protège
  et encaisse**.
- `clot_mender` (ANTLER WRAITH) : ses voisins **posent eux-mêmes un saignement** — il transforme des
  unités passives en saigneurs (et le saignement, rappel, **compose par source** : énorme).

Et les auras **scalent avec le niveau de fusion** (duplicatas) : 3 copies d'une même unité → niveau
supérieur → l'aura aussi monte (`LEVEL_MULT`).

### Strate 4 — Le commandant (le pari d'équipe)

Une unité posée sur un **piédestal hors-plateau**. Elle est **intouchable** (le moteur renvoie 0
dégât, le ciblage l'ignore, le décompte de victoire l'exclut) mais attaque **plus lentement**
(`cdMult=1.5`) : elle **combat ET commande**. En échange, elle donne une **aura à toute l'équipe**
(trigger `combat_start`).

**Objectif atteint : 83/83 unités peuvent commander** (un test CI permanent l'exige — plus jamais de
« Cannot command »). Deux types d'aura :

- **`aura_stat`** — buff chiffré : `haste`, `atkInc` (empower), `dmgReduce`, `regen`, `multicast`,
  `lifesteal`, `statInc` (+% PV **et** dégâts), ou amplis d'école (`poisonInc`/`burnInc`/…).
- **`grant_team`** — un **drapeau qui change une règle** : `shockChain` (le choc rebondit),
  `poisonNoCap` (poison sans plafond), `burnNoDecay` (feux éternels), `plagueAmp` (+25 % si 2+
  afflictions), `markEnemiesVuln`, `stripEnemyShield`, `rotEnemies`…

**Le commandant cible par rôle** : `team`, `role:front/back/center`, `tier:N` (par rang), `level:N`.
Donc le choix du commandant **reconfigure** ta compo : mettre `deep_kraken` (**L'Aïeul**,
`statInc +15 %` sur les unités niveau 1) récompense un board **non-fusionné et large** ; mettre
`maggot_king` (**La Couronne d'Échos**, `multicast` au front) récompense **un carry avancé**.

> Garde-fous gravés : `multicast` et `statInc` ciblant `team` sont **interdits** (sinon c'est trop
> fort partout). Les commandants `statInc` forts (`galvanizer`, `deep_kraken`) ont été **nerfés en
> sim** (0.50→0.14, 0.40→0.15) car en early — où tout est niveau/rang 1 — ils buffaient **tout** le
> board. L'intention : un **payoff tardif**, pas un snowball précoce.

### Strate 5 — Les reliques (l'égalisateur, 34 au total)

Modèle **lisible** (les leurres cryptiques ont été **retirés**, décision user). Offre **1-parmi-3**
toutes les ~3 combats, **garanties** aux 3ᵉ et 6ᵉ victoires (avec un plancher de qualité pour ne pas
servir 3 stat-sticks), plus une offre bonus à chaque **level-up** (bornée 1/round). Tu peux
**REFUSER pour +3 or**. Une **garde de diversité** empêche les 3 offres d'être quasi-identiques. Le
**Grimoire** garde la collection **entre les runs** (méta-progression).

Reliques **gated par avancée** : tier ≤2 (stats universelles) avant 2 victoires → tier ≤3 (amplis
conditionnels) → **tier 4 transformatives** seulement à partir de 5 victoires. On ne te donne les
jouets qui cassent les règles que **tard**.

Familles fonctionnelles (chiffres = **code réel**) :
- **Amplis d'affliction** : `kings_bowl` (poison **+20 %**), `ember_heart` (feu **+30 %**),
  `weeping_nail` (saignement **+18 %**), `grave_cap` (pourriture **+18 %**), `plague_communion`
  (≥2 afflictions → **+25 % de tout**), `hollow_choir` (les afflictions **percent 40 % des soins**).
- **Amplis de fréquence** : `echo_crown` (l'unité **la plus avancée frappe 2×**), `whetstone`
  (**+15 % cadence** d'équipe), `forked_tongue` (**le choc arque** vers un 2ᵉ ennemi).
- **Transformatives (tier 4)** : `everburn` (feux sans décroissance), `open_wounds` (saignements qui
  ne se referment jamais), `second_breath` (chaque unité **survit 1× à 1 PV**), `sacred_shield`
  (**invuln d'ouverture**).
- **Buffs d'équipe** : `blood_banner` (**+10 %** atk équipe), `bloodstone` (+14 % dmg),
  `feeding_frenzy` (chaque mort ennemie → **+8 %** dmg équipe, max ×6), `famines_math` (si **≤3
  unités** : **+30 % dmg / +20 % PV**).
- **Économie / boutique** (hors combat, n'altèrent jamais le golden) : `paupers_boon` (+3 or/round),
  `usurers_ledger` (intérêts), `black_summons` (+1 tier de boutique)…

**Principe-clé : la relique est un ÉGALISATEUR, jamais un gate.** Team-wide, intra-combat. Une
relique qui « matche » ta compo la fait décoller ; une relique « générique » (bloodstone/whetstone/
blood_banner/aegis) aide **n'importe quelle** compo ; et tu peux toujours **refuser pour de l'or**.
Tu n'es jamais bloqué par une mauvaise offre (cf. Scénario G).

### Strate 6 — Les murmures (la couche cachée)

Une **3ᵉ couche de spice**, pour l'amoureux du lore, **jamais build-defining**. Registre déclaratif
pur (`id_unité → murmures`). Déclenchés par des **affinités cachées** : présence/adjacence d'un
partenaire, seuil de PV, mort d'allié, solitude d'espèce, durée de combat. **9 actifs** en v1 (le
seul à base de RNG — une esquive — est **désactivé** pour ne pas désynchroniser l'async).

Le contrat de design est strict : magnitude plafonnée à **~10 %** (`WHISPER_STAT_CAP=0.10`) ou un
seul one-shot. **Trop faible pour construire autour** — si un effet est assez fort pour ça, il
**monte en couche visible**. Révélation par un **log cryptique à 2 canaux** : le joueur lit une
phrase d'ambiance **sans aucun chiffre** (« *Saignant à blanc, {x} ouvre une bouche de plus — et se
repaît de ce qui coule.* »), pendant que le canal dev garde la vraie valeur. *Seul le créateur
connaît les vrais nombres.*

Exemples : `the_lure_and_the_brood` (ink_horror + deep_kraken présents → +10 % atk : l'**appât
abyssal** et la **couvée**), `the_patient_one` (patient_worm après ~8 s de combat → +10 % stats),
`the_lone_titan` (skull_colossus seul de son espèce → +10 %). De la profondeur **émergente**, qui ne
surcharge pas le theorycraft public.

---

## Partie II — L'arc d'une partie (scénarios concrets)

Voici la même run racontée à différents niveaux de réussite. Chaque scénario donne le **setup**, **ce
qui se passe mécaniquement**, et **la leçon de design**.

### Scénario 0 — Le départ (tout le monde commence fragile)

Tu ouvres avec **3 slots**, 10 or, une boutique de 5 unités aléatoires. Tu ne peux poser que 2-3
unités. Rien ne synergise encore. Le combat 1 se gagne ou se perd sur les **stats brutes** et un peu
de placement. C'est voulu : la profondeur se **débloque** avec les slots (le leveling sert à *ça*).
Filet de sécurité SAP : **5 vies**, et **+1 vie rendue au round 3** si tu perds tôt. Une mauvaise
ouverture n'est pas une condamnation.

### Scénario A — La partie qui foire (dispersion, zéro synergie)

**Setup.** Tirages malheureux : un `spore_tick` (poison), un `razorkin` (saignement isolé), un
`live_wire` (choc), un `husk` (stat-stick). Quatre familles, aucune masse. Tu les poses en vrac, pas
de voisinage pensé. Commandant : `husk` (le seul « libre »), aura `dmgReduce +4 %`.

**Ce qui se passe.** Le `razorkin` **saigne tout seul** → rappel : le saignement **ne rampe que par
source**, un saigneur isolé plafonne très bas. Le `live_wire` charge 1 stack de choc et le décharge
pour `1×3=3` — anecdotique sans fréquence. Le poison du `spore_tick` (1 dps) ne fait pas le poids
seul. Tu **fonds** : tes dégâts sont saupoudrés sur 4 systèmes dont aucun n'atteint son seuil
d'efficacité. Tu perds, tu lâches une vie.

**Leçon de design.** Le jeu **punit la dispersion sans la rendre injouable** : tu as quand même
**érodé** l'adversaire (chaque famille fait *quelque chose*), et le filet de vies te laisse rebondir.
C'est la « partie qui se passe mal » : lisible (« je n'ai pas de plan »), pas frustrante (« le jeu m'a
volé »).

### Scénario B — La partie moyenne (demi-synergie + on tient par l'éco)

**Setup.** Tu dérives vers **deux** `razorkin`/`gash_fiend` (saignement) collés, plus un `templar`
tank. Commandant : `gash_fiend` (**`bleedInc +20 %`** équipe). Relique offerte : `weeping_nail`
(saignement **+18 %**) — tu la prends.

**Ce qui se passe.** Maintenant **deux** sources de saignement **composent** (dps additionnés), et les
deux amplis (commandement +20 % + relique +18 %) montent le **cap d'équipe** de 12 vers ~17. Le slow
de cadence ralentit l'ennemi. Ce n'est pas explosif — le saignement reste **plat dans le temps** — mais
c'est **régulier**, et le `templar` devant (taunt d'aggro 40, `dmgReduce` d'adjacence) te fait gagner
**la course d'usure**. Tu gagnes 55/45.

**Leçon.** Une **demi-synergie** (une famille cohérente + 1 ampli + 1 tank) suffit à passer en
positif. Tu n'as pas « le build », mais tu as **un plan**, et le plan paie. C'est le régime « moyen »
où vit la majorité des parties.

### Scénario C — La partie normale (une famille + un commandant qui matche + reliques alignées)

**Setup.** Tu trouves la **pourriture** : `rot_hound` + `necro_leech` + `maggot_king` au centre
(aura `atkInc +20 %` aux voisins), `gravewarden` (taunt) devant. Commandant : `necro_leech`
(**`rotInc +20 %`**). Reliques : `grave_cap` (pourriture +18 %) et `plague_communion` (+25 % si 2+
afflictions).

**Ce qui se passe.** La pourriture **ampute les PV max** et **coupe les soins de 80 %** : contre un
adversaire qui mise sur un gros mur + regen, tu **détruis sa barre de vie** au lieu de cogner dessus.
La **nécrose anti-tank** ronge ∝ ses PV max (jusqu'à −45 %). `plague_communion` voit que tes cibles
portent pourriture **+** (via un voisin) un poison léger → **+25 % sur tout**. Le `gravewarden`
encaisse pendant que la pourriture fait son œuvre. Victoire nette, 70/30.

**Leçon.** Voilà la « partie normale réussie » : **une identité claire** (anti-mur), **un commandant
qui la sert**, **deux reliques qui matchent**. Pas un god-roll — juste un **plan complet et exécuté**.
La diversité vient de ce que cette même structure existe pour **5 familles** + tanks + boucliers, et
que chacune bat des choses différentes (cf. Scénario H).

### Scénario D — Le comeback (perte précoce → relique-clutch → on remonte)

**Setup.** Tu perds les combats 1 et 2 (mauvaise ouverture). 3 vies restantes, +1 rendue au round 3.
Au level-up tu décroches `second_breath` (chaque unité **survit 1× à 1 PV**) ; un peu plus tard,
`sacred_shield` (**invuln d'ouverture**).

**Ce qui se passe.** `second_breath` transforme chaque combat serré : tes unités encaissent un coup
létal, **survivent à 1 PV**, et placent **un dernier tick** d'affliction — souvent suffisant pour
renverser une course perdue d'un cheveu. `sacred_shield` absorbe l'**alpha strike** adverse (la demi-
seconde où une compo burst fait le plus mal). Tu enchaînes 4 victoires et tu repasses devant.

**Leçon.** Le **comeback est un système**, pas de la chance : filet de vies SAP + reliques de survie
**intra-combat**. La relique est un **égalisateur de matchup** (pilier de design), exactement faite
pour ces moments. La psychologie : une remontée **se sent méritée** parce que tu as *choisi* les bons
outils de survie.

### Scénario E — Le god-roll CHOC (l'explosion par fréquence) ⚡

**Setup.** Le carry choc `stormlord`/`arc_warden` **en avant** (exposé, à dessein), `gravewarden`
taunt à côté. Commandant : `maggot_king` (**`multicast +1` sur `role:front`**). Reliques :
`echo_crown` (`multicast +1` sur l'unité avancée) **+** `forked_tongue` (le choc **arque** vers un 2ᵉ
ennemi) **+** `whetstone` (+15 % cadence).

**Ce qui se passe — et pourquoi ça atomise.** Le choc se décharge **à chaque sous-coup**. Ton carry
avancé reçoit le multicast du **commandant** *et* d'`echo_crown` → **3 sous-coups par swing** (cappé
`MULTICAST_MAX=3`). Donc **3 décharges** du condensateur par swing, chacune `stacks×3`, **chacune
arquée** vers un second ennemi par `forked_tongue`. `whetstone` raccourcit le rechargement → plus de
swings/seconde → encore plus de décharges. La **fréquence se multiplie sur elle-même** et le choc,
qui est par-frappe, **suit la courbe**. La colonne avant ennemie **s'évapore** (TTK sim ≈ **481
frames, ~8 s**, **100 % de victoires** au sommet).

**Le risque qui équilibre.** Pour recevoir les buffs `role:front`, ton carry **doit être le plus
avancé** → il est **ciblé en premier** (depth 0). C'est une **course** : tu gagnes si tu atomises
avant d'être focus. Glass cannon assumé.

**Leçon.** C'est **le** build broken historique du jeu, et il est **borné** : `MULTICAST_MAX=3` plafonne
les sous-coups, `HIT_DMG_CAP_MULT=7` plafonne **chaque** coup, `HASTE_CAP=0.40` empêche le timer de
tomber à zéro. Tu **peux** exploser l'adversaire — tu ne peux pas casser la simulation.

### Scénario F — Le god-roll POISON (le nouveau, débloqué par l'overhaul) 🟢

**Setup.** Un board **plein de poison** : `witch` + `bile_spitter` + `miasma_acolyte` (aura `+50 %`
poison aux voisins) + `festering` (son **passif de board** donne **`poisonNoCap`** à l'équipe — le
poison **n'a plus de plafond de stacks**) + `plague_bearer` (**contagion** : son poison se propage
aux voisins). Commandant : `venom_censer` (`poisonInc +22 %`) — ou `plague_bearer` au piédestal, dont
le **commandement** donne lui aussi `poisonNoCap`. Reliques : `kings_bowl` (+20 %) **+**
`plague_communion` (+25 % si 2+ afflictions).

**Ce qui se passe — et pourquoi c'est NOUVEAU.** Le poison empile sur **trois axes à la fois** :
**densité** (`poisonNoCap` lève le cap de 8→99, et la **contagion** de `plague_bearer` propage aux
voisins du champ), **ampli par stack** (`kings_bowl` + aura +50 % + commandement, plafonné par
`DOT_CAP_MULT`), et **ampli global** (`plague_communion +25 %`). En prime, le **malus de valeur**
(weaken, −40 %) **étouffe l'attaque adverse**. Résultat sim : **100 % de victoires** au sommet (dom
0,77).

> **Le choix de tuning derrière** : avant l'overhaul, `DOT_CAP_MULT` valait **3** — l'ampli par stack
> était bridé trop bas, le poison plafonnait à ~**60 %** même sur-investi. On l'a monté à **4**. Effet
> **« gated »** : le cap n'est atteint **qu'**en god-roll haut-investissement → la baseline n'a **pas
> bougé** (DoT share 30,6 %, σ inchangé), mais un poison **vraiment** sur-investi peut désormais
> atomiser, **comme** le choc. **Un seul levier**, validé en sim, sans toucher au reste.

**Leçon.** On a créé un **deuxième fantasme de build**. Avant, **seul** le choc « poppait » ; tout le
reste plafonnait → mortel pour la rejouabilité (un seul rêve = on ne relance pas). Maintenant le
poison **rejoint le club des 100 %** → **plus de chemins** vers l'explosion → plus de raisons de
retenter « cette run la peste s'aligne ».

### Scénario G — La relique qui NE matche pas (l'égalisateur en action)

**Setup.** Tu joues **choc**, et l'offre 1-parmi-3 te propose : `grave_cap` (ampli **pourriture** —
inutile pour toi), `bloodstone` (**+14 % dmg générique**), `paupers_boon` (**+3 or/round**).

**Ce qui se passe.** Tu n'es **jamais coincé** : la garde de diversité a glissé une option **générique**
(`bloodstone`, utile à *toute* compo) et une option **éco** (`paupers_boon`, qui te paie l'économie
de ta vraie relique au prochain tour). Et si vraiment rien ne te parle, tu **refuses pour +3 or**.
Tu prends `bloodstone` : +14 % de frappe, ça booste aussi tes **décharges** de choc indirectement (plus
de frappes qui connectent fort).

**Leçon.** C'est le pilier « **égalisateur, jamais gate** » rendu concret. Une mauvaise offre te
**ralentit** d'un cran, elle ne te **bloque** pas. La variance crée de la **texture** (« pas mon tour
de rêve »), pas de l'injustice.

### Scénario H — Pierre-feuille-ciseaux (la diversité prouvée par les counters)

Les sims valident des **counters DESIGNED** (voulus, pas accidentels) :

| Si tu joues… | tu bats… | parce que… |
|---|---|---|
| **poison / brûlure / pourriture** | le **tank** | la pourriture ampute les PV max + coupe les soins ; le poison ignore le bouclier et affaiblit. On **contourne** le mur au lieu de le cogner. |
| **saignement** | le **bruiser** | le saignement compose en masse + le **slow de cadence** désamorce le DPS du bruiser. |
| **tank / sustain** | le **bruiser**, et le **choc base** | un seul condensateur **ne perce pas un mur** (le choc tire toute sa valeur de la fréquence, pas de la frappe → **bipolaire** : nul sans masse, létal en god-roll). |

**Leçon.** La diversité n'est pas cosmétique : **chaque archétype bat quelque chose et perd contre
autre chose**. C'est ce qui fait qu'aucune compo « normale » ne domine — et que le métagame respire.

---

## Partie III — Pourquoi ces choix (le raisonnement)

- **Pourquoi 34 reliques *lisibles* (fini les leurres).** Décision user : « pas fan des leurres,
  trop compliqué pour pas grand-chose ». On garde l'ambiance (noms + flavor grimdark) et l'offre
  1-parmi-3, mais l'effet est **affiché**. La profondeur vient de la **combinatoire** relique×compo,
  pas d'un jeu de devinette.
- **Pourquoi le cap DoT 3→4 plutôt qu'un buff direct du poison.** Un buff plat aurait **déplacé la
  baseline** (poison trop fort *partout*). Le cap, lui, **n'agit qu'au sommet** : effet *gated*,
  baseline intacte, god-roll débloqué. Discipline **1 levier à la fois**, re-simulé, gardé seulement
  parce que le faisceau s'apaisait sans nouvel outlier.
- **Pourquoi `VOLT_PER_STACK 3→4` a été REJETÉ.** Testé pour réparer `shock>tank`. Résultat :
  (a) n'a **pas** réparé le counter (il faut de la **densité/pénétration**, pas du volt), (b) a
  **re-monopolisé** le god-roll sur le choc (repoussant le poison hors de la queue). **Net négatif →
  reverté.** C'est la preuve que la discipline marche : on **annule** un levier qui empire le faisceau.
- **Pourquoi le commandant intouchable mais lent (`cdMult=1.5`).** « Voie A » : il **combat et
  commande**. L'invulnérabilité évite la stratégie dégénérée « snipe le commandant » (qui réduirait
  tout à *kill the buff-bot*) ; la lenteur paie cette sécurité. Et il est **exclu du décompte de
  victoire** : board mort = défaite, même si le chef vit. Pas de cheese.
- **Pourquoi les murmures sont plafonnés à ~10 %.** Parce qu'un easter-egg qui **récompense
  l'optimiseur** cesse d'être un easter-egg : tout le monde le théorycrafte et il devient une couche
  visible de fait. En le **bornant sous le seuil de décision**, on le réserve à l'explorateur/amoureux
  du lore — *spice*, jamais build.
- **Pourquoi les sigils gelés sur le carré (réversible).** Honnêteté : 5 formes = 5 profils
  d'exposition à équilibrer, jugé « trop coûteux pour l'instant » par l'user. Le carré est **déjà**
  profond (front/back, adjacence, 4-voisins au centre). Le code des 5 sigils est **conservé intact** —
  un flag les réactive le jour où on voudra équilibrer cette dimension.
- **Pourquoi le ciblage 100 % déterministe.** Le multijoueur est **async** (on affronte des snapshots
  figés, pas un joueur live). Un combat doit donc être **rejouable à l'identique** depuis une seed. Zéro
  dé en ciblage = vérifiable, et ça **convertit la frustration RNG en skill de placement**.

---

## Partie IV — La preuve par la simulation

On ne « pense » pas l'équilibrage, on le **mesure**. Le moteur de scénarios (`tools/sim.lua`, modes
`invest`/`policy`/`godroll`/`commander`/`counter`) joue des milliers de combats et sort un faisceau
de métriques. Le **juge suprême** est le **win-rate contextualisé par l'investissement** (gagner en
dépensant 3× plus n'est pas « fort »).

**La baseline est SAINE** (mode P0, 2000 combats) :
- **σ des win-rates = 0,058** (bas = équilibré) · **entropie = 0,999** (haut = diversité réelle).
- **0 drapeau d'outlier** (toutes les unités dans la moyenne ±0,087).
- **Part des dégâts par altération = 30,6 %** (frappe directe 69,4 %), bien **répartie** entre
  familles : poison 8,2 % · choc 6,9 % · brûlure 6,5 % · pourriture 5,6 % · saignement 3,5 % ·
  épines 3,2 %. **Pas de monoculture.**

**Le god-roll est RARE mais réel** (mode godroll) : ~**6,7 %** des combinaisons haut-investissement
dépassent le 95ᵉ percentile de domination. Au sommet, le choc (dom 0,80) et le poison (dom 0,77)
atteignent **100 % de victoires**. C'est exactement le réglage visé : **assez rare pour être spécial,
assez atteignable pour qu'on le chasse**. Garde-fous tenus à chaque run : `multicast ≤ 3`,
**0** combat « one-swing », **0** combat non-conclu sur 18 000.

**La dette connue, en toute transparence :**
- `shock > tank = 0 %` — un counter **voulu mais cassé** (le choc base ne perce pas un mur faute de
  densité). Fix identifié = **densité de condensateurs / pénétration dédiée**, **pas** le volt global
  (déjà testé et rejeté). Reproductible via le moteur.
- **Diversité formelle du top-4** : le poison est au club des 100 %, mais le pic du choc reste
  marginalement devant (artefact de seuil TTK). Piste propre : une **relique tier-4 `dotUncap`
  *gated*** plutôt que de monter encore un cap global.
- Quelques **T3 simplifiés** et des **valeurs placeholder** partout (assumées, à tuner au gros N).

---

## Conclusion — la profondeur en une phrase

> **The Pit empile six strates de décision sur une seule grammaire d'effets, où la *position* décide
> qui est buffé, où chaque famille bat des choses différentes, et où des caps stricts laissent une
> compo sur-investie *atomiser* l'adversaire — assez rarement pour que ce soit un fantasme, assez
> sûrement pour qu'on relance.**

Ce qui est concrètement **mieux** depuis l'overhaul : on est **sorti de la monoculture** (un seul
build qui poppait) vers **plusieurs fantasmes coexistants** (choc *et* poison, avec la voie ouverte
pour brûlure/pourriture), le tout **mesuré sain** et **borné** par 14 garde-fous — et désormais
outillé par un **moteur de simulation** qui transforme chaque question d'équilibrage en expérience
reproductible.

---

## Annexe A — Les 14 caps (le filet de sécurité)

| Cap | Valeur | Protège |
|---|---|---|
| `DOT_CAP_MULT` | **4** | ampli d'un DoT borné à ×4 sa base (relevé 3→4 en Phase C) |
| `BLEED_DPS_CAP` | **12** | dps total de saignement d'équipe (enfle avec l'ampli) |
| poison stack cap | **8** (→99 si `poisonNoCap`) | nombre de stacks de poison |
| `VOLT_PER_STACK` | **3** | dégâts libérés par stack de choc |
| `SHOCK_STACK_CAP` | **8** | plafond dur de charge de choc |
| `WEAKEN_CAP` | **0.40** | malus de valeur max du poison (−40 %) |
| `ATK_INC_CAP` | **1.5** | empower cumulé (+150 % dmg max) |
| `VULN_INC_CAP` | **0.5** | vulnérabilité cumulée (+50 % subis max) |
| `HIT_DMG_CAP_MULT` | **7** | une frappe ≤ ×7 le dmg de base (anti-burst) |
| `MULTICAST_MAX` | **3** | sous-coups par swing (anti-boucle) |
| `HASTE_CAP` | **0.40** | cadence (−40 % max → anti-non-terminaison) |
| `DMG_REDUCE_CAP` | **0.60** | défense (−60 % max → anti-gate all-tank) |
| `ROT_NECRO_CAP` | **0.45** | nécrose (ronge jusqu'à −45 % PV max) |
| `ROT_HEAL_CUT` | **0.80** | part de soins annulée par la pourriture |

## Annexe B — Le roster par famille (comptes officiels `U.dotFamily`)

**Poison 15 · Brûlure 13 · Saignement 12 · Pourriture 12 · Choc 11** = 63 poseurs/amplis de DoT.
+ **20** non-DoT : tanks/taunt (`gravewarden`, `aegis_warden`), boucliers (`shieldbearer`,
`oath_keeper`, `ward_weaver`, `runestone_golem`…), counters anti-bouclier (`siege_breaker`),
contre-DoT (`plague_doctor`), stat-sticks (`husk`/`footman`/`mire_thing`), et les 6 vanilla.

## Annexe C — Auras de commandement par type (les 83 chefs)

school-amp (poison/burn/bleed/rotInc) **22** · dmgReduce **16** · grant_team (flags) **16** ·
empower (atkInc) **10** · haste **9** · regen **9** · lifesteal **5** · vuln **3** · statInc **4** ·
multicast **2**. Couverture **83/83** (test CI permanent).

## Annexe D — ✅ Strings d'UI corrigées (alignées sur le code, v0.9)

9 reliques affichaient un **ancien chiffre** (le code avait été recalibré, pas la traduction `en.lua`).
**Corrigées dans ce jalon** — la carte affiche désormais la valeur réelle du code (conforme à la règle
« valeurs concrètes, carte↔chip jamais contradictoires ») :

| Relique | Affichait | Valeur réelle (désormais affichée) |
|---|---|---|
| `bloodstone` | +20 % | **+14 %** |
| `carapace` | +15 PV | **+8 PV** |
| `weeping_nail` | bleed +30 % | **+18 %** |
| `grave_cap` | rot +30 % | **+18 %** |
| `thornguard` | 4 dmg | **2 dmg** |
| `seers_mark` | +15 % | **+12 %** |
| `tide_caller` | 8 % | **4 %** |
| `gravediggers_due` | +50 % | **+40 %** |
| `splitting_maw` | 40 % splash | **5 % splash** (écart majeur) |
