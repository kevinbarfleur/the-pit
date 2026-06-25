# Refonte des effets/synergies — RÉCAPITULATIF DE CAMPAGNE

> **Pour le créateur, à ton retour.** Synthèse de la campagne autonome multi-agents lancée le 2026-06-24
> sur la branche **`feat/effects-overhaul`** (depuis `feat/base-game`). Tout est **committé localement,
> RIEN n'est poussé** — la décision de merge `dev` / push te revient. `sh tools/check.sh` est **VERT**,
> golden stable **`1176281181`**.

---

## 1. Ce qui était demandé

Sortir de la **monoculture d'afflictions** (75,9 % du roster = « frappe → applique un DoT ») et créer de
vraies **synergies positionnelles** + un build-around dopaminergique, en **réutilisant les ~83 créatures
existantes** (on change leurs EFFETS, pas les sprites). Y inclure : **commandants** (slot invulnérable,
aura d'équipe, condition de défaite) et **murmures** (3e couche cachée, lore), **reliques à 3 paliers** +
**~8 reliques/partie**, et un **gros équilibrage de masse**. Vérifier chaque conclusion par d'autres
agents, sans pression de temps.

## 2. Ce qui a été livré (tout committé sur `feat/effects-overhaul`)

| Système | Détail | Commits clés |
|---|---|---|
| **Spec + design** | Spec source (5 critiques adversariaux), plan de contenu v2, plans reliques/commandants/murmures | `961b241`, `1d19ddb`, `064077b`, `c72a496` |
| **Moteur (keystones)** | `aura_stat` générique · `Stats` empower (`atkInc`)/vuln (`vulnInc`) + **caps durs** (ATK 1.5 / VULN 0.5 / backstop ×7) · **multicast entier** (cap 3) · **slot commandant** (K4) · triggers on_kill/on_ally_death/on_low_hp · 8 new-ops (crit/execute/grant_vuln/grant_affliction_if_absent/convert_dot/cleave/heal_on_kill/purge) | `28f37d5` (revu adversarialement = SAFE) |
| **Effets des unités** | **15 greffes agnostiques** sur des hôtes au visuel parfait (multicast, vuln, empower, hâte, armure, execute, heal_on_kill, cleave, grant-if-absent, purge, aggro) → ~85 % de DoT-pur ramené, sans casser les 5 familles DoT | `b381bf1` |
| **Reliques** | **3 paliers nets** (BAS stats / MOYEN transformatif / HAUT réécrit une règle), pool **25 → 34** (+9, dont les verbes réservés), op `relic_aura_stat`, **cadence ~8/run** (canal 3 = jalons 3e/6e victoire) | `3ea03f0` |
| **Commandants** | **LIVE** : slot piédestal hors-graphe, 6 chefs (Tambour/Calice/L'Aïeul/Roi des Rats/Couronne d'Échos/Bris-Siège), drag-drop, grant de run, aura build-résolue, board mort = défaite. **UI** : socle carvé, survol→portée éclairée, cadence, « At command » | `9c6d975`, `0f078fb` (UI) |
| **Murmures** | 3e couche **cachée** (spice, jamais build-defining), `whispers.lua` data-pure + lint, **log cryptique 2 canaux** (joueur sans valeur / dev avec valeurs), 10 exemplars ancrés **lore canon**, snapshot gratuit | `fe2c417` |
| **Icônes** | 9 nouvelles reliques ciselées (placeholder → art fini, cohérent avec les 25) | `43adb92` |
| **Équilibrage** | Harnais `tools/balancematrix.lua` (matrice early/mid/end × 34 reliques × 6 commandants) + 2 rounds de tuning | `375c980`, `556f080`, `25e6931` |

## 3. Verdict d'équilibrage (honnête)

**Le MOTEUR est sain** : **0 gate · 0 combo cassé** (lift>1.6) **· 0 dominant suspect** (les dominants
gagnent à coût juste, par sur-investissement légitime) · déterministe · golden stable.

**Tuning fait** : auras de commandant `level:1`/`tier:1` resserrées (elles dominaient l'early car tout le
board y est niveau 1) ; rot front-load qui **renforce son identité anti-mur** (rot-vs-mur 80→95 %).

**2 constats ASSUMÉS (pas des bugs, décision pour toi)** :
1. **Entropie de diversité 0,864 < 0,90 (cible)** — le **rot** est un **contre-spécialiste sain** (100 %
   vs les murs, 0 % vs le burst rapide). Le rendre « méta-présent » exigerait de lui donner de la
   survie/du burst = **le dénaturer**. On a choisi de **préserver son identité** plutôt que de gratter
   l'entropie.
2. **Courbe MID > END** — aucune compo ne contre proprement le **mur regen+taunt+purge** (qui est la compo
   la plus investie). En partie **réel**, en partie artefact de mesure (corrigé en partie).

   **Levier de diversité FUTUR (contenu/design, PAS du tuning de valeurs)** : les **bullies poison**
   (`poison_diamant_perfect` bat presque tout — c'est *eux*, pas le rot, qui plombent la diversité) et/ou
   une **unité anti-mur dédiée** au tier mid. À décider par toi.

**Recommandation** : **équilibré-suffisant pour livrer.** On n'a pas sur-tuné ni truqué de métrique.

## 4. Différé (volontairement, hors v1)

- **Esquive** (`the_coward`, seul murmure RNG) — derrière le contrat snapshot 2-camps (W7).
- **Snapshot** du commandant + de la synergie-famille (C5) — un ghost rejoue sans eux (effet LOCAL solo) ;
  à encoder **avant** d'ouvrir ces systèmes au **multi async**.
- **Synergie-famille-à-l'achat** : implémentée en effet LOCAL ; idem snapshot.

## 5. Comment reprendre / valider

- **Jouer** : `love .` — débloque le piédestal au round 3, couronne une bête, survole le socle + une fiche.
  ⚠️ **Ton PC fait foi** pour le rendu (le `--shoot` masque les bugs de transform) : valide l'UI piédestal
  en vrai.
- **Équilibrage** : `luajit tools/balancematrix.lua [N]` → `runs/balance-matrix.json` + résumé priorisé.
- **Tests** : `sh tools/check.sh` (déterminisme + firewall + headless + golden + bands + props + ui…).
- **Merge** : `git switch dev && git merge --no-ff feat/effects-overhaul` puis re-vérifier vert (au signal).

## 6. Méthode (pour mémoire)

Chaque conclusion a été **vérifiée par d'autres agents** : 5 critiques adversariaux sur la spec, revues
adversariales indépendantes du moteur et des commandants (déterminisme/golden/firewall, edge cases),
2 critiques sur le plan de contenu (qui ont fait remonter de ~8 à 15 greffes), et le tuning piloté par un
harnais de matrice avec seuils objectifs. Tout en commits jalonnés, `check.sh` vert à chaque étape, golden
géré.
