# La Chronique — inspecteur de combat (spec UX / UI / technique)

> Feature demandée par l'user (2026-06-23). Un **journal de combat lisible** (qui fait quoi, dégâts,
> afflictions posées/propagées, procs de relique) **+ une timeline scrubbable post-combat** (clic dans le
> log → saut au tick, avance/recul fluides, replay) **+ un mode ralenti**. But : **apprendre de ses
> erreurs, comprendre les mécaniques et leurs interactions, reproduire ses bons builds.**
>
> Statut : **spec validée techniquement** (recon code-vérifiée, refs `fichier:ligne` en §9). Implémentation
> phasée en §6. Décisions ouvertes en §8. Aligné roadmap-lab : c'est la version aboutie de **1.3 (post-mortem
> "pourquoi")** + **1.4 (Moment du Run)**.

---

## 0. En une phrase
Transformer le combat-spectacle en **outil de compréhension** : un journal organisé par type **et par
équipe**, filtrable, horodaté, couplé à une **timeline qu'on rembobine** — possible parce que le combat est
**déterministe seedé** (rejouer un instant = re-dérouler la même graine).

## 1. Vision & valeur

- **Le déclic.** Le combat est 100 % déterministe seedé (pilier #2). Donc **n'importe quel instant est
  reconstructible exactement**. Rembobiner / ralentir / sauter à un tick = re-simuler la même graine, pas de
  la magie. Peu de jeux peuvent le faire aussi proprement — c'est un **différenciateur** quasi gratuit.
- **But pédagogique (l'user).** (a) *Apprendre de ses erreurs* : « pourquoi mon Templier est tombé ? » →
  scrub + lecture. (b) *Comprendre les interactions* : l'indentation causale montre `brûlure → ignore
  bouclier → tue`. (c) *Reproduire un bon build* : un « instantané de build » lié à la Chronique.
- **Continuité.** Le post-mortem « pourquoi » (déjà livré, `combat.lua`) est le **résumé** ; la Chronique
  est le **détail navigable** du même flux d'événements. Aucune logique jetée.

## 2. Faisabilité (ancrée — synthèse de la recon)

| Brique | Verdict | Détail |
|---|---|---|
| **Pas-fixe contrôlable** | ✅ gratuit | `main.lua` `love.run` : `TICK=1/60`, accumulateur ; 1 tick sim/update. `Combat.paused` gèle déjà. Avancer = `arena:update(1, t)` ; ralentir = espacer les updates. |
| **Re-sim déterministe → tick T** | ✅ exact | Tout l'aléatoire via `arena.rng` (seedé injecté), zéro état hors-seed (le golden le prouve). ~150 ticks/ms headless → T=1000 ≈ 7 ms, T=5000 ≈ 33 ms. |
| **Capture des events** | ⚠️ partielle | Émis : `spawned/attack/hit/damage/death/shield_cast/reflect/amped/spread`. **SILENCIEUX** : application de DoT (poison/burn/bleed/rot/shock), vol de vie, regen. → **ajouter ~6 events** (§5.1). |
| **Logger runtime** | ✅ existe | `tools/eventlog.lua` (records `{tick, ev, …}`) — utilisé en tests/headless, pas au runtime. La scène Combat peut s'abonner (déjà le cas pour le post-mortem 1.3). |
| **Rendu d'un instant T** | ⚠️ anim | Positions/PV/`dots` lus de `arena.units` (gratuit). L'**état d'anim** (rig state, nombres flottants) n'est pas persisté → option « replay du bus » (fidèle) ou « état figé » (simple). |
| **Golden** | ✅ neutre* | *Un nouvel `emit` n'altère pas la sim ; le logger du golden n'écoute que `attack/damage/death` → JSONL inchangé. **À confirmer au `check.sh`** ; sinon rebaseline explicite. |

## 3. UX — les trois briques

### 3.1 Le Journal (log lisible)
Panneau **scrollable** (clip `Draw.scissor`, jamais d'overflow fenêtre). Une ligne = un événement, **horodaté**,
**coloré par nature**, **ancré à son équipe** (§4.2). Deux niveaux de détail : **« faits marquants »** (défaut :
coups lourds, afflictions, propagations, procs, morts) et **« verbeux »** (tout, ticks de DoT compris). Filtres
en haut (§4.3). Structure en **blocs temporels** + **indentation causale** (§4.4).

### 3.2 La Timeline (scrubber) — *uniquement combat terminé*
Barre temporelle + curseur. **Clic = saut à ce tick** (re-sim). Avance/recul **fluides**. **Marqueurs** des
moments clés (morts, gros coups, procs). **Couplage log ↔ timeline** : cliquer une ligne déplace le curseur ;
scrubber la barre surligne + auto-scroll la ligne. Deux vues d'une même réalité.

### 3.3 Les contrôles de lecture
**Play / Pause**, **step** (tick par tick ou événement par événement, **avant et arrière**), **ralenti**
(×1 / ×0.5 / ×0.25). En replay on possède l'horloge → tout est naturel.

## 4. UI — maquettes (ASCII, pour le designer humain)

### 4.1 Layout global (mode Chronique, post-combat)
```
┌─────────────────────────────────────────────────────────────────────┐
│  THE PIT — combat                                    vs  GRAVE CHOIR  │
│                                                                       │
│            [ arène REJOUABLE — l'instant T s'affiche ici ]            │
│                                                                       │
├──────────────────────────────────────┬──────────────────────────────┤
│                                       │ ⌖ CHRONIQUE        ⏷ verbeux  │
│   [ replay du combat ]                │ ⚔ ☣ ⤳ ✦ ⛨ ☠     équipe‹Tout▾›│ ← filtres
│                                       │──────────────────────────────│
│                                       │  2.0s ───────────────────────│ ← bloc
│                                       │ ▌2.1s ⚔ Maraudeur→Goule 12   │
│                                       │ ▌     ⤳ ↳ poison→Râle-os     │
│                                       │ ▐2.4s ☣ Goule⇒Templier pois  │
│                                       │ ▌2.8s ✦ Carrion Ledger +1    │
│                                       │  3.0s ───────────────────────│
│                                       │ ▐3.0s ☠ Templier tombe — rot │
│                                       │              ⋮ (scroll)       │
├──────────────────────────────────────┴──────────────────────────────┤
│ ◀◀ ◀ ▶ⅠⅠ ▶ ▶▶    ×0.25 ×0.5 ●×1    [▮▮▮▮▮▮▯▯▯▯▯▯▯] 2.4 / 8.1s        │ ← timeline + contrôles
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Clarté par équipe — **la décision clé** (déléguée par l'user)
Problème : un événement implique souvent **deux** équipes (*ton* Maraudeur frappe *sa* Goule). Solution
retenue après comparaison :

| Piste | Verdict |
|---|---|
| 2 panneaux séparés (toi \| adverse) | ❌ tue la causalité croisée — or le but est de COMPRENDRE les interactions |
| Colonnes type chat (toi←→adverse) | ⚠️ casse sur l'inter-équipe + gâche la largeur ; option lointaine |
| **Flux unique : gouttière = équipe de l'ACTEUR + noms colorés par équipe** | ✅ **RETENU** — dense, 1 scroll, interaction lisible en 1 ligne, filtre d'équipe trivial |

Principe : **barre de gouttière à gauche = qui a initié** (toi = **or**, adverse = **rouge sang**, couleurs déjà
dans `Theme.c`) ; **dans le texte, chaque nom garde la couleur de son équipe**.
```
 gout.  temps  type   texte (noms colorés : OR = toi, ROUGE = adverse)
 ▌or    2.1s    ⚔     Maraudeur frappe Goule — 12  (7 absorbés)
 ▌or            ⤳     ↳ son poison se propage à Râle-os
 ▐rouge 2.4s    ☣     Goule empoisonne Templier — 2/s · 3s
 ▐rouge 3.0s    ☠     Templier tombe — achevé par pourriture
```
→ gouttière = *qui agit* ; noms colorés = *qui → qui*. Et comme chaque ligne porte une « équipe d'acteur »,
le **filtre d'équipe** (Tout / Toi / Adverse) se réduit à un test sur l'acteur.

### 4.3 Filtrage (deux dimensions combinables, ET)
```
┌ CHRONIQUE ───────────────────────────────────────  ⏷ verbeux ┐
│ [⚔ Frappes] [☣ Afflictions] [⤳ Propagation] [✦ Reliques]      │  ← puces de TYPE (toggle)
│ [⛨ Soins/Boucliers] [☠ Morts]            équipe: ‹ Tout ▾ ›    │  ← + sélecteur d'ÉQUIPE (tri-état)
└───────────────────────────────────────────────────────────────┘
```
Puce active = pleine + couleur de famille ; éteinte = grisée. Compteur possible (« ☠ Morts · 4 »). Ex :
*Afflictions + Adverse* = uniquement ce que l'ennemi t'a posé.

### 4.4 Blocs & timestamps
- **Primaire = blocs temporels** : en-têtes par seconde (ou demi-seconde) → le timestamp saute aux yeux, on
  navigue par phase.
- **Secondaire = indentation causale** : une conséquence (affliction d'un coup, propagation, mort) est
  indentée `↳` sous sa cause. **C'est ça qui rend les interactions lisibles** (objectif pédagogique #1).
- **Timestamps** : `S.d s` par ligne ; durée totale dans la timeline ; le tick brut en infobulle (debug).

### 4.5 Taxonomie (type → icône / couleur ; réutilise les Chips d'affliction existants)
| Type | Icône | Couleur | Event(s) source |
|---|---|---|---|
| Frappe | ⚔ | acier neutre | `attack` / `hit` / `damage(cause=attack)` |
| Affliction posée | ☣ | **couleur de la famille** | `affliction_applied` *(à ajouter)* |
| Propagation / contagion | ⤳ | teinte « transmission » | `spread` |
| Relique (proc) | ✦ | or | `relic_proc` *(à ajouter, ou dérivé)* |
| Soin / Bouclier | ⛨ | bleu protecteur terni | `shield_cast`, `heal/regen` *(à ajouter)* |
| Choc / décharge | ⚡ | électrique | `amped` + `damage(cause=shock)` |
| Mort | ☠ | sang sombre | `death` (+ dernière `cause`) |

### 4.6 Afflictions & ticks de DoT — afficher le CONTINU sans noyer le log
**Le problème (user).** Un combat a des centaines de ticks ; plusieurs afflictions tickent sur plusieurs
unités en même temps. Logger chaque tick = des milliers de lignes « −2 poison » → **illisible**. Or la donnée
existe déjà : chaque tick de DoT émet un `damage(cause=poison/burn/…)`.

**Le principe.** Un tick n'est **pas un événement narratif** — c'est la *respiration d'une cause déjà loggée
(la pose)*. On logue la **cause** une fois, on **agrège** les ticks, on ne les déroule jamais par défaut.
Conceptuellement : **événements discrets** (frappe, pose, propagation, proc, mort = le log narratif) vs
**dégâts continus** (ticks de DoT = état de fond, agrégé/visualisé, jamais ligne-à-ligne).

**4 mécanismes (combinés) :**

1. **La ligne VIVANTE d'affliction** (agrégation par instance). Une affliction = **une ligne** qui vit de la
   pose à l'expiration/mort, avec **total cumulé + DPS + durée**. Les ticks alimentent le total, pas le log.
```
2.0s ☣ Goule ⇒ Templier · POISON 2/s 3s          Σ 14  ✗ tué        ← repliée (l'instance entière en 1 ligne)
       ▸ déplier :  2.0s −2 (8)   2.5s −2 (6)   3.0s −2 (4) …        ← accordéon, seulement si on clique
```
2. **La TIMELINE en BANDES (gantt d'afflictions)** — la pièce maîtresse pour « plein de trucs à la fois ».
   Une piste par unité, barres colorées par famille sur la durée d'activité. Le continu devient **spatial**
   (zéro ligne de texte) ; on **VOIT** les chevauchements. Survol d'une bande = détail (DPS / source / total).
```
 Templier  ▐██ poison ██▌    ▐ burn ▌
 Séraphin      ▐███ bleed ████████▌
 Goule(adv)         ▐█ rot █▌
           └────┴────┴────┴────┴────┴──  temps (couplé au scrubber : le curseur balaie ces bandes)
```
3. **Le DÉPLIAGE (accordéon)** : qui veut les ticks fins clique pour déplier une affliction. Caché par défaut.
4. **Le SCRUB** : la granularité tick vit dans le **replay visuel** (PV qui descendent, afflictions en
   surbrillance sur les unités), pas dans le texte.

**Option (verbeux)** : une ligne de « battement » agrégée par seconde
(`3–4s ☣ Templier −6 poison · Séraphin −4 burn`) si on veut une trace continue **dans le texte**.

**Technique.** Aucun event par tick à créer : on **agrège les `damage(cause=family)` déjà émis** par
`(source, target, family)` sur la fenêtre bornée par `affliction_applied` → expiration/mort. La ligne vivante
et la bande gantt lisent la même agrégation.

## 5. Architecture technique

### 5.1 Capture — events à ajouter (SIM, golden-safe)
Aujourd'hui silencieux dans `src/effects/ops.lua` : la **pose** de poison/burn/bleed/rot/shock, le vol de
vie, le regen. Ajouter un event déclaratif à la pose, p. ex. :
```lua
-- dans chaque op de pose (poison/burn/bleed/rot/shock) :
ctx.arena.bus:emit("affliction_applied",
  { target = v, source = ctx.source, family = "poison", dps = dps, dur = p.dur, stacks = #stacks })
```
+ (option) `heal` (lifesteal/regen) et un `relic_proc` si un proc n'est pas déjà couvert par un event existant.
**Golden** : neutre tant que le logger du golden n'écoute pas ces events (il n'écoute que `attack/damage/death`).
→ **valider au `check.sh`** ; si l'empreinte bouge, rebaseline **explicite** documenté.

### 5.2 Replay / scrub — re-sim déterministe
Pour afficher l'instant T : recréer l'`Arena` (même seed) et la dérouler jusqu'à T. Exact (la SIM reste la
source de vérité — firewall respecté). Coût acceptable (§2). **Optimisation** si combats longs : snapshots
d'état tous ~N ticks → re-sim depuis le snapshot le plus proche ≤ T (différable, non-MVP).

### 5.3 Rendu d'un instant T — anim
`arena.units[]` donne positions/PV/`dots` à T (gratuit). L'**état d'anim** n'est pas persisté. Deux options :
- **Option A — replay du bus jusqu'à T** (fidèle : anim correcte) ; coût O(events ≤ T).
- **Option B — état figé** (rigs en `idle`, pas de nombres flottants ; stable, simple). **MVP = B**, A en raffinement.

### 5.4 Ralenti
En replay on contrôle l'avancement : `×0.5` = avancer 1 tick toutes les 2 frames ; `×0.25` = 1/4. Aucune
modification de la SIM (juste la cadence d'appel). Play/pause/step = idem.

### 5.5 Firewall & golden
Le Journal **écoute** le bus (RENDER), il **n'émet pas** (comme le post-mortem 1.3). Le scrub **re-simule**
(SIM) puis **affiche** (RENDER). Les nouveaux events SIM (§5.1) ne changent pas le déroulé. Garde `check.sh`
vert (golden 970156547) sauf rebaseline explicite et documenté.

## 6. Phasage (chiffré — ordres de grandeur solo dev)

| Phase | Contenu | Effort | Golden |
|---|---|---|---|
| **P1 — Le Journal** | events d'affliction (§5.1) + logger runtime branché sur la scène + panneau scrollable + **filtres type×équipe** + **gouttière équipe + noms colorés** + blocs temporels + timestamps + niveaux de détail | ~2-3 j | neutre* (vérifier) |
| **P2 — La Timeline** | barre + curseur + **saut au tick par re-sim** + couplage log↔timeline + rendu instant T (option B) + marqueurs | ~3-4 j | neutre |
| **P3 — Contrôles & ralenti** | play/pause, step avant/arrière, ralenti ×0.5/×0.25, (option A : replay d'anim fluide) | ~1-2 j | neutre |
| **Bonus** | « Instantané de build » (unités+placement+sigil+reliques) pour reproduire un build aimé (recoupe les snapshots, pilier #3) | ~1 j | neutre |

Total ~1-2 semaines. **MVP utile dès P1** (journal lisible filtrable) — déjà une grosse valeur seule.

## 7. Risques & décisions
- **Events SIM à ajouter** → golden-safe en théorie, **prouver au `check.sh`** ; rebaseline explicite sinon.
- **Volume du log** (~1000 ticks) → niveaux de détail **obligatoires** (faits marquants par défaut), sinon illisible.
- **Anim au scrub** → option B (figé) pour livrer vite ; option A (replay bus) si le rendu figé déçoit.
- **Re-sim des combats longs** → snapshots périodiques si la latence se voit (différable).
- **Lisibilité couleur** (daltonisme) → la gouttière + l'icône + la position doublent la couleur (jamais la couleur seule).

## 8. Questions ouvertes (défauts pris si pas de réponse)
1. **Détail par défaut** : *faits marquants + toggle verbeux* **(défaut)** vs tout d'emblée.
2. **Scrub** : *états figés* (option B) **(défaut MVP)** vs anim rejouée fluide (option A).
3. **Le Journal se remplit-il en direct** pendant le combat (lecture seule), ou n'apparaît qu'à la fin ? *(défaut : en direct, scrub seulement après la fin)*.
4. **Activation** : panneau latéral permanent vs overlay plein écran « Chronique » sur touche. *(défaut : latéral en combat, plein écran post-combat)*.

## 9. Sources (code vérifié)
`main.lua:265-299` (`love.run` pas-fixe, `TICK=1/60`, accumulateur) ; `main.lua:~173` (`update(dt*FRAME)`,
FRAME=60) · `src/scenes/combat.lua` (`Combat:update`, `paused`, `restart:44` ; post-mortem 1.3 déjà branché
sur le bus) · `src/combat/arena.lua:79-100` (`Arena.new`, `rng` seedé, `bus`), `:284` damage, `:295` reflect,
`:309` death, `:326` hit, `:562` shield_cast, `:583` attack, `:174` spawned, `:657-659` (team left/right) ·
`src/effects/ops.lua` poison 61-96 / burn 117-132 / bleed 135-163 / rot 166-178 / shock 183-201 (**poses
silencieuses**), `amped` 68/121/140/170, `spread` 93/236/243/259 · `tools/eventlog.lua:10-30` (records
`{tick, ev, …}`, abonné attack/damage/death) · `src/render/arena_draw.lua:27-87` (rebuild + abonnements bus ;
état d'anim `rigs/dead/dmgNumbers` non persisté) · `tests/golden.lua:16-50` (seed 424242 → 970156547) ·
`src/i18n/en.lua` (`unit.<id>.name`).
```
