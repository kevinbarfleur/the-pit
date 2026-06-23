-- src/render/postfx.lua
-- SURCOUCHE CAUCHEMARDESQUE — post-fx RENDER-pur appliqué PAR-DESSUS l'UI déjà nette (bible §6).
--
-- Donne la crasse/horreur d'ambiance SANS jamais reflouter le texte. La discipline (chèrement acquise) :
--   1. On rend toute la frame dans un Canvas à la RÉSOLUTION NATIVE (love.graphics.getDimensions()).
--   2. On blit ce canvas 1:1 (scale 1) à travers le shader -> aucun rééchantillonnage -> texte INTACT.
--   3. AUCUN flou plein écran (le flou adoucit le texte ; interdit ici). Effets = per-pixel, text-safe :
--        · DISTORSION ONIRIQUE (★ displacement UV) : on DÉCALE les coordonnées de texture AVANT d'échantillonner
--          (`Texel(tex, uv + offset)`) avec un champ de sinus basses-fréquences qui s'écoulent dans le temps ->
--          la VRAIE bordure (les vrais pixels) ONDULE et tangue, ce n'est PAS une ligne superposée. Amplitude
--          en PIXELS écran, modulée par un MASQUE RADIAL (≈0 au centre où l'on lit, forte vers la périphérie =
--          « on voit flou et ça tangue sur les bords »). Méthode reconnue (EarthBound/Yoshi's Island/heat-haze).
--        · vignette animée (assombrit coins/bords, se resserre à la tension ; centre épargné)
--        · grain de film animé (casse le « trop propre » ; RNG NON-seedé OK car 100% RENDER)
--        · palette-lock doux vers les teintes Wraeclast (tire les ombres/lumières vers braise/abysse —
--          le « même artiste » ; faible -> ne lave pas le texte)
--        · aberration chromatique RADIALE (forte aux bords, ~0 au centre = lisible) bornée à ~1px
--        · dérive chromatique VIOLET/ABYSSE sur la zone distordue (les pixels déformés tirent vers le violet
--          c.rot / un bleu froid) -> la couleur « bizarre » demandée, SANS laver l'image (modulée par le masque)
--        · dither de Bayer 4×4 (gravure 1-bit subtile, cohérente pixel-art)
--        · pulsation de braise globale très lente (l'écran « respire » comme une chair froide)
--   Tout est AGRESSIF sur fond/bords/pics, RETENU au centre/sur le texte (bible §6).
--
-- FIREWALL : 100% RENDER (cosmétique). Ne lit/écrit aucune SIM. L'horloge vient de love.draw (dt mural).
-- HEADLESS-SAFE : sous le mock LÖVE, newShader/newCanvas/setShader sont ABSENTS -> self.available=false ->
--   tous les points d'entrée sont des NO-OP gardés (le jeu et toute la suite de tests tournent sans GPU).
--   Toute création/usage de ressource graphique est pcall-gardé : un asset/feature absent ne crashe jamais.
--
-- Syntaxe GLSL LÖVE (≠ générique, vérifiée sur love2d.org/wiki/Shader_Variables + newShader, cible 11.5) :
--   fonction obligatoire `effect(vec4 color, Image tex, vec2 tc, vec2 sc)` ; `Texel(tex,uv)` (PAS texture2D) ;
--   `extern` (= uniform) ; `number` (= float). GLSL 1.20 (aucune boucle dynamique -> pas de #pragma glsl3).
--   Le motif (shader + canvas créés UNE fois, pcall-gardés) est exactement celui d'affliction_fx.lua, prouvé.

local Theme = require("src.ui.theme")

local PostFX = {}
PostFX.__index = PostFX

-- ★ INSTANCE ACTIVE (hook module-niveau) : les composants d'UI (Panel/Button) n'ont PAS de référence à
-- l'objet PostFX (créé dans main.lua). Ils appellent `PostFX.markBox(...)` (fonction du MODULE) qui forwarde
-- à l'instance courante enregistrée par new(). Découplé (pas de cycle de require) ET inerte sans instance/GPU
-- (markBox module = no-op si aucune instance, ou si l'instance est headless/désactivée). Une seule instance
-- vit à la fois (main.lua) -> un simple champ suffit (pas de pile).
local active = nil

-- Fonction MODULE appelée par les composants d'UI avec leur rect en ESPACE DESIGN. Forwarde à l'instance
-- active (no-op si aucune / headless / désactivée). C'est le point d'entrée léger demandé.
function PostFX.markBox(x, y, w, h)
  if active then active:_markBox(x, y, w, h) end
end

-- ╔═══════════════════════════════════════════════════════════════════════════════════════════════╗
-- ║ LEVIERS DE DISTORSION ONIRIQUE — dose ici en UNE ligne (le user préfère trop fort puis réduire). ║
-- ║ L'intensité globale est `PostFX.distort` (≈0..1, voir new()). Ces constantes en règlent le grain.  ║
-- ║                                                                                                   ║
-- ║ ★ DÉSORMAIS CONFINÉE AUX BORDURES DES BOX D'UI (panels/boutons/cartes) via un MASQUE de bandes.    ║
-- ║   Le FOND, le MONDE et le CENTRE des box (où vit le texte) restent NETS (offset d'UV = 0 hors      ║
-- ║   masque). Seul l'ANNEAU autour du périmètre de chaque box ondule + dérive vers le violet/abysse.  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
local DISTORT = {
  AMP_PX    = 3.5,   -- amplitude MAX du décalage d'UV, en PIXELS écran (dans les bordures ; ×distort). RÉDUITE.
  SPEED     = 0.85,  -- vitesse d'écoulement des ondes (rad/s) : lent = onirique, organique
  SCALE     = 5.5,   -- échelle SPATIALE des ondes (≈ nb de lobes en travers de l'écran) : bas = larges houles
  CHROMA    = 0.45,  -- force de la dérive chromatique violet/abysse sur la zone déformée (0 = aucune)
  -- ── MASQUE DE BANDES-BORDURES (remplace l'ancien masque RADIAL) ──────────────────────────────────
  -- La distorsion ne s'applique QUE dans une bande autour du périmètre de chaque box enregistrée.
  RING_PX   = 11.0,  -- largeur de l'anneau (bande-bordure) en px ÉCRAN. ~8-14 : on doit SENTIR le bord onduler.
  RING_FEATHER = 4.0,-- fondu doux (px écran) vers l'intérieur ET l'extérieur de l'anneau (pas de coupe nette)
}

-- ── Teintes de palette-lock (palette Wraeclast, depuis Theme.c -> floats 0..1) ─────────────────────
-- On tire les OMBRES vers l'abysse/void (violet très sombre) et les HAUTES LUMIÈRES vers la braise
-- (ember chaud). Résultat : l'UI nette importée prend la dominante « même artiste » du Puits.
local SHADOW = Theme.c.void   -- 0x050308 (presque noir, légère teinte violette)
local HILITE = Theme.c.ember  -- 0xc4663a (braise chaude) — pôle chaud du palette-lock

-- ── Teinte « bizarre » de la zone distordue : violet pourriture (c.rot) viré vers un bleu d'abysse froid.
-- Les pixels déformés tirent vers cette dominante -> couleur malsaine SANS laver l'image (faible, masquée).
local DROT  = Theme.c.rot     -- 0xa86fc4 (violet pourriture) — pôle de la dérive chromatique onirique

-- ── GLSL (per-pixel, text-safe ; aucun flou plein écran) ──────────────────────────────────────────
-- `tc` = UV [0..1] (centre 0.5,0.5) ; `sc` = pixel écran (pour grain/dither -> motif à la grille native).
local NIGHTMARE_GLSL = [[
extern number time;        // horloge murale (s) : grain/pulse/respiration/écoulement des ondes
extern number tension;     // 0..1 : 0 = calme, 1 = l'écran se ferme (vignette + dérive)
extern number strength;    // 0..1 : maître d'intensité de TOUTE la surcouche (subtilité par défaut)
extern vec2 screen;        // dimensions natives du canvas (px) — pour ancrer grain/dither à la grille
extern vec3 shadowTint;    // pôle sombre du palette-lock (abysse/void)
extern vec3 hiliteTint;    // pôle chaud du palette-lock (braise)
extern vec3 rotTint;       // pôle de la dérive chromatique onirique (violet pourriture)

// ── DISTORSION ONIRIQUE (displacement) : leviers passés depuis Lua (DISTORT.*) ──────────────────────
extern number dAmp;        // amplitude du décalage d'UV en PIXELS écran (×dStrength) dans les bordures
extern number dSpeed;      // vitesse d'écoulement des ondes (rad/s)
extern number dScale;      // échelle spatiale des ondes (nb de lobes en travers de l'écran)
extern number dChroma;     // force de la dérive chromatique violet/abysse sur la zone déformée
extern number dStrength;   // maître d'intensité de la SEULE distorsion (PostFX.distort)

// ★ MASQUE DE BANDES-BORDURES : canvas natif blanc UNIQUEMENT dans l'anneau autour du périmètre de
// chaque box d'UI (panels/boutons/cartes), noir partout ailleurs (fond/monde/intérieur des box). La
// valeur [0..1] MULTIPLIE l'amplitude du displacement -> distorsion CONFINÉE aux bordures ; hors masque
// (= la quasi-totalité de l'écran, dont le texte au centre des box) l'offset d'UV est NUL -> pixels NETS.
extern Image mask;         // R = appartenance à la bande-bordure (rendu sous le MÊME transform que l'UI)
extern number maskOn;      // 1 = masque valide (distorsion confinée aux bordures) ; 0 = fallback NET (aucune
                           //     distorsion nulle part — si le canvas masque n'a pas pu être créé). Sûr par défaut.

// Hash 2D bon marché et stable (Wraeclast n'a pas besoin de bruit cher) -> grain/dither.
number hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Matrice de Bayer 4×4 (ordre de dither) -> seuil [0..1) par pixel écran. Gravure 1-bit subtile.
number bayer4(vec2 px) {
  int x = int(mod(px.x, 4.0));
  int y = int(mod(px.y, 4.0));
  int i = x + y * 4;
  // table 4x4 normalisée /16 (motif de dispersion standard)
  number b =
      (i==0)?0.0:(i==1)?8.0:(i==2)?2.0:(i==3)?10.0:
      (i==4)?12.0:(i==5)?4.0:(i==6)?14.0:(i==7)?6.0:
      (i==8)?3.0:(i==9)?11.0:(i==10)?1.0:(i==11)?9.0:
      (i==12)?15.0:(i==13)?7.0:(i==14)?13.0:5.0;
  return (b + 0.5) / 16.0;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  // Distance radiale au centre [0..~1] : pilote vignette, aberration ET masque de distorsion (fortes aux
  // bords, ~0 au centre). Corrige l'aspect -> champ régulier, pas étiré.
  vec2 d = tc - vec2(0.5);
  d.x *= screen.x / screen.y;
  number r = length(d) * 1.41421356; // ~1.0 dans les coins

  // ══ DISTORSION ONIRIQUE (★ displacement UV) ════════════════════════════════════════════════════════
  // On calcule un OFFSET d'UV = champ de displacement organique : SOMME de sinus basses fréquences qui
  // S'ÉCOULENT dans le temps (extern time), avec variation 2D (x ET y) -> ondulation lente, non-périodique
  // (fréquences incommensurables -> ne se répète pas à l'œil). On échantillonnera ENSUITE `tc + offset` :
  // ce sont les VRAIS pixels (la vraie bordure) qui ondulent — pas une ligne superposée.
  number tt = time * dSpeed;
  number sx = tc.x * dScale * 6.28318530;   // phase spatiale en X (≈ dScale lobes en travers)
  number sy = tc.y * dScale * 6.28318530;   // phase spatiale en Y
  // Offset X : porté par la coordonnée Y (les colonnes ondulent verticalement -> les bords gauches/droits
  // tanguent) ; 2 sinus à fréquences distinctes (1.0 et 0.53) -> houle composite non-périodique.
  number ox = sin(sy + tt) + 0.5 * sin(sy * 0.53 - tt * 1.31 + sx * 0.21);
  // Offset Y : porté par X (les lignes ondulent horizontalement -> bords haut/bas) ; idem, déphasé.
  number oy = sin(sx * 0.91 - tt * 0.83) + 0.5 * sin(sx * 0.47 + tt * 1.17 + sy * 0.19);

  // ★ MASQUE DE BANDES-BORDURES : on échantillonne le canvas masque à l'UV NON DÉCALÉE (`tc`) — il répond
  // « ce pixel de sortie est-il dans l'anneau d'une box d'UI ? ». 0 = fond/monde/intérieur des box (NET) ;
  // 1 = pleine bande-bordure (ondule). Remplace l'ancien masque RADIAL (qui distordait toute la périphérie).
  number bmask = Texel(mask, tc).r * maskOn;
  // Amplitude finale en UV : pixels -> UV (÷screen), modulée par le MASQUE de bordure, l'intensité distorsion
  // et la tension (les bords tanguent plus quand ça tourne mal). `strength` global la borne aussi.
  number ampUV = dAmp * bmask * dStrength * (0.85 + 0.6 * tension) * strength;
  vec2 disp = vec2(ox / max(screen.x, 1.0), oy / max(screen.y, 1.0)) * ampUV;
  vec2 dtc = tc + disp;   // UV DÉCALÉE : l'échantillonnage qui suit lit les VRAIS pixels déformés (bordures only)

  // ── Aberration chromatique RADIALE : décale R/B le long du rayon, AMPLITUDE ∝ r² (centre intact). ──
  // r² -> quasi nul au centre (texte net) et marqué aux bords. Bornée ≈1px (à la résolution native).
  // Échantillonne autour de `dtc` (= déjà distordu) -> l'aberration suit l'ondulation.
  number ab = (r * r) * strength * (1.6 / max(screen.x, 1.0)) * (1.0 + tension * 1.5);
  vec2 dir = (r > 0.0001) ? (d / (length(d) + 0.0001)) : vec2(0.0);
  vec3 src;
  src.r = Texel(tex, dtc + dir * ab).r;      // canal rouge tiré vers l'extérieur
  src.g = Texel(tex, dtc).g;                  // vert pivot = NETTETÉ préservée (le texte reste piqué)
  src.b = Texel(tex, dtc - dir * ab).b;       // canal bleu tiré vers l'intérieur
  vec3 col = src;

  // ── DÉRIVE CHROMATIQUE violet/abysse sur la ZONE DÉFORMÉE : les pixels qui ondulent tirent vers le violet
  // pourriture (rotTint) -> couleur « bizarre, malsaine ». Force ∝ amplitude locale du displacement -> nulle
  // hors des bandes-bordures (disp=0 quand bmask=0). EN MIX -> teinte sans LAVER (le reste garde ses couleurs).
  number warp = clamp(length(disp) * max(screen.x, screen.y), 0.0, 1.0); // px de déplacement local [0..1+]
  col = mix(col, mix(col, rotTint, 0.5), warp * dChroma * bmask);

  // ── Palette-lock DOUX : tire ombres -> abysse, lumières -> braise (le « même artiste »). ──────────
  // Mélange par luminance, faible (×strength) -> teinte sans laver les couleurs ni écraser le contraste.
  number lum = dot(col, vec3(0.299, 0.587, 0.114));
  vec3 graded = mix(shadowTint, hiliteTint, clamp(lum, 0.0, 1.0));
  col = mix(col, graded, 0.14 * strength);

  // ── Posterize TRÈS doux (réduit la finesse des dégradés -> aspect gravé) — n'affecte pas le texte plein. ─
  number levels = 32.0;
  vec3 post = floor(col * levels + 0.5) / levels;
  col = mix(col, post, 0.25 * strength);

  // ── Dither de Bayer : casse le banding du posterize, ajoute le grain de gravure 1-bit (faible). ────
  number bdith = (bayer4(sc) - 0.5) * (1.0 / 255.0) * 6.0 * strength;
  col += bdith;

  // ── Grain de film ANIMÉ (RNG non-seedé : RENDER pur). Densité montée par la tension. ──────────────
  number g = hash21(sc + vec2(time * 53.0, time * 71.0)) - 0.5;
  col += g * (0.045 + 0.05 * tension) * strength;

  // ── Pulsation de braise GLOBALE très lente : l'écran « respire » (chair froide), + chaud aux bords. ─
  number breath = 0.5 + 0.5 * sin(time * 0.6);
  number ember = breath * (0.02 + 0.05 * r) * strength;   // discret au centre, plus marqué aux bords
  col += hiliteTint * ember * (0.5 + 0.5 * tension);

  // ── Vignette : assombrit coins/bords ; se RESSERRE quand la tension monte (l'écran « se ferme »). ──
  // smoothstep -> jamais sur le centre. À tension 0 : douce ; à tension 1 : oppressante.
  number vstart = mix(0.45, 0.30, tension);
  number vend   = mix(1.15, 0.92, tension);
  number vig = 1.0 - smoothstep(vstart, vend, r) * (0.55 * strength + 0.25 * tension * strength);
  col *= vig;

  // ── Scanline horizontale TRÈS subtile (rétro discret) — amplitude minime, pas un CRT (déforme pas le texte). ─
  number scan = 1.0 - 0.025 * strength * (0.5 + 0.5 * sin(sc.y * 3.14159265));
  col *= scan;

  return vec4(col, 1.0) * color;
}
]]

-- ── Détection de capacité (headless = pas de GPU/shader -> NO-OP propre) ───────────────────────────
local function graphicsReady()
  local g = love and love.graphics
  return g and g.newShader and g.newCanvas and g.setCanvas and g.setShader and g.getDimensions and true or false
end

-- Crée les canvas natifs à la taille (w,h) : le canvas de CAPTURE (toute la frame) ET le canvas MASQUE (bandes-
-- bordures). pcall-gardé : un échec laisse self.canvas=nil -> bypass. Le masque est créé au mieux : s'il échoue,
-- self.mask=nil -> la passe masque se by-passe et le shader reçoit un masque PLEIN (1.0) en fallback (cf. endFrame).
function PostFX:_ensureCanvas(w, h)
  if not self.available then return end
  if self.canvas and self.cw == w and self.ch == h then return end
  local ok, cv = pcall(love.graphics.newCanvas, w, h)
  if ok and cv then
    pcall(cv.setFilter, cv, "nearest", "nearest") -- 1:1, mais nearest = zéro adoucissement si jamais resamplé
    self.canvas, self.cw, self.ch = cv, w, h
  else
    self.canvas = nil -- échec -> on bypass cette frame (et les suivantes tant que la taille ne change pas)
    self.mask = nil
    return
  end
  -- Canvas MASQUE (même taille native). 'linear' EN ÉCHANTILLONNAGE -> le shader lit un masque légèrement lissé
  -- (bords d'anneau plus doux) ; le contenu reste binaire/ramp, pas du texte -> aucun impact sur la netteté.
  local okm, mk = pcall(love.graphics.newCanvas, w, h)
  if okm and mk then
    pcall(mk.setFilter, mk, "linear", "linear")
    self.mask = mk
  else
    self.mask = nil -- pas de masque -> fallback masque plein (1.0) côté shader (distorsion non confinée, mais pas de crash)
  end
end

function PostFX.new()
  local self = setmetatable({
    enabled = true,     -- défaut ON, mais SUBTIL (strength modeste) — la lisibilité prime
    available = false,  -- passe à true si le shader compile (sinon NO-OP partout)
    strength = 0.85,    -- maître d'intensité (subtilité par défaut ; <1 garde l'UI lisible)
    distort = 0.7,      -- ★ maître d'intensité de la DISTORSION onirique (displacement), CONFINÉE aux bordures.
                        --   RÉDUIT (on doit la SENTIR sur les bords sans que ça gondole). Dose en 1 ligne
                        --   (0 = off, 1 = AMP_PX nominal). Inclus au [F9].
    t = 0,              -- horloge murale accumulée (s)
    active = false,     -- vrai entre beginFrame() et endFrame() (canvas engagé cette frame)
    cw = 0, ch = 0,
    boxes = {},         -- ★ COLLECTEUR DE RECTS : box d'UI {x,y,w,h} (espace DESIGN) enregistrées cette frame
    nboxes = 0,         -- nb d'entrées valides dans `boxes` (on RÉUTILISE la table -> zéro churn GC/frame)
    mask = nil,         -- canvas natif du MASQUE de bandes-bordures (créé une fois, redessiné/frame)
  }, PostFX)

  if graphicsReady() then
    local ok, sh = pcall(love.graphics.newShader, NIGHTMARE_GLSL)
    if ok and sh then
      self.shader = sh
      self.available = true
      -- Uniforms constants envoyés une fois (les teintes de palette + les leviers de distorsion ne changent pas).
      pcall(sh.send, sh, "shadowTint", { SHADOW[1], SHADOW[2], SHADOW[3] })
      pcall(sh.send, sh, "hiliteTint", { HILITE[1], HILITE[2], HILITE[3] })
      pcall(sh.send, sh, "rotTint",    { DROT[1],   DROT[2],   DROT[3] })
      pcall(sh.send, sh, "dAmp",     DISTORT.AMP_PX)
      pcall(sh.send, sh, "dSpeed",   DISTORT.SPEED)
      pcall(sh.send, sh, "dScale",   DISTORT.SCALE)
      pcall(sh.send, sh, "dChroma",  DISTORT.CHROMA)
    end
    -- Si newShader échoue (driver/GLSL), self.available reste false -> le jeu rend sans surcouche (pas de crash).
  end
  active = self -- enregistre l'instance courante -> PostFX.markBox (module) la trouve. main n'en crée qu'une.
  return self
end

-- ★ COLLECTEUR DE RECTS (méthode d'INSTANCE) — appelée via le forwarder MODULE `PostFX.markBox` (en tête de
-- fichier) par les composants d'UI (Panel.draw, Button.*) avec LEUR rect en ESPACE DESIGN (celui qu'ils
-- dessinent). Simple push dans une table réutilisée -> INERTE sans GPU (aucune ressource graphique touchée
-- ici). La liste est VIDÉE en début de frame (beginFrame) ; elle est CONSOMMÉE par la passe masque (endFrame,
-- sous le MÊME transform que l'UI) pour que l'anneau de distorsion coïncide pixel-pour-pixel avec la VRAIE
-- bordure de chaque box. Garde-fous : no-op si la surcouche est inactive (rien à masquer) et w/h positifs.
-- (Nom `_markBox` distinct du forwarder module `PostFX.markBox` : sinon l'un écraserait l'autre sur la table.)
function PostFX:_markBox(x, y, w, h)
  if not (self.available and self.enabled) then return end
  if not (w and h) or w <= 0 or h <= 0 then return end
  local n = self.nboxes + 1
  local b = self.boxes[n]
  if b then b[1], b[2], b[3], b[4] = x, y, w, h
  else self.boxes[n] = { x, y, w, h } end
  self.nboxes = n
end

-- Largeur de l'anneau exposée au reste du module (px écran ; lue par la passe masque).
PostFX.RING_PX = DISTORT.RING_PX
PostFX.RING_FEATHER = DISTORT.RING_FEATHER

-- Rend le CANVAS MASQUE (résolution native) : pour chaque box enregistrée, un ANNEAU blanc autour du PÉRIMÈTRE
-- (~RING_PX de large, à fondu doux RING_FEATHER vers l'intérieur ET l'extérieur), noir partout ailleurs. CRITIQUE :
-- on applique le MÊME transform que l'UI (translate ox/oy + scale view.scale/4, cf. Draw.begin) -> l'anneau colle
-- aux vrais pixels de bordure. Le CENTRE des box (texte) reste hors anneau -> non distordu -> NET.
--   L'anneau = DIFFÉRENCE de deux rectangles pleins : on remplit la bande [extérieur..intérieur] en 4 quads
--   (haut/bas/gauche/droite). Le fondu (alpha en rampe) est approximé par 2-3 passes concentriques d'alpha
--   décroissant (cheap, pixel-art-friendly) — pas besoin d'un vrai gradient par-pixel pour une bande de ~11px.
-- HEADLESS-SAFE : tout est pcall-gardé et ne s'exécute QUE si le canvas masque a pu être créé (sinon bypass).
function PostFX:_drawMask(view)
  if not self.mask then return false end
  local ringW = DISTORT.RING_PX
  local feather = DISTORT.RING_FEATHER
  local ox = (view and view.ox) or 0
  local oy = (view and view.oy) or 0
  local s = ((view and view.scale) or 4) / 4
  -- L'épaisseur de l'anneau et le fondu sont définis en px ÉCRAN ; sous le scale `s` du transform, on dessine
  -- en unités DESIGN -> on convertit (÷s) pour que la bande mesure bien ~RING_PX à l'écran quel que soit le zoom.
  local rwD = (s > 0) and (ringW / s) or ringW
  local ftD = (s > 0) and (feather / s) or feather
  local ok = pcall(function()
    love.graphics.setCanvas(self.mask)
    love.graphics.clear(0, 0, 0, 1) -- masque NOIR = aucune distorsion par défaut (fond/monde/intérieur)
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(s, s)
    love.graphics.setColor(1, 1, 1, 1)
    -- 3 passes concentriques : cœur de l'anneau (plein) + 2 fondus (intérieur/extérieur, alpha décroissant).
    -- Chaque passe dessine un anneau via 4 quads (haut/bas/gauche/droite) entre un rect EXTÉRIEUR et un INTÉRIEUR.
    local PASSES = { { off = 0,        w = rwD,           a = 1.0 },   -- cœur plein de la bande
                     { off = -ftD,     w = ftD,           a = 0.5 },   -- fondu vers l'EXTÉRIEUR de la box
                     { off = rwD,      w = ftD,           a = 0.5 } }  -- fondu vers l'INTÉRIEUR de la box
    for i = 1, self.nboxes do
      local b = self.boxes[i]
      local bx, by, bw, bh = b[1], b[2], b[3], b[4]
      for p = 1, #PASSES do
        local pass = PASSES[p]
        love.graphics.setColor(1, 1, 1, pass.a)
        -- Bande [o0..o1] mesurée vers L'INTÉRIEUR depuis le bord de la box (off>0) ou vers l'extérieur (off<0).
        local o0 = pass.off            -- bord de bande le plus proche du périmètre
        local o1 = pass.off + pass.w   -- bord opposé
        local lo = math.min(o0, o1)
        local hi = math.max(o0, o1)
        local t = hi - lo              -- épaisseur de cette passe (unités design)
        if t > 0 then
          -- Anneau = 4 quads peignant le périmètre (jamais le centre plein) entre les insets `lo` et `hi`.
          local x0, y0 = bx + lo, by + lo            -- coin sup-gauche de la bande extérieure de cette passe
          local wMid = bw - 2 * lo                   -- largeur des quads haut/bas
          local hMid = bh - 2 * lo                   -- hauteur des quads gauche/droite
          love.graphics.rectangle("fill", x0, y0, wMid, t)                  -- haut
          love.graphics.rectangle("fill", x0, by + bh - hi, wMid, t)        -- bas
          love.graphics.rectangle("fill", x0, y0, t, hMid)                  -- gauche
          love.graphics.rectangle("fill", bx + bw - hi, y0, t, hMid)        -- droite
        end
      end
    end
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
  end)
  -- On a changé de cible (setCanvas(mask)) : il appartient à l'APPELANT (endFrame) de RE-ENGAGER sa cible
  -- (le canvas de capture) ensuite. On renvoie le succès pour qu'il sache si le masque est exploitable.
  return ok
end

-- TOGGLE [F9] : comparer ON/OFF. No-op si la surcouche n'est pas disponible (headless).
function PostFX:toggle()
  self.enabled = not self.enabled
  return self.enabled
end

-- Canvas ACTIF de la frame (cible de rendu courante) ou nil si la surcouche est inactive. main.lua s'en
-- sert pour RESTAURER la cible après les passes monde (un setCanvas() nu retournerait à l'écran et
-- court-circuiterait la capture). nil hors-fx -> setCanvas(nil) == écran (comportement par défaut intact).
function PostFX:currentCanvas()
  return self.active and self.canvas or nil
end

-- Ouvre la frame : redirige tout le dessin vers le canvas natif. Retourne true si on a bien engagé le
-- canvas (l'appelant fait son dessin normal quoi qu'il arrive ; ce booléen pilote juste endFrame).
-- dt = secondes murales (horloge des effets animés). w,h = dimensions NATIVES (love.graphics.getDimensions()).
function PostFX:beginFrame(dt, w, h)
  self.active = false
  self.nboxes = 0 -- ★ VIDE le collecteur de rects en début de frame (les composants ré-enregistrent au draw)
  if not (self.available and self.enabled) then return false end
  self.t = self.t + (dt or 0)
  self:_ensureCanvas(w, h)
  if not self.canvas then return false end
  local ok = pcall(function()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear(0, 0, 0, 1) -- fond opaque : le shader sort vec4(col,1)
  end)
  if not ok then -- échec d'engagement -> on s'assure de rendre la cible par défaut et on bypass
    pcall(love.graphics.setCanvas)
    return false
  end
  self.active = true
  return true
end

-- Ferme la frame : (1) rend le CANVAS MASQUE des bandes-bordures sous le MÊME transform que l'UI (`view`),
-- (2) décroche le canvas (retour écran), (3) blit la capture 1:1 (scale 1, pos 0,0) à travers le shader, le
-- masque envoyé en `extern Image mask`. 1:1 = ZÉRO rééchantillonnage -> texte INTACT. La distorsion d'UV est
-- multipliée par le masque -> elle n'existe QUE dans l'anneau des box (fond/monde/centre des box = NETS).
--   `view` (main.lua : {scale,ox,oy}) est REQUIS pour que l'anneau coïncide avec les vrais pixels de bordure.
--   tension = 0..1 (optionnel). Si le canvas masque manque (création échouée), maskOn=0 -> fallback NET (aucune
--   distorsion) plutôt que de distordre tout l'écran.
function PostFX:endFrame(view, tension)
  if not self.active then return end
  self.active = false
  local sh = self.shader
  -- (1) Passe MASQUE : redessine l'anneau de chaque box (laisse la cible sur self.mask). maskOK pilote maskOn.
  local maskOK = self:_drawMask(view)
  pcall(function()
    love.graphics.setCanvas() -- (2) retour à l'écran (après la passe masque qui ciblait self.mask)
    love.graphics.setShader(sh)
    sh:send("time", self.t)
    sh:send("tension", math.max(0, math.min(1, tension or 0)))
    sh:send("strength", self.strength)
    sh:send("dStrength", math.max(0, self.distort or 0)) -- ★ maître de la distorsion (≥0), réglable à chaud
    sh:send("screen", { self.cw, self.ch })
    -- Masque : la vraie image si dispo, sinon le canvas de capture en DUMMY (jamais lu car maskOn=0 -> bmask=0).
    sh:send("mask", (maskOK and self.mask) or self.canvas)
    sh:send("maskOn", (maskOK and self.mask) and 1 or 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0) -- (3) blit 1:1, pas de scale -> texte intact
    love.graphics.setShader()
  end)
end

return PostFX
