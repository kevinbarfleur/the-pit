-- src/scenes/bestiary_board.lua
-- PLANCHE-BESTIAIRE complète (revue au SCREENSHOT, --shoot=grimoire_bestiary) : TOUTES les créatures du roster
-- rendues côte à côte, GROUPÉES PAR FAMILLE (les jumeaux potentiels sont donc adjacents → on les repère d'un
-- coup d'œil), à l'échelle ~COMBAT (pas le zoom galerie : on juge la silhouette à la taille où elle est jouée).
-- En queue : une bande RÉSERVE avec les pièces ELDER non mécanisées (sans unité) — rendues depuis leur (famille,
-- forme) directe — pour juger les nouvelles silhouettes imposantes.
--
-- DEV / RENDER pur — montée UNIQUEMENT par la fabrique d'export (jamais en jeu ni en headless). Réutilise le
-- moteur de rendu vivant (Critter, mêmes sprites qu'en combat). Interface scène : update / drawWorld / drawOverlay.

local Background = require("src.fx.background")
local Critter   = require("src.render.critter")
local Primgen   = require("src.gen.primgen")
local Units     = require("src.data.units")
local Draw      = require("src.ui.draw")
local Theme     = require("src.ui.theme")

local BestiaryBoard = {}
BestiaryBoard.__index = BestiaryBoard

-- ELDER imp-10 SANS unité in-game (réserve R5, atteignable ici/bestiaire mais non mécanisée). Affichées en
-- bande dédiée depuis (famille, forme). Les 3 ELDER mécanisées (skulltitan/devourer/voidtyrant) sont déjà
-- dans la grille du roster via leur unité (skull_colossus/pit_maw/marrow_drinker).
local RESERVE = {
  { family = "automate", arch = "juggernaut" },
  { family = "spectre", arch = "veiledking" },
  { family = "arachnide", arch = "broodmother" },
}

local VW, VH = 320, 180

function BestiaryBoard.new(palette, vw, vh, host, opts)
  opts = opts or {}
  local self = setmetatable({
    vw = vw or VW, vh = vh or VH, t = 0, host = host, palette = palette,
    nativeWorld = true, -- sprites primgen rendus en RÉSOLUTION NATIVE (nets)
    bg = Background.new(palette, vw or VW, vh or VH),
    items = {}, reserve = {},
  }, BestiaryBoard)

  -- roster TRIÉ par (famille, rank, id) -> les unités d'une même famille sont CONTIGUËS (repérage des doublons).
  local ids = {}
  for _, id in ipairs(Units.order) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b)
    local ua, ub = Units[a], Units[b]
    local fa, fb = ua.family or "", ub.family or ""
    if fa ~= fb then return fa < fb end
    if (ua.rank or 0) ~= (ub.rank or 0) then return (ua.rank or 0) < (ub.rank or 0) end
    return a < b
  end)
  for _, id in ipairs(ids) do
    self.items[#self.items + 1] = { id = id, family = Units[id].family, arch = Units[id].arch }
  end

  -- pré-bake les sprites RÉSERVE (pas d'unité -> on génère depuis (famille, forme) ; image statique suffit).
  for _, r in ipairs(RESERVE) do
    local ai = Primgen.archIndexOf(r.family, r.arch)
    if ai then
      local ok, gen = pcall(Primgen.generate, { seed = 99, family = r.family, archIndex = ai, paletteIndex = 1 })
      if ok and gen and gen.image then
        self.reserve[#self.reserve + 1] = { img = gen.image, w = gen.w, h = gen.h, arch = r.arch, family = r.family }
      end
    end
  end
  return self
end

-- Grille : COLS colonnes, cellules CW×CH en px virtuels. Le roster fait ~83 -> ~7 rangées. La bande réserve
-- vient sous le roster.
local COLS = 12
local CW, CH = 26, 20
local GX0, GY0 = 3, 13 -- marge gauche / sous le titre

local function cellXY(idx)
  local i = idx - 1
  local c, r = i % COLS, math.floor(i / COLS)
  return GX0 + c * CW + CW * 0.5, GY0 + r * CH + CH - 4 -- centre x / pieds ~bas de case (marge pour label)
end

function BestiaryBoard:update(frameDt)
  self.t = self.t + frameDt
  self.bg:update(frameDt, self.t)
end

function BestiaryBoard:drawWorld()
  self.bg:draw()
  local ts = self.t / 60 -- horloge idle en SECONDES (Critter attend des secondes)
  -- ROSTER (chaque unité au repos, à l'échelle ~combat : on juge la silhouette telle que jouée).
  for i, it in ipairs(self.items) do
    local cx, cy = cellXY(i)
    local scale = (CH - 4) / 64 * 1.4 -- ~hauteur de case (cadre natif 64), léger boost de lisibilité
    Critter.drawAt(nil, it.id, cx, cy, scale, ts, 1, { shadow = true })
  end
  -- BANDE RÉSERVE (ELDER sans unité) : sprites statiques, plus gros (pièces maîtresses), sous le roster.
  local rows = math.ceil(#self.items / COLS)
  local ry = GY0 + rows * CH + 16 -- baseline de la bande réserve
  local rscale = 0.5              -- ×2 entier (WORLD_FIT) : net
  for i, r in ipairs(self.reserve) do
    local cx = 40 + (i - 1) * 90
    -- pivot (32,58) du sprite primgen posé aux pieds (cx, ry).
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(r.img, cx - 32 * rscale, ry - 58 * rscale, 0, rscale, rscale)
  end
end

function BestiaryBoard:drawOverlay(view)
  Draw.begin(view)
  Draw.text("BESTIARY — " .. #self.items .. " units (by family) + " .. #self.reserve .. " ELDER reserve",
    GX0 * 4, 2 * 4, Theme.c.ink, Theme.label(9))
  -- label id sous chaque vignette (zébré famille pour lire les blocs). Petit, sous les pieds.
  local prevFam = nil
  for i, it in ipairs(self.items) do
    local cx, cy = cellXY(i)
    local col = (it.family ~= prevFam) and Theme.c.brass or Theme.c.ink2 -- 1re unité d'une famille = teinte d'accent
    Draw.textC(it.id, cx * 4, (cy + 2) * 4, col, Theme.labelSmall(7))
    prevFam = it.family
  end
  -- labels de la bande réserve.
  local rows = math.ceil(#self.items / COLS)
  local ry = GY0 + rows * CH + 16
  Draw.text("RESERVE (ELDER, no unit)", GX0 * 4, (ry - 30) * 4, Theme.c.brassS, Theme.labelSmall(8))
  for i, r in ipairs(self.reserve) do
    local cx = 40 + (i - 1) * 90
    Draw.textC(r.arch .. " / " .. r.family, cx * 4, (ry + 4) * 4, Theme.c.ink2, Theme.labelSmall(8))
  end
  Draw.finish()
end

return BestiaryBoard
