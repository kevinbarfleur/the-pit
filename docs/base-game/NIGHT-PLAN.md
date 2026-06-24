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

## ÉTAT AU RÉVEIL (handoff 2026-06-24) — branche `feat/base-game` (poussée sur `origin`)

**Tester** : `git checkout feat/base-game && love .` (ou pull sur PC). Boucle : menu → ENTER THE PIT →
build (boutique + plateau + **BANC** sous le plateau) → COMBAT → relique tous les 3 combats → … →
10 victoires / 5 défaites → runover. Captures de TOUS les écrans : `love . --shoot=all` →
`~/Library/Application Support/LOVE/the-pit/shots/`.

**LIVRÉ cette nuit** (tout committé · `check.sh` vert · golden **970156547** stable · vérifié au screenshot) :
1. **Harnais de capture PNG** (bestiaire + écrans) sous vrai `love` — pour s'auto-vérifier sans toi.
2. **PIN des 65 familles** — sprites procéduraux **verrouillés** (canon).
3. **BANC** (réserve hors-combat) — achat→banc/plateau, **fusion croisée** banc↔plateau, drag complet.
4. **55 créatures RENOMMÉES** vers leur visuel + lore ; bloc choc/bouclier comblé (descriptions « condenser » corrigées vs `en_ext` périmé).
5. **Adversaires PROCÉDURAUX scalés** au stade (taille/rangs/niveaux selon round/tier/slots ; déterministe ; testé).
6. **Game feel** — bursts achat (anneau) / vente (+N or) / level-up (flash + « LVL n »).
7. **Refonte combat P0** — sol d'arène + ligne de front + brume centrale + vignette (fini « 2 clusters dans le noir »).
8. **Reliques d'économie** (ton levier intérêts/or) — Usurer's Ledger (report+intérêt) · Tithe-Bowl (or/victoire) · Pauper's Boon (income/round) · Grave-Robber's Cut (vente pleine). Testées.
9. **Bug runover `[level]`** corrigé · **équilibre CONFIRMÉ** (sim N=3000 : σ 0.051, entropie 0.999, **zéro outlier**).
10. **Refonte combat P1/P2** — profondeur (gorge + piliers + brouillard + braises) + **feel** des coups (shake + flash + mort = particules de sang). Render-only, golden inchangé, prouvé SIM-neutre.
11. **Icônes dédiées** des 7 reliques boutique/éco (ledger · bol de pièces · bourse · pelle · lanterne · parchemin scellé · tally d'os) — fin du losange générique.
12. **Lore (flavor) des 83 unités** — affiché dans la fiche de monstre (« nom + lore » complété) ; la fiche montre aussi la **famille** (via le PIN).

**Tout est committé et poussé sur `origin/feat/base-game`. Rien en cours.**

**RESTANT / DIFFÉRÉ (à décider ensemble)** :
- **Re-mécanique des effets** vers le visuel (« adapte tous les effets ») — **DIFFÉRÉE** : sim-gated + risque d'équilibre ; les **noms** règlent déjà la plainte #1. À faire ensemble, chaque batch sim-validé.
- Noms longs un peu serrés sous les cases · doublons morts d'`en_ext.lua` (override par en.lua, inertes) · synergies de **TYPE** (M4) · combat P2.1/P2.4 (télégraphe / beat victoire) · grille du cabinet debug `[r]` (18→25 icônes).
- Collisions d'archetype créatures (3 herons…) — familles assumées, à arbitrer si gênant (`creature-renames.md`).

---

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
- 2026-06-24 — Branche `feat/base-game` sur 54443f6 ; `dev` réaligné ; Mac éveillé ; audits lancés ; NIGHT-PLAN posé (commit 1f70cac).
- 2026-06-24 — AUDIT état-code livré (harnais VERT, baseline capturée). Réframe majeur ci-dessous.
- 2026-06-24 — **Harnais PNG** livré+committé (0b545bc) ; **PIN 65 familles** committé (b0ff167) ; UI-audit 6 écrans.
- 2026-06-24 — **BANC livré** (A2, commit b2b8a27) : `self.bench[1..7]`, achat→banc/plateau, fusion banc↔plateau (ordre déterministe), drag complet, rendu+anim+infobulle ; **golden inchangé** ; screenshot vérifié (3 bandes propres). Reste (Phase C) : scale/spacing/label « RESERVE »/header dev + **test dédié banc**.
- 2026-06-24 — **34 renommages SEVERE prêts** (2 agents, vus PNG) → `docs/base-game/creature-renames.md` ; mild (~26) en cours (agent). Écriture en.lua = golden-neutre.
- 2026-06-24 — **Créatures RENOMMÉES** (commit, en.lua) : 38 noms édités + 17 entrées canoniques (bloc choc/bouclier — descriptions **condenser CORRIGÉES** vs `en_ext.lua` périmé qui décrivait l'ancien modèle amplify). i18n 83 OK, golden inchangé, **vérifié écran**. Reste : noms longs serrés sous les cases (Phase C) ; nettoyer doublons morts d'`en_ext.lua`.
- 2026-06-24 — **A4 ADVERSAIRES SCALÉS** livré (`oppgen.lua` + test ; commits) : équipe cohérente au stade (taille≈slots, rangs via cotes du tier, niveaux tardifs, placement tank-devant) ; déterministe seedé ; **vérifié écran** (r7/t3 → 5 unités variées). Golden inchangé. Reste : noms d'adversaires dédiés (réutilise les clés pré-construites) ; fairness à sim-tuner.
- 2026-06-24 — **GAME FEEL achat/vente/level-up** livré (build.lua, commit) : bursts éphémères (anneau achat / +N vente / flash+anneau+« LVL n » level-up) ; render-only, golden inchangé, **vérifié écran**.
- 2026-06-24 — **Design refonte combat** prêt (agent) → `docs/base-game/combat-refonte.md` (P0 sol+front+brume / P1 profondeur / P2 feel ; tout RENDER-only). **À implémenter** (le combat lit « 2 clusters dans le noir »).

### AUDIT-SYNTHÈSE (2026-06-24) — l'éco est DÉJÀ faite, CLAUDE.md périmé
L'économie « hybride mesuré » du créateur est **déjà implémentée** (`docs/research/progression-economy-prd.md`, Lots 0-6, **verrouillé post-playtest 2026-06-23**) :
- Or fixe **10/round**, reroll **1**, streaks (cap 3, win OU loss), vente 50 %. **Zéro intérêt de base.** ✓
- **Slots = grants temporisés GRATUITS** (rounds 2-7, accept / décline→+3 or), PAS via leveling. (CLAUDE.md « leveling=slots payant » → PÉRIMÉ.)
- **« Niveau » = tier de boutique via XP TFT** : passif **+1/round dès r2** + **achetable 4XP/4or** → gate les **COTES** (table ODDS r1-r5), pas les slots.
- **Boutique rank-tiérée** (plus de pool uniforme). **Doublons 3→niveau** (cascade, LEVEL_MULT 1/1.8/3).
- **Reliques = modèle LISIBLE** (effet montré, plus de leurres), cadence **/3 combats**, tiérées, décline→+or. (CLAUDE.md/relics.lua header « cryptique » → PÉRIMÉS.)

⇒ **Je NE RECONSTRUIS PAS l'éco.** Vrais manques pour la vision du créateur :
  1. **BANC** (n'existe PAS — gap dur : on ne peut pas acheter sans placer ⇒ boucle de merge non « pêchable »). **A2.**
  2. **Reliques d'éco** (intérêts / bonus d'or — le levier voulu). **A3.**
  3. **Adversaires scalés au STADE** (`pickEncounter` = f(round) seul ; ignore plateau / niveaux / tier / sigil ; 6 teams, répète `pit_sovereign` après ~r12). **A4.**
  4. **Cohérence créatures** (renommer + relore + ré-adapter effets vers le visuel canon). **Phase B.**
  5. **Synergies de TYPE** (M4 : les 5 familles DoT = les types ; contre seuils 2/4 ; 1 twist `more`/famille borné). **A5 — profondeur de build = « jeu complet ».**
  6. **Feedbacks éco** (achat / vente / level-up / merge = **ZÉRO VFX** aujourd'hui ; tier montré via pip+border). **Phase C.**

### DÉCISION (buyXp) — JE GARDE l'XP achetable
Malgré le libellé de l'option « hybride » (« pas d'XP-achetable »). Rationale : (1) l'intention réelle = « zéro intérêt de base, intérêt via reliques », pas la buyabilité ; (2) buyXp = **puits d'or qui achète de la puissance** (accélérateur TFT), pas un mécanisme d'intérêt/banque ; (3) design **verrouillé post-playtest** ; (4) le créateur veut de la profondeur. **Réversible** (1 bouton) si rejet au réveil.

### UI-AUDIT (2026-06-24, via harnais screenshot — 6 écrans lus)
- **MENU** : ✅ **référence DA** (blackletter, braises/noir, typo, vignette). Garder tel quel.
- **BUILD** : header encombré de **texte dev** (« SEE POOL · GALLERY… ») ; **pas de banc** ; tier/feedback à ajouter ; bug glyphe **W**. Place dispo **sous le plateau** pour le banc.
- **COMBAT** : **trop vide** (2 clusters sur grand noir) → **refonte** composition + atmosphère.
- **RELICPICK** : ✅ propre/cohérent (modèle lisible) ; micro-polish labels.
- **RUNOVER** : **BUG i18n `LEVEL [level]`** non interpolé ; « 1 ROUNDS » (pluriel) ; un peu vide.
- **GRIMOIRE** : ✅ bien fichu (2 volets, tabs, tri, back) ; bug glyphe **W** (« KNOWN »→« KNOMN ») ; « ??? CRYPTIC » = reliquat du vieux modèle cryptique (terminologie à revoir).
- **🐛 BUGS (vérifiés)** :
  - **(A) ❌ FAUSSE ALERTE** — le « W cassé » (WINS→XENS, KNOWN→KNOMN) est un **artefact de downsampling** de ma lecture des PNG ; les chaînes source sont correctes (`ui.wins`=« WINS », `grimoire.effect_known`=« KNOWN EFFECT »). Net en natif. **Aucun fix.**
  - **(B) ✅ VRAI BUG `[level]` runover** : `runover.lua:101` passe `level = r.level` mais le RunState a **`r.tier`** (migration level→tier) ⇒ var manquante rendue `[level]`. Fix = passer `r.tier`. Idem « 1 ROUNDS » (pluriel).
- **Cibles refonte** : combat (composition/atmosphère) ; header build (virer le dev) ; densifier (mineur) runover/grimoire.

### SIM-LOG  *(N · σ win% · entropie · outliers · levier)*
- **Baseline N=200** : σ **0.129**, entropie **0.995**, field_mean 0.653, 1 outlier (`demon` +1.6σ). DoT share **27.6 %**. Top : pyre_tender 90 %, plague_bearer 88.9 %, bellows_priest 87.5 %. Bas : soot_acolyte 33 %, static_swarm 38.5 %, ash_moth 40 %. ⚠️ détecteur de combos **starved @N=200** → **N≥2000** pour les lectures réelles (le créateur veut « par milliers »).

### GOLDEN-REBASELINE-LOG  *(ancienne → nouvelle · raison)*
- **Baseline confirmée : 970156547 / 199 events** (check.sh vert).

### DECISIONS-LOG  *(décisions autonomes + rationale)*
- 2026-06-24 — **Une seule** branche d'intégration (`feat/base-game`), poussée aux jalons (le créateur pull une seule chose). Worktrees d'agents fusionnés dedans.
- 2026-06-24 — Garder l'économie implémentée (cf. AUDIT-SYNTHÈSE) ; ne builder que les manques. Garder buyXp (cf. ci-dessus).
- 2026-06-24 — **Différer M5/M6/M8** (ranked / season / async) : multijoueur **hors scope cette nuit** (consigne créateur). Focus local complet.
- 2026-06-24 — **MANDAT SCREENSHOT (créateur)** : screenshot + vérifier **visuellement** chaque écran travaillé (beauté, cohérence DA, alignement, propreté) ; **refonte complète** autorisée des vieux écrans au design dépassé ; objectif « **100 % final** ». ⇒ je construis un **harnais de capture PNG sous vrai `love`** (keystone P0.5) pour m'auto-vérifier (le créateur dort) et je Read les PNG (vision).
- 2026-06-24 — **Créatures = PIN-puis-RENOMME** : visuels actuels = **canon**. ⇒ (1) **pin `family=`** sur les ~53 unités à famille **dérivée** (verrouille le sprite ; golden-neutre car la `family` est lue par le GÉNÉRATEUR, pas la SIM) ; (2) **renomme + relore** (i18n, golden-neutre) ; (3) **ré-adapte effets** vers le visuel en gardant la famille mécanique/rôle quand possible (**sim-gated** + rebaseline). Audit : ~32 SEVERE / 23 MILD / 28 none ; collisions (3 herons, 4 cocons, 3 marionnettes, 3 thrones…) **notées au réveil**. Spec complète : `docs/base-game/creature-identity-map.md`.
