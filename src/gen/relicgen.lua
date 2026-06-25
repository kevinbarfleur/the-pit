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

  -- ═══════════════ VAGUE 5 — reliques d'ÉCONOMIE / BOUTIQUE (append-only) ═══════════════
  -- Foyer commun : l'OR terni (Y/y/T) = la monnaie du Puits (indice « ça touche au butin/à l'éco »),
  -- sur des supports grimdark (cuir p/d, os S/s, fer A/a/I). Chacune garde UN point de focus luisant.

  -- USURER'S LEDGER — report d'or + intérêt (introduit la banque). « Every debt is collected. »
  -- Grimoire-comptable FERMÉ posé sur tranche : couverture de cuir (p/d), tranches de pages dorées
  -- (Y/y), FERMOIR de fer en travers (A/a) à boucle luisante (I = focus), nervures du dos à gauche.
  usurers_ledger = {
    "                ",
    "   KKKKKKKKKK   ",
    "  KdppppppppdK  ",
    "  KdpKIIIIKpdK  ",
    "  KppKaAAaKppK  ",
    "  KdpKaAIaKpdK  ",
    "  KppKaAAaKppK  ",
    "  KdpKKKKKKpdK  ",
    "  KppppppppppK  ",
    "  KdYYYYYYYYdK  ",
    "  KpyYyYyYyYpK  ",
    "  KdYyYyYyYYdK  ",
    "  KpyYyYyYyYpK  ",
    "  KKdYyYyYydKK  ",
    "    KKKKKKKK    ",
    "                ",
  },

  -- TITHE BOWL — or sur victoire (l'offrande au Puits, rendue au mort). « Pay, and you may pass. »
  -- Coupe d'offrande LARGE et BASSE (alms-dish, ≠ le calice haut de kings_bowl) en or terni, emplie
  -- de PIÈCES (y/Y/T), une qui dépasse la lèvre. Anses latérales. Éclat de pièce 'T' au centre = focus.
  tithe_bowl = {
    "                ",
    "                ",
    "        T       ",
    "      KyYYK     ",
    "   K KYYyYK K   ",
    "  KAK KYyYK KAK ",
    "  KaKKKKKKKKKaK ",
    "  KKYyYTYyYyYKK ",
    "   KYyYyYyYyYK  ",
    "   KYTyYyYTyYK  ",
    "    KYyYyYyYK   ",
    "    KKYyYyYKK   ",
    "     KKYYYKK    ",
    "      KKKK      ",
    "                ",
    "                ",
  },

  -- PAUPER'S BOON — petit revenu plat chaque round. « A coin a day, against the dark. »
  -- Bourse de cuir à cordon : col cinché (p/d) noué d'une ficelle (s), panse rebondie de cuir (p)
  -- frappée d'une pièce d'or (Y/T = focus), une pièce qui s'échappe en bas. Couture latérale (d).
  paupers_boon = {
    "                ",
    "      Kss K     ",
    "     KsKKsK     ",
    "    KpKssKpK    ",
    "   KdpKssKpdK   ",
    "   KppKKKKppK   ",
    "  KdppppppppdK  ",
    "  KppKYYYYK pK  ",
    "  KdpKYTTYKpdK  ",
    "  KppKYTTYKppK  ",
    "  KdppKYYKppdK  ",
    "   KdpppppdK    ",
    "    KKdppKK  KyK",
    "      KKK   KYYK",
    "            KyYK",
    "             KK ",
  },

  -- GRAVE-ROBBER'S CUT — la vente rembourse le coût plein (on déterre la valeur). « Dig deeper. »
  -- Bêche de fossoyeur : lame de fer triangulaire (A/a) au TRANCHANT luisant (I = focus), motte de
  -- terre de tombe (d/N) + un éclat d'os (S) collés au fer, manche de bois (p) à poignée-T en haut.
  grave_robbers_cut = {
    "     KKKK       ",
    "     KppK       ",
    "   KKKppKKK     ",
    "   KppppppK     ",
    "    KKppKK      ",
    "     KppK       ",
    "     KppK       ",
    "    NKppKd      ",
    "   KSKppKNK     ",
    "  KIAaIIaAIK    ",
    "  KIAaaaaAIK    ",
    "   KIAaaAIK     ",
    "    KIAAIK      ",
    "     KIIK       ",
    "      KK        ",
    "                ",
  },

  -- BEGGAR'S LANTERN — décale les cotes de boutique d'un cran (la lampe qui cherche en bas). « It seeks the low. »
  -- Lanterne encapuchonnée : capot de fer (A/a) en cône, anneau de suspension (I) au sommet, corps de
  -- verre (b/B) abritant une flamme basse et vacillante (r/Q/T = focus), socle de fer. Cerclages (a).
  beggars_lantern = {
    "       II       ",
    "      KIIK      ",
    "      KaaK      ",
    "     KaAAaK     ",
    "    KaAAAAaK    ",
    "   KaAAAAAAaK   ",
    "   KKaaaaaaKK   ",
    "   KbBbbbbBbK   ",
    "   KBbbrrbbBK   ",
    "   KbBbrQrBbK   ",
    "   KBbrQTQrBK   ",
    "   KbBbrQrBbK   ",
    "   KKaaaaaaKK   ",
    "   KaAAAAAAaK   ",
    "    KKKKKKKK    ",
    "                ",
  },

  -- BLACK SUMMONS — fait monter la boutique d'un tier (la convocation scellée du Puits). « Answer the call. »
  -- Parchemin ROULÉ (os/ivoire S/s) lié en son centre par un SCEAU de cire sang (R/q) frappé d'un sigil
  -- sombre (K), liens de ficelle (d) aux deux bouts. Volutes des rouleaux. Éclat de cire 'q' = focus.
  black_summons = {
    "                ",
    "                ",
    "   KK      KK   ",
    "  KsSKKKKKKSsK  ",
    " KsSssssssssSsK ",
    " KSsssssssssSSK ",
    " KsdSsssssSsdsK ",
    " KSsdKRqRKdsSK  ",
    " KsSdRqqqRdSsK  ",
    " KSsdRqKqRdsSK  ",
    " KsSdKRqRKdSsK  ",
    " KSsssssssssSK  ",
    " KsSssssssssSsK ",
    "  KsSKKKKKKSsK  ",
    "   KK      KK   ",
    "                ",
  },

  -- CARRION LEDGER — bond d'XP de boutique immédiat (le décompte des morts). « Count the fallen. »
  -- BÂTON DE COMPTE en os : long fémur dressé, têtes bombées (S/s) en haut et en bas, fût d'ivoire (S/W)
  -- ENTAILLÉ d'encoches de comptage (K en travers, tirets nets) — chaque cran = un mort. Boucle de cordon
  -- (d) suspendue à la tête haute. La lueur d'ivoire 'W' sur la tête supérieure = focus « os qui luit ».
  carrion_ledger = {
    "      KK        ",
    "     KdddK      ",
    "    KdKKdK      ",
    "    KSWSSK      ",
    "    KSSWSK      ",
    "    KKSSKK      ",
    "    KKSSWK      ",
    "    KSKKSK      ",
    "    KSSWSK      ",
    "    KKSSKK      ",
    "    KSKWSK      ",
    "    KSSSKK      ",
    "    KKSWSK      ",
    "    KSWSSK      ",
    "    KKSSKK      ",
    "     KKKK       ",
  },

  -- ════════════════════════ REFONTE 2026-06 (relics-overhaul §V6) — PLACEHOLDERS ════════════════════════
  -- ⚠️ Les 9 icônes ci-dessous sont des PLACEHOLDERS FONCTIONNELS (16×16 + palette + contour 'K' + 1 focus
  --    lumineux) -> elles passent tests/relics_icons.lua, mais ne sont PAS de l'art fini. À UPGRADER par
  --    asset-forge / pixel-art-master (DA alignée sur les 25 ci-dessus, vrai « objet maudit qui luit »).
  --    Liste à upgrader : blood_banner, seers_mark, carrion_feast, second_plague, tide_caller, bait_lantern,
  --    echo_crown, gravediggers_due, splitting_maw.

  -- BLOOD BANNER (empower team) — bannière de peau cloutée sur une hampe d'OS. La hampe (os S/s à reflet W,
  -- tête fémorale bombée en haut) porte une traverse, dont pend une étoffe de PEAU (sang R/r/D, plis par
  -- bandes de valeur, rivets de fer 'a' alignés au bord supérieur). Pointe de fanion en bas (swallowtail).
  -- Le pli central capte la lumière (q = focus, le « sang qui luit »). Lecture « bannière » immédiate.
  blood_banner = {
    "   KWK          ",
    "   KSSK         ",
    "   KsSKKKKKKKK  ",
    "   KSsaRaRaRaK  ",
    "   KsSRrRDRrRK  ",
    "   KSsrRqRRrDK  ",
    "   KSsDRqRRrRK  ",
    "   KSsrRRqRDrK  ",
    "   KSsRDRRrRRK  ",
    "   KSsrRRrqRDK  ",
    "   KSsDRrRRrK   ",
    "   KSsKRrDRK    ",
    "   KSsKKKrK     ",
    "   KSs  KK      ",
    "   KsK          ",
    "   KK           ",
  },

  -- SEER'S MARK (vuln on_hit) — un ŒIL ouvert au CREUX d'une main, iris fendu. La main (chair P/p/d) se cintre
  -- en coupe sous l'œil, doigts repliés aux deux bords. L'œil : amande de sclère (ivoire S/W), grand iris
  -- arcane (b/B froid) cerclé de sang (R), PUPILLE en FENTE verticale ('K') ; éclat froid 'z' = focus (« il a
  -- vu trop loin »). La paupière haute (R/r) ourle l'amande. Lecture « œil-dans-la-main » immédiate.
  seers_mark = {
    "                ",
    "      KKKK      ",
    "    KKRrrRKK    ",
    "   KRBBBBBBRK   ",
    "  KRBbBzBbBBRK  ",
    " KRBbBBKBzBbBRK ",
    " KRBbBBKBBBbBRK ",
    "  KRBbBBKBBbBRK ",
    "   KRBbBBbBRK   ",
    "    KKRRRRKK    ",
    "   KPpKKKKpPK   ",
    "  KPppPppPppPK  ",
    " KPpdPpPpPdpPK  ",
    " KdppdppppdppdK ",
    "  KKddppppddKK  ",
    "    KKKKKKKK    ",
  },

  -- CARRION FEAST (heal-on-kill) — une GUEULE de chair qui AVALE un crâne. Mâchoire supérieure (chair R/r/D)
  -- hérissée de crocs (ivoire W/S pointant vers le bas), gosier sombre (H), mâchoire inférieure de crocs qui
  -- remontent ; AU CENTRE, un CRÂNE (cranium S/W, deux orbites 'K', dents) à demi englouti. Babines saignantes
  -- (q = focus). « La fosse ne gaspille rien » : on voit la tête disparaître entre les dents.
  carrion_feast = {
    " KKKKKKKKKKKKK  ",
    " KRrDRRqRRDrRK  ",
    " KRDRrRrRrRDRK  ",
    " KWKWKWKWKWKWK  ",
    " HKWKWKWKWKWKH  ",
    " HRKKSWWSKKRH   ",
    " HRKSWKKWSKRH   ",
    " HRKSWWWWSKRH   ",
    " HRKSWKKWSKRH   ",
    " HRKKSWWSKKRH   ",
    " HKWKWKWKWKWKH  ",
    " KWKWKWKWKWKWK  ",
    " KRDrRrqrRrDRK  ",
    " KRrDRRqRRDrRK  ",
    " KKKKKKKKKKKKK  ",
    "                ",
  },

  -- SECOND PLAGUE (grant-if-absent poison) — DEUX plaies suintantes JUMELLES. Chaque plaie = un bourrelet de
  -- chair infectée (vert maladif Z sombre / z clair) enflé autour d'un cœur ouvert et sombre (H) d'où sourd
  -- une bile (z = focus) ; une goutte qui perle sous chacune. La paire (l'une un peu plus basse) = le sens
  -- (« une plaie en appelle une seconde »). Cernes de pus (z) en couronne. Lecture « pustules jumelles ».
  second_plague = {
    "  KKKK          ",
    "  KZzzZK   KKK  ",
    " KZzGgzZK KGGGK ",
    " KzGHHGzK KGzZK ",
    " KZGHHGZKKzGHGK ",
    " KzGgGzZ KGHHGK ",
    "  KZzGzK KzGHGK ",
    "   KzZK  KZGgGK ",
    "   KzK    KzGzK ",
    "    z      KZzK ",
    "           KzK  ",
    "            z   ",
    "                ",
    "                ",
    "                ",
    "                ",
  },

  -- TIDE-CALLER (dmgReduce team) — un VITRAIL BRISÉ taillé en forme d'AILE. Plumes étagées en escalier
  -- (silhouette d'aile montant vers la droite), serties de plombs (cames sombres 'a'/'i') en panneaux de
  -- verre froid (b sombre / B clair / C cyan terni) ; une FÊLURE ('K' en diagonale) fend le vitrail.
  -- Un panneau capte la lumière (W = focus, « le mur se souvient d'avoir été un saint »).
  tide_caller = {
    "          KKK   ",
    "        KKBCBK  ",
    "       KBCWCBaK ",
    "      KBaKbCBaK ",
    "    KKBCaKWCBK  ",
    "   KBCWCaKbBaK  ",
    "  KBaCbBaKBCBK  ",
    " KBaKbCBCaKbBK  ",
    " KbBCaKWCBaKK   ",
    "  KBaCbBaKbBK   ",
    "   KbBCWaKBK    ",
    "    KBaCbBK     ",
    "     KbBaK      ",
    "      KBK       ",
    "       KK       ",
    "                ",
  },

  -- BAIT-LANTERN (lifesteal team) — une LANTERNE abyssale au bout d'un FIL DE CHAIR (l'esca de la baudroie).
  -- Un filament charnu (R/r) descend en serpentant depuis le haut et se renfle en un APPÂT lumineux : globe de
  -- verre (b/B) cerclé de fer (A/a), abritant une braise abyssale (O/Q) à cœur INCANDESCENT (T = focus). Sous
  -- le globe, une dernière goutte de chair-appât (q). « Allume le fanal, et laisse la faim faire le reste. »
  bait_lantern = {
    "    KrK         ",
    "   KRrK         ",
    "    KrRK        ",
    "    KRrK        ",
    "     KrK        ",
    "    KKKKK       ",
    "   KaAAAaK      ",
    "  KbBOQObBK     ",
    "  KBOQTQOBK     ",
    "  KBQTTTQBK     ",
    "  KBOQTQOBK     ",
    "  KbBOQObBK     ",
    "   KaAAAaK      ",
    "    KKKKK       ",
    "     KqK        ",
    "      K         ",
  },

  -- ECHO CROWN (multicast role:front) — un DIADÈME noir à dents REDOUBLÉES. Bandeau de fer sombre (a/A) ;
  -- chaque pointe est DOUBLÉE — une dent pleine (or terni Y) suivie de son ÉCHO décalé (T clair, le reflet
  -- fantôme) — « la couronne se souvient de chaque coup et le redonne ». Sertissures sombres entre les dents,
  -- bandeau bas à rivets. Les éclats d'or 'T' (les échos) = focus. La duplication EST le sens (frappe ×2).
  echo_crown = {
    "                ",
    "  K T K T K T   ",
    "  KYTKYTKYTKT   ",
    " KaYTaYTaYTaYTK ",
    " KaYTaYTaYTaYTK ",
    " KAaYaaYaaYaaAK ",
    " KAaaaaaaaaaaAK ",
    " KAaTaTaTaTaaAK ",
    " KAaaaaaaaaaaAK ",
    " KKAAaAaAaAAAKK ",
    "  KKAAAAAAAAKK  ",
    "    KKKKKKKK    ",
    "                ",
    "                ",
    "                ",
    "                ",
  },

  -- GRAVEDIGGER'S DUE (execute) — une FAUX ébréchée plantée dans un TAS D'OS. Lame d'acier recourbée (fer A à
  -- TRANCHANT vif 'I' = focus), une ENCOCHE ('K' qui mange le fil = « ébréchée »), montée sur un long manche
  -- (bois p/d) ; en bas, un amas de crânes et de fémurs (ivoire S/s/W) où la pointe se fiche. « Sous le quart,
  -- tu es une dette qu'on solde » : l'outil du fossoyeur, posé sur sa récolte.
  gravediggers_due = {
    "          KKKK  ",
    "       KKKIIaaK ",
    "     KKIIIaaaKK ",
    "    KIIaaaKKK   ",
    "   KIaaKKK pK   ",
    "  KIaKK   KpK   ",
    "  KaK     KpK   ",
    "  KK      KpdK  ",
    "          KpdK  ",
    "    KSsK   KpK  ",
    "   KSWWSK KSpsK ",
    "  KSWKWSKKWSWSK ",
    " KsWSWWSWSWKWsK ",
    " KSWKsWSWKsWSWK ",
    " KKSWSsWSWSsWKK ",
    "  KKKKKKKKKKKK  ",
  },

  -- SPLITTING MAW (cleave) — une MÂCHOIRE éclatée en ÉVENTAIL de crocs. Un gosier sombre central (chair R/r/H)
  -- d'où JAILLISSENT des crocs d'ivoire (W/S) RAYONNANT vers l'extérieur en éventail (« une bouche n'a jamais
  -- suffi ; toute la rangée saigne »). Les pointes externes saignent (q = focus). La structure radiale = le
  -- sens du cleave (la frappe éclabousse les voisins). Lecture « bouche qui explose en lames ».
  splitting_maw = {
    "  W  W W  W  W  ",
    "  SK KS SK KS   ",
    " W KS KSK SK W  ",
    " SK KRrRrRK KS  ",
    "K WKRrRHRrRKW K ",
    " S KRrHHHrRK S  ",
    "KWKRrHHqHHrRKWK ",
    " SKRrHHqHHrRKS  ",
    "KWKRrHHHHHrRKWK ",
    " S KRrHqHrRK S  ",
    " SK KRrRrRK KS  ",
    " W KS KSK SK W  ",
    "  SK KS SK KS   ",
    "  W  W W  W  W  ",
    "                ",
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
  -- vague 5 : reliques d'économie / boutique (append-only)
  "usurers_ledger", "tithe_bowl", "paupers_boon", "grave_robbers_cut",
  "beggars_lantern", "black_summons", "carrion_ledger",
  -- refonte 2026-06 (relics-overhaul) — PLACEHOLDERS (append-only). À upgrader par asset-forge.
  "blood_banner", "seers_mark", "carrion_feast", "second_plague", "tide_caller", "bait_lantern",
  "echo_crown", "gravediggers_due", "splitting_maw",
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
