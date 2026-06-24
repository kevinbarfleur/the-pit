# The Pit — présentation express

> **Autobattler multijoueur asynchrone**, en pixel art.
> Univers **grimdark cryptique** : *Cthulhu × Path of Exile × Dark Souls*. On descend **Le Puits**.
> Solo dev · Lua / LÖVE · **projet en construction**.

---

## L'idée en une phrase

Tu **bâtis une équipe de monstres** sur un petit plateau, puis tu la regardes **se battre toute seule**.
Tu ne joues pas le combat — tu joues les **décisions d'avant** : qui acheter, qui placer, **où**.
Et le « où » compte autant que le « qui ».

```
   ┌─────────────┐   achète + place   ┌─────────────┐   tu regardes   ┌─────────────┐
   │  BOUTIQUE   │ ─────────────────▶ │   COMBAT    │ ───────────────▶│  RÉSULTAT   │
   │   + BUILD   │ ◀───────────────── │   (auto)    │  victoire /     │  on continue│
   └─────────────┘   round suivant    └─────────────┘   défaite       │  la descente│
                  (le plateau est conservé entre les rounds)           └─────────────┘
```

> *⚠️ Projet **solo, en construction**. Je travaille **encore sur les game loops** — le rythme des
> matchs, leur durée, la structure du run, l'économie : rien de figé côté équilibrage. Ce qui suit, ce
> sont les **mécaniques de fond**, posées, qui font l'identité du jeu.*

---

## ⭐ La mécanique signature : le plateau **EST** le graphe de synergies

Un plateau **3×3** (9 cases). L'**adjacence** est orthogonale : **un voisin buffe son voisin**.
La case du **centre** touche 4 voisins → c'est la place de la **carry**.

```
        arrière        avant (exposé à l'ennemi →)
        ┌────┬────┬────┐
        │ .  │ .  │ .  │      ● — ● : ces deux-là se buffent (voisins)
        ├────┼────┼────┤
        │ .  │ C  │ .  │      C = centre = 4 voisins = siège de la carry
        ├────┼────┼────┤
        │ .  │ .  │ .  │      placer, c'est déjà jouer
        └────┴────┴────┘
```

### Et la grille **change de forme** : les **sigils**

Des reliques redessinent la **topologie** du plateau — toujours 9 cases, mais des **connexions
différentes**. Une géométrie **non-euclidienne** : c'est à la fois le **thème** (lovecraftien) et la
**mécanique**. **1 forme = 1 archétype** qui l'adore.

```
     CARRÉ              CROIX              LIGNE
   ●─●─●              ·  ●  ·            ●
   │ │ │                 │              │
   ●─●─●              ●─●─●             ●          (+ anneau, diamant…)
   │ │ │                 │              │
   ●─●─●              ·  ●  ·            ●
  équilibré         mono-carry         file / conduit
```

> Tu n'échanges pas de la *puissance*, tu échanges une *forme* — donc une autre façon de connecter
> tes synergies.

---

## Le combat : automatique, mais **100 % déterministe**

Pas de timeline temps réel : chaque unité **frappe à son cooldown**. Aucun dé caché — le RNG est
**seedé**. Même équipe + même graine = **bataille identique** (clé du multi, plus bas).

Le **ciblage** est entièrement prévisible — donc **le placement devient du skill** :

```
   TON ÉQUIPE                     ENNEMI
   arr   mid   front   ║   front   mid   arr
  [carry][ ][ TANK ]   ║   [TANK ][ ][carry]
                  ▲           ▲
   on tape la COLONNE AVANT d'abord, dans l'ordre :
   colonne avant → TAUNT → aggro la plus haute → départage haut→bas
   ⇒ ton TANK encaisse devant, ta CARRY reste protégée derrière.
```

---

## ⭐ Le multijoueur **fantôme** (asynchrone)

Tu n'affrontes **jamais** un joueur en direct. Le jeu prend des **photos figées** (snapshots) de vraies
équipes et te les sert comme adversaires — des **« ghosts »**. Jouable **hors-ligne**, zéro netcode.

```
   TOI (build réel)                          AUTRES JOUEURS
   ┌──────────┐    snapshot figé      ┌────────────────────┐
   │ ton team │ ───(unités+sigil)───▶ │   réservoir de     │
   └──────────┘                       │      « ghosts »    │
                                      └─────────┬──────────┘
                                                │ servi selon
                                                │ ta progression / ton rang
   TOI, plus tard  ◀── tu combats un GHOST figé (pas un humain en direct)
                       (pas assez de ghosts ? → équipes IA en renfort)
```

Comme tout est **déterministe**, un combat est **rejouable et vérifiable** à l'identique. C'est ce qui
rend le multi async possible **sans serveur de jeu temps réel**.

---

## Les monstres : exemples & passifs

Chaque monstre a un **passif** — sa capacité de combat. Quelques exemples réels du jeu :

| Monstre | Passif |
|---|---|
| **La Sorcière** | empoisonne à chaque coup (le poison s'**empile**) |
| **Le Gardien des tombes** | TANK : **force** l'ennemi à le viser + renvoie des **épines** |
| **L'Appeleur d'orage** | charge un **condensateur** ; au coup suivant, tout se **décharge** d'un coup |
| **Le Porte-peste** | son poison **contamine** les voisins de la cible |
| **Le Démon** | **vole la vie** à chaque coup |
| **La Gueule de cendres** | tant qu'elle vit, les **feux de TOUTE l'équipe ne s'éteignent plus** |

À ça s'ajoutent : les **afflictions** (poison, brûlure, saignement, pourriture, choc — elles s'empilent,
se propagent, se croisent), les **duplicatas** (3 copies identiques → fusionnent en une version
supérieure), et les **reliques** (offre 1-parmi-3, effet lisible, collectionnées dans un **Grimoire**
persistant entre les runs).

---

## 🔭 Le prochain grand chantier : **3 identités par monstre**

*(conçu et décidé — pas encore implémenté, c'est ma direction de design.)*

L'idée : sortir d'un monde où tout tourne autour des afflictions, et donner à **chaque monstre trois
couches d'identité** distinctes.

```
   UN MONSTRE = 3 identités
   ┌──────────────────────────────────────────────────────────┐
   │ 1. PASSIF        ce qu'il fait au combat   → visible (socle)│
   │ 2. COMMANDEMENT  son aura s'il DIRIGE       → visible (choix)│
   │ 3. MURMURE       son secret de lore         → CACHÉ (découvert)│
   └──────────────────────────────────────────────────────────┘
```

### Couche 2 — Le **Commandant**

Un **slot en plus** : tu y places une unité qui devient **invulnérable**, combat lentement, et projette
une **aura sur toute l'équipe**. Mais elle quitte le plateau (elle perd ses synergies de voisinage) — et
si ton équipe meurt, tu perds : le commandant seul ne gagne pas. **Tu choisis donc une *doctrine*.**

Règle d'équilibre élégante : **plus l'aura touche de monde, plus elle est faible** ; un effet énorme ne
vise qu'**une** unité. Exemples :

- **Le Roi des Rats** — *toutes tes unités de bas étage* gagnent +50 % → récompense le jeu « en masse ».
- **L'Aïeul** — *les unités niveau 1* gagnent un gros bonus. Paraît faible… mais **redoutable en fin de
  partie** : tes monstres légendaires, eux, sont presque jamais montés en niveau.
- **La Couronne d'Échos** — l'unité **la plus avancée frappe DEUX fois** (multicast). Mets une
  empoisonneuse devant → elle double tous ses poisons.

> L'astuce : un **bon combattant** n'est pas forcément un **bon commandant**. On draft pour **deux**
> usages à la fois.

### Couche 3 — Les **Murmures** (l'easter egg caché)

Chaque monstre porte un **secret d'affinité** lié à son **lore**, **invisible** au départ. Tu le
**découvres en jouant** : le journal de combat le signale… mais **sans jamais donner le chiffre**, en
restant cryptique. *« Il semblerait que, par la présence du Démon, la Sorcière soit plus venimeuse… »*

C'est du **bonus discret**, jamais un truc à « build autour » — juste de la profondeur pour qui fouille.
Exemples :

- **Le Pacte** — *Sorcière + Démon* côte à côte (elle l'a invoqué) : le contrat les renforce.
- **Le Lâche** — un *voleur* placé tout au fond a une chance d'**esquiver** (il fuit le danger).
- **La Couvée** — le *Kraken* et ses petits *céphalopodes* se reconnaissent et s'enhardissent.

---

## En une carte mentale

```
                        THE PIT
                           │
      ┌────────────┬───────┴───────┬──────────────┐
   PLATEAU       COMBAT          MULTI          MONSTRES
   3×3 +         auto +          fantômes       passif + (à venir)
   sigils        déterministe    async          commandant
   mutables      (placement      (snapshots      + murmure caché
   = synergies    = skill)        + IA)          grimdark cryptique
```

> **En résumé** : la *forme* de ton plateau est ta stratégie · le combat se joue *avant* qu'il commence ·
> tu te mesures au monde entier **sans jamais être en ligne en même temps que lui** · et chaque monstre
> cache **plus qu'il n'en montre**.
