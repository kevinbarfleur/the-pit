-- src/audio/sfx.lua
-- DIRECTEUR DE SON — bake une palette de SFX d'UI procéduraux (src/audio/synth.lua), les joue avec VARIATION DE
-- PITCH (anti-répétition), et câble les hooks Feel.onPress/onHover. RENDER pur ; headless-safe (no-op si pas
-- de device audio). 100% du son passe par les MÊMES NOMS de vocabulaire -> on échange juste le PACK.
-- Transplanté tel quel du Feel Lab (validé par l'user) : SEUL `oneiric` (grave, réverbéré, doux) est le défaut
-- et l'identité du jeu ; les autres packs restent en option (sélecteur éventuel plus tard). Aucune SIM touchée.
--
-- PACKS (mood) :
--   oneiric   — DÉFAUT/identité : onirique GRAVE, sine & cloches douces + reverb, registre bas, zéro agressivité
--   grimdark  — donjon/pierre : mat, grave, descendant, saturé léger
--   visceral  — humide/chair : squelch, gargouillis, succion (body-horror)
--   nightmare — arcane/cauchemar : désaccordé, dissonant, drones, inharmonique
--   candy     — sinus aigus, clairs, ascendants (la réf « trop intense », gardée pour comparaison)
--
-- API : SFX.load() · SFX.play(name,opts) · SFX.ladder(reset) · SFX.setPack(id) · SFX.setEnabled/toggle ·
--       SFX.setMaster(v) · SFX.PACK_LIST · SFX.pack (id courant)

local Synth = require("src.audio.synth")
local Feel  = require("src.ui.feel")

local SFX = { enabled = true, master = 0.50, pack = "oneiric" }

local banks = {}        -- name -> { voices = {Source,...}, idx, jitter, vol }
local POOL = 5
local ladderStep = 0

local function haveAudio() return love and love.audio and love.sound end

local function register(name, sd, opts)
  if not sd or not haveAudio() then return end
  local src = love.audio.newSource(sd, "static")
  local voices = {}
  for i = 1, POOL do voices[i] = src:clone() end
  banks[name] = { voices = voices, idx = 0, jitter = (opts and opts.jitter) or 0.06, vol = (opts and opts.vol) or 1 }
end

-- enregistre l'échelle montante (combo) à partir d'un builder(semi)->SoundData et d'une suite de degrés
local function ladderReg(builder, degrees)
  for k, semi in ipairs(degrees) do register("ladder" .. k, builder(semi), { jitter = 0.01 }) end
end

-- ════════════════════════════════════ PACKS ════════════════════════════════════
local PACKS = {}

-- ── CANDY (la réf « trop intense ») ─────────────────────────────────────────────────────────────────────
function PACKS.candy()
  register("hover",  Synth.tone{ wave = "sine",   freq = 520, dur = 0.030, slide = 260,  vol = 0.16, r = 0.025 }, { jitter = 0.05, vol = 0.5 })
  register("tick",   Synth.tone{ wave = "sine",   freq = 1200, dur = 0.012, vol = 0.12, r = 0.01 },               { jitter = 0.04, vol = 0.5 })
  register("press",  Synth.tone{ wave = "square", freq = 300, dur = 0.040, slide = -200, vol = 0.30, harm = 0.2, r = 0.03 }, { jitter = 0.05 })
  register("click",  Synth.tone{ wave = "square", freq = 360, dur = 0.045, slide = 900,  vol = 0.30, r = 0.03 }, { jitter = 0.06 })
  register("pop",    Synth.tone{ wave = "tri",    freq = 880, dur = 0.085, slide = -1600, vol = 0.34, r = 0.05 }, { jitter = 0.07 })
  register("back",   Synth.tone{ wave = "saw",    freq = 300, dur = 0.070, slide = -900, vol = 0.26, r = 0.04 }, { jitter = 0.05 })
  register("coin",   Synth.tone{ wave = "square", freq = 990, dur = 0.110, slide = 380,  vol = 0.22, harm = 0.3, r = 0.06 }, { jitter = 0.05 })
  register("pickup", Synth.tone{ wave = "tri",    freq = 420, dur = 0.060, slide = 700,  vol = 0.26, r = 0.04 }, { jitter = 0.06 })
  register("drop",   Synth.noiseHit{ dur = 0.06, vol = 0.30, lp = 0.55, r = 0.04 },                              { jitter = 0.05 })
  register("whoosh", Synth.noiseHit{ dur = 0.22, vol = 0.20, lp = 0.30, r = 0.16 },                              { jitter = 0.04 })
  register("error",  Synth.tone{ wave = "saw",    freq = 220, dur = 0.130, slide = -260, vol = 0.30, r = 0.06 }, { jitter = 0.02 })
  register("success", Synth.chord({ Synth.semis(330,0), Synth.semis(330,4), Synth.semis(330,7), Synth.semis(330,12) }, { dur = 0.42, vol = 0.30, arp = 0.05 }), { jitter = 0.01 })
  register("thud",   Synth.noiseHit{ dur = 0.12, vol = 0.40, lp = 0.7, r = 0.09 },                               { jitter = 0.05 })
  register("defeat", Synth.tone{ wave = "saw", freq = 300, dur = 0.40, slide = -260, vol = 0.30, r = 0.22 },     { jitter = 0.02 })
  ladderReg(function(s) return Synth.tone{ wave = "tri", freq = Synth.semis(392, s), dur = 0.10, vol = 0.26, harm = 0.25, r = 0.06 } end,
            { 0, 2, 4, 5, 7, 9, 11, 12 })
end

-- ── ONEIRIC (onirique GRAVE : rêve qui vire au cauchemar ; sine/cloches DOUCES + reverb, registre bas, peu d'aigu) ──
function PACKS.oneiric()
  local function rev(sd, tail, mix) return Synth.reverb(sd, { tail = tail, mix = mix, damp = 0.65, room = 0.72 }) end
  register("hover",  rev(Synth.tone{ wave = "sine", freq = 185, dur = 0.15, a = 0.040, lp = 0.55, detune = 0.006, vol = 0.09, r = 0.09 }, 0.30, 0.27), { jitter = 0.03, vol = 0.6 })
  register("tick",   rev(Synth.tone{ wave = "sine", freq = 270, dur = 0.07, a = 0.020, lp = 0.50, vol = 0.07, r = 0.05 }, 0.20, 0.24), { jitter = 0.02, vol = 0.6 })
  register("press",  rev(Synth.tone{ wave = "tri",  freq = 135, dur = 0.20, a = 0.032, slide = -16, lp = 0.55, detune = 0.008, sub = 0.20, vol = 0.16, r = 0.12 }, 0.36, 0.33), { jitter = 0.03 })
  register("click",  rev(Synth.tone{ wave = "sine", freq = 200, dur = 0.20, a = 0.018, harm = 0.14, sub = 0.18, lp = 0.60, detune = 0.006, vol = 0.16, r = 0.12 }, 0.42, 0.34), { jitter = 0.03 }) -- cloche douce GRAVE
  register("pop",    rev(Synth.tone{ wave = "tri",  freq = 250, dur = 0.22, a = 0.030, slide = -150, lp = 0.55, vol = 0.15, r = 0.12 }, 0.42, 0.34), { jitter = 0.04 })
  register("back",   rev(Synth.tone{ wave = "sine", freq = 185, dur = 0.26, a = 0.045, slide = -90, lp = 0.55, vol = 0.13, r = 0.13 }, 0.46, 0.34), { jitter = 0.03 })
  register("coin",   rev(Synth.tone{ wave = "sine", freq = 320, dur = 0.28, a = 0.012, harm = 0.20, detune = 0.010, lp = 0.62, vol = 0.13, r = 0.13 }, 0.52, 0.36), { jitter = 0.02 }) -- cloche grave
  register("pickup", rev(Synth.tone{ wave = "sine", freq = 220, dur = 0.18, a = 0.030, slide = 110, lp = 0.55, vol = 0.13, r = 0.11 }, 0.42, 0.32), { jitter = 0.03 })
  register("drop",   rev(Synth.tone{ wave = "sine", freq = 165, dur = 0.22, a = 0.032, slide = -70, lp = 0.55, sub = 0.25, vol = 0.16, r = 0.11 }, 0.46, 0.34), { jitter = 0.03 }) -- doux, grave, AUCUN bruit
  register("whoosh", rev(Synth.tone{ wave = "sine", freq = 360, dur = 0.32, a = 0.070, slide = -240, lp = 0.45, vol = 0.10, r = 0.18 }, 0.52, 0.40), { jitter = 0.02 }) -- souffle sine bas (pas de bruit)
  register("error",  rev(Synth.chord({ Synth.semis(150, 0), Synth.semis(150, 1) }, { dur = 0.34, vol = 0.16, detune = 0.012, r = 0.16 }), 0.58, 0.40), { jitter = 0.01 }) -- pad seconde mineure grave (malaise DOUX)
  register("success", rev(Synth.chord({ Synth.semis(160, 0), Synth.semis(160, 4), Synth.semis(160, 7), Synth.semis(160, 11) }, { dur = 0.52, vol = 0.20, arp = 0.09, detune = 0.010, r = 0.22 }), 0.85, 0.45), { jitter = 0.01 }) -- pad maj7 grave, rêveur
  register("thud",   rev(Synth.tone{ wave = "sine", freq = 72, dur = 0.32, a = 0.022, sub = 0.55, lp = 0.62, vol = 0.30, r = 0.22 }, 0.72, 0.42), { jitter = 0.03 }) -- boom grave profond
  register("defeat", rev(Synth.tone{ wave = "sine", freq = 105, dur = 0.52, a = 0.045, slide = -60, sub = 0.55, lp = 0.55, detune = 0.010, vib = 0.2, vibHz = 3, vol = 0.28, r = 0.32 }, 0.95, 0.45), { jitter = 0.02 }) -- la chute, grave et longue
  ladderReg(function(s) return rev(Synth.tone{ wave = "sine", freq = Synth.semis(180, s), dur = 0.20, a = 0.018, harm = 0.18, detune = 0.008, lp = 0.58, sub = 0.12, vol = 0.16, r = 0.12 }, 0.44, 0.34) end,
            { 0, 2, 4, 7, 9, 12, 14, 16 })   -- pentatonique majeure montante = cloches rêveuses GRAVES
end

-- ── GRIMDARK (donjon/pierre : mat, grave, descendant, retenu) ───────────────────────────────────────────
function PACKS.grimdark()
  register("hover",  Synth.tone{ wave = "sine",   freq = 240, dur = 0.032, slide = -90, lp = 0.40, vol = 0.11, a = 0.010, r = 0.025 }, { jitter = 0.05, vol = 0.6 }) -- grave, descendant, attaque adoucie (anti-agressif)
  register("tick",   Synth.tone{ wave = "sine",   freq = 360, dur = 0.014, lp = 0.30, vol = 0.10, r = 0.01 },  { jitter = 0.04, vol = 0.6 })
  register("press",  Synth.tone{ wave = "square", freq = 150, dur = 0.052, slide = -120, drive = 1.6, crush = 5, lp = 0.55, sub = 0.30, vol = 0.30, r = 0.04 }, { jitter = 0.04 })
  register("click",  Synth.tone{ wave = "square", freq = 172, dur = 0.050, slide = -200, drive = 1.5, lp = 0.50, sub = 0.25, vol = 0.28, r = 0.035 }, { jitter = 0.05 })
  register("pop",    Synth.tone{ wave = "tri",    freq = 300, dur = 0.090, slide = -520, drive = 1.4, lp = 0.45, vol = 0.30, r = 0.05 }, { jitter = 0.06 })
  register("back",   Synth.tone{ wave = "saw",    freq = 200, dur = 0.085, slide = -520, drive = 1.5, lp = 0.50, vol = 0.26, r = 0.05 }, { jitter = 0.04 })
  register("coin",   Synth.tone{ wave = "square", freq = 210, dur = 0.110, slide = -120, detune = 0.02, drive = 1.5, lp = 0.40, sub = 0.20, vol = 0.18, r = 0.06 }, { jitter = 0.04 }) -- métal terni, pas un ding clair
  register("pickup", Synth.tone{ wave = "tri",    freq = 260, dur = 0.060, slide = 240, drive = 1.3, lp = 0.40, vol = 0.24, r = 0.04 }, { jitter = 0.05 })
  register("drop",   Synth.noiseHit{ dur = 0.075, vol = 0.32, lp = 0.62, drive = 1.5, r = 0.05 },               { jitter = 0.05 })
  register("whoosh", Synth.noiseHit{ dur = 0.24, vol = 0.16, lp = 0.22, r = 0.18 },                             { jitter = 0.03 })
  register("error",  Synth.tone{ wave = "saw",    freq = 180, dur = 0.160, slide = -160, detune = 0.02, drive = 1.8, lp = 0.50, vol = 0.30, r = 0.07 }, { jitter = 0.02 })
  register("success", Synth.cavern(Synth.chord({ Synth.semis(196,0), Synth.semis(196,3), Synth.semis(196,7), Synth.semis(196,12) }, { dur = 0.40, vol = 0.28, arp = 0.04, detune = 0.008, drive = 1.3 }), { delay = 0.07, taps = 3, decay = 0.45 }), { jitter = 0.01 })
  register("thud",   Synth.cavern(Synth.noiseHit{ dur = 0.12, vol = 0.40, lp = 0.72, drive = 1.6, r = 0.09 }, { delay = 0.06, taps = 2, decay = 0.4 }), { jitter = 0.05 })
  register("defeat", Synth.cavern(Synth.tone{ wave = "saw", freq = 160, dur = 0.50, slide = -200, sub = 0.50, drive = 1.8, lp = 0.50, vib = 0.3, vibHz = 4, vol = 0.32, r = 0.25 }, { delay = 0.09, taps = 4, decay = 0.5 }), { jitter = 0.02 }) -- la chute dans le Puits
  ladderReg(function(s) return Synth.tone{ wave = "tri", freq = Synth.semis(130, s), dur = 0.11, detune = 0.008, drive = 1.3, lp = 0.40, sub = 0.15, vol = 0.24, r = 0.06 } end,
            { 0, 2, 3, 5, 7, 8, 10, 12 })   -- mineur naturel ascendant = tension qui grimpe
end

-- ── VISCERAL (humide/chair : squelch, gargouillis, succion) ─────────────────────────────────────────────
function PACKS.visceral()
  register("hover",  Synth.squelch{ dur = 0.040, from = 0.6, to = 0.92, vol = 0.12, drive = 1.2, a = 0.012 }, { jitter = 0.05, vol = 0.6 })
  register("tick",   Synth.squelch{ dur = 0.022, from = 0.5, to = 0.9, vol = 0.10 },               { jitter = 0.04, vol = 0.6 })
  register("press",  Synth.squelch{ dur = 0.060, from = 0.3, to = 0.9, drive = 1.8, vol = 0.30 },  { jitter = 0.05 })
  register("click",  Synth.squelch{ dur = 0.050, from = 0.45, to = 0.95, drive = 2.0, vol = 0.28 }, { jitter = 0.06 })
  register("pop",    Synth.squelch{ dur = 0.110, from = 0.9, to = 0.2, drive = 1.6, vol = 0.32 },  { jitter = 0.07 }) -- « splort » qui s'ouvre
  register("back",   Synth.tone{ wave = "saw", freq = 160, dur = 0.130, slide = -260, detune = 0.015, vib = 0.3, vibHz = 16, drive = 1.8, lp = 0.50, vol = 0.26, r = 0.06 }, { jitter = 0.03 })
  register("coin",   Synth.squelch{ dur = 0.120, from = 0.5, to = 0.85, drive = 1.5, vol = 0.20 }, { jitter = 0.04 })
  register("pickup", Synth.squelch{ dur = 0.060, from = 0.75, to = 0.4, drive = 1.4, vol = 0.24 }, { jitter = 0.05 }) -- succion
  register("drop",   Synth.squelch{ dur = 0.080, from = 0.3, to = 0.85, drive = 1.6, vol = 0.30 }, { jitter = 0.05 }) -- « slap » humide
  register("whoosh", Synth.squelch{ dur = 0.240, from = 0.8, to = 0.2, vol = 0.18 },               { jitter = 0.03 })
  register("error",  Synth.tone{ wave = "saw", freq = 150, dur = 0.180, slide = -120, detune = 0.025, vib = 0.5, vibHz = 22, drive = 2.2, lp = 0.45, vol = 0.30, r = 0.07 }, { jitter = 0.02 }) -- gargouillis guttural
  register("success", Synth.cavern(Synth.chord({ Synth.semis(174,0), Synth.semis(174,3), Synth.semis(174,7) }, { dur = 0.40, vol = 0.28, arp = 0.05, detune = 0.012, drive = 1.5 }), { delay = 0.08, taps = 3, decay = 0.5 }), { jitter = 0.01 })
  register("thud",   Synth.cavern(Synth.squelch{ dur = 0.140, from = 0.2, to = 0.6, drive = 2.0, vol = 0.42 }, { delay = 0.06, taps = 2, decay = 0.45 }), { jitter = 0.05 }) -- impact charnu
  register("defeat", Synth.cavern(Synth.squelch{ dur = 0.420, from = 0.2, to = 0.7, drive = 2.0, vol = 0.34 }, { delay = 0.08, taps = 3, decay = 0.5 }), { jitter = 0.02 }) -- effondrement humide
  ladderReg(function(s) return Synth.tone{ wave = "tri", freq = Synth.semis(123, s), dur = 0.12, detune = 0.014, vib = 0.2, vibHz = 14, drive = 1.6, lp = 0.45, vol = 0.24, r = 0.06 } end,
            { 0, 2, 3, 5, 7, 8, 10, 12 })
end

-- ── NIGHTMARE (arcane/cauchemar : désaccordé, dissonant, drones, inharmonique) ──────────────────────────
function PACKS.nightmare()
  register("hover",  Synth.tone{ wave = "sine",   freq = 300, dur = 0.042, detune = 0.03, lp = 0.30, vol = 0.11, a = 0.012, r = 0.03 }, { jitter = 0.05, vol = 0.6 }) -- battement d'unease
  register("tick",   Synth.tone{ wave = "sine",   freq = 520, dur = 0.016, detune = 0.03, vol = 0.10, r = 0.012 }, { jitter = 0.04, vol = 0.6 })
  register("press",  Synth.tone{ wave = "tri",    freq = 200, dur = 0.060, slide = -80, detune = 0.04, drive = 1.4, lp = 0.40, vol = 0.28, r = 0.04 }, { jitter = 0.04 })
  register("click",  Synth.tone{ wave = "square", freq = 240, dur = 0.050, slide = -100, detune = 0.05, drive = 1.4, lp = 0.45, vol = 0.26, r = 0.035 }, { jitter = 0.05 })
  register("pop",    Synth.tone{ wave = "tri",    freq = 330, dur = 0.100, slide = -300, detune = 0.06, lp = 0.40, vol = 0.30, r = 0.05 }, { jitter = 0.06 })
  register("back",   Synth.tone{ wave = "saw",    freq = 220, dur = 0.130, slide = -260, detune = 0.04, vib = 0.4, vibHz = 6, lp = 0.50, vol = 0.26, r = 0.06 }, { jitter = 0.03 })
  register("coin",   Synth.tone{ wave = "sine",   freq = 440, dur = 0.120, detune = 0.06, lp = 0.30, vol = 0.18, r = 0.06 }, { jitter = 0.03 }) -- triton/beating eerie
  register("pickup", Synth.tone{ wave = "sine",   freq = 300, dur = 0.070, slide = 180, detune = 0.05, lp = 0.35, vol = 0.22, r = 0.04 }, { jitter = 0.05 })
  register("drop",   Synth.tone{ wave = "tri",    freq = 180, dur = 0.085, slide = -200, detune = 0.06, lp = 0.45, sub = 0.30, vol = 0.28, r = 0.05 }, { jitter = 0.05 })
  register("whoosh", Synth.noiseHit{ dur = 0.260, vol = 0.16, lp = 0.20, r = 0.20 },                            { jitter = 0.03 })
  register("error",  Synth.chord({ Synth.semis(165,0), Synth.semis(165,1), Synth.semis(165,6) }, { dur = 0.220, vol = 0.28, detune = 0.02, drive = 1.6, r = 0.10 }), { jitter = 0.02 }) -- cluster dissonant (seconde min + triton)
  register("success", Synth.cavern(Synth.chord({ Synth.semis(196,0), Synth.semis(196,6), Synth.semis(196,12) }, { dur = 0.44, vol = 0.26, arp = 0.05, detune = 0.012 }), { delay = 0.09, taps = 4, decay = 0.55 }), { jitter = 0.01 }) -- récompense NON résolue (triton+octave)
  register("thud",   Synth.cavern(Synth.tone{ wave = "noise", freq = 60, dur = 0.130, lp = 0.7, sub = 0.4, drive = 1.5, vol = 0.40, r = 0.10 }, { delay = 0.08, taps = 3, decay = 0.5 }), { jitter = 0.05 })
  register("defeat", Synth.cavern(Synth.tone{ wave = "saw", freq = 140, dur = 0.50, slide = -160, detune = 0.04, sub = 0.50, drive = 1.6, lp = 0.50, vib = 0.4, vibHz = 5, vol = 0.30, r = 0.25 }, { delay = 0.10, taps = 4, decay = 0.55 }), { jitter = 0.02 })
  ladderReg(function(s) return Synth.tone{ wave = "tri", freq = Synth.semis(146, s), dur = 0.12, detune = 0.03, lp = 0.40, vol = 0.24, r = 0.06 } end,
            { 0, 2, 4, 6, 8, 10, 12, 14 })   -- gamme PAR TONS (onirique, sans tonique = flottant)
end

-- métadonnées pour l'UI (ordre d'affichage)
SFX.PACK_LIST = {
  { id = "oneiric",   name = "Oneiric",   desc = "Onirique : doux, réverbéré, atmosphérique — sine & cloches, zéro agressivité. (défaut)" },
  { id = "grimdark",  name = "Grimdark",  desc = "Donjon/pierre : mat, grave, descendant, saturé léger." },
  { id = "visceral",  name = "Visceral",  desc = "Humide/chair : squelch, gargouillis, succion. Dégueulasse." },
  { id = "nightmare", name = "Nightmare", desc = "Arcane : désaccordé, dissonant, drones. Cryptique." },
  { id = "candy",     name = "Candy",     desc = "Sinus aigus, clairs, ascendants — la réf « trop intense »." },
}

-- ════════════════════════════════════ Runtime ════════════════════════════════════
local function bake()
  banks = {}
  local p = PACKS[SFX.pack] or PACKS.grimdark
  p()
end

function SFX.load()
  if not haveAudio() then SFX.loaded = true; return end
  bake()
  Feel.onHover = function(_) SFX.play("hover") end
  Feel.onPress = function(_) SFX.play("press") end
  SFX.loaded = true
end

function SFX.setPack(id)
  if not PACKS[id] or id == SFX.pack then SFX.pack = PACKS[id] and id or SFX.pack; return end
  SFX.pack = id
  if haveAudio() then bake() end
end

function SFX.play(name, opts)
  if not SFX.enabled or not haveAudio() then return end
  local b = banks[name]; if not b then return end
  opts = opts or {}
  b.idx = (b.idx % #b.voices) + 1
  local v = b.voices[b.idx]
  v:stop()
  local p = (opts.pitch or 1) + (love.math.random() * 2 - 1) * (opts.jitter or b.jitter)
  if p < 0.05 then p = 0.05 end
  v:setPitch(p)
  v:setVolume(math.max(0, math.min(1, (opts.vol or 1) * b.vol * SFX.master)))
  v:play()
  return v
end

function SFX.ladder(reset)
  if reset then ladderStep = 0 end
  ladderStep = ladderStep + 1
  SFX.play("ladder" .. math.min(8, ladderStep))
end

function SFX.setEnabled(b) SFX.enabled = b and true or false end
function SFX.toggle() SFX.enabled = not SFX.enabled; return SFX.enabled end
function SFX.setMaster(v) SFX.master = math.max(0, math.min(1, v or 0.55)) end

return SFX
