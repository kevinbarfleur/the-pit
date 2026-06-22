# The Pit — Catalogue des composants d'interface (handoff designer)

> **But** : lister TOUS les éléments d'interface du jeu (inputs interactifs + cadres/conteneurs +
> fiches), chacun avec une maquette ASCII, ses états et son contexte d'usage — pour qu'un designer
> en produise des exemples pixel-art.
>
> **Style cible** : « forge gothique ARPG » (cf. `docs/pixel-art/forge-ui-reference.html`) — plaques
> sombres propres, **métal biseauté à la main** (laiton/or terni), **rivets** aux angles, **liseré or**,
> **texte binarisé**, **aucune texture bruitée** (le détail vient de la FORME). Rendu basse-réso +
> agrandissement nearest-neighbor. Accent commutable : or (défaut) / sang / mana / violet.

## Dimensions de référence (alignées sur le HTML)
- Espace de travail **basse résolution** (≈ ce que voit le baker), agrandi ×4. Texte binarisé ≈ **8 px**, chasse 6 px.
- **Bouton** : hauteur ≈ 28 (plaque 24 + 4 d'ombre portée) ; biseau métal **3 px** ; rivets à 4 px des coins.
- **Jauge** : hauteur ≈ 16 ; biseau **2 px**.
- **Orbe** : ≈ 64×64 ; anneau de laiton **3 px**.
- **Cadre 9-slice** : bordure **4 px** ; équerres d'angle **8×8** (art pixelé à la main, non étirées).

## Légende ASCII
```
●  rivet / clou de laiton          ━ ═ ║  arête métal biseautée
◆ ◇  gemme / losange / pip          ▓ ▒ ░  remplissage (fluide / tramé / vide)
▦   icône d'affliction (8×8)        ▸ ◂   chevrons de survol
★   pip de rareté                   ╌ ╎   trait « scellé / verrouillé »
```
> Les états sont notés **repos / survol / clic(enfoncé) / désactivé / sélectionné** selon le composant.

---

## A. BOUTONS & ACTIONS (inputs)

### A1 — Bouton CTA primaire
Usage : COMBAT (build), BIND THE FRAGMENT (relique), ENTER THE PIT (menu), NEW RUN (fin de run).
États : repos / survol (label s'éclaire, liseré or vif) / **clic (s'enfonce 1px, écrase l'ombre)** / désactivé.
```
 repos                 survol                clic (enfoncé)        désactivé
 ●━━━━━━━━━━━━●        ●━━━━━━━━━━━━●        ●━━━━━━━━━━━━●        ●╌╌╌╌╌╌╌╌╌╌╌╌●
 ┃  DESCENDRE ┃        ┃  DESCENDRE ┃        ┃  DESCENDRE ┃        ╎   SCELLÉ   ╎
 ●━━━━━━━━━━━━●        ●━━━━━━━━━━━━●        ●━━━━━━━━━━━━●        ●╌╌╌╌╌╌╌╌╌╌╌╌●
   ▔▔▔▔▔▔▔▔▔▔            ▔▔▔▔▔▔▔▔▔▔             ▔▔▔▔ (réduite)        (grisé, mat)
 plaque + cadre        label or vif +        plaque baissée,       label éteint,
 laiton + rivets +     halo discret          ombre comprimée       pas de rivets
 label or
```

### A2 — Bouton d'économie (secondaire)
Usage : REROLL (+coût), NIVEAU/LEVEL, REFUSER +or, WATCH/SIM (banc d'essai).
États : repos / survol / clic / désactivé (or insuffisant). Plus petit que le CTA, même métal, label + valeur.
```
 ●──────────●        ●──────────●
 │ REROLL 1◇│        │  NIVEAU  │        valeur (coût) à droite si présente
 ●──────────●        ●──────────●
```

### A3 — Bouton-icône (carré)
Usage : changer de sigil [s], flèches de page (galerie ‹ ›), retour/BACK, futur engrenage réglages.
États : repos / survol / clic.
```
 ●────●     ●────●     ●────●
 │ ◈  │     │ ‹  │     │ ⟲  │     glyphe/flèche binarisé centré
 ●────●     ●────●     ●────●
```

---

## B. SÉLECTION & NAVIGATION (inputs)

### B1 — Onglet (tab)
Usage : Codex (RELIQUES / BESTIAIRE). État : actif (plaque éclairée + liseré or) / inactif (mat).
```
 ┌─RELIQUES─┐  BESTIAIRE              actif : relief + or
 │  ●    ●  │ ─────────────          inactif : aplat sombre, label éteint
 └──────────┴───────────────
```

### B2 — Item de menu (ligne sélectionnable)
Usage : écran-titre (ENTER / GRIMOIRE / PROVING / ABANDON). États : repos / survol / désactivé (SEALED).
```
   ENTER THE PIT              repos : texte traqué éteint
 ▸ ENTER THE PIT ◂            survol : éclairé + chevrons / liseré or
   RITES & OFFERINGS  (SEALED)  désactivé : très éteint + tag
```

### B3 — Puce de filtre (chip-toggle)
Usage : filtres du banc d'essai (Spread / Cross / Control…). État : inactif (contour) / actif (rempli accent).
```
 ( Spread )  ( Cross )  «Control»      actif = pilule pleine accent + texte sombre
```

### B4 — Bouton de tri / cycle
Usage : codex « TRI : type ▾ ». Clic = cycle l'ordre.
```
 ┌──────────────┐
 │ TRI : TYPE ▾ │     petite plaque, libellé + chevron
 └──────────────┘
```

### B5 — Barre de défilement (scrollbar)
Usage : listes longues (codex, banc d'essai). Piste sombre + pouce métal proportionnel.
```
 ║░║          piste (logement sombre)
 ║▓║   ◄ pouce métal (taille = part visible)
 ║▓║
 ║░║
```

---

## C. PLATEAU & BOUTIQUE (inputs spécifiques)

### C1 — Case du plateau (slot / drop-target)
Usage : 9 cases du sigil. États : vide / verrouillée / survol / cible-de-drop / **occupée** / voisine (adjacence).
```
 vide        verrouillée   survol        cible drop     occupée            voisine
 ┌──────┐    ┌╌╌╌╌╌╌┐      ●──────●      ┌──────┐       ●──────●           ┌──────┐
 │      │    ╎  +   ╎      │      │      │  ▼   │       │ [rig]│           │ [rig]│
 │      │    ╎      ╎      │      │      │      │       │ ▦ ●● │           │      │
 └──────┘    └╌╌╌╌╌╌┘      ●──────●      └──────┘       ●──────●           └──────┘
 sobre        scellé,      liseré or     vert (valide)  pip type + niveau   liseré sang
              glyphe +                                  + nom dessous       (lien)
```

### C2 — Carte de boutique (offre achetable)
Usage : 5 offres du shop (drag → case). États : achetable / trop cher / survol / vendu.
```
 achetable      trop cher      vendu
 ●────────●     ┌────────┐     ┌────────┐
 │ [rig]  │     │ [rig]  │     │        │
 │ ▦▦     │     │ ▦▦     │     │  SOLD  │
 │ NOM ❲3◇│     │ NOM ❲5◇│     │        │
 ●────────●     └────────┘     └────────┘
 cadre or +     cadre mat,     plaque éteinte
 coût or        coût grisé
```
(`▦▦` = mini-icônes des afflictions que l'unité applique ; `❲n◇` = coût.)

### C3 — Emplacement de relique possédée
Usage : rangée de reliques au-dessus de la boutique. Repos / survol (→ infobulle).
```
 ●────●  ●────●  ●────●        icône bakée 16×16, sertie ; survol = liseré or
 │[◈] │  │[◈] │  │[◈] │
 ●────●  ●────●  ●────●
```

---

## D. JAUGES & RESSOURCES (affichage)

### D1 — Jauge de vie (gauge)
Usage : barre de vie au-dessus de chaque unité en combat. Logement sombre + fluide tramé + crête + **segments d'altération** + alarme sous 25%.
```
 ●━━━━━━━━━━━━━━━●
 ┃▓▓▓▓▓▓▓▒▒░░░░░░┃     ▓ vie · ▒ segment affliction (couleur famille) · ░ vide
 ●━━━━━━━━━━━━━━━●     crête lumineuse au front ; pulse rouge si < 25%
   ▦ ▦                 rangée d'icônes d'afflictions actives sous la barre
```

### D2 — Orbe de ressource (signature ARPG)
Usage : candidat pour VIES (et/ou une ressource future). Verre bombé + fluide ondulant + reflet + anneau laiton.
```
    ╭───────╮          anneau de laiton + 4 rivets cardinaux
   ╱▓▓▓▓▓▓▓▓▓╲         fluide qui MONTE selon la valeur (vague animée)
  │▓▓▓▓▓▓▓▓▓▓▓│        reflet spéculaire haut-gauche, bulles
  │▓▓▓▓▓▓▓▓▓▓▓│
   ╲▓▓▓▓▓▓▓▓▓╱
    ╰───────╯
   VIES · 4/5
```

### D3 — Plaque HUD (bandeau de run)
Usage : haut de l'écran build (OR / VIES / VICTOIRES / ROUND / SLOTS). Bandeau métal, labels éteints + valeurs claires.
```
 ●─────────────────────────────────────────────●
 │  OR 12   VIES 4/5   VICTOIRES 3/10   ROUND 4 │
 ●─────────────────────────────────────────────●
```

---

## E. CADRES & CONTENEURS (frames)

### E1 — Panneau 9-slice (conteneur générique)
Usage : tout panneau (boutique, codex, détail…). Équerres d'angle 8×8 **intactes**, bords répétés, centre = aplat sombre. Taille libre.
```
 ╔●═══════════════════●╗      ● équerre d'angle (art à la main)
 ║                     ║      bords = motif répété
 ║      contenu        ║      centre = plaque sombre propre
 ║                     ║
 ╚●═══════════════════●╝
```

### E2 — Séparateur (divider)
Usage : entre sections d'un panneau / d'une fiche. Filet dégradé + losange central.
```
 ────────────────◆────────────────      fond → or au centre, ◆ losange
```

### E3 — Bannière de résultat
Usage : VICTOIRE / DÉFAITE (fin de combat), fin de run. Grand mot gothique cadré.
```
 ═══════════════════════════
        V I C T O I R E
 ═══════════════════════════
```

### E4 — Infobulle / fiche au survol (conteneur flottant)
Usage : survol d'une unité ou d'une relique. Petit panneau 9-slice qui suit le curseur (cf. F1 pour la fiche monstre).
```
 ╔●═══════════════●╗
 ║  (contenu fiche) ║   suit le curseur, rebond sur les bords
 ╚●═══════════════●╝
```

### E5 — Conteneur scrollable (liste + clip)
Usage : listes du codex / banc d'essai. Cadre + zone clippée + scrollbar (B5).
```
 ╔●═══════════════●●╗
 ║ ligne 1         ▓║   ◄ contenu clippé au cadre
 ║ ligne 2         ▓║   ◄ scrollbar à droite
 ║ ligne 3         ░║
 ╚●═══════════════●●╝
```

---

## F. CARTES & FICHES (composés)

### F1 — Fiche monstre (carte TCG, au survol)
Usage : survol d'une unité (build/codex). Le composé le plus riche : portrait + identité + tags + stats + capacités + flavor. Cadre 9-slice (gildé si rang élevé).
```
 ╔●═══════════════════════●╗
 ║ ASH-MAW           ❲ 5◇ ┃   nom (gothique) + coût
 ║ ┌─────────────────────┐ ║
 ║ │     [ portrait ]    │ ║   rig re-rendu + halo de rareté
 ║ └─────────────────────┘ ║
 ║ ◗ ABYSS · Démon  ★★★★★  ║   type+couleur · famille · rang
 ║ [ CARRY ][ ▦BURN ][CHIM]║   chips : rôle / affliction / bodyplan
 ║ ─────────────────────── ║
 ║  ♥ 70    ⚔ 6    ⧗ 6.0s  ║   stats à glyphes
 ║ ─────────────────────── ║
 ║ ◉ ▦ Brûlure  6 dps · 3s ║   capacité : chip + valeurs
 ║   Chaque coup embrase.  ║   + prose
 ║ ◉ ✦ Pacte de Cendre     ║
 ║ « Il respire, le Puits  ║   flavor (si la place)
 ║   expire. »             ║
 ╚●═══════════════════════●╝
```

### F2 — Carte de relique (choix 1-parmi-3)
Usage : écran relique post-victoire (3 cartes). États : repos / survol / sélectionnée (liseré or).
```
 ╔●═════════════●╗
 ║   [ icône ]   ║   icône bakée ×grande
 ║  BLOODSTONE   ║   nom
 ║ ───────────── ║
 ║ +X à l'effet  ║   effet clair (or)
 ║ « flavor… »   ║   ambiance (serif)
 ╚●═════════════●╝
```

### F3 — Ligne de codex (entrée de liste)
Usage : listes Reliques / Bestiaire. Vignette + nom + méta. États : repos / survol / sélectionnée / inconnue (« ? »).
```
 ┌────┬────────────────┐        connue              inconnue
 │ ▣  │ ASH-MAW         │       ┌────┬─────────┐    ┌────┬─────────┐
 │    │ ABYSS    R5     │       │[rig]│ NOM     │    │ ?  │ ??????  │
 └────┴────────────────┘       └────┴─────────┘    └────┴─────────┘
```

### F4 — Échelle de rareté (R1→R5)
Usage : panneau détail du bestiaire. Cinq cadres, rang courant éclairé, pips.
```
  R1    R2    R3    R4    R5
 ┌──┐  ┌──┐  ┌──┐ ╔══╗  ┌──┐     le rang courant = cadre éclairé
 │░░│  │░░│  │░░│ ║██║  │░░│
 └──┘  └──┘  └──┘ ╚══╝  └──┘
  ★     ★★    ★★★  ★★★★  ★★★★★
```

---

## G. ATOMES (briques réutilisables)

### G1 — Chip de mot-clé (affliction / tag)
Usage : partout où une affliction/un tag est mentionné (fiche, codex, relique). Icône 8×8 + nom + valeur, liseré couleur famille.
```
 ┌────────────┐   ┌──────────┐   ┌──────────┐
 │ ▦ BURN   6 │   │ ▦ POISON │   │  CARRY   │   (tag pur = sans icône)
 └────────────┘   └──────────┘   └──────────┘
```

### G2 — Pip de type
Usage : marque la famille d'une unité. flesh=barre · order=croix · bone=diamant · arcane=étoile · abyss=disque.
```
 ▬   ✚   ◇   ✷   ●
```

### G3 — Pips de niveau (duplicatas)
Usage : coin d'une case, niveau 2-3 (fusion TFT). Petits carrés dorés.
```
 ▪ ▪ ▪      (1 à 3, dorés)
```

### G4 — Gemme / indicateur d'état
Usage : voyant on/off (sceau actif, statut). Sertissage métal + gemme facettée qui s'allume.
```
 ◇  inerte (sombre)        ◆  éveillé (facettes accent + reflet)
```

### G5 — Traitement de titre
Usage : titres d'écran/section. Gothique (Jacquard) en casse de titre, court ; sous-titre traqué (Silkscreen).
```
 The Pit                 (gothique, grand)
 T H E   O F F E R I N G  (traqué, éteint)
```

---

## Hors-scope (non requis actuellement)
- **Champ de saisie texte** : le jeu n'a aucune entrée clavier de texte.
- **Sliders / réglages** : pas d'écran options à ce jour (volume, etc.). À prévoir SEULEMENT si un menu réglages arrive.
- **Cases à cocher / radios** : remplacées par les onglets (B1) et puces (B3).

## États à fournir par le designer (récap)
| Composant | repos | survol | clic/enfoncé | désactivé | sélectionné | actif/on |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Boutons A1–A3 | ✓ | ✓ | ✓ | ✓ | — | — |
| Onglet B1 / item B2 | ✓ | ✓ | — | ✓ (B2) | ✓ | — |
| Puce B3 / tri B4 | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| Case C1 | ✓ (vide/verrou) | ✓ | — | — | ✓ (drop/occupée) | ✓ (voisine) |
| Carte shop C2 | ✓ | ✓ | — | ✓ (cher/vendu) | — | — |
| Carte relique F2 | ✓ | ✓ | — | — | ✓ | — |
| Gemme G4 | — | ✓ | — | — | — | ✓ |
