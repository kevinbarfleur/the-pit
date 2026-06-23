# ROADMAP — Brouillon #11 (intégré round 10 FINAL, priorisé, chiffré)

> **Statut** : v11, **intégré après le round 10 adversarial FINAL** (6 lentilles). Synthèse du débat :
> `docs/roadmap-lab/round-10.md` (+ `round-0{1..9}.md`). Volontairement assertif et chiffré pour être
> contesté. Chaque proposition cite sa source (URL de jeu/article ou **fichier:ligne** du repo). Les
> chiffres **[PH]** sont des placeholders d'équilibrage à valider via `tools/sim.lua`.
>
> **Diff majeur vs v10** (cf. round-10.md) — **round de COMPLÉTUDE DE SPEC + INTÉGRITÉ + FEEDBACK : une
> proposition DA-INVALIDE corrigée (skull_colossus apex choc) + 1 faille d'intégrité async exhumée (#LL
> concede meta) + la SIGNATURE du jeu enfin spécifiée (reliques positionnelles + saturation des arêtes) + 2
> litiges clos par #JJ (#HH, #II)** :
> 0. **FIL ROUGE R10 — LA SIGNATURE EST SOUS-SPÉCIFIÉE** (3 lentilles convergent : relics §2.5, synergies
>    §2.3, rétention §2.1) : le moteur (effets/sigils/adjacence/déterminisme) est riche, mais les couches qui
>    exploitent le différenciateur #1 (le plateau-graphe, le déterminisme comme feedback causal) sont
>    sous-spécifiées. **Aucune relique positionnelle (sigils) ; saturation des ARÊTES jamais mesurée ; high-roll
>    spécifié comme probabilité au lieu de feedback SÉQUENTIEL visible.** → préconditions de signature ajoutées
>    (saturation arêtes §5 + 4 reliques sigil-aware §4.11/§8.1 + activation séquentielle §2.4).
> 1. **`skull_colossus → apex choc` est DA-INVALIDE** (units §2.1/§2.2, `units.lua:421-424` code-vérifié) :
>    `type="bone", family="crane"` (crâne osseux) + `shockChain` (électricité) = incohérence thème/mécanique
>    (décision #3, le différenciateur). Tous les units choc = `type=arcane/abyss`. → **APEX CHOC = NOUVELLE
>    unité** rang-5 `type=arcane/abyss` (~15 lignes data) ; **`skull_colossus` reste burn** (niche tank-burn,
>    burn_dps 4→8). **Le « 0 moteur » du recyclage = analogie mécanique paresseuse.** **§3.7 corrigé.**
> 2. **Audit rang-5 à 3 colonnes E1/E2/E3 (DPS_frappe / DoT_dps / grant_team)** (units §2.3) : le diagnostic
>    R09 « carry burn DPS 0.131 » porte sur la frappe MÉLÉE ; le burn_dps réel = **4 (sous le rang-1 ash_moth=7)**
>    → `skull_colossus` = tank-burn opaque (E1 haut, E2 bas) ≠ `deep_kraken` (E1 ET E2 hauts) → **remèdes
>    DIFFÉRENTS.** **§3.7 + §3.1 enrichis.**
> 3. **FAILLE D'INTÉGRITÉ « CONCEDE META » = #LL neuf** (ranked §2.1, Steam Bazaar août 2025 : « kinda HAVE TO
>    concede to win ») : capturer le snapshot seulement à `startCombat` → un run avorté avant ne génère aucun
>    ghost → le concède sélectionne ses bons départs sans alimenter le pool. → **capturer dès `shopBuys >= 1`
>    OU round 2** (~5 lignes IO, exclusion jour-0). **§6.4bis enrichi. AVANT code ranked P2.**
> 4. **HIGH-ROLL = FEEDBACK SÉQUENTIEL VISIBLE, pas probabilité** (rétention §2.1, Blake Crosley + CHI 2025 Kao
>    n=1699) : la roadmap dose les VRR en fréquence sans spécifier l'activation SÉQUENTIELLE des événements du
>    bus (délai 80-120ms/nœud, accélération Balatro). Sans spec → affichage simultané (bruit) = high-roll
>    invisible. **§2.4 + §2.3 enrichis (0 SIM, le bus a déjà source/cause/tick).**
> 5. **4 RELIQUES POSITIONNELLES sigil-aware pour P1.5b** (relics §2.5) : AUCUNE des 21 reliques n'interagit
>    avec la topologie (le différenciateur #1, CLAUDE.md §2). 0 moteur (lisent `shapes[shape].edges`,
>    snapshotables) : `axis_pact`/`bloodline`/`ring_hunger`/`horde_pact`. Satisfont COURONNEURS (dimension
>    placement). **§4.11 + §8.1 enrichis.**
> 6. **TABLEAU DE SATURATION DES ARÊTES = précondition P1** (synergies §2.3, Kritz & Gaina 2025) : on a la
>    saturation `inc` mais ZÉRO pour les arêtes (la signature). « Plus de slots = plus d'arêtes » est faux
>    (croix = 4 arêtes, branches isolées). Par (sigil × famille × slots), alarme < 0.3 à 7 slots. ~1 h
>    combinatoire. **§5 enrichi.**
> 7. **#HH (palier choc-4) → CLOS par #JJ = Option B (`tickCount=2`)** (synergies §2.2) : Option A (arc →
>    voisin ADVERSE) = cause partielle ; Option B (ticks DoT du POSEUR) = cause FORTE (compo). Option B
>    compatible avec les 2 axes → **#HH tranché, DÉCOUPLE #GG.** **§3.7/§5 corrigés.**
> 8. **CRITÈRE DE TRANCHAGE CONFIG-CE2 = Option A (auto-DoT) par défaut** (synergies §2.1, PoE Lightning
>    Exposure) : ferme « détection sans résolution » — la fiabilité dépend du BUILD (#JJ), pas de l'adversaire.
>    **§3.7 enrichi.**
> 9. **GRIMOIRE MINIMAL avancé à v0.9.3 (// P0.5)** (rétention §2.3, Åslund 2026) : la méta-progression légère
>    requiert plus de temps pour « devenir claire » → Chapitre I (reliques + silhouettes) dès le 1er run. **§9
>    calendrier corrigé.** + **Chapitre II segmenté par famille** (seuil 40 % en 2-3 runs, Yu-Kai Chou). **§6.7.**
> 10. **CADENCE DE SAISON S1-S2 : 5 SEMAINES (non 3)** (ranked §2.2) : Milkman 2014 démontée (landmark naturel
>    ≠ reset arbitraire) + Bazaar mensuel démonté (pool mondial ≠ FIFO 200 local) ; 10-15 runs/saison = 1 tier
>    + temps de régénération du pool. Garde-fou bas 2→4 sem. **§6.3 corrigé.**
> 11. **RE-TIER `carrion_ledger` (tier 3 → 2)** (relics §2.2, `relics.lua:64-66`) : valeur MAXIMALE en early
>    (bypasse un palier XP) → tier-3 anti-optimal. + **granularité intra-famille sur UNE relique B** (poison,
>    `venom_covenant`) + **décider `hollow_choir` RÉORIENTÉE (pas retirée) avant P1.5a.** **§4.6/§4/§4.10.**
> 12. **Précisions doc/sim** : table du plafond naturel de la passive avant `--xp-climax` (§7.0) ; signal
>    slot-unlock avec HORIZON DE RUN (§2.5bis) ; **Amabile & Kramer → Endowed Progress Effect (Nunes & Drèze
>    2006) + framing** (§7.0) ; hiérarchie de remèdes à la condition 4 (§7.1) ; near-miss reformulé comme
>    hypothèse testable + hint opt-in (§2.3) ; prérequis escalade IA pour la Profondeur du Puits (§6.2) ; filtre
>    persistance ghost double critère (§6.3/§6.4bis) ; candidat poison-4 `poisonWeakenDeep` (§5) ; #II clos
>    recommandé (Option B symétrique, §5) ; batching #FF distingue ticks homogènes/modifiés (§5.4).
>
> **2 litiges clos par #JJ ce round** : **#HH** (palier choc-4 = Option B) ; **#II** (directionnalité #FF =
> Option B, recommandé à décision user). **1 litige neuf** : **#LL** (ancre snapshot ranked, prérequis P2).
> **#Y RÉ-OUVERT** (#LL accélère la grâce 7 j). **Q_R9_2 RE-QUALIFIÉE BLOQUANTE** (gate §2.10 sur ghost humain,
> majorité IA en bêta). **#GG DÉCOUPLÉ de #HH** (Option B compatible avec les 2 axes).
>
> ---
>
> **(Conservé v10, intégré round 9)** — **round de CALIBRAGE + ALIGNEMENT PAYOFF↔AGENCE : un fil rouge
> systémique découvert (#JJ) + 2 seuils d'alarme éco FAUX corrigés par code + 1 dette de spec de 9 rounds
> exhumée (palier choc-4) — 3 constantes revérifiées dans `00-state` par le synthétiseur** :
> 0. **FIL ROUGE `#JJ` — ALIGNEMENT PAYOFF↔AGENCE** (4 lentilles convergent : reliques §2.2, rétention §2.1/
>    §2.2, synergies §2.3, units §2.3) : **tout payoff de build doit s'ancrer sur une cause CONTRÔLÉE PAR LE
>    JOUEUR** (composition / placement / décision), JAMAIS sur la cible (afflictions adverses), l'exposition
>    (unité vue) ou l'adversaire (ghost). En async, l'ancrage adversaire est non-reproductible côté agence.
>    **Adopté garde-fou (§10, §4.11)** ; ferme/réoriente `plague_communion`, badge MAÎTRE, §2.10, choc axe D.
> 1. **`plague_communion` MAL ALIGNÉ : se déclenche sur la CIBLE, pas sur la COMPO du joueur** (relics §2.2,
>    `relics.lua:57-58` + `arena.lua:248-252` code-vérifiés) → **#J RE-TRANCHÉ** : `dot_family_count ≥ 2` du
>    BUILD JOUEUR (≠ afflictions de la cible). Devient LE payoff relique des builds multi-types (interagit
>    avec P1). Annule la variante §11 "scalante cible". **§4.2 + §11 corrigés** (golden à grep avant code).
> 2. **2 SEUILS D'ALARME ÉCO FAUX corrigés par code** (progression §2.3) : `reroll_dominance_T1 > 0.25` est
>    **trop bas** (3 rerolls = 30 % du budget = sain ; `P(cible/reroll)≈42 %` → 80 % à 3 rerolls) → corrigé
>    **`> 0.45` + `achat_rang_1_T1 < 1.5`** ; `engagement_rate_T2 = P(achat rang-3 en T2)` est **MÉCANIQUEMENT
>    IMPOSSIBLE** (rang-3 à 0 % en T2, **vérifié `00-state §4.3`**) → redéfini `P(2e achat même famille rang-2
>    vs 1re famille différente)`, cible 40-60 %. **§7.1 corrigé.**
> 3. **Palier CHOC-4 JAMAIS spécifié en 9 rounds = #HH neuf, co-bloquant #GG** (synergies §2.2, units §2.3) :
>    burn-4/bleed-4/rot-4 ont un twist nommé, **choc-4 = vide** (`rust_sentinel` ≠ twist). Option A
>    (`shockChain arc`, 0 moteur) vs Option B (`tickCount=2`, ~3 lignes), co-trancher avec #GG. **§3.7 + §5.**
> 4. **`combat_effect_legibility` = PRÉCONDITION de #FF ET §2.10** (synergies §2.1, **Q3 r08 réintroduite**) :
>    un tick peut déclencher 6-12 événements ; au-delà de 3-5 le joueur ne perçoit rien → règle de BATCHING +
>    priorité d'affichage si avg > 4. ~10 lignes sim. **§5.4 + §2.10 enrichis.** Une profondeur invisible
>    (#FF, relief) est inexistante.
> 5. **`REROLL_COST=1` n'est PAS neutre : coût relatif dérive 1:1→1:5 de T1 à T5** (progression §2.1,
>    coût=rang vérifié) — SAP (prix uniformes 3g → 1:3 constant) ne partage PAS la dynamique → documenter
>    l'INTENTION (statique/scalant/soft-cap) dans §7.0 AVANT la sim. **§7.0 + §7.5 enrichis.**
> 6. **CONFIG-CE2 : la hiérarchie choc < poison est un problème de FIABILITÉ (axe D conditionnel à
>    l'adversaire), pas de puissance** (synergies §2.3, units §2.3, #JJ) → `discharge_effective_ratio` par
>    config ; alarme < 0.40. **§3.7 matrice sim enrichie.** Les 3 mesures P0.5 ne l'isolaient pas.
> 7. **3 SIGNAUX/AXES RANKED NEUFS** (ranked §3.1-3.3) : **Profondeur du Puits #KK** (round max atteint, axe
>    orthogonal mid-core, per-run + record-saison) ; **élan 3 runs** (pré-run) ; **modificateur LP borné ±1
>    sans pénalité** par contexte de pool. Répondent à Management Science 2026 (+4-6 % via 2 dimensions
>    d'historique). **§6.2 + §6.11 enrichis.**
> 8. **Réformes PAYOFF↔AGENCE (rétention)** : signal §2.10 reformulé vers l'**agence du joueur** (pas le
>    Puits) + **BLOQUÉ jusqu'à CONFIG-SURVIVAL** (seuil 75 % PV calibré PAR RÔLE) ; badge MAÎTRE = **VICTOIRE
>    AVEC L'APEX JOUÉ** (pas découverte) ; hiérarchie one-more-run S1 = **near-miss PRIMAIRE, identité
>    SECONDAIRE**. **§2.10 + §6.7 corrigés.**
> 9. **3 analogies recalées** (ranked §4) : SAP Arena ≠ SAP v0.41+ ranked ; LoL LP invalide comme calibrage
>    (comme TFT round 8) ; Fresh Start incomplet sans incertitude partagée → **pré-annonce de saison 24-48 h**.
> 10. **#U RE-QUALIFIÉ** (ranked §2.2) : Contrainte de Saison cible "axe RÉSOLU + plus grand écart
>    potentiel/réel" (PAS "bas win-rate") ; **prérequis bloquant** (choc interdit tant que #GG ouvert) +
>    **fallback sigil pur** (`lineSlow2x`). **§8.0 enrichi.**
> 11. **Reliques** : critère COURONNEURS (E doivent OUVRIR une dimension — placement/inter-familles/compo,
>    sinon = SHAPER) ; `feeding_frenzy` = amplificateur PAS égalisateur (corriger classification) ; 3
>    archétypes éco des F documentés avant le marchand ; A non-identitaires = choix accepté. **§4.11 + §4.6.**
> 12. **Units** : collision burn de `skull_colossus` (carry+tank+dominance T3 → niche "burn sacrificiel mort
>    d'allié" 0 moteur) ; plancher "≥2 POSEURS ACTIFS/rang-3" (pas auras → désert burn confirmé) ; flag
>    compatibilité sigil pour auras r3/4 (précondition P1) ; audit `galvanizer` conditionnel à l'axe D. **§3.1.**
> 13. **Précisions doc** : slot-unlock = signal de coût d'opportunité (symétrique §2.5bis) ; rôle PASSIVE XP
>    [A] levier vs [B] rituel à déclarer §7.0 ; règle de priorité §2.10/§2.4 ; flavor d'interaction au Nom de
>    Build ; test 14 aura×palier.
>
> **(Conservé v9, toujours à prouver)** — diff structurel v8→v9 (round de PROFONDEUR STRUCTURELLE) :
> 1. **APEX CHOC `skull_colossus → shockChain` ≠ « 0 moteur » si l'axe D adopté = LITIGE #GG BLOQUANT**
>    (units §2.3, **code-vérifié synthé**) : `shockChain` est consommé dans `dischargeShock` (`arena.lua:
>    342-388`) = **burst de décharge (axe A/B)** ; l'axe D (ampli du 1er tick DoT) **n'est PAS implémenté**.
>    « 0 moteur » ne tient que si le choc reste axe A/B. **§3.7 + §3.4 corrigés** : trancher avant P1 —
>    Option 1 (2 axes coexistent) vs Option 2 (`shockAmpMult`, moteur minimal cohérent).
> 2. **`corruptor`/`bile_spitter` rang-3 = paire de DOMINANCE** (units §2.1, code-vérifié synthé) : op
>    identique (`poison dps=2 dur=180`), `weaken 0,06 < 0,10` = `bile_spitter` strictement meilleur → dead
>    pick. **Audit col B étendu rang-3.** + **`rust_sentinel` rang-4 = `stormcaller` rang-2 (op IDENTIQUE
>    `shock add=1 cap=6 dur=150`)** = viole #10, jamais vu en 7 rounds → **col B/E étendues rang-4** ;
>    `runestone_golem` niche ambiguë (aura<oath_keeper).
> 3. **`--pool-repr` AVANT `--poison-frac` en ORDRE STRICT = #DD CLOS (strict)** (synergies §2.1 + units Q3) :
>    **preuve neuve** — retirer `corruptor` change la représentation rang-3 poison → simuler avant la cohorte
>    mesure un pool à corriger. La nuance r07 (« même lot ») tombe.
> 4. **Signal VRR de RELIEF « CONTRE LA MORT » (nouveau §2.10)** (retention §2.1) : **les 5 sources VRR sont
>    toutes POSITIVES** → habituation au même circuit (Game Developer : « habituation by reward TYPE »). Il
>    manque le **contraste hédonique** (relief sous agence, SDT Dark Souls). Post-victoire, unité-singulière,
>    P0 RENDER ~1 h.
> 5. **`offer_decision_quality` SEGMENTÉE par tier + pseudo-décision** (relics §2.1) : seuil uniforme « 40 % »
>    ignore la trivialité STRUCTURELLE early (**≥89 % des offres contiennent une A**, hypergéométrique) + ne
>    détecte pas 2 B même famille (non-triviale au lift mais 0 tension). Cibles par tier + divergence de
>    conséquence. **§3.10 enrichi.**
> 6. **GRIMOIRE — couche de MAÎTRISE visible** (retention §2.3) : implémente la découverte (Ovsiankina) pas la
>    maîtrise (SDT-compétence, le type le plus durable, IntechOpen 2025). Badge INITIÉ/PRATICIEN/MAÎTRE par
>    famille (apex découverts). **§6.7 enrichi, P2 RENDER.**
> 7. **CONTRAINTE DE SAISON → P2 (depuis P4-light)** (ranked §2.3) : `grant_team` câblé → 0 moteur ; sans
>    différenciateur méta, **la S2 = reset de score dans une méta inchangée**. 4 `teamFlags` saisonniers
>    pré-définis avec ranked v1. **§8.0 → calendrier v0.11.3.**
> 8. **Daily SEED PARTAGÉ (date+contrainte) = #BB CLOS (condition)** (ranked §2.1) : sans adversaires
>    partagés, l'analogie StS Daily est **paresseuse** ; 1 ligne (`daily_seed`), leaderboard comparable même à
>    10 joueurs. Scope = combat seul (#EE-ranked). **§6.6 enrichi.**
> 9. **Seuil PROGRESSIF du Nom de Build = #EE adopté** (synergies §2.3) : `≥4` impossible à 3 slots → fallback
>    « ARPENTEUR » pendant les rounds 1-4 (zone churn 0-5 wins). ≥2 early / ≥3 mid / ≥4 late. **§2.4bis enrichi.**
> 10. **IA cold-start ranked = 1 build par famille (6 Encounters)** (ranked §3.3) : pool FIFO biaise vers les
>    familles à win-rate élevé → le joueur choc ne voit jamais de ghost choc → abandonne. **§6.4bis enrichi.**
> 11. **CONFIG-CE co-prioritaire à la décision d'apex choc** (synergies §2.4) : apex sans correction de latence
>    early = apex jamais atteint. Promu de « diagnostic P3 » à mesure P0.5. **§3.7 enrichi.**
> 12. **Métriques éco** (progression §2.1-3.4) : 6e métrique `passive_vs_bought_ratio` ; **3 régimes de tension**
>    (T1 recherche/T2 engagement/T3 pivot) ; signal passive contextualisé ; **retrait de la table TFT comme
>    ancrage de CALIBRAGE** (forme seule, set-dépendante). **§7.0/§7.1/§2.5bis enrichis.**
> 13. **Précisions** : désert rang-3 burn (units §2.4) ; framing i18n ranked/normal AVANT code P2 (ranked §2.4) ;
>    signal distribution pool post-combat ranked ; nom de build = mode statistique + Daily exclu ; pondération
>    hédonique du tableau VRR ; ordre de calibration des reliques B ; critère #CC documenté avant P1 ; note
>    drought-protection reliques P3 ; test edge-case axe D + C2 ; gate `player_move` avant §2.7.
>
> **2 propositions de PROFONDEUR adoptées comme SPEC À PROUVER (pas gravées)** : **#FF interactions inter-
> familles MID** (aggravation croisée + contagion au kill — la diversification mécaniquement récompensée avant
> les T3) ; **relique B SCALANTE « resonance »** (cohérence mono-famille, coût d'irréversibilité positif à la
> Balatro). **Les deux dépendent du tableau de saturation (précondition P1) + `dot_family` (P0.5)** → spécifiées
> et simulées AVANT de graver.
>
> **4 litiges neufs R09** : **#HH** (palier choc-4, co-bloquant #GG) ; **#II** (directionnalité #FF) ; **#KK**
> (Profondeur du Puits per-run vs record) ; **#JJ** (alignement payoff↔agence — ADOPTÉ garde-fou, pas litige).
> **#J RE-TRANCHÉ** (plague_communion → compo du joueur). **#U RE-QUALIFIÉ** (critère Contrainte de Saison).
> **Aucun clos par preuve concluante R09** (un litige ne se clôt que sur preuve, pas sur consensus mou).
> *(Conservés v9 : #GG axe apex BLOQUANT ; #FF inter-familles MID ; #EE seuil nom de build ADOPTÉ ; #EE-ranked
> scope seed daily CONFIRMÉ. Clos v8 : #DD, #BB, #Z.)*
>
> **Ancrage** : `00-state.md` (état canonique + 32 invariants), `BRIEF.md`, les 10 teardowns
> `competitive/*.md`, les 48 critiques `rounds/r0{1..9}-*.md`, les 8 synthèses `round-0{1..8}.md`.
> **Garde-fous** : 4 piliers, 10 décisions définitives, 32 invariants. Toute proposition touchant un
> invariant le **signale** et exige le changement de test AVANT le code. Lecture seule du repo ;
> n'édite que sous `docs/roadmap-lab/`. **Règle de méthode (round 4-9)** : reformuler/corriger un mécanisme
> existant = citer la **ligne de code/constante relue ce round**, jamais une description héritée. Une
> affirmation « code-vérifiée » d'un round précédent reste contestable ; un litige nuancé reste ouvert tant
> qu'une preuve neuve peut le trancher ; un litige ne se clôt que sur preuve. **Round 9 : 3 constantes
> revérifiées dans `00-state` (coût=rang → ratio reroll 1:1→1:5 ; rang-3 à 0 % en T2 ; `XP_TO_LEVEL={2,5,8,12}`
> = placeholder) tranchent ou démolissent des seuils que 8 rounds avaient laissés passer.**

---

## 0. TL;DR — la thèse de priorisation (révisée round 5)

**Le jeu a un moteur solide ; il lui manque LA RAISON DE RÉENCHAÎNER — ET son contenu a des trous, des
collisions, ET des bugs latents que seule la relecture du code révèle.** Les rounds 4-5 ont relu le code
**ligne à ligne** : round 4 a découvert que la roadmap décrivait des reliques inexistantes ; **round 5 a
débusqué 3 bugs/trous de plus** (`afflictionCount` compte la présence → `wither_bloom` déclenche
`plague_communion` à lui seul ; les renforts de bouclier sont des **dead picks dans le pool** ; le snapshot
n'a **pas de séparation ranked/unranked**). **Leçon** : avant d'empiler du design, **vérifier ce que le code
fait vraiment** — puis (a) **mesurer les DEUX causes structurelles de poison>choc AVANT les types**
(propagation **et** weaken), (b) **décider le design du compteur type AVANT d'écrire ses tests** (variance
positionnelle), (c) traiter le choc comme un **condensateur** + **ampli ciblé sur la famille du poseur** +
**visible**, (d) donner au ranked une **intégrité de pool réelle** (ranked≠unranked) + un **moteur pré-run au
bon horizon** (sub-tier), (e) traiter la **session initiation** (signal d'appartenance — personne ne lance le
jeu sans raison), (f) **exposer les décisions éco implicites** (`REROLL_COST`). Sinon on amplifie une méta
cassée, on récompense (en ranked) la pauvreté du pool plutôt que le skill, et on retient l'intra-session sans
jamais faire **rouvrir** le jeu (postmortems Dota Underlords : −97 % en <2 ans).

**Cinq chantiers dominants, dans cet ordre (inchangé ; P0/P0.5/P1/P2 enrichis rounds 6-7) :**

1. **Lisibilité, feedback, HIGH-ROLL, ATTRIBUTION, APPARTENANCE, VRR BOUTIQUE & IDENTITÉ DE RUN (P0)** —
   multiplicateur de tout, bon marché, débloque l'attributabilité du ranked **et** la session initiation
   **et** la **relance**. **Round 8** : **signal VRR de RELIEF « CONTRE LA MORT »** (§2.10 — les 5 sources VRR
   sont toutes POSITIVES = même circuit ; le relief sous agence = contraste hédonique, SDT Dark Souls) ;
   **seuil PROGRESSIF du Nom de Build** (§2.4bis — `≥4` impossible à 3 slots → fallback en zone churn ; ≥2/≥3/≥4)
   + **mode statistique** (« TU ES PRINCIPALEMENT UN BRÛLEUR [4/10] ») + **Daily exclu** ; **signal passive
   contextualisé** (§2.5bis — « +1 XP (N rounds ou M BUY_XP) ») ; **#Z = gate bloquant de §2.8** ; **gate
   `player_move` avant §2.7** ; **pondération hédonique du tableau VRR** (§2.9). (Round 7 : NOM DE BUILD §2.4bis,
   BARRE XP §2.5bis, VRR Phase 2 + enveloppe ≤20/run. Round 6 : VRR boutique §2.9 ; trace d'impact §2.8 ; surprise
   placement drag intentionnel + cap 10. Round 4-5 : Moment du Run source+placement+P75, streak-loss, appartenance.)
2. **Audit identité QUANTITATIF (10 col A-J) + axe choc AXE D ciblé + corrections code + RANG-5 + APEX CHOC (P0.5)** —
   data/doc + sim, ≤2 réécritures ciblées (choc + `afflictionCount`). **Round 8** : **#GG BLOQUANT — apex choc
   `shockChain` ≠ 0 moteur si axe D** (code-vérifié : `dischargeShock` = burst, axe D non implémenté → trancher
   l'axe AVANT P1) ; **`corruptor`/`bile_spitter` rang-3 = DOMINANCE** + **`rust_sentinel` rang-4 = `stormcaller`
   rang-2 (op identique, viole #10)** + **`runestone_golem` ambigu** → **col B/E étendues rang-2/3/4** ; **désert
   rang-3 burn** ; **`--pool-repr` AVANT `--poison-frac` ORDRE STRICT (#DD clos)** ; **CONFIG-CE co-prio à la
   décision apex** ; **`offer_decision_quality` segmentée par tier + pseudo-décision** ; **critère #CC documenté
   avant P1**. (Round 7 : `deep_kraken`→r4/`skull_colossus`→apex choc ; paires niche rang-2 ; cross-rank byakhee.
   Round 6 : colonne J, P90/P10≤3×, CONFIG-PC. Round 4-5 : #S, `--poison-frac`/`--no-weaken`, C2, burst_DPS_eq.)
3. **Complétude reliques P1.5a (data pure, // P0)** — garantie B-E + déprio F + arc temporel ACTIONNABLE +
   règle ≥2/archétype. **Round 8** : **ordre de calibration des B** (bleed/rot faibles AVANT burn — éviter le
   tuning du symptôme) ; **baseline `offer_decision_quality` post-correction-garantie-early** ; **note
   d'intention DROUGHT PROTECTION reliques (P3)**. (Round 7 : `famines_math` tri STABLE par `id` NON-NÉGOCIABLE ;
   hiérarchie build-definition §4.11 — E = amplificateurs → P1 = prérequis de fun ; `forked_tongue` non silencieuse
   #Q2-relics CLOS ; sacred_shield 120 ticks. Round 6 : #O option a, hollow_choir pool-A, sacred_shield [PH].)
4. **Synergies par TYPE (P1)** — les 5 familles DoT comme types, `dot_family` + lint, **compteur GLOBAL PUR
   (#D CLOS round 6)**, seuils 2/4, twist = **1 règle `more` bornée, ≠ sous-cas T3, ≠ vide-T2** ;
   **bleed-4 = `bleedPierceShield`**, **burn-4 = `burnIgnoreShield` (#W CLOS)**. **Round 8 — la lacune de
   profondeur #1 : P1 CLOISONNE les familles** → **#FF interactions inter-familles MID** (aggravation croisée
   + contagion au kill — adopté SPEC À PROUVER après le tableau de saturation, **pas gravé**) + **relique B
   SCALANTE « resonance »** (cohérence mono-famille, P1.5b candidate). **Précondition (r7-8)** : test 2a/2b
   (shield_caster actif) + baseline `offer_decision_quality` + tableau saturation [+exception choc +bleed-par-
   rang +resonance +#FF entrent dedans]. **Conditionné par P0.5** : `dot_family` posé + **poison non
   structurellement dominant** (propagation **ET** weaken **ET** représentation pool corrigée) + **apex choc
   existant (axe #GG tranché)**.
5. **Ranked v1 LOCAL + Daily + Contrainte de Saison (P2)** — moteur du « grimper ». **Round 8** : **Daily SEED
   PARTAGÉ** (date+contrainte → leaderboard comparable même à 10 joueurs ; #BB clos, scope combat seul) ;
   **CONTRAINTE DE SAISON avancée P4-light → P2** (4 `teamFlags` saisonniers, 0 moteur — sans différenciateur méta
   la S2 = reset de score) ; **IA cold-start ranked = 1 build par famille** (le joueur choc doit voir des ghosts
   choc) ; **signal distribution pool post-combat ranked** ; **framing i18n ranked/normal AVANT le code** ;
   **Grimoire couche de MAÎTRISE** (badge SDT-compétence par famille). (Round 7 : Daily UNRANKED + leaderboard ;
   ranked S1 = Invocations ; IA = Encounters puissants ; score persiste inter-saisons explicite ; #Z = IA distincte.
   Round 6 : SOFT=3/HARD=5 (#T), saisons 3-4 sem., FIFO persistance filtrée + grâce 7 j, cosmétique daté.)

Puis **P1.5b** (post-choc : swarm_logic scalante + shield + 1 relique rot tier-4 ; option `hollow_choir`
réorientée `pierceShield` ; **relique B SCALANTE `resonance_stone` candidate** [round 8, après saturation] ;
**reconception `wither_bloom` si #CC le tranche**) → **P1.5c** (post-marchand : F→marchand) → **P3 équilibrage
auto** (+ recourbe XP robuste variance **et streaks** + **co-calibration shopTier/slots** + décision `REROLL_COST`
+ **pivot T4** + **6e métrique `passive_vs_bought_ratio`** + **3 régimes de tension éco**) — **précédé du tableau
d'intention des constantes éco** → **P4 reliques G (sigils) + saisons (3-8 sem. selon contenu)**.

**Ce qui NE doit PAS entrer** (analogies paresseuses démontées, §10) : intérêt/banque d'or, grille 2D
Backpack, héros nommés, ciblage RNG, anomalies globales **aléatoires par lobby**, **DPS estimé pré-combat**
(ni un **pré-run directif** qui dicte l'éco du run), unités T5 lockées, floors LP/MMR caché, grille de score
avec pénalité, **score intra-run** (StS Ascension l'a abandonné), rating par sigil, mode endless, monétisation
multi-points, **axe choc C (réordonne `hit()`)**, **ampli choc-D sur l'ordre fixe pur** (trahit la famille du
build), **`build_cost_proxy` volatil**, **flag `quality.human` punitif caché**, **`feeding_frenzy` refondue**,
**`plague_communion` « scalante par famille majoritaire »**, **`dmg/cd` uniforme appliqué au choc**, **seuil
Moment du Run sur les 250 seeds fixes**, **pity-garantie explicite**, **friction inter-familles MOTEUR**
(F1/F2, casse la composabilité data ; F3-doc suffit), **`sv` snapshot spéculatif maintenant** (différé ;
re-lié à #Y), **guidance d'agence prospective au round 1-2** (doublon du surlignage d'arêtes §2.1).
**Round 6** : **compteur de type HYBRIDE 2-global/4-adjacence** (dead-zone TFT Galaxies ; les auras
sont déjà l'axe positionnel — #D clos global pur), **changer `REROLL_COST` ce round** (analogie SAP corrigée
mais valeur tranchée par sim P3, pas par décret), **démonter le Moment du Run** (il fait *rester* ; on AJOUTE
le VRR boutique pour *relancer*), **citer Bazaar comme validation du « sans pénalité »** (Bazaar a la perte
de points depuis 2025 — citer format run-court + FIFO local), **afficher le nom des joueurs** dans « spectre
affronté » (la valeur est la trace, pas la connexion sociale → anonymat grimdark), **saisons 6-8 sem. sans
contenu** (timer perçu ; 3-4 sem. échelonnées par contenu), **`siege_breaker`/`soot_acolyte` traités comme
budgets symétriques** (double-valeur non documentée).
**NOUVEAU round 7** : **différer `deep_kraken`/`skull_colossus` rang-5** (BLOQUANT, pas différable — DPS
> tous les T3 + async = mur sans counter-play), **`bleedPierceShield` 1 pt/tick sans tester `shield_caster`**
(absorbé par `ward_weaver` niveau-3 = quasi-inerte, code-vérifié → test 2b obligatoire), **`famines_math` tri
sans clé secondaire `id`** (`table.sort` Lua non-stable → non-déterministe → viole l'invariant #2), **traiter
les reliques E comme build-defining au sens StS** (pas de downside ≠ boss relics StS qui forcent le theming →
amplificateurs, pas créateurs ; P1 = prérequis de fun), **changer `bleedPierceShield` en burst PAR DÉFAUT**
(le drain progressif est l'identité voulue ; burst = repli SI la sim 2b prouve l'inertie), **imposer
`--pool-repr` AVANT `--poison-frac` en ordre strict** (la col B le fait déjà qualitativement ; même lot P0.5,
pas d'ordre prouvé — **RENVERSÉ round 8 : ordre STRICT adopté, preuve corruptor**), **vue Grimoire-par-archétype
comme item P2 séparé** (subsumée par le nom de build §2.4bis ; 2e segmentation avant validation de la 1re =
sur-engineering), **Daily ranked sans pool dédié** (#BB : biais famille dominante ; recommandation = unranked +
leaderboard journalier).
**NOUVEAU round 8** : **graver l'apex choc `shockChain` comme « 0 moteur » sans trancher l'axe** (`dischargeShock`
= burst axe A/B ; l'axe D n'est PAS implémenté → « 0 moteur » faux si axe D adopté ; #GG à trancher avant P1),
**laisser l'audit de paires au rang-2 seul** (`corruptor`/`bile_spitter` rang-3 = dominance, `rust_sentinel`
rang-4 = `stormcaller` rang-2 op identique → col B/E rang-2/3/4), **graver les interactions inter-familles MID
(#FF) ou la relique resonance dans P1 sans les passer au tableau de saturation** (un `more` croisé/scalant peut
dépasser le seuil de saturation — adoptés SPEC À PROUVER, pas gravés), **traiter les 5 sources VRR comme
diverses** (toutes de valence positive = même circuit ; il manque le RELIEF, contraste hédonique → §2.10),
**seuil Nom de Build fixe ≥4** (impossible à 3 slots → fallback en zone churn 0-5 wins ; seuil progressif #EE),
**Daily à seed libre** (sans seed partagé date+contrainte, le leaderboard mesure la chance de pool = analogie StS
paresseuse ; #BB clos avec condition seed), **différer la Contrainte de Saison en P4-light** (`grant_team` câblé =
0 moteur ; sans elle la S2 = reset de score dans une méta inchangée → P2), **MMR caché à la TFT** (6-9 runs/saison
ne convergent pas ; `slot_tier_composite` suffit), **partage social / streak des noms de build** (anonymat
grimdark ; streak punit l'exploration), **VRR négatif prévisible** (le déterminisme rend le signal fixe = pas du
VRR), **ancrer le calibrage de la courbe XP sur la table TFT** (set-dépendante + 2 XP/round ≠ nos 1/round ; forme
seule).

**Calendrier macro** (solo dev, jalons `vX.Y` ; §9) :
`v0.9 Lisibilité+carte risque+Moment du Run(source+placement+P75)+NOM DE BUILD(§2.4bis: seuil PROGRESSIF
+mode statistique +Daily exclu)+BARRE XP boutique(§2.5bis +passive contextualisée)+post-combat+surprise de
placement(drag intentionnel, gate player_move)+SPECTRE AFFRONTÉ(trace d'impact, #Z=gate)+VRR BOUTIQUE(Phase 2 +
enveloppe pondérée hédonique)+SIGNAL RELIEF « CONTRE LA MORT »(§2.10)+validation distribution VRR(3 signaux)` →
`v0.9.3 P1.5a reliques(data, // — arc temporel actionnable + forked_tongue gating[#Q2-relics CLOS] +
famines_math #O option a + TRI STABLE id + hollow_choir pool-A + sacred_shield[120 ticks] + §4.11 hiérarchie
build-definition + ORDRE de calibration B[bleed/rot avant burn] + note drought-protection P3)` →
`v0.9.5 Audit 10-col(A-J)+RANG-5 BLOQUANT(deep_kraken/skull_colossus)+APEX CHOC #GG(axe A/B vs shockAmpMult,
TRANCHER avant P1)+CONFIG-CE co-prio apex+paires niche/DOMINANCE(col B rang-2/3 corruptor/bile_spitter)+rang-4
audité(rust_sentinel=stormcaller, runestone_golem, col B/E)+cross-rank byakhee(col E)+désert rang-3 burn+singletons
rang-1(gnaw_rat)+dot_family+choc AXE D CIBLÉ(#S)+afflictionCount(C2 +critère #CC)+plague_communion CONFIG-PC
+offer_decision_quality(par tier +pseudo-décision)+pool-repr AVANT poison-frac(#DD ORDRE STRICT)+no-weaken
+position-variance(calibrer auras)+burst_DPS_eq+budget tank+test edge axe D+C2)` →
`v0.10 Types(GLOBAL PUR #D, dot_family, bleed-4, burn-4 ignoreShield #W ; précédé tableau saturation inc
[+exception choc +bleed-par-rang +resonance +#FF entrent dedans] + test 2a/2b inter-famille[shield_caster actif]
+ baseline offer_decision_quality post-correction-garantie + SPEC #FF interactions inter-familles MID[à prouver
en sim saturation])` →
`v0.10.5 P1.5b swarm scalante + shield + relique rot tier-4 + shock_conduit + resonance_stone candidate(#FF)
(+ option hollow_choir→pierceShield) (+ reconception wither_bloom si #CC)` →
`v0.11 Ranked v1 local + POOL RANKED SÉPARÉ + RANKED_MIN_POOL(SOFT=3/HARD=5) + pré-run SUB-TIER + marques +
COSMÉTIQUE DATÉ fin de saison + score persiste inter-saisons explicite + slot_tier_composite + pool-signal +
post-combat-ranked(+distribution pool familles) + Daily UNRANKED+leaderboard journalier+SEED PARTAGÉ(#BB, scope
combat) + ranked S1=Invocations + IA ranked=Encounters puissants 1/FAMILLE + framing i18n ranked/normal + tooltip
daily + Grimoire 3-chap(III silhouette Ovsiankina, II segmenté par famille + BADGE MAÎTRISE SDT) + Dernier
Souffle + #Z=IA formulation distincte + FIFO de saison(persistance filtrée + grâce 7 j)` →
`v0.11.3 §8.0 Contrainte Permanente de Saison (AVANCÉE P4-light → P2, 4 teamFlags pré-définis, famille
sous-représentée, priorité VISIBLE — livrable avec ranked v1)` →
`v0.11.5 P1.5c F→marchand` →
`v0.12 Équilibrage auto (tableau d'intention éco PRÉCOND.[+pivot T4] + recourbe XP robuste variance+streaks+
co-calibration slots + REROLL_COST tranché) + pool + reliques-qualité` →
`v0.13 Reliques G (sigils) + saisons(3-8 sem. échelonnées par contenu)` → `v1.0 Backend + Daily mondial`.

---

## 1. Pourquoi cet ordre (logique de séquencement révisée round 4)

Le séquencement reste une **chaîne de dépendances + dérisquage**, avec le **dérisquage du contenu
AVANT les systèmes qui en dépendent**. Round 4 a **vérifié le contenu réel** et **promu 2 mesures en
P0.5** :

- **Lisibilité + Moment du Run + post-combat + surprise de placement (P0)** : multiplicateur, bon
  marché, condition de l'attributabilité du ranked. **Round 4** : 3 sources de VRR distinctes et
  temporellement complémentaires — **placement** (early, plateau peu peuplé), **cascades DoT** (mid-
  late), **reliques** (offre 1-parmi-3). Le seuil de chaîne se mesure sur **seeds variées** (P75), pas
  les 250 seeds fixes du fuzz (biais déterministe). RENDER, lu du bus.
- **Audit identité QUANTITATIF + `dot_family` + choc AXE D + 2 sims (P0.5)** : **convergence de 3
  lentilles**. **Round 4** : (a) le choc passe par **`tickDots`** (axe D), pas `hit()` (axe C
  infaisable) ; (b) `--poison-frac` mesure la **cause structurelle** de poison>choc **avant** que les
  types ne l'amplifient ; (c) `--position-variance` décide le **design** du compteur type **avant**
  d'écrire ses tests ; (d) le choc est jaugé en **`burst_DPS_eq`** (condensateur). La **seule** ligne
  de code moteur du P0.5 reste la réécriture ciblée du choc (+ signal UI = RENDER). Le reste = data/
  doc + sim → se fait pendant que P0 (RENDER) tourne.
- **P1.5a (data pure, // P0/P0.5)** : garantie B-E + déprio F + rôle temporel + `famines_math` (#O)
  sont **sans dépendance** → les retarder dilue les offres pendant P0-P0.5. **`plague_communion`
  gardée telle quelle** (la « correction » du round 3 est annulée).
- **Types (P1)** : enrichissent chaque run AVANT d'en demander 100. **Seulement** une fois `dot_family`
  posé (P0.5) + niches/budgets nommés + **poison non structurellement dominant** (`--poison-frac`) +
  le twist spécifié comme `more` borné. Mécanisme = `grant_team` build-résolu, golden-safe.
- **P1.5b (post-choc)** : `swarm_logic` (scalante) + shield dépendent de l'axe choc décidé (P0.5).
- **Ranked v1 LOCAL (P2)** avant backend : `state.lua` supporte l'injection de seed (#2). **Round 4** :
  ajoute le **moteur pré-run** (le manquant #1 — les signaux post-run ne lancent pas une session) et
  le **post-combat ranked enrichi** (la vraie asymétrie ranked/unranked). **§8.0 Contrainte Permanente
  de Saison** est **AVANCÉE en P2 (round 8 — livrable avec ranked v1)** : `grant_team` câblé = 0 moteur ;
  sans différenciateur méta saisonnier la S2 = reset de score → comble le plafonnement inter-saisons **dès la
  S2**, pas en P4. **Round 8** : Daily **seed partagé** (#BB) ; IA cold-start = 1 build/famille ; framing i18n
  ranked/normal avant le code ; Grimoire couche de maîtrise (SDT-compétence).
- **Équilibrage auto + pool + recourbe XP (P3)** : on ne tune pas un système qu'on n'a pas. **La
  recourbe XP doit être robuste à la VARIANCE de durée de run** (#R : 10-19 rd) ; `--poison-frac` et
  `--position-variance` sont **déjà mesurés en P0.5** (ne reviennent ici que pour le tuning fin).
- **Reliques G (sigils) + saisons (P4)** en dernier des gros chantiers — MAIS **prototyper 1 forme
  pendant P3** si le critère du plafond de connaissance se déclenche (§6.7), et le **Grimoire
  3-chapitres** rend l'arc visible **dès le run 1** (codé en P2).

> **Litige #A (P3, conditionné round 4)** : P1 (types) vs P2 (ranked). Critère `--meta-convergence`
> (§7.1), `rang_convergence < 8 runs` pour **≥2 sigils** → types d'abord. **Désormais à mesurer sur
> une méta NON cassée** (après `--poison-frac`, sinon la convergence est artificielle). 2 args
> tiennent (variance inter-runs ≠ « compo dominante » ; types remplissent le pool ranked).

---

## 2. CHANTIER P0 — Lisibilité, feedback, HIGH-ROLL & ATTRIBUTION (v0.9, ~1 lot)

> **Pourquoi P0** : multiplicateur de fun, coût faible, débloque l'attributabilité du ranked **ET** la
> mémorabilité du run. Convergence : Backpack §4.4/§11.2, StS §1.4, Balatro §8.2/§8.5, Artifact
> (postmortems §4.4), Snap §7, retention §2.1 (high-roll), retention §2.4 (post-combat + **surprise de
> placement, round 4**), progression §2.4 (granularité de coût).

> **Granularité de coût** : §2.1-2.4 + §2.6-2.7 = RENDER pur, ~0.5-1 j chacun → **lot rapide**. §2.5 =
> coût réel (83 unités × effets) → **peut chevaucher P1**, ne bloque pas.

### 2.1 Surlignage des arêtes d'adjacence actives en build — **PRIORITÉ 1**

- **Quoi** : au drag-drop et au survol, surligner les arêtes du sigil actif qui produisent une
  aura/synergie. Lecture immédiate du « qui buffe qui ».
- **Source** : Backpack surligne ses slots ★ en temps réel = item UI #1 manquant (backpack §4.4/§13).
- **Chiffre** : 0 mécanique. RENDER (`arena_draw`/`build.lua`). Zéro invariant.

### 2.2 Carte de risque visuelle (exposition + arêtes) — **PRIORITÉ 1** *(tue le « score estimé »)*

- **Quoi** : sur le plateau en build — (a) **gradient par slot** : rouge = colonne front (`depth=0`,
  ciblée en 1er) → bleu = arrière protégé, selon le sigil ; (b) **nombre d'arêtes actives** par slot
  occupé. Mise à jour au swap `[s]`.
- **Source** : SBB rend front/back lisible par affordance (postmortems §3.2.A/O4) ; **PAS de DPS
  estimé** (trompeur en système asymétrique ; LocalThunk cache le score pré-main exprès — GMTK 2024).
- **Chiffre** : 0 mécanique. Résout-en-le-rendant-visible la dette « profils d'exposition non réglés »
  (00-state §7.1 ; le *réglage* reste P3). Utilise les arêtes de `shapes.lua`. RENDER.

### 2.3 Écran post-combat « pourquoi » — **PRIORITÉ 1 (co-priorité, +enrichi ranked round 4)**

- **Quoi** : après chaque combat (surtout défaite), synthèse depuis le **bus** (`bus.lua`, JSONL) : 1re
  unité morte + cause (exposée front / aggro faible / pas de taunt), affliction adverse dominante,
  relique adverse décisive si capturée.
- **Enrichissement ranked (round 4, ranked §2.4 → §6.x)** : **si le combat est ranked ET contre un
  ghost humain**, ajouter les **métadonnées du snapshot adverse** (famille dominante = compter
  `dot_family` sur `units[]` ; sigil = `shape`) — **lues directement du snapshot** (`{shape, units}`
  déjà encodés ; **dépend de P0.5** pour `dot_family`). C'est la **vraie asymétrie ranked/unranked** :
  le ghost de ton tier est **informatif sur la méta de ton niveau**. Relique adverse = « — » en v1
  (non capturée — 00-state §5). **Garde-fou de spoil** : métadonnées affichées **après** la résolution
  uniquement (jamais avant).
- **SIGNAL DE DISTRIBUTION DU POOL — attribution correcte (NOUVEAU round 8, ranked §2.2/§3.4, P2 RENDER ~1 h)** :
  le pool FIFO biaise vers les familles à win-rate élevé (Backpack Battles, steam mai 2026) → un joueur **choc**
  qui perd des LP contre 7 builds poison d'affilée **ne voit pas son skill testé, il voit la distribution du
  pool**. → après le « pourquoi » ranked, ajouter « **TU AS AFFRONTÉ [N] INVOCATIONS : [K BRÛLEURS / M SAIGNEURS
  / …]** » (lu de `dot_family` sur les snapshots servis ce run, IO hors SIM). **Ce n'est PAS un accusé de biais —
  c'est rendre VISIBLE la distribution** pour que le joueur attribue correctement : « 7 poison → le pool est
  poison-lourd ce tier » vs « 2 choc + 3 poison + 2 burn → mon build a un problème générique » (grimdark : « le
  Puits révèle ce qu'il t'a envoyé »). **Zone sans test** → comptage des familles adverses correct sur golden run.
- **Pourquoi co-priorité (retention §2.4)** : la carte de risque (§2.2) est **prospective** ; le
  post-combat est **rétrospectif** (combats **perdus**). Pour la zone 0-5 victoires (la plus à risque
  de churn), convertir la défaite en compréhension actionnable est **aussi urgent** que célébrer les
  victoires.
- **Source** : anti-pattern Artifact (postmortems §4.4) ; Jesper Juul (« Fear of Failing ») ;
  Entalto/Grid Sage 2025 (« arbitrary failure kills retention »). **Le déterminisme garantit
  l'exactitude** (invariants #1/#5).
- **LIEN STREAK-LOSS (NOUVEAU round 5, progression §2.2/§3.2)** : si le joueur est en **loss-streak ≥2**,
  ajouter une ligne grimdark **qui pointe une DÉCISION, pas un chiffre d'or** — « LE PUITS VERSE SON OR DANS
  TA COUPE — ton architecture de mort mérite d'être repensée » + le **slot le plus exposé** (front) **avec le
  moins d'arêtes actives**. **Pourquoi** : asymétrie psychologique sourcée (Smashing Magazine 2026 ;
  Kahneman-Tversky : la perte pèse ~2,3×) — l'or de streak arrive **trop tard dans le cycle de correction**
  (le build est mal orienté, pas sous-financé) → sans direction, l'or **renforce** un build inadapté. **Coût
  ~0** : lecture de `state.streaks` (hors SIM) + bus, deux signaux déjà planifiés liés. RENDER, 0 invariant.
- **NEAR-MISS COMME HYPOTHÈSE TESTABLE + HINT OPT-IN (NOUVEAU round 10, rétention §2.4 + ranked §2.3, Grid Sage
  2025 + stat.berkeley near-miss type 1/2)** : le near-miss async est de **TYPE 1** (sous agence rétrospective —
  AMPLIFIÉ par le déterminisme : même ghost + placement différent → résultat différent, impossible en RNG pur).
  MAIS le joueur ne le perçoit comme tel que si le post-combat montre la **CAUSALITÉ**, pas seulement le
  diagnostic. Le §2.3 actuel est diagnostique (« exposé front ») mais non prescriptif. Reformuler en hypothèse
  (0 moteur supplémentaire — lit l'event-log JSONL déjà structuré + famille dominante du snapshot servi + table
  statique anti-fam dans `units.lua`) :
  ```
  (a) NEAR-MISS COMME HYPOTHÈSE (si victoires >= WIN_TARGET-2 ET défaite au round N>5) :
    "[UNITÉ] A CÉDÉ AU ROUND N — FAMILLE DOMINANTE : [FAM] — ESSAIE [UNITÉ_ANTI_FAM] ([sa mécanique en 3 mots])"
    Logique RENDER : unité morte en dernier + famille la plus représentée dans les stacks DoT à la mort (event-log)
      + 1 unité anti-fam (table statique units.lua, ex. tank si mort par burn direct, regen si poison DoT lent).
    CONTRAINTE : JAMAIS prescrire une unité ABSENTE du pool boutique actuel (sinon frustration) → suggestion de
      la famille adverse OU type "shield" si famille non reconnue. Grimdark : "Le Puits révèle sa faille."
  (b) HINT OPT-IN (settings.near_miss_hint, OFF par défaut ; runs 1-3 OU loss-streak >= 2) :
    ligne prescriptive "un taunt en avant-gauche aurait absorbé l'attaque initiale" (si 1ère mort front ET
    aggro<15 ET aucun taunt même colonne → inférer). Respecte l'autonomie des experts (Grid Sage 2025 : les
    mastery seekers rejettent les hints). ~30 min RENDER. Ne déclenche PAS sur runs 4+ (le joueur infère seul).
  ```
  Zone sans test → ne crash pas si event-log vide (combat non démarré). Source : rétention §2.4 ; ranked §2.3 ;
  gridsagegames.com 2025 ; stat.berkeley.edu/near_miss (type 1 sous agence vs type 2 sans agence) ; armchairarcade
  2026 (Balatro : « each run teaches something new »).
- **Garde-fou** : RENDER + lecture de log/snapshot/`state.streaks`, **n'écrit pas dans le snapshot**. **Zone
  sans test** → **ajouter un test** que la synthèse pointe la bonne 1re mort + les bonnes métadonnées
  adverses sur un golden connu.

### 2.4 « MOMENT DU RUN » — high-roll nommé, ancré à l'UNITÉ-SOURCE + PLACEMENT — **PRIORITÉ 1 (ENRICHI round 4)**

- **Quoi** : au post-combat, lire le **bus JSONL** pour identifier la **chaîne d'événements la plus
  longue** (`A tue B → on_death propage burn → burn tue C → …`) et l'afficher en **nommant l'unité du
  build du joueur** qui l'a déclenchée (lue du `source` du 1er événement de la chaîne — le bus encode
  `{source, cell.x, cell.y, cause, target, tick}`) : **« MOMENT DU RUN — TA [NOM_UNITÉ] A CONSUMÉ 5
  ENNEMIS EN CHAÎNE »** + flavor grimdark.
- **ENRICHISSEMENT PLACEMENT (round 4, retention §1.1, Déclos 2025)** : si l'unité-source est adjacente
  à une autre unité du build **via une arête du sigil actif** (vérifier `shapes[shape].edges`), le
  signal devient **« TA [NOM_UNITÉ] PLACÉE EN VOISIN DE [NOM_AUTRE] A CONSUMÉ 5 ENNEMIS EN CHAÎNE »**.
  Le placement = **décision non-triviale** → la fierté de construction est plus forte (Déclos 2025 :
  « secondary player » qui a *décidé des règles* ; Yonkers 2025 : « pride — seeing a strategy succeed
  without intervention »). **+1 champ lu du bus, coût 0.**
- **SEUIL DE CHAÎNE (round 4, retention §2.1)** : remplacer « ≥ médiane des cascades sur les **250
  seeds FIXES** » par **P75 sur 1000 seeds ALÉATOIRES** (`tools/sim.lua --chain-distribution --n 1000
  --random-seeds`). Raison : la sim est déterministe → la médiane des 250 seeds fixes est un
  **échantillon biaisé** (si les seeds penchent tank-vs-tank, le seuil est trop permissif → le Moment
  se déclenche sur des cascades **ordinaires** → **réduit l'agence**, Kao et al. 2024 CHI). Cible : le
  signal se déclenche sur **~25 % des combats** (Hopson 2001 : VRR résiste à l'extinction à ~20-30 %).
  À mesurer **avant v0.9** (Q1).
- **Variante (Q4)** : si la chaîne max est **côté ennemi** (notre défaite par cascade adverse), tonalité
  inversée : « LE PUITS VOUS A CONSUMÉ — 5 DE VOS UNITÉS TOMBÉES EN CASCADE ». Articuler avec le
  Dernier Souffle (§6.10), le post-combat (§2.3) et la surprise de placement (§2.7).
- **PRÉCONDITION DE CODAGE — valider la distribution temporelle VRR (NOUVEAU round 5, retention §2.2/Prop-B)** :
  la « complémentarité temporelle » Moment du Run (mid-late) vs Surprise de Placement (early) est une
  **hypothèse non mesurée**. Sous-hypothèses fragiles : un plateau de 3-4 unités a **peu d'arêtes activables**
  → la surprise peut être plus fréquente en **mid** ; un build focalisé peut chaîner dès le round 2. **Si les
  deux se déclenchent au même combat (round 4-6), ils se cannibalisent** (Kao et al. 2024 CHI : l'amplification
  excessive *réduit* l'agence). **Mesure (~0.5 h, AVANT de coder les deux signaux)** : `chain_len` et
  `edge_missed` **par round** + chevauchement `P(chain≥P75 ET edge_missed≥1 | round_i)`. **Si chevauchement
  > 0.30 → règle de priorité Moment du Run > Surprise de Placement** (la surprise passe en silencieux ce
  combat). Articulé avec §2.7.
- **ACTIVATION SÉQUENTIELLE — le high-roll est un problème de FEEDBACK, pas de probabilité (NOUVEAU round 10,
  rétention §2.1/Prop-A, Blake Crosley + CHI 2025 Kao n=1699)** : la roadmap dose les VRR en FRÉQUENCE (enveloppe
  pondérée hédonique §2.9) sans spécifier que les événements du bus sont rendus **SÉQUENTIELLEMENT**. Or Balatro
  — la masterclass de référence — produit le high-roll par ce mécanisme : chaque élément s'active séquentiellement
  avec callout visuel (« 30 ms par Joker → attribution causale par l'animation, remplace un tutoriel de 10 pages
  par 300 ms »). CHI 2025 (n=1699) : l'amplification (volume) SANS success-dependency ne produit PAS l'engagement
  équivalent. **Sans cette spec, l'impl par défaut = VFX simultanés (bruit) → le high-roll est invisible même si
  les effets sont là.** **Distinct de `combat_effect_legibility`** (densité d'événements) — c'est la TEMPORALITÉ
  D'AFFICHAGE (séquentiel vs simultané), indépendante de la densité (préconditions complémentaires).
  ```
  SPEC SÉQUENTIELLE DU MOMENT DU RUN (RENDER ~2-3 h en impl, 0 SIM, lit le bus JSONL déjà câblé) :
    Chaîne affichée nœud par nœud, délai 80-120ms/nœud, accélération Balatro sur les 5+ derniers (100→60→40ms)
    pour préserver la cascade (12 nœuds × 100ms = 1200ms trop long → perd l'effet).
    Chaque nœud : [ICONE_FAMILLE] [SOURCE] → [ACTION] → [CIBLE]. Total : [N morts en chaîne].
    CONNEXION §2.3 : si chaîne ≥ 3 nœuds, le Moment du Run EST la synthèse post-combat (l'un absorbe l'autre).
    Priorité étendue : Moment du Run (seq. ≥3) > §2.10 (relief survie) > post-mortem diagnostic.
  ```
  Q_R10_1 (cadence exacte) → playtest, non sim. **§2.9 (enveloppe VRR) ASSUME cet affichage** (sinon poids
  hédoniques surestimés, rétention §5.1). Source : rétention §2.1 ; blakecrosley.com/balatro ; CHI 2025 (Kao).
- **Garde-fou** : RENDER + lecture du bus, hors SIM. **Le déterminisme garantit l'exactitude**
  (invariants #1/#5). **Test à ajouter** : chaîne max + source + adjacence correctement identifiées
  sur le golden (la chaîne la plus longue identifiée par `tools/eventlog.lua` déjà câblé).

### 2.4bis « [NOM DE BUILD] » — IDENTITÉ DE RUN nommée, précède le Moment du Run — **PRIORITÉ 1 (NOUVEAU round 7, retention §2.2/Prop-A)**

- **Trou mécaniste que 6-8 rounds ont manqué (retention §2.2)** : le Moment du Run (§2.4) nomme une
  **UNITÉ** mais **jamais le BUILD**. « Ta torche a brûlé 5 ennemis » = **attribution d'événement** ;
  « TU ÉTAIS UN BRÛLEUR DU PUITS — 5 consumés » = **identité de run**. La fierté de construction (Déclos
  2025, British J. Aesthetics) exige que le joueur **s'identifie à ses décisions de build** — pas à un fait
  isolé. **Source** : DEV Community 2026 (dev.to/yurukusa, implémentation concrète roguelite) — « Stats are
  data. Names are identity. [...] The name converts a technical state into a social object. »
- **Quoi (RENDER pur, ~1 h, 0 SIM, 0 invariant)** : au post-combat, **AVANT le Moment du Run**, lire `shape`
  + les `dot_family` des unités du build (comptage par famille, **dépend de P0.5**) + présence d'unités
  spéciales (`aggro ≥ 40` tank, `trigger="combat_start"` aura) pour générer un **nom de build grimdark** :
  ```
  - ≥4 dot_family=="burn"   → "BRÛLEUR DU PUITS"
  - ≥4 dot_family=="poison" → "DISTILLATEUR DU PUITS"
  - ≥4 dot_family=="bleed"  → "SANG-FROID DU PUITS"
  - ≥4 dot_family=="rot"    → "NÉCROLOGUE DU PUITS"
  - ≥4 dot_family=="choc"   → "CONDENSATEUR DU PUITS"
  - ≥2 + ≥2 (2 familles)    → "ALCHIMISTE DU PUITS"
  - sigil=="croix" + tank taunt → "CROISÉ MAUDIT" (override)
  - sigil=="anneau" + aura  → "CERCLE MAUDIT" (override)
  - sinon                   → "ARPENTEUR DU PUITS" (fallback)
  ```
  Le Moment du Run devient « **[BRÛLEUR DU PUITS]** — TA [ASH_MOTH] A CONSUMÉ 5 ENNEMIS EN CHAÎNE » →
  l'unité-source s'ancre **dans** l'identité, pas en dehors.
- **SEUIL PROGRESSIF — #EE adopté (NOUVEAU round 8, synergies §2.3/P3)** : le seuil fixe `≥4` est **impossible
  à 3 slots** (START_SLOTS=3) ; le palier-4 P1 ne s'active qu'au round 5+ → « ARPENTEUR DU PUITS » (fallback)
  pendant les **rounds 1-4** = **exactement la zone 0-5 wins (churn maximal, §2.3)** = le signal manque son
  objectif quand il compte le plus. **Seuil progressif (RENDER, lit `state.wins`)** :
  ```
  slots 3-5 (early)  → nom si ≥2 même famille OU ≥2 familles → "[FAM] NAISSANT" / "ALCHIMISTE NAISSANT"
  slots 5-7 (mid)    → seuil=3 ; nom complet sans "NAISSANT"
  slots 7-9 (late)   → seuil=4 (palier P1 actif, nom = palier actif)
  ```
  **L'option « 2 familles → ALCHIMISTE dès l'early » aligne le signal d'identité avec l'incitation à
  diversifier** (synergie avec #FF §5 + resonance §3.6) : 1 burn + 1 bleed au round 2 → « ALCHIMISTE » = signal
  **positif** pour la diversification. **Coût RENDER nul supplémentaire.** Se simplifie en post-P1 (nom = palier
  actif, supprime l'ambiguïté 2+2).
  **+ FLAVOR D'INTERACTION au nom ALCHIMISTE (NOUVEAU round 9, synergies §1.4)** : si c'est une simple étiquette,
  l'effet identitaire est réduit (StS : les cartes qui « bridgent » 2 archétypes sont les plus mémorables). Le
  nom doit **nommer l'interaction** : « ALCHIMISTE NAISSANT — *ton venin brûle tes blessures* » (1 ligne flavor
  grimdark qui dit POURQUOI le build est nommé ainsi). Coût RENDER nul.
- **HIÉRARCHIE DU ONE-MORE-RUN S1 — near-miss PRIMAIRE, identité SECONDAIRE (NOUVEAU round 9, retention §2.3/
  Prop-C, doc)** : en S1 **sans communauté visible**, le **near-miss actionnable (§2.3)** est le driver PRIMAIRE
  du restart (« si j'avais placé X ici, j'aurais gagné » → restart = test d'hypothèse, Grid Sage 2025) ;
  l'**identité (§2.4bis)** est SECONDAIRE (amplifie l'engagement déjà déclenché, ancre l'attribution, réduit le
  churn — mais ne suffit pas SEULE à INITIER une session sans signal externe). **La dépendance est
  UNIDIRECTIONNELLE** : si §2.3 est faible (post-mortem incomplet), §2.4bis ne compense pas. En **S2+ avec
  communauté visible** (ranked/leaderboard), l'identité monte en PRIMAIRE (la comparaison sociale réactive le
  moteur d'identité). **Synthé NUANCE : §2.4bis n'est PAS déclassé** (driver secondaire valide + méta-progression
  via le mode statistique) — la note clarifie le MÉCANISME, ne change pas les priorités d'implémentation (les deux
  restent P0). Doc, 0 code. Source : Grid Sage Games 2025 (near-miss = driver primaire sans communauté).
- **Deux fonctions** : (1) **ancre le Moment du Run** ; (2) **rend le Grimoire II identifiable par
  archétype** (« DÉCOUVERTES DU BRÛLEUR : 7/11 » = goal-gradient sur identité nommée — **subsume** la vue
  Grimoire-par-archétype, retention §2.4 ; **+ couche de MAÎTRISE §6.7**). **Persistance — MODE STATISTIQUE,
  PAS LISTE (RAFFINÉ round 8, retention §2.2 + Q_R8_3)** : `grimoire.lua` stocke le nom **par run** → le signal
  d'identité durable affiche le **mode statistique** : « **TU ES PRINCIPALEMENT UN BRÛLEUR [4/10 runs]** » (dev.to
  /yurukusa relu : « what creates retention is *recognition* — the game must REFLECT the pattern back, not just
  list it » → la roadmap n'implémentait que la 1re moitié). Le **mode** (sur les 10 derniers) évite l'instabilité
  « BRÛLEUR/ALCHIMISTE/BRÛLEUR » sur sessions courtes. **Daily EXCLU de la persistance d'identité (§5.2 retention)** :
  un Daily à contrainte imposée force un nom hors archétype habituel → **ne pas persister les noms des Daily**
  (convention StS : Daily n'alimente pas l'Ascension).
- **Garde-fou DA** : grimdark **seul** (titres sombres courts, jamais félicitation : « DISTILLATEUR DU
  PUITS » oppressif ≠ « GREAT POISON BUILD »). **Précondition `dot_family` (P0.5)** → codable en // dès P0.5.
  **Se simplifie si P1 (types) est adopté** (nom = palier de type actif au résultat, supprime l'ambiguïté 2+2
  — Q_R7_2). **Zone sans test** → test de dérivation du nom sur golden (composition connue → nom attendu).
- **Source** : retention §2.2/Prop-A ; dev.to/yurukusa 2026 ; Déclos 2025 ; ROADMAP §2.4 (Moment du Run) + §6.7.

### 2.5 Tooltip de cotes de boutique + compteur de copies — **PRIORITÉ 2**

- **Quoi** : afficher cotes par rang du tier courant (00-state §4.3) + **nombre de copies déjà
  possédées** d'une unité. **Prépare** le pity-signal (§7.3).
- **Source** : The Pit a des cotes plus fines que SAP mais « si l'UI ne les montre pas, le joueur subit
  l'aléatoire » (SAP §10.1) ; HS:BG : coût/cote visible amplifie la décision (§2.2).

### 2.5bis BARRE XP de boutique visible intra-round — **PRIORITÉ 1 co-priorité (NOUVEAU round 7, progression §2.3)**

- **Lacune (progression §2.3)** : la décision **« monter (BUY_XP) vs reroller vs acheter »** est la décision
  éco **CENTRALE**, prise en temps réel pendant la boutique. Si le joueur ne voit pas (a) son XP vs seuil du
  prochain tier, (b) l'XP passive de ce round, (c) ce que +4 XP rapporte → il **ne peut pas évaluer le coût
  d'opportunité**. **TFT affiche la barre XP en permanence** (lolchess.gg/guide/exp : « L4=10 XP, L5=20 XP »
  visibles) ; HS:BG affiche le coût d'upgrade à côté de l'or.
- **Pourquoi PRIORITÉ 1 et URGENT AVANT P3** : les sims P3 supposent un **joueur informé qui décide**. Sans
  ce signal, on calibre pour un **joueur aveugle** et on livre un jeu aveugle — **plus** décisionnel que le
  tooltip de cotes §2.5 (qui est « lisibilité du pool » ; celle-ci est « la décision éco principale »).
- **Quoi (RENDER pur, ~1 h, 0 SIM, 0 invariant)** : dans `build.lua`, afficher « **XP : {shopXp}/{xpToNext()}
  → Tier {shopTier+1}** » ; au survol de BUY_XP, preview « **+4 XP → {shopXp+4}/{xpToNext()}** » ; si
  `shopTier==MAX_TIER` → « Tier max ». Lit `state.shopXp`/`shopTier`/`state:xpToNext()` (déjà exportés).
- **SIGNAL PASSIVE CONTEXTUALISÉ — pas « +1 XP » nu (NOUVEAU round 8, progression §2.4/§3.4)** : « +1 XP passif »
  seul **risque une décision d'attente IRRATIONNELLE** (3 rounds de passive = 3 XP < 1 BUY_XP de 4 XP ; le joueur
  rationne son BUY_XP en pensant accumuler la passive — gamedeveloper.com 2013 : « help players organize
  trade-offs »). **Remplacer par une ligne CONTEXTUELLE** selon `delta = xpToNext() − shopXp` :
  ```
  delta == nil (Tier max) → rien
  delta <= 4              → "+1 XP passif → ou BUY_XP = Tier {shopTier+1} immédiat"
  delta  > 4              → "+1 XP passif ({delta} rounds OU {ceil(delta/4)} BUY_XP)"
  ```
  Montre le **coût d'opportunité** sans prescrire (langage grimdark/neutre, pas « tu dois »). RENDER ~0,5 h
  supplémentaire ; enrichit le signal, ne le remplace pas.
- **SIGNAL DE COÛT D'OPPORTUNITÉ DU SLOT-UNLOCK — SYMÉTRIQUE À LA BARRE XP (NOUVEAU round 9, progression §2.2)** :
  la roadmap contextualise le coût d'opportunité de BUY_XP mais **il n'existe AUCUN équivalent pour le
  slot-decline `+3 or`** — un joueur voit « ACCEPTER le slot | REFUSER (+3 or) » sans contexte : 3 or maintenant
  valent-ils un slot qui durera 8 rounds ? C'est une décision à **HORIZON DIFFÉRENT non affichée** → la sim P3
  mesurerait un comportement de joueur aveugle. La progression LA PLUS VISIBLE du jeu (la grille qui grandit) n'a
  aucun signal de coût d'opportunité. **CORRIGÉ round 10 (progression §2.2) — intégrer l'HORIZON DE RUN, pas le
  potentiel brut `(9 − slots)`** : `(9 − slots)` mesure le potentiel TOTAL restant, identique au round 2 et au
  round 7 — mais un slot au round 2 (8 rounds d'usage) ≠ un slot au round 7 (3 rounds). Un slot refusé tard est
  souvent un or inutile (le run finit avant de le dépenser). La valeur MARGINALE = combats restants × valeur
  d'une unité de plus. **Quoi (RENDER ~1 h, 0 SIM)** : ligne contextuelle sous l'offre de slot, grimdark et
  **sans prescription** (le mot « optimal » INTERDIT) :
  ```
  rounds_remaining_est = max(0, (WIN_TARGET − wins) + lives − 1)  -- borne haute, hors SIM (accessible build.lua)
  early (slots<5, horizon>5) → "Un slot = {rounds_remaining_est} combats à venir — ou {SLOT_DECLINE_GOLD} or maintenant"
  late (horizon<=5)          → "Refuser = {SLOT_DECLINE_GOLD} or ({ceil(SLOT_DECLINE_GOLD/BUY_XP_COST*BUY_XP_AMOUNT)} XP) — ~{horizon} combats"
  Flavor grimdark : "Le Puits t'offre l'espace — ou son prix. Il ne restera pas longtemps." (~N = approximation assumée)
  ```
  Précondition : `WIN_TARGET`/`START_LIVES` accessibles depuis `build.lua` (vérifier) + tableau §7.0 inclut
  l'intention de `SLOT_DECLINE_GOLD` (Q3 progression : point de parité exact avec achat rang-3 en T3 — voulu ?).
  Zone sans test → cas limites (`slots=9` = pas d'offre ; `wins=0/lives=5` ; `wins=9/lives=1`). Source :
  progression §2.2 ; gamedeveloper.com 2013 (coût d'opportunité = montrer l'horizon, pas seulement le prix).
- **Garde-fou** : hors SIM. **Zone sans test** → test headless que le rendu ne crash pas à `shopTier==MAX_TIER`
  (cas limite `xpToNext()=nil`, invariant #17) **+ label contextuel correct pour delta=1/4/8/nil** **+ label slot
  correct pour slots=3/9**. **Forme un « tableau de bord économique » cohérent avec §2.5.**
- **Source** : progression §2.2/§2.3/§2.4/§3.4 ; TFT barre XP (lolchess.gg/guide/exp ; mobalytics.gg) ; HS:BG coût
  d'upgrade visible ; gamedeveloper.com 2013 (coût d'opportunité, shadow values). **La passive 1/round (moitié de
  TFT) est RARE → la rendre visible ET contextualisée est d'autant plus justifié.**

### 2.6 Audit « ≤ 12 mots » des textes reliques/effets — **PRIORITÉ 3**

- **Quoi** : auditer `src/i18n/en.lua` pour que chaque effet/relique tienne en une ligne (cible **≤12
  mots** hors flavor). Coût réel (83 unités × effets + 21 reliques).
- **Source** : Snap/Ben Brode GDC 2023 « >8 mots = non lu » (marvel-snap §7.3) ; Balatro ≤4 lignes/≤20
  mots, « 1 règle modifiée » (§5.1/§8.4). Aligne décision #7. Couvert par `tests/i18n.lua`.

### 2.7 « SURPRISE DE PLACEMENT » — signal « arête révélée » post-défaite — **PRIORITÉ 2 (NOUVEAU round 4)**

- **Quoi (retention §2.4/Prop-D)** : 3e source de VRR, **propre au plateau-graphe 3×3**. Après chaque
  combat **PERDU** (jamais une victoire — évite le paternalisme), calculer (RENDER, lecture
  `shapes[shape].edges` + positions, déjà en mémoire) si **déplacer 1 unité** vers une case voisine
  activerait **≥1 arête de plus**. Si oui, signal grimdark **« LE [SIGIL] MURMURE — TU N'AS PAS
  ENTENDU »** + surlignage de la case optimale.
- **Pourquoi (Boyle et al. 2024, Nature Sci Rep)** : le near-miss **sous contrôle personnel** (goal
  gradient) génère un arousal **plus constructif** que le near-miss aléatoire. « Si j'avais placé mon
  carry en case 4, j'activais 2 arêtes de plus et je gagnais » = **déterminisme révélé par
  l'expérimentation** = agence maximale. **Orthogonal aux cascades DoT** → se déclenche même sans
  chaîne longue (utile en **early**, plateau peu peuplé = beaucoup d'arêtes manquées → temporellement
  complémentaire du Moment du Run, qui est mid-late).
- **Condition de déclenchement (retention §3.4)** : uniquement si le combat **n'a impliqué que le
  front** (`depth < 2`) — sinon le problème est d'**exposition**, pas de placement.
- **Désactivation = déplacement INTENTIONNEL, pas quantité d'arêtes (RAFFINÉ round 6, retention §2.4/Prop-D)** :
  le critère v5 (`hasLearnedAdjacency` ≈ ≥5 arêtes sur ≥3 combats) est une **mesure de QUANTITÉ, pas
  d'APPRENTISSAGE** (Q_R5_1) — un joueur passif qui active 5 arêtes **par accident** (plateau de départ
  adjacent) verra la Surprise disparaître **avant d'avoir appris**. **Digital Thriving Playbook (SDT
  autonomie)** : « autonomy satisfaction requires that the player perceives their choices as **causal** ».
  → **`grimoire:hasMovedForAdjacency()`** : vrai quand le joueur a **déplacé une unité (`cause="player_move"`
  dans le bus JSONL) qui a activé une arête nouvelle** ≥3 fois (il perçoit que **SA décision** a activé
  l'arête). **+ CAP DUR ~10 sessions** quel que soit le critère (sinon le profil **purement passif** — qui
  ne déplace jamais — voit la Surprise devenir du **bruit après 20 runs** ; litige #Y retention fusionné).
  **~1 h RENDER, lit les drags du bus, 0 SIM, 0 invariant.**
- **Garde-fou DA (retention Q_R4_4)** : ne **pas** exposer le mot « arête » crûment (casse le
  cryptique) → langage de **sigil**. **Zone sans test** → test que le calcul retourne le bon slot sur
  le golden (carré, positions fixes) **+ que la désactivation suit un drag intentionnel** (pas un
  placement passif). RENDER, 0 invariant.
- **GATE `player_move` BLOQUANT AVANT L'IMPLÉMENTATION (NOUVEAU round 8, retention §5.1)** : le critère
  `grimoire:hasMovedForAdjacency()` **dépend de `{cause="player_move"}` émis par `build.lua` à chaque drag**.
  Si `player_move` n'est **pas émis systématiquement**, le critère ne se déclenche jamais → la Surprise **ne se
  désactive jamais** → bruit après 20 runs (00-state §8 : zone sans test). **Ajouter une assertion headless
  (drag → vérifier que le bus reçoit `{cause="player_move"}`) AVANT de coder §2.7.** 0 invariant (test headless,
  pas golden).

### 2.8 « LE PUITS GARDE MÉMOIRE DE TON BUILD » — signal de TRACE D'IMPACT (session initiation) — **PRIORITÉ 1 (RÉ-ANCRÉ round 6)**

- **Quoi (retention §2.1/Prop-A)** : au **lancement** (écran menu), lire depuis `snapstore.lua` le nombre de
  combats résolus **contre le ghost local du joueur** depuis sa dernière session. Si N ≥ 1 → message grimdark
  **« LE PUITS GARDE MÉMOIRE DE TON BUILD — [N] ÂME[S] Y ONT AFFRONTÉ SON ÉCHO DEPUIS TON DÉPART »**
  (cliquable → résumé des combats depuis le bus JSONL local). Si N = 0 → **rien** (pas de message « 0 combat »).
  « **âme** » pour l'adversaire (et non « joueur ») **renforce l'asymétrie anonyme**.
- **ANCRAGE CORRIGÉ — trace d'impact, PAS SDT-relatedness (RÉ-ANCRÉ round 6, retention §2.1/Prop-A)** : v5
  justifiait ce signal par la **relatedness SDT** (Möller et al. 2024). **C'est un fondement empiriquement
  fragile** : Ballou et al. 2024 (ACM TOCHI, « Unfulfilled Promises », **259 papiers**, arxiv.org/html/
  2405.12639) — « all of the above posited causal relations remain empirically untested » ; la relatedness est
  la **moins documentée** des 3 besoins. Pire, le **même papier Möller** dit « relatedness frequently ignored »
  = **constat d'absence d'étude, pas validation** → v5 inversait la charge de preuve. Et un **ghost figé qu'un
  inconnu a affronté** sans connaissance mutuelle est **l'analogue le plus distant de la relatedness** (connexion
  sociale) — **c'est de la TRACE, pas de la connexion**. → **mécanisme réel = amorce comportementale par trace
  d'impact persistante** : Fogg Behavior Model (prompt externe + motivation de l'impact = initiation de
  session) ; Countly 2026 (les 90 s post-relance = moment critique, le prompt doit concerner **l'identité/
  l'impact persistant**, pas un événement social). « Mon action passée vit encore → agir à nouveau » — **n'exige
  PAS que le joueur se sente connecté** aux autres, juste que son build ait **laissé une trace**.
- **Conséquence UX (décisive)** : **NE PAS afficher le nom des joueurs** qui ont affronté le ghost (si la valeur
  est la trace, l'**anonymat grimdark est PRÉFÉRABLE** — montrer des noms réorienterait vers une relatedness
  fragile et casserait la DA). C'est exactement le genre de mauvaise décision dérivée qu'un ancrage faux aurait
  induite.
- **Compteur technique** : `snapstore.lua` ajoute `battles_since_last_session` (incrémenté quand le ghost
  local est servi, remis à 0 au lancement ; `love.filesystem`, IO **hors SIM**, déjà prévu).
- **Garde-fou piliers** : **async-safe** (ghost figé, pas de live), **déterministe** (compteur local, pas de
  RNG), **DA grimdark** (formulation du Puits, pas de félicitation). **0 invariant. Zone sans test** → test que
  le compteur s'incrémente correctement sur le golden.
- **Litige #Z — RECOMMANDÉ CLORE round 7 → IA FORMULATION DISTINCTE (2 lentilles convergent : ranked §3.3 +
  retention Prop-D)** : en **cold-start** (pool vide), N=0 silencieux supprime le moteur de session-initiation
  **exactement quand il est le plus critique** (au lancement, **tous** les joueurs sont en cold-start ;
  Countly 2026 : 90 s post-relance). **Décision recommandée** : **déclencher sur les IA avec une formulation
  DISTINCTE** — « LE PUITS A SOUMIS TON BUILD AUX ÉPREUVES DU VIDE — [N] INVOCATION[S] L'ONT ÉPROUVÉ », avec
  **fallback silencieux si N=0 même pour les IA**. Préserve : (1) **honnêteté** (les IA ne sont **pas**
  présentées comme humaines) ; (2) **trace d'impact réelle** (N combats réellement simulés) ; (3) **cohérence
  avec la proposition de valeur ranked S1 = Invocations** (§6.5). Condition i18n : `if N>0 AND battles_are_ai
  THEN "INVOCATIONS" ELSE "ÂMES"`. **Décision DA FINALE à l'user** (le mot « ÉPREUVES DU VIDE » casse-t-il le
  cryptique ou l'enrichit ? si « casse » → silence accepté). **Zone sans test** → distinction IA vs humain sur
  un golden de store.
- **#Z = GATE BLOQUANT DE §2.8 (PROMU round 8, retention §2.4/Prop-D)** : « recommandé clos » au round 7 mais
  **reste ouvert** → si l'user ne tranche pas, §2.8 entre en P0 avec le **comportement par défaut (silencieux si
  N=0)** qui, **en S1 local sans backend**, est silencieux pour **la majorité des joueurs** (le pool FIFO n'est
  affronté que par les propres combats du joueur ; le cold-start IA utilise `aiComp`, pas les ghosts locaux →
  **N=0 systématiquement** sauf formulation IA distincte). **C'est un GATE de priorisation, pas un changement de
  design** : **l'implémentation de §2.8 est BLOQUÉE par la décision DA de #Z.** Option 1 (silencieux si N=0 → §2.8
  ne marche qu'en backend P4, **accepté explicitement**) vs Option 2 (IA formulation distincte → fonctionne dès
  S1, **recommandée**, cohérente ranked S1 = Invocations §6.5). **Décision consciente requise, pas par défaut.**
- **Source** : retention §2.1/Prop-A + Prop-D + §2.4 ; ranked §3.3 ; Ballou 2024 ACM TOCHI ; Möller et al. 2024 ;
  Fogg BM ; Countly 2026 ; SAP §3.1.

### 2.9 « LE PUITS RÉSISTE À TA FAIBLESSE » — VRR de BOUTIQUE (le moteur du one-more-run) — **PRIORITÉ 1 (NOUVEAU round 6)**

- **Lacune structurelle que 5 rounds ont manquée (retention §2.3 + Prop-B)** : toute la couche VRR de la
  roadmap (le **Moment du Run**, §2.4) est de la **narration POST-COMBAT** — le joueur **LIT** le résumé d'un
  combat qu'il **n'a pas joué** (il est **spectateur**). La littérature VRR (PSU.com 2025) distingue **VRR sous
  agence** (chaque geste = une décision → l'incertitude est « au bout du geste » = le one-more-run de Balatro)
  de **VRR narré** (« c'était bien de lire ça »). **Ils ne sont pas équivalents pour la motivation de RELANCE.**
  Dans **SAP (notre référence)**, le VRR est dans la **BOUTIQUE**, pas le combat. **Preuve sourcée**
  (Switchblade Gaming 2026, switchbladegaming.com/strategy-games/best-auto-battler-games-2026) : facteur **#1**
  de rétention autobattler = « **the build phase unpredictability — what will the shop offer me?** » — les
  **jeux morts** (Dota Underlords, Storybook Brawl) ont rendu le **combat** spectaculaire ; les **jeux vivants**
  (SAP, TFT) ont rendu la **boutique** imprévisible.
- **Quoi (RENDER pur, ~2 h, 0 SIM, 0 invariant)** : dans `build.lua`, quand un **reroll** produit une offre
  contenant une unité de **rang ≥ `shopTier`** OU une unité dont le `dot_family` (P0.5) correspond à **≥ 60 %
  du build courant**, déclencher un signal **discret** — pulsation légère de l'offre concernée + texte grimdark.
  Lire `shopTier` depuis `state` (hors SIM) ; comparer `dot_family` de l'offre vs plateau.
- **Garde-fous DA (Q_R6_4, décisifs)** : le signal est **DISCRET** (pulsation, pas fanfare) ; **JAMAIS actif sur
  le 1er shop d'un round** (sinon le joueur apprend à attendre le signal avant d'acheter) ; **formulé comme une
  RÉSISTANCE/menace, pas une aide** — « **LE PUITS RÉSISTE À TA FAIBLESSE — [UNITÉ] S'IMPOSE** » (le Puits ne te
  **guide** pas vers les bonnes choses, il te **force la main** → cohérent avec le grimdark oppressif/cryptique).
- **Complémentarité PROUVÉE, pas cannibalisation** : VRR boutique = **BUILD, agence directe, décision active** ;
  Moment du Run = **post-COMBAT, narration** → temporellement et psychologiquement distincts (circuits cérébraux
  différents, PSU.com 2025). **On AJOUTE l'axe « relancer », on ne retire pas l'axe « rester »** (le Moment du
  Run reste la mémorabilité mid-session — §3.2 round-06.md). **Entre dans la même validation de chevauchement
  que les 2 autres signaux VRR** (§2.4 : mesurer boutique × placement × cascade par round avant de coder).
- **Seuil [PH] (litige #AA, ENRICHI round 7)** : « rang ≥ `shopTier` OU ≥ 60 % `dot_family` match » → à
  calibrer en sim sur N=100 builds, **cible ~30 % des rerolls** déclenchent (Hopson 2001 : 20-30 % optimal).
  **+ critère de PRÉVISIBILITÉ DE RÈGLE (NOUVEAU round 7, retention §2.1)** : Hopson 2001 vaut pour le **VRR
  pur** (règle invisible) ; notre signal est **semi-prévisible** (règle explicite) → un joueur qui la comprend
  **anticipe** le signal au lieu d'être surpris → il **dégénère en info utile** après ~10 runs (PSU.com 2025 :
  une règle visible comprise « drops the excitement »). **Calibrer la PRÉVISIBILITÉ** (Q_R7_1 : à quel run le
  joueur devine la règle → playtest), pas seulement le taux. **Zone sans test** → test que le signal se
  déclenche pour la bonne unité sur un golden de build connu.
- **SPEC PHASE 2 (NOUVEAU round 7, retention §2.1/Prop-C — doc, 0 code avant P0)** : documenter **AVANT de
  coder** que le signal a 2 phases (sinon Phase 1 est gravée comme définitive) :
  - **Phase 1 (runs 1-10)** : règle actuelle. Surprenante pour un nouveau. **Acceptable.**
  - **Phase 2 (runs 10+)** : ajouter un **3e facteur moins modélisable** — **distance à la 3e copie d'une
    unité du build** (`≥60 % dot_family` ET `shopTier` OU à 1 copie d'un triple) → plus rare, contextuellement
    fort, difficile à anticiper. `SHOP_SIZE=5` + pool LOCAL → calculable en headless. **Implémentation Phase 2
    = P3** ; l'intention Phase 2 doit exister **maintenant**.
- **ENVELOPPE DE FRÉQUENCE VRR (NOUVEAU round 7, retention §2.3/Prop-B — doc, 0 code)** : la précondition de
  chevauchement (§2.4) est au niveau du **COMBAT** ; il manque la **SATURATION au niveau du RUN ENTIER**. Sur
  10-15 rounds on cumule ~17-28 signaux VRR (9-14 boutique + 3-4 Moment du Run + 2-3 surprise placement + 4-5
  offres reliques + 1 trace d'impact). Kao et al. 2024 (CHI) : l'amplification **excessive réduit l'agence**.
  → **tableau d'intention de fréquence VRR, cible ≤20 signaux/run** (hypothèse de travail à valider en
  playtest ; même logique que le tableau d'intention éco §7.0). Si les sims dépassent → **prioriser le VRR
  boutique** (circuit agence directe) sur les autres en cas de budget saturé.
- **PONDÉRATION HÉDONIQUE DU TABLEAU (NOUVEAU round 8, retention §3.1 — doc, 0 code)** : le compteur ≤20 brut
  **agrège des signaux de poids émotionnel très différents** (une offre de relique = identité du run, high-stakes,
  décision 1-parmi-3 ≠ un signal VRR boutique low-stakes). Couper sans distinguer = borne arbitraire (Game
  Developer : « habituation by reward TYPE, not frequency »). **Ajouter une colonne POIDS HÉDONIQUE** :
  | Source VRR | Fréq/run | Poids | Pondérée |
  |---|---|---|---|
  | Boutique (reroll) | ~9-14 | 1 | 9-14 |
  | Moment du Run | ~3-4 | 3 | 9-12 |
  | Surprise de Placement | ~2-3 | 2 | 4-6 |
  | Offre de Relique | ~4-5 | 4 | 16-20 |
  | Trace d'impact | 1 | 2 | 2 |
  | **CONTRE LA MORT** (§2.10) | ~2-3 | 2 | 4-6 |
  **Total pondéré ~44-60.** Borne devient « **≤50-60 unités pondérées/run** » (plus précis que « ≤20 bruts »).
  Si dépassement → couper en priorité les signaux **poids=1** (boutique, les plus fréquents et les moins intenses).
  **Enrichit #AA.**
- **Source** : retention §2.3/Prop-B + §2.1 + §3.1 ; Switchblade Gaming 2026 ; PSU.com 2025 ; Kao et al. 2024 CHI ;
  Game Developer (Reward Schedules, habituation par type) ; SAP ; TFT.

### 2.10 « [NOM] A TENU — TA SYNERGIE L'A MAINTENU EN VIE » — signal VRR de RELIEF (contraste hédonique, attribution AGENCE) — **PRIORITÉ 1 (NOUVEAU round 8 ; REFORMULÉ + 2 préconditions round 9, retention §2.1/§2.4)**

> **CORRECTIONS ROUND 9 (retention §2.1/§2.4, #JJ) — 2 préconditions + reformulation d'attribution :**
> 1. **REFORMULATION (#JJ, attribution à l'AGENCE, 0 coût)** : le format v8 « LE PUITS A FAILLI TE CONSUMER »
>    attribue la survie au **Puits** (acteur externe) → réduit l'agence perçue. Le plaisir d'ordeal vient de la
>    **reconstruction narrative interne** (arXiv 2603.26677 : « j'ai placé le tank → il a absorbé le burst »),
>    pas de la félicitation. **Nouveau format** : « **[NOM_UNITÉ] A TENU — [TA SYNERGIE A×B / TON PLACEMENT]
>    L'A MAINTENU EN VIE** » + 1 ligne atmosphérique « **LE PUITS N'OBTIENT PAS CE QU'IL VEUT** ». Si l'unité
>    survivante est adjacente via une arête active du sigil → « TA SYNERGIE [A]×[B] » ; si carry isolé → « SON
>    ISOLATION L'A PROTÉGÉ DES AFFLICTIONS ». Le Puits reste l'antagoniste, le **JOUEUR reste l'agent**.
> 2. **PRÉCONDITION CONFIG-SURVIVAL (BLOQUE le code, ~15 lignes sim)** : le seuil « ≥75 % PV perdus » est un
>    placeholder NON calibré PAR RÔLE. Avec `HP_MULT=2`, un **tank** à 25 % PV est fréquent (le taunt fait son
>    travail = banal) ; un **carry** à 25 % PV est rarissime (jamais déclenché) → le seuil brut inverse la
>    signification par rôle. **Mesurer `P(hp_ratio<0.25 | victoire | role)`** (role dérivé de aggro :
>    aggro≥40=tank / ≤8=carry / reste=bruiser) : si `P_tank>0.4` → exclure tank OU seuil tank <10 % ; si
>    `P_carry<0.05` → DA : signal exclusif tanks/bruisers OU seuil carry 20 %. **Ne pas coder §2.10 avant.**
> 3. **PRÉCONDITION LISIBILITÉ (commune avec #FF, §5.4)** : §2.10 lit le bus ; si un tick déclenche >5
>    événements simultanés, le signal de relief est noyé. Soumis à `combat_effect_legibility` (§5.4) : règle de
>    BATCHING avant de coder. **Une profondeur invisible est inexistante.**
> 4. **RÈGLE DE PRIORITÉ (Q_R9_4, doc)** : si §2.10 (relief) ET le Moment du Run §2.4 se déclenchent au même
>    combat → **§2.4 en PRINCIPAL, §2.10 en ligne SECONDAIRE** (étend la règle « Moment > Surprise de Placement »).
> **Ce qui NE change PAS (rejet partiel, synthé §7.1)** : la critique « §2.10 = simple second Moment du Run dans
> un système déterministe » est **rejetée** — la différence de VALENCE (positif vs évitement) reste réelle même
> sur un build connu ; poids hédonique 2 maintenu (retention §5.3). On corrige l'ancrage et la calibration, on
> ne dégrade pas le signal.

- **Hypothèse systémique non questionnée en 8 rounds (retention §2.1)** : **les 5 sources VRR de la roadmap sont
  TOUTES de valence POSITIVE** (bonne offre, belle cascade, spectre affronté, beau build, relique pertinente). La
  distinction « agence directe / narration rétrospective » (§2.9, PSU.com 2025) concerne 2 **TYPES d'action**
  (décision vs observation), **pas** 2 circuits **émotionnels**. **Sur le plan de la neuromodulation, une surprise
  positive sature le même circuit** qu'elle arrive de la boutique ou d'une cascade. **Preuve (Game Developer,
  Reward Schedules)** : « Players habituate to reward *TYPE*, not just frequency. A mix of rewards that feel
  structurally identical — all positive surprises — habituates at the same rate as a single repeated reward.
  Diversity requires *hedonic contrast*. »
- **Ce qui manque = le RELIEF (évitement sous agence)** — le mécanisme de rétention le **plus durable** des
  Soulslike (researchgate.net/publication/399804244 : « the avoidance-followed-by-mastery loop is more durable
  than pure positive reinforcement — relief after a threat overcome is *qualitatively different* from a reward
  given »). « Éviter la défaite grâce à un placement minutieux » **est déjà dans le jeu** mais jamais NOMMÉ comme
  source VRR. La **DA grimdark oppressive** est le cadre idéal (« le Puits a failli te consumer »).
- **Quoi (RENDER ~1 h, 0 SIM, 0 invariant ; BLOQUÉ par CONFIG-SURVIVAL + lisibilité, cf. encadré round 9)** :
  après chaque **VICTOIRE** où une unité du build a **survécu** en ayant perdu **≥[seuil PAR RÔLE, CONFIG-
  SURVIVAL] de ses PV** (lu du bus `{target, hp_before, damage}`), afficher **1 ligne distincte du Moment du
  Run** : **« [NOM_UNITÉ] A TENU — [TA SYNERGIE A×B / TON PLACEMENT] L'A MAINTENU EN VIE »** + ligne
  atmosphérique « LE PUITS N'OBTIENT PAS CE QU'IL VEUT » + surlignage discret de l'unité (attribution #JJ).
  - **Distinct du Moment du Run** : Moment = « j'ai fait quelque chose de brillant » (agence positive) ; CONTRE
    LA MORT = « j'ai *évité* quelque chose de terrible » (relief / agence défensive). **Unités DIFFÉRENTES** du
    build → **pas de cannibalisation** ; ensemble = **contraste hédonique**.
  - **Conditions** : **VICTOIRE uniquement** (jamais défaite — éviter le paternalisme « tu as failli survivre ») ;
    `hp_remaining > 0` (vraie survie) ; **1 seule unité** satisfait (sinon « failli te consumer » perd sa
    singularité).
- **Garde-fou DA** : grimdark pur (le Puits = ennemi, pas ami), **0 félicitation**, survie = miracle sombre.
  **Compatible enveloppe VRR** (Q_R8_1) : ~2-3 signaux/run estimés (poids 2 = +4-6 pondérées). **À valider en
  sim** (lire `{hp_before, damage_taken}` sur N=200 : ~20 % des combats gagnés ont une unité survivante ≥75 %
  PV perdus ?). **Zone sans test** → test que la condition se déclenche sur un golden (unité survivante proche de
  0 HP). **À articuler avec le Moment du Run (§2.4), le Nom de Build (§2.4bis), le Dernier Souffle (§6.10).**
- **Source** : retention §2.1/Prop-B (diagnostic) + §2.1/Prop-A (reformulation attribution) + §2.4/Prop-D
  (CONFIG-SURVIVAL) ; researchgate.net/publication/399804244 (SDT Dark Souls, avoidance-mastery loop + hedonic
  contrast) ; **arXiv 2603.26677 (Ordeal Pleasure — reconstruction narrative interne, round 9)** ; Game
  Developer (Reward Schedules) ; Kao et al. 2024 CHI (diversité de valence).

---

## 3. CHANTIER P0.5 — Audit identité 10-col (A-J) + `dot_family` + axe choc AXE D CIBLÉ + RANG-5/APEX CHOC + sims + corrections code (v0.9.5, data/doc + sim ; ≤2 réécritures ciblées + data rang-5) — **APPROFONDI rounds 4-8 (round 8 : #GG apex axe, col B/E rang-3/4, #DD ordre strict, CONFIG-CE co-prio)**

> **Pourquoi AVANT les types** : convergence de **3 lentilles** (units, synergies, relics). **Rounds 4-5
> ont vérifié le code et promu 3 mesures ici** : `--poison-frac` (1re cause poison>choc), `--no-weaken`
> (**2e cause** — le weaken, axe défensif non capté par `win_rate(dégâts)`), `--position-variance` (design
> du compteur type — **repositionné round 6 : calibrer les auras, #D clos global pur**) **doivent être
> mesurées AVANT P1**, sinon les types amplifient une méta cassée. Le choc est jaugé en **`burst_DPS_eq`**,
> **cible la `dot_family` du poseur** (#S clos), et son ampli est **rendu visible**. **Round 6 ajoute** :
> **CONFIG-PC** (magnitude `plague_communion` = sim **BLOQUANTE**, le seul `more` hors-cap) ; **colonne (J)**
> valeur sigil-dépendante ; **règle de dispersion DPS** `P90/P10 ≤ 3×` (rupture perceptive `cost=rank`,
> spread 7,24×). **2 corrections code** : axe D ciblé (`dischargeShock` dans `tickDots`) + **Option C2**
> (`afflictionCount` ne compte que les dps réels). **Coût : data/doc + sim headless + ≤2 réécritures
> ciblées** (sim-validées, golden rebaseliné si nécessaire ; le signal UI = RENDER).

### 3.1 Audit d'identité — grille à 10 COLONNES (A-J) + plafond ET plancher + lignes spécialisées — **PRIORITÉ 1 (ÉTENDU round 6)**

- **Quoi** : tableau dans `docs/roadmap-lab/` — 5 familles × 5 rangs + lignes spécialisées (tank,
  auras). **Grille à 10 colonnes (A-J)** :
  - **(A) niche** ≤10 mots ;
  - **(B) type de redondance** = NICHE (même op/axe, params ≤20 %) | POOL (niches distinctes mais trop
    d'enablers/famille/rang) | Sain. **+ catégorie « DOUBLE-VALEUR » (NOUVEAU round 6, units §2.2/§2.3)** :
    une unité qui cumule **2 valeurs** distinctes (aura + DPS carry, ou DPS carry + counter) → à trancher
    explicitement (documenter la niche OU normaliser une des valeurs).
    **+ DÉTECTION DE PAIRES DE NICHE (NOUVEAU round 7, units §2.2/P-B)** : la règle `P90/P10 ≤ 3×` (§3.1 col E)
    mesure le **spread** mais **masque la redondance de NICHE** — 2 unités adjacentes dans la distribution
    peuvent avoir des params **≤20 % d'écart sur l'axe principal** et passer le test de spread. **Preuve code
    (units §2.2, vérif synthé)** : burn rang-2 `pyre_herald` (dps=6/dur=170) ≈ `emberling` (dps=6/dur=150,
    9 % DPS frappe) ; bleed rang-2 `wailing_shade` (dps=2/slow=15 %) ≈ `razorkin` (dps=2/slow=20 %, 4 % DPS
    frappe) ; `byakhee` (dps=3/slow=10 %) ≈ `gash_fiend` (dps=3/slow=20 %). **Pool LOCAL** → 2 quasi-identiques
    co-apparaissent souvent → le joueur prend le 1er → **l'autre n'existe pas pour lui** (a327ex « 1 pet = 1
    valeur ; sinon l'un est invisible »). → **identifier les paires (≤20 % sur l'axe principal), différencier
    l'axe OU retirer la plus faible de `U.pool`** (candidats : `pyre_herald`, `wailing_shade`, `byakhee` —
    croisés cohorte v7 §3.2). **Garde-fou** : ne pas retirer si ça passe une famille sous le plancher ≥2/rang.
    **+ ÉTENDRE L'AUDIT AU RANG-3 ET RANG-4 (NOUVEAU round 8, units §2.1/§2.2, code-vérifié synthé)** — l'audit
    col B ne couvrait que le rang-2 depuis 7 rounds. **2 cas neufs code-vérifiés** :
    - **PAIRE DE DOMINANCE rang-3 (`units.lua:64` + `:124`)** : `corruptor` (`poison dps=2 dur=180 weaken=0,06`)
      vs `bile_spitter` (`poison dps=2 dur=180 weaken=0,10`) — **op IDENTIQUE**, `bile_spitter` a un weaken
      **supérieur** ET un DPS frappe seulement 8 % inférieur = **strictement meilleur sur chaque axe** → ce
      n'est **PAS** une paire de niche (50/50) mais une **DOMINANCE** (`corruptor` = dead pick garanti, P≈0 %
      avec joueur informé ; Ariely 2003 : un item dominé **dégrade** la décision). **Remède** : (a) différencier
      `corruptor` sur un axe orthogonal (ex. `dps=3` = « empoisonneur rapide » vs `bile_spitter` « affaiblisseur
      lent ») **OU** (b) retirer de `U.pool` (garder `U.order` ; `bile_spitter` maintient poison rang-3 ≥1). **À
      croiser avec l'ordre `--pool-repr` (§3.5) — retirer `corruptor` CHANGE la représentation rang-3 poison.**
    - **ENABLER rang-4 = enabler rang-2 (`units.lua:427` vs `:80`)** : `rust_sentinel` (`shock add=1 cap=6
      dur=150`, rang-4) = **op IDENTIQUE** à `stormcaller` (`shock add=1 cap=6 dur=150`, rang-2) → enabler
      rang-2 en taille rang-4 = **viole #10** (rang-4 = twist), jamais détecté en 7 rounds (ni twist, ni tank
      aggro=20, ni choc avancé). **Remède** : ajouter un T2 twist choc (ex. `chain=1`/auto-discharge lent) **OU**
      rétrograder rang-3 (libère un slot rang-4 choc pour un vrai twist). **+ `runestone_golem` niche ambiguë
      (`:431` vs oath_keeper `:353`)** : `shield_aura value=12` < `oath_keeper` value=18, mais plus de HP (88 vs
      84) et DPS (0,125 vs 0,114) → laquelle pour un build bouclier ? Trancher : aura pure (réduire DPS/HP) OU
      carry-tank sans aura (renommer). **Tous tranchés avec la cohorte v7 (§3.2), AVANT P1 ; col B/E étendues
      rang-2/3/4.** Source : GhostCrawler (« no design role of a lower tier without a new dimension ») ; Ariely 2003 ;
  - **(C) remède** = NICHE → « différencier l'axe » ; POOL → « retirer de `U.pool` (garder en
    `U.order` pour encounters IA) » ;
  - **(D) `dot_family` inférée** (= op du 1er effet DoT non-aura — documenté pour P1) ;
  - **(E) BUDGET STAT (units §2.2)** : `DPS base (dmg/cd)` + HP + proxy EHP×DPS, dans la plage
    `[rang-1 < rang-2 < rang-3]` ? (Oui / Over / Under). **EXCEPTIONS DOCUMENTÉES (round 4)** : voir
    §3.1a (choc = condensateur, `burst_DPS_eq`) et §3.1b (tanks, `EHP_proxy` + `DPS_tank ≤ 0.07×rang`) ;
    **+ RÈGLE DE DISPERSION INTRA-RANG (NOUVEAU round 6, units §2.1)** : `P90/P10 du DPS des enablers DoT
    d'un même rang ≤ 3×` (**tanks et condensateurs EXCLUS** — ils ont leurs propres critères §3.1a/b).
    **Preuve code (units §2.1, relu)** : rang-2 = **`witch` 0,181 → `shieldbearer` 0,025 = 7,24× de spread**
    (médiane 0,103) → le contrat `cost=rank` est **perceptivement rompu** (un joueur voit `witch`+`hookjaw`
    en boutique et conclut que `hookjaw` est « bas de gamme » — **ancrage d'Ariely, Loewenstein & Prelec
    2003 QJE** ; SHOP_SIZE=5 + pool LOCAL = ancrage maximal). **Remède** : ajuster les outliers d'**enablers
    DoT** (pas les tanks) **+ SIGNAL BOUTIQUE « GARDIEN »** pour les tanks (le rôle bas-DPS doit être signalé
    **autrement que par le prix**) → pilote le tooltip boutique (§2.5). **Ce n'est PAS du rééquilibrage des
    tanks** (ils DOIVENT avoir un DPS bas), c'est de la **lisibilité**.
    **+ RÈGLE CROSS-RANK (NOUVEAU round 7, units §2.4/P-D)** : « **DPS_frappe rang-n < médian DPS_frappe
    rang-(n+1)** par famille » — l'inversion **cross-rank** est le pire cas de signal `cost=rank` cassé
    (2 tiers concernés). **Preuve code (vérif synthé `units.lua:402-403` vs `:195-196`)** : `byakhee` (rang-2,
    dmg=8/cd=50 = **DPS 0,160**) **dépasse de 76 %** `vein_splitter` (rang-3, dmg=4/cd=44 = **DPS 0,091**) =
    **1,76×**, pire que `cinder_cur`/`bellows_priest` (1,37×). Cause : `byakhee` = v7 « familles visuelles »
    sans calibrage cross-rank. **Remède** : `byakhee` → réduire dmg 8→5-6 (DPS 0,100-0,120, budget rang-2) OU
    rétrograder. Tranché avec la cohorte v7 (§3.2). **Ariely 2003** : un joueur voyant `byakhee` à 2 or ET
    `vein_splitter` à 3 or dans la **même boutique T3** n'achète jamais `vein_splitter` ;
    **+ DENSITÉ RANG-3 PAR FAMILLE — DÉSERT BURN (NOUVEAU round 8, units §2.4/P-D, code-vérifié)** : les rounds
    précédents ont compté les **singletons rang-1** mais jamais la **densité rang-3** (le « bridge » early→late).
    **Calcul `units.lua`** : burn r1=1/r2=5/**r3=1**(`bellows_priest`)/r4=2/r5=3 = **DÉSERT r3** ; bleed
    r3=3 (OK). `P(bellows_priest visible T3, SHOP_SIZE=5) ≈ 27 %` vs `P(≥1 bleed r3) ≈ 61 %` → un joueur burn
    trouve sa progression rang-3 **2,3× moins souvent** (async : asymétrie dans les pools d'adversaires). SAP
    (a327ex : « each tier = introduction to the next mechanic ») → la progression burn **plafonne en mid**
    (rounds 4-7 = shopTier 2-3 = consolidation). **Décision (audit, data-only)** : **voulu** (bridge resserré =
    build burn plus exigeant, grimdark-cohérent) **ou trou** = 1 enabler burn rang-3 distinct (ex. burn + aura
    d'explosion ≠ `wildfire_hound`) → P ~45-50 %. **À croiser avec la cohorte v7 et le plancher ≥2/rang.**
    Priorité moyenne (audit P0.5, ne bloque pas les paires de dominance) ;
  - **(F) CONFLIT TWIST-T2 (synergies §2.3)** : « si le palier 4 de ce type implémente le mécanisme
    clé de ce T2 → NICHE VIDÉE » (à croiser quand les twists P1 sont spécifiés).
  - **(G) EFFET SECONDAIRE PERÇU ≤8 mots (NOUVEAU round 4, units §2.1)** : ce que le joueur **voit en
    build sans lire les params**, + la famille avec laquelle il **risque de confondre**. → **pilote
    les textes i18n** (`unit.<id>.passive_desc`). Ex. Bleed = « ta cible frappe au ralenti » (confond
    avec Rot) ; Rot = « ta cible fond de l'intérieur » (confond avec Bleed) ; Poison = « empoisonne de
    plus en plus » (orthogonal). **Coût RENDER/i18n, 0 moteur ; pas un sujet de rééquilibrage.**
  - **(H) DÉPENDANCE DE POOL + CONTRE-BOUCLIER (NOUVEAU round 5, units §2.2 + synergies §2.5 ; ÉTENDU round 6)** :
    pour chaque unité, **quelle condition pour qu'elle soit utile en boutique** (autonome / adjuvant-dépendant).
    **Preuve code-vérifiée (synthé, `units.lua:366-376` + `:479`/`:507`)** : `barrier_savant`/`mirror_ward`/
    `surge_warden` sont des `aura_shield` **dans `U.pool`** qui ne font **RIEN** sans un `shield_caster`
    voisin — or **seul `ward_weaver` l'est** → **dead picks silencieux** (Wayward Strategy 2018). **Décision
    pool-A** : les **retirer de `U.pool`** (garder en `U.order` pour encounters IA), avec la cohorte v7 (§3.2).
    **+ `hollow_choir` AJOUTÉE à pool-A (NOUVEAU round 6, relics §2.4)** : `relics.lua:37-38` pose
    `pierceHeal=0.40` (perce 40 % des **soins** ennemis) — mais **regen = 1 unité** (`plague_doctor`),
    **heal-on-kill = 0** (00-state §2.1) → **counter d'un archétype qui n'existe pas** = bruit (quasi-nul en
    ~95 % des matchups) qui **contamine les offres mid** en gating tier≤3. Retirer de `U.pool` (réintégrer si
    ≥3 unités regen/heal-on-kill). **Q ouverte (Q2 relics, liée à #X)** : **réorienter** en `pierceShield`
    (counter-bouclier léger, lisible, non-dominant) = 1re relique de **counter actif** → P1.5b après la colonne
    (I). + colonne intègre le **contre-bouclier par famille** : burn=absorbé (`arena.lua:432`) / bleed-poison-rot=
    ignoreShield / choc-D=partiel → **#W CLOS round 6 = VOULU (synergies §2.2)** : la vulnérabilité burn/bouclier
    est **intentionnelle** — rock-paper-scissors propre (**burn > carries, tank > burn, autres percent via
    `ignoreShield`**) ; Wayward Strategy 2024 (« counterplay needs measurable responses for all options ; no
    response = dominance ») → si burn ignorait les boucliers, les tanks n'auraient **aucune réponse** = dominance.
    **Conséquence** : **twist burn-4 = `burnIgnoreShield` (keystone de commit)** ; l'**archétype tank est
    RENFORCÉ** (counter dur au burn = identité claire). (Le **coût** de la vulnérabilité = burn a déjà le
    meilleur axe de propagation = ignore-bouclier **implicite** ; le doubler de base serait excessif.)
  - **(I) CONTRE QUOI OPTIMAL (NOUVEAU round 5, units §2.4)** : l'archétype adverse que chaque famille
    **counter** mécaniquement → **pilote l'i18n grimdark + l'audit reliques**. **Code-vérifié** (`chooseTarget`
    aggro câblée) : **rot → tanks/taunt** (l'amputation PV max contourne le HP brut ; le tank meurt avant que
    les carries soient atteintes) ; burn → front faible-HP ; bleed → carries haute-cadence (slow) ; poison →
    haute-valeur-stat (weaken) ; choc-D → cibles **déjà dotées** (l'axe D ne déclenche rien sur une cible sans
    DoT → lié à la latence VRR early #Q). **Documente aussi le co-build bleed+rot** comme légitime **sans
    palier propre** (option F3, units §2.1 : niches orthogonales tempo vs HP — rend la friction **explicite**
    sans toucher le moteur). **Révèle rot = counter taunt ORPHELIN de relique** (→ ticket P1.5b, §1.10).
    **+ CONDITION DE PLACEMENT rot-counter-tank (NOUVEAU round 7, synergies §2.4/P5)** : « rot → tanks »
    n'est vrai que **si le rot atteint les tanks**, or le ciblage déterministe cible la **colonne avant** ;
    si le sigil adverse met ses **carries en front** (croix, carry central) et ses **tanks en flanc**, le rot
    cible les carries → **le rot counter les tanks SEULEMENT quand les tanks sont en front adverse** (non
    garanti). **Candidat twist/relique rot-4 (P1.5b) = amputation de la cible à PV_max le plus élevé** (pas
    la cible front) → rend le counter rot-tank **placement-indépendant** (combat-model-decision §4) ;
  - **(J) VALEUR SIGIL-DÉPENDANTE (NOUVEAU round 6, units §2.5 + synergies §2.4)** : pour les unités à
    `trigger="combat_start", target="neighbors"` (auras + `shield_aura`), la valeur **varie ~2×** selon le
    sigil — carré/croix centre = **4 voisins** ; ligne/anneau = **2 voisins max**. **Dimension absente des 9
    colonnes A-I.** Backpack Battles (steam) : « positional adjacency items require **spatial tooltips** ».
    → noter **valeur max** (sigil à N voisins) / **min** / **sigil hostile** (efficacité < 50 %). Ex.
    `soot_acolyte` : max = croix/carré (4 voisins) / hostile = ligne (2 voisins). **Révèle si une aura est
    viable dans TOUS les sigils ou seulement certains** = critère de pick absent du brouillon. Doc, lit
    `shapes.lua`, **0 code, 0 invariant.**
    **+ FLAG DE COMPATIBILITÉ SIGIL ACTIONNABLE (NOUVEAU round 9, units §2.4/P-C, précondition P1)** : la col J
    était **documentaire mais non actionnable**. Ajouter un critère binaire **« viable ≥3/5 sigils ? »** pour
    les 4 auras DoT rang-3 (`soot_acolyte`/`clot_mender`/`miasma_acolyte`/`decay_tender`) — calcul sur
    `shapes.lua` (toutes passent ≥3/5, sigils-MAX = carré/croix 4 voisins, sigils-MIN = ligne/anneau 2). **NE
    PAS retirer de `U.pool`** (trop radical, rejet synthé §7.3). MAIS : (a) **alimente le tooltip boutique
    (§2.5)** ; (b) **INFORME P1 (types)** — le sigil `ligne` (conduit front→back, archétype bleed-intuitif) ne
    donne que 2 voisins → une aura « 5×4 » devient « 5×2 » (50 % perdus). **Si un palier-4 prescrit `clot_mender`
    comme aura bleed et que le build bleed joue `ligne` (son sigil naturel), l'aura est à moitié inefficace =
    incompatibilité silencieuse archétype↔aura** → c'est un **problème de SPEC P1** (Q2 units), pas d'unité :
    soit le palier prescrit une unité rang-4 différente, soit le tooltip signale l'incompatibilité. Doc, lit
    `shapes.lua`, **0 code.** Source : units §2.4 ; Backpack Battles (steam mai 2026).
- **Preuve code budget chiffrée (units §2.2, vérif synthétiseur)** : `cinder_cur`/`zeal_inquisitor`
  (rang-2, DPS=0.118) **dépassent** `bellows_priest` (rang-3, 0.111) → anomalie. `cost=rank`
  (décision #10) ne tient que si **le budget réel suit le coût** (= contrat d'apprentissage avec le
  joueur, units §1.2). Seuil indicatif : `DPS base rang-2 < médian rang-3`, **sauf condensateur/tank**.
- **`siege_breaker` = anomalie DOUBLE-VALEUR à trancher (NOUVEAU round 6, units §2.3, `units.lua:377-380` relu)** :
  rang-3, **DPS=0,154 (le PLUS HAUT du rang-3)** + `strip_shield` (seul counter-bouclier actif) = **carry +
  counter** non documenté, jamais cité en 5 rounds (glisse hors radar tank car pas `aggro=40`/taunt).
  GhostCrawler : « not both best attacker and best counter ». → **catégorie NICHE (col B), décision binaire
  AVANT P3** : (a) réduire DPS ≤0,095 (counter pur, budget compense l'utilité) **OU** (b) retirer de `U.pool`
  (garder en `U.order` pour encounters IA). Croisé avec la cohorte v7 (§3.2).
- **`soot_acolyte` DOUBLE-VALEUR aura+carry à trancher (NOUVEAU round 6, units §2.2, `units.lua:149-151` relu)** :
  aura burn **DPS=0,111 = MÉDIAN rang-3**, vs les 3 autres auras (`clot_mender`/`miasma_acolyte`/`decay_tender`
  ≈ 0,067) → le joueur la pick **pour son DPS de frappe**, pas pour l'aura (SAP « 1 pet = 1 valeur », Q3 round 4
  jamais répondue). **Décision (col B/G)** : (a) normaliser DPS vers 0,07-0,08 (aura pure, cohérent) **OU**
  (b) documenter « **carry-aura** » (niche unique au burn — « brûleur-prêtre » grimdark vs les 3 « acolytes »).
  **Option (b) recommandée si la DA supporte un burn-carry hybride** (i18n seulement). Option (a) = 1 param +
  golden si dans le scénario.
- **Preuve code redondance (units §1.3)** : burn rang-2 = 5 ; bleed rang-2 = 5 ; **poison rang-2 = 6**.
- **Cible PLAFOND** : **≤4 enablers/famille/rang dans `U.pool`** (`units.lua:488`, ≠ `U.order` `:453`).
- **Cible PLANCHER (units §2.1)** : **≥2 enablers/famille au rang-2 ET au rang-3** pour `P(famille
  visible/boutique T2) ≥ 40 %`. **Preuve** : rot rang-2 = `rot_hound`+`rot_grub`+`bore_worm`(v7) =
  2-3 → `P(voir rot/boutique T2) ≈ 25-43 %`. Une famille à 1 enabler rang-2 = **archétype caché**.
  **Q1** : si 1 enabler est la **rareté voulue**, le documenter, ne pas combler par réflexe.
  **+ RAFFINEMENT RANG-3 = COMPTER LES POSEURS ACTIFS, PAS LES AURAS (NOUVEAU round 9, units §2.2/Q3)** : le
  plancher ≥2/rang appliqué au TOTAL (auras incluses) fait « passer » toutes les familles par construction
  (chaque famille a une aura rang-3). Mais une aura (`soot_acolyte`, trigger `combat_start`) **amplifie le
  rang-2, n'introduit PAS un twist rang-3** (SAP : « each tier = a new mechanic »). Pire : un joueur burn avec
  `soot_acolyte` + 4 rang-2 croit avoir une progression rang-3 = **piège de composition**. **Redéfinir le
  plancher rang-3 = « ≥2 POSEURS ACTIFS (trigger `on_hit`) par rang-3 »** (auras exclues). **Conséquence : burn
  rang-3 = `bellows_priest` (1 poseur actif) → SOUS le plancher → désert burn confirmé SANS AMBIGUÏTÉ.** Croisé
  avec `--burn-progression-gap` (§3.1 désert burn). Source : units §2.2 ; a327ex.com/super_auto_pets.
- **PLANCHER RANG-1 : burn, rot ET bleed = SINGLETONS (NOUVEAU round 6, ÉTENDU round 7, units §2.4 + §1.4/Q4)** :
  `ash_moth` (`units.lua:100`, **seul** enabler burn rang-1, HP=26 fragile, DPS=0,075), `carrion_pecker`
  (**seul** rot rang-1) **ET `gnaw_rat`** (`units.lua:446`, **seul** bleed rang-1, dps=1/slow=8 % — **oublié
  par le brouillon v7, signalé round 7**). **3 familles sur 5** ont un singleton rang-1 (burn, rot, bleed) ;
  seuls poison (`spore_tick`) et choc (`live_wire`) en ont sans concurrence. **P(visible T1, SHOP_SIZE=5) ≈
  42 %** (juste au-dessus du plancher) **MAIS la visibilité de RECONNAISSANCE est plus basse** : un singleton
  fragile « ne ressemble pas à la porte d'entrée ». SAP : « early tiers = introduction à chaque mécanique ;
  sans ancre early-accessible, le joueur ne peut s'orienter ». → **traiter les 5 familles UNIFORMÉMENT** :
  documenter chaque singleton (rareté voulue **OU** trou). **Si trou → 1 stat-stick rang-1** (DPS≈0,09-0,10,
  HP≈40) suffit, sans nouvelle mécanique. **Décision data, pas moteur.** (Précondition : décision de cohorte
  v7 §3.2, pour vérifier qu'aucune v7 rang-1 ne compense déjà.)
- **Source** : SAP 10/tier (1 trigger/pet, §3.2 ; a327ex.com) ; Balatro (1 règle/Joker) ; StS Giovannetti ;
  GhostCrawler power-budget ; Ariely/Loewenstein/Prelec 2003 QJE (ancrage) ; **pool LOCAL (≠ TFT partagé) →
  math de visibilité propre** (units §1.1). **Garde-fou** : data-only, **0 invariant**, toute modif de stat
  passe `tools/sim.lua` + golden.

#### 3.1a — Le CHOC est un CONDENSATEUR : `burst_DPS_eq`, pas `dmg/cd` (anti-nerf-aveugle de `galvanizer`) — **NOUVEAU round 4 (units §2.2)**

- **Problème** : le ladder choc viole `DPS base < médian rang+1` **par conception** (cd long / dmg
  faible pour empiler des stacks qui déchargent en burst). Appliquer `dmg/cd` uniformément →
  `galvanizer` (rang-4, DPS frappe=**0.172**, l'**outlier #1 du roster**) apparaît « OVER » → **risque
  de nerf aveugle du meilleur candidat à l'archétype choc** en P3.
- **Remède** : pour les unités `op="shock"`, la colonne E utilise **`burst_DPS_eq = (volt × stacks_moy)
  / cd_moy_décharge`**, comparé **intra-famille choc** (pas cross-famille). `galvanizer` reste outlier
  même ainsi (`burst_DPS_eq ≈ 0.245`) → **l'étiqueter « condensateur premium — outlier voulu, ne pas
  nerf aveuglément »**. **Précondition #G** (le burst change selon l'axe D — tick DoT, pas décharge
  directe). **Ordre** : décider l'axe D, puis valider l'audit condensateur.
- **Source** : StS Totem/Ironclad jaugé sur **dégâts par éruption**, pas DPS moyen
  (slaythespire.wiki.gg/wiki/Cards). Doc, 0 invariant.

#### 3.1b — Budget TANK dédié : `EHP_proxy` + `DPS_tank ≤ 0.07×rang` ; trancher `templar` et `runestone_golem` — **NOUVEAU round 4 (units §2.3)**

- **Problème** : « pas de 6e type tank » (litige #F, **aucun** — confirmé) **ne résout pas** la
  **dispersion de DPS intra-groupe** des 11 tanks (`shieldbearer` 0.025 → `templar` **0.146**). Un tank
  à DPS élevé = bruiser → hiérarchie implicite non documentée.
- **Remède** : colonne E **dédiée tanks** : `EHP_proxy = hp × (1 + max_shield/hp)` + règle indicative
  `DPS_tank ≤ 0.07×rang`. **Décisions à trancher** : `templar` (rang-3, DPS=0.146, **unité vanille
  dessinée main**) = bruiser iconique **étiqueté** OU tuner ≤0.095 ? ; `runestone_golem` (rang-4 v7,
  DPS=0.125 + shield_aura, déjà signalé round 3 §3.6) = **roster-only** OU tuner ≤0.08 ? **Garde-fou** :
  ne pas rétrograder `templar` sans peser la friction UI (identité visuelle iconique compense si voulu).
- **Source** : metatft (HP/DPS inversé tank vs carry, Set 14). Doc, 0 code.

### 3.2 Décision de COHORTE pour la vague v7 + (option) champ `pool` déclaratif — **PRIORITÉ 1 (ENRICHI round 4)**

- **Quoi (units §2.5)** : les 14 unités v7 (`units.lua:383-447`) ont été créées pour la **génération
  procédurale** (champ `family`), **pas** pour l'équilibre du pool — `units.lua:487` « Identique au
  roster pour l'instant. ». **Filtre de 1er niveau, AVANT l'audit ligne-à-ligne** : « parmi les 14 v7,
  lesquelles ont une niche distincte **ET** un budget cohérent (colonne E) pour le pool day-1 ? » Les
  autres → **`roster-only`** (restent dans `U.order`, retirées de `U.pool`).
- **Estimation** : sur 10 v7 rang-2, ~4-6 à retirer (doublons burn/poison/bleed). `bore_worm` (rot) et
  `siphon_jelly` (choc) candidats au **maintien**.
- **Champ `pool` déclaratif (NOUVEAU round 4, units §2.4 — NON-bloquant)** : la cause racine est une
  **règle implicite non enforçable** (`U.pool = U.order`). Le remède propre = champ **data** `pool =
  false` (roster-only) + reconstruction filtrée de `U.pool` + lint « toute unité sans `pool` explicite
  = WARNING si ajoutée après v0.9 ». **Ce n'est PAS de la complexité moteur** (data + 3 lignes). →
  **À faire SI on touche `U.pool` pour la cohorte v7 de toute façon** ; sinon différer (la cohorte
  documentée+commitée suffit tant qu'aucune vague v8+ n'est planifiée avant P3). **Devient prioritaire
  si v8+ planifiée.** Source : « convention vs configuration » (Fowler). 0 invariant.
- **Garde-fou** : éditorial, 0 op, max 1 PR data. **0 invariant.**

### 3.3 Porteur de la famille DoT (`dot_family`) + lint + règle des multi-effets — **PRIORITÉ 1 (prérequis P1)**

- **Quoi** : décider **AVANT de coder P1** (a) le **champ porteur** : **`dot_family =
  "poison"/"burn"/"bleed"/"rot"/"choc"`** (nil pour les non-DoT ; rétro-compatible ; **pas de
  collision** avec `type` visuel ni `family` procédural) ; (b) la **règle des multi-effets** :
  `dot_family = op du 1er effet DoT non-aura` → `wither_bloom→rot`, `leech_thorn→bleed` (thorns =
  défensif), `galvanizer→choc` (bonus_first = stat — confirmé units §1.2). Tableau ~20 lignes.
- **+ LINT (synergies §1.1)** : règle dans `tools/check.sh` — « **toute unité avec un op DoT dans ses
  effets DOIT avoir `dot_family` non-nil** » (~5 lignes luacheck). Empêche un oubli futur.
- **Pourquoi** : sans champ stable, le compteur de palier (P1) inférerait depuis `effects[1].op`
  (fragile) ou utiliserait `type` (collision visuelle). C'est **la prochaine ligne de code de P1**.
- **Note DA** : les 3 axes `type`/`family`/`dot_family` **orthogonaux** sont **l'archi voulue**
  (« familles = THÈMES, 3 axes découplés » — the-pit-creature-visual-refonte). À documenter.
- **Garde-fou** : data/doc + lint, 0 code moteur, 0 invariant.

### 3.4 Axe du CHOC = AXE D (décharge sur le 1er tick DoT) — VALIDER 10 UNITÉS + sim 4-configs + SIGNAL UI + litige #S — **PRIORITÉ 1 (ENRICHI round 4)**

- **Vérité code (rounds 2-4)** : le ladder choc est **DÉJÀ codé** — `stormcaller, live_wire,
  thunderhead, static_swarm, galvanizer, stormlord, dynamo_priest, arc_warden, storm_anchor,
  siphon_jelly` (**10 porteurs**, `units.lua:79-332`). **Le chantier = décider l'axe + valider
  l'existant, pas créer.**
- **L'AXE C EST RETIRÉ (round 3, confirmé round 4)** : `dischargeShock` est appelé par `hit()`
  **APRÈS** le coup déclencheur (`arena.lua:330`, **vérifié 2 lentilles + synthé**) → amplifier ce
  coup exige de **réordonner `hit()`** (touche les invariants #22-32). De plus PoE Shock **ne stacke
  pas** (durée, pas intensité), ampli **toutes** sources ; notre choc stacke jusqu'à 8 et notre
  ciblage est **mono-cible** → « amplifie le prochain hit » ≠ l'amplificateur d'équipe de PoE
  (poewiki.net/wiki/Shock).
- **AXE D (ADOPTÉ, synergies §2.1) — CIBLAGE TRANCHÉ round 5 (#S clos)** : la décharge amplifie le tick de
  DoT de la **famille `dot_family` du POSEUR de choc** (fallback ordre fixe).
  - Dans `tickDots` (`arena.lua:392+`, **après** le cycle de frappe → **0 conflit d'ordre** ; le tick
    choc actuel n'inflige rien, `arena.lua:520-526` — l'axe D s'insère proprement), si `u.dots.shock.stacks
    > 0` : déterminer la famille à amplifier (algorithme #S ci-dessous), `tick_amplifié = tick × (1 + stacks
    × N)`, puis **consommer** les stacks. Émettre `shock_amplify {source, magnitude, famille}`.
  - **Algorithme #S (synergies §2.2)** : `family = source.dot_family` (champ statique posé au build) ; si
    présent sur la cible → amplifier cette famille ; **sinon fallback** = 1er disponible dans l'ordre fixe
    `burn→bleed→poison→rot` (préserve les stat-sticks choc sans affiliation). **1 lookup d'un champ statique,
    0 nouvelle structure, 0 invariant, déterministe.**
  - **`N` [PH suggéré 0.05 → +40 % à 8 stacks, cap lisible].**
  - **Identité** : « charger la cible, puis **TON** DoT explose ». Le ciblage par famille-du-poseur rend la
    promesse **vraie** (un build 4-choc+4-poison amplifie son poison, pas le bleed adverse). Précédent : StS
    *Vulnerable* (ampli ciblé).
- **SIGNAL UI OBLIGATOIRE (NOUVEAU round 4, synergies §2.1/P1)** : l'événement `shock_amplify` **DOIT**
  être rendu visible en combat (`arena_draw.lua` : couleur/icône « choc a amplifié X » — jaune=burn,
  rouge=bleed, vert=poison, brun=rot), **pas juste loggé en JSONL**. **Sans ce signal, l'axe D crée une
  profondeur INVISIBLE** : un joueur 4-poison dont la cible reçoit un bleed adverse verra son choc
  amplifier le **bleed**, pas le poison, sans raison de le savoir = **frustration Artifact**
  (postmortems §4.4). RENDER, écoute bus, 0 SIM.
- **LITIGE #S — CLOS round 5 (synergies §2.2/P2, corroboré relics §2.4)** : l'axe D amplifie la **`dot_family`
  du poseur de choc** (fallback ordre fixe). **L'ordre fixe pur est REJETÉ** : il amplifierait **burn-first
  par défaut** = la famille (i) **absorbée par les boucliers** (burn non-ignoreShield, `arena.lua:432`) et
  (ii) **qui n'est pas celle du build** → un build 4-choc+4-poison verrait son choc amplifier le bleed
  adverse = **l'opposé de la promesse** (PoE Shock = ampli universel ; notre transposition correcte = ciblé
  sur le build). Réponse mécaniste sourcée, rien ne la contredit → **statut « litige » retiré**.
- **Test opérationnel CONTEXTUALISÉ — matrice 4 CONFIGS + 2 métriques, seed fixe `20260623`** :
  | Mesure | Config | Seuil |
  |---|---|---|
  | win% choc-D vs poison | **A** : `gravewarden`(taunt,aggro=40) col1 + 3 choc col3, **ligne**, N=50 | cible win% ∈ [0.45,0.55] ; ajuster `N` |
  | win% galvanizer (auto-décharge) | **B** : galvanizer + stat-sticks, carré, N=50 | si >moy+0.5σ → 2 sous-archétypes (Q3 units) ; reste-t-il viable en axe D ? |
  | win% sur anneau | **C** : choc pur, **anneau**, N=50 | win% vs défense pure |
  | win% vs tank+bouclier | **D** : 3 choc-D + `ward_weaver×3`, carré, N=50 | si < moy−1σ → décider counter voulu/accidentel |
  | **latence VRR early (NOUVEAU round 4, #Q)** | sur plateau early 3 slots T1-2 | médiane **>3 combats** → leurre choc rang-1 (§3.7) |
  | **ampli burn vs non-burn (NOUVEAU round 4, synergies §2.5)** | dans Config D | mesurer séparément (burn absorbé par bouclier, autres ignorés) → feel voulu/accidentel |
  | **CONFIG-PC : magnitude `plague_communion` (NOUVEAU round 6, §3.9)** | **PC** : `{festering×2, plague_bearer, chitin_drone} + plague_communion`, carré, N=50 | win% ∈ [0,55 ; 0,65] ; **>0,70 → plagueAmp=0,15 OU `NOT poisonNoCap`** ; activation>80 % → option (c) scalante |
- **Config D résout un counter implicite (synergies §2.4)** : le burst de l'axe A/B a
  `ignoreShield=true` (**confirmé** `arena.lua:325`) ; en **axe D** l'ampli touche le **tick DoT** —
  bleed/poison/rot ignorent **déjà** les boucliers (00-state §3.1), mais **burn NON** (`arena.lua:432`)
  → l'ampli D sur un **tick burn** est **partiellement absorbée**. Config D mesure si l'ampli est
  gaspillée vs une cible qui régénère/re-bouclier. Rapatrie `timing-shield` de P3.
- **Garde-fou** : décision #8 (5 familles à axes distincts) **intacte**. Axe D = **réécriture ciblée de
  `dischargeShock` DANS `tickDots`** + **rebaseline golden signalé**. Sim headless, 0 invariant data.

### 3.5 `--poison-frac` + `--no-weaken` : mesurer les DEUX causes structurelles de poison>choc — **PRIORITÉ 1 (PROMU de P3, ÉTENDU round 5)**

- **Quoi — CAUSE 1 : propagation (synergies §2.2/P2 + retention §2.3)** : la propagation-à-la-mort du poison
  (`spread_*_on_death`, `ops.lua:219-231` ; avec `festering:poisonNoCap`) peut faire qu'une cible accumule
  >8 stacks, meurt, **propage** ses stacks aux voisins (`arena:neighborsOf`) → **cascade auto-amplifiante** que
  **ni le cap ×3 d'output ni l'axe choc-D ne plafonnent** (`poisonNoCap` lève le cap de *stacks*, pas la
  propagation). L'axe D résout la **lisibilité** du choc, **pas** la hiérarchie inter-familles.
  - **Mesure (data-only, golden-safe)** : `--poison-frac <f>` ; op `contagion` lit `frac = p.frac or 1.0`.
    `win_rate(poison) vs pool` à **frac=1.0** puis **frac=0.5**, N=200. Si delta passe de `>+1σ` à `<+0.5σ` →
    activer `frac=0.5`. **Golden inchangé si défaut 1.0.**
- **Quoi — CAUSE 2 : weaken (NOUVEAU round 5, synergies §2.1/P1)** : poison a **3 axes indépendants** (stacks
  multi-sources / **weaken** / propagation) ; le choc en a **1** (condenser→décharger). **Le weaken** (malus
  d'output ennemi, `ops.lua:71` + `chitin_drone`/`corruptor` relus) est un **axe défensif** que
  `win_rate(dégâts bruts)` **ne capte pas** → `--poison-frac` seul ne suffit pas. Précédent sourcé : **PoE
  Wither** (debuff cumulatif d'affaiblissement) dominait le late-game « only measurable by isolating the
  debuff contribution », plafonné à 15 charges (pathofexile.com/forum/view-thread/3870562).
  - **Mesure (~5 lignes, golden-safe)** : `--no-weaken` (désactive l'op weaken) ; `win_rate(poison)` avec/sans
    weaken, N=200 seeds aléatoires (même pool que `--poison-frac`). **Seuil d'alarme : delta > 0.3σ → le
    weaken est une 2e cause à corriger AVANT P1** (levier : réduire le malus jusqu'à `delta < 0.2σ`).
- **Pourquoi AVANT P1 (les deux)** : si poison est `> +1σ` **structurellement** (par l'une OU l'autre cause),
  un palier type poison +20 % (P1) **grave une méta cassée avant le ranked**, et le `--meta-convergence` (#A)
  mesurerait une convergence **artificielle**. On élimine **les deux** variables de confusion **avant** de
  coder les types. **Risque spécifique weaken** : `--poison-frac=0.5` peut valider (propagation corrigée) alors
  que weaken+stacking reste `>+0.8σ` sur les builds `chitin_drone` → le twist P1 amplifierait un axe **déjà
  dominant non détecté**.
- **Quoi — CAUSE 3 (CANDIDATE) : REPRÉSENTATION DE POOL (NOUVEAU round 7, litige #DD, synergies §2.3/P3 +
  units §0)** : poison a **15 unités** vs choc **11** (00-state §2.1) → P(voir poison en boutique) ≈ **36 %
  plus élevée** à cotes uniformes. La cause de **VISIBILITÉ** est **antérieure** à toute propagation : si
  poison est vu 2,3× plus souvent en T2 (calcul synergies §2.3), le joueur construit poison **par défaut
  d'exposition** (SAP/mobilegamereport 2026 : la profondeur commence par la visibilité boutique, surtout en
  pool LOCAL). `--poison-frac` seul corrigerait « l'arbre pas les racines » (puissance d'un poison **déjà
  sur-représenté ET sur-puissant** → 2 leviers confondus dans le win%).
  - **Mesure : `--pool-repr` (~10 lignes)** — compter `unités/famille/rang`, **alarme si
    `max_famille/min_famille > 1,5` par rang** → corriger le pool (col B §3.1, retrait d'enablers POOL
    redondants). **ADOPTÉE (litige #DD).**
  - **ORDRE STRICT IMPOSÉ — #DD CLOS round 8 (synergies §2.1/P1 + units Q3)** : l'ordre strict « `--pool-repr`
    AVANT `--poison-frac` » (réclamé r7, **nuancé** par le synthé r07 : « même lot, pas de preuve d'ordre ») est
    désormais **REQUIS** par une **preuve neuve** : la col B identifie les **REDONDANTES** mais ne décide pas
    **COMBIEN retirer** (≠ excédent de représentation) ; **et retirer `corruptor` (paire de dominance, §3.1)
    CHANGE la représentation rang-3 poison (de 2 à 1)** → simuler `--poison-frac` **avant** la décision de
    cohorte mesure un **pool qu'on va corriger** = propagation + sur-représentation **confondues** dans le win%.
    **L'isolation des variables** (Kritz & Gaina 2025, arxiv 2502.10304 : « measuring synergy requires isolating
    element contributions ») **exige** l'ordre :
    ```
    ORDRE STRICT P0.5 :
      1. décision de cohorte v7 (col B/E étendues r2/r3/r4 : corruptor, rust_sentinel, runestone_golem…)
      2. --pool-repr   : alarme si max_famille/min_famille > 1,5 par rang → corriger le pool
      3. --poison-frac : mesure la propagation sur un pool REPRÉSENTATIF
      4. --no-weaken   : isole le weaken sur le même pool corrigé
    ```
    **La nuance r07 tombe** (elle confondait « fait le même travail qualitativement » avec « produit le même
    résultat quantitatif »). **Lié à Q2 synergies** (répartition choc par rang). **Coût : doc pur, 0 code.**
- **Q2 (synergies)** : borner la propagation des **transforms T3** (`festering`/`venom_censer`) séparément du
  cap de stacks ? Le `frac` de l'op suffit a priori. À confirmer en sim. **Q1 (synergies)** : `chitin_drone`
  (rang-2, poison+weaken) est-il une **enabler double** sous-tarifée ? → colonne E de l'audit (§3.1).
- **Garde-fou** : paramètres data dans `ops.lua`, sim headless. 0 invariant.

### 3.6 `--position-variance` : CALIBRER les auras d'adjacence (le compteur de type est GLOBAL PUR) — **REPOSITIONNÉ round 6 (#D CLOS)**

- **#D CLOS round 6 → GLOBAL PUR (synergies §2.1/P1)** : le compteur de type est **global** aux deux paliers
  (2 et 4), **sans condition d'adjacence**. **Pourquoi la mesure ne décide plus** : TFT Galaxies (officiel,
  teamfighttactics.leagueoflegends.com, relu round 6) — les traits à **double condition simultanée** (nombre
  + autre facteur) créent une **« dead zone »** (le joueur a 3 unités, vise le palier 4, mais n'a ni la 4e
  unité ni la paire adjacente — 2 axes hétérogènes qui ne progressent pas ensemble). Et `--position-variance`
  mesure si la **position impacte le win-rate**, **PAS si la condition d'adjacence crée une frustration de
  dead-zone** (un joueur peut être en état frustrant 3+0 sans que ça apparaisse dans les stats). Surtout :
  **les auras d'adjacence build-résolues SONT déjà la couche positionnelle du type** (palier = « combien de
  burn » ; auras = « où tu les places » = 2 couches orthogonales). Dupliquer l'axe = sur-engineering.
- **OBJECTIF REPOSITIONNÉ (synergies Q2)** : `--position-variance` (3 permutations/build, seed fixe,
  `std_dev(win%)`) **calibre les AURAS existantes** — (a) valider qu'elles génèrent une variance
  positionnelle **significative** par sigil (sinon le plateau-graphe est un **décor topologique**, pas un
  différenciateur) ; (b) **comparer les sigils** (si la variance est homogène sur les 5 formes → les formes
  ne différencient pas le gameplay = problème de design sigil **indépendant des types**). **Nouveau critère** :
  `variance < 0.02` sur **TOUS** les sigils → les auras sont **trop faibles** → **les amplifier** (pas ajouter
  de paliers adjacents). Coût : ~20 lignes de sim.
- **Gain mesurable du #D-global** : **−2 invariants de test** (plus de « count=4+paire » vs « count=4 sans
  paire ») ; **aucun sigil hostile aux paliers de type** (résout la Q3 round 5 : la croix activait mal
  l'adjacence) ; design plus lisible (goal-gradient sur un **count visible** — diva-portal.org 2025).

### 3.7 Audit rang-5 — `deep_kraken`/`skull_colossus` BLOQUANTS + APEX CHOC manquant + trous d'archétype — **PRIORITÉ 1 BLOQUANT (PROMU round 7, units §2.1/§2.3)**

- **`deep_kraken`/`skull_colossus` = BLOQUANT, pas différable (NOUVEAU round 7, units §2.1/P-A, code-vérifié
  synthé)** : le brouillon v6 les signalait comme « décision à raffiner ». **Calcul `units.lua` relu** : ce
  sont des **stat-sticks `on_hit` PURS sans règle d'équipe** au rang-5 (coût max), violant #10 (rang-5 =
  transform/règle d'équipe). **Vérifié synthé** (`units.lua:421-423` skull dmg=11/cd=84 `on_hit burn` ;
  `:437-439` kraken dmg=12/cd=78 `on_hit poison`) :
  - `deep_kraken` **DPS=0,154 = le PLUS HAUT du rang-5**, **dépasse de 34 %** `marrow_drinker` (0,115, meilleur
    T3 transform légitime) ;
  - `skull_colossus` **DPS=0,131** dépasse **7 des 8** T3 transforms.
  **Problème (Giovannetti GDC 2019)** : « the power of a card must match its complexity — a rare that does
  nothing complex is worse than a common with a twist ». **Aggravant async (units §2.1)** : un `deep_kraken×3`
  (niveau-3 = DPS frappe 0,462) en ghost tier-4/5 = **mur de DPS brut SANS counter-play lisible** (pas de
  trigger conditionnel) → **amplifie les matchups ennuyeux** dans la méta async figée (trahit le pilier
  « petits nombres, profondeur émergente »).
  **DÉCISION (data, BLOQUANT avant P3 ; RÉVISÉE round 10)** : `skull_colossus` **RESTE burn** (la réorientation
  apex choc du round 7 est RETIRÉE — DA-invalide, voir le bloc R10 ci-dessous) ; sa niche tank-burn est clarifiée
  (burn_dps 4→8). `deep_kraken` → croisé poison-rot OU AoE colonne + mini grant_team (voir R10). → rang-5 burn =
  `ash_maw`+`plague_pyre`+`skull_colossus` (tank-burn clarifié) ; rang-5 poison = `festering`+`venom_censer`
  (+`deep_kraken` croisé/AoE) ; **rang-5 choc = NOUVELLE unité** (`type=arcane/abyss`, voir R10).
- **APEX CHOC rang-5 MANQUANT = trou structurel (NOUVEAU round 7, units §2.3/P-C, code-vérifié synthé)** : la
  famille choc est la **SEULE des 5** sans rang-5 dans `U.pool` (relu : live_wire r1 / stormcaller·thunderhead·
  static_swarm·siphon_jelly r2 / stormlord·storm_anchor r3 / galvanizer·dynamo_priest·arc_warden·rust_sentinel
  r4 / **0 r5**). 11 unités choc (densité égale) **mais aucun closing move**. **Conséquence (Giovannetti + Entalto
  2026 « every archetype must have a closing move »)** : un joueur qui commit choc et monte au shopTier 5 **ne
  trouve jamais d'apex** → croit à de la malchance, pas une absence de design = **mort de l'archétype en ranked**.
  **Aggravé en async** : un ghost choc tier-4 sans rang-5 = **moins menaçant** → `--meta-convergence` mesurerait
  une convergence **artificielle** vers les familles à apex.
  **DÉCISION ÉCONOMIQUE — RÉVISÉE round 10 (la réorientation skull_colossus est RETIRÉE, DA-invalide)** :
  l'apex choc rang-5 = **une NOUVELLE unité** `type=arcane/abyss` (cohérente avec la famille choc), PAS un
  recyclage de `skull_colossus`. **Pourquoi (units §2.2, `units.lua:421-424`, décision #3)** : `skull_colossus
  = { type="bone", family="crane" }` — un crâne osseux mort-vivant. TOUS les units choc sont `type=arcane`
  (live_wire/thunderhead/stormlord) ou `type=abyss` (static_swarm/arc_warden/siphon_jelly) ; aucun n'est
  `type=bone`. L'électricité (`shockChain`) sur un crâne osseux **brise la cohérence visuelle-mécanique** qui
  EST le différenciateur du jeu (décision #3). « Le slot existe + le HP/aggro convient → donc électricité » est
  une **analogie mécanique paresseuse** (BRIEF). Le « 0 moteur » du round 7 était faux sur le **fond thématique**.
  **NOUVELLE UNITÉ apex choc (data ~15 lignes)** :
  ```
  type = "arcane" OU "abyss" ; family = électrique (DA grimdark) ; rank=5, cost=5
  hp = 60-70 (carry, pas tank), aggro = 5-10 ; dmg = 7, cd = 60-70
  effects : { on_hit: shock{add=2, volt=6, cap=8, dur=240} }
          + { combat_start: grant_team{shockChain=true} }   -- SI #GG → axe A/B (0 moteur, ops.lua:187)
          OU { combat_start: grant_team{shockAmplify=true} } -- SI #GG → axe D (~3-5 lignes SIM)
  → contrat rang-5 respecté (grant_team = règle d'équipe, comme TOUS les T3 légitimes).
  → pool : U.order direct ; U.pool conditionnel à CONFIG-CE2 (axe D fragile sans setup = U.order d'abord, Q2 units).
  ```
  `shockChain` reste **déjà câblé** (`ops.lua:187` le consomme, `:276` le pose via `grant_team`). **PRIORITÉ :
  avant P1** (le palier-4 type choc — désormais Option B `tickCount=2`, #HH CLOS — n'a plus besoin de l'apex,
  mais l'archétype choc a toujours besoin d'un closing move au shopTier 5).
- **#GG BLOQUANT (NOUVEAU round 8, units §2.3/P-C, code-vérifié synthé) — « 0 moteur » ≠ vrai si l'axe D est
  adopté** : le round 7 affirmait « apex choc `shockChain` = 0 moteur » (ci-dessus) **et** que « si l'axe D est
  adopté (P0.5), le rebond devient propagation d'ampli DoT » (§3.4). **Ces deux affirmations sont
  contradictoires.** **Vérifié synthé (`arena.lua:342-388` + `:522-525`)** : `shockChain` est consommé dans
  `dischargeShock` qui est un **BURST de décharge (axe A/B)** — il inflige `volt × stacks` en une instance
  (`cause="shock"`, l.349) et chaîne **la décharge** à un voisin (l.358 `arc`, l.370-378 `spread`). **L'axe D
  (ampli du 1er tick DoT) N'EST PAS implémenté** (le bloc choc de `tickDots` n'écoule que la durée). Donc
  « 0 moteur » ne tient **que si le choc reste en axe A/B**. Reformuler `shockChain` en propagation d'ampli DoT
  (si axe D adopté) **exige une réécriture de `tickDots`/`dischargeShock`** (`for voisin in neighborsOf(source)`
  après l'amplification) = **SIM, pas data** + un test (invariant #22).
  **DÉCISION (à trancher AVANT P1, #GG)** :
  - **Option 1 (0 moteur, axe A/B)** : `skull_colossus` apex = `shockChain` (rebond de décharge burst). Les
    rang-2/4 utilisent l'axe D (ampli tick). **2 axes coexistent sur la famille choc** (profondeur : « charger
    pour amplifier le DoT » vs « charger pour rebondir la décharge »). **Tester que `shockChain` et l'axe D ne se
    court-circuitent pas** (un stack ne déclenche pas 2 amplifications ; interaction avec `DOT_CAP_MULT=3`).
  - **Option 2 (moteur minimal, axe D cohérent)** : apex via `grant_team {shockAmpMult=1.5}` (amplifie le
    multiplicateur de l'axe D au tick). **0 moteur SI `shockAmpMult` est déjà paramétrable dans `tickDots`**
    (à vérifier) ; sinon ~5 lignes SIM. Préserve la cohérence de l'axe D pour tout le ladder choc.
  Entalto 2026 (« build identity clear within 2 min ») : le ladder choc doit savoir **sur quel axe il amplifie**
  AVANT de coder le palier-type choc-4. **Le « 0 moteur » du round 7 n'était vrai que dans l'état pre-axe-D.**
  **CORRECTION round 10 (le PORTEUR de l'apex change)** : dans les Options 1/2 ci-dessus, l'apex choc n'est PLUS
  `skull_colossus` (DA-invalide, bloc ci-dessus) mais une **NOUVELLE unité rang-5 `type=arcane/abyss`**. L'analyse
  d'AXE (Option 1 = `shockChain` burst A/B 0 moteur ; Option 2 = `shockAmpMult` axe D ~5 lignes SIM) reste
  VALIDE telle quelle — seul le porteur est corrigé. **De plus, le palier choc-4 (#HH) est désormais Option B
  `tickCount=2` (CLOS, ci-dessous) → il ne contraint PLUS l'axe d'apex** : #GG = uniquement l'axe de l'apex rang-5,
  découplé du palier-4.
- **CONFIG-CE co-prioritaire à la décision d'apex choc (PROMU round 8, synergies §2.4/P4)** : l'apex choc **sans
  correction de la latence early du choc** = **apex jamais atteint** (le joueur engage choc en early → peu de DoT
  adverse → axe D ne se déclenche pas → choc paraît faible → quitte l'archétype au round 3 → ne voit jamais l'apex
  au shopTier 5). **Aggravé async** : un ghost choc tier-4 sans DoT adverse → décharges n'amplifient rien → ghost
  « faible » au snapshot → déconseille l'archétype. **CONFIG-CE n'est plus « diagnostic P3 » (§11) mais une mesure
  CO-PRIORITAIRE de la décision d'apex (P0.5)** :
  ```
  PRÉCONDITION APEX CHOC : avant de coder skull_colossus → shockChain/shockAmpMult (#GG), lancer CONFIG-CE :
    {1 galvanizer T4 choc + 1 burn-poseur rang-2 + 1 stat-stick rang-1} vs IA round-2, N=30, seed 20260620.
    burst_DPS_eq réel vs théorique. Si écart > 40 % :
      → corriger 1 unité choc rang-1 avec fallback dégât direct non-nul AVANT de coder l'apex.
  ```
  ~15 lignes sim, non bloquant si écart < 40 %. **Source** : synergies §2.4/P4 + units-power.
- **PALIER CHOC-4 JAMAIS SPÉCIFIÉ = #HH NEUF, co-bloquant #GG (NOUVEAU round 9, synergies §2.2 + units §2.3)** :
  les paliers-4 (twists P1) de burn (`burnIgnoreShield`), bleed (`bleedPierceShield`), rot (amputation PV_max le
  plus élevé) ont un candidat **nommé** ; **choc-4 = vide** depuis 9 rounds. Le litige #GG (axe pour l'APEX
  rang-5) a capturé l'attention, mais le **palier-4** doit exister **quelle que soit la décision d'apex**.
  `rust_sentinel` rang-4 actuel = `stormcaller` rang-2 (op identique, viole #10) → **pas un vrai twist choc-4**.
  Coder P1 avec un choc-4 absent = les ghosteurs choc au shopTier 4 ne voient pas de payoff = perception de
  faiblesse structurelle (le problème de l'apex au palier intermédiaire).
  **DÉCISION (#HH CLOS round 10 par le critère #JJ → Option B, DÉCOUPLE #GG)** : la lentille synergies §2.2 a
  évalué les 2 options selon #JJ (cause contrôlée par le joueur) :
  | | Option A (arc → voisin ADVERSE) | Option B (`tickCount=2`, ticks du POSEUR) |
  |---|---|---|
  | Cause contrôlée | PARTIELLE (le voisin ciblé = placement adverse, hors contrôle async) | FORTE (la famille du poseur = compo du build) |
  | Verdict #JJ | PARTIEL | **FORT** |
  ```
  PALIER CHOC-4 = Option B (`tickCount=2`, ~3 lignes SIM) — TRANCHÉ :
    twist = « les 2 premiers ticks DoT de la famille du poseur de choc sont amplifiés »
    Cause = compo du build (FORTE #JJ). Distinct de l'apex (shockAmpMult = magnitude ; tickCount = durée).
    CLÉ : tickCount amplifie les DoTs actifs AU TICK, pas à la décharge → INDÉPENDANT de l'axe #GG.
    → Option B compatible avec axe A/B ET axe D → #HH NE CONTRAINT PLUS #GG. Test synergies.lua (invariant #22 étendu).
  ```
  **#HH CLOS ; #GG découplé** (l'apex rang-5 = NOUVELLE unité, axe à trancher séparément). Source : synergies
  §2.2 ; round-09 §1.0 (#JJ) ; balatrowiki.org/w/Jokers.
- **CONFIG-CE2 — la hiérarchie choc < poison est un problème de FIABILITÉ (axe D conditionnel à l'adversaire),
  pas de puissance (NOUVEAU round 9, synergies §2.3 + units §2.3, #JJ)** : les 3 mesures P0.5 traitent des
  leviers de puissance statique. Mais poison domine d'abord par son **horizon de payoff court** (stacks dès T2,
  weaken immédiat) et choc échoue d'abord parce que l'axe D **exige un DoT actif sur la cible = condition hors
  contrôle du joueur en async** (#JJ : ancrage adversaire non-reproductible). Aucune mesure n'isole `P(décharge à
  vide)`. **CONFIG-CE2 (P0.5, ~20 lignes sim)** :
  ```
  CONFIG-CE2 (Choc Fiabilité — axe D) : compo {1 galvanizer T4 + 1 burn-poseur r2 + 1 bleed-poseur r2}
    vs 3 configs : (a) ghost burn-seul (DoT actif → D favorable) (b) ghost tank-seul (sans DoT → D défavorable)
    (c) ghost mixte. N=20/config, seed 20260623+offset.
    discharge_effective_ratio = nb décharges amplifiant un DoT actif / nb décharges totales.
    Alarme : ratio < 0.40 en (b) → choc axe D CONDITIONNEL à l'adversaire → décision.
  CRITÈRE DE TRANCHAGE (NOUVEAU round 10, synergies §2.1, aligné #JJ — ferme « détection sans résolution ») :
    → DÉFAUT → Option A : 1 unité rang-3 choc avec on_attack {burn{dps=1,dur=60}} + shock{add=1}
      (auto-pose un DoT avant d'accumuler) = la fiabilité dépend du BUILD DU JOUEUR, pas de l'adversaire (#JJ).
      Analogue PoE Lightning Exposure (garantit le choc avant les DoT). ~1 ligne data, test headless.
    → FALLBACK → Option B (axe A/B) uniquement si l'auto-DoT crée une collision d'identité rang-3 burn (col A audit).
    Si ratio ≥ 0.40 : aucune correction ; DOCUMENTER inactif (traçabilité — un round futur ne re-cherche pas).
  ```
  Non bloquant si ratio ≥ 0.40. **Source** : synergies §2.1/§2.3 ; units §2.3 ; balatrowiki.org/w/Jokers
  (conditions sous contrôle > contextuelles) ; poewiki.net/wiki/Shock + /Ailment (Lightning Exposure auto-garanti).
- **AUDIT RANG-5 À 3 COLONNES E1/E2/E3 — le diagnostic R09 confondait DPS_frappe et DoT_dps (RÉVISÉ round 10,
  units §2.1/§2.3, DPS recalculés)** : le diagnostic R09 « `skull_colossus` carry burn DPS 0.131 qui domine
  `ash_maw`(0.100) » porte sur la **frappe MÉLÉE** (`dmg/cd`), PAS sur la contribution burn. Le burn_dps réel de
  `skull_colossus` = **4** (`units.lua:421-424`) — soit **ÉGAL à `cinder_cur` rang-2 et SOUS le rang-1
  `ash_moth`=7**. **`skull_colossus` n'est PAS un carry burn : c'est un TANK avec burn résiduel à niche ambiguë.**
  Le vrai problème n'est pas une collision de carry (son burn ne menace pas `ash_maw`) mais une **AMBIGUÏTÉ DE
  NICHE** (ni carry burn assez fort, ni bon tank avec taunt). Distinguer 3 axes orthogonaux :
  ```
  E1 DPS_frappe = dmg/cd | E2 DoT_dps = dps de l'effet | E3 = grant_team/règle d'équipe (oui/non)
    skull_colossus : E1=0.131 HAUT | E2=burn 4 BAS  | E3=AUCUN → tank-burn opaque (niche ambiguë)
    deep_kraken    : E1=0.154 HAUT | E2=poison 4 HAUT| E3=AUCUN → confond carry/transform (problème INVERSE)
  → les deux ont des problèmes DIFFÉRENTS → remèdes DIFFÉRENTS (E2 bas vs E2 haut).
  ```
  **REMÈDE `skull_colossus` (RESTE burn, data, 0 moteur)** :
  ```
  Option A (recommandée) : burn_dps 4→8 (cohérent ash_moth=7), aggro=40 maintenu → "mur qui brûle aussi fort
    que les meilleurs poseurs" (niche tank-burn LISIBLE, distinct d'ash_maw qui a burnNoDecay team).
  Option B (alt) : burn{dps=4} + on_death_ally{spread_burn frac=1.0, dps=10} → "crémateur d'alliés" (mort
    d'allié = explosion de feu, on_death allié = broadcast déjà câblé, distinct de plague_pyre = mort d'ENNEMI).
  ```
  **REMÈDE `deep_kraken` (croisé OU AoE, data + ≤5 lignes SIM si target neuf)** :
  ```
  Option B (recommandée) : poison{dps=4, target="column"} AoE + grant_team{poisonNoShield} (mini-flag, contrat
    rang-5) = "l'étreinte du Kraken vide la colonne" (DA cohérent : tentacules + enveniment). target="column"
    si non câblé = ~5 lignes SIM (Q4 units : Arena:neighborsOf couvre-t-il les colonnes ? à vérifier).
  Option A (alt) : croisé poison-rot (poison{dps=2} + rot{...}) = "le venin empoisonne ET gangrène".
  ```
  **Golden à grep AVANT tout change** (Q1 units : `skull_colossus`/`deep_kraken` dans `golden.lua:17` seed
  970156547 ? burn_dps=8 peut déclencher `DOT_CAP_MULT=3` → rebaseline explicite, invariant #5). Q3 units
  (distinction `skull_colossus` dps=8 vs `pyre_tender` dps=10 → tank-burn lent qui tient long vs glass-cannon
  rapide) à confirmer en sim. Cloudfall/StS : « if any choice is obviously the best, the designers have failed ».
  **Source** : units §2.1/§2.3 ; `units.lua:421-424`/`:437-440`/`:100`/`:231-236` ; cloudfallstudios.com/sts (2020).
- **Audit `burst_DPS_eq` de `galvanizer` CONDITIONNEL à l'axe D (NOUVEAU round 9, units §2.3/P-B)** : l'axe D
  change la valeur de `dynamo_priest` (transfer multi-cible, charge 2 cibles DoT-actives) vs `galvanizer`
  (mono-cible fort). **Ne pas figer l'audit `burst_DPS_eq` de `galvanizer` avant #GG** (= juger une hiérarchie
  provisoire). Note doc §3.1a. **Source** : units §2.3 ; gdcvault.com/TFT.
- **Trous d'archétype** : **regen = 1 unité** (`plague_doctor`) → singleton vs ladder ; **AoE/frappe
  multiple = 0**, **heal-on-kill = 0** → intentionnels ou opportunités v1 ? **11 unités shield/tank**
  = enablers transversaux (litige #F « aucun »). `runestone_golem` anomalie budget (§3.1b).
- **Leurre choc rang-1 (NOUVEAU round 4, #Q — CONDITIONNEL)** : **si** la latence VRR du choc en early
  (§3.4 sim) > 3 combats → ajouter **1 unité choc rang-1 stat-stick + 1 stack auto** (facilite la
  découverte sans casser l'axe DoT, compatible plancher ≥2/famille). **Ne pas créer par réflexe** —
  conditionnel à la sim. Niche distincte de `stormcaller` à vérifier.
- **Source** : units §2.1/§2.3/§Q3-Q4, retention §2.3 ; Giovannetti GDC 2019 ; Entalto 2026 ; grep synthé
  `shockChain`. **Décision data, pas sim** (sauf le leurre). Évite le power creep (marvel-snap §9.2).

### 3.8 Corriger `afflictionCount` (Option C2) — le faux signal `plague_communion` de `wither_bloom` — **PRIORITÉ 1 (NOUVEAU round 5, code-vérifié)**

- **Bug code-vérifié (synthé, relu `arena.lua:234-242` + `units.lua:280-287`)** : `afflictionCount` compte la
  **PRÉSENCE** d'une famille (`if d.burn then n=n+1`…), **pas le dps**. Or `wither_bloom` pose `rot` +
  `bleed{dps=0}` (pur slow) + `poison{dps=0}` (pur weaken) → **3 familles présentes** → `afflictionCount ≥ 2`
  → **déclenche `plague_communion` (+25 % de TOUS nos dégâts) à lui seul**, et une aura `miasma_acolyte`
  (+50 % poison dps) posée sur lui **amplifie un dps de 0** (gaspillage silencieux). **Fausse promesse
  mécanique non documentée** (units §2.3).
- **Remède — Option C2 (1 ligne, recommandée)** : `afflictionCount` ne compte une famille que si elle a un
  **dps/stacks réel** (`bleed.dps>0`, `poison[i].dps>0`, `rot.dps>0` / pour le choc, `stacks>0`), pas la
  simple présence. **Garde-fou code-vérifié** : `dischargeShock` lit `target.dots.shock.stacks` (**pas**
  `afflictionCount`) → C2 **n'affecte pas l'invariant #22** ; **rebaseline golden seulement si `wither_bloom`-
  seul y figure** (à vérifier avant le commit). **Zone sans test** → `tests/synergies.lua` : `wither_bloom`
  seul → `afflictionCount = 1` (rot à dps>0), **pas 3**.
- **Pourquoi PRÉCONDITION du tuning `plague_communion` (§4.2)** : régler la magnitude d'une relique qui se
  déclenche **faussement** = tuner sur une base cassée. **C2 doit précéder P1.5a.**
- **Option C1 (différée P1.5b)** : op dédié `apply_status` (slow/weaken sans dps) → nettoie `wither_bloom`,
  `marrow_drinker`, les auras grant_bleed proprement. **C1 = la cible propre, mais C2 ferme le faux signal
  maintenant sans nouveau moteur** ; C1 naîtra quand les types P1 auront besoin de conditions orthogonales.
- **CONSÉQUENCE SUR `wither_bloom` — litige #CC (NOUVEAU round 7, units §1.5/Q1)** : après C2, `wither_bloom`
  (rot{base=2} + bleed{dps=0} + poison{dps=0}) compte **1 famille active** (rot), pas 3 → **ne déclenche plus
  `plague_communion` seul** (objectif atteint). **MAIS** son rôle de « **proxy multi-affliction** » s'effondre
  (il pose 3 familles dont 2 inertes en dps ; une aura `miasma_acolyte` posée sur lui amplifierait un dps de 0).
  → **à trancher avant P1.5b (litige #CC)** : (a) **reconcevoir** avec des dps non-nuls sur bleed/poison (le
  slow/weaken deviennent secondaires) → vrai multi-affliction ; (b) **accepter** un rot-T3 + slow + weaken
  cosmétiques (documenter). **Lié à C1** (`apply_status` le nettoierait proprement). **Non bloquant P0.5** (C2
  ferme le faux signal ; la reconception est P1.5b).
- **CRITÈRE DE TRANCHEMENT #CC DOCUMENTÉ AVANT P1 (NOUVEAU round 8, relics §2.5 + synergies Q4)** : `wither_bloom`
  est en `U.pool` **maintenant** ; reporter le tranchement à P1.5b **sans critère** fait entrer P1 avec une unité
  au rôle « indécis » — en P1, son `dot_family=rot` ne contribue qu'au palier rot (1 fois), mais les joueurs qui
  l'ont auront l'impression d'un multi-affliction = **fausse attribution** ; + col B : si elle reste rot-T3, son
  rôle vs `pit_maw` (rot équipe ennemie) est flou. **Documenter le critère MAINTENANT (code en P1.5b)** :
  ```
  Critère #CC (à trancher AVANT de coder P1) :
  - Option (a) : CONFIG-XY = 1 wither_bloom + 1 poseur bleed + 1 poseur poison vs IA, N=30 ;
    si bleed ET poison se déclenchent et interagissent avec leur palier de type respectif
    → reconcevoir dps bleed/poison non-nuls (vrai multi-affliction, dot_family=rot, contribue rot ET cross-type).
  - Option (b) : si dps trop bas → renommer i18n en rot pur (« DISTILLATEUR DE VIDE »)
    + retirer de U.pool si écart < 20 % avec pit_maw (col B §3.1).
  ```
  0 code maintenant, 0 invariant.
- **Source** : units §2.3/P-C + §1.5/Q1 ; vérif code synthé. **Garde-fou** : ≤1 ligne moteur, 1 test ajouté,
  0 invariant data (invariant #22 préservé après vérif `dischargeShock`).

### 3.9 CONFIG-PC — la magnitude de `plague_communion` est une sim BLOQUANTE (le seul `more` hors-cap) — **PRIORITÉ 1 (NOUVEAU round 6, relics §2.1/Prop-A)**

- **Pourquoi BLOQUANTE et plus « tuning ultérieur » (relics §2.1)** : `plague_communion` (`plagueAmp=0.25`) est
  le **SEUL `more` hors-cap du système** (`arena.lua:252`, post-cap, vérifié round 4) **jamais simulé contre un
  ghost tier-3/4**. Risque code-ancré : **`festering` lève le cap de stacks** (`poisonNoCap`, `ops.lua:22`) →
  sur une cible >8 stacks, `plague_communion` amplifie un tick **hors-cap** = la **seule interaction `more` +
  `poisonNoCap`** du système, **non simulée**. **NOTE ROUND 9 (#J re-tranché, §4.2)** : la **condition
  d'activation passe de la CIBLE (`afflictionCount`) à la COMPO DU JOUEUR (`dot_family_count ≥ 2`)** → CONFIG-PC
  doit mesurer l'activation sur la compo du joueur (≥2 familles dans le build), PAS sur la cible. L'interaction
  `more` + `poisonNoCap` hors-cap reste à borner (le joueur multi-famille peut inclure `festering`). La
  comparaison `bloodstone` (+14 % toujours, frappe ponctuelle) vs `plague_communion` (+25 % sur frappe ET DoT
  **continu**) est **non-homogène** (les DoT tiquent continûment → outperform **non-linéaire**). **Précédent
  décisif** : MegaCrit (Giovannetti GDC 2019) « we run 18 million simulated runs per balance patch » → **une
  magnitude non validée par sim est une dette de balance, pas un PH**.
- **CONFIG-PC (ajoutée à la matrice sim §3.4, ~20 lignes, golden inchangé = nouvelle config)** :
  `build = {festering×2, plague_bearer, chitin_drone} + plague_communion` vs **sans** relique, plateau carré,
  **N=50, seed `20260623`**. Adversaire : ghost tier-3 snapstore ou équipe IA rang-3/4.
  | Mesure | Seuil |
  |---|---|
  | win% avec relique | cible **[0,55 ; 0,65]** (tier-4 = avantage **sans dominer**) |
  | % de combats où `dot_family_count(JOUEUR) ≥ 2` (condition #J round 9) | = activation réelle (build-dépendante) |
- **Décisions selon le résultat** : **win% > 0,70 OU activation > 80 %** → réduire `plagueAmp` à **0,15** OU
  ajouter exception **`NOT poisonNoCap`** (couper le combo `festering`+`plagueAmp` hors-cap). **NOTE ROUND 9** :
  l'option (c) scalante **sur la cible est ANNULÉE (§4.2, #JJ)** ; si une scalante reste souhaitable, elle doit
  scaler sur `dot_family_count(joueur)` (3 familles → +30/4 → +40), pas sur les afflictions de la cible.
- **Source** : relics §2.1/Prop-A ; `arena.lua:252` (more post-cap) ; `ops.lua:22` (poisonNoCap) ;
  `ops.lua:135-140` (contagion) ; gamedeveloper.com (GDC 2019 MegaCrit). **Garde-fou** : config sim
  **nouvelle** (pas une modif du golden) ; toute baisse de `plagueAmp` rebaseline le golden si `plague_communion`
  y figure. **BLOQUANTE avant de figer la magnitude (P0.5), pas P1.5a/P3.**

### 3.10 `offer_decision_quality` — mesurer la DENSITÉ DE DÉCISIONS RÉELLES de l'offre 1-parmi-3 — **PRIORITÉ 1 (NOUVEAU round 7, relics §2.1/Prop-A), précondition P1**

- **Lacune (relics §2.1)** : la roadmap corrige le **CONTENU** du pool (garantie B-E §4.1, déprio F §4.6,
  arcs temporels §4.8) mais **ne mesure JAMAIS la QUALITÉ DE DÉCISION** de l'offre. **Keith Burgun**
  (keithburgun.net/pick-1-of-3, vérifié) : « when powers are loosely coupled, the decision is random/arbitrary ;
  when highly coupled with no restrictions, the choice is obvious — neither is interesting. » La garantie de
  pertinence peut être satisfaite **formellement** tout en produisant une offre **triviale** (1 option dominante)
  ou **arbitraire** (0 tension).
- **Pourquoi PRÉCONDITION P1** : si la qualité d'offre est faible **avant** P1, les paliers de type peuvent la
  **dégrader encore** (un palier-4 burn rend les reliques B burn encore plus triviales). Connaître la baseline
  AVANT permet de spécifier les twists pour **diversifier**, pas homogénéiser.
- **Quoi (sim ~15 lignes, s'insère dans CONFIG-PC §3.9, le `lift` existe déjà) — SEGMENTÉE par tier +
  PSEUDO-DÉCISION (RAFFINÉ round 8, relics §2.1/Prop-A)** : le seuil **uniforme** « 40 % triviales » est
  **insuffisant** pour 2 raisons code-ancrées :
  1. **Trivialité STRUCTURELLE early non-tunable** : 4 reliques A (universelles) sur 21 ; en tier-1, 3 A sur 7
     éligibles → **`P(≥1 A dans une offre de 3) = 1 − C(4,3)/C(7,3) ≈ 88,6 %`** (hypergéométrique) → ~89 % des
     offres early contiennent une A « meilleure par défaut » si le build n'est pas engagé = **impossible <40 %
     en early STRUCTURELLEMENT** (pas par tuning). Facile en late (A diluées dans le pool T4).
  2. **« Triviale » (lift>2×) manque la PSEUDO-DÉCISION** : 2 reliques B de la même famille ont un lift
     similaire (toutes deux amplifient le même axe) → classées « non-triviales » alors que c'est **0 tension
     de direction**. Burgun : « interesting = meaningful alternatives that cost something not to take » — le
     lift capture le cas trivial mais pas l'**absence d'alternative DISTINCTE**.
  → **(a) Cibles PAR TIER D'AVANCÉE** : early (wins 0-1) **< 60 %** triviales (structurel) ; mid (2-4) **< 40 %** ;
  late (5+) **< 30 %**. **(b) Sous-métrique DIVERGENCE DE CONSÉQUENCE** : pour chaque offre non-triviale, si les
  2 options au lift le plus proche ciblent la **même `dot_family`** OU sont deux A → classer **« pseudo-décision »**
  (cible **< 20 %**). **(c) % d'offres en TENSION RÉELLE** = total − triviales − arbitraires − pseudo-décisions
  (cible **> 35 %**). La définition de base reste : **triviale** = `lift(1re) > 2× max(lift des 2 autres)` ;
  **arbitraire** = `std_dev(lift des 3) < 0,02`.
- **Baseline mesurée sur le pool ACTUEL (21 reliques) AVANT P1** (Q1 relics) — **POST-correction-garantie-early
  (NOUVEAU round 8, relics §2.3)** : la garantie renforcée en early (§4.1, priorité 3) **change** la baseline →
  la mesurer **sur le pool post-correction** OU **mesurer les deux et documenter le delta** (« gain de la
  garantie » vs « gain de P1 ») pour ne pas attribuer un gain de garantie à P1. **Garde-fou** : sim headless,
  **dépend de P0.5** (`dot_family` pour les B), 0 invariant. **Pourquoi maintenant** : si la baseline mesure des
  pseudo-décisions comme bonnes, P1 (types) peut les dégrader sans que la métrique le détecte. **Source** : relics
  §2.1/Prop-A ; keithburgun.net/pick-1-of-3 ; Wayline.io (« overlaps and genuine conflicts ») ; `tools/sim.lua`.

---

## 4. CHANTIER P1.5a — Reliques data-pure (v0.9.3, // P0/P0.5) — **REMONTÉ round 2, CORRIGÉ rounds 4-7**

> **Pourquoi REMONTÉ et parallélisé** : relics §2.6 — la garantie de pertinence, la déprio F et le
> rôle temporel sont **data pure sans dépendance** (quelques heures). **Round 4 a CORRIGÉ 2 décisions**
> bâties sur une mauvaise lecture du code : `plague_communion` **gardée telle quelle** (pas de
> reformulation) ; `feeding_frenzy` **confirmée correcte** (1 test). Nouveau litige **#O**
> (`famines_math` anti-growth).

### 4.1 Garantie de pertinence d'offre = sur B-E SEULEMENT — **PRIORITÉ 1**

- **Quoi (relics §2.2)** : « parmi les 3 offres, **si ≥1 est de catégorie B-E**, alors ≥1 de ces B-E a
  son type-cible présent sur le plateau courant ». Les **A (stats plates) sont offertes librement**.
  **Évite le bug « pertinence triviale »** (`carapace`/`aegis`/`whetstone` n'ont pas de type-cible).
- **Source** : TFT *dead choices* ; HS:BG ≤2-coût universels, **nos A non universels** ; StS commun=
  universel / boss=build-defining.
- **Garde-fou invariant #3** : « même seed+wins » → « même seed+wins+**compo** ». **Signature** :
  `rollRelicChoices(n)` → `rollRelicChoices(n, compo)` (**vérifié** : actuelle = `n` seul,
  `state.lua:339`) ; compo en **donnée pure**. **Modifier `tests/relics.lua` #3 AVANT le code.**
- **Risque dégénéré (progression §2.5)** : au round ≤4, le plateau = rang-1 de la famille commune → la
  garantie **confirme** le 1er axe. **Mitigation** : si la famille pertinente a ≥5 unités rang-1,
  vérifier qu'une des 3 propose un type **non encore présent**. → **drapeau** (progression Q4 :
  distribution des familles au round 3 sur 200 seeds).
- **GARANTIE RENFORCÉE EN EARLY — PRIORITÉ 3 (NOUVEAU round 7, relics §2.3/Prop-C)** : en early (plateau 3
  slots = 1 burn + 1 bleed + 1 poison), la garantie est satisfaite **simultanément** pour les 3 familles →
  l'offre propose un B **arbitraire** qui « confirme un axe à 33 % » au lieu d'orienter (Burgun : « orientation
  requires a cost to not committing » ; en early, rien n'est perdu à ne pas committer). **Décision (P1.5a, ~3
  lignes `rollRelicChoices`)** : pour les rounds **≤3 wins**, un B est « pertinent » **seulement si** sa famille
  ≥50 % de la compo **OU** ≥2 unités de cette famille achetées. Empêche la satisfaction triviale en early.
  **NON bloquant** (la garantie actuelle > pas de garantie). Test #3 adapté avec le reste.
- **NOTE D'INTENTION P3 — DROUGHT PROTECTION RELIQUES (NOUVEAU round 8, relics §2.4/Prop-D — doc, 0 code maintenant)** :
  le Fisher-Yates seedé des reliques (00-state §2.2) n'a **aucune** protection contre la sécheresse d'archétype
  (≠ **rare-climb StS** : +1 % de rare par commune vue) → un joueur burn qui ne voit aucune relique burn en 6
  rounds installe la frustration « unlucky RNG ». **La garantie de pertinence ci-dessus atténue PARTIELLEMENT**
  (si une B est offerte, sa famille est présente) **mais ne garantit pas qu'une B de l'archétype dominant soit
  DANS l'offre**. **Intention à implémenter en P3 (pas maintenant)** :
  ```
  Si le build a ≥60 % dot_family depuis ≥2 offres sans une B/E de cette famille,
  augmenter le poids de tirage seedé de +20 %/offre manquée (cap +60 %, JAMAIS garantie dure).
  Déterministe : poids depuis l'état seedé du run. Analogue rare-climb StS.
  S'active SEULEMENT si la garantie de pertinence a été satisfaite mais n'a pas produit la bonne B
  (≠ doublement de la garantie — relics Q4 : éviter d'aggraver la trivialité d'une famille dominante).
  ```
  **Pas une pity-garantie (rejet round 7 maintenu)** : poids supplémentaire, pas garantie. Évite la re-découverte
  en P3. Source : competitive/slay-the-spire.md §3.2 ; Medium/@JeongHyeonUk (adaptive RNG).

### 4.2 `plague_communion` — #J RE-TRANCHÉ round 9 : ANCRAGE SUR LA COMPO DU JOUEUR (`dot_family_count ≥ 2`), pas sur la cible — **#JJ alignement payoff↔agence**

> **RE-TRANCHEMENT ROUND 9 (relics §2.2/Prop-A, #JJ) — correction d'une décision maintenue 6 rounds :**
> les rounds 3-8 ont gardé `plague_communion` "telle quelle" en s'appuyant sur le fait que le **mécanisme**
> est correct (vérifié code). **Mais le PAYOFF n'est pas ALIGNÉ sur la STRATÉGIE qu'il prétend récompenser** :
> la condition `afflictionCount(target.dots) >= 2` porte sur la **CIBLE adverse**, pas sur la **composition du
> JOUEUR**. Conséquences (relics §2.2) : (a) un build **mono-famille** (burn avec propagation T3) la déclenche ;
> (b) un build **multi-famille restrictif** (bleed pur sans contagion) ne la déclenche pas ; (c) en **async**,
> le flag profite au ghost selon ce que **l'adversaire** subit — **hors contrôle du joueur** (#JJ : ancrage
> adversaire non-reproductible côté agence) ; (d) la relique la plus transformative du pool est **AVEUGLE au
> choix de familles**, la dimension build-defining #1. Le rejet round 3 de la "scalante par famille
> majoritaire" était correct (trop complexe), mais il ne validait PAS l'original (relics §2.2, note historique).

- **CE QUE LA RELIQUE FAIT AUJOURD'HUI (vérif synthé `arena.lua:248-252` + `relics.lua:57-58`)** : `plagueAmp =
  0.25` amplifie +25 % de nos dégâts contre une cible portant ≥2 **familles** d'affliction. **Condition sur la
  CIBLE.**
- **DÉCISION (#J FINAL round 9, ~5 lignes data — plus simple que la variante §11)** :
  ```
  plague_communion : plagueAmp=0.25 s'active si dot_family_count(BUILD JOUEUR) >= 2
    (nombre de familles DoT distinctes dans la compo, lu au combat_start). NON sur la cible.
    → devient LE payoff relique des builds MULTI-TYPES (interagit directement avec P1 seuil 2/4).
    → corrige l'incohérence async (ne dépend plus de ce que l'adversaire subit).
    → satisfait le critère COURONNEUR §4.11 dimension (3) "conditionnel à la composition".
  ```
  - **PRÉREQUIS** : `dot_family` posé sur chaque unité (P0.5, §3.3) — info déjà disponible post-P0.5.
  - **GARDE-FOU GOLDEN (à vérifier AVANT de coder)** : grep le build golden (`golden.lua:17`, seed 970156547).
    Si le build a ≥2 familles DoT distinctes, le flag passe **INACTIF→ACTIF** → **rebaseline EXPLICITE**
    requise (invariant #5). Q1 relics : impact golden à vérifier.
  - **ANNULE la variante §11 "scalante sur le seuil RÉEL de la cible"** (maintenait l'ancrage cible — incompatible
    avec #JJ).
  - **CONFIG-PC (§3.9) reste valide** mais sa **condition d'activation change** : mesurer l'activation sur
    `dot_family_count ≥ 2` **du joueur**, pas sur la cible (la magnitude reste une sim bloquante P0.5 ;
    le combo `festering`/`poisonNoCap` hors-cap reste à borner).
- **Source** : `relics.lua:57-58` (relu round 9) ; relics §2.2/Prop-A ; keithburgun.net/pick-1-of-3 ; #JJ ;
  relics §2.1/Prop-A (CONFIG-PC) ; MegaCrit GDC 2019 (18M runs). **Garde-fou** : data-only (condition + params) ;
  rebaseline golden conditionnel ; `tests/relics.lua` #18-21 à revérifier (la condition change → vérifier qu'un
  scénario ne présuppose pas l'ancien comportement cible, relics §3-Prop-A).

### 4.3 `feeding_frenzy` CONFIRMÉE CORRECTE (récompense les kills ennemis) — **NOUVEAU round 4** *(la « refonte » proposée est ANNULÉE)*

- **Vérif synthétiseur (`ops.lua:208-217`, `relics.lua:38-39`, `i18n/en.lua:389`)** : l'op
  `frenzy_gain` **existe** (snowball de `me.dmg`, cappé 6 stacks) ; l'arène broadcast `on_death`
  **aux ENNEMIS du mort** (`ctx.source` = une de NOS unités qui survit au kill) ; i18n = « **Each
  enemy that dies** makes your units strike harder ». → la relique **récompense déjà les kills
  ennemis**, **pas** les morts alliées. La crainte du round 4 (« bug silencieux » / « archétype
  kamikaze » / « reformuler ») reposait sur une **non-lecture du code**.
- **DÉCISION** : **aucune refonte.** Seul reste-t-il **1 test** que l'`on_death` ne profite qu'au camp
  survivant (zone de test `tests/relics.lua` ; coût ~0).
- **CORRECTION DE CLASSIFICATION ROUND 9 (relics §2.4, Wayline luxury-vs-enabler)** : `feeding_frenzy` est
  classée **« égalisateur de matchup »** dans `relics-design.md §1 principe #3` — **inexact**. `on_death` est
  différé : dans un matchup FACILE (kill rapide) le bonus arrive après le cap naturel ; dans un matchup
  DIFFICILE (tank adverse 40 aggro + `second_breath`) le bruiser peut ne JAMAIS obtenir le 1er kill →
  **silencieuse exactement quand on en aurait besoin**. C'est une **LUXE** (forte quand on gagne déjà), PAS un
  égalisateur (Wayline.io : « items most useful when you're already winning are luxuries, not enablers »).
  **Décision (doc, 0 code)** : corriger la classification dans `relics-design.md §1` → `feeding_frenzy` =
  **payoff bruiser/snowball, PAS égalisateur**. La **garantie de pertinence (§4.1)** doit la cibler aux builds
  à **aggro ≥20** (bruisers/tanks), pas la proposer à un joueur sans bruiser (= garantie satisfaite
  incorrectement). **≠ retirer la relique** (le snowball est un archétype valide en tier-3). Source :
  `relics.lua:39` ; wayline.io/blog/roguelike-itemization ; relics-design.md §1.
- **Leçon (round-04.md §5)** : une critique qui dépend de l'existence d'un op DOIT grep le code avant
  de proposer une refonte.

### 4.4 `second_breath` reste universelle tier-3 (NE PAS conditionner) — **PRIORITÉ 1**

- **Quoi (relics §2.4, vérif `relics.lua:47`)** : relique **défensive universelle de tier-3** (analogue
  Akabeko/Orichalcum StS). Son **tier (3, pas 4)** est déjà le garde-fou. Conditionner = fusionner deux
  reliques (tall XOR positionnement). Si trop forte en sim → monter tier ou réduire la survie (0.5 PV),
  **pas** ajouter une condition incohérente.
- **Source** : slaythespire.wiki.gg/wiki/Relics ; relics §2.4.

### 4.5 `famines_math` — #O CLOS round 6 : option (a) « 3 plus coûteuses » + spec `R.apply` (tri) + test #21 — **PRIORITÉ 1 (litige #O CLOS round 6)**

- **Conflit code-vérifié (relics §2.3, `relics.lua:34-35`)** : `relic_few_units {max=3, dmgInc=0.30,
  hpInc=0.20}` → bonus tant que `#comp ≤ 3`. Les `SLOT_GRANT_ROUNDS` (`state.lua:50`, 2-7, **6 grants
  automatiques**) **offrent** des slots ; **accepter un 4e slot SUPPRIME le bonus** → la relique rend le
  joueur **adverse à sa propre progression** par défaut (refuser 4 grants pour garder le bonus) = contrainte
  permanente sur la croissance (≠ « scope conditionnel » StS, qui est *active*). Pilier reliques (CLAUDE §2 :
  « égalisateur, jamais gate ») pris en défaut.
- **#O CLOS round 6 → OPTION (a) actée (relics §2.3/Prop-C)** : « **tes 3 unités les plus COÛTEUSES ont
  +30 % dmg / +20 % HP** » → toujours applicable, **ne pénalise pas** l'acceptation de slots, préserve le
  signal tall. **Pourquoi trancher AVANT P1.5a et pas « en P1.5a » (relics §2.3)** : l'option (a) **MODIFIE
  `R.apply`** (aujourd'hui `ipairs` sans tri, évalue `n = #comp`) → si on entre en P1.5a avec le code courant,
  la garantie B-E (§4.1) est implémentée avec `famines_math` dans un **état indéfini**.
- **SPEC P1.5a — TRI STABLE OBLIGATOIRE (RAFFINÉ round 7, relics §1.3, NON-NÉGOCIABLE)** : dans `R.apply`
  (`relics.lua:77-94`), **avant la boucle**, trier par coût **AVEC clé secondaire `id`** (sinon non-
  déterministe) — **`table.sort` en Lua N'EST PAS stable** (lua.org/manual/5.1#5.5) → 2 unités de **même coût**
  (fréquent : 2 rang-3) produiraient un ordre **variable selon l'insertion** = **viole l'invariant #2
  (déterminisme)** → un snapshot async rejoué donnerait un résultat différent (bug silencieux). Spec correcte :
  ```lua
  table.sort(comp, function(a,b)
    local c1, c2 = (a.cost or a.rank or 0), (b.cost or b.rank or 0)
    if c1 ~= c2 then return c1 > c2 else return a.id < b.id end  -- clé secondaire id
  end)
  ```
  appliquer le bonus aux **3 premiers seulement** (`n_active = math.min(3, #sorted)`). **Adapter le test #21**
  (`tests/relics.lua`) : (a) ne crash pas sur une compo de 1-2 unités (tall extrême) **ET (b) ordre STABLE sur
  2 unités de même coût** (déterminisme).
- **Source** : relics §2.3/Prop-C + §1.3 + vérif code ; `state.lua:50` (SLOT_GRANT_ROUNDS) ; lua.org/manual/
  5.1#5.5 (`table.sort` non-stable) ; pilier reliques. **Garde-fou** : data (`R.apply`), **+1 modif de test
  (#21)** signalée AVANT le code, 0 invariant de SIM (l'invariant #2 est **renforcé** par le tri stable).

### 4.6 Déprioritiser les reliques F dès maintenant — **PRIORITÉ 1**

- **Coût chiffré (relics §2.2, hypergéométrique, recalculé round 4)** : 3 reliques F (runOp :
  `carrion_ledger`, `black_summons`, `beggars_lantern`) sur 21 → `P(≥1 F parmi 3) = 1 −
  C(18,3)/C(21,3) ≈ 0.387` → **25-33 % des ~4 offres/run contaminées** par une décision d'un type
  différent (économie du run vs build de combat).
- **Remède actionnable MAINTENANT** : dans `rollRelicChoices`, si un F est tiré **ET** ≥1 B-E
  disponible → remplacer le F par un B-E (**tir seedé additionnel du même RNG de run**, déterministe).
  Les F **restent dans le pool** (gagnent si le pool B-E est épuisé). **Disparaît quand le marchand
  arrive** (P1.5c).
- **Nuance reportée (relics Q4, litige mineur)** : les 3 F n'ont pas la même courbe de valeur
  (`carrion_ledger` early-fort/late-faible ; `black_summons` late-fort/nul-si-T5 ; `beggars_lantern`
  niche « max-doubles »). La règle « remplacer » tient pour les 3 ; affiner quand le marchand arrive.
- **3 ARCHÉTYPES ÉCONOMIQUES À DOCUMENTER AVANT LE MARCHAND P1.5c (NOUVEAU round 9, relics §2.5/Prop-C)** : les
  F créent une **tension économique distincte** que le marchand vendra sans décision stratégique lisible si elle
  n'est pas articulée. Tableau à ajouter (doc) :
  ```
  carrion_ledger (+6 XP)   → archétype "rush-tier" : accélère la vision des hauts rangs ; pertinent si déficit
                             d'XP passive.
  black_summons  (tier+1)  → archétype "spike-mid" : monte un palier à un moment précis ; NUL si shopTier ≥
                             MAX_TIER−1 (positionné tier-4 anti-snowball = effet early sur une relique tardive).
  beggars_lantern (tier−1) → archétype "max-dup" : concentre les cotes basses pour tripler ; CONFLIT avec la
                             montée de tier = la SEULE mécanique du jeu créant cette opposition = DÉCISION RÉELLE.
  ```
  Sans cette articulation, la garantie de pertinence des F (si elles restent partiellement dans le pool) ne peut
  pas être spécifiée (pertinent pour quel critère ? le build n'a pas de `runOp_family`). **Q3 relics** :
  `beggars_lantern` garantie de pertinence = pertinente si ≥2 unités même id (cherche les triples) OU ≥1 rang-1
  → **ouverte, à spécifier avec le marchand P1.5c.** Source : `relics.lua:64-66` ; competitive/balatro.md §7.3.
- **RE-TIER `carrion_ledger` (tier 3 → 2) — le gating doit aligner VALEUR PAR PHASE et DISPONIBILITÉ (NOUVEAU
  round 10, relics §2.2, `relics.lua:64-66` + cotes `00-state §4.3` relus)** : le tier-gating des F est basé sur
  le NUMÉRO DE TIER, pas sur la VALEUR ATTENDUE par phase. `carrion_ledger` (+6 XP) a sa valeur **MAXIMALE en
  EARLY** (shopTier 1→2 = 2 XP ; +6 XP BYPASS le 1er palier entier) ; en tier-3 elle n'apparaît qu'au round 2-3
  → son meilleur usage est manqué = **ANTI-OPTIMAL depuis le code**. StS2 (mobalytics) : « the relics that matter
  most in Act 1 function IMMEDIATELY ».
  ```
  carrion_ledger : tier 3 → 2 (disponible dès early, max-valeur early). 1 ligne data.
  beggars_lantern : tier 2 maintenu + garantie de pertinence (≥2 même id du build au rollRelicChoices).
  black_summons : tier 4 maintenu (spike-mid juste).
  ```
  **Golden-safe** (F = `runOp`, pas de combat ; vérifier invariants #18-21). Source : relics §2.2 ;
  `relics.lua:64-66` ; mobalytics.gg/slay-the-spire-2.
- **Source** : StS (slot marchand séparé) ; relics §2.2 + §2.5/Prop-C. **Garde-fou** : adapter test #3 AVANT.

### 4.7 Colonne « RÔLE TEMPOREL » des reliques — ACTIONNABLE, pas seulement doc — **PRIORITÉ 1 (litige #P, ÉLEVÉ round 5)**

- **Quoi (relics §2.1/Prop-A)** : auditer chaque relique par **rôle temporel** — **SHAPER-EARLY**
  (offerte round 1-3, oriente le build) / **SHAPER-MID** (tier≤3, amplifie le build établi) / **PAYOFF-LATE**
  (tier-4, récompense le commit) — et **vérifier que la fenêtre d'offre (tier ≤ wins, `state.lua:339`)
  correspond au rôle**.
- **ACTIONNABLE, pas que signaler (NOUVEAU round 5, relics §2.1)** : identifier un mismatch **sans le corriger**
  = savoir qu'il y a un bug sans le fixer. Pour chaque mismatch → **prescrire** : (a) **recatégoriser la
  fenêtre d'offre** dans `rollRelicChoices` (gating conditionnel) **OU** (b) **déclarer le mismatch accepté +
  documenter pourquoi**. Mismatchs code-ancrés à corriger :
  - **`forked_tongue` (tier-4, SHAPER-MID piégé en LATE)** : oriente vers le choc (shaper) mais offerte à 5+
    wins → arrive quand le build est engagé ailleurs. **Action : gating conditionnel** — offrable **dès 3 wins
    SI le build a ≥1 unité choc** (champ data `minBuiltChoc`, vérifié à `rollRelicChoices`). **Sous réserve**
    que le filtre reste **seedé/déterministe** → **invariant #3 reformulé** « même seed+wins+**compo** → même
    offre » (déjà requis par §4.1).
  - **`famines_math` (tier-3, SHAPER-EARLY en conflit avec les grants de slots)** : litige #O (§4.5).
  - **ROT sans payoff-late / CHOC sans shaper-mid** : voir §4.8 (critère affiné) → tickets P1.5b.
- **Source** : TFT cale ses augments build-defining à 2-1/3-2/4-2, ses payoffs en late (bunnymuffins.lol/
  augment-guide-for-set-13 ; Riot GDC 2022). **Indépendant de l'erreur §4.2** (l'outil reste bon). Doc + 1
  champ data de gating.

### 4.8 Règle reliques/archétype AFFINÉE : ≥1 shaper-mid (tier≤3) ET ≥1 payoff-late (tier-4) — **PRIORITÉ 1 (RAFFINÉ round 5, doc)**

- **Quoi (relics §2.2/Prop-B)** : le critère v5 « ≥2 reliques, `P(aucune) < 25 %` » compte le **pool TOTAL** —
  mais le gating (tier ≤ wins) crée des **arcs temporels** qu'il masque. **Critère affiné** : « chaque
  archétype engagé a **≥1 relique tier≤3 (shaper-mid accessible) ET ≥1 relique tier-4 (payoff-late)** ;
  `P<25 %` calculé **sur le pool tier≤3 séparément** ».
- **Preuve code-ancrée (relics §2.2, gating `00-state §2.2`)** : tableau mid/late par archétype —
  | Archétype | shaper-mid (tier≤3) | payoff-late (tier-4) | Verdict |
  |---|---|---|---|
  | Burn | ember_heart (B/T2) | everburn (E/T4) | ✅ |
  | Bleed | weeping_nail (B/T2) | open_wounds (E/T4) | ✅ limite |
  | Poison | kings_bowl (B/T2) | plague_communion (E/T4) | ✅ |
  | **Rot** | grave_cap (B/T2) | **AUCUNE** | ❌ pas de payoff-late |
  | **Choc** | **AUCUNE** | forked_tongue (E/T4) | ❌ pas de shaper-mid |
  | **Wide** | **ABSENT** | **ABSENT** | ❌ rien |
- **→ PROUVE** que **`shock_conduit` (shaper-mid choc) + `swarm_logic` (wide) + 1 relique rot tier-4** sont
  **nécessaires** (P1.5b). Un archétype sans arc late « plafonne en mid » (le joueur voit des ghosts T3-T4 avec
  un payoff late, lui non) — invisible dans le critère `P<25 %` brut.
- **+ Marquer les inc des reliques B `[PH-DÉPENDANT]` (NOUVEAU round 5, relics §2.3/Prop-C)** : les 4 B
  (`kings_bowl=0.20`/`ember_heart=0.30`/`weeping_nail`/`grave_cap=0.18`, `relics.lua:27-29`) sont calibrés sur
  la hiérarchie **DÉFECTUEUSE** actuelle (poison>choc). Ajouter au doc P1.5a : **« [PH-DÉPENDANT : réajustés
  APRÈS `--poison-frac`/`--no-weaken` (P0.5) + rééquilibrage (P3) — NE PAS finaliser ni bâtir les twists de
  type en supposant ces inc calibrés] »**. C'est une **dépendance causale**, pas un simple [PH]. Évite que P1
  grave une métastase doublement ancrée (inc B défectueux × palier type).
- **ORDRE DE CALIBRATION DES B EN P3 — famille faible d'abord (NOUVEAU round 8, relics §2.6/Prop-E)** : les inc
  actuels sont **inversés vs l'idéal** : `kings_bowl`(poison)=0,20 conservateur (correct, poison dominant) **mais**
  `weeping_nail`/`grave_cap`(bleed/rot faibles)=0,18 **< `ember_heart`(burn)=0,30** → les familles faibles ont un
  inc INFÉRIEUR à burn, ne compensant pas leur faiblesse. **Ordre P3 (NE PAS inverser — éviter de tuner le symptôme
  visible avant la cause invisible)** :
  ```
  (1) pool-repr → si poison sur-représenté → réduire kings_bowl (0,20 → 0,14-0,16)
  (2) pool-repr → si bleed/rot sous-représentés → augmenter weeping_nail/grave_cap (0,18 → 0,22)
  (3) recalibrer ember_heart en DERNIER (burn a déjà l'inc le plus haut + meilleure propagation)
  ```
  Cohérent avec l'anti-circularité §7.1 (inc-B post-rééquilibrage) ; ajoute la **priorité famille faible d'abord**.
- **Livrable** : section du doc d'audit. **0 code, 0 invariant.** Mesure exacte via sim (§7.4).

> **`forked_tongue` — #Q2-relics CLOS round 7 (`shockChain` consommé, grep synthé)** : la lentille reliques
> (Prop-D) demandait de grep `shockChain` pour savoir si `forked_tongue` est silencieuse. **Vérifié synthé
> (`src/`)** : `shockChain` **EST consommé** — `ops.lua:187` (`local chain = p.chain or (tf and tf.shockChain)
> or nil`) le lit pour fixer le nb de rebonds, `:276` le pose via `grant_team`. → **`forked_tongue` chaîne
> bien la décharge ; ce n'est NI un stub NI du code mort** → le **gating conditionnel (§4.7) est justifié**.
> **Dépendance restante — RE-CADRÉE round 8 (#GG)** : `shockChain`/`dischargeShock` est un **rebond de décharge
> BURST (axe A/B)** ; l'axe D (ampli du 1er tick DoT) **n'est PAS implémenté** (vérif synthé `arena.lua:342-388`
> + `:522`). Donc si l'axe D est adopté (P0.5), reformuler le « rebond » en propagation d'ampli DoT **n'est PAS
> « 0 moteur »** — c'est une **réécriture de `tickDots`/`dischargeShock` (SIM)** + un test (#22). **C'est le
> litige #GG (§3.7)** : Option 1 (2 axes coexistent — `forked_tongue`/apex restent en axe A/B burst) vs Option 2
> (`shockAmpMult` paramétrable → cohérence axe D). **À TRANCHER avant P1** ; la reformulation de `forked_tongue`
> reste la 1re tâche de P1.5a dès #G/#GG tranchés. Ne pas graver `N rebonds = f(count choc)` ni « 0 moteur » avant.

### 4.9 `sacred_shield` (invulnT=30) = quasi-inerte — valeur `[PH]` à régler — **NOUVEAU round 6 (relics §2.5, CODE-VÉRIFIÉ synthé)**

- **Code-vérifié (synthé, relu)** : `sacred_shield` (`relics.lua:46`) pose `invulnT = 30` via `grant_team` à
  `combat_start` ; la garde (`arena.lua:247`) est `if itf.invulnT and self.t < itf.invulnT then return 0 end`,
  et **`self.t` est en TICKS @ 60 fps** (`arena.lua:58` : `FATIGUE_START = 1020 -- ~17 s @ 60 fps (1 tick =
  1/60 s)`). → **`invulnT=30` = 30 ticks = 0,5 s** d'invulnérabilité d'ouverture = **~2,9 % d'un combat**.
  Une unité rang-1 (cd ~300-360 ticks) **ne peut pas frapper** dans les 30 premiers ticks → `sacred_shield`
  ne protège que de **quelques ticks de DoT d'ouverture** = **fonctionnellement quasi-inerte**.
- **Décision** : **ce n'est PAS un bug de signe** (l'unité EST bien en ticks). C'est une **valeur à régler** :
  noter `invulnT [PH]` — **cible 60-120 ticks (1-2 s)**, **valeur HAUTE (120) recommandée (RAFFINÉ round 7,
  relics §1.4)** : à 120 ticks, les unités cd-court (rang-1, cd≈180-240) **n'ont pas encore frappé** →
  l'invulnérabilité **bloque le 1er hit de chaque unité adverse** = avantage **lisible et visible**, pas
  « quelques ticks de DoT d'ouverture ». **Sans** dépasser `FATIGUE_START` (1020 ticks/17 s) qui en ferait une
  relique brisée. **4e relique à ré-évaluer côté valeur** (après les 3 F dépriorisées et `hollow_choir`
  pool-A). → **ticket P1.5a + tableau de tuning P3.**
- **Source** : relics §2.5/Prop-E ; vérif code synthé (`relics.lua:46` ; `arena.lua:247` ; `arena.lua:58`).
  **Garde-fou** : data (1 param), 0 invariant.

### 4.10 `hollow_choir` → candidat pool-A + option de réorientation `pierceShield` — **NOUVEAU round 6 (relics §2.4)**

- **Counter d'un archétype INEXISTANT (relics §2.4, `relics.lua:37-38` relu)** : `grant_team {pierceHeal=0.40}`
  perce 40 % des **soins** ennemis — mais **regen = 1 unité** (`plague_doctor`), **heal-on-kill = 0**
  (00-state §2.1) → utilité quasi-nulle en ~95 % des matchups = **bruit qui contamine les offres mid** en
  gating tier≤3 (réduit la qualité de l'offre 1-parmi-3). **Pas un égalisateur** (pilier §2). → **pool-A**
  (retrait de `U.pool`, garder en `U.order` ; réintégrer si ≥3 unités regen/heal-on-kill). Détaillé en col (H)
  §3.1.
- **Option de réorientation (Q2 relics, liée à #X)** : **`pierceShield=0.40`** au lieu de `pierceHeal` =
  counter-bouclier **léger, lisible, non-dominant** (réduit l'enveloppe des tanks temporairement, ne les
  détruit pas) → **1re relique de counter ACTIF**, orthogonale aux 4 défensives, qui comblerait partiellement
  la relique de contre-jeu méta (#X) **sans toucher la SIM**. **Déprio à P1.5b** : dépend de la colonne (I)
  (§3.1, « contre quoi optimal ») qui révèle si un counter-bouclier comble un trou **réel** de la méta.
- **Source** : relics §2.4/Prop-D + Q2 ; 00-state §2.1. **Garde-fou** : data, 0 invariant.
- **Vérif anti-doublon (NOUVEAU round 7, relics §1.5)** : si `hollow_choir` est réorientée en `pierceShield`,
  vérifier qu'elle **n'est pas un doublon fonctionnel** du twist bleed-4 `bleedPierceShield` (§5.2) — les deux
  réduisent les boucliers mais par mécanismes distincts (relique = flat instantané / twist = par tick) →
  **pas un doublon si les niveaux d'activation et magnitudes diffèrent significativement** (croiser colonne F).
- **DÉCISION GRAVÉE round 10 (PRIORITÉ 1 BLOQUANTE pour P1.5a, relics §2.4) — RÉORIENTÉE, pas retirée par
  inertie** : si `hollow_choir` est retirée de `U.pool` (pool-A) **sans décision de réorientation**, elle risque
  d'être oubliée en P1.5b puis re-ajoutée = **double travail**. La réorientation `pierceHeal → pierceShield` est
  une opération DATA (+ ~3 lignes SIM dans le gate `Arena:damage:432`, déjà doté de `ignoreShield`). **Décision
  explicite (doc, 0 code maintenant)** : `hollow_choir` est **RÉORIENTÉE (`pierceShield`) en P1.5b**, PAS retirée
  définitivement. La retirer de `U.pool` maintenant (pool-A, regen counter inexistant) reste correct ; la décision
  de réorienter est CONSIGNÉE pour éviter le retrait définitif par inertie. Source : relics §2.4 ;
  `arena.lua:432` (gate bouclier).

### 4.11 HIÉRARCHIE de BUILD-DEFINITION — les reliques E sont des AMPLIFICATEURS, pas des CRÉATEURS — **PRIORITÉ 1 (NOUVEAU round 7, relics §2.2/Prop-B, doc)**

- **Erreur à corriger (relics §2.2)** : le brouillon qualifie les reliques E (`forked_tongue`, `everburn`,
  `open_wounds`, `plague_communion`) de « payoffs-late **build-defining** » analogues aux **boss relics StS**.
  **Analogie paresseuse** : les boss relics StS ont un **downside explicite** (Ectoplasm : +1 énergie, plus
  d'or ; Fusion Hammer : +1 énergie, pas de forge) qui **FORCE** la construction autour d'elles (Giovannetti
  2018 : « the downside functions as a forced theming »). **Nos E n'ont AUCUN downside** (principe relics-
  design #2 : « aucune relique ne handicape ») → elles **amplifient** un archétype existant sans le **créer**
  (la décision « est-ce que ça aide mon build ? » est presque toujours oui si engagé). La vraie analogie StS =
  les **rares non-boss** (Dead Branch, Frozen Egg).
- **CONSÉQUENCE DE DESIGN DÉCISIVE** : si les E ne **créent** pas l'identité, **P1 (types) DOIT la créer** —
  sinon P1 est une **duplication fonctionnelle** des E (ambiguïté de design). **Cela élève P1 de « amélioration
  de contenu » à PRÉREQUIS DE FUN** (relics Q4 : les reliques seules ne portent **pas** 3-4 identités de build
  distinctes dans un run de 10 victoires).
- **Quoi (doc ~10 lignes, à mettre au ticket P1.5a)** : hiérarchie explicite —
  - **Types P1 = CRÉATEURS d'identité** (paliers 2/4, oriente le build sur 5-9 rounds) ;
  - **Reliques B = SHAPERS** (inc par famille, confirme et amplifie l'axe engagé) ;
  - **Reliques E = COURONNEURS de commit** (transforment une règle, payoff post-commit, pas pivot) ;
  - **Reliques A = FONDATIONS** universelles (pas de vote sur l'identité).
  Rend explicite que les E sont **correctement** en tier-4 (post-commit) ET que **P1 est leur prérequis**.
- **CRITÈRE DES COURONNEURS — les E FUTURES doivent OUVRIR une dimension (NOUVEAU round 9, relics §2.1/Prop-B,
  #JJ)** : les 4 E actuelles posent toutes un `teamFlag` via `grant_team` (`relics.lua:51-58` relu) = des
  toggles binaires ON/OFF sur des mécaniques existantes. « burn ne décroît plus » (`burnNoDecay`) est un
  **ajustement de paramètre**, pas un moment de couronnement (Burgun/Balatro : une relique build-defining
  **change la STRUCTURE des décisions suivantes**, ex. Dead Branch/Four Fingers ; `everburn` amplifie sans
  changer les décisions de placement/composition). **Inversion de hiérarchie émotionnelle** : les 4 B plates
  sont alors PLUS build-defining que les 4 E. **Critère éditorial (s'applique aux E FUTURES P1.5b+, PAS aux 4
  existantes — synthé NUANCE : principe #2 maintenu, et en async une E sans downside est préférable)** :
  ```
  Une relique E est build-defining ssi elle ouvre ≥1 des 3 dimensions :
    (1) nouvelle décision de PLACEMENT (interaction avec la topologie du sigil actif)
    (2) nouvelle interaction entre FAMILLES de DoT (pas juste amplifier une seule)
    (3) nouveau comportement CONDITIONNEL LIÉ À LA COMPOSITION (dot_family_count, aggro, copies)
  Un toggle de flag sans condition nouvelle = SHAPER (tier-2/3), PAS COURONNEMENT.
  ```
  **Statut honnête des 4 E** : `forked_tongue` → dimension placement implicite ; `everburn`/`open_wounds` →
  amplificateurs (acceptés) ; `plague_communion` → satisfait (3) **APRÈS le re-tranchement §4.2** (`dot_family
  _count ≥ 2` = condition de compo). La dimension (3) EST l'ancrage #JJ sur la compo du joueur.
- **RELIQUES A NON-IDENTITAIRES = CHOIX ACCEPTÉ (NOUVEAU round 9, relics §2.3/Prop-D)** : ≥89 % des offres early
  contiennent une A (hypergéo `1−C(4,3)/C(7,3) ≈ 88,6 %`). Les A ne portent pas de `dot_family` → le Nom de
  Build (§2.4bis) est un fallback (« ARPENTEUR NAISSANT ») jusqu'au round 2-3 **même avec le seuil progressif
  #EE**. **C'est VOULU** (les A = stabilisateurs neutres, pas définisseurs) — **documenter pour éviter qu'un
  round futur tente de le "corriger"** sans comprendre que c'est délibéré. L'identité de run vient des B/C/D/E.
  **Signal visuel A vs B/C/E (round 10, relics §1.2, RENDER ~30 min)** : glyphe grimdark discret sur les A
  (« socle », trait horizontal) vs B/C/E (« rune », icône plus complexe) — JAMAIS le mot « commun/rare » (casse
  le DA). Le joueur comprend que les A stabilisent, ne définissent pas. 0 SIM, aligné §2.6.
- **AUCUNE RELIQUE POSITIONNELLE — 4 CANDIDATS SIGIL-AWARE POUR P1.5b (NOUVEAU round 10, relics §2.5 — comble un
  TROU DE CATÉGORIE sur LA SIGNATURE)** : parmi les 21 reliques, **AUCUNE n'interagit avec la topologie du
  plateau** (les 5 sigils, les arêtes). Le plateau-graphe 3×3 est LE différenciateur (CLAUDE.md §2 : « la forme
  du plateau EST le graphe de synergies ») mais aucune relique ne récompense un sigil → le critère COURONNEURS
  (dimension placement) n'a aucune incarnation concrète. **Transfère async** : une relique positionnelle s'active
  au BUILD (lit le `shape` au `combat_start`) → snapshotable (`shape` déjà dans le format, 00-state §5),
  déterministe (arêtes fixes dans `shapes.lua`), async-safe. StS 2026 (nat1gaming) : les reliques mémorables sont
  CONTEXTUELLES (créent le « lock-in »).
  ```
  4 RELIQUES POSITIONNELLES (sigil-aware, 0 moteur, lisent shapes[shape].edges + spec.id) — P1.5b :
    | Sigil cible        | Relique       | Effet                                                  |
    | Croix (mono-carry) | axis_pact     | Le carry central (2,2) gagne +30 % dmg et +50 % HP     |
    | Ligne (conduit)    | bloodline     | Unités en ligne directe (même colonne) partagent 10 % dps max |
    | Anneau (chaîne)    | ring_hunger   | Chaque unité donne +5 % affliction_inc à ses 2 voisins de l'anneau |
    | Diamant (go-wide)  | horde_pact    | Unités rang-1/2 gagnent +10 HP chacune                 |
  ```
  **Satisfont COURONNEURS (dimension PLACEMENT). N'IMPOSENT pas de sigil** (le joueur peut changer avec `[s]`) —
  RÉCOMPENSENT un engagement déjà pris = **égalisateurs, pas gates** (relics-design §1). Distinct des reliques G
  (qui MODIFIENT la topologie, P4) : une positionnelle est catégoriquement plus légère (0 moteur). **Garde-fou
  saturation (Q4 relics)** : vérifier que `anneau + resonance_stone + ring_hunger` ne passe pas `DOT_CAP_MULT=3`
  AVANT de graver `resonance_stone` ET `ring_hunger` dans la même vague. **§8.1 (reliques G) aussi enrichi.**
  Source : relics §2.5 ; nat1gaming.com/sts2 ; switchbladegaming.com/sts2 ; `shapes.lua` ; CLAUDE.md §2.
- **GRANULARITÉ INTRA-FAMILLE sur UNE relique B (NOUVEAU round 10, relics §2.1, `relics.lua:26-29` relu — test
  poison)** : les 4 reliques B sont **architecturalement identiques** (`relic_affliction_inc`, seule la famille
  diffère) → un build poison-spread (`contagion`/propagation) et un build poison-weaken (`bile_spitter`) reçoivent
  EXACTEMENT la même `kings_bowl` (+20 % poisonInc) avec le même effet — deux stratégies radicalement différentes
  traitées identiquement. StS Paper Phrog = contre-exemple (amplifie le sous-build qui applique Vulnerable, pas
  tous les Silent). Le STYLE est dérivable des triggers au `combat_start` (compter `on_death`/`on_attacked` vs
  `on_hit` standard) = GRATUIT (0 moteur, lit `spec.effects`), async-safe. Si la saturation P1 montre que
  `DOT_CAP_MULT=3` est atteint avec B+aura+palier, une variante à périmètre PLUS ÉTROIT mais PLUS FORTE est le bon
  levier (tension intra-famille sans casser le cap).
  ```
  GRANULARITÉ INTRA-FAMILLE (test sur la famille DOMINANTE = poison, après sim, ~5 lignes data, 0 moteur) :
    kings_bowl (actuelle) : +20 % poisonInc — universel poison
    venom_covenant (nouvelle) : +15 % poisonInc PAR unité avec trigger on_death (spread) OU +15 % si build a une
      unité weaken (weaken) [à trancher en sim] → crée la tension de choix intra-famille.
    NE PAS faire pour toutes les B simultanément : poison d'abord, mesurer offer_decision_quality, puis étendre
      (1 levier à la fois). Q2 relics : interaction avec beggars_lantern + dup rang-1 à mesurer.
  ```
  Source : relics §2.1 ; `relics.lua:26-29` ; switchbladegaming.com/sts2 (Paper Phrog contextuel).
- **Q3 relics (à résoudre dans la spec P1)** : un palier-4 burn (`burnIgnoreShield`) + `everburn` = 2
  modificateurs de règle burn → profondeur (combo) ou redondance (double-buff) ? À trancher avant de coder
  les twists.
- **Source** : relics §2.2/Prop-B + §2.1/Prop-B + §2.3/Prop-D ; keithburgun.net/pick-1-of-3 ;
  competitive/balatro.md §5.3 ; slaythespire.wiki.gg (boss relics vs rares) ; Giovannetti 2018 (forced
  theming) ; relics-design §1 (principe #2 : pas de downside) ; #JJ. **Garde-fou** : doc, 0 code, 0 invariant.

---

## 5. CHANTIER P1 — Synergies par TYPE (v0.10, ~2 lots)

> **Pourquoi P1 (après P0.5)** : gap de contenu #1 (BRIEF/CLAUDE §7), identité de build précoce.
> Convergence : traits TFT, tribus HS:BG, héros Bazaar, alliances Underlords, classes Backpack.
> **Conditionné par P0.5** : `dot_family` posé (§3.3) + niches/budgets nommés (§3.1) + **poison non
> structurellement dominant** (§3.5) + **design global/adjacence décidé** (§3.6), sinon le palier
> amplifie sans distinction, grave une méta cassée, ou impose une refonte de tests.

### 5.1 Décision — les types SONT les 5 familles, lus depuis `dot_family`

- **Quoi** : type d'unité = **`dot_family`** (burn/bleed/poison/rot/choc), **pas** le champ `type`
  (visuel, **déjà pris**). **6e type non-DoT = LITIGE #F** : orienté **« aucun »** (les 11 unités
  shield/tank = enablers transversaux sans palier — units §Q4 ; leur dispersion DPS est un sujet
  d'**audit budget** §3.1b, **pas** un argument pour un palier). **Dépend de #G.** **Ne pas graver
  round 4.**
- **Source** : TFT « 4-5 types, ≤3 paliers » ; HS:BG « 4-5 tags pour un MVP » ; Underlords « max 6-8,
  jamais requis ». Roster déjà réparti (00-state §2.1).
- **Anti-analogie** : seuils **2 et 4 seulement** (jamais 2/4/6 de TFT). Raison mécaniste (synergies
  §1.4, **confirmée code round 4**) : sur 9 slots, un palier-6 consomme 6/9 = 67 % de la compo → pas de
  place pour un tank → front détruit immédiatement (ciblage déterministe colonne 1) → les 2/4 **forcent
  un optimum de diversité** (1 famille à 4 OU 2 familles à 2 + 5 slots libres).

### 5.2 Mécanique — bonus graduels, build-résolus, via `grant_team` ; **compteur GLOBAL PUR (#D CLOS round 6)**

- **Quoi** [PH valeurs, ouvertes] : 2 paliers/type, **compteur GLOBAL** (n'importe où sur le plateau).
  - **2 du même type** (global) → +20 % de l'effet du type.
  - **4 du même type** (global) → palier plus fort + **twist = 1 RÈGLE modifiée, ≤8 mots, puissance comparable**
    (lift ±0.05 en sim). Les twists « +1 stack cap » (chiffre opaque) sont **rejetés**.
- **#D CLOS round 6 → GLOBAL PUR (synergies §2.1/P1)** : **PAS** de condition d'adjacence sur le palier 4.
  TFT Galaxies (officiel) : les traits à **double condition** (count + adjacence) créent une **« dead zone »**
  mid-tier ; `--position-variance` mesure le win-rate, **pas la frustration de la dead-zone** ; **les auras
  d'adjacence sont DÉJÀ la couche positionnelle du type** (palier = « combien de burn » ; auras = « où tu les
  places » = 2 couches orthogonales/cumulatives). Détaillé en §3.6. **Gain : −2 invariants de test, aucun
  sigil hostile aux paliers de type.** (L'option hybride 2-global/4-adjacence du round 5 est **RETIRÉE**.)
- **GARDE-FOU twist #1 (synergies §2.4)** : un twist de palier 4 ne doit PAS être un **sous-cas d'un T3**
  (ex. « burn 4 = no-decay en front » = clone d'`ash_maw` `units.lua:232` → **rejeté**).
- **GARDE-FOU twist #2 (synergies §2.3)** : un twist de palier 4 ne doit PAS **VIDER la niche d'un T2**
  de la même famille. Ex. « poison 4 = slow cadence » **vide `chitin_drone`** ; « bleed 4 = aggravate
  équipe » **vide `razor_fiend`** (`units.lua:188`). Croisé en colonne F (§3.1). Source :
  effects-synergy-tiers §3.1.
- **Candidats orthogonaux à valider en sim (confirmés round 4-5, + burn-4 tranché round 6)** :
  **burn 4 = `burnIgnoreShield` (KEYSTONE — #W CLOS round 6, synergies §2.2)** : `grant_team
  {burnIgnoreShield}` — commit total burn → **contourne les boucliers**. Burn est **vulnérable au bouclier par
  DESIGN** (rock-paper-scissors : burn>carries, tank>burn, autres percent ; coût de la propagation) → le twist
  burn-4 est le **payoff de commit** qui lève cette vulnérabilité. **Identité forte et lisible.** (≠ propagation
  en cours-de-vie, qui peut être le palier-2 ou un autre axe à départager en sim.) ;
  rot 4 = amputation sur HP **final** (≠ `necro_leech maxHpFrac=0.35` → vérifier qu'il ne le vide pas) ;
  poison 4 = un axe **autre** que le slow (candidat : propagation **active** au dépassement d'un seuil, ≠
  `plague_bearer` qui propage au hit) ;
  **bleed 4 = « Décomposition » (round 5, synergies §2.4/P4)** : `grant_team {bleedPierceShield}` — **chaque
  tick bleed retire 1 point de bouclier**. Ne vide aucun T2 bleed (relus : `razor_fiend`=burst, `blood_echo`=
  cadence, `leech_thorn`=épines). Counter-bouclier lent et prévisible (1 pt/tick → n'invalide pas les tanks).
  **NOTE DE DESIGN (synergies §2.3/P4, round 6)** : l'identité bleed bascule **défensive (palier-2 = ralentir
  la cadence) → offensive (palier-4 = percer les boucliers)** → **signal UI au palier-2 OBLIGATOIRE** (« au
  palier 4, ton bleed ronge les boucliers ennemis ») pour préparer la bascule, sinon elle **surprend** le
  joueur et casse la lisibilité (StS synergy signaling). À valider en Config D. Croiser colonne F.
- **GARDE-FOU twist #3 — nature stats + TABLEAU DE SATURATION PAR FAMILLE (synergies §1.2 + relics §2.2, round 6)** :
  le **cap ×3 borne l'OUTPUT du tick, PAS le `increased` total ni le `more`**. **Avant de figer les valeurs des
  paliers, produire un TABLEAU DE SATURATION (relics §2.2/Prop-B, doc ~5-15 lignes, 0 code)** — la composition
  de **3 sources d'inc de la même famille** (relique B + palier type + aura) est **probable dès le tier-3 sur
  9 slots** : poison = `kings_bowl` 0,20 + palier 0,20 + `miasma_acolyte` 0,50 = **inc 0,90** ; burn =
  `ember_heart` 0,30 + palier 0,20 + `warmth_emitter` 0,25 = **inc 0,75**. Si le cap est bas vs la base, il
  **écrase la profondeur** ; trop haut → sur-puissance. **Et les familles n'ont pas le même cap** :
  `DOT_CAP_MULT=3` (`ops.lua:22`) ≠ `BLEED_DPS_CAP=12` (`ops.lua:28`). Le tableau note, par famille : `base_dps
  médian`, `cap output`, **`seuil d'inc saturé = (cap/base_min) − 1`** (au-delà = cap toujours atteint =
  profondeur écrasée), `inc naturel max (B+aura)`, **marge avant saturation**, et **marque `[SATURATION_RISK]`**
  toute famille dont la stack d'inc dépasse 1,0 naturellement → **permet de fixer le palier-2 (+20 %) et le
  twist-4 (`more`) sans saturer une famille déjà à 0,90**. → **le twist de palier 4 DOIT être spécifié comme un
  `more` borné séparément, OU une règle qui ne passe PAS par `Stats.resolve`** (litige #B) + drapeau de sim.
  **2 CAS SPÉCIAUX DU TABLEAU (NOUVEAU round 7) :**
  - **EXCEPTION CHOC (synergies §2.2/P2)** : `base_dps tick = 0` (condensateur, 0 dégât à la pose) → la formule
    `(cap/base_min)−1 = N/0 = ∞/crash`, et le cap choc = `SHOCK_STACK_CAP=8` (stacks), **PAS** `DOT_CAP_MULT=3`
    (output DoT). **Ligne hors-formule** : `base = N/A` ; métrique = `burst_DPS_eq` (§3.1a). **Le twist choc-4
    ne peut PAS être un `more` sur l'output** ; il doit modifier un de 3 axes : `shockStackBonus` (nb stacks/
    hit), `shockAmpMult` (magnitude ampli par famille du poseur), `shockTrigger` (`any_dot` vs `dot_family`).
  - **BLEED PAR RANG (relics §2.5/Prop-E)** : `BLEED_DPS_CAP=12` est un cap **absolu** (≠ multiplicateur de
    base) → le seuil **varie par rang** : bleed rang-2 (dps=2) → seuil = 500 % (marge énorme) ; bleed rang-3
    (dps=6) → seuil = **100 %** (si inc naturel=0,58, reste 42 % = serré). **Ajouter une colonne « rang-3
    représentatif »** pour les familles à cap fixe (bleed). Le tableau par famille seul **masque** cette
    hétérogénéité intra-famille.
- **PRÉCONDITION P1 — 3 tests inter-famille adjacence (NOUVEAU round 6, synergies §2.4/P3)** : le palier de type
  pose un `teamFlag` à `combat_start` **APRÈS** le bake des auras → l'**ordre de résolution n'est pas testé**
  (si `poisonIncTeam` est appliqué avant que `miasma_acolyte` ne soit bakée, l'accumulated peut diverger du cap
  ×3 ; le fuzz déterministe ne couvre pas ces cas-limites). **Ajouter à `tests/synergies.lua` (seed connue,
  0 code moteur)** : (1) `miasma_acolyte` + palier poison-2 + tick cible → l'accumulated ≤ cap ×3 ;
  **(2) → SCINDÉ EN 2a/2b (RAFFINÉ round 7, synergies §2.1, code-vérifié synthé)** :
  **(2a)** `shield_aura` **statique** (voisin) + twist bleed-4 `bleedPierceShield` → le tick retire 1 pt **ET**
  l'aura ne se reconstruit PAS en combat (baked à `combat_start`) = drain progressif validé ;
  **(2b)** `shield_caster` ACTIF (voisin) + `bleedPierceShield` → mesurer le bouclier **NET** après N ticks.
  **Pourquoi 2b est obligatoire** : `ward_weaver` (`units.lua:362-364`, vérif synthé) re-bouclier **20/240
  ticks (4 s) aux voisins, SCALANT par niveau** → un `ward_weaver` **niveau-3** (60/4 s) **absorbe
  entièrement** un drain de 1 pt/tick si le bleed actif est faible = twist **quasi-inerte** (exact schéma
  `sacred_shield invulnT=30`). **Si NET < 0 → augmenter à 2 pts/tick OU passer à un burst de stacks** (« à 5
  stacks bleed, vider 50 % du bouclier courant »). **Le burst est un REPLI conditionnel à la sim 2b, PAS le
  défaut** (le drain progressif est l'identité « bleed ronge » voulue) ;
  **(3)** choc-D `dot_family` + aura d'amplification (post-`miasma`) → l'ampli touche le tick **aura-amplifié**,
  pas un tick fantôme. **+ Q3 synergies** : clarifier si `bleedPierceShield` s'applique à **tous les ticks de
  toutes les instances** (alors drain = nb_stacks ×1 pt, bien plus fort que « 1 pt/tick »). **+ Q1 synergies** :
  **nommer les `teamFlags` de palier DISTINCTS** des flags T3 (`poisonIncTeam` ≠ `poisonNoCap` de `festering`)
  → éviter une collision de nommage.
- **Source psycho** : **goal-gradient** (Hull 1932 ; Nunes & Drèze 2006) ; diva-portal.org 2025 (engagement =
  count visible progressant vers le seuil).
- **Architecture (vérifiée code)** : `grant_team` pose des `teamFlags` à `combat_start` (00-state §3 ;
  pattern `ash_maw`/`festering`/`pit_maw`). Un palier = un flag selon le **compte de `dot_family`**
  calculé **au build** (golden-safe si `mods=nil` quand inactif). **Aucune** édition de boucle.
- **Garde-fou invariants** : gated par compte → **golden inchangé**. **Tests à ajouter** : 5 types × 2
  paliers + interaction `DOT_CAP_MULT=3` + les **3 tests inter-famille** ci-dessus.
- **PRÉCONDITION P1 — TABLEAU DE SATURATION DES ARÊTES (NOUVEAU round 10, synergies §2.3, Kritz & Gaina 2025) —
  parallèle au tableau de saturation `inc`** : les arêtes d'adjacence sont la SIGNATURE de The Pit (« la forme EST
  le graphe de synergies »), mais on a un tableau de saturation des `inc` (ci-dessus) et **ZÉRO pour les ARÊTES**.
  L'hypothèse « plus de slots = plus d'arêtes = plus de profondeur » est **fausse** : la croix n'a que 4 arêtes
  (branches isolées) → avec 5 slots ouverts, 3 branches peuvent n'avoir qu'une unité (0 arête active). Kritz &
  Gaina 2025 : la saturation **positionnelle** est PLUS à risque que la saturation de type (co-location requise,
  pas seulement co-existence). On AJOUTE des synergies de TYPE (P1) qui CUMULENT avec les auras d'adjacence →
  sans connaître la saturation des arêtes, on risque de prescrire des combinaisons P1 incompatibles avec
  l'archétype positionnel naturel d'une famille (ex. bleed+ligne, déjà flaggé §3.1 col J).
  ```
  TABLEAU DE SATURATION DES ARÊTES (calculable sans sim, ~1 h combinatoire sur shapes.lua) :
    Pour chaque (sigil ∈ {carré,croix,anneau,diamant,ligne} × famille DoT × slots ∈ {3,5,7,9}) :
      arêtes_max(sigil) = |edges| de shapes.lua (carré 12 / croix 4 / anneau 9 / diamant 8 / ligne 8)
      E[arêtes_homogènes_actives] (espérance, pool uniforme par rang) ; saturation = E[homogènes] / arêtes_max
    ALARME : saturation < 0.3 à 7 slots → incompatibilité positionnelle DOCUMENTÉE avant de prescrire une AURA de
      cette famille sur ce sigil en P1 (ex. si bleed+ligne < 0.3 → P1 ne prescrit pas clot_mender comme arme
      principale sur la ligne → note dans la spec P1).
    + colonne "saturation_shield" pour les 6 porteurs de bouclier (Q4 synergies : auras build-résolues).
  ```
  **Précondition de P1 au même titre que le tableau `inc`.** 0 invariant SIM (lecture pure de `shapes.lua`).
  Source : synergies §2.3 ; Kritz & Gaina 2025 (arxiv 2502.10304v1) ; 00-state §2.3 (5 sigils, arêtes explicites).

### 5.3 UI — compteur de type visible (lié à P0)

- **Quoi** : compteur sur le plateau (« Burn 3/4 »), surlignant les unités du même `dot_family`,
  cohérent avec le surlignage d'adjacence (§2.1) et la carte de risque (§2.2).
- **Source** : compteur de trait = objectif intermédiaire visible (tft §2.1/§4.3) ; goal-gradient.

### 5.4 INTERACTIONS INTER-FAMILLES MID — la diversification mécaniquement récompensée avant les T3 — **#FF NEUF (NOUVEAU round 8, synergies §2.2/P2) — SPEC À PROUVER EN SIM, PAS GRAVÉ**

- **Lacune de profondeur #1 non adressée en 8 rounds (synergies §2.2)** : les interactions inter-familles
  n'existent qu'aux **T3 croisées** (`bleed→rot`, `poison→burn à 5 stacks`) = rang-3, round 8+. Les paliers de
  type P1 sont **par FAMILLE SEULE** (bleed-4 OU poison-4, jamais « bleed+poison »). → un build 2-familles n'a
  **aucune décision asymétrique** vs un build 1-famille avant le mid-game → **les builds MONOFAMILLE dominent**,
  la diversification n'est récompensée que par opportunité boutique, pas par stratégie. **Distinction Kritz &
  Gaina (arxiv 2502.10304)** : synergie **intra-ensemble** (notre palier 2/4 par famille) vs **inter-ensemble**
  (2 familles → effet que ni l'une ni l'autre n'a — nos T3 seules). **Le manque d'inter-ensemble en MID** est la
  lacune de profondeur #1. **P1 sans elles = couche de types qui CLOISONNE les familles au lieu de les faire
  résonner** (et renforce la dominance de poison déjà sur-représenté).
- **2 mécaniques proposées (triggers existants, 0 nouveau moteur)** :
  - **A — Aggravation croisée par co-présence** (`tickDots`) : si une cible a 2 familles DoT actives (dps>0), le
    2nd tick a un `more` de **+10-15 %** (cap = 1× l'incident, **pas de cascade**). Déterministe (condition sur
    stacks). Lit les dots déjà dans `tickDots`.
  - **B — Contagion de famille au kill** (`on_death`) : si une unité meurt avec 2+ familles, la **plus forte**
    (stacks/dps) se propage aux voisins de combat (`Arena:neighborsOf`) à **15-20 %** (distincte de la propagation
    poison à 1,0×). 1 ligne dans `on_death`.
- **POURQUOI ADOPTÉ MAIS PAS GRAVÉ (garde-fou décisif du synthé)** : la critique est **valide et importante**
  (diversification mécaniquement rentable avant les T3, run court 10 victoires). **MAIS** : (1) **sa propre Q2 le
  reconnaît** — le `more` croisé **interagit avec le tableau de saturation** (un build complet pourrait dépasser
  le seuil) → **dépend du tableau de saturation (précondition P1) ET de `dot_family` (P0.5)** ; (2) **golden** —
  un bonus conditionnel `more` au tick **rebaseline si la config golden contient une co-présence** (≠ « 0
  invariant » comme la critique l'affirme) ; (3) **2 rounds restants** — graver une mécanique structurelle sans
  l'avoir simulée vs la saturation = risque de combo cassé (ce que `offer_decision_quality` et le tableau de
  saturation cherchent à éviter).
- **DÉCISION (#FF ouvert, SPEC À ÉVALUER en P1)** : **documenter les 2 mécaniques** comme candidates à spécifier
  **APRÈS le tableau de saturation (§5.2)**, avec garde-fou : le `more` croisé **entre dans le MÊME tableau de
  saturation** que les paliers/auras/reliques B/resonance, sa magnitude bornée pour ne pas dépasser le seuil de
  la famille la plus chargée. **Si la sim de saturation montre un dépassement → réduire le `more` croisé OU
  différer P1.5b.** **Complémentaire de la relique resonance (§3.6)** : resonance récompense la **cohérence
  MONO-famille**, #FF la **diversification MULTI-familles** — pas redondant, **les traiter ensemble après la
  saturation**. **Litige #FF à trancher round 10 (+ précondition lisibilité + #II ci-dessous).** Source : Kritz & Gaina 2025 ; entaltostudios.com (« every
  archetype must have a reason to branch ») ; SAP (triggers qui chaînent entre families).
- **PRÉCONDITION LISIBILITÉ — `combat_effect_legibility` (NOUVEAU round 9, synergies §2.1, Q3 r08 réintroduite —
  IGNORÉE à tort par le synthé r08)** : #FF n'ajoute de la profondeur **que si le joueur peut VOIR** l'interaction.
  Un tick peut déjà déclencher 6-10 événements simultanés (6 familles + bouclier + aura + propagation kill +
  contagion hit + décharge choc) ; #FF monte à 8-12. Au-delà de **3-5 effets distincts** (heuristique NN/g, non
  une loi mesurée — synthé NUANCE §7.4), le joueur ne perçoit rien → la profondeur est dans le code, pas dans
  l'expérience (switchbladegaming.com/balatro-best-joker-combos : interaction = déclencheur **observable**). **Et**
  §2.3 (pourquoi) + §2.10 (relief) lisent le bus JSONL : s'il est dense, le signal d'attribution est noyé.
  **MESURE (PRÉCONDITION de #FF ET de §2.10, ~10 lignes sim)** :
  ```
  Mesurer sur N=200 combats (bus JSONL) : avg_events_per_tick, max_events_per_tick.
  Si avg > 4 OU max > 8 → règle de BATCHING obligatoire dans arena_draw.lua :
    - regrouper les ticks de même famille en 1 VFX cumulé ("BRÛLURE ×12" vs 12 ticks)
    - priorité d'affichage : mort > décharge choc > DoT tick > bouclier > regen
  Si avg ≤ 4 → #FF et §2.10 implémentables sans batching.
  Test : la condition se déclenche sur le golden (événements bus comptés par tick). 0 invariant (RENDER).
  ```
- **DIRECTIONNALITÉ DE L'AGGRAVATION CROISÉE = #II NEUF (NOUVEAU round 9, synergies §2.4)** : la spec dit « la 2e
  famille reçoit un `more` ». Mais l'ordre fixe `tickDots` (`burn→bleed→poison→rot→choc→regen`) signifie que la
  « 2e famille » d'une paire donnée est **toujours la même** → « burn amplifie rot mais rot n'amplifie pas burn »
  = **asymétrie non explicite**. **À trancher AVANT le test #FF** :
  ```
  Option A — DIRECTIONNELLE (ordre fixe) : la dernière famille de l'ordre actif reçoit le `more`.
    Ex : burn+rot → rot amplifié ("le feu aggrave la pourriture"). Signal UI nomme la relation. 0 moteur, thématique.
  Option B — SYMÉTRIQUE (2 passes dans tickDots) : les 2 familles s'amplifient mutuellement. ~5 lignes,
    rebaseline golden possible. Plus cohérent avec "synergie".
  ```
  **Impact tableau de saturation (Q2 synergies)** : directionnelle = 1 entrée (famille amplifiée) ; symétrique =
  2 entrées (plus proche du seuil) → la directionnalité doit être tranchée AVANT de placer #FF dans le tableau.
  **#II CLOS recommandé round 10 (synergies Q2, via #JJ) → Option B (symétrique)** : Option A (directionnelle) =
  condition partielle (dépend de la présence de la famille adverse) ; Option B (les 2 familles co-présentes du
  BUILD s'amplifient) = condition FORTE (compo contrôlée = #JJ). Recommandation de clôture à **décision user**
  (rebaseline golden = garde-fou explicite, ~5 lignes SIM). Source : 00-state §3.2 (ordre fixe) ; synergies §2.4/Q2 ; #JJ.
- **BATCHING #FF — DISTINGUER TICKS HOMOGÈNES vs MODIFIÉS (NOUVEAU round 10, synergies §1.1)** : la règle de
  batching (« BRÛLURE ×12 ») est correcte pour la FRÉQUENCE des ticks homogènes, mais #FF ajoute un type
  d'événement DISTINCT (l'aggravation croisée = MODIFICATEUR de tick, pas un tick de plus). Sans distinction, le
  batching aplanit EXACTEMENT l'interaction que #FF rend visible. → distinguer : ticks HOMOGÈNES (« BRÛLURE ×12 »)
  vs ticks MODIFIÉS par #FF (« BRÛLURE++(×12) » ou VFX couleur mixte). Source : synergies §1.1 ;
  accessiblegamedesign.com/guidelines/statuseffects.html.
- **CANDIDAT POISON-4 NOMMÉ `poisonWeakenDeep` (NOUVEAU round 10, synergies §2.4 — COMPLÉTUDE spec P1)** :
  burn-4/bleed-4/rot-4 ont un twist nommé, choc-4 = Option B `tickCount=2` (#HH clos §3.7), poison-4 = vide
  depuis 10 rounds. **Sans candidat, la spec P1 a 4/5 familles.** Candidat naturel (le poison agit sur la VALUE
  via weaken) :
  ```
  POISON-4 (SPEC À PROUVER, simuler avant gravure) — poisonWeakenDeep : si ≥4 unités dot_family=="poison" →
    teamFlag{poisonWeakenPassif} → le weaken s'applique aux passives adverses (auras "combat_start") à coefficient
    réduit (0.30). ~5 lignes data + 1 op {on_hit: weaken_passif, factor=0.30}. Alignement #JJ : compo (4 poison)
    = contrôlée. Garde-fou : NE s'applique PAS aux teamFlags de TYPE adverses (évite la boucle inter-camps).
    Compatible DOT_CAP_MULT=3 (cap = DPS, pas weaken). Thème : « le venin sape les fondations » (auras fléchissent).
    Simuler P90/P10 d'une compo poison-4 vs compo aura-lourde adverse.
  ```
  Source : synergies §2.4 ; 00-state §3.1 (cap stacks poison array 8) ; #JJ.
- **TEST 14 `aura_bakée × palier_teamFlag` (NOUVEAU round 9, synergies §2.5, zone sans test §8)** : l'ordre de
  résolution (bake auras de `shapes.lua` PUIS `teamFlags` P1) est docté (engine-architecture §8) mais non testé
  pour **aura + palier sur la MÊME unité** (`soot_acolyte` aura `burnInc` + `grant_team{burnInc=0.20}` palier
  burn-2). Interaction la plus fréquente en P1 (chaque famille a ≥1 aura). **Test (~8-10 lignes `tests/synergies
  .lua`)** : `assert |resolved_inc − (aura_inc + 0.20)| < 0.001` (additif, `increased` additif `stats.lua:
  resolve`). 0 moteur. Source : engine-architecture §8 ; synergies §2.5.

> **Litige #B (confirmé code round 4)** : double-comptage inc% (types × reliques B × auras). **Borné
> par le cap ×3** pour l'output (confirmé : `kings_bowl + miasma + palier = 3.8 < 6`). `plagueAmp`
> hors-cap **voulu**. **Le cap borne l'output, pas le `increased` ni le `more`** → **le twist de palier
> 4 = `more` à borner séparément** (sinon hors-cap sur grosse base). → drapeau de sim (lift) **+
> spécifier la nature du twist AVANT P1**.

---

## 6. CHANTIER P2 — Ranked v1 LOCAL + Daily + Contrainte de Saison (v0.11, ~2-3 lots) — **REFONDU round 1, ENRICHI rounds 2-8 (round 8 : Daily seed partagé #BB, Contrainte de Saison avancée P2, IA 1/famille, framing i18n, Grimoire maîtrise)**

> **Pourquoi P2** : zone vierge #1 (00-state §7). Moteur du « réenchaîner pour grimper ». **Livrable en
> LOCAL** (pas de backend). **Round 4** : ajoute le **moteur PRÉ-RUN** (§6.11 — le manquant #1 : les
> signaux post-run ne lancent pas une session) ; le **post-combat ranked enrichi** (§2.3, la vraie
> asymétrie ranked/unranked) ; **10+ contraintes daily compositionnelles** + **filet pédagogique** ;
> le **Grimoire 3-chapitres** (§6.7).

### 6.1 Principe — l'unité de compétition est le RUN — **ACCORD FORT (5e confirmation)**

- **Source** : « score par run » (SAP §8.4, Bazaar §9.4, TFT §V8) ; **confirmé round 4** : Bazaar
  pré-Legend = **gains seulement** (pas de perte) ; Legend = moyenne 0-1000 (steamcommunity 1617400) ;
  SAP Versus (gain/perte) est **P2P temps réel**, pas notre modèle. L'accumulation de points est **plus
  lisible pour notre faible volume** (2-3 runs/sem). Accumulation maintenue.
- **CORRECTION D'ANNOTATION ROUND 9 (ranked §4.1) — « SAP Arena » est une analogie paresseuse pour le RANKED** :
  SAP a **3 modes distincts** (superautopets.wiki.gg/wiki/Version_0.28) — **Arena** (IA générées, casual, 10V,
  JAMAIS de ranked) ≠ **async-versus** (matchmaking async, builds capturés = nos ghosts humains) ≠ **Versus
  ranked** (1v1 temps réel, ELO). Notre modèle est proche de **SAP async-versus** pour la boucle, pas de Arena.
  **Distinguer dans les annotations** : « **SAP Arena = réf RUN-structure** (10V, casual, pas de pénalité) » vs
  « **SAP v0.41+ ranked = réf SAISONNIÈRE** » (saisons ajoutées juillet 2025, APRÈS coup — superautopets.wiki.gg/
  wiki/Version_0.41 ; même SAP a eu besoin de saisons ranked post-lancement). 0 code, doc.

### 6.2 Grille de score SANS pénalité + marques sub-tier [PH] — **calibrée AVEC la hauteur des paliers + COMBLE LE GOUFFRE MID-CORE**

- **Raisonnement MIS À JOUR round 6 (ranked §1.1)** : `+4/+2/+1/0` **reste correct**, mais **NE PLUS citer
  Bazaar comme validation** — le Bazaar a introduit **gain ET PERTE** de rank points en 2025
  (bazaar-builds.net/ranking-update-reset : « players now gain and lose rank points »). **Le Bazaar est
  désormais une CONTRE-référence partielle** : il a les pénalités **parce que son backend mondial** (pools
  de centaines de milliers) les rend **légitimes** (la pénalité calibre le MMR). **Notre FIFO 200 LOCAL ne
  le peut pas** : une pénalité punirait la **pauvreté du pool, pas le skill** (PMC10839887 : la perte
  amplifie le churn quand le matchmaking est **perçu injuste** — notre FIFO + `RANKED_MIN_POOL` est
  transparent sur son imperfection → une pénalité y serait perçue comme une **injustice mécanique**). **Et
  format run-court** : une run = 1-2 h → une pénalité = **~4 h de gain perdues** en aversion à la perte
  (Kahneman-Tversky 2,3×) = incompatible avec « jeu de grind fun ». → **citer : format run-court + FIFO local
  imparfait + FIFO transparent**, plus Bazaar.
- **Grille + calibrage adoptés [PH, à sim]** :
  | Résultat du run | Δ rating [PH] | Justification |
  |---|---|---|
  | **Ascension 10 victoires** | **+4** | signal fort, récompense le grind complet |
  | Chute 8-9 victoires | **+2** | presque là |
  | Chute 6-7 victoires | **+1** | mid-run sain |
  | **Chute 0-5 victoires** | **0** (jamais de pénalité) | le joueur tente, il revient |
- **GOUFFRE MID-CORE — MARQUES SUB-TIER (ranked §3.1 + retention §2.4)** : la zone 0-5 victoires = **0
  point toute la saison** pour le joueur mid-core honorable → churn. `season_wins` est un **journal
  privé**, pas un signal **comparatif**. → **3 marques cosmétiques** (0 rated) sur le **meilleur run de
  la saison** : **Survivant** (argent, 5-7 wins) / **Forgé** (or, 8-9 wins) / **Ascendant** (rouge, ≥1
  ascension). Visibles sur le profil. Comparaison sociale (Duradoni 2026 ; Festinger : motive si le gap
  est **closable**). **3 marques seulement.** Texte grimdark.
- **CALIBRAGE post-launch (NOUVEAU round 4, ranked §1.2)** : LoL ranked 2025 (egamersworld) montre une
  **désaffection si les cosmétiques sont trop accessibles**. → calibrer le seuil **Survivant** sur le
  **p25 de la distribution des meilleurs runs/saison** (pas un absolu 5 wins), pour qu'~25 % des
  joueurs l'obtiennent. Seuil absolu = [PH] légitime, **à recalibrer dès la saison 1**.
- **Hauteur de palier [PH]** : **~35 pts/tier** — vitesse-cible **1 tier / saison 6-8 sem.** Script
  `tools/ladder_sim.lua`. **NE PLUS citer LoL LP comme ancrage de CALIBRAGE (NOUVEAU round 9, ranked §4.3 —
  comme TFT round 8)** : rank inflation LoL 2023-2026 + **hard reset Masters+ 2026** (leagueoflegends.com/dev-
  ranked-2026) = LoL n'a pas de calibrage stable. **Seule réf de calibrage = `tools/ladder_sim.lua` sur nos
  contraintes** + cible « 1 tier/saison à 2-3 runs/sem ». (Cohérent avec le retrait de la table TFT round 8.)
- **Écrémage élite — EXPLICITE AVANT LA RUN (ranked §2.5/§4.1)** : tiers 1-3 = toute ascension = +4 ;
  tiers 4-5 = ascension ≤1 vie perdue = +4 / 2-3 vies = +2 ; tier 6 = ascension parfaite = +4 / sinon
  +2. **Affiché AVANT** (pas de condition cachée).
- **PROFONDEUR DU PUITS — 2e DIMENSION VISIBLE ORTHOGONALE AU LP = #KK NEUF (NOUVEAU round 9, ranked §3.3)** :
  la roadmap n'a qu'**UNE** dimension de classement (LP). Un joueur **7-3 répété** n'a jamais de signal de
  compétence durable (les marques sub-tier exigent 8-9 wins). Management Science 2026 (Lichess 5.4M parties) :
  considérer **2 dimensions** (skill + historique récent) produit **+4-6 % d'engagement** ; kydagames.com 2026 :
  « personal best alongside competitive rank = motivation maximale ». **La Profondeur du Puits** = round max
  atteint cette saison, **indépendamment du résultat final** — exactement le « personal best » qui mesure la
  progression INDIVIDUELLE. Pour le 7-3 répété : Profondeur = Round 7 → axe d'amélioration concret (« qu'est-ce
  qui me bloque au round 8 ? »). Les « Cercles du Puits » (Dante/PoE) = archétype grimdark parfait.
  **Complémentaire des marques** (qui récompensent le meilleur résultat FINAL).
  ```
  depth_record = max(rounds_completed_this_season). Méta cross-run, reset saisonnier (comme le LP).
  - PER-RUN au score-screen (feedback : "LE PUITS T'A VU DESCENDRE JUSQU'AU SEPTIÈME CERCLE")
  - RECORD-SAISON au pré-run §6.11 (motivation : "ton record : 8e cercle")
  ```
  **Async-safe** (stat de run, pas de snapshot), **0 invariant.** **#KK** (per-run vs record) → recommandation :
  **les deux**, endroits différents.
  **PRÉREQUIS round 10 (ranked §1.2/§3.5, 1 grep AVANT le code du signal §6.2)** : la Profondeur du Puits n'est
  motivante que si le joueur perçoit une **vraie différence de difficulté** entre le round 4 et le round 8. Si la
  courbe d'escalade des IA (`encounters.lua`) est **plate**, la Profondeur mesure un plafond d'ÉCONOMIE (or), pas
  de SKILL → « bloqué au round 8 » = « bloqué ici depuis toujours » = démotivation. **Vérification : 1 grep sur
  `encounters.lua` (lecture seule) que les builds IA ESCALADENT sur les rounds.** Si plat → dette de contenu à
  résoudre AVANT de coder le signal, OU reformuler « rounds atteints » sans promettre de difficulté croissante.
  + les ghosts ranked servis au round 8+ doivent avoir `slot_tier_composite ≥ seuil` (signal de menace pré-run,
  0 mécanique : « les fantômes du cercle 8 sont les plus corrompus »).
  Zone sans test → test `depth_record` mis à jour à chaque combat (golden run 7 combats). Source : kydagames.com
  2026 ; eurekalert.org/news-releases/1130401 ; thebigbois.com/legionbound ; ranked §1.2/§3.5.
- **MODIFICATEUR LP VISIBLE PAR CONTEXTE DE POOL (NOUVEAU round 9, ranked §2.1/§3.1 — PRIORITÉ 2.5)** : la grille
  `+4/+2/+1/0` récompense la DURÉE du run, pas la QUALITÉ — Ascension 10V contre un pool choc (facile) = même +4
  que 10V contre un pool poison (difficile). Le signal de distribution du pool (round 8 §4.8) est adopté comme
  info, jamais comme levier de score. SAP ranked utilise ELO (superautopets.wiki.gg/wiki/Version_0.28 : victoire
  contre mieux classé = plus de points). **Synthé ADOPTE en BORNANT fortement (PAS de retour au MMR caché —
  round 8 : 6-9 runs insuffisants)** : un ajustement **VISIBLE, grimdark, borné à ±1, JAMAIS de pénalité** qui
  MODULE la grille sans la remplacer :
  ```
  JUGEMENT DU PUITS (après la baseline pool §4.8, ~15 lignes IO+RENDER) :
    pool "dominant" (≥60 % famille à win-rate max, ex. poison) → +1 LP ("pool corrosif")
    pool "faible"   (≥60 % famille à win-rate min, ex. choc)   → +1 LP (under-challenge non contrôlé)
    pool "équitable" (aucune famille > 60 %)                   → 0 (base)
    JAMAIS de pénalité (le joueur choc qui gagne ne doit pas être puni pour un pool "facile").
    Calculé depuis les familles des snapshots servis (IO hors SIM, 0 invariant).
  ```
  **Priorité 2.5** (dépend de la mesure `dot_family` des snapshots P0.5 + `toComp`). Zone sans test → golden
  store famille-distribution. Source : ranked §2.1 ; fairgame.us (« fairness = trust, not just math », mai 2026).
- **Garde-fou** : rating = **méta** (cross-run, IO hors SIM). Aucun invariant. **Q (ranked §5.5)** :
  marques **reset par saison** (position adoptée round 4 : la comparaison sociale perd sa valeur si la
  marque ne se renégocie pas — cohérent Bazaar/HS:BG).

### 6.3 Tiers nommés + RÈGLE DE PERTE MAX (pas de floors) + reset partiel [PH]

- **Tiers nommés grimdark** [PH] : *Crawler → Condemned → Forsaken → Damned → Pit-Born → Void* (6 tiers).
  **Cosmétique, coût nul.**
- **PAS de floors** : double LP-visible / MMR-caché = confusion #1. → **règle asymétrique LISIBLE** :
  « on ne peut pas perdre plus d'1 tier par saison ». « Le Puits vous a retenu. »
- **Reset saisonnier** : rating visible **−20 %** (pas zéro) ; **MMR interne jamais resetté**. **Reset
  conditionnel (round 4, ranked §5.3)** : si `ranked_runs_this_season < 3` → reset à **0** (pas −20 %,
  qui de toute façon = 0) + message clair « tu n'as pas perdu de rating » (évite la confusion du joueur
  entré tard en saison).
- **PERSISTANCE INTER-SAISONS RENDUE EXPLICITE (NOUVEAU round 7, ranked §3.5/§1.6)** : à 3 sem./saison, le
  joueur mid-core ne monte que d'un demi-tier/saison → le pré-run montrera « PROCHAIN GRADE — 4 pts » pendant
  2 saisons. Ce n'est un problème que si la persistance (−20 %, pas à 0) reste **implicite**. → au démarrage
  de saison, le signal pré-run (§6.11) affiche **explicitement** : « **PUITS S[N] : TU AS CONSERVÉ [X] PTS DE
  TA DESCENTE PRÉCÉDENTE — TA PROGRESSION TRAVERSE LES SAISONS.** » Prévient la déception du reset partiel +
  renforce la valeur long-terme. Lit `playerRating` (avant/après reset), RENDER, 0 mécanique, 0 invariant.
- **Cadence COURTE échelonnée par contenu (RÉVISÉ round 6 ; CORRIGÉ round 10 : 3 sem. → 5 sem. S1-S2)** : le
  **Fresh Start Effect** (Dai, Milkman & Riis 2014, Management Science) fonctionne **seulement si le reset
  crée une discontinuité perçue**. **CORRECTION round 10 (ranked §2.2/§4.1-4.2)** : la valeur héritée « 3 sem. »
  s'appuyait sur (a) Milkman 2014 (landmarks proches) et (b) « Bazaar mensuel = benchmark » — **deux transferts
  faux** : Milkman étudie des landmarks **NATURELS** (lundi, Nouvel An — préexistants, indépendants du
  comportement) ; un reset de saison est **ARTIFICIEL imposé** → sa puissance Fresh Start est proportionnelle au
  sentiment d'avoir quelque chose à recommencer (accumulation préalable). **3 sem. = 6-9 runs = une session, pas
  une saison.** Et Bazaar mensuel = **pool mondial** (adversaires non répétitifs) ≠ **FIFO 200 LOCAL** (épuisé en
  ~20 runs : à 3 sem. le joueur a vu ~60 ghosts mais le pool n'a pas eu le temps de se régénérer). **Cadence
  révisée** :
  | Saison | Durée | Condition |
  |---|---|---|
  | Saisons 1-2 (pré-P3) | **5 sem.** | pas de contenu — Fresh Start minimal mais RÉEL (10-15 runs = 1 tier mid-core = ~50 ghosts) |
  | Saisons P3+ | **6-8 sem.** | nouveau tuning majeur = mini-refresh |
  | Saisons P4+ (reliques G) | **8-10 sem.** | contenu nouveau = durée longue justifiée (HS:BG/TFT) |
  **Garde-fou BAS** : **jamais < 4 sem.** (dessous = session, pas saison ; Milkman 2014 relu = landmark naturel
  ≠ reset arbitraire → ne justifie QUE le garde-fou bas, pas 3 vs 5). **Garde-fou HAUT** : jamais > 10 sem. sans
  contenu (pool ghost stagne, méta prévisible). 1 constante `SEASON_WEEKS` [PH], décision éditoriale. Coïncide
  avec rotation sigil (P4) + **Contrainte de Saison** (§8.0). Source : ranked §2.2 ; GamineAI 2026 (6-12 sem.) ;
  Milkman 2014 relu ; FIFO 200 local ≠ pool mondial Bazaar.
- **DÉMARRAGE DE SAISON — FIFO ranked + fenêtre de grâce (NOUVEAU round 6, ranked §2.2/§3.3)** : au reset,
  le **Fresh Start** (jouer immédiatement) et **`RANKED_MIN_POOL`** (pool vide) **se heurtent** — le moment
  le plus fragile de la rétention ranked. **Remède (IO hors SIM, 0 invariant)** : **(a) FIFO ranked NON vidé,
  persistance FILTRÉE** — **filtre ENRICHI round 10 (ranked §1.4)** : `wins_at_capture ≥ 3` SEUL est un proxy
  fragile (3 victoires early ≠ 3 victoires late STRUCTURELLEMENT — la capture est liée au shopTier+reliques, pas
  au compte de victoires brut). **Double critère : `snap.wins_at_capture ≥ 3 AND slot_tier_composite ≥
  MIN_COMPOSITE [PH]`** (le même proxy de matchmaking §6.4 ; suggestion `MIN_COMPOSITE >= 6`, ex. shopTier=2,
  slots=4). Garde-fou : si pool < `RANKED_MIN_POOL SOFT=3` avec le double critère → relaxer à `wins_at_capture ≥
  2` (priorité : pool non vide). **(b) fenêtre de grâce « Montée des Ombres »** — les **7 premiers jours**,
  `RANKED_MIN_POOL` est en mode **SOFT** (jamais « indisponible »), signal 🟡 « Pool en réveil — les ombres de la
  saison passée rôdent encore » (grimdark). **RÉ-OUVERTURE #Y round 10 (ranked §5.2)** : avec **#LL** (capture au
  premier achat, §6.4bis), la grâce 7 j se remplit PLUS vite (chaque run ranked capturé dès l'achat R1) →
  l'argument de la persistance filtrée vs vidage change → **re-trancher #Y en P2 après mesure de densité du pool
  avec la nouvelle règle de capture.** Grimdark : « Le Puits ne garde que les ombres qui ont prouvé leur descente. »
  **Zone sans test** → snapshots filtrés respectent les 2 critères + fallback si pool < SOFT ; grâce expire à J+7.
  Source : ranked §1.4/§5.2 ; arxiv 2602.17015 (Cinder : distribution > proxy — `slot_tier_composite` reste un
  PROXY uni-dimensionnel, §6.4).

### 6.4 Matchmaking `(bucket, wins_at_capture, slot_tier_composite)` + fallback descendant — **REFONDU round 3, CONFIRMÉ round 4**

- **`slot_tier_composite` (ranked §3.2 ; reconfirmé round 4 par Bazaar)** : remplace le
  `build_cost_proxy` **volatil** (5 rang-3 passent de proxy=15 à 45 après merges à `wins_at_capture`
  identique). **`slot_tier_composite = shopTier × slots_actifs`**, **MONOTONE CROISSANT** (tier/slots
  ne régressent jamais) → **stable à la capture**. Bazaar sept. 2025 (bazaar-builds.net/announcement)
  filtre par **rang** (pas proxy de force) — notre composite est **plus granulaire**.
- **`serve` ranked, ORDONNÉ** (évite le zéro résultat en cold-start) :
  1. bucket == joueur **ET** `|slot_tier_composite − joueur| ≤ 8` [PH] ;
  2. sinon bucket == joueur **ET** `wins_at_capture ±2` ;
  3. sinon bucket == joueur (tous) ;
  4. sinon **bucket−1** (jamais au-dessus) ;
  5. sinon `serveComp` (IA, cold-start garanti).
- **Architecture** : `snapshot = {version(+season_id), tier, seed, shape, units, +rank_bucket,
  +wins_at_capture, +slot_tier_composite, +mode}`. Encodage tabulé **sûr** (pas de `load()`). **Test requis
  (NOUVEAU round 4, ranked §1.3)** : round-trip + fallback ordonné + `slot_tier_composite` ne varie pas
  de plus de **±4** entre deux snapshots du même run à `wins_at_capture` identique. Invariants snapshot
  #18-21 non touchés (champs ajoutés).

### 6.4bis Pool ranked SÉPARÉ du pool unranked (`mode`) + `RANKED_MIN_POOL` (INTÉGRITÉ ASYNC) — **PRIORITÉ 1 (NOUVEAU round 5, code-vérifié)**

- **Trou de spec code-vérifié (synthé, relu `snapshot.lua:24` — struct `{version,tier,seed,shape,units}` SANS
  `mode`)** : v5 traite le store comme **un seul FIFO 200**. **Faille réelle d'intégrité async** (ranked §1.3/
  §2.1) : un débutant qui génère 5 snapshots tier-1-2 **pollue le cold-start ranked** d'un joueur établi → ce
  dernier gagne **+2/+4 en battant des builds faibles** faute de pairs dans le pool (monte **non par mérite,
  mais par pauvreté du pool**). `slot_tier_composite` filtre **qui** servir (`tier ≤ demandé`), **pas SI le
  pool contient des pairs de tier**. **Fait Bazaar vérifié** (bazaar-builds.net/did-you-know-how-ghosts-work) :
  « ghosts from ranked games only appear in ranked matches… separation ensures competitive integrity ».
- **Remède** : (a) champ **`mode = "ranked"|"unranked"`** dans le snapshot (**rétro-compatible** : `nil →
  "unranked"`) + **2 FIFO** dans `snapstore.lua` ; `serve("ranked")` ne pioche **jamais** un snapshot
  unranked. (b) **`RANKED_MIN_POOL` PROGRESSIF SOFT=3 / HARD=5 (RAFFINÉ round 6 — clôt #T, ranked §3.1)** :
  `count < 3` → 🔴 « **Puits Silencieux** » (ranked indisponible, fallback IA, **NON compté**) ; `3 ≤ count
  < 5` → 🟡 « **Pool Mince** » (ranked **disponible**, progression partielle, certains combats vs IA — **le
  joueur CHOISIT** de jouer avec un pool mince) ; `count ≥ 5` → 🟢 « **Pool Vivant** » (progression complète).
  **C'est une CONDITION DE FAIRNESS, pas une pénalité** (grimdark « Le Puits exige des témoins avant de
  juger »). **Le signal UI §6.5 supporte DÉJÀ les 3 états 🟢🟡🔴** → architecture inchangée. **Fallback HARD** :
  forcer le ranked sous SOFT=3 → `serveComp` (IA), résultat **NON compté** (RENDER : « Adversaire : Invocation
  — pool insuffisant, run non comptée »).
- **Garde-fou** : IO hors SIM, **0 invariant de combat**. **Zone sans test** → test que `serve("ranked",
  tier=3)` ne retourne **jamais** un snapshot `mode="unranked"` **ni** un `tier < 3−1` **+ que l'état
  🟢/🟡/🔴 retourné est correct pour chaque plage de `count`** (SOFT/HARD).
- **Litige #T CLOS round 6** : SOFT=3 / HARD=5 progressif **clôt #T sans trancher arbitrairement** — la valeur
  utilisée **dépend de l'état du pool**, pas d'un seuil figé (3 safe en bêta fermée, 5 idéal early access ; les
  deux coexistent dans la règle progressive).
- **IA RANKED = ENCOUNTERS PUISSANTS, 1 PAR FAMILLE (NOUVEAU round 7, ÉTENDU round 8 ranked §3.3)** : en S1, le
  ranked sera majoritairement des IA (pool quasi-vide 2-3 sem.). Pour que les runs ranked S1 n'affrontent pas des
  « builds aléatoires », les IA ranked (`aiComp`) sont sélectionnées depuis les **Encounters les plus PUISSANTS**
  (pas `rand()` dans `encounters.lua`), à la force d'un joueur établi. **Cohérent avec la persistance filtrée**
  (`wins_at_capture ≥ 3` = builds qui « marchent »). **ÉTENDU round 8 — COUVERTURE DE TOUTES LES FAMILLES** : le
  filtre `wins_at_capture ≥ 3` ne distingue pas **compétence de chance** → le pool FIFO biaise vers les familles à
  win-rate élevé (poison > tank > … > choc ; **Backpack Battles, steam mai 2026** : « pairing you up against the
  best builds pulled from thousands of games with the best combined skill AND luck »). **Si le cold-start IA est
  3 poison + 2 tank** (les mieux calibrés), un joueur **choc** en S1 ne voit **jamais** de ghost choc à son tier →
  abandonne l'archétype (biais de sélection par pool). → **spécifier que le cold-start ranked = 6 builds : 1 burn
  fort + 1 bleed fort + 1 poison fort + 1 rot fort + 1 choc fort + 1 tank** (1 par famille, les plus puissants).
  **0 code** (les Encounters existent), curation éditoriale. **Zone sans test** → `serveComp(ranked)` retourne
  1 build par famille (golden store). Source : ranked §3.3 ; Backpack Battles steam 2026.
- **Dépendance #Y (NOUVEAU round 6, ranked §5.1)** : le **comportement du FIFO ranked au reset de saison**
  (§6.3) est un litige (#Y). **Persistance filtrée** (`wins_at_capture ≥ 3`, le défaut §6.3) **n'exige PAS
  `sv`**. Le **vidage complet** (plus propre) **exige `sv`** (litige #V) pour identifier/ignorer un snapshot
  de saison précédente sans `dot_family`. **Position synthé** : `dot_family` est **déduit dynamiquement**
  (`Units.dotFamily(id)`, pas stocké dans le snapshot) → pas de `nil` dans le cas courant (un id existant
  récupère la famille du `units.lua` courant ; le seul cas cassant est un id devenu roster-only, rare +
  silencé) → **`sv` reste DIFFÉRABLE ; la persistance filtrée est le chemin par défaut qui ne l'exige pas**.
  **#V re-évalué en P0.5 SI on tranche #Y vers le vidage complet.**
- **ANCRE DE SNAPSHOT RANKED = #LL NEUF — capturer au PREMIER ACHAT, pas seulement à `startCombat` (NOUVEAU
  round 10, ranked §2.1, INTÉGRITÉ ASYNC)** : le snapshot est capturé à `startCombat` (`snapstore.lua:save`,
  00-state §5) → **un run ranked avorté AVANT `startCombat` (mauvaise boutique R1 → le joueur quitte) ne génère
  AUCUN ghost**. Le joueur qui concède sélectionne effectivement ses bons départs **sans pénalité ni
  contribution au pool** = faille d'intégrité silencieuse jamais nommée en 9 rounds. **Preuve directe** (Steam
  Bazaar, steamcommunity.com/app/1617400, août 2025) : « players can just concede until they get ideal rewards.
  There is no punishment. […] you kinda HAVE TO concede to win » ; Reynad (déc. 2024) a conçu le matchmaking
  Swiss AUTOUR de ce problème. **Aggravé chez nous** : pool FIFO 200 LOCAL petit → chaque ghost écarté par un
  concede = un de moins pour les autres → le pool ranked se biaise vers les bons départs R1, pas vers la gestion
  de l'adversité.
  ```
  RÈGLE D'INTÉGRITÉ "ANCRE DE SNAPSHOT" (#LL, ~5 lignes IO snapstore.lua:save, AVANT code ranked P2) :
    Déclencher save (mode ranked) dès : (a) shopBuys >= 1  OU  (b) round 2 atteint  OU  (c) startCombat (fallback)
      — whichever FIRST.
    Exclusion : shopTier==START_TIER AND slots_actifs==START_SLOTS AND shopBuys==0 (jour-0 identique = ghost nul).
    Flag debug : capture_reason = "first_buy"/"round_2"/"combat" (PAS dans toComp).
    Effet : un concede APRÈS le 1er achat alimente quand même le pool → l'avantage du concede est NEUTRALISÉ
      (son build R1 sert au pool de ses futurs adversaires). PAS de pénalité directe (cohérent §6.2). Grimdark :
      « Le Puits garde trace de chaque descente, même avortée. »
  ```
  **Note round 10 (rejet d'un angle)** : la lentille ranked soulève aussi que le RNG de run seedé rendrait le
  concede « semi-déterministe » (identifier les R1 favorables). **REJETÉ comme justificatif premier** : spéculatif
  pour une bêta (le joueur ne lit pas `rng_state` en jeu normal). Le fix est adopté sur la justification POOL.
  **#LL ouvert** (Option A premier achat vs round 2 → recommandation : les deux, OR). **Prérequis P2.** Zone sans
  test → test que `save()` est appelé au 1er achat ranked + test que les runs avortées avant achat ne génèrent
  PAS de ghost. ⟹ **#Y RÉ-OUVERT** (§6.3 : impact sur la densité de la grâce 7 j). Source : ranked §2.1 ;
  steamcommunity.com/app/1617400 (août 2025) ; bazaar-builds.net/reynad-interview ; azurgames.com Kingdom Clash.
- **Source** : ranked §1.3/§2.1/§3.1/§5.1 ; Bazaar ghost pools séparés (vérifié) ; Bazaar sept. 2025
  (séparation étendue + filtrage rang ≤ joueur).

### 6.5 Bifurcation Unranked / Ranked + ghost replacement + signal de pool pré-run — **REFONDU round 3, CONFIRMÉ round 4**

- **Quoi** : 2 pools séparés (champ `mode`). Unranked = sans pression. Ranked = matchmaking par rang +
  **ghost replacement FIFO** (rotation de méta, **ranked uniquement**).
- **Source** : Backpack (Unranked/Ranked) ; **Bazaar sept. 2025** : matching par rang + **transparence
  du pool avant la run** (bazaar-builds.net/announcement — **convergence directe avec notre pattern**).
- **SIGNAL DE POOL PRÉ-RUN (ranked §2.4 ; seuils = SOFT/HARD round 6)** : remplace le flag `quality.human`
  (couperet caché = MMR-shadow). **Afficher AVANT la run l'état du pool**, le joueur **choisit** (les 3 états
  mappent **exactement** sur `RANKED_MIN_POOL` SOFT=3/HARD=5, §6.4bis) :
  - 🟢 **Pool Vivant** (`count ≥ 5`) : « ghosts humains à ton tier — progression complète » ;
  - 🟡 **Pool Mince** (`3 ≤ count < 5`) : « peu de ghosts — progression partielle, certains combats vs
    Invocations » (ranked disponible, le joueur choisit) ;
  - 🔴 **Puits Silencieux** (`count < 3`) : « Pool insuffisant — les Invocations répondent, run non comptée »
    (ranked indisponible, fallback IA).
  **Local v1** : « Pool local : X ghosts à ce tier » (FIFO 200 ; **backend P4 = signal inter-joueurs
  exact**, ranked §1.4). `snapstore:poolStatus(tier)` → `{count, quality}`, RENDER pré-run, IO hors
  SIM, **0 invariant**.
- **PROPOSITION DE VALEUR RANKED S1 = INVOCATIONS (NOUVEAU round 7, ranked §2.2/§3.2, option a)** : en S1
  (< 50 joueurs beta), le ranked sera **quasi exclusivement contre des IA** 2-3 sem. (le Bazaar, backend
  mondial, a **quand même** souffert d'un ranked mal peuplé au lancement — steamcommunity 1617400). La
  distinction ranked/unranked **perd son sens** si les deux affrontent des IA → **alerte de COMMUNICATION
  (pas de drapeau pilier, l'async reste correct)**. **Décision (option a)** : **assumer la DA** — présenter
  le ranked S1 comme **progression personnelle contre les Fantômes du Puits**, pas un PvP compétitif
  classique. Texte pré-run S1 : « **LE PUITS S'ÉVEILLE — tes premiers rivaux sont les Invocations (Fantômes
  du Puits)** » → pas de tromperie, pas de déception. La faiblesse (peu de joueurs) devient **caractéristique
  thématique grimdark**. (Option b « ranked désactivé en S1 » **REJETÉE** : frustre les early adopters qui
  veulent le lancement compétitif.) **0 code, framing.**
- **FRAMING IDENTITAIRE RANKED/NORMAL — tableau i18n AVANT le code P2 (NOUVEAU round 8, ranked §2.4, doc 5 clés)** :
  le signal pré-run (§6.11) répond à « combien de LP ? » mais pas à « **pourquoi ce run ranked est-il différent
  d'un run normal ?** » (seganerds 2026 : 4 leviers du ranked — progress/rewards/fairness/reset ; le pré-run ne
  couvre que (1)). **2 framings pour 2 états psychologiques** (la DA structure le code, pas l'inverse) :
  | Moment | Normal | Ranked |
  |---|---|---|
  | Sélection de mode | « UNE DESCENTE DANS LE PUITS » | « UNE ÉPREUVE DU PUITS » |
  | Lancement du run | « LE PUITS ATTEND » | « LE PUITS PÈSE TON BUILD » |
  | Victoire run | « TU AS SURVÉCU » | « LE PUITS T'A RECONNU » |
  | Défaite run | « LE PUITS T'A CONSUMÉ » | « LE PUITS A JUGÉ TON BUILD INSUFFISANT » |
  | Saison active | — | « SAISON DES [NOM] — LES RÈGLES DU PUITS ONT CHANGÉ » |
  **Doit être écrit AVANT le code du mode ranked** (sinon cosmétique bolté après coup). 0 mécanique, 5 clés i18n.
- **Garde-fou** : **pas de ticket payant**. **Pas de decay avant masse critique**. Seuils X/Y =
  **à mesurer au launch** (hors scope lab).

### 6.6 Daily = « Contrainte du Jour » — 10+ CONTRAINTES COMPOSITIONNELLES + FILET PÉDAGOGIQUE — **#H tranché round 3, #H' tranché round 4**

- **Option (c) — Contrainte du Jour (ADOPTÉE round 3)** : la seed daily impose **une restriction
  mécanique** active toute la run daily. **La contrainte EST la différenciation** ; **score brut**
  `daily = wins × (10−lives)` (SAP). Modèle StS Daily (modifiers imposés). **Le joueur lui-même est
  contraint** — il ne peut pas « juste mieux jouer son build habituel ».
- **DAILY = UNRANKED + LEADERBOARD JOURNALIER SÉPARÉ — #BB CLOS round 8 (ranked §5.1)** : **Daily = UNRANKED**
  (score daily ≠ ranked MMR), **leaderboard journalier séparé** (modèle **StS Daily**). **Raison** : le gating
  par `win_rate ≥ 0,8×médiane` (ci-dessous) **exige que le daily fonctionne dès la S1**, **avant** l'équilibre
  ranked → ne peut pas attendre. Si Daily=ranked, une famille dominante biaiserait la contrainte. **Les 2 modes
  partagent `state.lua`.**
- **SEED PARTAGÉ (date + contrainte) — la condition de #BB (NOUVEAU round 8, ranked §2.1/§3.1)** : le « unranked +
  leaderboard journalier » (acté r07) résout **la mauvaise moitié** — un leaderboard journalier à < 50 joueurs S1
  est **psychologiquement creux**. **La vraie valeur de la Contrainte du Jour est la SEED PARTAGÉE** : si tous les
  joueurs affrontent **les mêmes ghosts** ce jour-là, les résultats deviennent **comparables** (yurukusa 2026 :
  « use the date as the seed. The 'map' is shared. The score is earned. »). **Sans le seed partagé, le leaderboard
  mesure « qui a eu la meilleure chance de pool » → l'analogie StS Daily est PARESSEUSE** (StS Daily = run à seed
  partagée, comparabilité totale ; sans cette propriété on copie la forme sans le mécanisme). **Comparable même à
  10 joueurs** (« j'ai monté en 12 rounds, X vies » dans les **mêmes conditions**).
  - **Quoi (1 ligne)** : dériver le seed de combat du Daily depuis `hash(date_ymd .. constraint_id)` au lieu d'un
    seed libre (`state.lua:startRound` → `self.rng = newRandomGenerator(daily_seed)` si `mode=="daily"`). Compatible
    déterminisme (invariant #4 : RNG injecté).
  - **#EE-ranked — scope du seed daily (NOUVEAU round 8, ranked §5.1)** : s'applique au **run entier (shop inclus)**
    ou aux **seeds de combat seulement** ? **Recommandation : combat SEULEMENT** — si le shop est aussi seedé, tous
    voient les mêmes offres → run encore plus comparable mais **perd la variance de build** (trop restrictif). Le
    seed daily contrôle l'**ordre de tirage des ghosts**, pas le shop. **Variante de l'invariant #2 à documenter**
    dans `seed/tests.md` (« même seed daily → même suite d'adversaires »).
  - **Garde-fou** : le leaderboard journalier est **CONDITIONNEL au seed partagé** — sans lui, ne pas le présenter
    comme compétitif. **Zone sans test** → 2 sessions daily du même jour + même tier = même séquence de ghosts.
- **#H' TRANCHÉ round 4 (ranked §2.3/§3.4) — 10+ CONTRAINTES COMPOSITIONNELLES** : 5 contraintes =
  cycle 5 j = **entièrement prédictible** (neutralise le VRR ; StS a des **dizaines** de modifiers). →
  **mécanique compositionnelle** (évite 10 implémentations) : la seed combine **2 axes parmi 3** —
  famille `{burn, bleed, poison, rot, none}` × topologie `{anneau, ligne, croix, none}` × éco `{+2 or
  rang4+, −1 reroll, none}` → **12-15 contraintes distinctes** avec **2 variables de code**
  (`dailyConstraint = seedHash % #TUPLES`). Extension de 2 (prototype) à 10+ = **data + seed**, 0 code
  moteur. **Cible : 10 avant la fin P2.**
- **FILET PÉDAGOGIQUE (NOUVEAU round 4, progression §2.4) — tooltip de run AVANT d'accepter** : une
  contrainte (« Jour de Brûlure ») **présuppose** la maîtrise de l'archétype (burn = chaîne de
  connaissances) → pour un joueur 0-5 wins, daily sans contexte = session punitive (à rebours du
  post-combat co-prio 1). **StS présente ses modifiers AVANT le run.** → panneau de contexte **avant**
  d'accepter : titre + 1 phrase (« unités de feu qui propagent leurs flammes aux voisins à la mort ») +
  2-3 icônes des unités burn rang-1 du jour. RENDER, 0 mécanique, ~1-2 h. **Obligatoire dès v0.11.**
- **CONDITION DE FAIRNESS — gater les familles par équilibre (NOUVEAU round 5, ranked §2.2/P2)** : la seed
  garantit la **reproductibilité**, **pas l'équité de difficulté inter-contraintes** (dev Spell Cascade,
  dev.to/yurukusa 2026 : « the seed is authentication, but the experience must feel fair »). « Jour de
  Brûlure » vs « Jour de Poison » **ne sont pas d'égale difficulté** tant que burn<poison structurellement →
  sur 10 jours, la progression d'un joueur dépend de **quelles contraintes tombent ses jours de jeu**, pas de
  son skill. **Remède** : une famille n'est imposée que si **`win_rate(famille) ≥ 0.8 × médiane`** dans
  `report.json` ; sinon le tuple `{famille, sigil, éco}` retombe sur **sigil/éco seuls** (« Jour de l'Anneau »).
  **Dépend de P0.5** (`dot_family` dans la sim) ; jusque-là, daily = axes sigil+éco. **Discipline de
  déploiement, 1 lookup, 0 code moteur.**
- **Timezone (note, ranked §5.5)** : jeu **local-first** → seed daily = `date_locale × prime` (fuseau-
  dépendant, comme SAP Arena / Spell Cascade). **Accepter la date locale en v1, documenter** ; date UTC au
  backend P4.
- **Sélection des ghosts daily (retention §2.5)** : `wins_at_capture ∈ [3,7]` → difficulté homogène
  pour tous. Pool thématique < 10 → seed générale (fallback transparent).
- **Q ouverte (progression Q3)** : ordre **pédagogique** des contraintes les 5 premières semaines
  (1 famille/sem) = courbe d'apprentissage déguisée. À documenter dans le ticket daily.
- **Transférabilité (ranked §3.3)** : contrainte dérivée de la **seed** (déterministe #2), **hors SIM**
  (filtre `U.pool` / lock sigil = RENDER/data). **Implémentation minimale** : 2 contraintes pour
  valider, puis étendre.
- **Source** : StS daily = rétention #1 (~7000 j/jour 8 ans après) ; StS2 Daily Climb.

### 6.7 Codex des synergies — BOOTSTRAPPÉ + **GRIMOIRE 3 CHAPITRES** — **ENRICHI round 4, RÉ-ANCRÉ round 6 (Ovsiankina)**

- **Quoi (round 2-3)** : tracker les 12 interactions de `tests/synergies.lua` (extensible aux ~30 de
  type). **3 ajouts de bootstrap (retention §2.3)** : (a) **flash d'accroche** 2-3 s en combat à la 1re
  occurrence ; (b) écran de résultat « Synergies découvertes : 2 » ; (c) onglet Grimoire : inconnues en
  **silhouette**. **+ Chapitre I reçoit les « Mentions de Témoin » saisonnières** (§6.12, cosmétiques datés).
- **GRIMOIRE 3 CHAPITRES (round 4, retention §2.2/Prop-B)** : restructurer `grimoire.lua` (2 onglets déjà
  prévus) en **3 chapitres à barre de progression visible** :
  - **Chapitre I — Afflictions** : les 12 synergies actuelles. Débloqué dès le run 1.
  - **Chapitre II — Essences** : les ~18 synergies de type (P1) + le **bestiaire (83 unités)**. Silhouette
    « ??? » tant que P1 absent / Chapitre I incomplet. **Débloqué à `synergies_base ≥ 8/12`** (pas 12/12)
    pour être **visible en saison 1**. **SEGMENTÉ PAR FAMILLE (NOUVEAU round 6, retention Q_R6_3)** : le
    goal-gradient s'efface au-delà de ~7 étapes (LogRocket 2024) → **83 unités ≠ 83 étapes** = pas de
    goal-gradient direct → **afficher « 11/15 unités poison découvertes »** (cible = 15 par famille, pas 83)
    pour que la progression du bestiaire reste **motivante par segment**.
    **RATIONNEL DU SEUIL 40 % + RISQUE MONO-FAMILLE (NOUVEAU round 10, rétention §2.2/Prop-B, Yu-Kai Chou CD4)** :
    Yu-Kai Chou documente un seuil de bascule empirique — **sous 40 % de complétion, une collection est « bruit
    de fond » (pas d'urgence d'engagement, même si l'Ovsiankina est présent)**. **Diagnostic ancré sur nos
    ressources** : un joueur **mono-famille** voit ~5 unités/run et son archétype en priorité → peut ne voir que
    15 des 83 sur 5 runs = **18 % → reste « bruit de fond » toute la phase early** = exactement le joueur engagé
    (optimise son achat) = le plus susceptible de churner sans hook. **La segmentation par section corrige ça** :
    ```
    [SECTION BURN] 4/13 essences (31 %) ████░░░░ → silhouettes des manquantes
    [SECTION BLEED] 7/13 (54 %) ████████░ ← SEUIL 40 % FRANCHI (urgence visible)
    → chaque famille passe 40 % en ~2-3 runs si jouée → Ovsiankina PERSONNALISÉ à l'archétype, pas à la collection.
    ```
    **Q_R10_3 (FOMO de famille)** : sections NON jouées = taille réduite, **pas de silhouettes** (compteur discret
    seul) → l'Ovsiankina se déclenche sur la section ACTIVE, pas de FOMO inter-familles. Le seuil 40 % = HEURISTIQUE
    (Yu-Kai Chou, observation), pas loi — mais la segmentation est utile INDÉPENDAMMENT (13 unités = goal-gradient
    plus motivant que 83). Source : rétention §2.2 ; yukaichou.com/collection-set-design-cd4 ; Åslund 2026.
    **+ COUCHE DE MAÎTRISE VISIBLE (NOUVEAU round 8, retention §2.3/Prop-C, P2 RENDER ~2 h, 3 règles data, 0 SIM)** :
    le Grimoire implémente la **découverte** (Ovsiankina) mais pas la **maîtrise manifestée** (SDT-compétence —
    le type de progression le plus durable, IntechOpen 2025 : 3 types = puissance / contenu découvert / **maîtrise**,
    la maîtrise a la plus longue durabilité de rétention). Dans un jeu **déterministe**, la connaissance se manifeste
    mécaniquement (12/15 unités poison connues → build poison optimal dès le round 1) ; le Grimoire **stocke les
    découvertes mais ne les traduit pas en capacités**. → **badge de MAÎTRISE à 3 paliers** (Goal Gradient maximal
    ≤7 étapes).
    **CORRECTION ROUND 9 (#JJ, retention §2.2/Prop-B) — VICTOIRE AVEC L'APEX JOUÉ, pas DÉCOUVERTE** : le badge v8
    (« 2/2 apex DÉCOUVERTS ») se déclenchait sur l'**exposition** (avoir vu l'apex en boutique au shopTier 5),
    pas sur l'**utilisation victorieuse** = du SDT-contenu (type 2) **renommé** SDT-compétence (type 3, arXiv
    2502.07423 : « skill use = exercice réel, pas reconnaissance »). Un joueur burn peut « découvrir » l'apex
    poison sans jamais le jouer → **fausse maîtrise** → déception attributionnelle (perd contre bleed, attribue
    à « la difficulté » au lieu de son manque de maîtrise) = **churn**. Dans un jeu déterministe, la maîtrise SE
    MANIFESTE par le résultat → ancrer le badge sur une cause CONTRÔLÉE (avoir joué + gagné), pas l'exposition :
    ```
    MAÎTRISE POISON (corrigé #JJ) :
      ○ INITIÉ    — défaut
      ◑ PRATICIEN — ≥1 run avec un apex poison dans le build ACTIF (même sans victoire = apprentissage actif)
      ● MAÎTRE    — ≥1 VICTOIRE de run avec ≥1 apex poison dans le build au combat final + ≥1 relique-E poison
                    acquise CE MÊME run
    Données : grimoire.lua stocke +1 bit/run {run_id, dot_family_dominant, apex_used:bool, won:bool}
      (snapshot.units capture déjà les unités du plateau + niveau, 00-state §5). ~5 lignes data.
    ```
    **Connexion au Nom de Build (§2.4bis)** : « Tes runs BRÛLEUR : 3× INITIÉ, 1× PRATICIEN. Prochaine étape :
    GAGNER avec [ASH_MAW] » → résout le passage **identité de run → identité DURABLE via maîtrise** (retention §2.2).
    Ancre le Grimoire sur les **2 piliers psychologiques** (Ovsiankina + SDT-compétence). **Zone sans test** → test
    `apex_used==true` si l'apex figure dans `snapshot.units` du run gagné. **Q_R8_2 résolue différemment** : non pas
    en abaissant le seuil, mais en rendant PRATICIEN atteignable en ~3 runs avec un apex, MAÎTRE en ~5 runs après un
    1er succès (progression réelle). **Q_R9_1 (parité MAÎTRE par famille)** : mesurer `P(run gagné avec apex)` par
    famille (lié #GG/CONFIG-CE — si `P_choc_maître ≪ P_poison_maître`, le badge choc est injuste). **0 invariant SIM.**
  - **Chapitre III — Abysses** : les ~20 synergies sigil×famille (P4, reliques G). Verrouillé jusqu'à
    Chapitre II complet. **MAIS son EXISTENCE doit être VISIBLE en silhouette dès P2** (retention §1.1).
    **RÉ-ANCRÉ round 6 (Ovsiankina, PAS Zeigarnik — retention §2.2)** : Nature H&SS 2025 (méta-analyse) —
    **Zeigarnik manque de validité universelle** ; l'**Ovsiankina** (tendance à **reprendre** une tâche
    interrompue) **tient**. La silhouette ne crée pas une « mémoire d'inachevé » (Zeigarnik) mais une
    **tension de reprise** (Ovsiankina + Goal Gradient). **Conséquence sur la SPEC** : la silhouette doit
    sembler **DÉJÀ COMMENCÉE, pas juste annoncée** — montrer **1-2 synergies en « ??? » avec une structure
    reconnaissable** (ex. « **[SIGIL ANNEAU] × [POISON] → ???** »), pas un simple titre verrouillé. C'est ce
    qui déclenche l'Ovsiankina (« quelque chose a été interrompu »).
- **Pourquoi (diva-portal 2026 ; Grid Sage 2025)** : un jeu à méta-progression **minimale** (TBOI, The
  Pit) retient via un **arc long à jalons visibles** (« path to Dead God »). Le Grimoire plat (« 30
  interactions ») n'a pas d'équivalent. L'arc 3-chapitres **EST** la séquence P1→P4 déjà planifiée — il
  ne crée pas de contenu, il le **présente** comme une progression (Ovsiankina/Goal Gradient : chapitre
  suivant « déjà commencé » = tension de reprise). Pas d'unlock de **puissance**, unlock d'**horizon**.
- **Pourquoi bootstrappé** : The Pit **ne peut pas s'appuyer sur un wiki au lancement**. **Remplace les
  unités lockées** : 10 T5 lockées = 12 % du pool + viole « égalisateurs » ; Balatro Jokers lockés =
  *outils*, pas *archétypes*.
- **GRIMOIRE MINIMAL AVANCÉ à v0.9.3 (NOUVEAU round 10, rétention §2.3/Prop-D, Åslund 2026)** : le calendrier
  place le Grimoire 3-chapitres en v0.11 (ranked) → pendant v0.9-v0.9.5 (P0/P0.5), les runs 1-5 sont joués SANS
  méta-progression visible. Åslund 2026 (DIVA) : la méta-progression LÉGÈRE (comme la nôtre) requiert PLUS de
  temps pour « devenir claire » → le hook est plus tardif. **Coder un Grimoire MINIMAL en // P0.5** :
  ```
  GRIMOIRE MINIMAL (v0.9.3, // P0.5, ~2 h RENDER, 0 SIM) : Chapitre I SEUL — reliques découvertes/vues +
    silhouettes des non-découvertes (21 total). [NOM] • [EFFET COURT] • [FLAVOR]. Lit grimoire.lua (déjà câblé).
    Q_R10_2 : relique VUE en boutique = silhouette + nom ; ACQUISE = + effet (modèle StS ; leurres retirés simplifient).
  GRIMOIRE COMPLET (v0.11) : Chapitre II (segmenté par famille) + III (sigils) + badges MAÎTRE/PRATICIEN.
  ```
  → un joueur qui finit son 1er run et voit « 3/21 reliques du Puits » a un ancre méta-progressif **dès v0.9.3**,
  dans la fenêtre la plus critique (runs 1-5). **Le P0 (lisibilité) reste la VRAIE précondition** (le Grimoire ne
  sauve pas un run confus) — ceci ne change pas la priorité de P0, il avance l'ancre. Source : rétention §2.3 ;
  Åslund 2026 (DIVA).
- **Garde-fou** : RENDER + écoute du bus + structure `grimoire.lua` (hors SIM). **Chapitre I MINIMAL à v0.9.3
  (// P0.5) ; Grimoire COMPLET pendant P2**, pas P4. **0 invariant.**

> **PLAFOND DE CONNAISSANCE — CRITÈRE D'ALARME (round 3, articulé round 4)** : la progression de
> connaissance a un **plafond** (~30 interactions → le Codex ne retient plus). **Calcul** : ~72 runs ;
> **un joueur très actif (5 runs/sem) atteint le plafond DANS la saison 1**. → drapeau `tools/sim.lua
> --knowledge-ceiling` **+ critère production** : `season_wins ≥ 50 ET Grimoire.synergies ≥ 25/30` →
> **prototyper 1 relique G PENDANT P3**. **L'arc 3-chapitres (ci-dessus) est le véhicule** qui rend ce
> plafond moins brutal en attendant ; les reliques G + saisons sont le vrai relais.

### 6.8 Score de saison PERSONNEL visible — **round 2, complété par les marques (round 3)**

- **Quoi** : compteur `season_wins += nb_wins_ce_run` (toujours), affiché menu + fin de run. Reset à la
  saison.
- **Pourquoi** : la grille donne **0 à toute la zone 0-5 victoires** → progression visible. **Round 3** :
  `season_wins` est un **affichage secondaire** ; les **marques sub-tier** (§6.2) sont le signal
  **comparatif** ; **le moteur PRÉ-RUN (§6.11) est le vrai pull** (round 4 : `season_wins` ne lance pas
  une session). RENDER + IO hors SIM, 0 invariant.

### 6.9 (réservé)

### 6.10 Dernier Souffle — **litige #A2 TRANCHÉ round 3 (existe, à 1 vie, relique seedée gratuite)**

- **Quoi (ranked §4.3)** : à **1 vie restante** (pas 0), le joueur reçoit une **relique tier-4 gratuite**
  (1-parmi-3 déjà seedé/équitable), catégorie E (transformative, **pas** runOp → ne touche pas #20),
  habillée « Le Puits vous donne une dernière chance ». **0 nouvelle mécanique.**
- **Pourquoi 1 vie, pas 0** : à 0, la prochaine défaite = game over → trop **rare** pour un impact de
  rétention. À 1 (sur 5), tension **haute mais pas désespérée** → near-miss plus fort (Clark 2009).
  **Confirmé round 4** : Bazaar « Fate » se déclenche à 0 Prestige (game over imminent) ; à 1 vie sur 5,
  la tension est **non terminale** = zone near-miss la plus productive (ranked §1.6).
- **Garde-fou** : seedée (déterminisme préservé), ne modifie pas le snapshot. **Zone sans test** → test
  que le Dernier Souffle se déclenche **exactement à `lives == 1`** avec le bon tirage.

### 6.11 MOTEUR PRÉ-RUN — récompense potentielle + distance au prochain tier — **NOUVEAU round 4 (litige #N), PRIORITÉ 1 ranked**

- **Le manquant #1 (ranked §2.1)** : les marques + `season_wins` sont des signaux **POST-run** ; ils
  n'**initient** pas une session. Le moteur du grind ranked est l'**incertitude résoluble** pré-run
  (« vais-je monter ce run ? » — seganerds.com 2026 : « uncertainty keeps you queuing »). TFT affiche
  le LP potentiel **à la sélection de mode** précisément pour ça (immortalboost).
- **Quoi** : dans l'écran de sélection (unranked / ranked), afficher la grille concrète + la distance :
  ```
  RANKED — DESCENDRE LE PUITS
    Ascension (10 victoires)   → +4 pts
    Chute honorable (8-9)      → +2 pts
    Descente (6-7)             → +1 pt
    Chute précoce (≤5)         → +0 pt (jamais de pénalité)
    PROCHAIN GRADE : Forgé — il vous manque 4 pts.      [primaire : horizon court 1-3 runs]
    Tier 2 — Condemned (12/35 pts) — Forsaken au suivant [secondaire : horizon moyen]
  ```
  **Sub-tier en primaire (AFFINÉ round 5, ranked §1.5/P4)** : **goal-gradient BORNÉ** (Nunes & Drèze 2006,
  « Endowed Progress Effect » : l'effet s'efface au-delà de **~7 étapes**). « 23 pts pour le tier » = **8-17
  runs** à `+4/+2/+1/0` = **hors horizon** pour 2-3 runs/sem ; la **marque sub-tier** est l'horizon **closable**
  (1-3 runs). Montrer les deux laisse le joueur choisir son horizon — le sub-tier est l'**appel à l'action**.
- **Transfert async (validé)** : notre grille est **statique** → l'affichage est plus simple que TFT
  (pas de calcul MMR). RENDER pur, pré-run, lit `playerRating` + `tiers[currentTier]` (IO hors SIM),
  ~15 lignes + barre. **0 invariant.**
- **SIGNAL D'ÉLAN DES 3 DERNIERS RUNS (NOUVEAU round 9, ranked §3.2)** : le signal pré-run montre la **POSITION**
  (LP, marque) mais pas l'**ÉLAN**. Deux joueurs à 14/35 LP (Forgé dans 2 runs) : l'un en progrès (3.5 pts/run),
  l'autre en plateau (1.5 pts/run sur 9 runs) — **même affichage, motivation de re-queue radicalement
  différente**. Management Science 2026 : « matchmaking = système dynamique où chaque match influence le suivant ».
  L'élan est le signal psychologique le plus direct du « je progresse » (yukaichou.com/leaderboard-design,
  Octalysis). **Quoi (RENDER pur, ~30 lignes, lit `player.ranked_history[-3:]`, IO hors SIM)** :
  ```
  trend = sign(lp_run[-1] − lp_run[-3]) →
    montant     : "LE PUITS RESSENT TON ASCENSION"
    descendant  : "LE PUITS ABSORBE TA CHUTE"  (factuel, SANS jugement)
    plateau     : "LE PUITS TE TIENT"
  Si < 3 runs ranked → afficher sans label de tendance (pas de signal faux).
  ```
  Zone sans test → test du label sur 3 issues fixes. Source : ranked §3.2 ; eurekalert.org/news-releases/1130401.
- **RECORD PROFONDEUR DU PUITS (NOUVEAU round 9, ranked §3.3 / #KK)** : afficher le **record-saison** de
  Profondeur (§6.2) dans le pré-run comme MOTIVATION (« ton record : 8e cercle ») — le « personal best » qui
  donne un axe de progression au joueur mid-core (7-3 répété) indépendamment du LP. RENDER, lit `depth_record`.
- **LITIGE #N (ranked §3.1)** : signal pré-run + signal de pool (§6.5) sur le **MÊME écran** (position
  adoptée — une décision = toutes les infos). Séparer seulement si le retour user montre une surcharge.

### 6.12 Cosmétique DATÉ de fin de saison — urgence émotionnelle du reset — **NOUVEAU round 6 (ranked §3.4)**

- **Lacune (ranked §3.4)** : les marques Survivant/Forgé/Ascendant (§6.2) sont **permanentes** → le reset de
  saison **n'enlève rien de mémoriel** = **pas d'urgence émotionnelle** (juste −20 % de points). Or le temporal
  landmark (Dai/Milkman/Riis 2014) fonctionne par l'**arc** : « j'ai accompli quelque chose **avant que ça
  disparaisse** ». Sans récompense **distribuée** à la fin, le Fresh Start est structurellement absent même
  avec un reset mécanique.
- **Quoi (RENDER + 1 entrée `grimoire:addSaisonTemoignage(season_id, best_rank)`, IO hors SIM, 0 invariant)** :
  à la **FIN** de chaque saison (avant le reset), distribuer **1 cosmétique DATÉ** par joueur ayant joué ≥1 run
  ranked — **non reproductible en saison suivante = rareté temporelle** :
  | Meilleur résultat | Cosmétique daté |
  |---|---|
  | ≥1 Ascension | **Icône « Puits Traversé — Saison N »** |
  | ≥8 wins ranked | **Titre « Forgé dans le Puits — Saison N »** |
  | ≥1 run ranked | **Mention « Témoin — Saison N »** (log Grimoire, Chapitre I) |
- **Vecteur (Q5.2 ranked, tranché)** : **log Grimoire + message au menu** (cohérent avec le signal
  d'appartenance §2.8, même endroit que la méta-progression) plutôt qu'un modal dismissable.
- **Garde-fou DA + pilier (DÉCISIF)** : **cosmétiques UNIQUEMENT** — zéro gameplay, **aucun item/unité/relique
  locké** derrière la récompense → aligné « **égalisateurs, pas de gates** ». Texte/icône = pixel art procédural
  ou texte pur. **Zone sans test** → `grimoire` enregistre le cosmétique **au reset** (pas avant, pas après).
- **Source** : ranked §3.4 ; Dai/Milkman/Riis 2014 (temporal landmark) ; LoL/HS:BG ranked rewards saisonniers
  (moteur de rétention validé). **0 invariant.**

---

## 7. CHANTIER P3 — Équilibrage auto-itéré + raffinement du pool + recourbe XP (v0.12, continu)

> **Pourquoi P3** : on ne tune pas un système qu'on n'a pas (types + axe choc + ranked d'abord).
> Continu dès P1. **Round 4** : `--poison-frac` et `--position-variance` **déjà mesurés en P0.5** (ne
> reviennent ici que pour le tuning fin) ; la **recourbe XP doit être robuste à la VARIANCE de durée de
> run** (#R). **Round 6 : §7.0 (tableau d'intention des constantes) est une PRÉCONDITION de toute sim P3.**

### 7.0 PRÉCONDITION — Tableau d'intention des constantes éco AVANT toute sim — **NOUVEAU round 6 (progression §2.3/§3.1)**

- **Renversement d'ordre, pas nouveau contenu (progression §2.3)** : un tableau d'intention **dit ce qu'une
  constante est censée faire** ; la sim **mesure si elle le fait**. **Sans le tableau AVANT la sim, on mesure
  sans savoir quoi optimiser** — les sims `--xp-climax`/`--reroll-cost-scaling` produiraient des **chiffres
  sans verdict** (« voulu ou accidentel ? »). Les 5 rounds ont **révélé** que plusieurs constantes n'ont
  **aucune intention documentée** (`REROLL_COST` copié de SAP, `SLOT_DECLINE_GOLD` arbitraire, `STREAK_CAP`
  non challengé). **Principe sourcé** : Machinations.io 2025 (« define the goal before measuring »).
- **Quoi (≈2-3 h éditorial, 0 code)** : créer **`docs/roadmap-lab/seed/eco-decisions.md`** (distinct de
  `seed/decisions.md` moteur) **comme 1re tâche de P3, AVANT `--xp-climax`** — une ligne par constante de
  `state.lua` : valeur actuelle | **INTENTION DE DESIGN** | comportement attendu en sim | signal d'alarme :
  | Constante | Valeur | INTENTION [TBD] | Attendu en sim | Signal d'alarme |
  |---|---|---|---|---|
  | `REROLL_COST` | 1 | **coût RELATIF dérive 1:1 (T1) → 1:5 (T5) car coût=rang (RÉVISÉ round 9)** — statique VOULU (late = exploration, grimdark) vs scalant T3+ vs soft-cap par signal [TBD user] | `[STATIQUE] reroll_T5 ≤ 1.5× reroll_T1` ; `[SCALANT] reroll_T3 ≈ reroll_T1` (politique `standard` only) | **`reroll_T5 > 2.5× reroll_T1`** → le ratio 1:5 incite massivement au reroll late = décider |
  | `BUY_XP_COST` | 4 | **pivot T4 (BUY_XP = 1 rang-4 en coût) intentionnel ?** [TBD user] — ratio 4:1 en T1-T3, **1:1 en T4** | `pivot_T4_decision_rate` ∈ [30 %,70 %] (§7.1) | <30 % = trop cher T4 ; >70 % = montée automatique ; achat XP dominant en T1-2 |
  | `XP_PASSIVE_RATE` | 1/round | **RÔLE À DÉCLARER (round 9 ; SOURCE CORRIGÉE round 10, progression §2.3) : [A] LEVIER mécanique (cible ratio 20-50 %) OU [B] RITUEL perçu comme DON ACTIF (Endowed Progress Effect, Nunes & Drèze 2006 — PAS Amabile & Kramer = travail signifiant, non transférable). PRÉCONDITION [B] : le signal §2.5bis frame la passive comme un DON grimdark (« LE PUITS T'ACCORDE SA MARQUE »), pas un fait du temps — sinon [B] = attente (frustration), pas progrès** [TBD user] | si [A] → `passive_vs_bought_ratio` ∈ [20 %,50 %] ; si [B] → 15-25 % naturel | si [B] et <15 % → améliorer le signal §2.5bis, NE PAS buffer la passive |
  | `GOLD_PER_ROUND` | 10 | budget contraint sans banque | max 3 achats rang-1 | plainte de pauvreté |
  | `STREAK_CAP` | 3 | égalisateur anti-snowball (+30 % budget max) | … | refus de jouer en loss-streak |
  | `SELL_REFUND_FRAC` | 0.5 | coût de pivot (asymétrie engageante) | pivots tardifs rares | pivot rate > 30 % en late |
  | `SLOT_DECLINE_GOLD` | 3 | trade tall/wide (avec option C XP) ; **grants FIXES rounds 2-7 NON liés aux victoires (round 9, Q1 = option a, "égalisateurs pas gates")** ; **point de parité EXACT avec achat rang-3 en T3 (Q3 progression — voulu ?)** | refus optimal < 60 % | refus systématique > 70 % |
- **INTERACTIONS DÉCLARÉES ENTRE CONSTANTES (NOUVEAU round 9, Q4 progression)** : les constantes **ne sont pas
  indépendantes** — ajouter une section « interactions » au tableau : `REROLL_COST × BUY_XP_COST` (reroll 1g vs
  XP 4g = reroll 4× moins cher que monter → incite-t-on à reroller plutôt qu'à monter ?) ; `SLOT_DECLINE_GOLD ×
  REROLL_COST` (décliner un slot = 3 rerolls → décliner finance-t-il l'exploration plus que le leveling ?). Ces
  interactions doivent figurer pour que la sim P3 sache quoi mesurer.
- **TABLE DU PLAFOND NATUREL DE LA PASSIVE — AVANT `--xp-climax` (NOUVEAU round 10, progression §2.1/§3.5)** :
  la courbe candidate est calibrée pour un comportement acheteur, mais le PLAFOND NATUREL de la passive (1/round,
  dès round 2) n'est jamais calculé — et personne ne pose si la courbe est COHÉRENTE avec ce plafond. **5 lignes
  arithmétiques par courbe prédisent le verdict de `--xp-climax` SANS la lancer** :
  ```
  Plafond passif (policy = 0 BUY_XP, passive dès round 2 ; XP totale = rounds − 1) :
    {2,5,10,18} : T2=R3 / T3=R6 / T4=R12 (OK run médian 14R) / T5=R19 (passif JUSTE à la fin d'un run long
      17-19R → RISQUE : T5 passif élimine la tension finale).
    {2,5,10,20} : T5=R21 (jamais passivement sur un run normal → T5 TOUJOURS actif, plus propre pour [A],
      plus frustrant si le joueur ne BUY_XP pas).
  → Croisé avec la 6e métrique passive_vs_bought_ratio : sur run TRÈS long, le ratio passif est structurellement
    proche de 100 % (la passive domine MÉCANIQUEMENT, pas par choix) — à constater, pas à « corriger ».
  ```
- **Intentions `[TBD]` soumises à l'USER (Q4 progression)** : les **choix de design** (« est-ce voulu que
  reroll=rang-1 en T1 ? », « la passive est-elle [A] ou [B] ? », « `REROLL_COST=1` en T5 VOULU ou non ? ») appartiennent
  à l'user, pas à la sim → le tableau est rédigé avec des intentions proposées et **validé avant les sims P3**.
  **CORRECTION round 10 (progression Q1)** : trancher l'intention `REROLL_COST=1` en T5 comme VOULU (exploration
  late grimdark) ou NON VOULU **dans ce tableau** (pas TBD) — sinon P3 passe à chercher un problème qui est un choix.
- **Source** : progression §2.1/§2.3/§3.1/§3.5 ; Machinations.io 2025 ; Nunes & Drèze 2006 (Endowed Progress) ;
  `00-state §4.1-4.3` (calcul du plafond passif). **Garde-fou** : document uniquement, **0 code, 0 invariant.
  LECTURE SEULE du repo de jeu.**

### 7.1 Passe d'équilibrage — un levier à la fois — **+ drapeaux nommés/promus rounds 2-6**

- **Méthode** : `tools/sim.lua` (gros N), lift de co-occurrence + drapeaux d'outliers (σ). **Un seul
  levier/itération**, vert (σ, entropie), committé. Méthode MegaCrit (StS, 18M runs, GDC 2019).
- **Drapeaux prioritaires** :
  - **Recourbe XP ROBUSTE À LA VARIANCE + STREAKS + CO-CALIBRATION SLOTS (`--xp-climax`, litige #R, PRÉCONDITION — RAFFINÉ rounds 4-6)** :
    les seuils linéaires `{2,5,8,12}` + passive 1/round = tension **plate**. Tester `{2,5,10,18}` ET
    **`{2,5,10,20}`** [PH] (progression Q1 : à 14 rd médian, T5=18 → rush ≈ 14-17 % < 25 % cible).
    **Critère à 4 conditions (progression §3.1 round 5 + §2.2 round 6)**, la durée varie **10-19 rd** :
    (1) T4 jamais passif à 15 rd ; (2) rush T5 **≥20 %** du budget sur **run court (10-12 rd)** ; (3)
    rush T5 **≥10 %** sur **run long (17-19 rd)** ;
    **(4) CO-CALIBRATION boutique/slots (NOUVEAU round 6, progression §2.2/§3.3)** : `ratio = shopTier_moyen /
    slots_actifs_moyen` par round par politique — **cible < 1,5 à tout round** ; **si > 1,5 pour `rush_XP` (ou
    `rush_XP + option_C`) → déséquilibre structurel** (le joueur rush T3+ rounds 1-2 avec **3 slots** → voit des
    rang-3 P=20 % qu'il **ne peut pas placer** = avantage du tier **dilué**). 3-4 lignes de sim, données
    shopTier/slots déjà tracées.
    **HIÉRARCHIE DE REMÈDES (NOUVEAU round 10, progression §2.4 — ferme « détection sans résolution »)** : la
    condition 4 détectait le déséquilibre sans prescrire de remède (« calibrer ensemble OU limiter le rush » ont
    des implications radicalement différentes ; limiter le rush exigerait un coût variable dynamique, hors spec
    `state.lua`). Sans critère AVANT la sim, c'est une détection sans verdict — exactement ce que §7.0 doit éviter.
    ```
    Si ratio > 1.5 en rush_XP (ET <= 1.5 en standard) :
      Remède 1 [sans code, // P0] : vérifier si §2.5bis + slot-unlock horizon suffisent à réduire le ratio
        (comportement informé vs aveugle — la différence peut être le signal, pas la mécanique).
      Remède 2 [data] : BUY_XP_COST T1 → 5g (ralentit le rush sans bloquer ; retest condition 4 + --xp-climax).
      Remède 3 [mesure] : exclure rush_XP de la co-calibration (si le problème est propre à la politique extreme).
      Ordre STRICT : R1 avant R2 avant R3 (ne pas complexifier avant de mesurer si R1 suffit).
    ```
    **+ MODÉLISER LES STREAKS (round 5, progression §2.4/§3.3)** : calculer sur le budget **RÉEL** =
    `GOLD_PER_ROUND × rounds + Σ streak_bonus`, **pas** `10 × rounds` fixe (win-streak ~+24 or ; loss-streak
    ~+12 → le seuil bascule de **5 points** → **décide `{2,5,10,18}` vs `{2,5,10,20}`**). Clause : win-streak
    P50 + loss-streak P50 sur N=200 ; `std_dev(budget) < 30 %`. **+ dépend de `REROLL_COST` (§7.5)**.
    Sim : 3 politiques × 3 tranches × N=100. **Précédée du tableau §7.0. Avant de figer les cotes.**
    **FORME superlinéaire validée par la LOGIQUE DE DESIGN, PAS par la table TFT (CORRIGÉ round 8, progression
    §2.1)** : les seuils TFT **changent à chaque set** (wiki Riot : L4=10/L5=20 par palier ACTUEL ≠ table v7
    citée) et ciblent **2 XP/round sur 30 rounds** ≠ **nos 1 XP/round sur 15** → **citer TFT comme ancrage de
    VALEURS précises est non fondé**. La forme (tension croissante) est validée par la logique de design ; le
    **calibrage appartient aux sims sur NOS contraintes** (run 10-19 rd, 1 XP/round). **Ne plus écrire « cohérent
    avec TFT » — écrire « cohérent avec nos contraintes propres ».** Source : wiki.leagueoflegends.com/en-us/TFT:
    Experience (form-only) ; progression §2.1/§2.2/§2.4.
    **+ 5e MÉTRIQUE `pivot_T4_decision_rate` (NOUVEAU round 7, progression §2.2/§3.4)** : à `BUY_XP_COST=4`, le
    ratio BUY_XP/unité est **4:1 en T1-T3** (monter = sacrifice lourd = tension voulue) mais **1:1 en T4**
    (monter = même coût qu'une unité rang-4) = **pivot décisionnel** non documenté (intentionnel ou
    accidentel ?). `pivot_T4_decision_rate = P(BUY_XP vs achat rang-4 en T4)` sur N=200 — **cible [30 %, 70 %]**
    (ni dominant ni négligé = vraie décision). **<30 %** → BUY_XP trop cher en T4 ou rang-4 trop attractif ;
    **>70 %** → montée quasi-automatique en T4, tension perdue. Intention `[TBD]` soumise à l'user (§7.0).
    **+ 6e MÉTRIQUE `passive_vs_bought_ratio` (NOUVEAU round 8, progression §2.2/§3.2)** : aucune des conditions
    ne mesure la **dépendance au BUY_XP vs passive**. Calcul (state.lua : passive 1/round dès round 2) : sur un run
    médian 15 rounds, la passive seule (~13 XP) **atteint T4 vers le round 11 mais T5 est inatteignable
    passivement** → T5 = exclusivement BUY_XP. **Est-ce voulu ?** `xp_from_passive / (passive + bought)` sur N=200 ;
    cibles : **< 20 %** = passive = bruit (signal §2.5bis décoratif → buff ou simplifier) ; **20-50 %** = sain ;
    **> 60 %** = BUY_XP sous-utilisé (trop cher OU courbe trop facile passivement → durcir vers {2,5,10,20}). ~5-8
    lignes sim, **précondition du choix {2,5,10,18} vs {2,5,10,20}**. Intention `[TBD]` (Q1 : T5 = accès actif
    uniquement ?) soumise à l'user.
    **+ TROIS RÉGIMES DE TENSION ÉCO (NOUVEAU round 8, progression §3.3)** : le « pivot T4 » est le **3e** d'une
    série de 3 régimes ; les sims n'isolent que le 3e. **Une métrique globale masque des comportements opposés
    par tier** (un run peut satisfaire les conditions de courbe ET avoir des décisions plates en T2). 3 ratios de
    régime au tableau §7.0 :
    | Régime | ShopTier | Tension | Signal d'alarme (CORRIGÉ round 9, progression §2.3) |
    |---|---|---|---|
    | 1 (early) | T1-T2 | Recherche (reroll vs se contenter) | **`reroll_dominance_T1 > 0,45` ET `achat_rang_1_T1 < 1,5`** (pool T1 trop homogène) — politique `standard` only |
    | 2 (mid-early) | T2-T3 | Engagement (s'engager sur un axe vs diversifier) | **`engagement_rate_T2 = P(2e achat MÊME famille rang-2 vs 1re famille DIFFÉRENTE) ∉ [40 %,60 %]`** |
    | 3 (mid-late) | T3-T4 | Pivot (BUY_XP = rang-4) | `pivot_T4_decision_rate ∉ [30 %,70 %]` (déjà défini) |
    **CORRECTION ROUND 9 (progression §2.3, 2 seuils FAUX) :**
    - **Régime 1** : le seuil v8 `> 0,25` (= 2,5 rerolls/10g) est **TROP BAS** — `P(voir cible rang-1/reroll) ≈
      5/12 ≈ 42 %` → 3 rerolls = `1−(1−0,42)³ ≈ 80 %` de certitude = 30 % du budget = **comportement SAIN**.
      Nouveau seuil `> 0,45` (4,5 rerolls) **ET** `achat_rang_1_T1 < 1,5` (cherche ET n'achète pas = pool dilué).
    - **Régime 2** : la définition v8 `P(achat rang-3 en T2)` est **MÉCANIQUEMENT IMPOSSIBLE** — **les cotes
      rang-3 sont à 0 % en T2** (`00-state §4.3`, vérifié synthé). Redéfini : `P(2e achat même famille rang-2 vs
      1re famille différente)` = la vraie décision d'engagement (2 rang-2 même famille = pré-activation d'archétype).
    ~20 lignes sim (régime 2 = tracker les 2 derniers achats par famille en T2). **Le régime 2 cible la zone
    décisionnelle la plus importante pour la lisibilité du build** (lié à l'audit col B rang-3). Intentions `[TBD]`
    soumises à l'user.
  - **`--meta-convergence` (PRÉCONDITION du litige #A, conditionné round 4)** : N=200 runs/sigil ;
    `rang_convergence` = N où `win%(top_1) − win%(pool) > +2σ` stable. **< 8 runs pour ≥2 sigils →
    types d'abord.** **À mesurer sur une méta NON cassée** (après `--poison-frac` en P0.5, sinon
    convergence artificielle).
  - **Entropie de famille poison (`--family-entropy`/`--poison-frac`) — DÉPLACÉ EN P0.5 (§3.5)** : la
    cause structurelle (propagation 100 %) se mesure et se corrige **avant P1**. Reste ici un **suivi**
    si le tuning fin le rouvre (Q4 synergies : 50 % vs autre valeur).
  - **Hiérarchie ...>choc** : remonter l'apex choc — *après* l'axe D (#G) + la sim 4-configs. Levier =
    raffinement des 10 unités choc (jaugées en **`burst_DPS_eq`**, §3.1a) + calibrage de `N` (ampli).
    **`galvanizer` = outlier voulu, ne pas nerf aveuglément** (§3.1a).
  - **Double-comptage inc% (litige #B)** : lift sur builds mono-type ; `plagueAmp` hors-cap = voulu. **+
    le twist = `more` borné (§5.2) AVANT de mesurer.**
  - **Inc des reliques B post-rééquilibrage (relics §2.5)** : les inc des 4 B (`kings_bowl=0.20`/
    `ember_heart=0.30`/`weeping_nail`/`grave_cap=0.18`) sont calibrés sur la hiérarchie **actuelle**
    (poison>...>choc) = **le problème à résoudre** → **ré-évaluer APRÈS le rééquilibrage** (le principe
    « forte → inc faible » tient ; les valeurs changent). Anti-circularité.
  - **Slot-decline + option C + RECALIBRAGE SUR LA NOUVELLE COURBE (progression §2.2/§3.2, PROMU
    précondition)** : `SLOT_DECLINE_GOLD=3` peut rendre le refus **systématiquement optimal**. **Option
    C** : décliner = **+1 or + +1 XP passive** (trade largeur vs profondeur). **`SLOT_DECLINE_XP` à
    sim ∈ {0, 0.5, 1, 1.5} sur `{2,5,10,18}`** (round 4 : +6 XP valent 17 % de T5 sur la nouvelle
    courbe vs 22 % sur l'ancienne → la valeur `+1` n'est PAS transférable ; cible : refus ne domine pas
    de +5 % sur les runs longues). **Mesurer AVANT de figer.**
  - **Hunt médian (PROMU précondition)** : p50 rang-2 en T2 > 5 boutiques → correctif (pity/pool). **À
    mesurer AVANT de figer les cotes** (litige #E ; dilution déjà adressée par §3.1).
  - **Timing-shield + ampli burn-vs-shield** : **rapatriés dans la sim choc P0.5 (§3.4 Config D)**.
    Reste un suivi en P3 si l'axe D révèle un déséquilibre.
  - **Variance early / courbe inversée** : rounds 1-3 « délibérément généreux » (Balatro Ante 1→3).
    **Async** : filtrer les ghosts R1-3 à tiers/wins bas (réutilise §6.4).
  - **Métriques [PH] à figer une fois équilibré** : toutes les constantes éco (00-state §4).

### 7.2 Raffinement du roster — distinction NICHE vs retrait POOL — **lié à P0.5 (raffiné round 4)**

- **Quoi** : **après** l'audit identité (§3.1), la **décision de cohorte v7 (§3.2)** et le **champ
  `pool` optionnel**, appliquer les remèdes : NICHE → refonte d'axe (data) ; **POOL → retrait de
  `U.pool`** (garder en `U.order`). **Cible plafond ≤4 ET plancher ≥2** (§3.1). + **audit rang-5
  (§3.7)** : transform / stat-amplification / rétrograde rang-4. + **trancher `templar`/`runestone_golem`**
  (§3.1b).
- **Source** : « profondeur > largeur » (SAP 10/tier ; « 20 unités intéressantes > 83 plates »,
  marvel-snap §9.2 ; Giovannetti GDC 2019). **Ne pas ajouter pour ajouter.**

### 7.3 Cotes par rareté/unité + pity-SIGNAL (litige #E/#L) — **prérequis SIM, AFFINÉ round 4**

- **Quoi** : pool **uniforme par rang** aujourd'hui. **PRÉREQUIS** : mesurer le **hunt médian (rerolls)
  pour 3 copies par rang/tier** AVANT de figer les cotes. Seuils : rang-2 <5 boutiques = sain ; >5 =
  trop dilué.
- **Preuves convergentes** : rang-3 en T3 ≈ **12 rerolls** ; rang-2 spécifique ≈ 9.4 %/boutique après
  audit → ~6-7 rounds. → correctif **nécessaire** ; dilution déjà attaquée par §3.1.
- **Litige #E/#L — pity = SIGNAL sans garantie, seuil `max(N_abs, fraction × médiane)` (AFFINÉ round
  4)** : *deux lentilles* convergent (un pity **explicite avec garantie** neutralise le VRR — MDPI 2025,
  ScienceDirect 2025). **Synthèse adoptée** : pity **complémentaire**, **SIGNAL grimdark SANS chiffre**.
  **Seuil = `max(PITY_MIN_ABS, floor(PITY_FRAC × hunt_median[rang][tier]))`** avec **`PITY_MIN_ABS=3`
  [PH]** (NOUVEAU round 4, progression §2.3 : **plancher absolu** pour que le signal survive à l'audit
  de pool qui réduit la médiane) et **`PITY_FRAC=0.5`** ; cote interne +5 %/reroll **cappée ×1.5**.
  **Progression VISUELLE implicite (NOUVEAU round 4, progression §3.3)** : l'icône de l'unité cherchée
  **s'intensifie** à chaque reroll sans la voir (pas de chiffre, mais progression perceptible — ACM
  SIGCHI 2023 : il faut *percevoir* la progression vers la garantie). **Pas de freeze « avec coût en
  slot »** (SAP freeze = gratuit).
- **GEL DE BOUTIQUE — CRITÈRE STRUCTUREL, PAS « hunt médian » (NOUVEAU round 7, progression §2.1)** : le
  critère « si hunt médian > 3 rounds → geler utile » est la **mauvaise question**. Le freeze SAP a 2
  fonctions propres — **(A) report de décision** (« now or later ») et **(B) signal d'information** (séparer
  gelé/nouveau au reroll) — **aucune liée au hunt médian**. Dans The Pit : (A) est **structurellement
  invalide** (budget non reporté entre rounds → geler pour le prochain round = acheter avec un budget qu'on
  n'a pas encore) ; (B) est **peu marginale** (à `REROLL_COST=1`, explorer coûte déjà presque rien, vs SAP
  1:3). → **gel DIFFÉRÉ v1.5+ conditionnel à (a) report d'or inter-round OU (b) `REROLL_COST` scalant en
  T3-4** (qui rend B précieuse). **Précision (l'issue ne change pas)** : ancrer la décision sur les bonnes
  raisons empêche une future lentille de réintroduire le gel au prétexte du « hunt long ». **Couplé à la
  décision `REROLL_COST` (§7.5).** Source : SAP wiki (freeze gratuit, 1:3) ; gamedeveloper.com 2024 (temporal
  horizon).
- **Garde-fous** : or in-game ≠ monnaie réelle → pity sain. **Déterminisme (litige #L')** : seuil
  **seedé** (position dans la run), rencontre **variable dans la distribution seedée** (Boyle 2024 : le
  near-miss N+1 non livré est plus frustrant que la non-apparition → ne pas garantir une position fixe).
  **Sim Pop A (garantie) vs Pop B (signal)** sur `session_length_post_acquisition`.

### 7.4 Reliques — métrique de complétude + passe de qualité « 1 règle modifiée » — **après P1.5b**

- **Quoi** : (a) **enrichir `tools/sim.lua` du comptage reliques/archétype** (relics §Prop-D) — la
  fraction des runs d'un archétype qui voit ≥1, ≥2 reliques pertinentes → mesure exacte de la règle
  ≥2/archétype (§4.8). (b) Auditer les reliques pour que les mémorables **modifient une règle** ;
  enrichir les **T3 simplifiés** (ash_maw, pit_maw, wither_bloom, vein_splitter).
- **Source** : Balatro « 1 Joker = 1 règle » ; StS scope conditionnel. **Garde-fou** : [PH] ; chaque
  modif passe sim + golden. Décision #7 + invariant #20 préservés.

### 7.5 `REROLL_COST` : trancher garder-vs-scaler en sim T1-vs-T3 — analogie SAP CORRIGÉE — **PRIORITÉ 1 (RAFFINÉ round 6, précondition #R)**

- **ANALOGIE SAP CORRIGÉE round 6 (progression §2.1, wiki vérifié)** : depuis r01, « SAP fait 1 or donc
  acceptable » contextualisait `REROLL_COST=1`. **C'est FAUX en T1** : dans SAP, **tous les pets coûtent 3 or,
  reroll = 1 or → ratio 1:3, JAMAIS 1:1** (superautopets.wiki.gg/wiki/Gold ; fandom ; twoaveragegamers.com).
  Dans The Pit, `cost=rank` → **rang-1 = 1 or = prix d'un reroll → ratio 1:1 en T1** (le plus favorable au
  reroll), 1:3 en mid (rang-3, = SAP), 1:5 en late. **The Pit a en T1 un ratio que SAP n'a JAMAIS eu** →
  « SAP fait 1 or donc acceptable » **ne s'applique qu'aux rangs 3+**. **Ce n'est PAS un argument pour changer
  la valeur** — c'est un argument pour **ne plus citer SAP en T1** et **valider empiriquement**. **Corroborant
  (progression Q3)** : SHOP_SIZE=5, pool 12 rang-1 → **P(≥1 doublon en T1) ≈ 61,8 %** → reroller en T1 =
  souvent « éviter de voir 2× le même rang-1 » (décision réelle mais **mécanique**). Comparatif : **TFT reroll
  = 2 or = 40 % du revenu passif** (« players agonize », boosteria.org) ; **HS:BG reroll scalant**.
- **Deux options à trancher en sim, AVANT de figer la courbe XP** (le reroll affecte le budget réel, donc #R) :
  - **(a) GARDER `REROLL_COST = 1`** : la tension vient **entièrement de la qualité des 5 offres** → la
    garantie de pertinence (§4.1) et le pity-signal (§7.3) deviennent **doublement critiques**. Moins de
    friction nouveaux joueurs.
  - **(b) SCALER `REROLL_COST = max(1, shopTier − 1)`** (T1-2→1, T3-4→2, T5→3) : tension croissante naturelle,
    cohérent HS:BG. Risque : un joueur T5 qui chasse une 3e copie paie 3 or de reroll → mitigé par le pity-signal.
- **Sim `--reroll-cost-scaling` — 2 MÉTRIQUES SÉPARÉES T1-vs-T3 (RAFFINÉ round 6, progression §3.2)** : le
  pivot décisionnel **change par tier** (T1 = « chercher ou se contenter » ; T3 = « chercher ou investir ») →
  une seule métrique (rerolls/round) **ne capte pas** si le reroll est utilisé **par stratégie ou par défaut** :
  - **(A) `reroll_opportunity_cost`** = `P(reroll produit une unité strictement meilleure que la meilleure déjà
    visible)` par tier — **si < 30 % en T1 → reroll = bruit → garder=1 OK** ; **si > 60 % en T1 → reroll
    dominant → envisager scaler** ;
  - **(B) `reroll_by_tier_ratio`** = `rerolls / or total` par tier — **si T1 > 0,20 ET T3 < 0,05 → asymétrie
    structurelle → scaler** ; si T1 ≈ T3 → homogène → garder.
- **+ Tableau d'intention des constantes éco = PRÉCONDITION §7.0 (RAFFINÉ round 6, progression §2.3/§3.4)** :
  **rédiger AVANT cette sim** (sinon on mesure sans verdict). La **note SAP corrigée** (1:3 ≠ 1:1) y figure
  pour qu'une future lentille ne reverte pas la décision en T1 pour de mauvaises raisons.
- **Garde-fou** : toute modif de `REROLL_COST` **rebase le golden** (rerolls dans `headless.lua`), vérifie
  `tests/run.lua` vert, **signalée avant sim**. 0 invariant rompu avec ces gardes. **`REROLL_COST=1` reste
  ni confirmé ni rejeté** (tranché par la sim, pas par décret round 6).
- **Source** : progression §2.1/§3.1/§3.2/§3.4 + Q3 ; SAP wiki (1:3) ; boosteria.org (TFT) ; HS:BG reroll scalant.

---

## 8. CHANTIER P4 — Reliques G (sigils) + Contrainte Permanente de Saison + saisons (v0.13, gros chantier signature)

> **Pourquoi en dernier des gros chantiers** : le plus signature ET cher. Moteur de rotation méta —
> et vrai vecteur anti-stagnation inter-runs. **§8.0 Contrainte Permanente de Saison est AVANCÉE en P2
> (round 8 — livrable avec ranked v1, `grant_team` câblé = 0 moteur)** ; elle ne fait plus partie de ce
> chantier P4 (elle comble le plafonnement inter-saisons DÈS la S2). Prototyper 1 forme PENDANT P3 si le
> plafond de connaissance se déclenche (§6.7).

### 8.0 CONTRAINTE PERMANENTE DE SAISON — renouveau inter-saisons sans contenu — **NOUVEAU round 4 (ranked §2.2), AVANCÉE EN P2 round 8 (livrable avec ranked v1)**

- **Problème (ranked §2.2)** : TFT/HS:BG renouvellent la **méta** à chaque saison (nouveaux sets/
  tribus) → le joueur qui plafonne a du **neuf à apprendre**. The Pit v1 ne fait que resetter le rating
  (−20 %) ; les reliques G (vraie rotation) sont en P4, **trop tard** : le plafonnement intervient avant.
- **Solution (async-safe, vérifiée §4.2 ranked)** : **1 Contrainte Permanente par saison** active en
  **ranked hors-daily** (ex. « Ce Puits Brûle : unités burn +10 % cadence » ; « Puits Corrosif : toutes
  les unités démarrent avec 1 stack de poison »). C'est un **`teamFlag` injecté à `combat_start` depuis
  le seed de saison** (distinct du seed de run) → s'applique aux **2 camps** du snapshot **sans le
  modifier** (snapshots figés ; pool séparé par `season_id`, déjà dans `version`).
- **Pourquoi ça survit aux piliers** : (1) **async** — appliquée à `combat_start` côté résolution, pas
  codée dans le snapshot ; (2) **déterministe** — `teamFlag` depuis un seed fixe pour tous → golden
  inchangé (le golden ne tourne pas avec un `season_id`) ; **invariant #2 préservé** (offres + seeds de
  combat inchangés) ; (3) **DA** — « Ce Puits Brûle » = grimdark parfait, chaque saison a un nom.
  **Distinction des anomalies HS:BG rejetées** : HS:BG = aléatoire **par lobby** ; la nôtre est
  **identique pour tous** (seed de saison) et **choisie par le designer**, pas subie.
- **Place — AVANCÉE P4-light → P2 (NOUVEAU round 8, ranked §2.3/§3.2)** : c'est le mécanisme le **moins coûteux**
  et **plus impactant** pour la rétention S2 → **livrer AVEC le ranked v1 (P2)**, pas en P4-light. **Vérifié** :
  `grant_team` est déjà câblé (`ops.lua:276`) ; les `teamFlags` existants (`burnNoDecay`, `poisonNoCap`,
  `shockChain`…) sont data-driven et injectés à `combat_start` → **0 moteur**. **Pourquoi P2** : **sans
  différenciateur méta, la S2 = un reset de score dans une méta INCHANGÉE** — les joueurs S1 qui ont appris
  « poison domine » reviennent en S2 avec **le même avantage** ; le Fresh Start (Milkman 2014) **exige une
  nouvelle règle** pour être ressenti (yukaichou 2023 ; seganerds 2026 ; **POE 2** gamedesigning.org 2026 : « a
  build that dominated last season may be ordinary now » = différenciateur S1→S2 minimal). **4 `teamFlags`
  saisonniers pré-définis (data, `src/data/season.lua`)** : S1 `bleedSlow2x` (favorise bleed) / S2
  `burnPropagateAlways` (favorise burn) / S3 `poisonWeakenStack` (favorise poison) / S4 `shockChain` équipe
  (favorise choc). **Dépend de** P0.5 (`dot_family`) + P1 (types) pour les contraintes liées aux familles.
- **PRIORITÉ VISIBLE (round 7, RENFORCÉ round 8)** : sans reliques G (P4), la **S1 finit avec un méta stable** →
  un joueur qui plafonne en S1 n'a **aucune raison MÉCANIQUE** de revenir en S2 sinon le reset. La Contrainte de
  Saison est **le seul renouveau méta avant P4** → **critique pour la rétention S2** → **calendrier v0.11.3 avec
  ranked v1**, pas différée. **Croisé avec #A** (le `teamFlag` saisonnier biaise `--meta-convergence` → mesurer
  #A sur les runs **normaux non-ranked sans teamFlag**, ranked §5.3).
- **CRITÈRE DE SÉLECTION — #U RE-QUALIFIÉ round 9 (ranked §2.2/§3.4, POE 2)** : le débat v5-v8 « plus bas
  win-rate vs plus sous-représenté » était **mal posé** — les deux ciblent un **symptôme**. La Contrainte de
  Saison n'est PAS un outil d'équilibrage (= P3) mais de **renouveau méta**. **Cibler une famille à bas
  win-rate AVANT que son axe soit résolu (ex. choc avec #GG bloquant) = AMPLIFIER un archétype cassé** → le
  joueur S2 qui joue choc avec `shockChain` équipe découvre en cours de run que l'apex choc n'est toujours pas
  satisfaisant = **frustration S2 garantie**. POE 2 (game-wisdom.com mars 2026) co-livre toujours le `teamFlag`
  avec un équilibrage de la famille ciblée. **Critère révisé + PRÉREQUIS (doc, AVANT code P2)** :
  ```
  PRÉREQUIS DE SÉLECTION DU TEAMFLAG SAISONNIER :
    1. La famille ciblée DOIT avoir son axe marqué "résolu" dans seed/decisions.md
       (PAS de litige bloquant : #GG pour CHOC, désert-rang-3 pour BURN).
    2. Priorité parmi les "résolues" : (a) plus grand écart [potentiel théorique sim] − [win-rate réel] ;
       (b) à égalité : la moins représentée dans le pool ghost tier 3+.
    3. S1 (avant P3) : bleedSlow2x (bleed = axe résolu, sous-représenté vs poison, aucun litige bloquant).
    4. FALLBACK ABSOLU (si aucune famille "résolue") : modificateur de SIGIL pur (lineSlow2x : unités en
       Ligne +15 % vitesse) — indépendant de l'équilibrage des familles (5 sigils, 0 dette hors anneau).
  ```
  **#U reste OUVERT mais re-qualifié** (le prérequis est acté ; le choix précis dépend de P0.5/P3). **Prérequis
  bloquant : CHOC interdit comme cible tant que #GG non tranché.** Les 4 `teamFlags` v8 (`bleedSlow2x` /
  `burnPropagateAlways` / `poisonWeakenStack` / `shockChain` équipe) restent candidats SOUS RÉSERVE du prérequis
  (S4 choc gelé jusqu'à #GG ; S2 burn gelé jusqu'au désert rang-3 résolu).
- **PRÉ-ANNONCE DE LA CONTRAINTE 24-48 H AVANT LE RESET (NOUVEAU round 9, ranked §4.2, POE 2 Fresh Start
  incomplet)** : le Fresh Start (Milkman 2014) exige **3 conditions** — reset + nouvelles règles + **INCERTITUDE
  PARTAGÉE** (game-wisdom.com : « the moment when the new META is genuinely unknown »). Notre reset + Contrainte
  couvre 2/3 ; l'incertitude manque si « bleedSlow2x → build bleed » est connu d'avance. **Remède** : pré-annoncer
  la Contrainte 24-48 h avant le reset (maximise la spéculation collective) — 1 clé i18n `ranked.season_preview`
  + logique de timing (`days_to_season_end < 2`). **DA = « Présage » grimdark** (« LA SAISON DES SAIGNEMENTS
  APPROCHE — LES RÈGLES DU PUITS VONT CHANGER »), pas communication corporate (Q_R9 §5.4 ranked, décision
  éditoriale). Contrainte opérationnelle : la Contrainte finalisée ≥48 h avant le reset. Doc, 0 code maintenant.
- **Q ouverte (ranked §5.2)** : cumul avec la Contrainte du Jour ? → **non-cumulable** (la daily
  override la saison pour la run daily). **Zone sans test** → test que la contrainte de saison
  s'applique aux **2 camps**, golden inchangé.

### 8.1 Reliques G — la topologie via relique

- **Quoi** : reliques qui **redessinent la topologie** (croix/anneau/diamant/ligne) en **gardant 9
  slots** (1 forme = 1 archétype, jamais de puissance échangée — décision #4).
- **Source** : équivalent *actif* des lieux Snap + rotation TFT. Géométrie non-euclidienne = thème +
  mécanique fusionnés (CLAUDE §3).
- **Lien (relics §2.3, litige #M)** : la relique d'**adjacence** « +X % par arête active au build »
  (lue de `shapes[shape].edges`) — proposée pour `swarm_logic` mais **réservée ici** (récompense la
  **topologie**, pas la quantité). `swarm_logic` (wide) reste une relique de **quantité scalante** en
  P1.5b ; la version « par arête » est une **relique G candidate**. À trancher avec les reliques G.
- **DISTINCTION reliques POSITIONNELLES (P1.5b) vs reliques G (P4) — NOUVEAU round 10 (relics §2.5)** : les 4
  reliques positionnelles `axis_pact`/`bloodline`/`ring_hunger`/`horde_pact` (§4.11) **RÉCOMPENSENT** un sigil
  sans le MODIFIER (0 moteur, lisent `shape` au build) → **P1.5b, catégoriquement plus légères**. Les reliques G
  **MODIFIENT** la topologie (redessinent la forme) → **P4, gros chantier**. Les positionnelles comblent le trou
  de la signature DÈS P1.5b ; les G sont l'incarnation maximale (P4). Source : relics §2.5 ; CLAUDE.md §2.
- **Garde-fou** : **zone sans test** (profils d'exposition non-carré ; golden = carré seul). **Test
  obligatoire** : exposition par forme + déterminisme sous chaque sigil. Snapshot capture déjà `shape`.

### 8.2 Saisons + rotation de pool

- **Quoi (cadence RÉVISÉE round 6, §6.3)** : saisons **échelonnées par contenu** — **3 sem.** sans contenu
  (saisons 1-2), **4-5 sem.** post-tuning (P3+), **6-8 sem.** quand un lot de contenu accompagne (P4+ reliques
  G). **C'est en P4 (reliques G) que les 6-8 sem. sont justifiées** (contenu nouveau = durée longue, Fresh
  Start préservé). Avec **reset −20 %** (§6.3) + **fenêtre de grâce 7 j + FIFO persistance filtrée** (§6.3) +
  **cosmétique daté** (§6.12) + rotation légère du pool (reliques G / sigils « de saison ») + la **Contrainte
  Permanente** (§8.0).
- **Source** : Fresh Start Effect (Dai/Milkman/Riis 2014 : landmarks proches > lointains) ; « sans cadence
  saisonnière, pas de retour » (Loi 4 postmortems : Underlords mort sans Season 2). Rotation reliques G = « set
  rotation sans dev lourd ». SAP Weekly Pack.
- **Anti-analogie** : **PAS d'anomalies globales aléatoires par lobby** (HS:BG) — la variation est
  **choisie** (sigils, Contrainte de Saison), pas subie. **PAS de saison 6-8 sem. SANS contenu** (timer perçu).

### 8.3 Backend distant + Daily mondial (v1.0)

- **Quoi** : endpoint minimal save/serve de snapshots. Daily **mondial**. Capture des **effets aura/
  relique** dans le snapshot (v1 = effets de base) + **signal de pool inter-joueurs exact** (ranked
  §1.4 : impossible en local).
- **Source** : async par snapshots = économiquement supérieur (postmortems §3.3).
- **Garde-fou** : encodage **sûr** (tabulé, jamais `load()` externe). Ghost replacement déjà en §6.5.

---

## 9. Séquençage en jalons (vue d'ensemble révisée round 6, à contester)

> Solo dev, branches `<type>/<slug>` depuis `dev`, commit quand `tools/check.sh` est vert (CLAUDE §8).
> Chaque jalon = vert sur les 32 invariants (ou test modifié explicitement AVANT).

| Jalon | Contenu | Coût | Dépendances | Invariants touchés |
|---|---|---|---|---|
| **v0.9** | P0 §2.1-2.9 (lisibilité + carte risque + post-combat co-prio **+streak-loss** + Moment du Run/source+**placement**+**P75** + **§2.4bis NOM DE BUILD** + **§2.5bis BARRE XP boutique** + surprise de placement (drag intentionnel +cap 10) + **§2.8 SPECTRE AFFRONTÉ (trace d'impact, #Z=IA distincte)** + **§2.9 VRR BOUTIQUE (Phase 2 + enveloppe ≤20/run)** + **valider distribution des 3 signaux VRR avant codage**) | Faible | aucune (NOM DE BUILD dépend P0.5 dot_family) | +test post-combat, +test chaîne/source/adjacence golden, **+test nom de build golden**, +test arête-révélée + désactivation drag, +test compteur spectre, +test VRR boutique golden, +test barre XP no-crash MAX_TIER |
| **v0.9.3** | **P1.5a** §4 (garantie B-E **+ renforcée early** + **plague_communion #JJ compo joueur** + **feeding_frenzy 1 test** + `second_breath` + **`famines_math` #O option a + spec R.apply TRI STABLE id + test #21** + déprio F + **carrion_ledger tier 3→2** + **rôle temporel ACTIONNABLE + forked_tongue gating[#Q2-relics CLOS]** + **arc mid+late §4.8** + **§4.11 hiérarchie build-definition** + **inc-B [PH-DÉPENDANT]** + **hollow_choir pool-A→RÉORIENTÉE P1.5b (décidé)** + **sacred_shield [120 ticks]** + **décider venom_covenant/positionnelles spec**) **+ GRIMOIRE MINIMAL (Chapitre I, // P0.5)** — *data pure + RENDER grimoire min., // P0* | ~Nul (+2 h Grimoire min.) | aucune (Grimoire min. dépend grimoire.lua câblé) | **adapter #3** (compo+pool_state), **adapter #21 (tri par coût + STABLE id)**, +#18-21 ; +test Grimoire min. no-crash |
| **v0.9.5** | **P0.5** §3 (audit **10-col A-J + 3-col rang-5 E1/E2/E3** [+paires de niche col B, +cross-rank byakhee col E, +placement rot col I] + cohorte v7 (+`pool`?, +pool-A shield-renforts+hollow_choir) + **§3.7 RANG-5 BLOQUANT (skull_colossus RESTE burn niche tank-burn dps4→8 / deep_kraken croisé OU AoE colonne / APEX CHOC = NOUVELLE unité type=arcane-abyss, NON skull_colossus)** + **dispersion DPS P90/P10≤3×** + **singletons rang-1 (gnaw_rat)** + `dot_family`+lint + **choc AXE D CIBLÉ #S** sim 4-cfg+UI + **CONFIG-CE2 fiabilité (critère tranchage Option A auto-DoT)** + **palier choc-4 = Option B tickCount=2 [#HH CLOS]** + **C2 afflictionCount [+litige #CC wither_bloom]** + **CONFIG-PC plague_communion** + **§3.10 offer_decision_quality** + **§3.5 --pool-repr** + `--poison-frac` + `--no-weaken` + **tableau saturation ARÊTES (précondition P1)** + `--position-variance` (calibrer auras) + **burst_DPS_eq** + budget tank) — *data/doc + ≤2 réécritures (choc + afflictionCount) + data rang-5 (skull burn / nouvelle unité choc)* | ~Nul (+choc+data rang-5) | aucune (// P0) | choc + **C2 = rebaseline golden si concerné** ; **rang-5 data (skull burn_dps=8, nouvelle unité choc) = rebaseline golden si dans scénario / DOT_CAP_MULT** ; #22 préservé ; lint check.sh ; sims golden-safe si défauts |
| **v0.10** | P1 §5 (types, `dot_family`, **compteur GLOBAL PUR #D**, twist `more` borné ≠ T3 ≠ vide-T2 ; **burn-4 = burnIgnoreShield #W** ; **bleed-4 = bleedPierceShield + signal UI palier-2→4** ; **choc-4 = tickCount=2 [#HH CLOS]** ; **poison-4 = poisonWeakenDeep [SPEC À PROUVER]** ; **#FF = Option B symétrique [#II clos recommandé]** ; **précédé : tableau saturation inc + tableau saturation ARÊTES [+exception choc +bleed-par-rang] + test 2a/2b inter-famille (shield_caster actif) + baseline offer_decision_quality**) | Moyen | **P0.5** (dont apex choc + saturation arêtes) | +tests type ×2 paliers, cap ×3, **+test 2a/2b shield_caster** + 2 autres inter-famille ; −2 invariants vs hybride ; teamFlags palier ≠ T3 ; spécifier nature-stats du twist (choc = stacks/ampli/trigger, pas more) |
| **v0.10.5** | **P1.5b** (swarm_logic **scalante** + **shock_conduit (shaper-mid choc)** + **1 relique rot tier-4 [placement-indépendante]** + shield-pur + **hollow_choir→pierceShield [décidé RÉORIENTÉE, après colonne I, ≠ doublon bleed-4]** + **4 RELIQUES POSITIONNELLES sigil-aware [axis_pact/bloodline/ring_hunger/horde_pact, 0 moteur]** + **venom_covenant [granularité intra-famille poison, après sim]** + option C1 `apply_status` + **reconception wither_bloom si #CC**) | Faible-Moyen | **P0.5 (axe D + saturation arêtes)** | reliques gated → golden inchangé ; **positionnelles : test lecture shape + 0 sigil imposé** ; **garde-fou saturation anneau+resonance+ring_hunger ≤ cap×3** |
| **v0.11** | P2 §6 (ranked LOCAL sans pénalité + **§6.4bis pool ranked SÉPARÉ + ANCRE SNAPSHOT #LL (capture au 1er achat) + RANKED_MIN_POOL SOFT=3/HARD=5 + IA ranked=Encounters puissants** + **§6.11 pré-run SUB-TIER + score persiste inter-saisons explicite** + marques + **§6.12 cosmétique daté** + `slot_tier_composite`+test ±4 + signal pool 🟢🟡🔴 + **ranked S1=Invocations** + post-combat-ranked (near-miss hypothèse) + **Daily UNRANKED+leaderboard journalier #BB (gated équilibre)** + tooltip daily + Grimoire 3-chap COMPLET (III silhouette Ovsiankina, II segmenté par famille seuil 40 %) + badges MAÎTRE/PRATICIEN + Dernier Souffle + season_wins + reset conditionnel <3 + **#Z=IA formulation distincte** + **prérequis escalade IA (#KK)** + FIFO de saison persistance filtrée DOUBLE CRITÈRE + grâce 7 j) | Moyen-Élevé | P0 + **P0.5** (dot_family du post-combat ranked) + Grimoire min. (v0.9.3) | +snapshot (bucket,wins,composite,season_id,**mode**) ; rating=méta (0 invariant SIM) ; +test Dernier Souffle `lives==1` ; +test #LL save au 1er achat + pas de ghost si avorté ; +test serve(ranked)≠unranked + état SOFT/HARD + FIFO de saison `wins_at_capture≥3 AND composite` ; +test daily leaderboard séparé ; +test signal IA vs humain (#Z) ; **§2.10 gaté ghost_is_human [décision user]** |
| **v0.11.3** | **§8.0** Contrainte Permanente de Saison (teamFlag seedé, **famille sous-représentée**, **PRIORITÉ VISIBLE = seul renouveau méta avant P4**) | Faible | P1 (types) | +test contrainte sur 2 camps, golden inchangé |
| **v0.11.5** | **P1.5c** (runOp F → marchand) | Faible | marchand /3 codé | invariant #20 préservé |
| **v0.12** | P3 §7 (**§7.0 tableau d'intention éco PRÉCOND.** + **recourbe XP robuste variance+STREAKS+co-calibration slots #R** + **§7.5 REROLL_COST tranché (sim T1-vs-T3)** + équilibrage + pool + **pity-signal `max(3,…)`+visuel** + **slot-decline C recalibré** + reliques-qualité + meta-convergence (méta saine, unranked libres) + inc-B post-rééq) | Continu | P1+P1.5+P2 | adapter tests cotes ; **rebase golden si REROLL_COST change** ; +prototype relique G si plafond |
| **v0.13** | P4 §8.1-8.2 (reliques G sigils + **saisons 5-10 sem. échelonnées par contenu [RÉVISÉ round 10 : S1-S2 = 5 sem.]** — 8-10 sem. justifiées ICI car contenu nouveau) | Élevé | ranked+types | +tests exposition sigils |
| **v1.0** | P4 §8.3 (backend + Daily mondial + effets dans snapshot + signal pool inter-joueurs + **`sv` schema-version au 1er champ persisté / si #Y = vidage complet**) | Élevé | tout | étendre encodage snapshot |

**Hors-scope explicite** (différés sains) : passifs de ligne (façade/arrière), contres de taunt
(AoE-colonne/strip/furtivité), 6e famille « Ordre » (gen créatures), monétisation. **Le 6e type
non-DoT** (litige #F) est **orienté « aucun »** (la dispersion DPS tank = audit budget §3.1b, pas un
type). **L'axe choc** (litige #G) = **AXE D** + **#S** (ciblage), tranchés en P0.5. **Litiges CLOS round 6** :
**#D** (global pur), **#W** (burn-vuln intentionnel), **#T** (SOFT/HARD), **#O** (famines_math option a).
**CLOS round 7** : **#Q2-relics** (`forked_tongue` non silencieuse — `shockChain` consommé, grep synthé).
**Recommandé clos round 7** : **#Z** (IA formulation distincte). **Neufs round 7** : **#CC** (wither_bloom
post-C2), **#DD** (`--pool-repr` ordre), **#BB** (Daily ranked vs unranked).

---

## 10. Analogies paresseuses DÉJÀ démontées (ne pas re-proposer) — **enrichi rounds 4-6**

| Mécanisme tentant | Verdict | Pourquoi (source) |
|---|---|---|
| Intérêt / banque d'or | **NON** | Run court → spirale de mort débutants (tft §V3, balatro §9.3) |
| Grille 2D + rotation (Backpack) | **NON** | Hors-budget LÖVE + « À ÉVITER » (autobattler-design §4) |
| Héros nommés + Hero Powers | **NON** | Pas de héros dans la DA procédurale ; sigils+reliques jouent ce rôle (hs-bg §7.3) |
| Ciblage RNG en combat | **NON, jamais** | Viole déterminisme (pilier #2) ; ciblage déterministe = avantage (hs-bg §5.3) |
| Anomalies globales **aléatoires par lobby** | **NON** | Incompatible snapshots déterministes. *La Contrainte de Saison (§8.0) est l'alternative : identique pour tous, seedée, choisie* |
| Score Chips×Mult **/ DPS estimé pré-combat** | **NON** | Trompeur en système asymétrique ; LocalThunk cache le score (GMTK 2024) |
| Unités T5 lockées (Balatro) | **NON** | 12 % du pool T5 manquant + gate ; Grimoire 3-chap = horizon sans lock (Kammonen 2023) |
| Floors anti-churn (TFT/Snap) | **NON** | Double système LP/MMR caché = confusion #1 (immortalboost/boosteria) |
| Grille de score avec pénalité (Bazaar S1) | **NON** | **Bazaar pré-Legend = SANS pénalité** (steamcommunity 1617400) → notre direction |
| Rating par sigil/archétype | **NON** | 5 ratings = ranked inexploitable (litige #C clos, Backpack rating global) |
| Freeze « avec coût en slot » | **NON** | Aucun jeu de réf ; SAP freeze = **gratuit** (progression §2.2) |
| Daily `×(1+xp_spent)` | **NON** | Note l'**investissement** pas l'efficience — 3 lentilles |
| Twist de palier 4 = sous-cas d'un T3 | **NON** | Duplication (« burn 4 no-decay » = clone d'ash_maw, synergies §2.4) |
| Twist de palier 4 qui VIDE un T2 | **NON** | « poison 4 = slow » vide chitin_drone (synergies §2.3) |
| Axe choc C (amplifie le hit déclencheur) | **NON** | `dischargeShock` après `damage` → réordonne `hit()` (invariants #22-32) ; PoE no-stack/durée (synergies §2.1, vérif code) |
| **`build_cost_proxy` (Σ rank×level) en matchmaking** | **NON** | Volatil (merge → ×3) → filtre l'état de collecte ; `slot_tier_composite` monotone (ranked §2.2 ; Bazaar confirme matching par rang) |
| **Flag `quality.human` (grille /2 caché)** | **NON** | Couperet découvert après la run = MMR-shadow ; signal de pool **pré-run** transparent (ranked §2.4 ; Bazaar sept. 2025 converge) |
| **`feeding_frenzy` refondue « kills ennemis »** *(NOUVEAU round 4)* | **NON — DÉJÀ FAIT** | `frenzy_gain` existe (`ops.lua:211`), broadcast `on_death` **aux ennemis du mort** (vérif synthé). La relique récompense déjà les kills ennemis ; la « refonte » réécrit du code correct |
| **`plague_communion` « scalante +5 %/allié majoritaire »** *(NOUVEAU round 4)* | **NON — MAUVAISE RELIQUE** | Le code (`arena.lua:251`) conditionne sur `afflictionCount(CIBLE) ≥ 2`, pas le roster. Le « dead range » n'a jamais existé ; la relique réelle = payoff multi-affliction à GARDER (litige #J requalifié) |
| **`dmg/cd` uniforme appliqué au CHOC** *(NOUVEAU round 4)* | **NON — WRONG METRIC** | Le choc est un condensateur (cd long/dmg faible pour burst) → `dmg/cd` fait apparaître `galvanizer` « OVER » = nerf-aveugle. Mesurer en `burst_DPS_eq` (units §2.2 ; StS Totem) |
| **Seuil Moment du Run = médiane des 250 seeds FIXES** *(NOUVEAU round 4)* | **NON — BIAIS D'ÉCHANTILLON** | Sim déterministe → médiane d'un échantillon biaisé. P75 sur 1000 seeds aléatoires (retention §2.1 ; Kao et al. 2024) |
| **Pity-tracker avec garantie explicite** | **NON** | « garanti dans N » neutralise le VRR ; signal sans chiffre + progression visuelle (retention §2.3, ACM SIGCHI 2023) |
| **6e type « tank »** *(re-tenté round 4 via dispersion DPS)* | **NON (reste « aucun »)** | La dispersion DPS tank est un sujet d'**audit budget** (§3.1b), pas un palier (units §2.3 elle-même) |
| **Bleed/rot = rééquilibrer (redondance perçue)** *(NOUVEAU round 4)* | **NON (c'est de l'i18n)** | Les axes SONT distincts (slow vs amputation) ; le problème est la **perception** → texte tooltip (§3.1 col G, units §2.1), pas le moteur |
| Pool partagé inter-joueurs / Carrousel live | **NON** | Async = pas de lobby (tft §V1/§V6) |
| Mode Endless | **NON** | 10 victoires = durée contrôlée (atout async) |
| Monétisation multi-points / P2W | **NON, jamais** | Signal hostile (Artifact), trahison (SBB) ; cosmétique procédural seul |
| Boons mid-combat (Hades) | **NON** | Combat auto spectateur ; viole le firewall SIM/RENDER (hades §11) |
| **Ampli choc-D sur l'ordre fixe PUR** *(NOUVEAU round 5)* | **NON** | Amplifie burn-first = la famille absorbée par les boucliers ≠ celle du build → trahit la promesse. **Cible la `dot_family` du poseur** + fallback (#S clos, synergies §2.2 ; PoE Shock) |
| **Friction inter-familles MOTEUR** (ops bleed/rot s'excluent) *(NOUVEAU round 5)* | **NON (F1/F2)** | Casse la composabilité data (pilier d'archi) ; la « friction » PoE/LE vient de %res qu'on n'a pas. **F3-doc** (colonne I : niches orthogonales) suffit (units §2.1) |
| **`snapshot_schema_version` (`sv`) MAINTENANT** *(NOUVEAU round 5)* | **NON (différé)** | `toComp` ignore déjà les ids inconnus + `dot_family` déduit dynamiquement → pas de crash ; purge unique au passage P0.5 acceptable. `sv` **au 1er champ persisté** (reliques v2) — anti-complexité spéculative (ranked §2.3, #V) |
| **Guidance d'agence PROSPECTIVE au round 1-2** *(NOUVEAU round 5)* | **NON (doublon)** | Le besoin (placement lisible tôt) est **déjà couvert** par le surlignage d'arêtes en build (§2.1, P0 prio 1) ; frôle le tutoriel que la DA refuse (retention §2.4) |
| **Moteur pré-run DIRECTIF** (dicte l'éco du run) *(NOUVEAU round 5)* | **NON (v2 au plus tôt)** | Réintroduit le DPS-estimé pré-combat démonté ; le goal-gradient INFORME, ne DIRIGE pas (progression §2.3) |
| **Relique de contre-jeu méta MAINTENANT** *(NOUVEAU round 5)* | **DÉPRIO (P3)** | Touche la SIM (champ `previousCombatAfflictions`) ; post-combat + signal pool donnent déjà l'info ; Q DA non tranchée (#X) — après équilibrage (relics §2.6) |
| **Compteur de type HYBRIDE 2-global/4-adjacence** *(NOUVEAU round 6)* | **NON (#D clos global pur)** | Dead-zone TFT Galaxies (double condition count+adjacence) ; les auras d'adjacence sont DÉJÀ l'axe positionnel du type ; `--position-variance` mesure le win-rate, pas la frustration (synergies §2.1) |
| **Changer `REROLL_COST` ce round** *(NOUVEAU round 6)* | **NON (sim P3)** | L'analogie SAP est corrigée (1:3 ≠ 1:1) mais la VALEUR se tranche par `--reroll-cost-scaling` (2 métriques T1-vs-T3), pas par décret ; P(doublon T1)≈62 % justifie partiellement garder=1 (progression §2.1) |
| **Démonter le Moment du Run** *(NOUVEAU round 6)* | **NON (complémentaire)** | Il fait *rester* (mémorabilité mid-session) ; on AJOUTE le VRR boutique pour *relancer* — circuits cérébraux distincts, pas cannibalisation (retention §2.3) |
| **Citer Bazaar comme validation du « sans pénalité »** *(NOUVEAU round 6)* | **NON (contre-réf partielle)** | Bazaar a la PERTE de points depuis 2025 (backend mondial la légitime) ; citer format run-court + FIFO local + transparent (ranked §1.1) |
| **Afficher le nom des joueurs dans « spectre affronté »** *(NOUVEAU round 6)* | **NON (anonymat grimdark)** | La valeur est la TRACE d'impact, pas la connexion sociale (SDT-relatedness non testée, Ballou 2024) → l'anonymat grimdark est préférable (retention §2.1) |
| **Saisons 6-8 sem. SANS contenu** *(NOUVEAU round 6)* | **NON (timer perçu)** | Fresh Start Effect : landmarks proches > lointains ; sans contenu nouveau = stagnation = désengagement → 3-4 sem. échelonnées par contenu (ranked §2.1) |
| **`siege_breaker`/`soot_acolyte` traités comme budgets symétriques** *(NOUVEAU round 6)* | **NON (double-valeur)** | `siege_breaker` DPS=0,154+strip = carry+counter ; `soot_acolyte` DPS=0,111+aura = carry+aura → trancher la niche OU normaliser (units §2.2/§2.3 ; GhostCrawler) |
| **Différer `deep_kraken`/`skull_colossus` rang-5** *(NOUVEAU round 7)* | **NON (BLOQUANT)** | Stat-sticks `on_hit` purs ; `deep_kraken` DPS=0,154 > tous les T3 transforms (+34 %) + async = mur sans counter-play → §3.7 BLOQUANT, pas différable (units §2.1, code-vérifié) |
| **`bleedPierceShield` 1 pt/tick sans tester `shield_caster`** *(NOUVEAU round 7)* | **NON (test 2b obligatoire)** | `ward_weaver` re-bouclier 20/4 s **scalant** → niveau-3 (60/4 s) absorbe le drain = quasi-inerte (schéma `invulnT=30`) ; test 2b + repli 2 pts/tick (synergies §2.1, code-vérifié) |
| **`famines_math` tri sans clé secondaire `id`** *(NOUVEAU round 7)* | **NON (déterminisme)** | `table.sort` Lua **non-stable** → 2 unités de même coût = ordre variable = viole l'invariant #2 (snapshot async rejoué divergent). Clé secondaire `id` (relics §1.3 ; lua.org/manual/5.1#5.5) |
| **Reliques E « build-defining » au sens StS** *(NOUVEAU round 7)* | **NON (amplificateurs)** | Pas de downside ≠ boss relics StS (qui forcent le theming) → amplifient, ne créent pas → P1 (types) = PRÉREQUIS DE FUN, pas amélioration de contenu (relics §2.2 ; Giovannetti 2018) |
| **`bleedPierceShield` en burst PAR DÉFAUT** *(NOUVEAU round 7)* | **NON (repli conditionnel)** | Le drain progressif 1 pt/tick est l'identité « bleed ronge » voulue ; le burst est un REPLI SI la sim 2b prouve l'inertie, pas le défaut (synergies §2.1) |
| **`--pool-repr` AVANT `--poison-frac` (ordre strict)** *(NOUVEAU round 7)* | **NUANCÉ (même lot, pas ordre)** | La col B fait déjà le diagnostic qualitatif ; `--pool-repr` en est la validation quantitative → même lot P0.5, aucun ordre prouvé (#DD ; synergies §2.3) |
| **Vue Grimoire-par-archétype comme item P2 séparé** *(NOUVEAU round 7)* | **NON (subsumée)** | Le nom de build (§2.4bis) la fournit trivialement ; 2e segmentation avant validation de la 1re (par famille) = sur-engineering → note « à l'étude » (retention §2.4) |
| **Daily ranked sans pool dédié** *(NOUVEAU round 7)* | **NON (#BB : unranked)** | Famille dominante biaiserait la contrainte ; le gating `win_rate` exige que le daily marche dès S1 avant l'équilibre ranked → unranked + leaderboard journalier (StS, ranked §5.1) |
| **Apex choc `shockChain` « 0 moteur » sans trancher l'axe** *(NOUVEAU round 8)* | **NON (#GG bloquant)** | `dischargeShock` = burst axe A/B ; l'axe D (ampli tick) n'est PAS implémenté → « 0 moteur » faux si axe D adopté = réécriture `tickDots` (SIM). Trancher avant P1 (units §2.3, code-vérifié) |
| **Audit de paires au rang-2 SEUL** *(NOUVEAU round 8)* | **NON (rang-2/3/4)** | `corruptor`/`bile_spitter` rang-3 = DOMINANCE (op identique, weaken 0,06<0,10) ; `rust_sentinel` rang-4 = `stormcaller` rang-2 (op identique = viole #10) (units §2.1/§2.2, code-vérifié) |
| **`--pool-repr` « même lot » (pas d'ordre)** *(RENVERSÉ round 8)* | **NON (ordre STRICT, #DD clos)** | Retirer `corruptor` change la repr rang-3 poison → simuler `--poison-frac` avant la cohorte = pool à corriger ; isolation des variables (Kritz & Gaina 2025 ; synergies §2.1) |
| **Graver #FF/resonance dans P1 sans tableau de saturation** *(NOUVEAU round 8)* | **NON (spec à prouver)** | Un `more` croisé/scalant peut dépasser le seuil de saturation (Q2 des deux lentilles) ; golden rebaseline si co-présence → spécifier APRÈS la saturation, magnitude bornée (synergies §2.2, relics §2.2) |
| **Traiter les 5 sources VRR comme diverses** *(NOUVEAU round 8)* | **NON (même circuit)** | Toutes de valence positive = habituation au même circuit (Game Developer : « habituation by reward TYPE ») ; il manque le RELIEF = contraste hédonique (SDT Dark Souls → §2.10) |
| **Seuil Nom de Build fixe ≥4** *(NOUVEAU round 8)* | **NON (#EE progressif)** | Impossible à 3 slots → « ARPENTEUR » placeholder rounds 1-4 = zone churn 0-5 wins ; seuil progressif ≥2/≥3/≥4 (synergies §2.3) |
| **Daily à seed libre (sans seed partagé)** *(NOUVEAU round 8)* | **NON (#BB : seed partagé)** | Sans adversaires partagés, le leaderboard mesure la chance de pool = analogie StS Daily paresseuse ; 1 ligne `hash(date+constraint)`, comparable même à 10 joueurs (ranked §2.1) |
| **Différer la Contrainte de Saison en P4-light** *(RENVERSÉ round 8)* | **NON (→ P2)** | `grant_team` câblé = 0 moteur ; sans différenciateur méta la S2 = reset de score dans une méta inchangée (POE 2 : « a build that dominated last season may be ordinary »). 4 teamFlags pré-définis (ranked §2.3) |
| **MMR caché à la TFT** *(re-validé round 8)* | **NON (prématuré)** | 6-9 runs/saison de 3 sem. ne convergent pas ; `slot_tier_composite` monotone suffit pour le volume S1 (ranked §4.3) |
| **Partage social / streak des noms de build** *(NOUVEAU round 8)* | **NON (anonymat + exploration)** | Partage = croissance (marketing) ≠ rétention (psycho interne), anonymat grimdark ; streak punit l'exploration (pilier roguelite) (retention §6.1/§6.2) |
| **VRR négatif prévisible (régression de stats)** *(NOUVEAU round 8)* | **NON (déterminisme)** | Même build = même signal = feedback fixe, pas du VRR (le déterminisme invalide toute VRR négative prévisible — retention §6.3) |
| **Ancrer le calibrage de la courbe XP sur la table TFT** *(NOUVEAU round 8)* | **NON (forme seule)** | Seuils TFT set-dépendants (L4=10/L5=20 actuel ≠ table v7) + 2 XP/round ≠ nos 1/round sur 15 ; calibrage sur NOS contraintes via sim (progression §2.1) |
| **`plague_communion` ancrée sur la CIBLE (afflictions adverses)** *(NOUVEAU round 9)* | **NON (#JJ → compo du joueur)** | Un build mono-famille avec contagion la déclenche, un multi-famille restrictif non ; en async le flag dépend de ce que l'adversaire subit = hors agence. Ancrer sur `dot_family_count(joueur) ≥ 2` (relics §2.2, code-vérifié) |
| **Badge MAÎTRE sur la DÉCOUVERTE d'apex (exposition boutique)** *(NOUVEAU round 9)* | **NON (#JJ → victoire avec l'apex joué)** | Avoir vu un apex ≠ maîtrise = SDT-contenu (type 2) renommé compétence (type 3) → fausse maîtrise → déception attributionnelle = churn. Condition = VICTOIRE avec l'apex au combat final (retention §2.2 ; arXiv 2502.07423) |
| **`feeding_frenzy` = égalisateur de matchup** *(NOUVEAU round 9)* | **NON (amplificateur/luxe)** | `on_death` différé → silencieux dans les matchups perdants (jamais le 1er kill), fort dans les gagnants = LUXE pas enabler (Wayline). Corriger la classification + cibler la garantie aux builds aggro ≥20 (relics §2.4) |
| **Seuil §2.10 « 75 % PV » uniforme (tous rôles)** *(NOUVEAU round 9)* | **NON (calibrer PAR RÔLE)** | Tank à 25 % PV = banal (le taunt fait son travail) ; carry à 25 % = jamais → seuil brut inverse la signification. CONFIG-SURVIVAL : `P(hp<0.25 | victoire | rôle)`, bloque le code §2.10 (retention §2.4) |
| **Signal §2.10 attribuant la survie au PUITS** *(NOUVEAU round 9)* | **NON (#JJ → agence du joueur)** | Le plaisir d'ordeal vient de la reconstruction narrative interne (« mon placement a tenu »), pas de la félicitation externe → reformuler « TON PLACEMENT/TA SYNERGIE L'A MAINTENU EN VIE » (retention §2.1 ; arXiv 2603.26677) |
| **Ajouter #FF (ou coder §2.10) sans mesurer la lisibilité combat** *(NOUVEAU round 9)* | **NON (précondition `combat_effect_legibility`)** | Un tick = 6-12 événements simultanés ; au-delà de 3-5 le joueur ne perçoit rien → profondeur invisible = inexistante. Mesurer avg/max events/tick, batching si > 4 (synergies §2.1, Q3 r08) |
| **Coder P1 avec un palier choc-4 vide** *(NOUVEAU round 9)* | **NON (#HH : spécifier choc-4)** | burn-4/bleed-4/rot-4 ont un twist nommé, choc-4 = vide (`rust_sentinel` ≠ twist) → ghosteurs choc au shopTier 4 sans payoff. Option A (`shockChain arc`) vs B (`tickCount=2`), co-trancher avec #GG (synergies §2.2) |
| **Tuner la hiérarchie choc < poison comme un problème de PUISSANCE** *(NOUVEAU round 9)* | **NON (problème de FIABILITÉ)** | L'axe D est conditionnel à un DoT actif sur la cible = hors contrôle du joueur en async (#JJ) ; les 3 mesures P0.5 ne l'isolent pas → CONFIG-CE2 `discharge_effective_ratio` < 0.40 = fiabilité, pas magnitude (synergies §2.3, units §2.3) |
| **Compter les AURAS dans le plancher « ≥2 enablers/rang-3 »** *(NOUVEAU round 9)* | **NON (POSEURS ACTIFS only)** | Chaque famille a une aura rang-3 → le plancher "passe" artificiellement ; l'aura amplifie le rang-2, n'introduit pas un twist (SAP). Compter les poseurs `on_hit` → burn-r3 = 1 = désert confirmé (units §2.2) |
| **Cibler la Contrainte de Saison sur une famille à AXE NON RÉSOLU** *(NOUVEAU round 9)* | **NON (prérequis "axe résolu")** | Cibler choc (#GG bloquant) ou burn (désert r3) = amplifier un archétype cassé = frustration S2 (POE 2 co-livre l'équilibrage). Prérequis : axe résolu dans seed/decisions.md ; fallback = sigil pur (ranked §2.2) |
| **« SAP Arena » comme réf du ranked async** *(NOUVEAU round 9)* | **NON (analogie paresseuse)** | SAP Arena = IA, casual, JAMAIS de ranked ≠ SAP async-versus (ghosts) ≠ SAP v0.41+ ranked (saisons post-coup). Distinguer "Arena = réf RUN" vs "v0.41+ = réf SAISONNIÈRE" (ranked §4.1) |
| **LoL LP comme ancrage de calibrage** *(NOUVEAU round 9)* | **NON (comme TFT round 8)** | Rank inflation LoL 2023-2026 + hard reset Masters+ 2026 = pas de calibrage stable. Seule réf = `tools/ladder_sim.lua` + « 1 tier/saison à 2-3 runs/sem » (ranked §4.3) |
| **Reset de saison SANS pré-annonce (Fresh Start « reset suffit »)** *(NOUVEAU round 9)* | **NON (incertitude partagée manquante)** | Fresh Start (Milkman 2014) exige 3 conditions : reset + nouvelles règles + INCERTITUDE PARTAGÉE ; si « bleedSlow2x → bleed » est connu, l'incertitude manque → pré-annoncer 24-48 h (ranked §4.2 ; POE 2) |
| **Réorienter `skull_colossus` en apex choc (« le slot/HP/aggro convient »)** *(NOUVEAU round 10)* | **NON (DA-invalide)** | `type="bone", family="crane"` (crâne osseux) + électricité = incohérence thème/mécanique (décision #3, le différenciateur) ; tous les units choc = `type=arcane/abyss`. Le stat-line ne fait pas l'identité = analogie mécanique paresseuse → NOUVELLE unité choc (units §2.1/§2.2, code-vérifié) |
| **Diagnostiquer `skull_colossus` « carry burn » par DPS_frappe** *(NOUVEAU round 10)* | **NON (confond 2 axes)** | DPS_frappe (mélée 0.131) ≠ burn_dps (4, SOUS le rang-1 ash_moth=7) → tank-burn opaque, pas carry. Audit 3 colonnes E1/E2/E3 ; remède = burn_dps 4→8 ou sacrificiel, PAS apex choc (units §2.1/§2.3) |
| **Milkman 2014 justifie 3 sem. de saison** *(NOUVEAU round 10)* | **NON (landmark naturel ≠ reset arbitraire)** | Milkman étudie des landmarks NATURELS (lundi, Nouvel An — préexistants) ; un reset est ARTIFICIEL → sa puissance exige une accumulation préalable (6-9 runs = session). Retenir Milkman pour le garde-fou BAS (jamais < 4 sem.), pas 3 vs 5 (ranked §4.1) |
| **« Bazaar mensuel = benchmark de cadence »** *(NOUVEAU round 10)* | **NON (pool mondial ≠ FIFO local)** | Bazaar = pool mondial (adversaires non répétitifs) ≠ FIFO 200 LOCAL (épuisé en ~20 runs) → la variété perçue s'épuise à des cadences différentes. 5 sem. = 10-15 runs = 1 tier + temps de régénération du pool (ranked §4.2) |
| **High-roll = problème de PROBABILITÉ (enveloppe VRR)** *(NOUVEAU round 10)* | **NON (FEEDBACK SÉQUENTIEL)** | Balatro produit le high-roll par activation SÉQUENTIELLE visible (30ms/Joker = attribution causale), pas la magnitude brute. Copier le résultat sans le mécanisme = high-roll invisible → spec séquentielle §2.4 (rétention §2.1 ; CHI 2025 n=1699) |
| **Capturer le snapshot ranked SEULEMENT à `startCombat`** *(NOUVEAU round 10)* | **NON (#LL concede meta)** | Un run avorté avant `startCombat` ne génère aucun ghost → le concède sélectionne ses bons départs sans alimenter le pool (Steam Bazaar août 2025 : « kinda HAVE TO concede to win »). Capturer dès le 1er achat (ranked §2.1) |
| **Tier-gater les reliques F par NUMÉRO de tier** *(NOUVEAU round 10)* | **NON (valeur ≠ tier)** | `carrion_ledger` (+6 XP, tier 3) a sa valeur MAXIMALE en early (bypasse un palier XP) → tier-3 anti-optimal. Aligner VALEUR PAR PHASE et DISPONIBILITÉ → tier 3→2 (relics §2.2, code-vérifié) |
| **Amabile & Kramer 2011 pour la passive XP « rituel »** *(NOUVEAU round 10)* | **NON (travail signifiant ≠ jeu)** | Étude de motivation au TRAVAIL (238 personnes en entreprise) ; une passive invisible ne déclenche pas la même neurochimie qu'un progrès actif. Source correcte = Endowed Progress Effect (Nunes & Drèze 2006) + précondition de framing « DON » (progression §2.3) |
| **« Plus de slots = plus d'arêtes = plus de profondeur »** *(NOUVEAU round 10)* | **NON (hypothèse non vérifiée)** | La croix n'a que 4 arêtes (branches isolées) → 5 slots = 3 branches à 1 unité (0 arête). Saturation positionnelle PLUS à risque que de type (co-location requise, Kritz & Gaina 2025) → tableau de saturation des ARÊTES précondition P1 (synergies §2.3) |

> **CRITÈRE TRANSVERSAL POSITIF — `#JJ` ALIGNEMENT PAYOFF↔AGENCE (NOUVEAU round 9, garde-fou de design)** : la
> moitié des analogies démontées ce round partagent une racine. **Tout payoff de build (relique, badge, signal,
> palier) DOIT s'ancrer sur une cause CONTRÔLÉE PAR LE JOUEUR** — composition du build (`dot_family_count`,
> copies, aggro), placement (adjacence via sigil), ou décision (achat/level). **JAMAIS sur la cible** (afflictions
> adverses), **l'exposition** (unité vue en boutique), ou **la composition de l'adversaire** (ghost). En async,
> l'ancrage adversaire est **non-reproductible du point de vue de l'agence** du joueur (le ghost est figé, non
> choisi granulairement) — même si la sim est déterministe. Un payoff mal ancré crée de la **fausse maîtrise**
> (déception attributionnelle = churn). Source : keithburgun.net/pick-1-of-3 ; arXiv 2502.07423 (skill use) ;
> balatrowiki.org/w/Jokers (conditions sous contrôle > contextuelles). **Applique ce critère à toute nouvelle
> relique/badge/signal/palier au round 10 et en P0.5+.**

---

## 11. Idées « à l'étude » (compatibles piliers, valeur à challenger) — **révisé round 6**

- **`plague_communion` scalante sur le SEUIL RÉEL de la cible** (option (c) §4.2) — **ANNULÉE round 9 (#J
  re-tranché, #JJ)** : l'ancrage sur la cible est incompatible avec l'alignement payoff↔agence (§4.2). Si une
  scalante reste souhaitable, elle scale sur `dot_family_count(JOUEUR)` (3 familles → +30/4 → +40), pas sur les
  afflictions de la cible. À sim vs +25 % flat (condition `dot_family_count(joueur) ≥ 2`).
- **CONFIG-SURVIVAL — seuil §2.10 par rôle (NOUVEAU round 9, retention §2.4)** : `P(hp_ratio<0.25 | victoire |
  role)` sur N=200, role dérivé de aggro (≥40 tank / ≤8 carry / reste bruiser). **PRÉCONDITION BLOQUANTE du code
  §2.10** (le seuil 75 % PV est banal pour les tanks, jamais atteint pour les carries). ~15 lignes sim.
- **Leurre choc rang-1** (§3.7, #Q) : conditionnel à la latence VRR > 3 combats en sim.
- **Champ `pool` déclaratif** (§3.2, units §2.4) : recommandé, non-bloquant ; prioritaire si v8+.
- **Asymétrie de coût BUY_XP variable** (progression §3.2) : **SUBORDONNÉ** à la sim de la courbe #R.
- **Escalade de la passive XP** (+2 en round 8+) : à mesurer avec #R, pas un second changement non
  mesuré (progression Q2).
- **`swarm_logic` par arête** (relics §2.3) : relique **G candidate** (topologie), pas P1.5b (#M).
- **Exclusion de 2 unités rang-5/run** (anti-stagnation) : réduit la diversité, frôle le gate ; après
  `--meta-convergence`.
- **D-durée vs D-ponctuel** (l'ampli choc touche N ticks vs 1) : sous-question du litige #G, sim.
- **Ordre pédagogique des contraintes daily** (5 premières semaines, 1 famille/sem) : progression Q3.
- **Intel pré-combat** : révéler compo+sigil du ghost 3-5 s avant. **Risque** : ralentit la boucle
  (et le post-combat ranked §2.3 donne déjà l'info, sans spoiler la tension).
- **Relique de contre-jeu méta** (`war_scar`, relics §2.6/Prop-E) : lit le log post-combat pour renforcer
  contre les afflictions subies. **Subordonné** à la Q DA #X (le Puits subi vs appris) + après équilibrage.
- **`apply_status` (op slow/weaken sans dps)** (units §2.3, option C1) : nettoie `wither_bloom`/auras
  grant_bleed ; naît en P1.5b quand les types ont besoin de conditions orthogonales (C2 ferme le faux signal
  en attendant).
- **Détection du profil joueur-passif** (retention Q_R5_3) : `reroll_count/round` + `placement_variance/run`
  → calibrer **quels** signaux activer (pas en ajouter). Diagnostic, pas mécanique.
- **`snapshot_schema_version` (`sv`)** (#V) : au 1er champ snapshot persisté (reliques v2), pas avant —
  **RE-LIÉ à #Y round 6** (requis seulement si #Y choisit le vidage complet du FIFO de saison).
- **`pool_priority` par famille de caster/adjuvant** (units §2.2/P-B) : offrir `ward_weaver` avant ses
  renforts plutôt qu'un simple retrait — alternative non explorée à pool-A.
- **`hollow_choir` réorientée en `pierceShield` (NOUVEAU round 6, relics Q2/§4.10)** : counter-bouclier léger
  = 1re relique de **counter ACTIF**, orthogonale aux 4 défensives, comblerait partiellement #X **sans toucher
  la SIM** ; déprio P1.5b, après la colonne (I) (révèle si un counter-bouclier comble un trou réel).
- **`soot_acolyte` carry-aura (NOUVEAU round 6, units §2.2, option b)** : garder DPS=0,111 + documenter
  « brûleur-prêtre » = niche hybride unique au burn (i18n seulement) — si la DA supporte un burn-carry grimdark.
- **Stat-stick burn rang-1 (NOUVEAU round 6, units §2.4)** : si `ash_moth` singleton est jugé un trou (pas
  une rareté voulue) → 1 unité rang-1 DPS≈0,09/HP≈40/op burn `dps=2`. Data, conditionnel à la décision cohorte v7.
- **Cosmétiques de saison : modal vs log Grimoire (NOUVEAU round 6, ranked Q5.2)** : tranché vers **log Grimoire
  + message au menu** (cohérent §2.8) ; modal réservé si le retour user montre un manque de saillance.
- **Vue Grimoire II PAR ARCHÉTYPE (NOUVEAU round 7, retention §2.4)** : « DÉCOUVERTES DU BRÛLEUR : 7/11 » —
  **subsumée par le nom de build (§2.4bis)**, conditionnée à (a) noms de build livrés ET (b) P1 (types) qui
  rend l'archétype non-ambigu (Q_R7_2/3). **Vue secondaire** (défaut = par famille déjà acté round 6), data-only.
  Pas un livrable P2 ; à intégrer si la 1re segmentation (par famille) est validée.
- **CONFIG-CE (Choc Early) — PROMU CO-PRIO APEX (round 8, synergies §2.4)** : déplacée de « diagnostic P3 » à
  **mesure co-prioritaire de la décision d'apex choc (P0.5, §3.7)** — l'apex sans correction de la latence early
  = apex jamais atteint (le joueur quitte choc au round 3). **N'est plus une idée « à l'étude » ; c'est une
  précondition de validité de l'apex (§3.7).**
- **Relique B SCALANTE « resonance_stone » (NOUVEAU round 8, relics §2.2/Prop-B — P1.5b candidate)** : `+5 %
  affliction_inc par unité du même dot_family` (team-wide, calculée au build) → coût d'irréversibilité **positif**
  (sans downside, à la Balatro : « cost to not committing ») ; le joueur qui pivote perd le scaling. **Nouveau op
  `relic_resonance_inc`** → pas P1.5a (data pure), **P1.5b** ; dépend de `dot_family` (P0.5) + tableau de
  saturation (sa magnitude y entre). **Complémentaire de #FF** (resonance = cohérence mono-famille ; #FF =
  diversification multi-familles) → traiter ensemble après la saturation. **Non gravé tant que la saturation
  n'est pas validée.** Source : balatrogame.fandom.com (scaling par tags) ; Wayline.io (commitment costs).
- **Vue Grimoire II PAR ARCHÉTYPE** : **subsumée par le nom de build (§2.4bis) + couche de maîtrise (§6.7)** —
  pas un livrable séparé ; à intégrer si la 1re segmentation (par famille) est validée.

## 12. Questions ouvertes (litiges — état FINAL après round 10)

1. **#A (P3, conditionné ; PRÉCISÉ rounds 6+9)** : P1 (types) vs P2 (ranked). `--meta-convergence < 8 runs` pour
   ≥2 sigils → types d'abord. **À mesurer sur une méta saine** (après `--poison-frac` ET `--no-weaken`) **et
   sur les runs UNRANKED LIBRES uniquement** (ranked §5.3 : les runs ranked ont un biais de sélection vers le
   méta dominant → convergence artificielle). **PRÉCISION round 9 (ranked §5.3)** : exclure de `--meta-convergence`
   **non seulement** les runs ranked teamFlag **mais aussi** les runs DAILY à contrainte familiale (« Jour de
   Brûlure ») — elles biaisent aussi la convergence mesurée sur les runs normaux.
2. **#B (confirmé code ; ENRICHI round 6)** : double-comptage inc% borné par cap ×3 pour l'output ; **le cap
   ne borne pas le `increased`/`more`** → **twist de palier 4 = `more` à borner séparément** — AVANT P1. **+
   TABLEAU DE SATURATION D'INC PAR FAMILLE (round 6, §5.2)** : rend #B **calculable** sans sim (poison à 0,90
   d'inc naturel = `[SATURATION_RISK]`).
3. **#C : CLOS** → rating global unique.
4. **#D : CLOS round 6 → GLOBAL PUR** (2 et 4, **sans** adjacence). TFT Galaxies dead-zone + les auras sont
   déjà l'axe positionnel ; `--position-variance` mesure le win-rate pas la frustration. `--position-variance`
   **repositionné** : calibrer les auras (§3.6). −2 invariants de test.
5. **#E / #L (P3)** : hunt 3e copie — pity = SIGNAL sans garantie, **seuil `max(3, 0.5×médiane)`**
   (plancher absolu) + **progression visuelle implicite** + cappé ×1.5. **#L'** : seuil seedé ⊗
   rencontre variable. Sim Pop A/B + hunt médian **après** nettoyage pool.
6. **#F (orienté « aucun », confirmé)** : 6e type non-DoT — les 11 shield/tank = enablers transversaux ;
   leur dispersion DPS = audit budget §3.1b **+ `siege_breaker` double-valeur (round 6)**, **pas** un type.
7. **#G (P0.5) ; #S CLOS round 5** : axe choc = **AXE D** + **D-ponctuel vs D-durée** (sous-question #G).
   **#S TRANCHÉ** : ampli sur la **`dot_family` du poseur** (fallback ordre fixe). Sim **4 configs** + latence
   VRR early (#Q) + burn-vs-shield ; **signal UI famille amplifiée obligatoire** ; rebaseline golden.
8. **#H (tranché c) + #H' (tranché round 4)** : daily = Contrainte du Jour, **10+ contraintes
   compositionnelles** (famille × sigil × éco), score brut `wins×(10−lives)` + **filet pédagogique**.
9. **#I** : grille `+4/+2/+1/0` + ~35 pts/tier + marques (p25) + écrémage explicite + signal pool +
   **pré-run §6.11** + **cosmétique daté §6.12**. Script `tools/ladder_sim.lua`.
10. **#J (RE-TRANCHÉ round 9 → ANCRAGE COMPO DU JOUEUR, #JJ)** : `plague_communion` s'active désormais si
    **`dot_family_count(BUILD JOUEUR) ≥ 2`** (≠ `afflictionCount(cible)`), +25 % flat. **Correction d'alignement
    payoff↔agence** (le payoff multi-affliction est enfin ancré sur la stratégie du joueur, pas sur ce que
    l'adversaire subit ; en async, l'ancrage cible était non-reproductible). Devient LE payoff relique des builds
    multi-types (interagit avec P1). **Magnitude = sim BLOQUANTE P0.5 (CONFIG-PC §3.9, condition recalibrée sur la
    compo joueur)** ; combo `festering`/`poisonNoCap` hors-cap à borner. **Annule la variante (c) scalante sur la
    cible.** Golden à grep avant code (rebaseline si build golden ≥2 familles). **PAS** un gate. §4.2.
11. **#K (intégré à #R)** : courbe XP recourbée — voir #R.
12. **#M** : relique wide = quantité scalante (P1.5b) vs adjacence par arête (relique G, P4).
13. **#N (round 4)** : signal de récompense pré-run (§6.11) + signal de pool = **même écran** (position
    adoptée ; séparer si surcharge UX).
14. **#O : CLOS round 6 → option (a)** « tes 3 unités les plus COÛTEUSES +30 % dmg / +20 % HP » + **spec
    `R.apply` (tri par coût) + test #21 AVANT P1.5a** (§4.5).
15. **#P (round 4)** : colonne « rôle temporel » des reliques (shaper/payoff) ; signaler les mismatchs
    fenêtre/rôle.
16. **#Q (round 4)** : latence VRR du choc en early ; médiane > 3 combats → leurre choc rang-1.
17. **#R (round 4, ex-#K ; ENRICHI round 6)** : courbe XP robuste à la **variance (10-19 rd) + STREAKS dans le
    budget réel + CO-CALIBRATION `shopTier/slots` (4e condition)** ; tester `{2,5,10,18}` ET `{2,5,10,20}` ;
    recalibrer `SLOT_DECLINE_XP` ; **dépend de `REROLL_COST`**. **Co-calibration rush_XP+option_C ouverte**
    (Q2 progression : archétype viable ou gaspillage ?). Précondition P3 (précédée du tableau §7.0).
18. **#S (round 4) : CLOS round 5** — ampli choc-D sur la **`dot_family` du poseur** (l'ordre fixe pur trahit
    la famille du build).
19. **#A2 (TRANCHÉ)** : Dernier Souffle, à 1 vie, relique tier-4 seedée gratuite (§6.10).
20. **Twists de palier 4** : règles ≤8 mots, ≠ sous-cas T3, ≠ vide-T2 (colonne F), `more` bornées (candidats
    §5.2 : **burn-4 = `burnIgnoreShield` #W clos** ; bleed-4 = `bleedPierceShield` + signal UI palier-2→4).
21. **Plafond de connaissance** : Grimoire 3-chapitres (chapitre II à `synergies_base ≥ 8/12`, **segmenté par
    famille** round 6) + prototype relique G PENDANT P3 si `season_wins ≥ 50 ET Grimoire ≥ 25`.
22. **Reliques G** : sous-ensemble minimal v0.13 (1-2 formes) + tests d'exposition AVANT le code ?
23. **Reset ranked conditionnel** : `< 3 runs/saison` → reset à 0 (pas −20 %) + message clair.
24. **Quand le backend ?** Ranked local + Daily local suffisent-ils à prouver la boucle ?
25. **#T : CLOS round 6 → SOFT=3 / HARD=5 progressif** (la valeur dépend de l'état du pool, pas d'un seuil
    figé — §6.4bis).
26. **#U (RE-QUALIFIÉ round 9, ranked §2.2)** : le débat « plus bas win-rate vs plus sous-représentée » était
    **mal posé** (symptômes). Vrai critère = **« axe RÉSOLU dans seed/decisions.md + plus grand écart [potentiel
    théorique sim] − [win-rate réel] »**. **Prérequis bloquant : CHOC interdit comme cible tant que #GG ouvert ;
    BURN gelé tant que désert rang-3 non résolu.** S1 = `bleedSlow2x` ; fallback absolu = modificateur de sigil pur
    (`lineSlow2x`). **Reste OUVERT** (choix précis post-P0.5/P3). §8.0.
27. **#V (round 5 ; RE-LIÉ à #Y round 6)** : `sv` (schema version) — **différé pour la SIM** (`dot_family`
    déduit dynamiquement → pas de `nil` dans le cas courant) ; **requis SEULEMENT si #Y choisit le vidage
    complet** du FIFO de saison. → ré-évaluer en P0.5 **quand on tranche #Y**.
28. **#W : CLOS round 6 → INTENTIONNEL** — burn-vuln-bouclier voulu (rock-paper-scissors + counterplay
    measurable) ; **twist burn-4 = `burnIgnoreShield` keystone** ; renforce l'archétype tank (§3.1 col H, §5.2).
29. **#X (round 5)** : relique de « contre-jeu méta » compatible DA ? (Puits **subi** vs **appris**) — Grimoire
    + post-combat impliquent « appris » → cohérent. **`hollow_choir` réorientée en `pierceShield`** est un
    candidat light (§4.10) → P1.5a après la colonne (I). Avant Prop-E (P3).
30. **#Y (NOUVEAU round 6 ; RÉ-OUVERT round 10)** : FIFO ranked au reset de saison — **persistance filtrée**
    (`wins_at_capture ≥ 3` **+ `slot_tier_composite` DOUBLE CRITÈRE round 10**,
    n'exige pas `sv`, défaut §6.3) vs **vidage complet** (exige `sv`/#V). P2, avant la spec FIFO de saison.
31. **#Z : CLOS round 8 (GATE)** — recommandé Option 2 (IA formulation distincte) ; **GATE BLOQUANT de §2.8**
    (sinon §2.8 ship silencieux pour la majorité S1). Décision DA finale à l'user (consciente, pas par défaut).
32. **#AA (NOUVEAU round 6 ; ENRICHI rounds 7-8)** : seuil + DA du signal VRR boutique (§2.9) — cible ~30 % des
    rerolls (Hopson) ; formulation « résistance », jamais 1er shop du round. **+ critère de PRÉVISIBILITÉ DE
    RÈGLE (round 7)** : Phase 2 (3e facteur distance-3e-copie). **+ PONDÉRATION HÉDONIQUE (round 8)** : le tableau
    de fréquence ≤20 brut agrège des poids différents → borne « ≤50-60 pondérées » (couper poids=1 d'abord).
33. **#BB : CLOS round 8** — Daily UNRANKED + leaderboard journalier, **CONDITIONNEL au SEED PARTAGÉ**
    (date+contrainte → adversaires partagés → comparable même à 10 joueurs ; sans lui = analogie StS paresseuse).
    Scope = **combat seul** (#EE-ranked). Avant code P2 (§6.6).
34. **#CC (round 7)** : `wither_bloom` après C2 → `afflictionCount=1` → **rôle multi-affliction effondré**.
    Reconcevoir (dps non-nuls) vs accepter (rot+slow+weaken cosmétiques). **CRITÈRE DE TRANCHEMENT DOCUMENTÉ AVANT
    P1 (round 8, §3.8)** ; code en P1.5b. Lié à C1 (`apply_status`).
35. **#DD : CLOS round 8 (ORDRE STRICT)** — `--pool-repr` AVANT `--poison-frac` **REQUIS** : preuve neuve (retirer
    `corruptor` change la repr rang-3 poison → simuler avant la cohorte mesure un pool à corriger). La nuance r07
    (« même lot ») tombe (isolation des variables, Kritz & Gaina 2025). §3.5.
36. **#Q2-relics : CLOS round 7** → `forked_tongue` **non silencieuse** (`shockChain` consommé `ops.lua:187`,
    posé `:276`). **RE-CADRÉ round 8 (#GG)** : `shockChain` = burst axe A/B → si axe D adopté, la reformulation
    n'est PAS « 0 moteur ».
37. **#GG (NOUVEAU round 8, BLOQUANT)** : apex choc — **Option 1 (2 axes coexistent : `shockChain` burst axe A/B
    + axe D ampli tick)** vs **Option 2 (`shockAmpMult` paramétrable → cohérence axe D, moteur minimal)**.
    Code-vérifié : `dischargeShock` = burst, axe D non implémenté → « 0 moteur » r07 corrigé. **À TRANCHER avant
    P1** (le palier-type choc-4 doit savoir sur quel axe il amplifie). §3.7/§3.4.
38. **#FF (NOUVEAU round 8 ; ENRICHI round 9)** : interactions inter-familles MID (aggravation croisée + contagion
    au kill) dans P1 — **Adopté SPEC À PROUVER en sim de saturation (§5.4), pas gravé.** Complémentaire de resonance
    (§3.6). **+ PRÉCONDITION round 9 : `combat_effect_legibility`** (avg/max events/tick, batching si > 4 — une
    interaction invisible n'existe pas, synergies §2.1). **+ directionnalité #II.** Trancher round 10.
39. **#EE (NOUVEAU round 8) : ADOPTÉ** — seuil Nom de Build **progressif** (≥2 early / ≥3 mid / ≥4 late) vs fixe
    ≥4 (impossible à 3 slots → fallback en zone churn). §2.4bis.
40. **#EE-ranked (CONFIRMÉ round 9)** : scope du seed daily = **combat seul** (shop libre, variance de build
    préservée ; SAP v0.47 daily mode confirme la séparation shop/combats). Variante invariant #2 à documenter. §6.6.
41. **#GG (NOUVEAU round 8, BLOQUANT ; DÉCOUPLÉ de #HH round 10)** : apex choc axe A/B vs D. **DÉCOUPLÉ round 10** :
    le palier choc-4 (#HH = Option B) ne contraint plus l'axe → #GG = uniquement l'axe de l'APEX rang-5. **ENRICHI
    round 10** : l'apex = **NOUVELLE unité rang-5 choc** (`type=arcane/abyss`, NON `skull_colossus` = DA-invalide,
    §3.7). CONFIG-CE2 (fiabilité + critère tranchage Option A, §3.7). Prérequis : choc interdit comme Contrainte de
    Saison tant que non tranché (#U). À TRANCHER avant P1. §3.7.
42. **#HH (NOUVEAU round 9 ; CLOS round 10 par #JJ)** : palier CHOC-4 — **Option B (`tickCount=2`, ~3 lignes SIM)**
    tranchée par #JJ (cause = compo du build, FORTE ; Option A arc → voisin adverse = partielle). **CLÉ : Option B
    compatible avec les 2 axes d'apex → DÉCOUPLE #GG.** §3.7/§5.
43. **#II (NOUVEAU round 9 ; CLOS recommandé round 10 par #JJ)** : directionnalité de l'aggravation croisée #FF —
    **Option B symétrique** (les 2 familles co-présentes du BUILD s'amplifient = condition FORTE #JJ) vs Option A
    directionnelle (condition partielle). Recommandation de clôture à **décision user** (rebaseline golden = garde-fou
    explicite, ~5 lignes SIM). §5.4.
44. **#JJ (NOUVEAU round 9, TRANSVERSAL — ADOPTÉ GARDE-FOU, pas litige ouvert)** : ALIGNEMENT PAYOFF↔AGENCE — tout
    payoff de build s'ancre sur une cause CONTRÔLÉE PAR LE JOUEUR (compo/placement/décision), jamais sur la cible/
    l'exposition/l'adversaire (non-reproductible en async). **Round 10 : devient un OUTIL DE CLÔTURE** (#HH, #II
    tranchés par #JJ). §10 (garde-fou) + §4.11.
45. **#KK (NOUVEAU round 9, ranked §3.3)** : Profondeur du Puits (2e dimension visible orthogonale au LP, round max
    atteint/saison) — recommandation : **les deux** (per-run au score-screen + record-saison au pré-run). **PRÉREQUIS
    round 10** : escalade IA visible (`encounters.lua`, 1 grep avant le code du signal — sinon plafond d'éco, pas de
    skill). Spec P2, 0 moteur. §6.2/§6.11.
46. **#LL (NOUVEAU round 10, ranked §2.1)** : ancre de snapshot ranked — capturer au **PREMIER ACHAT** (`shopBuys
    >= 1`) OU **round 2** (whichever first), pas seulement à `startCombat`. **Faille d'intégrité « concede meta »**
    (un run avorté avant `startCombat` ne génère aucun ghost → le concède sélectionne ses bons départs sans alimenter
    le pool ; Steam Bazaar août 2025). Recommandation : les deux (OR). ~5 lignes IO. **Prérequis P2, AVANT code
    ranked.** §6.4bis. ⟹ **#Y RÉ-OUVERT** (la grâce 7 j se remplit plus vite).

> **Neuf round 10** : **#LL** (ancre snapshot ranked — intégrité du concede). **CLOS round 10 par preuve (via #JJ)** :
> **#HH** (palier choc-4 = Option B `tickCount=2`, découple #GG) ; **#II** (directionnalité #FF = Option B symétrique,
> recommandé à décision user). **RÉ-OUVERT round 10** : **#Y** (impact de #LL sur la persistance filtrée). **RE-QUALIFIÉ
> round 10** : **Q_R9_2** (gate §2.10 sur `ghost_is_human` → BLOQUANT en bêta, majorité IA). **DÉCOUPLÉ round 10** :
> **#GG** de **#HH** (Option B compatible avec les 2 axes). **CORRIGÉ round 10** : `skull_colossus → apex choc`
> RETIRÉ (DA-invalide → NOUVELLE unité rang-5 choc).
> **Neufs round 9** : **#HH** (palier choc-4), **#II** (directionnalité #FF), **#KK** (Profondeur du Puits), **#JJ**
> (alignement payoff↔agence — garde-fou). **RE-TRANCHÉ round 9** : **#J** (`plague_communion` → compo du joueur).
> **RE-QUALIFIÉ round 9** : **#U** (critère Contrainte de Saison). **CONFIRMÉ round 9** : **#EE-ranked** (combat seul).
> **Litiges CLOS round 8** : **#DD** (`--pool-repr` ordre STRICT), **#BB** (Daily UNRANKED + seed partagé), **#Z**
> (gate bloquant §2.8). **CLOS round 7** : **#Q2-relics**. **CLOS round 6** : **#D**, **#W**, **#T**, **#O**.
> **Ouverts hérités** : **#A** (P1 vs P2), **#B** (inc + arêtes saturation), **#CC** (critère documenté), **#V** (sv,
> re-lié #Y), **#X** (relique contre-jeu → `hollow_choir`→pierceShield décidé), **#Y** (FIFO de saison, ré-ouvert),
> **#AA** (VRR boutique — ASSUME affichage séquentiel §2.4), **#GG** (axe apex choc), **#U** (cible Contrainte de
> Saison), **#M** (relique wide vs arête → lié positionnelles), **Q_R9_2** (gate §2.10, bloquant). **#S** clos round 5.

---

## 13. Index des sources

**Internes (repo, lecture seule)** : `00-state.md` (état + 32 invariants), `BRIEF.md`,
`round-0{1,2,3,4}.md` (synthèses), `seed/{decisions,mechanics,tests}.md`, `docs/research/*`. **Code
vérifié rounds 1-4** : `src/data/units.lua` (`type`=visuel ; `family`=procédural ; **`dot_family`
absent** ; ladder choc 10 unités l.79-332 ; `U.pool` l.488 ≠ `U.order` l.453 ; poison rang-2 = 6,
rot rang-2 = 2-3 ; budget : cinder_cur/zeal_inquisitor rang-2 DPS=0.118 > bellows_priest rang-3 0.111 ;
**galvanizer rang-4 DPS frappe=0.172 = outlier #1** ; **templar rang-3 DPS=0.146**, runestone_golem
rang-4 v7 DPS=0.125 ; rang-5 v7 skull_colossus/deep_kraken = stat-sticks),
**`src/data/relics.lua:34-73`** (21 reliques ; **`famines_math` l.34-35 = `relic_few_units {max=3}`
anti-growth** ; **`feeding_frenzy` l.38-39 → `frenzy_gain`** ; **`plague_communion` l.57-58 →
`plagueAmp=0.25`** ; `relic_affliction_inc`= poison/burn/bleed/rot, pas choc ; `forked_tongue` l.51-52
`shockChain=1` ; second_breath l.47),
**`src/combat/arena.lua:248-252`** (**condition RÉELLE de plague_communion = `afflictionCount(target.dots)
>= 2` sur la CIBLE**, `plagueAmp` = `more` post-cap), `:325-395` (ordre `hit()` : `damage → on_hit →
dischargeShock` → PROUVE que l'axe C réordonnerait `hit()` ; burn `tickDots` PAS d'ignoreShield l.432,
bleed/poison/rot ignoreShield ; tick choc n'inflige rien l.520-526 → axe D s'insère),
**`src/effects/ops.lua:208-217`** (**`frenzy_gain` EXISTE**, snowball cappé 6, broadcast `on_death` **aux
ennemis du mort**), `:219-231` (`spread_*_on_death` propage aux voisins du champ, profondeur 1, cap 14,
**bornable par `frac`**), `:22` (`DOT_CAP_MULT=3` borne l'output, `poisonNoCap` lève le cap de stacks),
`src/effects/stats.lua` (`(base+Σflat)(1+Σinc)·Π(1+more)`), `src/run/state.lua:50` (`SLOT_GRANT_ROUNDS`
2-7), `:68-70` (passive XP round 2+ ; `XP_TO_LEVEL={2,5,8,12}` ; BUY_XP=4/4), `:339`
(`rollRelicChoices(n)`), `src/board/shapes.lua`, `tools/sim.lua`, `tests/{props,golden,synergies,run,
relics}.lua`.

**Code vérifié round 6 (synthé + lentilles, relu ce round)** : `relics.lua:46` (`sacred_shield invulnT=30`),
`arena.lua:247` (garde `self.t < invulnT`), `arena.lua:58` (`self.t` en **ticks @60 fps**, FATIGUE_START=1020
≈17 s → `invulnT=30` = **0,5 s quasi-inerte**) ; `units.lua` DPS calculés (rang-2 spread **7,24×** : `witch`
0,181 → `shieldbearer` 0,025 ; `siege_breaker` l.377-380 **DPS=0,154 + strip_shield** ; `soot_acolyte` l.149-151
**DPS=0,111 = médian rang-3** vs auras 0,067 ; `ash_moth` l.100 **burn rang-1 singleton HP=26**) ;
`relics.lua:37-38` (`hollow_choir pierceHeal=0.40` — counter inexistant) ; `relics.lua:77-94` (`R.apply` `n=#comp`,
sans tri → spec #O option a) ; `ops.lua:22` (`poisonNoCap` × `plagueAmp` hors-cap), `:28` (`BLEED_DPS_CAP=12` ≠
`DOT_CAP_MULT=3`), `:135-140` (contagion).

**Concurrence (teardowns + critiques rounds 1-7)** : `competitive/{super-auto-pets,tft,balatro,
slay-the-spire,hs-battlegrounds,marvel-snap,the-bazaar,backpack-battles,hades,postmortems}.md` ·
`rounds/r0{1,2,3,4,5,6,7}-{progression-economy,ranked-competitive,relics,retention-addiction,synergies-effects,
units-power}.md`.

**Code vérifié round 7 (synthé, grep ce round)** : `ops.lua:187` (`shockChain` **consommé** : `local chain =
p.chain or (tf and tf.shockChain) or nil`) + `:276` (`shockChain` posé via `grant_team`) → `forked_tongue` non
silencieuse + apex choc 0 moteur ; `units.lua:362-364` (`ward_weaver` = `shield_caster {value=20, cd=240}` =
re-bouclier 20/4 s aux voisins, **scalant par niveau**) → `bleedPierceShield` absorbable ; `units.lua:421-423`
(`skull_colossus` dmg=11/cd=84 `on_hit burn`, **DPS=0,131**) + `:437-439` (`deep_kraken` dmg=12/cd=78 `on_hit
poison`, **DPS=0,154**) = stat-sticks rang-5 sans règle d'équipe ; `units.lua:402-403` (`byakhee` dmg=8/cd=50,
**DPS=0,160**) vs `:195-196` (`vein_splitter` dmg=4/cd=44, **DPS=0,091**) = inversion cross-rank 1,76× ;
`:446` (`gnaw_rat` bleed rang-1 singleton) ; choc dans `U.pool` = live_wire(r1)/4×(r2)/2×(r3)/4×(r4)/**0(r5)**.

**Sources web nouvelles du round 7** : Keith Burgun « Pick 1 of 3 is a missed game design opportunity »
(keithburgun.net/pick-1-of-3-is-a-missed-game-design-opportunity : couplage lâche=arbitraire/fort=évident →
métrique qualité d'offre §3.10) ; Wayline.io roguelike itemization (charge cognitive mixte → garantie B-E) ;
TFT Inkborn Fables learnings (teamfighttactics.leagueoflegends.com/dev/dev-tft-inkborn-fables-learnings : « big
vertical traits must have primary stars » → confirme #D global pur, angle lisibilité) ; PoE1 vs PoE2 Ignite
(poe2wiki.net/wiki/Shocked + archive PoE forums → confirme #W burn intentionnel) ; a327ex.com status stacking
(« 1 pet = 1 valeur ; Scaling Sensitivity Matrix bleed » → paires de niche + bleed contextuel) ; Slay the Spire
boss relics avec downside (slaythespire.wiki.gg/wiki/Relics + Giovannetti gamedeveloper.com 2018 « forced
theming » → reliques E = amplificateurs pas créateurs) ; GDC 2019 MegaCrit (gdcvault.com/play/1025731 « power
must match complexity » + « 18M runs/patch » → rang-5 stat-sticks bloquants) ; Entalto Studios (« build identity
clear within 2 min ; every archetype needs a closing move » → apex choc) ; dev.to/yurukusa 2026 (« names =
identity, not data » → nom de build §2.4bis) ; lua.org/manual/5.1#5.5 (`table.sort` non-stable → tri stable
`famines_math`) ; mobilegamereport.com 2026 (SAP « shop sequencing » → VRR boutique + représentation pool) ;
PSU.com 2025 (VRR pur vs règle visible → VRR Phase 2) ; Kao et al. 2024 CHI (amplification excessive réduit
l'agence → enveloppe fréquence VRR) ; Activision 2024 SBMM (activision.com/cdn/research/CallofDuty_Matchmaking_
Series_2.pdf : perte injuste amplifie le churn des tiers bas → grille sans pénalité consolidée) ; immortalboost
2026 (TFT MMR caché vs LP → `slot_tier_composite` proxy imparfait) ; bazaar-builds.net/patch-1-0-0 (Bazaar onramp
progressif → ranked S1 = Invocations) ; adriancrook.com (leaderboards amis > global → comparaison intra-tier) ;
TFT op.gg/lolchess (BUY_XP=4g, passive 2/round, seuils super-linéaires → pivot T4 + barre XP) ; HS:BG
hearthstone.fandom (upgrade 6g réduit 1/round → pivot T4) ; Nature H&SS 2025 (Ovsiankina 67 % resumption,
confirmé) ; gamedeveloper.com 2024 « Design of Decision-Making » (temporal horizon → gel critère structurel).

**Sources web nouvelles du round 9** : EurekAlert/Management Science (eurekalert.org/news-releases/1130401, juin
2026 : matchmaking dynamique considérant l'historique récent = +4-6 % engagement, Lichess 5,4M parties →
Profondeur du Puits #KK + élan 3 runs + 2 dimensions) ; arXiv 2603.26677 (Ordeal Pleasure in Souls-like : la
rétention vient de la reconstruction narrative interne, pas de la félicitation → reformulation §2.10 vers
l'agence #JJ) ; arXiv 2502.07423 (SDT compétence, 4 sous-composantes : skill use = exercice réel ≠ exposition →
badge MAÎTRE = victoire avec l'apex joué) ; game-wisdom.com/poe2 (POE 2 Fresh Start = 3 conditions reset +
nouvelles règles + INCERTITUDE PARTAGÉE → pré-annonce de saison §8.0 ; co-livraison équilibrage → #U axe résolu) ;
leagueoflegends.com/dev-ranked-2026 + dev-ranked-update-season-one-2025 (rank inflation 2023-2026 + hard reset
Masters+ → LoL LP invalide comme ancrage de calibrage, comme TFT) ; superautopets.wiki.gg/Version_0.28 (SAP 3
modes : Arena IA casual ≠ async-versus ≠ Versus ranked ELO → corriger « SAP Arena = réf ranked ») +
Version_0.41 (ranked seasons ajoutées juillet 2025, post-coup) + Version_0.47 (daily mode → #EE-ranked combat
seul confirmé) ; fairgame.us (skill-based matchmaking : « fairness = trust, not just math » → modificateur LP
borné ±1 visible) ; kydagames.com/designing-competitive-leaderboards-repeat-visits (personal best + rank =
motivation, réduit churn mid-core → Profondeur du Puits) ; yukaichou.com/leaderboard-design (Octalysis : élan =
signal direct de progrès) ; gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes (near-miss =
driver primaire de restart sans communauté → hiérarchie near-miss>identité S1) ; keithburgun.net/pick-1-of-3
(décision = orientation distincte sous contrôle → critère COURONNEURS + #JJ) ; balatrowiki.org/w/Jokers +
switchbladegaming.com/balatro-best-joker-combos (conditions sous contrôle du joueur > contextuelles ; interaction
= déclencheur observable → #JJ choc fiabilité + `combat_effect_legibility`) ; wayline.io/roguelike-itemization
(luxury vs enabler → `feeding_frenzy` = amplificateur pas égalisateur) ; cloudfallstudios.com/sts-decisions
(« if any choice is obviously the best, the designers have failed » → collision burn `skull_colossus`) ;
a327ex.com/super_auto_pets (« each tier = a new mechanic » → plancher poseurs actifs ≠ auras) ;
poewiki.net/wiki/Ailment (co-présence shock×DoT = axe de profondeur mais condition → CONFIG-CE2) ; Amabile &
Kramer 2011 « The Progress Principle » HBR (progress = motivation même en défaite → rôle [B] rituel de la passive
XP) ; thebigbois.com/legionbound-review (axe orthogonal de compétition quotidienne dans un roguelite → #KK) ;
NN/g (3-5 éléments simultanés max, heuristique UX → `combat_effect_legibility`, nuancée comme heuristique).
**Constantes revérifiées dans `00-state` ce round** : `§4.1` coût=rang → ratio reroll 1:1 (T1) → 1:5 (T5) ;
`§4.3` cotes rang-3 = 0 % en T2 → `engagement_rate_T2 = P(achat rang-3)` impossible ; `§4.1` `XP_TO_LEVEL=
{2,5,8,12}` = placeholder (la roadmap teste {2,5,10,18} vs {2,5,10,20}).

**Sources web nouvelles du round 10** : steamcommunity.com/app/1617400/discussions (Bazaar « concede meta »
documenté par les joueurs : « kinda HAVE TO concede to win » → faille d'intégrité #LL) ; bazaar-builds.net/
reynad-interview (Swiss matchmaking conçu autour du concede) ; bazaar-builds.net/did-you-know-how-ghosts-work
(ghost replacement) ; bazaar-builds.net/announcement (sept. 2025 : reset soft + pénalité séparée par niveau →
confirme « pas de pénalité sur pool imparfait ») ; azurgames.com Kingdom Clash (fév. 2025 : exploits = confiance
détruite) ; gameanatomy.blog/2025/08 (matchmaking rigging par concede) ; GamineAI 2026 (gamineai.com : saisons
6-12 sem. recommandées → cadence 5 sem. S1-S2) ; arxiv.org/html/2602.17015 (Cinder : distribution de skill >
proxy discret → `slot_tier_composite` = proxy uni-dimensionnel) ; blakecrosley.com/balatro (high-roll =
activation séquentielle visible, pas magnitude brute → spec séquentielle §2.4) ; CHI 2025 Kao (people.csail.mit
.edu/dkao, n=1699 : amplification sans success-dependency ≠ engagement équivalent) ; gmtk.substack.com (Balatro
score preview refusé délibérément → rejet du preview ex-ante) ; armchairarcade.com 2026 (Balatro : « each run
teaches something new » → near-miss = hypothèse) ; gridsagegames.com 2025 (feedback actionnable = moteur de
mastery → near-miss hypothèse + hint opt-in) ; stat.berkeley.edu/near_miss (type 1 sous agence vs type 2 sans) ;
yukaichou.com/collection-set-design-cd4 (seuil de bascule 40-60 % → Grimoire Chapitre II segmenté par famille) ;
his.diva-portal.org Åslund 2026 (méta-progression légère = hook plus tardif → Grimoire minimal avancé v0.9.3) ;
Nunes & Drèze 2006 JCR (Endowed Progress Effect : avantage perçu comme effort → rôle [B] passive, REMPLACE Amabile
& Kramer = travail signifiant non transférable) ; Csikszentmihalyi 1990 (Flow) ; poewiki.net/wiki/Shock + /Ailment
(Lightning Exposure = choc auto-garanti → CONFIG-CE2 Option A auto-DoT par défaut) ; arxiv.org/html/2502.10304v1
(Kritz & Gaina 2025 : saturation positionnelle > saturation de type, co-location requise → tableau de saturation
des ARÊTES) ; nat1gaming.com/sts2 + switchbladegaming.com/sts2 + mobalytics.gg/slay-the-spire-2 (reliques
CONTEXTUELLES = lock-in ; « Act 1 relics function IMMEDIATELY » → reliques positionnelles + `carrion_ledger` tier
3→2 + Paper Phrog contextuel → granularité intra-famille) ; cloudfallstudios.com/sts (« if any choice is obviously
the best, the designers have failed » → audit rang-5 E1/E2/E3). **Constantes revérifiées par les lentilles ce
round** : `units.lua:421-424` (`skull_colossus type="bone" family="crane" burn{dps=4}` → réorientation apex choc
DA-invalide + diagnostic carry burn faux) ; `relics.lua:26-29` (4 B = `relic_affliction_inc` identiques) ;
`relics.lua:64-66` (tier-gating F par numéro ≠ valeur par phase).

**Sources web nouvelles du round 6** : TFT Galaxies learnings (teamfighttactics.leagueoflegends.com/dev/
dev-teamfight-tactics-galaxies-learnings : traits double-condition = dead-zone → #D global pur, seuils 2/4) ;
Wayward Strategy 2024 (waywardstrategy.com/2024/03/20 : counterplay needs measurable responses → #W burn
intentionnel) ; Switchblade Gaming 2026 (switchbladegaming.com/strategy-games/best-auto-battler-games-2026 :
rétention autobattler #1 = imprévisibilité de la boutique → VRR boutique §2.9) ; Ballou et al. 2024 (ACM
TOCHI « Unfulfilled Promises », 259 papiers, arxiv.org/html/2405.12639 : relatedness SDT non testée → trace
d'impact §2.8) + Möller et al. 2024 (pmc PMC12412733 : « relatedness frequently ignored ») + Countly 2026
(90 s post-relance) ; Nature H&SS 2025 (méta-analyse nature.com/articles/s41599-025-05000-w : Zeigarnik
invalidé, Ovsiankina tient → §6.7) ; Dai/Milkman/Riis 2014 (Management Science, katymilkman.com : Fresh Start
Effect, landmarks proches > lointains → saisons 3-4 sem.) + Dai/Li 2018 (anderson-review.ucla.edu) ;
PMC10839887 (matchmaking + churn : perte amplifie le churn si injuste → grille sans pénalité, raisonnement
MAJ) ; Bazaar 2025 gain ET perte de points (bazaar-builds.net/ranking-update-reset → ne plus citer Bazaar
comme validation) ; SAP wiki/fandom + twoaveragegamers.com (pets 3 or, reroll 1 or = **ratio 1:3 jamais 1:1**
→ analogie REROLL_COST corrigée) ; Machinations.io 2025 (« define the goal before measuring » → tableau
d'intention éco précondition §7.0) ; Ariely/Loewenstein/Prelec 2003 QJE (« Coherent Arbitrariness », ancrage →
dispersion DPS 7,24×) ; GhostCrawler (askghostcrawler.tumblr.com : « not both best attacker and best counter »
→ siege_breaker) ; Backpack Battles steam (« positional items require spatial tooltips » → colonne J) ;
a327ex.com SAP (« 1 pet = 1 valeur ; early tiers = introduction » → soot_acolyte/singletons rang-1) ; MegaCrit/
Giovannetti GDC 2019 (gamedeveloper.com : « 18M runs per balance patch » → plague_communion sim bloquante) ;
Ludus/AAAI (ojs.aaai.org/index.php/AAAI/article/view/21550 : méta saine = faible σ + haute entropie = diversité,
pas égalité) ; diva-portal.org 2025 (engagement = count visible) ; LogRocket 2024 (goal gradient ~7 étapes →
bestiaire segmenté par famille).

**Sources web nouvelles du round 5** : intégrité ghost Bazaar (bazaar-builds.net/did-you-know-how-ghosts-work :
pools ranked/unranked séparés) ; Bazaar migration income linéaire (bazaar-builds.net/patch-7-0-0) ; daily
indie seedé (dev.to/yurukusa 2026 : « the seed is authentication, but the experience must feel fair » +
timezone) ; PoE Wither debuff cumulatif dominant (pathofexile.com/forum/view-thread/3870562) ; PoE Shock
ampli universel (poewiki.net/wiki/Shock) ; SDT besoin d'appartenance (Möller, Kornfield & Lu 2024,
selfdeterminationtheory.org) + Fogg Behavior Model ; Kao et al. 2024 CHI (amplification excessive réduit
l'agence) ; Smashing Magazine 2026 (UX streaks, loss ~2,3×) + Kahneman-Tversky ; TFT reroll 2 or = 40 %
revenu (boosteria.org) ; HS:BG reroll scalant ; Nunes & Drèze 2006 (goal-gradient borné ~7 étapes) ; Wayward
Strategy 2018 (combo-units indépendantes = dead picks) ; StS Ascension a abandonné le score classé ; TFT
augments directionnels-early/payoffs-late (bunnymuffins.lol/augment-guide-for-set-13) ; StS2 reliques
défensives universelles (pixelnitro.com) ; Kammonen 2024 (theseus.fi, méta-progression de connaissance).

**Sources web nouvelles du round 4** : ranked moteur pré-run (seganerds.com 2026 « uncertainty keeps
you queuing » ; immortalboost TFT LP potentiel à la sélection) ; Bazaar sept. 2025 (bazaar-builds.net/
announcement : matching par **rang** + transparence pool pré-run) ; Bazaar pré-Legend = gains seulement
(steamcommunity 1617400) ; LoL ranked 2025 (egamersworld : désaffection si cosmétiques trop accessibles
→ marques p25) ; méta-progression (Åslund 2026 essays.se ; diva-portal 2026 Hades 2 vs TBOI « path to
Dead God ») ; spectacle = agence (Déclos 2025 British J. Aesthetics philarchive.org/rec/DECSGC ; Yonkers
2025) ; VRR/juice (Kao et al. 2024 CHI nickballou.com ; Boyle et al. 2024 Nature Sci Rep s41598-024-
74450-0) ; pity (MDPI 2025 mdpi.com/2078-2489/16/10/890 ~55 tentatives ; ACM SIGCHI 2023 dl.acm.org/
doi/pdf/10.1145/3579438 percevoir la progression) ; StS Daily (slay-the-spire.fandom.com/wiki/Daily_
Challenge modifiers AVANT ; bossdown.com StS2) ; budget/condensateur (askghostcrawler 2017 ; StS Totem
slaythespire.wiki.gg/wiki/Cards) ; tank HP/DPS inversé (metatft.com Set 14) ; pool partagé vs local
(esportstales TFT) ; TFT XP super-linéaires (lolchess.gg/guide/exp). **Sources rounds 1-3 conservées** :
PoE Shock no-stack (poewiki.net/wiki/Shock) ; StS Vulnerable ; Giovannetti GDC 2019 ; goal-gradient
(Nunes & Drèze 2006, JCR ; Hull 1932) ; near-miss (Clark 2009) ; LocalThunk score caché (GMTK 2024) +
« 1 règle/Joker » ; floors/MMR (immortalboost, boosteria) ; TFT augment timing (Mort Sullivan, Riot
GDC 2022) ; Last Epoch / PoE Bleeding (encodage système vs paramètre).

---

*Brouillon #11 — intégré du round 10 FINAL (6 lentilles) le 2026-06-23. Améliorations mesurables vs v10 (round de
COMPLÉTUDE DE SPEC + INTÉGRITÉ + FEEDBACK) : **1 PROPOSITION DA-INVALIDE CORRIGÉE** — `skull_colossus → apex choc`
RETIRÉE (`type="bone", family="crane"` ≠ électricité, décision #3 ; le « 0 moteur » du recyclage = analogie
mécanique paresseuse) → APEX CHOC = NOUVELLE unité `type=arcane/abyss` ; `skull_colossus` reste burn (niche
tank-burn, burn_dps 4→8, via l'audit 3 colonnes E1/E2/E3 qui corrige le diagnostic « carry burn » de R09 = frappe
mélée ≠ burn_dps réel sous le rang-1). **1 FAILLE D'INTÉGRITÉ ASYNC EXHUMÉE (#LL)** — le « concede meta » (capture
seulement à `startCombat` → run avorté = pas de ghost = pool biaisé ; Steam Bazaar août 2025 « kinda HAVE TO
concede to win ») → capturer dès le 1er achat (~5 lignes IO). **2 LITIGES CLOS PAR #JJ** — #HH (palier choc-4 =
Option B `tickCount=2`, cause = compo → DÉCOUPLE #GG) ; #II (directionnalité #FF = Option B symétrique). **LA
SIGNATURE ENFIN SPÉCIFIÉE** — 4 reliques positionnelles sigil-aware (0 moteur, snapshotables) comblent un trou de
catégorie sur le différenciateur #1 ; tableau de saturation des ARÊTES (jamais mesuré en 10 rounds) = précondition
P1. **HIGH-ROLL RE-CADRÉ** — feedback SÉQUENTIEL visible (Balatro), pas probabilité → spec d'activation séquentielle
§2.4 (0 SIM). **CADENCE SAISON 3→5 SEM.** — Milkman 2014 démontée (landmark naturel ≠ reset arbitraire) + Bazaar
mensuel démonté (pool mondial ≠ FIFO 200 local). **GRIMOIRE CALIBRÉ** — minimal avancé à v0.9.3 (hook runs 1-5,
Åslund 2026) + Chapitre II segmenté par famille (seuil 40 %, Yu-Kai Chou). **2 SOURCES PROGRESSION CORRIGÉES** —
Amabile & Kramer (travail) → Endowed Progress Effect (Nunes & Drèze 2006 + framing) + table du plafond passif
(prédit `--xp-climax` sans le lancer) + hiérarchie de remèdes condition 4. **PRÉCISIONS** : `carrion_ledger` tier
3→2 ; granularité intra-famille `venom_covenant` ; `hollow_choir` RÉORIENTÉE (décidé) ; near-miss = hypothèse
testable + hint opt-in ; filtre persistance ghost double critère ; poison-4 `poisonWeakenDeep`. **NEUF** : #LL
(ancre snapshot). **CLOS PAR PREUVE** : #HH, #II (via #JJ). **RÉ-OUVERT** : #Y. **RE-QUALIFIÉ BLOQUANT** : Q_R9_2
(gate §2.10 ghost humain). **REJETS/NUANCES SOURCÉS** : angle « concede semi-déterministe » comme justificatif #LL
(spéculatif bêta) ; Cinder matchmaking (over-engineering 200 snapshots) ; seuil 40 % et NN/g = heuristiques pas
lois. **Méthode (round 4-10)** : claims de code revérifiés avant arbitrage ; #JJ devient un OUTIL DE CLÔTURE ; un
litige ne se clôt que sur preuve. **ROADMAP FINALE (10 rounds adversariaux).** Lecture seule du repo ; n'édite que
sous `docs/roadmap-lab/`. Piliers respectés (async snapshots / sim déterministe seedée / DA grimdark / pixel art
procédural), 32 invariants préservés.*

---

*Historique — Brouillon #10 (intégré du round 9, 6 lentilles) : Améliorations vs v9 (round de
CALIBRAGE + ALIGNEMENT PAYOFF↔AGENCE) : **1 FIL ROUGE SYSTÉMIQUE DÉCOUVERT (#JJ)** — 4 lentilles indépendantes
(reliques, rétention, synergies, units) convergent sur la même classe de bug : des payoffs ancrés sur une cause
NON contrôlée par le joueur (la cible / l'exposition / l'adversaire). Adopté garde-fou (§10, §4.11) ; ferme/
réoriente `plague_communion` (#J re-tranché → `dot_family_count(joueur) ≥ 2`), badge MAÎTRE (→ victoire avec
l'apex joué), §2.10 (→ attribution à l'agence du joueur), choc axe D (→ problème de fiabilité, pas de puissance).
**2 SEUILS D'ALARME ÉCO FAUX CORRIGÉS PAR CODE** — `reroll_dominance_T1 > 0,25` trop bas (3 rerolls = 30 % du
budget = sain → `> 0,45` + condition) ; `engagement_rate_T2 = P(achat rang-3 en T2)` **mécaniquement impossible**
(rang-3 à 0 % en T2, vérifié `00-state §4.3` → redéfini). **1 DETTE DE SPEC DE 9 ROUNDS EXHUMÉE** — palier
CHOC-4 jamais nommé (burn-4/bleed-4/rot-4 le sont) = #HH neuf, co-bloquant #GG ; + `combat_effect_legibility`
(Q3 r08 IGNORÉE par le synthé r08) réintroduite comme précondition de #FF ET §2.10 (une profondeur invisible est
inexistante). **`REROLL_COST` RE-CADRÉ** : coût relatif dérive 1:1→1:5 de T1 à T5 (coût=rang) ≠ placeholder neutre ;
SAP (prix uniformes → 1:3 constant) ne partage pas la dynamique → documenter l'intention §7.0. **3 SIGNAUX/AXES
RANKED NEUFS** : Profondeur du Puits #KK (2e dimension orthogonale au LP) + élan 3 runs + modificateur LP borné ±1
sans pénalité (Management Science 2026 : +4-6 % via 2 dimensions). **3 ANALOGIES RECALÉES** : SAP Arena ≠ SAP
v0.41+ ranked ; LoL LP invalide comme calibrage (comme TFT) ; Fresh Start incomplet sans incertitude partagée →
pré-annonce de saison. **#U RE-QUALIFIÉ** : Contrainte de Saison = « axe RÉSOLU + plus grand écart potentiel/réel »
(prérequis bloquant : choc gelé tant que #GG ouvert ; fallback sigil pur). **3 CONSTANTES REVÉRIFIÉES DANS
`00-state`** : coût=rang (§4.1), rang-3 à 0 % en T2 (§4.3), `XP_TO_LEVEL={2,5,8,12}` placeholder (§4.1). **4
LITIGES NEUFS** (#HH palier choc-4, #II directionnalité #FF, #KK Profondeur du Puits, #JJ alignement payoff↔agence
adopté garde-fou) ; **#J re-tranché** ; **#U re-qualifié** ; **#EE-ranked confirmé** ; **aucun clos par preuve
concluante** (un litige ne se clôt que sur preuve). **REJETS/NUANCES SOURCÉS** : §2.10 ≠ « simple second Moment du
Run » (valence distincte préservée) ; grants de slot liés aux victoires (viole « égalisateurs pas gates ») ;
retirer les auras hostiles de U.pool (trop radical) ; NN/g 3-5 = heuristique pas loi mesurée. **Méthode (round
4-9)** : constantes/claims revérifiés avant arbitrage ; une affirmation « code-vérifiée » reste contestable ; un
litige nuancé reste ouvert tant qu'une preuve neuve peut le trancher ; un litige ne se clôt que sur preuve.
DESTINÉ À ÊTRE ATTAQUÉ au round 10 (dernier). Lecture seule du repo ; n'édite que sous `docs/roadmap-lab/`.
Piliers respectés, 32 invariants préservés.*
