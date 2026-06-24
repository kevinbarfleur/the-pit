# The Pit — NIGHT-PLAN (branche `feat/base-game`)

> Build **autonome nocturne** (démarré 2026-06-24). Objectif : livrer une **boucle de jeu
> complète, jouable en local, testée, simulée par milliers et polie** (standard *Balatro*) pour
> le réveil du créateur. Ce fichier est la **source de vérité** de la session — décisions,
> protocole, backlog, journaux. Il survit à la compaction. Mis à jour à chaque jalon.

---

## 0. Objectif (commande du créateur)

Une **partie complète jouable en local de bout en bout** : économie cohérente, **banc**, équipes
adverses **cohérentes avec le stade** du joueur, **feedbacks visuels partout** (achat/vente/
level-up/tiers), créatures dont **nom + lore + effets matchent le visuel**, le tout **équilibré
par milliers de simulations** et **poli**. Pas de multijoueur cette nuit (local only). **Autonomie
totale** : je ne m'arrête pas pour demander ; je décide / délègue / cherche / simule.

## 1. Décisions verrouillées (créateur, 2026-06-24)

1. **Économie = hybride mesuré, ZÉRO intérêt de base.** Or fixe/round + reroll + streaks + **banc**
   + **cotes-par-niveau & raretés** (tiers lisibles) + doublons 3→niveau. **Intérêts & bonus d'or
   = UNIQUEMENT via reliques** (nouveau levier éco, sert le pilier #2, respecte le garde-fou #JJ).
2. **Boucle jouable d'abord, PUIS polish Balatro** (les deux, dans cet ordre — « tu auras le temps »).
3. **Refonte UI autorisée** (branche isolée = safe). MAIS créateur endormi ⇒ pas de validation
   screenshot ⇒ je reste **incrémental + validé headless**, je documente, tout réversible.
4. **Visuels créatures = CANON, intouchables** (« godlike, j'y touche plus »). On **renomme +
   ré-écrit le lore + ré-adapte effets/passifs** pour matcher le visuel. **Chaque** changement
   d'effet ⇒ **simulations** pour vérifier l'équilibre.

## 2. Garde-fous (non négociables)

- **Vérifier le code RÉEL avant tout design** (leçon roadmap-lab). Aucune API/valeur supposée
  (LÖVE 11.5 ; Lua 5.1/LuaJIT). Sources primaires.
- **4 piliers** : snapshots async · sim déterministe seedée · DA grimdark · pixel art procédural.
  Ne rien casser.
- **#JJ** : tout payoff s'ancre sur une **cause contrôlée par le joueur** (compo / placement /
  relique / décision), **jamais** cible / exposition / adversaire.
- **Firewall SIM/RENDER** : `src/combat|board|effects|run` = zéro `love.graphics`. Ordre de sim
  = array + `ipairs`, jamais `pairs`.
- **Déterminisme** : RNG seedé injecté (`opts.seed`/`opts.rng`), jamais `math.random` global en sim.
- **i18n** : tout texte affiché via `t(key)` ; la data ne porte que des clés mécaniques ; les
  chaînes vivent dans `src/i18n/en.lua`.

## 3. Protocole de boucle (à CHAQUE itération)

1. **Évaluer** — relire ce backlog + l'état ; choisir le prochain item par priorité.
2. **Déléguer / faire** — agents parallèles pour le travail indépendant (recherche, batch
   créatures, sims) ; main loop pour le séquentiel central (économie / banc).
3. **Simuler** — tout changement touchant l'équilibre ⇒ `luajit tools/sim.lua N` (N grand), lire
   `runs/report.json`, **tuner un levier à la fois**, journaliser (SIM-LOG).
4. **Vérifier** — `sh tools/check.sh` doit être **vert**.
5. **Golden** — un changement d'équilibre **intentionnel** change l'empreinte → **rebaseline** +
   entrée GOLDEN-LOG (raison). Un changement RENDER / data-non-lue-par-SIM doit **laisser le
   golden inchangé** (sinon il y a une fuite SIM, à corriger).
6. **Commit** (git-warden, conventionnel) au jalon vert. **Push** `feat/base-game` aux jalons
   majeurs (le créateur pull au réveil). **Jamais** de merge auto vers `dev`/`main`.
7. **Journaliser** ici (DONE-LOG / SIM-LOG / GOLDEN-LOG / DECISIONS-LOG).
8. **Auto-critique** — est-ce au niveau *Balatro* ? déjà fait ? cohérent avec la roadmap ? Si
   erreur, **corriger la roadmap** (ne pas hésiter à lancer plusieurs agents de recherche).

## 4. Phases & backlog (priorité décroissante) — *détail affiné après les audits*

### PHASE A — Boucle jouable (FONDATION) — *priorité max*
- **A1. Économie hybride** — cotes-par-niveau + raretés (tiers lisibles) ; or/reroll/streaks/
  leveling revus ; doublons. *(détail post-audit)*
- **A2. Banc** — stockage hors-plateau (data `run/state.lua` + UI/drag `scenes/build.lua`) ;
  gestion des level-ups ; fusion depuis le banc. *(détail post-audit)*
- **A3. Reliques d'économie** — nouvelles reliques **intérêts / bonus d'or** (le levier éco vit ici).
- **A4. Adversaires cohérents au stade** — équipes scalées round/niveau/tier/sigil (génération ou
  pool tiéré) ; cold-start IA propre. *(détail post-audit)*

### PHASE B — Cohérence créatures (CONTENU, sim-gated)
- **B1. Renommer + relore + ré-adapter effets** pour matcher le visuel **canon** (par batches d'agents).
- **B2. Sim après chaque batch** ; golden rebaseline ; i18n noms + lore.

### PHASE C — Polish *Balatro* (FEEDBACK & GAME FEEL)
- **C1. Feedback achat / vente** (coin fly, pop, accents visuels).
- **C2. Feedback level-up / merge** (la fusion 3→niveau doit **claquer**).
- **C3. Lisibilité des tiers** (langage visuel : bordure / gemme / couleur par tier).
- **C4. Feedback banc** (drag, slot, level-up depuis le banc).
- **C5. Game feel combat** (frappes, nombres de dégâts, application de statut, victoire/défaite).

### PHASE D — Équilibrage (CONTINU, transverse)
- **D1. Sims à grande échelle** après chaque changement ; tuner **un levier à la fois**.
- **D2. Hiérarchie d'archétypes** (cf. diagnostic : poison > tank > … > shock à resserrer).

## 5. Journaux (append-only)

### DONE-LOG
- 2026-06-24 — Branche `feat/base-game` créée sur 54443f6 ; `dev` local réaligné ; Mac maintenu
  éveillé ; audits état-code + identité-créatures lancés ; NIGHT-PLAN posé.

### SIM-LOG  *(N · σ win% · entropie · outliers · levier touché)*
- _baseline à venir (audit : `luajit tools/sim.lua 200`)_

### GOLDEN-REBASELINE-LOG  *(ancienne → nouvelle empreinte · raison)*
- Baseline de départ supposée : **970156547 / 199 events** *(à confirmer par l'audit)*.

### DECISIONS-LOG  *(décisions autonomes + rationale)*
- 2026-06-24 — Une **seule** branche d'intégration (`feat/base-game`), poussée aux jalons, plutôt
  qu'une série de sous-branches : le créateur doit pouvoir **pull une seule chose** et jouer. Les
  worktrees d'agents (travail parallèle) sont fusionnés dedans.
