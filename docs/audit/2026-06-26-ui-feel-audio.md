# Audit UI, DA, game feel et audio - 2026-06-26

## Verdict visuel

La direction artistique est beaucoup plus avancee qu'un prototype classique :
palette sombre, typographie forte, cartes lisibles, reliques iconiques, rendu
procedural coherent, UI "reliquaire" identifiable.

Le probleme principal est la **consistance de chrome**. Les captures ne donnent
pas l'impression d'un jeu sans DA ; elles donnent l'impression d'un jeu ou
plusieurs niveaux de DA coexistent :

- menu : scene ceremonielle tres vide ;
- build : outil dense, presque dashboard ;
- combat : plateau theatre avec grands ornements d'yeux ;
- summary : dashboard de resultat ;
- relicpick : scene rituelle lisible et calme ;
- grimoire : galerie/codex ;
- designsystem : storybook encadre par un grand cadre rouge/brun.

Tout est defendable individuellement. Ce qui manque est une regle qui explique
pourquoi chaque famille d'ecran a ce degre d'ornement.

## Screenshots inspectes

Les captures ont ete generees avec :

```sh
love . --shoot=all --shoot-size=1280x720
```

Chemin :

```text
/Users/kevinbarfleur/Library/Application Support/LOVE/the-pit/shots/
```

Constats rapides :

- `build.png` : bonne densite d'information, board clair, shop lisible. Le
  centre de l'ecran est tres vide autour du board, ce qui peut etre voulu, mais
  accentue le decalage avec le bandeau shop tres dense.
- `combat.png` : les silhouettes et barres sont lisibles. Les grands yeux en
  coin ont une presence enorme ; ils donnent de l'identite, mais peuvent voler
  l'attention au combat.
- `summary.png` : tres bon potentiel de postmortem sous agence. Les grands yeux
  lateraux et certains elements tres sombres peuvent perturber la lecture.
- `relicpick.png` : cartes tres lisibles, bon rituel. L'ecran est propre.
- `grimoire_relics.png` : galerie forte. Petit probleme visible : le compteur
  du tab bestiaire semble trop proche du label (`BESTIARY110/110` visuellement).
- `designsystem.png` : tres utile comme source visuelle, mais son cadre massif
  est plus fort que la plupart des ecrans de production.
- `system.png` / `settings.png` : modales lisibles et coherentes.
- `commander_hover.png` : fiche riche et lisible, bon exemple de tooltip
  complexe ; attention au recouvrement massif du board.
- `build_relic_hover.png` : pop-up de relique claire et conforme au modele
  lisible.

## Politique de chrome proposee

Creer une page source de verite : `docs/audit/chrome-policy.md` ou
`docs/research/chrome-policy.md`.

Familles recommandees :

1. **Run utilitaire** : build, combat HUD, inspect.
   Chrome faible a moyen, densite haute, ornements contenus. Le joueur doit
   agir vite et comparer.

2. **Rituel/recompense** : relicpick, level-up, runover, victory/defeat.
   Chrome moyen a fort, typographie ceremonielle, CTA unique, animations
   lentes mais courtes.

3. **Codex/collection** : grimoire, bestiary, relicons.
   Chrome moyen, grille stable, hover riche, scroll clair.

4. **System/dev** : settings, pause, designsystem, playground, gallery.
   Chrome sobre, pas plus spectaculaire que le jeu principal sauf storybook.

Regles pratiques :

- un seul CTA primaire rouge par ecran ;
- pas d'ornement geant dans un ecran utilitaire sauf s'il porte une fonction ;
- meme hauteur/bordure pour les tabs d'un meme niveau ;
- les pop-ups doivent avoir un plan de profondeur clair : modal > tooltip >
  cards > board ;
- les ecrans rituels peuvent utiliser les grandes typos ; les ecrans utilitaires
  doivent rester plus denses.

## Design system et composants

Points solides :

- `Theme` centralise couleurs et polices.
- `Draw` gere une UI native lisible en 1280x720 design.
- `Button`, `Panel`, `Slot`, `Gauge`, `Badge`, `Tooltip`, `RelicCard` existent.
- `designsystem.lua` rend les composants in-engine.
- `Feel` et `Button` sont branches pour hover/press/lift/squash/charge.

Points a consolider :

- `docs/research/game-ui-implementation.md` recommande `Theme.sp`,
  `Layout.grid`, `Layout.anchored`, `Layout.hug`, `ScrollView`. Dans `src/ui`,
  `Layout.row/column/inset` existent, mais pas encore toute cette API. Soit on
  l'implemente, soit on met a jour le doc.
- `src/ui/forge.lua` reste large et actif via `Button`/`Frame`/`NightmareBG`.
  Les commentaires disent parfois "ancien kit remplace", mais il est encore un
  moteur de bake utile. Il faut le renommer mentalement : pas "legacy mort",
  plutot "bake forge runtime", avec surface publique limitee.
- `src/scenes/designsystem.lua` contient encore un exemple `cryptic` pour
  `RelicCard`, alors que le modele courant est lisible. A corriger.

## Game feel

Le projet a deja les bons modules :

- `src/ui/feel.lua` : hover, press, action differee, charge.
- `src/ui/juice.lua` : scale/nudge/tilt, trauma shake, hitstop.
- `src/render/arena_draw.lua` : damage numbers, impacts, death burst, flash,
  audio throttled.
- `src/scenes/build.lua` : place/drop/coin/merge FX.

La prochaine etape n'est pas d'ajouter plus d'effets partout. C'est de formaliser
un **contrat de feedback** par action.

Table a creer :

| Action | Visuel immediat | Son | Delai | Payoff | Echec |
| --- | --- | --- | --- | --- | --- |
| Hover bouton | lift + glow | hover | 0 | aucun | aucun |
| Press CTA | squash + flash | press | 80-140 ms | scene transition | error si invalide |
| Acheter unite | or punch + carte retiree | coin | 0 | unite drag/place | error no gold |
| Drop valide | slot glow + pop | drop/place | 0 | unit settles | aucun |
| Fusion | merge burst + hitstop | ladder/success | court | level visible | aucun |
| Choix relique | card seal | success | court | transition build | aucun |
| Fin combat | freeze bref + banner | success/defeat | court | summary | aucun |

Sans ce tableau, le feel dependra des endroits ou tu as pense a brancher `SFX`
et `Juice` ce jour-la.

## Audio

La base audio est bonne :

- SFX proceduraux par pack, pool de voices, pitch jitter.
- Hooks `Feel.onHover` et `Feel.onPress`.
- Musique en stems avec crossfade par morceau et couches combat.
- Build/combat/relicpick partagent le morceau de run sans redemarrage brutal.

Risques :

- Les cues sont encore beaucoup codes directement dans les scenes.
- Le vocabulaire audio existe (`hover`, `press`, `coin`, `drop`, `success`,
  `defeat`, etc.), mais il n'y a pas encore de table "action -> cue".
- Pas d'audit d'oreille documente dans le repo : on sait que ca compile et joue,
  pas que le mix fatigue peu sur 30 minutes.

Recommandation :

- `src/audio/cues.lua` : mapping semantique par action (`buy`, `drop_valid`,
  `drop_invalid`, `merge_small`, `merge_big`, `relic_pick`, etc.).
- garder `SFX.play(name)` comme backend, mais ne plus disperser les noms de sons
  dans toutes les scenes ;
- ajouter une scene/dev "soundboard" ou un onglet settings/dev pour auditionner
  les packs.

## Transitions de scene

Aujourd'hui, `host.goto` change directement de scene. Certaines actions utilisent
`Feel.press(id, callback)` pour laisser voir le press avant le changement, et la
musique fait deja des crossfades. Mais il manque une couche commune de transition.

Proposition :

- `src/core/scene_transition.lua` ou `src/ui/transition.lua`
- API :

```lua
Transition.request({
  kind = "ritual" | "snap" | "fade" | "combat",
  out = 0.10,
  hold = 0.02,
  inn = 0.16,
  swap = function() host.gotoNow(name, payload) end,
})
```

`host.goto` deviendrait une demande de transition, et `host.gotoNow` ferait le
switch immediat. Les transitions doivent rester presentation-only : elles ne
touchent ni la sim, ni les seeds, ni le run state.

Types recommandes :

- `snap` : menus utilitaires, pause/settings, retour grimoire.
- `ritual` : relicpick, runover, level-up, victory/defeat.
- `combat` : build -> combat, avec bref voile sombre + son/whoosh.
- `none` : tests/export si besoin.

## Benchmark design : ce qu'il faut copier, pas copier

Balatro : copier la clarte de la formule et l'amplification sensorielle, pas le
theme ni le chaos visuel. Le joueur doit comprendre pourquoi ca explose.

Super Auto Pets : copier la boucle async sans pression et les phases claires
build/battle, pas la simplification cartoon.

Backpack Battles : copier l'idee de "je pose une hypothese, le combat la teste",
pas le puzzle spatial libre.

Postmortems Underlords/Artifact : eviter la complexite invisible et la dilution
des archetypes. Si le joueur perd, il doit savoir quoi essayer autrement.

## Definition of done visuelle

Une feature UI/feel n'est pas finie quand elle compile. Elle est finie quand :

- `sh tools/check.sh` passe ;
- une capture `--shoot` montre l'etat normal, hover/tooltip si pertinent, et
  modal/transition si pertinent ;
- le texte ne se chevauche pas a 1280x720 ;
- le composant existe dans `designsystem.lua` si c'est un atome/molecule ;
- les cues audio passent par le vocabulaire commun ;
- aucun effet presentation ne modifie la SIM.
