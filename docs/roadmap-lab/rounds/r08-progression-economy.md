# Round 08 — Critique adversariale : Progression & Économie

> **Lentille** : progression-economy — shop-XP passif+acheté, reroll, slots, or, courbe de
> leveling, tension monter-vs-reroll-vs-acheter.
>
> **Mandat** : challenge adversarial du `ROADMAP-draft.md` (v8, intégré round 7) depuis la
> lentille progression-économie. Accords argumentés / désaccords sourcés / propositions
> concrètes, chiffrées, priorisées. Aucune modification du code du jeu. Lecture seule du repo.
>
> **Sources primaires relues** :
> - `docs/roadmap-lab/ROADMAP-draft.md` v8 (intégral, §2.5bis, §7.0-7.5, calendrier macro)
> - `docs/roadmap-lab/00-state.md` §4 (constantes éco, boucle `startRound`, XP-gating)
> - `docs/roadmap-lab/rounds/r07-progression-economy.md` (round précédent, lentille identique)
> - `docs/roadmap-lab/round-07.md` §4 (adoptions progression/ranked)
> - `docs/roadmap-lab/competitive/super-auto-pets.md`, `competitive/tft.md`,
>   `competitive/hs-battlegrounds.md`, `competitive/balatro.md`
> - `docs/roadmap-lab/seed/mechanics.md` §1-§7
>
> **Sources web vérifiées ce round** :
> - TFT XP passive 2/round confirmé :
>   wiki.leagueoflegends.com/en-us/TFT:Experience (« You gain 2 Experience for free at
>   the end of each round »), tft.ninja/guides/game-mechanics/leveling, lolchess.gg/guide/exp
> - TFT seuils XP cumulés (wiki oficial) : L2=2, L3=8, L4=18, L5=38, L6=74, L7=122, L8=194
>   (superlinéaires, confirmés vs valeurs citées dans la roadmap v7 qui utilisait une ancienne
>   table {2,6,10,20,36,60,68} légèrement différente selon le set — note importante ci-dessous)
> - HS:BG : upgrade coût 5g (T1→T2), -1g/round non-upgradé ;
>   hearthstone.wiki.gg/wiki/Battlegrounds/Tavern_Tier (confirmé)
> - SAP freeze : superautopets.wiki.gg/wiki/Gold (freeze gratuit, non reporté entre rounds)
> - Gamedeveloper.com 2013, « The Psychology of Money » (coût d'opportunité, shadow values)
> - boosteria.org/guides/tft-economy-guide (rolling vs leveling vs rolling windows)

---

## 0. Thèse de ce round

Le round 7 a produit les avancées les plus importantes sur la lentille progression-économie
depuis le round 3 : la barre XP boutique (§2.5bis) et le pivot T4 (§7.0/§7.1 5e métrique)
sont adoptés, le gel de boutique est correctement réancré. Ces décisions tiennent.

Ce round identifie **quatre zones non résolues ou mal fondées dans v8**, toutes
sur la mécanique d'escalade XP et la tension de décision elle-même :

1. **DÉSACCORD MAJEUR : la courbe cible {2,5,10,18} est comparée à la MAUVAISE TABLE TFT.** Le
   brouillon v8 compare ses seuils XP à ceux de TFT Set 13 (mobalytics, lolchess ancienne table :
   {2,6,10,20,36,...}) alors que les seuils TFT actuels (wiki officiel Riot, confirmé ce round)
   sont **{2, 8, 18, 38, 74, 122, 194}** (cumulés L2→L8). The Pit cible **{2, 7, 17, 35}** (cumulés
   T1→T5 selon state.lua `xpToNext` avec seuils {2,5,10,18}). La comparaison n'est pas invalide
   — les deux sont superlinéaires — mais elle a été présentée comme un ancrage précis (« super-
   linéaire TFT » confirmé) alors que c'est une **analogie de FORME, pas de calibrage**. Cela
   a une conséquence directe : le critère de sim à 4+1 conditions valide la FORME de la courbe,
   mais le calibrage des seuils {2,5,10,18} vs {2,5,10,20} doit s'ancrer sur NOS constraintes
   propres (10 victoires, 1 XP passive vs 2 TFT), pas sur une table TFT qui décrit 30-40 min
   de jeu avec 2 XP/round.

2. **DÉSACCORD STRUCTUREL : The Pit a 1 XP passive/round vs 2 pour TFT, mais la courbe cible
   est calquée sur une dynamique TFT à 2 XP/round. Cet écart de 2× n'est pas modélisé nulle
   part dans les critères de sim.** En TFT, la passive seule donne 2 XP × ~20 rounds ≈ 40 XP
   cumulés au milieu de partie. Dans The Pit, la passive seule donne 1 XP × 15 rounds (run
   médian 10V/5D) ≈ 12-15 XP. Avec la courbe {2,5,10,18} (seuils cumulatifs {2,7,17,35}),
   la passive seule ne franchit jamais T4 (17 XP < 17 seulement si run 20 rounds, soit T4 à
   J+last). La **dépendance structurelle au BUY_XP est donc plus forte dans The Pit que dans
   TFT** — or le critère de sim (4 conditions) ne mesure pas cette dépendance directement. Ce
   n'est pas une erreur de design, mais c'est une décision non documentée dans le tableau
   d'intention §7.0 : est-ce voulu que T4-T5 soient quasiment inaccessibles via la passive seule ?

3. **LACUNE NON RÉSOLUE : la tension de décision « monter vs acheter vs reroller » change de
   nature selon le shopTier, mais la roadmap ne distingue pas les trois RÉGIMES de décision.**
   Le round 7 a identifié le « pivot T4 » (BUY_XP = rang-4 en coût). Ce round va plus loin :
   il existe en réalité **trois régimes de tension** dans The Pit, chacun avec une psychologie
   distincte et des signaux d'alarme différents. Les sims P3 à 4+1 conditions ne les testent
   pas séparément — une seule métrique par régime manque.

4. **DÉSACCORD MINEUR SUR LA PASSIVE 1/ROUND : le signal UI « +1 XP passif fin de round »
   (§2.5bis) est correct mais sous-dimensionné.** TFT (2 XP/round) force la passive à
   être visible parce qu'elle est fréquente et significative. Dans The Pit, 1 XP/round sur
   une courbe {2,5,10,18} a un impact marginal par rapport au BUY_XP (4 XP, 4× plus). Afficher
   « +1 XP passif » risque de **surestimer l'importance de la passive** aux yeux du joueur et
   de créer une **décision d'attente passive non fondée** (« j'accumule la passive jusqu'au
   prochain tier ») qui est mathématiquement irrationnelle (3 rounds de passive = 3 XP < coût
   d'un BUY_XP). Le signal doit être **contextualisé** : pas seulement « +1 XP » mais
   « +1 XP (3 rounds pour cette passive = 3 XP, il faut {delta} XP → {needed_buys} BUY_XP) ».

---

## 1. Accords avec pourquoi ils tiennent pour NOS contraintes

### 1.1 Or fixe 10/round non reporté : accord total — 8e confirmation

**Accord total.** Ancré sur SAP (superautopets.wiki.gg/wiki/Gold : « 10 is gained each turn,
but does not carry over turns ») et HS:BG (hearthstone.blizzard.com 2019 : « Coins can't be
saved up to be spent in future rounds »). Les deux références majeures rejettent le report.

**Pourquoi ça tient pour nos contraintes** : le budget frais concentre toutes les décisions
d'économie dans la fenêtre du round courant. En async (pas de lobby partagé), il n'y a aucun
signal social de « combien l'adversaire a épargné » — le mécanisme d'intérêt TFT exige ce
signal pour créer la tension économique de « greedy vs spending ». Sans lobby visible, l'or
fixe est la seule forme d'équité perçue garantissable.

### 1.2 XP TFT-style (passive + achetable) : accord sur la structure

**Accord sur la structure** — avec une nuance sur le calibrage (§2.1 ci-dessous).
La structure « passive + achetable » est correcte : elle crée un coût d'opportunité calibrable
indépendamment des streaks, et la décision BUY_XP existe dans tous les autobattlers à gating
de boutique. BUY_XP_COST=4 pour 4 XP (ratio 1:1) est identique à TFT (wiki.leagueoflegends.com :
« spend 4 gold to gain 4 Experience »). Ce n'est pas une analogie paresseuse : le ratio est
confirmé identique.

**Ce qui tient** : la structure de coût 1:1 est psychologiquement neutre (4g = 4 XP = valeur
face). Elle ne favorise ni ne pénalise le leveling par rapport à la valeur brute. La tension
vient du CONTEXTE (que vaut 4 XP vers le prochain tier maintenant ?) — ce que le signal UI
§2.5bis résoudra.

### 1.3 Barre XP de boutique visible intra-round (§2.5bis) : accord total, Priorité 1 confirmée

**Accord total, adoption de toutes les précédentes lentilles maintenue.** La justification
psychologique (coût d'opportunité non perçu = décision aveugle → sims P3 mesurent un joueur
mal informé) est rigoureuse. TFT affiche la barre XP en permanence (tft.ninja confirme :
« Passive XP alone is not enough — spend gold on XP to hit breakpoints on time »). Sans
visibilité, le joueur ne peut pas savoir si le breakpoint suivant est « rentable maintenant ».

**Nuance sur le signal de la passive (§2.4 ci-dessous)** : le « +1 XP passif fin de round »
doit être contextualisé, pas seulement affiché.

### 1.4 Gel de boutique différé (condition structurelle, pas hunt médian) : accord total

**Accord total** sur la correction du round 7. Le gel (freeze SAP) nécessite soit (a) un
budget reportable entre rounds, soit (b) un REROLL_COST scalant en T3+, aucun des deux n'étant
présent en v1. La confirmation SAP ce round : le freeze SAP est gratuit ET les items freezés
persistent sous reroll du même round (fandom.com/wiki/Shop) — mais HS:BG a le même freeze
gratuit, et The Pit sans budget inter-round manque la Fonction A (option temporelle). Correcto.

### 1.5 Pivot T4 documenté dans le tableau d'intention : accord total

**Accord total.** `BUY_XP_COST=4` = rang-4 en coût → décision « monter vs acheter T4 »
à parité de coût → à documenter comme tension voulue ou accidentelle. La 5e métrique
`pivot_T4_decision_rate` (cible 30-70 %) est bien calibrée. Accord maintenu.

### 1.6 Courbe {2,5,10,18} comme DIRECTION (superlinéaire) : accord sur la forme

**Accord sur la FORME superlinéaire uniquement.** La direction est correcte — une courbe
à escalade croissante crée une pression naturelle vers le leveling early sans rendre le T5
inatteignable. C'est là où s'arrête l'accord (§2.1 ci-dessous traite le calibrage précis).

### 1.7 Option C slot-decline (+3 or ou +1 or + +1 XP passive) : accord de structure

**Accord de structure.** Le trade tall-vs-wide (décliner un slot = ressource immédiate) est
un mécanisme de spécialisation lisible compatible avec le plateau-graphe. La valeur exacte
est à sim (déjà programmé). Pas de contestation de structure depuis r03.

### 1.8 REROLL_COST tranché par sim P3 (méthode) : accord total

**Accord total sur la méthode.** L'analogie SAP corrigée (1:3 en SAP ≠ 1:1 en T1 The Pit)
est verrouillée. Les 2 métriques T1-vs-T3 (`reroll_opportunity_cost` + `reroll_by_tier_ratio`)
constituent le bon cadre. La décision est réservée à la sim, pas par décret.

**Ajout de ce round** (en support du §2.3 ci-dessous) : le REROLL_COST interagit directement
avec les trois régimes de décision. En T1, `REROLL_COST=1` est quasi-neutre (1 reroll = 1
rang-1). En T4 avec REROLL_COST=1, reroller coûte 25 % d'une unité rang-4. En T5, reroller
coûte 20 % d'une unité rang-5. Le ratio REROLL/rang change à chaque tier, et **cette évolution
du ratio n'est pas un artefact accidentel** — c'est une courbe de coût relatif implicite qui
joue un rôle structurant et devrait être documentée dans le tableau §7.0.

---

## 2. Désaccords avec recherche sourcée

### 2.1 DÉSACCORD MAJEUR — La table TFT citée dans la roadmap est une ancienne table (set-dépendante)

**Claim du brouillon v8 (§7.1, §7.3, r06 §1.11)** : « seuils super-linéaires TFT (lolchess.gg/
guide/exp vérifié) » avec table {2,6,10,20,36,60,68} (par palier) = ancrage de la forme de
courbe de The Pit {2,5,10,18}.

**Le problème** : les seuils TFT **changent à chaque set** (Riot ajuste). La table citée dans
la roadmap correspond à une version passée. La table **actuelle** (wiki officiel Riot, confirmée
ce round : wiki.leagueoflegends.com/en-us/TFT:Experience) est **par palier** :
L2=2, L3=6, L4=10, L5=20, L6=36, L7=60, L8=68, L9=68.

Ce qui correspond aux **seuils CUMULÉS** : L2=2, L3=8, L4=18, L5=38, L6=74, L7=122, L8=194.

tft.ninja/guides/game-mechanics/leveling donne cependant des valeurs légèrement différentes :
L2=2, L3=6, L4=10, L5=20, L6=36, L7=48, L8=72, L9=84 (set courant différent).

**Ce que cela révèle** : les seuils TFT ne sont PAS une référence de calibrage stable —
ils bougent entre sets. Les citer comme « preuve que la forme superlinéaire est correcte »
est une **analogie de forme** (valide), mais les citer comme ancrage de valeurs précises
(« {2,5,10,18} est similaire à TFT L4=10/L5=20 ») est **non fondé** car :
1. Les seuils TFT se jouent sur ~25-30 rounds avec 2 XP/round (passive cumulée ~50-60 XP).
2. The Pit se joue sur ~15 rounds avec 1 XP/round (passive cumulée ~12-15 XP).
3. La **dépendance relative** au BUY_XP est donc structurellement différente.

**Ce qui change pour la roadmap** : la justification de {2,5,10,18} doit être ancrée sur
NOS données propres (sim), pas sur la table TFT. La forme superlinéaire est validée par
la logique de design (« tension plate vs tension croissante »), pas par l'analogie TFT.
**Le critère de sim à 4+1 conditions est la bonne méthode — mais il ne doit plus être
présenté comme « cohérent avec TFT »** ; il doit être présenté comme « cohérent avec nos
contraintes propres (run 10-19 rounds, 1 XP/round) ». Supprimer la référence TFT comme
ancrage de calibrage dans §7.1.

**Source** : wiki.leagueoflegends.com/en-us/TFT:Experience (XP passive = 2/round, seuils
par palier confirmés) ; tft.ninja/guides/game-mechanics/leveling (table alternative même
set) ; 00-state.md §4.2 (XP passive The Pit = 1/round dès round 2).

### 2.2 DÉSACCORD STRUCTUREL — La dépendance BUY_XP n'est pas modélisée dans le critère de sim

**Claim implicite de la roadmap** : le critère à 4+1 conditions (§7.1) couvre le comportement
de la courbe XP sous toutes les configurations pertinentes.

**Le problème** : aucune des 4 conditions ne mesure la **dépendance au BUY_XP** par rapport
à la passive. Or cette dépendance est une DÉCISION DE DESIGN fondamentale :

**Calcul rapide** (ancré sur state.lua via 00-state.md §4.1-4.2) :
- Passive : 1 XP/round dès round 2 → run médian 15 rounds → ~13 XP passives totales.
- Seuils cumulés {2,5,10,18} (T1→T5 via xpToNext {2,3,5,8}) : T2=2, T3=5, T4=10, T5=18.
- Passive seule : franchit T2 (round 3 : 2 XP) et T3 (round 6 : 5 XP), approche T4 (round
  11 : 10 XP) **exactement en milieu de run médian**. T5 : 18 XP = round 19 soit hors run
  court.

**Interprétation** : dans The Pit, la passive seule (si aucun BUY_XP) atteint T4 vers le
round 11 — c'est tard, mais c'est atteignable sur un run médian (15 rounds). T5 est
inatteignable passivement. Ça signifie :
- T5 est **exclusivement** accessible via BUY_XP. Un joueur qui ne BUY_XP jamais ne verra
  jamais de rang-5 dans sa boutique. Est-ce voulu ?
- En TFT (2 XP/round, ~25 rounds), la passive seule donne ~50 XP → atteint L7 (cumulé 122)
  en ~60 XP = 30 rounds. TFT a aussi des T5 accessibles seulement via XP achetée en mid-game
  — la structure est **similaire**. Mais TFT a 8 niveaux sur 30 rounds ; The Pit en a 5 sur
  15. **La proportion BUY_XP nécessaire est différente, même si la structure est analogue.**

**Ce qui manque dans les 4+1 conditions** : une **6e métrique** : `passive_vs_bought_ratio` =
fraction de l'XP totale qui provient de la passive sur les N=200 runs (toutes politiques
confondues). Cible proposée : **30-50 %** (ni trop forte dépendance à la passive = boucle
automatique, ni trop faible = le joueur ignore la passive). Si < 20 % : la passive est un
bruit de fond (à buff ou supprimer) ; si > 60 % : le BUY_XP ne vaut pas le coût d'opportunité
(à rendre plus attractif ou la courbe à durcir).

**Coût** : ~5 lignes dans `tools/sim.lua` (accumuler XP passive vs achetée dans la politique
`rush_XP` et `standard`). Non bloquant P0 ; intègre le lot sim P3 (même précondition que les
4+1 conditions existantes). Ne touche aucun invariant.

**Source** : 00-state.md §4.1-4.2 (BUY_XP_AMOUNT=4, passive=1/round dès round 2, seuils
xpToNext via table des seuils XP) ; tft.ninja (passive TFT = 2/round, structural comparison) ;
boosteria.org : « passive XP alone is not enough — spend gold on XP to hit breakpoints on
time » (TFT) → The Pit est encore plus dépendant vu la passive 2× plus lente.

### 2.3 LACUNE — Les trois RÉGIMES de tension éco ne sont pas distingués par les sims

**Claim implicite de la roadmap** : les métriques `pivot_T4_decision_rate` + `--xp-climax`
à 4+1 conditions + `reroll_opportunity_cost` + `reroll_by_tier_ratio` couvrent l'espace
décisionnel de l'économie.

**Le problème** : le brouillon identifie le « pivot T4 » (r07 §2.2 progression) comme un
point décisionnel particulier. Ce round identifie que c'est le 3e d'une série de **trois
régimes de tension** fondamentalement distincts, et que les sims actuelles n'isolent que le
3e (T4). Les deux premiers sont laissés sans signal d'alarme explicite.

**Les trois régimes** (ancrés sur `GOLD_PER_ROUND=10`, `cost=rank`, `BUY_XP_COST=4`,
`REROLL_COST=1` via 00-state.md §4.1) :

**RÉGIME 1 (T1-T2, early) — Tension de RECHERCHE** :
- Unités dominantes : rang-1 (1g) et rang-2 (2g).
- BUY_XP=4g = 4× le rang-1 = 2× le rang-2.
- Reroll=1g = même coût que rang-1.
- La tension est : « chercher (reroll) vs se contenter vs monter ». En T1, monter coûte
  **4 unités rang-1 ou 2 unités rang-2**. C'est un sacrifice de tempo élevé.
- Signe d'alarme propre au régime 1 : **reroll dominant en T1** (ratio rerolls/round > 0,25)
  = le joueur ne trouve pas ce qu'il cherche → pool trop peu diversifié ou pity insuffisant.
- Cette métrique existe (`reroll_by_tier_ratio` §7.5) mais sans seuil propre au régime 1.

**RÉGIME 2 (T2-T3, mid-early) — Tension d'ENGAGEMENT** :
- Unités dominantes : rang-3 (3g).
- BUY_XP=4g ≈ 1,33× le rang-3. L'écart est faible : monter coûte légèrement plus qu'une unité.
- Reroll=1g = 33 % d'une unité rang-3 (ratio SAP-like).
- La tension est : « s'engager sur un axe (acheter rang-3) vs explorer davantage (reroller) vs
  préparer le tier 3 (BUY_XP) ». C'est la zone où la DÉCISION D'ARCHÉTYPE se prend.
- Signe d'alarme propre au régime 2 : **rerolls excessifs en T2 sans achat rang-3** (le joueur
  cherche sans s'engager) = pool trop peu lisible ou identités rang-3 trop proches (trous de
  niche détectés par l'audit col B).
- Cette métrique est **absente** des sims actuelles. Elle cible pourtant la zone décisionnelle
  la plus importante pour la lisibilité du build.

**RÉGIME 3 (T3-T4, mid-late) — Tension de PIVOT** (c'est le pivot T4 déjà identifié) :
- BUY_XP=4g = rang-4. Décision de parité.
- Signe d'alarme : `pivot_T4_decision_rate` < 30 % ou > 70 %.
- **Couvert par la 5e métrique.** ✓

**Ce qui change** : la sim P3 doit mesurer **3 ratios de régime** (non 1) :
- Régime 1 : `reroll_dominance_T1` = rerolls/round en T1 → seuil < 0,25.
- Régime 2 : `engagement_rate_T2` = P(achat rang-3 en premier T2-round vs reroll en T2) →
  cible 50-70 % (le joueur doit s'engager plus souvent qu'explorer).
- Régime 3 : `pivot_T4_decision_rate` ∈ [30 %, 70 %]. (déjà défini)

Ces 3 ratios forment un profil de tension par régime → une seule métrique globale « declit
rate » masque des comportements opposés selon le tier.

**Coût** : ~20 lignes supplémentaires dans `tools/sim.lua`. Précondition : tableau §7.0
avec régimes documentés. Intègre P3 sans modifier invariants.

**Source** : r07-progression-economy.md §2.2 (structure triangulaire d'arbitrage) ;
gamedeveloper.com 2013 (« The Psychology of Money : shadow values ») — chaque décision sous
budget contraint exige que le joueur PERÇOIVE les alternatives pour qu'il y ait tension réelle ;
boosteria.org : « leveling vs rolling vs econning = core strategic skill in TFT economy
management ».

### 2.4 DÉSACCORD MINEUR — La passive « +1 XP fin de round » mal présentée dans §2.5bis

**Claim de §2.5bis (adoption round 7)** : afficher « +1 XP passif fin de round » comme
ligne dans la barre XP de boutique. C'est correct en tant que FAIT mais risque d'induire
une mauvaise évaluation de la décision BUY_XP.

**Le problème** : dans TFT, afficher « +2 XP fin de round » est utile car 2 XP sur une courbe
L4=18 cumulés représente **~11 % du chemin vers L5** (2/18=11 %). Dans The Pit, « +1 XP fin de
round » sur une courbe vers T3 (5 XP) représente **20 % du chemin vers T3** — ce qui semble
significatif — mais le BUY_XP donne 4 XP pour 4g, soit **4× plus vite**. Un joueur
qui lit « +1 XP passif » peut rationner son BUY_XP en pensant accumuler la passive en attendant,
alors que 4 rounds d'attente (4 XP passive) = 1 BUY_XP → le coût d'opportunité réel de
l'attente est : **4 rounds sans les unités des tiers supérieurs**.

**Gamedeveloper.com 2013** (« The Psychology of Money ») : « players consider only a small
subset of alternatives with each decision — helping them organize trade-offs is especially
important ». Le « +1 XP passif » seul n'organise pas le trade-off : il présente le gain
sans montrer le coût de l'alternative (BUY_XP × N).

**Proposition concrète** (enrichissement minimal du signal §2.5bis, RENDER pur, ~0,5 h) :
remplacer « +1 XP passif fin de round » par une ligne contextuelle :
- Si `delta = xpToNext() - shopXp > 4` : « +1 XP passif ; {delta-1} restants ({delta-1}
  rounds ou {ceil((delta-1)/4)} BUY_XP) »
- Si `delta == 1` : « +1 XP passif → palier atteint en fin de round »
- Si `delta <= 4` : « +1 XP passif ; ou BUY_XP → Tier {shopTier+1} immédiat »

Cette ligne contextualise la passive **par rapport au BUY_XP** sans supprimer l'information.
Elle évite la décision d'attente irrationnelle sans être prescriptive (elle montre le choix,
pas la bonne réponse).

**Garde-fou** : RENDER uniquement, 0 SIM, 0 invariant. Zone sans test → test headless
que le rendu contextuel est correct pour delta=1, delta=4, delta=0 (Tier max).

**Source** : §2.5bis du brouillon v8 ; 00-state.md §4.1-4.2 (BUY_XP_AMOUNT=4, xpToNext()) ;
gamedeveloper.com 2013 (coût d'opportunité et shadow values) ; tft.ninja (passive TFT 2/round
affichée comme urgence, pas comme confort).

---

## 3. Propositions priorisées

### 3.1 [PRIORITÉ 0 — PRÉCISION DOC] Retirer la référence TFT comme ancrage de CALIBRAGE de {2,5,10,18}

**Quoi** : dans §7.1 (critère à 4+1 conditions), retirer la phrase « super-linéaire TFT
(lolchess.gg vérifié) » comme justification de la forme PRÉCISE des seuils. Remplacer par :

```
AVANT : « Tester {2,5,10,18} ET {2,5,10,20} [PH] (progression Q1 : à 14 rd médian,
T5=18 → rush ≈ 14-17 % < 25 % cible). »

APRÈS : « Tester {2,5,10,18} ET {2,5,10,20} [PH]. Forme superlinéaire validée par logique
de design (tension croissante = voulu). Calibrage ancré sur NOS contraintes : run 10-19
rounds, 1 XP passive/round. L'analogie TFT est de FORME uniquement (les seuils TFT changent
à chaque set ; leur calibrage cible 2 XP/round sur 30 rounds, ≠ nos 1 XP/round sur 15). »
```

**Pourquoi** : empêche une future lentille de proposer des ajustements de seuil en se basant
sur la table TFT (qui a bougé deux fois en 18 mois selon les confirmations de ce round).
La décision de calibrage appartient aux sims P3, pas à l'analogie.

**Coût** : doc uniquement. < 20 min.

### 3.2 [PRIORITÉ 1] Ajouter la 6e métrique `passive_vs_bought_ratio` au critère de sim §7.1

**Quoi** : dans `tools/sim.lua`, mesurer le ratio passive/achetée sur toutes les politiques :

```lua
-- passive_vs_bought_ratio : fraction XP passive sur XP totale acquise
-- Accumuler : xp_from_passive += 1 chaque round (round >= 2)
-- Accumuler : xp_from_bought += BUY_XP_AMOUNT si BUY_XP acheté ce round
-- ratio = xp_from_passive / (xp_from_passive + xp_from_bought) par run
-- Agrégé sur N=200 runs par politique
```

**Seuils** :
- < 20 % → passive = bruit de fond (signal §2.5bis devient décoratif) → augmenter passive
  (+1 en round 8+, déjà en « à l'étude » §11) OU simplifier le signal passive.
- 20-50 % → zone saine : la passive contribue sans dominer.
- > 60 % → BUY_XP sous-utilisé → soit BUY_XP trop cher, soit la courbe trop facile
  à monter passivement (envisager durcir vers {2,5,10,20}).

**Pourquoi Priorité 1** : le tableau d'intention §7.0 est la PRÉCONDITION des sims P3 ;
cette métrique **complète le tableau** en documentant la tension passive/achetée comme
décision de design intentionnelle. Elle est corrélée à BUY_XP_COST (la 2e constante la plus
décisionnelle selon r07 §4.2) et au choix {2,5,10,18} vs {2,5,10,20}.

**Coût** : ~5-8 lignes dans `tools/sim.lua`. 0 invariant, 0 code moteur.

**Garde-fou** : précondition tableau §7.0. Résultat présenté à l'user avec tableau d'intention
(les décisions de design appartiennent à l'user — Q4 r06).

### 3.3 [PRIORITÉ 1] Documenter les trois RÉGIMES de tension éco dans le tableau §7.0

**Quoi** : ajouter une section « Régimes de tension par shopTier » au tableau d'intention §7.0 :

```
| Régime | ShopTier | Tension primaire | Signal d'alarme | Métrique sim |
|--------|----------|-----------------|----------------|--------------|
| 1 (early) | T1-T2 | Recherche (reroll vs contenter) | reroll_dominance_T1 > 0.25 | --reroll-cost-scaling (déjà défini) |
| 2 (mid-early) | T2-T3 | Engagement (acheter rang-3 vs explorer) | engagement_rate_T2 < 0.50 | NEW: à ajouter |
| 3 (mid-late) | T3-T4 | Pivot (BUY_XP = rang-4) | pivot_T4_decision_rate ∉ [0.30,0.70] | déjà défini (5e métrique) |
```

**Pourquoi** : le critère de sim à 4+1 conditions est une validation de la COURBE XP globale.
Les régimes sont une validation de la TENSION DE DÉCISION par zone. Ce sont deux questions
différentes. Un run peut satisfaire les 4 conditions de courbe (T5 accessible, pas trop
automatique) tout en ayant des décisions plates en T2 (engagement trivial : il n'y a qu'un
rang-3 dans l'offre, décision évidente). Sans les régimes, les sims P3 calibrent une courbe
saine mais ne garantissent pas une tension lisible à chaque phase.

**Coût** : doc ~30 min + 20 lignes sim (3 ratios). Précondition : tableau §7.0 rédigé et
validé par l'user. Intègre P3.

**Garde-fou** : régimes informatifs, pas prescriptifs. Les seuils d'alarme sont proposés ;
l'interprétation appartient à l'user + sim.

### 3.4 [PRIORITÉ 1] Enrichir le signal passive §2.5bis : contextualisé vs BUY_XP

**Quoi** : adapter le texte du signal passive dans `build.lua` (RENDER pur) :

```lua
-- Remplacer le texte fixe « +1 XP passif fin de round »
-- par un texte contextuel selon delta = state:xpToNext() - state.shopXp :
if delta == nil then -- Tier max
  -- rien (déjà couvert par §2.5bis)
elseif delta <= 4 then
  label = "+1 XP passif → ou " .. t("ui.buy_xp") .. " = Tier " .. (state.shopTier+1) .. " immédiat"
elseif delta > 4 then
  local rounds_needed = delta -- (passive rate = 1/round)
  local buys_needed = math.ceil(delta / 4)
  label = "+1 XP passif (" .. rounds_needed .. " rounds ou " .. buys_needed .. " BUY_XP)"
end
```

**Coût** : ~0,5 h RENDER. 0 SIM, 0 invariant. Zone sans test existant → test headless
que le label est correct pour delta=1, delta=4, delta=8, delta=nil.

**Précondition** : §2.5bis doit être implémenté (la barre XP de base d'abord) ;
ceci est un enrichissement du signal, pas un remplacement.

**Garde-fou** : ne pas supprimer « +1 XP passif » — enrichir. Le BUY_XP est présenté
comme alternative, pas comme prescription. Pas de guillemets « tu dois »,
langage grimdark ou neutre.

### 3.5 [PRIORITÉ 3 — CONDITIONNELLE] Évaluer +2 XP passive au round 8+ si `passive_vs_bought_ratio < 20 %`

**Quoi** : si la 6e métrique (§3.2) révèle une dépendance BUY_XP > 80 %, envisager
l'escalade de passive proposée dans §11 (« à l'étude » : +2 XP en round 8+). La passive
actuelle de 1/round est la moitié de TFT ; si la sim montre qu'elle est non-perçue,
l'augmenter ciblée sur les rounds tardifs (8+) évite de changer la tension early tout en
réduisant la dépendance structurelle au BUY_XP en late.

**Précondition absolue** : sim P3 avec `passive_vs_bought_ratio` mesurée. **Ne pas
implémenter avant la mesure.** Un second changement non mesuré sur la courbe XP = anti-
méthode MegaCrit (« un levier à la fois »).

**Coût** : 1 ligne `state.lua` si tranché. Rebase golden si `headless.lua` achète BUY_XP
(à vérifier dans le scénario golden).

---

## 4. Questions ouvertes

### Q1 — T5 est-il intentionnellement inaccessible sans BUY_XP ?

Calcul ancré : passive seule sur run médian 15 rounds → ~13 XP → n'atteint pas T5 (seuil=18).
T5 est donc réservé aux joueurs qui investissent activement en BUY_XP. Est-ce voulu ?
Si oui : documenter dans tableau §7.0 (« T5 = accès actif uniquement, exclusivité désirée »).
Si non : durcir la courbe ou augmenter la passive. Réponse appartient à l'user (Q4 r06).

### Q2 — Le régime 2 (engagement rang-3) est-il le goulet d'étranglement de la lisibilité ?

Si `engagement_rate_T2 < 0.50` → le joueur en T2 passe son temps à reroller sans s'engager
sur un archétype rang-3. Ce comportement est un symptôme de niches rang-3 indistinctes
(lié à l'audit col B, P0.5) **ou** de BUY_XP trop attractif à ce tier (il vaut mieux monter
que s'engager). Ces deux causes ont des remèdes différents ; la sim doit les distinguer.

### Q3 — La passive 1/round crée-t-elle un horizon stratégique perçu ?

En TFT, la passive 2/round est mentionnée dans tous les guides de meta (tft.ninja,
boosteria.org) comme « insuffisante seule mais prévisible ». Dans The Pit, 1/round est
encore moins visible. L'horizon stratégique (« dans 3 rounds j'aurai assez pour monter ») ne
peut fonctionner que si le joueur perçoit la passive comme un compteur. D'où l'importance
du signal contextuel (§3.4 de ce round). À confirmer en playtest.

### Q4 — Le tableau §7.0 est-il complet avant les sims P3 ?

Constantes à documenter dans §7.0 qui manquent encore d'intention explicite :
- `BUY_XP_COST` : pivot T4 intentionnel ? → [TBD, adopté r07]
- Ratio `passive / BUY_XP` : → [TBD, ce round Q1]
- Régime 2 (engagement rang-3) : → [TBD, ce round]
- REROLL_COST ratio T1/T3/T5 : → [TBD, sim §7.5]
- `SLOT_DECLINE_GOLD=3` + option C : → [TBD, sim §7.1 condition 4]

Sans ces 5 intentions documentées, les sims P3 mesurent sans verdict sur au moins 3 axes.

---

## 5. Synthèse des points clés pour la roadmap

### Ce qui change par rapport aux rounds 1-7 :

1. **La référence TFT est recadrée** : la forme superlinéaire est validée, le calibrage
   précis n'est plus ancré sur les tables TFT (qui varient selon le set). La justification
   devient autonome (nos contraintes propres : 15 rounds, 1 XP/round).

2. **Une 6e métrique `passive_vs_bought_ratio` est proposée** pour compléter les 4+1
   conditions de sim — elle mesure si la passive contribue de façon non-négligeable ou
   si elle est du bruit. Précondition du choix {2,5,10,18} vs {2,5,10,20}.

3. **Les trois régimes de tension (early/mid/mid-late) sont distingués** avec des signaux
   d'alarme propres à chaque régime. Le pivot T4 (r07) est le régime 3 ; les régimes 1-2
   manquaient de métriques dédiées.

4. **Le signal passive §2.5bis est enrichi** : contextualisé en « N rounds ou M BUY_XP »
   pour rendre le coût d'opportunité lisible sans prescrire.

### Ce qui reste inchangé et tient (8e confirmation globale) :

- Or fixe 10/round (non reporté) : correct, 8e confirmation.
- Structure XP (passive + achetable, BUY_XP_COST=4 = TFT) : saine.
- Barre XP §2.5bis Priorité 1 : maintenu et enrichi (§3.4).
- Gel conditionnel (report d'or ou REROLL_COST scalant) : correct.
- Pivot T4 dans tableau §7.0 + 5e métrique : maintenu.
- REROLL_COST tranché par sim T1-vs-T3 : méthode correcte.
- Option C slot-decline : structure saine, valeur à sim.
- Tableau §7.0 en PRÉCONDITION des sims P3 : maintenu (+ Q4 enrichi).
- Pity-signal `max(3, 0.5×médiane)` + progression visuelle implicite : accord fort.

---

## Sources

**Internes (repo, lecture seule)** :
- `src/run/state.lua` via `docs/roadmap-lab/00-state.md §4.1-4.3`
  (BUY_XP_COST=4, BUY_XP_AMOUNT=4, REROLL_COST=1, GOLD_PER_ROUND=10,
  XP passive=1/round dès round 2, seuils xpToNext)
- `docs/roadmap-lab/ROADMAP-draft.md` v8 §2.5bis, §7.0-7.5 (tableau d'intention,
  critère XP 4+1 conditions, gel, régimes de décision)
- `docs/roadmap-lab/rounds/r07-progression-economy.md` (round précédent — pivot T4,
  gel structurel, barre XP)
- `docs/roadmap-lab/round-07.md §4` (adoptions progression/économie)

**Sources web vérifiées ce round** :
- [TFT XP Experience — wiki.leagueoflegends.com](https://wiki.leagueoflegends.com/en-us/TFT:Experience)
  (passive = 2 XP/round confirmé ; seuils par palier L2=2/L3=6/L4=10/L5=20/L6=36/L7=60/L8=68)
- [TFT Leveling — tft.ninja](https://tft.ninja/guides/game-mechanics/leveling)
  (cumuls L2=2/L3=8/L4=18/L5=38 ; « passive alone is not enough »)
- [TFT Exp/Gold — lolchess.gg](https://lolchess.gg/guide/exp)
  (table XP par palier ; confirmé 2 XP/round)
- [HS:BG Tavern Tier — hearthstone.wiki.gg](https://hearthstone.wiki.gg/wiki/Battlegrounds/Tavern_Tier)
  (upgrade T1→T2=5g, -1g/round non-upgradé, confirmé)
- [SAP Gold — superautopets.wiki.gg/wiki/Gold](https://superautopets.wiki.gg/wiki/Gold)
  (10g/round, non reporté, reroll=1g)
- [SAP Shop — superautopets.fandom.com/wiki/Shop](https://superautopets.fandom.com/wiki/Shop)
  (freeze gratuit, sous reroll du même round)
- [TFT Economy Guide — boosteria.org](https://boosteria.org/guides/tft-economy-guide-interest-level-timers-rolling-windows)
  (leveling vs rolling vs econning = décision-clé TFT)
- [Game Psychology of Money — gamedeveloper.com](https://www.gamedeveloper.com/design/irrational-play-and-design-the-psychology-of-money)
  (2013 ; coût d'opportunité et shadow values : les joueurs sous-évaluent les alternatives
  non explicitées — justifie le signal contextuel de la passive §3.4)

---

*Rédigé 2026-06-23. Lentille : progression-economy, round 8. Lecture seule du repo de jeu.
N'édite que sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe
seedée / DA grimdark / pixel art procédural). 32 invariants non modifiés.
Désaccords sourcés par code + web. Propositions chiffrées ancrant les constantes dans
state.lua. 8e confirmation des accords structurels.*
