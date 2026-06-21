-- src/gen/relicgen.lua
-- ICÔNES DE RELIQUES (artefacts maudits) — couche DATA/gen, PAS de chemin SIM.
-- Chaque relique = une grille 16×16 (strings + palette) bakée en Image LÖVE filtrée "nearest"
-- via src/core/sprite.lua. On NE dépend PAS de src/data/relics.lua (édité ailleurs) : le mapping
-- vit ici par id-string ; le branchement données/UI se fait côté appelant via cet id.
--
--   Réf API (vérifiée love2d.org/wiki, cible 11.5) :
--     ImageData:setPixel(x,y, r,g,b,a) — coords 0-indexées, couleurs floats 0..1 (cf. sprite.lua).
--     love.graphics.newImage(data) ; Image:setFilter("nearest","nearest").
--   Aucun love.graphics ici : on ne produit/bake qu'à la demande (RelicGen.bake), jamais par frame.
--
-- ── CONVENTION (le « musée de la damnation »), pensée pour PASSER À L'ÉCHELLE ──
--   • Taille : ICON = 16×16. Lisible en petit (slot/infobulle), assez dense pour une silhouette
--     d'objet + contour 1px + 1-2 ombres + 1 highlight. Scale entier ×2/×3/×4 dans le canvas 320×180.
--   • Contour : 'K' (0x05030a), JAMAIS 0x000000. Silhouette flottante centrée, FOND TRANSPARENT
--     (l'UI pose son propre cadre). Cohérence par la LUMIÈRE : chaque relique a UN point de focus
--     lumineux (gemme/braise/résidu/halo) — la signature « objet maudit qui luit faiblement ».
--   • Palette = INDICE mécanique subliminal (cryptique mais lisible) :
--       sang(D/R/q)=dégâts/saignement · poison(Z/z)=poison/pourriture · braise(r/O/Q/T)=brûlure
--       or terni(y/Y/T)=sacré/royal · os(s/S/W)=anti-soin/famine/frénésie · fer(a/A/i/I/b/B)=défense.
--   • Ajouter une relique = +1 entrée { id = { ...16 lignes... } } dans ICONS, rien d'autre.
--
-- Légende des caractères (TOUS ∈ src/core/palette.lua) :
--   K contour · sang D/R/q · feu r/O/Q · or y/Y/T · poison Z/z · os s/S/W · fer a/A/i/I/b/B · rouille o/O
--   (q sang-vif, Q braise-chaude, z poison-clair/Z sombre, W lueur sacrée/ivoire — ajoutés à la palette.)

local Sprite = require("src.core.sprite")

local RelicGen = {}

RelicGen.SIZE = 16 -- toutes les icônes : grille carrée 16×16 (largeur cohérente -> validable).

-- ─────────────────────────── Les icônes (id -> grille 16×16) ───────────────────────────
-- Chaque grille fait EXACTEMENT 16 lignes de 16 colonnes (validé par tests/relics_icons.lua).
local ICONS = {

  -- BLOODSTONE — +dégâts d'attaque. « A heart of compressed murder, still warm. »
  -- Cœur cristallisé : facettes sang, fêlure centrale, éclat vif en haut-gauche (la lumière).
  bloodstone = {
    "                ",
    "     KK  KK     ",
    "    KqqKKqqK    ",
    "   KqqRRRRqRK   ",
    "  KqRRRRRRRRRK  ",
    "  KqRRRDRRRRRK  ",
    "  KRRRRDRRRRRK  ",
    "  KRRRDDDRRRRK  ",
    "   KRRRDRRRRK   ",
    "   KDRRRDRRDK   ",
    "    KDRRDRDK    ",
    "    KKDRDDKK    ",
    "      KDDK      ",
    "       KK       ",
    "                ",
    "                ",
  },

  -- CARAPACE — +PV max. « Shed by something that outgrew its own death. »
  -- Plaque chitineuse muée : dôme bombé, segments, crête centrale, deux pointes latérales.
  carapace = {
    "                ",
    "                ",
    "      KKKK      ",
    "    KKNSSNKK    ",
    "   KNSGNNGNNK   ",
    "  KNSNNGGNNGNK  ",
    " KNSGNGGGGNGNNK ",
    " KNGNGGggGGNGNK ",
    "KNNGGGggggGGGNNK",
    "KNGGNGgnngGGNGGK",
    "KKNGGNGnnGGNGGKK",
    "  KKNGGNNGGNKK  ",
    "    KKNGGNKK    ",
    "      KKKK      ",
    "                ",
    "                ",
  },

  -- WHETSTONE — +vitesse d'attaque. Pierre à aiguiser tachée de sang.
  -- Bloc trapézoïdal de grès, sillon d'affûtage, traînée de sang fraîche sur la face.
  whetstone = {
    "                ",
    "                ",
    "                ",
    "      KKKKKK    ",
    "    KKAAAAAAKK  ",
    "   KAAIIAAAAAAK ",
    "  KAAIIAAAqAAAK ",
    " KAAAAAAAqRqAAAK",
    " KAAAAAAAqRAAAAK",
    " KiAAAAAAARAAAiK",
    "  KiAAAAAARAAiK ",
    "   KiiAAAARiiK  ",
    "     KKiiiiKK   ",
    "        KKK     ",
    "                ",
    "                ",
  },

  -- AEGIS — -dégâts subis. Petit bouclier votif sombre et fêlé.
  -- Heater shield : bordure fer, boss central, FÊLURE diagonale (le « cracked »), rivets.
  aegis = {
    "                ",
    "   KKKKKKKKKK   ",
    "  KBBBBBBBBBBK  ",
    "  KBbbbbbbbbBK  ",
    "  KBbAAAKbbbBK  ",
    "  KBbAAKbbAbBK  ",
    "  KBbAKbbAAbBK  ",
    "  KBbbKbAAAbBK  ",
    "  KBbbbKbAbBK   ",
    "   KBbbbKbbBK   ",
    "   KBbAbbKbBK   ",
    "    KBbbbKBK    ",
    "    KBbbbbBK    ",
    "     KBbbBK     ",
    "      KBBK      ",
    "       KK       ",
  },

  -- THE KINGS' BOWL — +dégâts de poison. « A dozen kings drank deep... »
  -- Calice d'or terni, RÉSIDU vert-noir affleurant le bord, pied lourd. Une goutte qui perle.
  kings_bowl = {
    "                ",
    "  KKKKKKKKKKKK  ",
    "  KYzzzZzZzzYK  ",
    "  KYzZzzzZzzYK  ",
    "  KKYYzZzzYYKK  ",
    "   KYYYZYYYYK   ",
    "   KYyYYYYyYK   ",
    "    KYyYYyYK    ",
    "    KYyYYyYK z  ",
    "     KYyyYK  Z  ",
    "      KYYK      ",
    "      KYYK      ",
    "    KKYYYYKK    ",
    "   KYYYYYYYYK   ",
    "   KKKKKKKKKK   ",
    "                ",
  },

  -- EMBER HEART — +dégâts de burn. « It beats once an hour, and the hour burns. »
  -- Cœur calciné (charbon), fissures incandescentes, braise CHAUDE au centre, étincelle qui s'élève.
  ember_heart = {
    "        T       ",
    "     KK  KK     ",
    "    KrOrrOrK    ",
    "   KrOQOOQOrK   ",
    "  KrOQQOOQQOrK  ",
    "  KrQQQQQQQQrK  ",
    "  KrQTQQQQTQrK  ",
    "  KrOQQTTQQOrK  ",
    "   KrOQQQQOrK   ",
    "   KrrOQQOrrK   ",
    "    KrOQQOrK    ",
    "     KrOOrK     ",
    "      KrOrK     ",
    "       KrK      ",
    "        K       ",
    "                ",
  },

  -- THE WEEPING NAIL — +dégâts de bleed. Clou crochu rouillé qui goutte sans fin.
  -- Tête large martelée, fût rouillé courbé en crochet, pointe, GOUTTE de sang qui tombe.
  weeping_nail = {
    "    KKKKKKKK    ",
    "   KOOOOOOOOK   ",
    "   KOoIIIIoOK   ",
    "   KKOoooOKK    ",
    "     KOOOK      ",
    "     KOoOK      ",
    "      KOoK      ",
    "      KoOK      ",
    "      KOoK      ",
    "     KoOK       ",
    "    KOoK        ",
    "    KoK         ",
    "    KK     q    ",
    "          KqK   ",
    "          qRq   ",
    "           q    ",
  },

  -- GRAVE CAP — +dégâts de rot. Couronne fongique en putréfaction, spores qui s'échappent.
  -- Chapeau de champignon bombé (vert pourri), lamelles sombres, pied charnu, spores en suspension.
  grave_cap = {
    "    z    z      ",
    "      KKKK   z  ",
    "    KKzzzzKK    ",
    "   KzzZzzZzzK z ",
    "  KzZzzZZzzZzK  ",
    " KzzZzZZZZzZzzK ",
    " KzZzZZggZZzZzK ",
    "KKzzZZgssgZZzzKK",
    " KKZZZgssgZZZKK ",
    "   KKZsSSsZKK   ",
    "     KSssSK     ",
    "     KSssSK     ",
    "     KsSSsK     ",
    "     KSssSK     ",
    "    KKsssKK     ",
    "                ",
  },

  -- HOLLOW CHOIR — afflictions percent les soins (anti-sustain). Cloche fêlée qui sonne le creux.
  -- Silhouette de CLOCHE franche : anse/couronne étroite -> épaules -> jupe évasée -> lèvre, bouche
  -- béante (gosier 'H'), battant pendu sous la bouche, FÊLURE diagonale ('K' qui fend le flanc droit).
  hollow_choir = {
    "      KKKK      ",
    "      KWWK      ",
    "      KssK      ",
    "     KKKKKK     ",
    "    KSSSSSsK    ",
    "    KSWSSKsK    ",
    "   KSSSSSKssK   ",
    "   KSSWSSsKsK   ",
    "  KSSSSSSSsKsK  ",
    "  KSSSSSSSssKK  ",
    " KSSWSSSSSsssK  ",
    " KSSSSSSSSSsssK ",
    " KKKKKKKKKKKKKK ",
    "  KHHHKKKHHHK   ",
    "    KsSSsK      ",
    "     KssK       ",
  },

  -- FAMINE'S MATH — peu d'unités frappent plus fort (« tall »). Balance penchée : un os pèse, le vide remonte.
  -- TRAVERSE inclinée franche (bras de fléau qui descend à gauche), montant vertical central, fils visibles,
  -- plateau bas-gauche chargé d'un OS (lourd), plateau haut-droite VIDE (remonte). La pente EST le message.
  famines_math = {
    "      KKKK      ",
    "      KIIK      ",
    "   KKKKIIKKKK   ",
    "   KK KIIK KK   ",
    "  KsK KIIK KaK  ",
    "  KsK KIIK KaK  ",
    " KsK  KIIK  KaK ",
    " KsK  KIIK  KKK ",
    "KsSsK KIIK      ",
    "KSWSK KIIK      ",
    "KsSsK KIIK      ",
    " KKK  KIIK      ",
    "      KIIK      ",
    "    KKKIIKKK    ",
    "   KIIaaaaIIK   ",
    "   KKKKKKKKKK   ",
  },

  -- FEEDING FRENZY — boule de neige à chaque kill. Gueule aux dents trop nombreuses.
  -- Mâchoires béantes, double rangée de crocs d'ivoire imbriqués, gosier sombre, une éclaboussure rouge.
  feeding_frenzy = {
    "                ",
    "  KKKKKKKKKKKK  ",
    " KSSSSSSSSSSSSK ",
    " KWKWKWKWKWKWKK ",
    " KSKSKSKSKSKSKS ",
    " KHHHHHHHHHHHHK ",
    " KHrHHHHHHrHHHK ",
    " KHHHHqHHHHHHHK ",
    " KHHHHHHHHrHHHK ",
    " KSKSKSKSKSKSKS ",
    " KWKWKWKWKWKWKK ",
    " KSSSSSSSSSSSSK ",
    "  KKKKKKKKKKKK  ",
    "                ",
    "                ",
    "                ",
  },

  -- SACRED SHIELD — 0,5 s d'invulnérabilité à l'ouverture. Faux halo / ostensoir vacillant.
  -- OSTENSOIR (soleil-halo) : RAYONS d'or pointant en croix + diagonales depuis un disque central PÂLE
  -- (lueur sacrée 'W' qui vacille). Lecture « sacré » immédiate ; or terni (jamais 0xffd700) = faux/maudit.
  sacred_shield = {
    "       KK       ",
    "   K   KK   K   ",
    "    K  YY  K    ",
    "     KKYYKK     ",
    "  KK KYYYYK KK  ",
    "   KKYWWWWYKK   ",
    "  KYYWWTTWWYYK  ",
    "KKYYWWWTTWWWYYKK",
    "KKYYWWWTTWWWYYKK",
    "  KYYWWTTWWYYK  ",
    "   KKYWWWWYKK   ",
    "  KK KYYYYK KK  ",
    "     KKYYKK     ",
    "    K  YY  K    ",
    "   K   KK   K   ",
    "       KK       ",
  },

  -- ═══════════════ VAGUES 3-4 (append-only) ═══════════════

  -- SECOND BREATH — survit une fois à un coup fatal (reste à 1 PV). « One last grain of air. »
  -- Sablier d'os (S/s) presque vide : ampoule haute VIDÉE, étranglement, ampoule basse où il ne
  -- reste qu'un ULTIME grain de vie (q/R) — le dernier souffle. Lueur sacrée 'W' au verre = focus.
  second_breath = {
    "                ",
    "   KKKKKKKKKK   ",
    "   KSSSSSSSSK   ",
    "   KsWssssssK   ",
    "    KssssssK    ",
    "     KssssK     ",
    "      KssK      ",
    "      KssK      ",
    "      KssK      ",
    "     KssssK     ",
    "    KssssssK    ",
    "   KsssssssK    ",
    "   KsssqRsssK   ",
    "   KSSqRRqSSK   ",
    "   KKKKKKKKKK   ",
    "                ",
  },

  -- THORNGUARD — tes unités renvoient des dégâts quand on les frappe (reflect). « Cruel to hold. »
  -- Collier/cotte d'épines : anneau de fer (A/a + liseré I) hérissé de BARBES pointant vers
  -- l'extérieur, dont les pointes saignent (q/R) — défensif mais cruel. Éclat de fer 'I' = focus.
  thornguard = {
    "   q   qq   q   ",
    "  KqK KqqK KqK  ",
    "   KaKKaaKKaK   ",
    " qK KIIIIII K Kq",
    "KqaKIaaaaaaIKaqK",
    " K KIaAAAAaIK K ",
    "qaKIaAaaaaAaIKaq",
    " KKIaAa  aAaIKK ",
    "qaKIaAa  aAaIKaq",
    " K KIaAAAAaIK K ",
    "KqaKIaaaaaaIKaqK",
    " qK KIIIIII K Kq",
    "   KaKKaaKKaK   ",
    "  KqK KqqK KqK  ",
    "   q   qq   q   ",
    "                ",
  },

  -- FORKED TONGUE — ton choc rebondit sur un 2e ennemi (chain). « It speaks twice. »
  -- Langue de serpent (R/q) sortant en bas, qui se FEND en deux pointes — chacune crachant un
  -- éclair de choc (Q braise-choc + T éclat). La bifurcation EST le message. Éclat 'T' = focus.
  forked_tongue = {
    "  T          T  ",
    "  QK        KQ  ",
    "   TK      KT   ",
    "    QK    KQ    ",
    "    KqK  KqK    ",
    "    KqK  KqK    ",
    "     KqKKqK     ",
    "     KRqqRK     ",
    "      KRRK      ",
    "      KRRK      ",
    "      KRqK      ",
    "      KqRK      ",
    "      KRqK      ",
    "      KqRK      ",
    "      KRRK      ",
    "       KK       ",
  },

  -- EVERBURN — tes feux ne décroissent jamais (no-decay burn). « It refuses the dark. »
  -- Morceau de charbon (r/O/o) à cœur INCANDESCENT (Q braise + T éclat) qui ne s'éteint pas :
  -- bloc irrégulier, fissures de feu qui courent, aucune cendre froide. Éclat 'T' au cœur = focus.
  everburn = {
    "                ",
    "     KKKKK      ",
    "   KKrOOrKK     ",
    "  KrOoQQOrrK    ",
    " KrOoQTTQoOrK   ",
    " KOoQTQQTQoOK   ",
    "KrOQTQOOQTQOrK  ",
    "KrOoQQOOQQoOrK  ",
    "KrOoOQTTQOoOrK  ",
    " KrOoQTTQoOrK   ",
    " KKrOoQQoOrKK   ",
    "  KKrOooOrKK    ",
    "    KKrrOKK     ",
    "     KKrKK      ",
    "      KKK       ",
    "                ",
  },

  -- PLAGUE COMMUNION — un ennemi sous plusieurs afflictions souffre davantage. « Drink of many. »
  -- Calice d'or terni (Y/y) empli d'une bile de venins MÊLÉS (Z sombre + z clair, surface trouble
  -- qui bouillonne) ; deux gouttes de poison débordent. Le mélange = le sens. Résidu 'z' = focus.
  plague_communion = {
    "                ",
    "  KKKKKKKKKKKK  ",
    "  KYzZzzZzZzYK  ",
    "  KYZzzZzzZzYK z",
    "  KYzZzZzZzzYK Z",
    "   KKYzZzzYKK   ",
    "    KYyzZyYK    ",
    "  z KYyYYyYK    ",
    "  Z  KYyYyYK    ",
    "     KYyyYK     ",
    "      KYYK      ",
    "      KYYK      ",
    "    KKYYYYKK    ",
    "   KYYYYYYYYK   ",
    "   KKKKKKKKKK   ",
    "                ",
  },

  -- OPEN WOUNDS — tes saignements ne se referment jamais (no-decay bleed). « It will not knit. »
  -- Une PLAIE maintenue ouverte : entaille verticale, lèvres de chair écartées (r) tenues par des
  -- agrafes de fer (I) qui empêchent la suture, sang vif au fond (D/R/q qui sourd). 'q' = focus.
  open_wounds = {
    "      KK        ",
    "     KrrK       ",
    "    KIrRrIK     ",
    "    KrRDRrK     ",
    "   KIrDqDrIK    ",
    "   KrRDqDRrK    ",
    "   KrDqRqDrK    ",
    "  KIrDqRqDrIK   ",
    "   KrDqRqDrK    ",
    "   KrRDqDRrK    ",
    "   KIrDqDrIK    ",
    "    KrRDRrK     ",
    "    KIrRrIK     ",
    "     KrrK       ",
    "      KK        ",
    "                ",
  },
}

-- ─────────────────────────── API ───────────────────────────
RelicGen.ICONS = ICONS

-- Liste ordonnée des ids fournis (pour itérer en aperçu / préchauffage). Append-only.
RelicGen.order = {
  "bloodstone", "carapace", "whetstone", "aegis",
  "kings_bowl", "ember_heart", "weeping_nail", "grave_cap",
  "hollow_choir", "famines_math", "feeding_frenzy", "sacred_shield",
  -- vagues 3-4 (append-only)
  "second_breath", "thornguard", "forked_tongue", "everburn",
  "plague_communion", "open_wounds",
}

-- Grille brute d'une relique (ou nil si id inconnu). DATA pure (aucun love.*).
function RelicGen.grid(id)
  return ICONS[id]
end

-- Bake -> { image, w, h } via Sprite.bake (contexte gen/render). Nil si id inconnu.
-- À appeler une fois (chargement/galerie), JAMAIS par frame (cf. sprite.lua).
function RelicGen.bake(id, palette)
  local g = ICONS[id]
  if not g then return nil end
  return Sprite.bake(g, palette)
end

-- Cache module-level (mémoïsation par id) : une icône bakée une fois, réutilisée par tous les appelants.
local CACHE = {}
function RelicGen.cached(id, palette)
  local got = CACHE[id]
  if not got then
    got = RelicGen.bake(id, palette)
    CACHE[id] = got
  end
  return got
end

return RelicGen
