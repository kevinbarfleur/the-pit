-- src/render/chronicle_overlay.lua
-- LA CHRONIQUE — overlay MODAL, ouvrable n'importe où ([c]) et figeant le jeu derrière. Voile plein écran
-- + SÉLECTEUR DE ROUND (carrousel ‹ ... ›) + le panneau journal (chronicle_draw) pour la chronique choisie.
-- Le host route les inputs ici tant qu'il est ouvert -> aucune interaction ne termine un match.
--
-- ── Kit PROPRE (.dc.html / design-system), aligné sur src/scenes/combat.lua qui OUVRE cet overlay ──────
-- Plus de Forge (kit legacy : boutons-icône bakés, plaque qui respire). La chrome est propre : titre Cinzel
-- gravé (Theme.heading) + filet laiton (Dividers.brass) ; le carrousel et le X = Button.icon / plaque Panel
-- propre + glyphe net ; le label de round en Cinzel (subhead) + l'index en Space Mono (label). Le survol des
-- boutons est lissé par Feel (RENDER pur, headless-safe). RENDER pur ; ne touche jamais la SIM.

local Draw = require("src.ui.draw")
local Theme = require("src.ui.theme")
local Panel = require("src.ui.panel")       -- plaque propre du bouton X (remplace le cadre forge)
local Button = require("src.ui.button")     -- boutons-icône PROPRES (‹ › du carrousel) : remplace Forge.uiButton
local Dividers = require("src.ui.dividers")  -- filet laiton sous le titre (chrome propre)
local Feel = require("src.ui.feel")          -- JUICE : survol lissé des boutons (glow/lift), RENDER pur
local OverlayFx = require("src.ui.overlay")   -- CHORÉGRAPHIE d'entrée unifiée (voile qui monte + groupe back-ease)
local Chronicle = require("src.render.chronicle")
local ChronicleDraw = require("src.render.chronicle_draw")
local MonsterCard = require("src.render.monstercard") -- fiche TCG flottante au survol d'un nom (J4)
local CardGlossary = require("src.ui.card_glossary")
local T = require("src.core.i18n").t
local C = Theme.c

local Overlay = {}
Overlay.__index = Overlay

-- `currentChron` = chronique du combat EN COURS (si on ouvre depuis le combat), sinon nil. `run.chronicles`
-- = l'historique archivé (du plus récent au plus ancien). Le carrousel parcourt [courant] + archives.
function Overlay.new(run, currentChron)
  local sources = {}
  if currentChron then sources[#sources + 1] = { label = T("chronicle.now"), model = currentChron } end
  if run and run.chronicles then
    for i = #run.chronicles, 1, -1 do
      local a = run.chronicles[i]
      local res = a.win and T("chronicle.win") or T("chronicle.loss")
      sources[#sources + 1] = {
        label = T("chronicle.round", { n = a.round or i }) .. "  -  " .. res,
        model = Chronicle.fromEntries(a.entries),
      }
    end
  end
  if #sources == 0 then sources[1] = { label = T("chronicle.empty_hist"), model = Chronicle.fromEntries({}) } end
  return setmetatable({ sources = sources, sel = 1, panel = ChronicleDraw.new(sources[1].model),
    mx = -1, my = -1, t = 0 }, Overlay)
end

local function inR(mx, my, r) return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h end

-- Les inputs arrivent en espace VIRTUEL (main.lua:toVirtual divise par view.scale -> 320×180). Mais TOUTE
-- l'UI de l'overlay (et du panel) est composée en espace DESIGN 1280×720 (= virtuel ×4, la convention de
-- src/ui/draw.lua). On convertit donc ici, à l'unique point d'entrée souris. Le facteur est CONSTANT (×4 :
-- design = VW×4), indépendant de view.scale (qui, lui, mappe écran->virtuel).
local function toDesign(vx, vy) return vx * 4, vy * 4 end

function Overlay:_select(i)
  if i < 1 or i > #self.sources or i == self.sel then return end
  self.sel = i
  self.panel:setChron(self.sources[i].model)
end

-- Bouton X (fermeture) PROPRE : plaque Panel (dégradé + liseré iron) + croix nette par-dessus. Pas de cadre
-- forge ni de roue (le glyphe X dit « fermer » sans ambiguïté). `hot` = survol -> encre vive.
function Overlay:_drawClose(r, hot)
  Panel.draw(r.x, r.y, r.w, r.h, { fill1 = hot and C.stone700 or C.stone800, fill2 = C.stone900, border = C.iron })
  local xc, yc = r.x + r.w / 2, r.y + r.h / 2
  local cl = hot and C.ink or C.ink3
  for d = -4, 4 do
    Draw.rect(xc + d - 0.5, yc + d - 0.5, 2, 2, cl)
    Draw.rect(xc + d - 0.5, yc - d - 0.5, 2, 2, cl)
  end
end

function Overlay:draw(view)
  local c = Theme.c
  self.t = self.t + 1 / 60 -- horloge locale (overlay modal sans boucle update) : respiration de la fiche au survol
  -- ENTRÉE CHORÉGRAPHIÉE (anim 0→1) : cet overlay n'a pas de boucle update (host fige le jeu et appelle draw
  -- directement) -> on avance l'anim ICI, au pas fixe 1/60 s (cohérent avec self.t et Feel.update(1)).
  self._anim = OverlayFx.advance(self._anim, 1 / 60)
  local anim = self._anim
  Feel.update(1)           -- JUICE : avance le survol lissé des boutons (overlay modal -> pas de boucle update)

  -- Survol des boutons (lissé) — résolu avant le draw pour piloter glow/lift via Feel.state.
  Feel.hover("chron.ov.prev", inR(self.mx, self.my, self._prev))
  Feel.hover("chron.ov.next", inR(self.mx, self.my, self._next))
  Feel.hover("chron.ov.close", inR(self.mx, self.my, self._close))

  Draw.begin(view)
  -- VOILE qui MONTE (·anim) : il cache le jeu derrière (figé) mais se POSE au lieu de « poper » (cohérence
  -- avec les autres overlays). 0.93 = opacité cible (chronique = on masque vraiment le combat derrière).
  Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, 0.93 * anim })
  -- ENROBAGE de la CHROME (titre + carrousel + boutons) : back-ease subtil autour du centre écran. Le PANNEAU
  -- journal (scrollable, scissor en px écran) reste HORS de l'enrobage (un scale désynchroniserait son clip) ;
  -- son entrée est portée par le voile qui monte + le fade-up final. À anim=1 -> transform identité.
  OverlayFx.pushContent(Draw.W / 2, Draw.H / 2, anim)
  -- Titre Cinzel gravé (capitales, interlettrage) + hint clavier en Space Mono ; filet laiton dessous.
  Draw.textTrackedL(T("chronicle.title"):upper(), 24, 16, c.ink, Theme.heading(24), 2)
  Draw.textR(T("chronicle.close_hint"), Draw.W - 24 - 26 - 12, 26, c.ink4, Theme.label(11)) -- hint clavier (complément)

  -- Carrousel de round : [‹] label [›]  +  i / n. Label en Cinzel (subhead), index en Space Mono (label).
  local font = Theme.subhead(16)
  local label = self.sources[self.sel].label
  local lw = Draw.textWidth(label, font)
  local cy = 50
  local many = #self.sources > 1
  Draw.textC(label, Draw.W / 2, cy + 2, c.ink, font)
  Draw.textC(string.format("%d / %d", self.sel, #self.sources), Draw.W / 2, cy + 26, c.ink4, Theme.label(11))
  -- rects des boutons (espace design) : flèches de part et d'autre du label, X en haut à droite.
  local BS = 26
  self._prev = { x = math.floor(Draw.W / 2 - lw / 2 - BS - 14), y = cy, w = BS, h = BS }
  self._next = { x = math.floor(Draw.W / 2 + lw / 2 + 14), y = cy, w = BS, h = BS }
  self._close = { x = Draw.W - 24 - BS, y = 16, w = BS, h = BS }
  -- filet laiton sous la chrome (séparation propre, profil triangulaire centré).
  Dividers.brass(Draw.W / 2, 84, 520)

  -- boutons-icône PROPRES (Button.icon : plaque + glyphe net) : flèches seulement si plusieurs rounds.
  if many then
    Button.icon(self._prev.x, self._prev.y, BS, "prev", { hover = inR(self.mx, self.my, self._prev) })
    Button.icon(self._next.x, self._next.y, BS, "next", { hover = inR(self.mx, self.my, self._next) })
  end
  -- bouton X (close) : plaque propre + croix nette (toujours présent).
  self:_drawClose(self._close, inR(self.mx, self.my, self._close))
  OverlayFx.popContent() -- fin de l'enrobage de la chrome (back-ease)
  Draw.finish()

  self.panel:draw(view, 24, 96, Draw.W - 48, Draw.H - 112)

  -- FADE-UP : un wash sombre par-dessus chrome + panneau, alpha = (1-anim)·force, qui s'efface à l'entrée ->
  -- l'overlay « remonte du noir » d'un bloc (chrome ET journal entrent ensemble). À anim=1 -> rien (rendu d'avant).
  if anim < 1 then
    Draw.begin(view)
    Draw.rect(0, 0, Draw.W, Draw.H, { 0.02, 0.012, 0.03, (1 - anim) * 0.6 })
    Draw.finish()
  end

  -- FICHE de monstre au SURVOL d'un nom (J4) : dessinée AU NIVEAU OVERLAY, PAR-DESSUS la liste et HORS de
  -- son clip (la carte déborde volontairement du panneau). Ancrée au curseur (en design), rebond sur les
  -- bords géré par MonsterCard. Sprite FIGÉ (pas de rig animé passé) : une fiche posée, pas vivante.
  local hid = self.panel:hoveredName()
  if hid then
    Draw.begin(view)
    local box = MonsterCard.draw(view, nil, hid, self.mx, self.my, self.t, { keywordHint = true })
    CardGlossary.drawMonster(view, box, hid, self.t)
    Draw.finish()
  end
end

function Overlay:mousemoved(vx, vy)
  self.mx, self.my = toDesign(vx, vy) -- mémorise en DESIGN (cohérent avec les rects de l'overlay/panel)
  self.panel:mousemoved(self.mx, self.my) -- propage : le panel détecte le NOM survolé (carte au survol, J4)
end

-- Renvoie "close" si le X a été cliqué (main.lua referme l'overlay), sinon true (modal : capte tout).
function Overlay:mousepressed(vx, vy)
  local dx, dy = toDesign(vx, vy)
  if inR(dx, dy, self._close) then Feel.press("chron.ov.close"); return "close" end
  if inR(dx, dy, self._prev) then Feel.press("chron.ov.prev"); self:_select(self.sel - 1); return true end
  if inR(dx, dy, self._next) then Feel.press("chron.ov.next"); self:_select(self.sel + 1); return true end
  self.panel:mousepressed(dx, dy)
  return true -- MODAL : capte tout (rien ne fuit vers la scène derrière)
end

function Overlay:wheelmoved(dx, dy) self.panel:wheelmoved(dx, dy) end

function Overlay:keypressed(key)
  if key == "left" then self:_select(self.sel - 1)
  elseif key == "right" then self:_select(self.sel + 1) end
end

return Overlay
