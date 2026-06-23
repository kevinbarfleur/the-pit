# Round 04 — Critique adversariale (lentille : units-power)

> **Mandat** : challenge du brouillon `ROADMAP-draft.md` (v4, intégré round 3) depuis la lentille
> **units-power** — distinction des unités, budget de puissance par rang, identité, redondance,
> trous d'archétype. Round 4/10.
>
> **Inputs lus** : `BRIEF.md`, `ROADMAP-draft.md` (v4), `00-state.md`, `round-01.md`,
> `round-02.md`, `round-03.md`, `rounds/r01-units-power.md`, `rounds/r02-units-power.md`,
> `rounds/r03-units-power.md`, `competitive/*.md` (tous), `src/data/units.lua` (intégralité
> relue ce round), `src/data/relics.lua`.
>
> **Méthode** : désaccord = recherche web menée et citée. Analogie = démonter son mécanisme
> psychologique/mathématique avant d'accepter. Toute affirmation chiffrée porte sa source.
>
> **Garde-fou absolu** : lecture seule du repo jeu. Écriture uniquement sous `docs/roadmap-lab/`.
> Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).

---

## 0. TL;DR de ce round

Le brouillon v4 a intégré les trois critiques majeures du round 3 (plancher ≥2/famille/rang,
colonne budget stat, audit rang-5, cohorte v7) et les a correctement formulées dans P0.5. Mon
challenge de ce round porte sur **quatre angles non encore épuisés** par les lentilles
précédentes, identifiés après relecture COMPLÈTE de `units.lua` ligne à ligne :

1. **L'identité mécanique INTER-familles DoT n'est pas assez tranchée** : bleed et rot ont
   un problème de chevauchement d'EFFETS SECONDAIRES (le slow de bleed vs l'amputation rot) qui
   rend leur coexistence en build floue — pas au niveau du tick-dps, mais au niveau du
   **proxy qu'ils exercent sur la vitesse de mort** de la cible. Les deux familles ralentissent le
   tempo adverse, juste par des axes différents non clairement hiérarchisés.

2. **Le choc a un profil de STAT PARADOXAL non résolu** : le ladder choc 5/3/2 (T1: `live_wire`
   rang-1, `thunderhead`/`static_swarm` rang-2 ; T2: `stormlord`/`storm_anchor` rang-3,
   `galvanizer`/`dynamo_priest`/`arc_warden` rang-4) a des stats qui **cassent systématiquement
   la règle cost=rank** — `thunderhead` (rang-2) frappe à dmg=8/cd=76 soit DPS=0.105, inférieur
   à plusieurs rang-1. Ce n'est pas un outlier : c'est la **logique même du condensateur** (on
   accepte un DPS de frappe bas pour un burst de décharge) mais le brouillon n'a **jamais rendu
   cette exception EXPLICITE ET TESTÉE** dans la grille budget P0.5.

3. **La famille BOUCLIER est traitée comme un type transversal sans identité propre, mais ses
   11 unités ont des profils de STAT tellement disparates** (DPS=0.025 pour `shieldbearer` à
   DPS=0.125 pour `runestone_golem`) qu'elles ne peuvent pas coexister dans le même pool sans
   que le joueur déduise lui-même une hiérarchie qui n'est nulle part documentée. Ce n'est pas
   une question de « 6e type non-DoT » (litige #F, orienté « aucun ») mais de **lisibilité
   du budget intra-groupe**.

4. **La décision de cohorte v7 (§3.2 P0.5) identifie le SYMPTÔME mais pas la CAUSE** : les 14
   unités v7 n'ont pas été mal conçues par accident — elles reflètent une règle implicite
   (`family` pour gen procédurale → `pool` par défaut) que le brouillon veut corriger par
   filtrage, alors qu'il faudrait une **politique explicite de séparation pool/roster** encodée
   dans `units.lua` avec un champ `pool_eligible = false`. Sans champ explicite, la décision de
   cohorte doit être re-prise à chaque vague.

---

## 1. Accords avec pourquoi

### 1.1 ACCORD FORT — Double critère plafond (≤4) + plancher (≥2) pour la visibilité famille (adopté round 3)

La proposition §2.1 du round 3 est intégrée correctement dans le brouillon v4 §3.1 et les maths
hypergéométriques tiennent. Avec SHOP_SIZE=5 et un pool de 18 unités rang-2 (après nettoyage
≤4/famille) :

```
P(voir ≥1 famille X | T2, 2 enablers X dans pool 18) ≈ 1-(16/18)^5 ≈ 43 %
P(voir ≥1 famille X | T2, 1 enabler X dans pool 18) ≈ 1-(17/18)^5 ≈ 25 %
P(voir ≥1 famille X | T2, 4 enablers X dans pool 18) ≈ 1-(14/18)^5 ≈ 78 %
```

**Pourquoi ça tient pour nos contraintes async** : contrairement à TFT où le pool est PARTAGÉ
entre 8 joueurs (les achats d'un joueur réduisent le pool pour les autres —
esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances : T2=22 copies par
champion, T3=18), notre pool est LOCAL à la run (snapshots async = pas de pool partagé). Donc
la dilution ne vient que du SHOP_SIZE=5 + taille du pool, sans compétition inter-joueurs. La
règle ≥2/famille/rang n'est pas une analogie paresseuse TFT — elle répond à une mathématique
de visibilité indépendante du contexte async. Elle tient.

**Nuance prouvée par la recherche web** : SAP (Super Auto Pets) utilise ~10 pets/tier (
twoaveragegamers.com : tiers indépendants avec leur propre pool, chaque pet a un trigger unique).
Chez SAP, chaque pet T1 est **mécaniquement orthogonal** (trigger faint / buy / sell / eat / turn
start — a327ex.com/posts/super_auto_pets_mechanics). Le plancher de visibilité SAP n'est pas
une règle déclarée mais une **émergence de l'orthogonalité** : si chaque pet a un trigger
distinct, le joueur reconnaît *instantanément* lequel est présent (même si rare). Chez The Pit,
les DoT ont tous le même trigger (`on_hit`) et diffèrent par l'op — la lisibilité nécessite un
plancher minimum de visibilité que SAP obtient gratuitement via la diversity de triggers.

### 1.2 ACCORD — Colonne budget stat (DPS base rang-2 < médian rang-3) comme précondition de l'audit

La preuve `cinder_cur`/`zeal_inquisitor` rang-2 (DPS=0.118) > `bellows_priest` rang-3 (0.111)
est solide et le brouillon v4 l'a correctement intégrée en colonne E de la grille à 6 colonnes.

**Pourquoi ça tient** : GhostCrawler power budget (askghostcrawler.tumblr.com 2017, citée round 3)
s'applique ENTRE les rangs : un rang-2 à DPS base supérieur à un rang-3 signifie que le coût
ne reflète pas la puissance → le joueur qui arrive en T3 et achète un rang-3 pour la première
fois comparera au rang-2 qu'il connaît déjà et conclura « le rang-3 n'est pas meilleur ». C'est
un signal d'apprentissage cassé. **La décision #10 (cost=rank) n'est pas un artefact de code —
c'est un contrat d'apprentissage avec le joueur.** Si le budget ne suit pas, le contrat est faux.

### 1.3 ACCORD — Audit rang-5 dédié : stat-sticks vs transforms (intégré round 3)

`skull_colossus` (burn dps=4 + aggro=40, hp=92, rang-5) et `deep_kraken` (poison dps=4 + hp=84,
dmg=12, rang-5) sont des stat-amplifications sans règle nouvelle, lus directement dans
`units.lua:421-439`. La décision « transform réelle / stat-amplification à raffiner /
rétrograder rang-4 » est correctement formulée dans §3.5.

**Pourquoi ça tient** : en StS, les cartes rares (équivalent rang-5) ne font pas simplement « plus
de dégâts » — elles modifient la RÈGLE de jeu (Barricade = les boucliers ne disparaissent pas,
Offering = sacrifie un PV max pour 5 cartes). Giovannetti GDC 2019 (gamedeveloper.com) : « la
première erreur est de faire des cartes qui diffèrent seulement par les chiffres ». Un `skull_colossus`
rang-5 avec burn dps=4 (même op qu'un rang-2) ET profil tank n'est pas un transform — c'est un
rang-3 avec plus de HP et un prix premium injustifié pour la décision de build.

### 1.4 ACCORD — Décision de cohorte v7 comme filtre de 1er niveau

La formulation « parmi les 14 v7, lesquelles ont une niche distincte ET un budget cohérent ? »
est correcte comme approche. `units.lua:487` explicite : « Identique au roster pour l'instant. »

**Mais ça ne tient qu'à moitié** (voir §2.4 — désaccord sur la méthode).

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MODÉRÉ — L'identité inter-familles DoT est incomplète : bleed et rot ont un chevauchement d'EFFET SECONDAIRE sur le tempo adverse non documenté

**Ce que le brouillon dit** (00-state §3.1 — axes de stacking distincts) :

| Famille | Axe de stacking | Signature |
|---------|-----------------|-----------|
| Bleed | intensité + conditionnel (cumul par source) | **ralentit la cadence** |
| Rot | durée / accumulation | dps croît ; **ampute les PV max** |

**Ce qui est insuffisant** : le brouillon documente les axes comme distincts, et ils le sont sur
l'axe *primaire* (slow de cadence vs amputation PV max). Mais les deux familles exercent un
EFFET SECONDAIRE CONVERGENT sur la **vitesse à laquelle la cible peut tuer vos unités** :

- **Bleed** `slowPct=0.20-0.30` → la cible attaque 20-30 % moins souvent → elle tue moins vite
- **Rot** `maxHpFrac=0.10-0.35` → la cible perd des PV max → elle meurt plus vite ET, si c'est
  un attaquant, son DPS réel est réduit (moins de HP = mort plus rapide = moins de frappes)

Ces deux effets secondaires sont **mécaniquement différents** (l'un réduit la fréquence d'attaque,
l'autre réduit l'amplitude des dégâts réels de la cible via sa durée de vie), mais **perceptuellement
similaires** pour le joueur : « ma cible fait moins de dégâts sur ma team ». La distinction n'est
lisible que si le joueur comprend profondément la boucle de combat — ce qui ne s'apprend qu'après
20+ runs.

**Preuve issue du code** :

Dans `units.lua`, les deux familles existent en coexistence naturelle sur des builds :
- `razorkin` (bleed, slowPct=0.20, rang-2) + `rot_hound` (rot, maxHpFrac=0.15, rang-2)

Les deux se placent sur les mêmes cases (front-ish, adjacence aux carries) et ont des stats
similaires (razorkin : hp=52, dmg=5, cd=46 → DPS=0.109 ; rot_hound : hp=54, dmg=5, cd=56 →
DPS=0.089). Un joueur T2 qui voit les deux en boutique n'a pas assez d'information pour savoir
lequel PRÉFÉRER pour son archétype — les deux « ralentissent » l'adversaire selon des axes
qui se lisent identiquement en surface.

**Source** : PoE/Last Epoch ont résolu ce problème en donnant à chaque DoT un **vecteur
d'effet radicalement distinct** (poewiki.net/wiki/Bleeding : saignement = physique, amplifié
si la cible bouge, non-stackable par défaut ; lastepoch.fandom.com/wiki/Damage_Over_Time :
poison = chaos stackable, bleed = physique non-stackable). Leur distinction est encodée dans
un SYSTÈME (type de dommage + règle de stacking) pas dans un PARAMÈTRE (slowPct vs maxHpFrac).
Chez nous, la distinction existe mécaniquement mais pas au niveau de l'encodage visuel/verbal
accessible au joueur early.

**Ce n'est PAS un défaut de conception moteur** (les axes sont réels et distincts). C'est un
défaut de LISIBILITÉ DE BUILD qui va créer des builds accidentels « j'ai du bleed ET du rot parce
que les deux avaient l'air de « ralentir l'ennemi » » — sans que le joueur sache que l'un ne
stacke PAS avec l'autre dans son archétype optimal.

**Proposition** (§P-A priorisée) : L'audit P0.5 doit inclure pour chaque famille DoT une
**ligne de lisibilité** : « quel est l'EFFET SECONDAIRE lisible en build, et comment le différencie-t-on
d'une famille adjacente SANS lire la mécanique ? ». Bleed = « ta cible frappe au ralenti » ;
Rot = « ta cible fond de l'intérieur (PV max réduits) ». Ces distinctions doivent apparaître
dans l'i18n (`src/i18n/en.lua`) et dans le tooltip de build, pas seulement dans les paramètres.
**C'est un coût RENDER, pas moteur.** Mais il doit être décidé ici (P0.5) pour guider les
textes i18n.

---

### 2.2 DÉSACCORD FORT — Le profil stat paradoxal du choc n'est PAS traité comme une EXCEPTION DOCUMENTÉE dans l'audit budget P0.5

**Ce que le brouillon dit** (§3.1, colonne E budget stat) :
> « DPS base rang-2 < médian rang-3 — seuil indicatif : DPS base rang-2 < médian rang-3,
> sinon over-statté. »

**Ce qui manque** : le brouillon applique la règle `DPS base rang-N < médian rang-(N+1)` de
manière implicitement UNIFORME. Mais le ladder choc viole systématiquement cette règle pour une
raison **fonctionnellement justifiée** qui n'est nulle part documentée comme exception.

**Preuve issue de `units.lua`** — calcul DPS base (dmg/cd) du ladder choc :

| Unité | Rang | dmg | cd | DPS base | Anomalie vs règle |
|-------|------|-----|-----|---------|-------------------|
| `live_wire` | 1 | 3 | 30 | **0.100** | Supérieur au DPS médian rang-2 (0.097) |
| `thunderhead` | 2 | 8 | 76 | **0.105** | Inférieur à DPS médian rang-2 (0.097) — OK en abs, mais hp=40 FAIBLE |
| `static_swarm` | 2 | 4 | 50 | **0.080** | Sous le médian rang-2 → pénalisé en DPS pour un cap élevé |
| `stormcaller` | 2 | 6 | 58 | **0.103** | OK mais hp=38 minimal |
| `stormlord` | 3 | 6 | 54 | **0.111** | OK — comparable à `bellows_priest` (0.111) |
| `storm_anchor` | 3 | 5 | 62 | **0.081** | Sous le médian rang-3 — compensé par persist=0.5 |
| `galvanizer` | 4 | 11 | 64 | **0.172** | Supérieur à tout rang-4 non-choc → **OUTLIER FORT** |
| `dynamo_priest` | 4 | 5 | 58 | **0.086** | Sous le médian rang-4 |
| `arc_warden` | 4 | 6 | 60 | **0.100** | Légèrement sous |
| `rust_sentinel` | 4 | 9 | 72 | **0.125** | V7 — dans la plage |

**L'anomalie clé : `galvanizer` (rang-4, DPS=0.172)** est l'outlier le plus fort de TOUT le
roster. Son DPS de frappe dépasse ceux de tous les rang-4 et la majorité des rang-5. Son effet
`bonus_first` (value=6) + `shock (add=2, cap=6)` lui donne un profil de **burst très fort au
premier coup**, ce qui est cohérent avec son identité « bruiser autonome ». Mais dans la
colonne E de l'audit, il apparaîtra systématiquement comme « OVER » → il sera marqué comme
sur-côté → risque de nerf aveugle.

**La règle `DPS base < médian rang+1` est fausse pour le CHOC.** Raison mécaniste :

Le choc est un **condensateur** : les unités choc SACRIFIENT de la régularité de DPS (cd long,
ou faible dmg/coup) pour accumuler des stacks qui déchargent en burst. `live_wire` (rang-1)
a cd=30 (ultra-rapide) mais dmg=3 (minimal) → DPS=0.100 qui cache un RÔLE d'empileur
rapide, pas d'attaquant. Appliquer la règle DPS base à `live_wire` pour le comparer à
`spore_tick` (rang-1, dmg=3, cd=30, DPS=0.100 — IDENTIQUE) est juste en chiffres mais faux
en **intention de build** : `live_wire` est là pour empiler des stacks sur la cible, pas faire
du dégât direct.

**Proposition** (§P-B) : La colonne E de l'audit P0.5 doit avoir une **clause d'exception
pour les archétypes condensateurs** (choc, et potentiellement les auras) :

- **Condensateur** (choc, `op="shock"`) : le budget se mesure en `volt × add × typical_stacks`
  attendus à la décharge, PAS en `dmg/cd`. Formule proposée : `burst_DPS = volt × stacks_moy /
  cd_moyen_décharge`. `live_wire` : volt=3 (défaut), add=1, cap=5, cd=30 → ~3-5 stacks en 90-
  150 ticks → burst≈9-15/90-150 ticks = burst_DPS_eq ≈ 0.06-0.10. Plus faible qu'un rang-1 DoT
  → OK comme enabler de choc pur. `thunderhead` : volt=6, add=1, cap=4, cd=76 → stacks≈3-4 en
  228-304 ticks → burst_DPS_eq ≈ 18-24/228-304 ≈ 0.07-0.09. Encore dans la plage rang-2.
  **`galvanizer` : volt=3(défaut), add=2+bonus_first(6→ premier coup bonus), cap=6, cd=64 →
  peut décharger 12 stacks × 3 = 36 burst + 11 (frappe régulière) / ~192 ticks = burst_DPS_eq
  ≈ 0.245 → OUTLIER CONFIRMÉ même avec la formule condensateur.**

**Ce n'est pas un bug** — `galvanizer` est un rang-4 premium à forte identité, et son prix
(4 or) doit refléter cette puissance. Mais il doit être **ÉTIQUETÉ** comme tel dans l'audit
(« condensateur premium — burst_DPS confirmé élevé, voulu ») pour éviter un nerf aveugle lors
de P3.

**Source** : le modèle condensateur est analogue aux cartes « Totem » de StS (Ironclad) : une
carte qui accumule des charges (Totem passif) et éclate en dégâts. StS les jauge sur les
**dégâts par éruption**, pas le DPS moyen par énergie. (slaythespire.wiki.gg/wiki/Cards).
Appliquer le DPS moyen à un condensateur = mesurer le wrong metric.

---

### 2.3 DÉSACCORD MODÉRÉ — Les 11 unités bouclier/tank ont une dispersion de DPS non documentée qui crée une hiérarchie implicite en build

**Ce que le brouillon dit** (§5.1 — 6e type non-DoT, litige #F orienté « aucun ») :
> « Les 11 unités shield/tank = enablers transversaux d'adjacence sans palier. »

**Ce qui manque** : décider qu'elles n'ont pas de palier (aucun 6e type) ne résout pas le
problème de la **disparité de DPS intra-groupe** qui crée une hiérarchie implicite non documentée.

**Preuve issue de `units.lua`** — DPS base des unités bouclier/tank (mesure directe) :

| Unité | Rang | dmg | cd | DPS base | Rôle déclaré | Cohérence budget |
|-------|------|-----|-----|---------|--------------|-----------------|
| `templar` | 3 | 12 | 82 | **0.146** | shield_aura + tank (aggro=40) | OVER vs rang-3 |
| `shieldbearer` | 2 | 2 | 80 | **0.025** | tank cheap (aggro=40) | Cohérent (DPS low = voulu) |
| `aegis_warden` | 4 | 3 | 84 | **0.036** | tank-épines + taunt | Cohérent (DPS low) |
| `oath_keeper` | 4 | 8 | 70 | **0.114** | pilier d'équipe (grosse aura) | Elevé pour rang-4 support |
| `bulwark_acolyte` | 3 | 5 | 60 | **0.083** | support fragile | OK |
| `gravewarden` | 4 | 3 | 84 | **0.036** | tank/taunt (épines) | Cohérent |
| `ward_weaver` | 4 | 4 | 64 | **0.063** | caster périodique | OK |
| `barrier_savant` | 4 | 4 | 60 | **0.067** | support (aura bouclier) | OK |
| `mirror_ward` | 4 | 5 | 58 | **0.086** | support (réflexion) | OK |
| `surge_warden` | 4 | 4 | 60 | **0.067** | support (surcharge) | OK |
| `runestone_golem` | 4 (v7) | 10 | 80 | **0.125** | tank-support (shield_aura) | OVER : carry-DPS + support |

**Deux anomalies claires** :

1. **`templar` (rang-3, DPS=0.146)** est le tank le plus offensif du roster — DPS supérieur à
   tous les rang-3 et à la majorité des rang-4. C'est l'une des 6 unités vanille (dessinées à
   la main). Si son DPS est voulu comme « exception iconique », il doit être ÉTIQUETÉ. Sinon,
   c'est un rang-3 over-budget qui forme une carry tank non intentionnelle en position front.

2. **`runestone_golem` (rang-4 v7, DPS=0.125)** a le profil DPS d'une carry rang-4 (plus haut
   que `ward_weaver`×2) avec un effet de support pur (`shield_aura value=12`). Signalé par le
   round 3 (§3.6 Q2) mais pas tranché : le DPS de `runestone_golem` est soit voulu (tank
   offensif qui protège ses voisins), soit une anomalie v7 de la cohorte.

**Ce que le brouillon rate** : l'affirmation « enablers transversaux sans palier » est une
décision CORRECTE (pas de 6e type), mais elle doit S'ACCOMPAGNER d'une règle de budget
spécifique aux tanks : **les tanks ont un DPS intentionnellement bas et des HP élevés** —
c'est leur coût d'opportunité. Un tank avec DPS élevé n'est plus un tank, c'est un bruiser.
La règle n'est nulle part documentée → `templar` et `runestone_golem` ne peuvent pas être
diagnostiqués sans elle.

**Proposition** (§P-C) : l'audit P0.5 doit traiter les 11 unités shield/tank avec une colonne
E DISTINCTE : `EHP_proxy = hp × (1 + shield_value/hp)` ET `DPS_budget_tank ≤ 0.07 × rang`
(tank pur = DPS low assumé). `templar` (DPS=0.146 rang-3) → **décision à prendre : bruiser
iconique intentionnel (étiqueté) ou à tuner vers DPS=0.09-0.11 ?**

**Source** : Le modèle TFT distingue explicitement « tank/front » vs « carry/back » avec des
ratios HP/DPS inversés (metatft.com : les 1-costs tanks = 600 HP / 40 DPS ; 1-costs carries =
350 HP / 85 DPS en Set 14). Une unité ne peut pas être les deux sans que le coût reflète la
double valeur.

---

### 2.4 DÉSACCORD FORT (MÉTHODE) — La décision de cohorte v7 traite le SYMPTÔME ; la CAUSE est l'absence d'un champ `pool_eligible` dans `units.lua`

**Ce que le brouillon dit** (§3.2) :
> « Filtre de 1er niveau, AVANT l'audit ligne-à-ligne : parmi les 14 v7, lesquelles ont une
> niche distincte ET un budget cohérent pour le pool day-1 ? Les autres → roster-only. »

**Pourquoi c'est insuffisant** : la cohorte v7 n'est pas la dernière vague d'unités. Toute
vague future (v8, v9 — si le projet grandit) créera le même problème. `units.lua:487` dit
« Identique au roster pour l'instant. » → cette ligne persistera à chaque vague, et la
décision de cohorte devra être reprise.

**Le vrai problème** : U.pool = U.order par défaut est une dette architecturale qui n'est pas
résolue par un filtrage ponctuel. Elle est résolue par un **champ explicite** `pool_eligible`
(ou l'inverse, `roster_only = true`) dans la définition de chaque unité. Sans ce champ :

- La décision de cohorte doit être documentée ailleurs (un fichier .md) et manuellement
  synchronisée avec le code
- Tout futur designer qui ajoute une unité doit se souvenir de la règle « v7 = roster-only
  par défaut » sans garde-fou dans le code
- Le `U.pool` restera « Identique au roster pour l'instant » jusqu'à ce que quelqu'un fasse
  le ménage

**Ce que le brouillon propose au lieu de ça** : une décision doc + retrait manuel de U.pool
(édition data, 0 op moteur). C'est acceptable à court terme mais crée une **règle implicite**
non enforçable → dette.

**Contre-argument au contre-argument** : le brouillon a raison de ne pas vouloir ajouter de
la complexité moteur. Un champ `pool_eligible` n'est PAS de la complexité moteur — c'est de
la DATA. Il n'affecte pas le moteur, juste la construction de `U.pool` dans le module `units.lua`
lui-même. Le coût est : **1 ligne par unité + refactorisation de U.pool pour filtrer selon ce
champ**. Cela transforme la décision de cohorte en **règle déclarative** vérifiable par lint.

**Proposition** (§P-D) : avant de faire la décision de cohorte v7, décider si `units.lua` doit
porter un champ `pool = false` (ou équivalent) pour les unités roster-only. Si oui :
- Ajouter `pool = false` à toutes les unités v7 non retenues (à spécifier dans l'audit)
- Reconstruire `U.pool` dynamiquement depuis `U.order` en filtrant `unit.pool ~= false`
- Ajouter une règle lint : « toute unité ajoutée DOIT avoir `pool` explicite si elle n'est
  pas destinée à la boutique day-1 »
**Coût : ~30 lignes data + 3 lignes de construction de `U.pool` + 1 règle lint.** 0 invariant
(U.pool contient les mêmes unités après, juste déclaratif).

**Source** : le principe « convention vs configuration » (Martin Fowler, *Patterns of Enterprise
Application Architecture*) s'applique ici : « si la convention ne peut pas être enforçée, il
faut la rendre explicite ». Toute règle implicite dans un fichier data accumule de la dette
silencieuse dans les jeux solo dev (les commits futurs ne savent pas qu'ils violent une règle).

---

## 3. Propositions priorisées

### P-A (P0.5, data/doc, RENDER tooltip, faible coût) — Documenter la lisibilité des EFFETS SECONDAIRES inter-familles DoT dans l'audit

**Quoi** : dans l'audit P0.5, pour chaque famille DoT, ajouter une ligne :
> **« Effet secondaire perçu en build (≤8 mots, vu par le joueur sans lire les params) »**

| Famille | Effet secondaire perçu | Risque de confusion avec |
|---------|----------------------|--------------------------|
| Burn | « Brûle vif, s'éteint sans entretien » | Poison (accumulatif) |
| Bleed | « Ta cible frappe au ralenti » | Rot (réduit aussi la menace adverse) |
| Poison | « Empoisons de plus en plus (stacks) » | Aucun (orthogonal) |
| Rot | « Ta cible fond de l'intérieur (PV max) » | Bleed (ralentit aussi la menace) |
| Choc | « Charge, puis éclate en burst » | Burn (aussi un burst) |

Cette ligne doit ensuite PILOTER les textes `unit.<id>.passive_desc` dans `src/i18n/en.lua`
pour que le texte de l'infobulle encode la distinction perçue, pas la mécanique brute. **Coût :
audit doc + directive i18n. 0 code moteur.** Priorité : AVANT de rédiger P0.5 (guide les textes).

---

### P-B (P0.5, data/doc, critique) — Traiter le choc comme ARCHITECTURE CONDENSATEUR dans la colonne E budget : formule burst_DPS_eq distincte du DPS base

**Quoi** : la colonne E de l'audit P0.5 s'applique différemment pour les unités choc :
- **Non-choc** : `DPS base = dmg/cd` comparé au médian rang adjacent
- **Choc** : `burst_DPS_eq = (volt × stacks_moy) / cd_moy_décharge` comparé à la plage rang-N
  des autres condensateurs (le choc étant sa propre famille, on compare intra-famille, pas
  cross-famille)
- **Exception documentée `galvanizer`** : burst_DPS_eq confirmé outlier (voulu, rang-4 premium)
  → étiqueter dans l'audit comme « condensateur autonome premium — outlier voulu, ne pas nerf
  aveuglément »

**Coût** : ~20 lignes de calcul tableur. **Précondition** : résoudre le litige #G (axe D) avant
de valider `galvanizer` (son burst_DPS_eq change selon l'axe — axe D = tick DoT, pas décharge
directe). **Ordre** : décider l'axe D, puis valider l'audit condensateur. 0 invariant.

---

### P-C (P0.5, data/doc) — Budget distinct pour les tanks : EHP_proxy + règle DPS_budget_tank ≤ 0.07 × rang ; trancher `templar` et `runestone_golem`

**Quoi** : les 11 unités tank/bouclier ont une colonne E dédiée dans l'audit :
1. `EHP_proxy = hp × (1 + max_shield / hp)` (max_shield = valeur d'aura ou de caster)
2. `DPS_budget_tank ≤ 0.07 × rang` comme règle indicative (tank pur)
3. **Décisions à trancher** :
   - `templar` (rang-3, DPS=0.146) : **bruiser iconique voulu** → étiqueté ; ou tuner dmg/cd
     pour un DPS ≤ 0.095 (rang-3 sain)
   - `runestone_golem` (rang-4 v7, DPS=0.125 + shield_aura) : **anomalie v7** → cohorte-only
     (roster) ou tuner DPS vers ≤ 0.08

**Coût** : audit tableur + 2 décisions. 0 code. **Précondition** : décision de cohorte v7 (§3.2).
**Garde-fou** : `templar` est une unité vanille (rig dessiné main) — ne pas rétrograder son rang
sans peser la friction UI (rang-3 en boutique T3 = accessible assez tôt, son identité visuelle
iconique compense le DPS élevé si intentionnel).

---

### P-D (P0.5, data architecture, optionnel mais recommandé) — Ajouter un champ `pool` par unité dans `units.lua` pour rendre la règle roster/boutique déclarative et lintable

**Quoi** : dans `units.lua`, chaque unité reçoit un champ `pool = false` si elle n'est pas
destinée à la boutique day-1 (ex. unités v7 roster-only). `U.pool` est reconstruit dynamiquement
via filtrage, plutôt que répété manuellement. Lint : « toute unité sans `pool` explicite =
WARNING si ajoutée après v0.9 ».

**Pourquoi non-bloquant à court terme** : si la décision de cohorte v7 est bien documentée
dans l'audit P0.5 ET commitée avant toute nouvelle vague, la dette reste gérable. Ce P-D
devient PRIORITAIRE seulement si une vague v8+ est planifiée avant P3. **Signaler comme
technicité à intégrer à la politique de contribution.**

**Coût** : ~30 lignes data + 3 lignes de refacto U.pool + 1 lint check.sh. 0 invariant.

---

## 4. Questions ouvertes

**Q1 — L'effet secondaire de Rot (amputation PV max) affecte-t-il l'aggro effective ?**
Si une cible à haut aggro (tank ennemi, aggro=40) voit ses PV max amputés, elle meurt plus vite
mais RESTE la cible prioritaire (l'aggro est câblée à `arena.lua:chooseTarget`, pas au HP
courant). La rot est donc particulièrement efficace contre les TANKS adverses. Est-ce documenté
quelque part comme interaction intentionnelle ? Si oui → l'identité rot « tueur de tank » est un
archétype de counter, pas juste un DoT de sustain. À confirmer en sim.

**Q2 — `galvanizer` en axe D : l'auto-décharge (`bonus_first` → frappe premier) déclenchera-t-elle
l'ampli DoT, ou seulement les frappes régulières ?**
`galvanizer` a `bonus_first` + `shock (add=2)`. Son premier coup applique 2 stacks de choc. En
axe D, la décharge se produit sur le PREMIER TICK DoT — mais `galvanizer` génère les stacks par
frappe, pas en one-shot. La question : si `galvanizer` frappe (add=2 stacks), puis une frappe
alliée (`live_wire` add=1) pousse la charge à cap → la décharge en tick DoT profite à
`galvanizer` ou à l'ensemble ? Est-ce que `galvanizer` reste viable comme « condensateur
autonome » en axe D, ou son identité est-elle affaiblie (l'auto-synergie disparaît) ?
→ **À clarifier dans la sim 4-configs (Config B du brouillon) — critique pour valider si 2
sous-archétypes coexistent.**

**Q3 — Les auras DoT (soot_acolyte, clot_mender, miasma_acolyte, decay_tender) ont-elles un
budget stat cohérent avec leur rôle de SUPPORT ?**
Les 4 auras rang-3 ont des DPS base variés : `soot_acolyte` (dmg=6, cd=54, DPS=0.111),
`miasma_acolyte` (dmg=4, cd=60, DPS=0.067), `clot_mender` (dmg=4, cd=56, DPS=0.071),
`decay_tender` (dmg=4, cd=60, DPS=0.067). `soot_acolyte` a le DPS le plus élevé ET l'aura la
plus forte (+50 % burn). Double valeur rang-3 = under-coûtée ? À inclure dans l'audit P0.5.

**Q4 — Quel est le ROT MINIMAL pour qu'une famille soit visible « comme archétype de build »
vs « comme complément » ?**
La règle ≥2/famille/rang vise P(≥1 enabler/boutique T2) ≥ 40 %. Mais cette probabilité de
VISIBILITÉ ne suffit pas pour que la famille devienne un *archétype de build* — il faut que le
joueur voie 2-3 unités de la même famille dans des boutiques successives pour décider de «
jouer poison ». Combien de boutiques consécutives sont nécessaires pour que le signal soit
perçu comme une « voie » et pas une « rencontre fortuite » ? À modéliser via sim
(`tools/sim.lua --family-streak-distribution`).

---

## 5. Synthèse pour le round suivant

Les 4 zones non encore épuisées par les rounds précédents, par ordre de priorité :

1. **Lisibilité des effets secondaires inter-familles DoT** (§2.1) : bleed et rot ralentissent
   la menace adverse par des axes différents mais perceptuellement similaires. L'audit P0.5
   doit documenter la ligne de lisibilité perçue → pilote les textes i18n. Coût nul, impact
   élevé.

2. **Traitement explicite du choc comme condensateur dans la colonne E** (§2.2) : `DPS base`
   est le WRONG METRIC pour les unités choc. `galvanizer` apparaîtra comme OVER dans l'audit
   si la formule est uniforme — ce qui pourrait déclencher un nerf aveugle sur le meilleur
   candidat à l'archétype choc. La formule `burst_DPS_eq` doit remplacer `DPS base` pour
   cette famille. **Critique pour éviter de casser l'équilibre choc pendant P3.**

3. **Budget distinct pour les 11 unités tank/bouclier** (§2.3) : la règle DPS base < médian
   rang+1 s'applique mal aux tanks (voulus à DPS bas). `templar` (rang-3, DPS=0.146) et
   `runestone_golem` (rang-4 v7, DPS=0.125) sont des anomalies à trancher (voulu ou à tuner).

4. **Déclarativité du champ pool dans `units.lua`** (§2.4) : solution architecturale à la
   dette silencieuse U.pool = U.order. Optionnel à court terme, recommandé avant v8+.

---

## 6. Index des sources

**Internes (lecture seule du repo)** :
- `src/data/units.lua` (intégralité relue ce round — DPS base calculés pour TOUTES les unités)
- `docs/roadmap-lab/00-state.md` (32 invariants, constantes, répartition roster)
- `docs/roadmap-lab/ROADMAP-draft.md` (v4, intégré round 3)
- `docs/roadmap-lab/round-01.md`, `round-02.md`, `round-03.md` (synthèses)
- `docs/roadmap-lab/rounds/r01-units-power.md`, `r02-units-power.md`, `r03-units-power.md`
  (lentilles précédentes — ne pas re-dériver ce qui est déjà acté)
- `src/run/state.lua` (SHOP_SIZE=5)

**Sources web vérifiées ce round** :

- [esportstales.com — TFT Set 17 champion pool size and draw chances](https://www.esportstales.com/teamfight-tactics/champion-pool-size-and-draw-chances) :
  pool partagé TFT = T1 29/T2 22/T3 18/T4 12/T5 10 copies par champion. Fonde §1.1 (distinction
  pool partagé TFT vs pool local async The Pit → la règle ≥2/famille ne copie pas TFT, elle
  répond à notre propre mathématique de visibilité).

- [a327ex.com/posts/super_auto_pets_mechanics](https://a327ex.com/posts/super_auto_pets_mechanics) :
  SAP : triggers mécaniquement orthogonaux par pet (faint / buy / sell / eat / turn start) →
  visibilité immédiate par type. Fonde §1.1 (orthogonalité des triggers SAP vs orthogonalité des
  params chez nous → plancher de visibilité différent).

- [twoaveragegamers.com — Ultimate Guide to Super Auto Pets](https://www.twoaveragegamers.com/ultimate-guide-to-super-auto-pets-game-mechanics/) :
  SAP : ~10 pets par tier, pool indépendant par tier, triggers distincts. Confirme §1.1.

- [lastepoch.fandom.com/wiki/Damage_Over_Time](https://lastepoch.fandom.com/wiki/Damage_Over_Time) :
  Last Epoch : bleed = physique non-stackable par défaut (highest instance) ; poison = chaos
  stackable infiniment. Fonde §2.1 (la distinction LE bleed/poison est encodée dans le SYSTÈME
  — type de dégât + règle de stacking — pas dans un paramètre ; à contraster avec notre approche
  param-based).

- [poewiki.net/wiki/Bleeding](https://www.poewiki.net/wiki/Bleeding) :
  PoE Bleeding = 70 % base phys, instance unique par défaut, amplifié par le mouvement de la
  cible (Crimson Dance pour stacking). Fonde §2.1 (PoE donne à chaque DoT une règle de
  stacking ORTHOGONALE — not just a different dps/sec).

- [metatft.com/tables/shop-odds — TFT Set 14 Shop Odds](https://www.metatft.com/tables/shop-odds) :
  TFT : ratio HP/DPS inversé selon le rôle. Fonde §2.3 (tanking = HP élevé + DPS intentionnellement
  bas — contrat de rôle non déclaré chez The Pit).

- [slaythespire.wiki.gg/wiki/Cards_List](https://slaythespire.wiki.gg/wiki/Cards_List) :
  StS : cartes rares = règle modifiée (Barricade, Offering, etc.) pas simple DPS amplifié.
  Fonde §1.3 (rang-5 = transform, pas stat-stick — confirmation round 3 acté).

- [gamedeveloper.com — Giovannetti GDC 2019](https://www.gamedeveloper.com/design/how-i-slay-the-spire-i-s-devs-use-data-to-balance-their-roguelike-deck-builder) :
  « Première erreur : trop de cartes qui font la même chose avec des chiffres différents. »
  Fonde §1.3 (rang-5 stat-sticks) et §2.2 (wrong metric pour le choc = DPS moyen d'un
  condensateur).

**Compétitifs lus ce round** : `competitive/super-auto-pets.md`, `competitive/tft.md`,
`competitive/slay-the-spire.md`, `competitive/postmortems.md`, `competitive/backpack-battles.md`,
`competitive/the-bazaar.md`.

---

*Round 04 rédigé le 2026-06-23. Lentille units-power. Lecture seule du repo jeu (`units.lua`
intégralité — DPS base calculés pour toutes les unités). N'édite que sous `docs/roadmap-lab/`.
Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art procédural).
32 invariants non touchés. 0 modification du code du jeu.*
