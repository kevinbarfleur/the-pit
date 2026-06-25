-- src/audio/synth.lua
-- SYNTHÈSE de SFX d'UI 100% procédurale (cohérent « zéro asset »). RENDER/cosmétique, JAMAIS dans une sim.
-- Transplanté tel quel du Feel Lab (validé). Pur Lua + love.sound ; aucune dépendance, aucune SIM touchée.
-- APIs vérifiées love2d.org/wiki (11.5) : love.sound.newSoundData(samples,rate,bits,channels) ·
-- SoundData:setSample(i,v) (i débute à 0, v ∈ -1..1) · SoundData:getSample(i) · love.audio.newSource(sd,"static").
-- Headless-safe : si love.sound absent (tests), les fabriques renvoient nil (no-op).
--
-- Ondes : sine/square/saw/tri/noise. Au-delà du « blip » candy, des outils GRIMDARK :
--   detune (beating/épaisseur) · drive (saturation = crasse) · crush (bitcrush = lo-fi) · lp (passe-bas =
--   étouffé/grave) · sub (octave inférieure = corps/poids) · vib (vibrato = malaise) · slide (glissando ;
--   DESCENDANT = menaçant). Plus : squelch() (bruit à cutoff balayé = humide/viscéral) et cavern()
--   (réverb par échos décroissants = le Puits). Un son = une SoundData bakée UNE FOIS (jamais par frame).

local Synth = {}
local RATE = 44100

local function haveSound()
  return love and love.sound and love.sound.newSoundData
end

-- enveloppe linéaire ADSR (t et durées en secondes) -> gain 0..1
local function adsr(time, dur, a, d, s, r)
  if time < a then return time / math.max(1e-6, a)
  elseif time < a + d then return 1 - (1 - s) * ((time - a) / math.max(1e-6, d))
  elseif time < dur - r then return s
  else return s * math.max(0, (dur - time) / math.max(1e-6, r)) end
end

local function wave(kind, ph)
  if kind == "sine"  then return math.sin(2 * math.pi * ph)
  elseif kind == "square" then return (ph % 1) < 0.5 and 1 or -1
  elseif kind == "saw" then return 2 * (ph % 1) - 1
  elseif kind == "tri" then return 2 * math.abs(2 * (ph % 1) - 1) - 1
  else return (love and love.math and love.math.random() or math.random()) * 2 - 1 end -- noise
end

local function clamp1(v) return v < -1 and -1 or v > 1 and 1 or v end

-- saturation douce (drive>1 = plus de crasse). tanh existe en Lua 5.1/LuaJIT.
local function saturate(v, drive)
  if not drive or drive <= 1 then return v end
  return math.tanh(v * drive) / math.tanh(drive)
end

-- Génère une SoundData mono 16-bit. opts :
--   wave, freq, dur, a,d,s,r, vol            (base)
--   slide   : glissando Hz/s (>0 monte, <0 descend = menaçant)
--   detune  : ratio d'un 2e oscillateur (ex. 0.012) -> beating/épaisseur
--   sub     : 0..1 amplitude d'une sine à l'octave inférieure -> corps/poids
--   harm    : 0..1 mélange une octave SUPÉRIEURE -> brillance (0 pour grimdark)
--   drive   : >1 saturation -> crasse
--   crush   : bits (ex. 5) -> bitcrush lo-fi (nil = off)
--   lp      : 0..1 passe-bas one-pole (0 = clair, 0.8 = très étouffé/grave)
--   vib     : profondeur de vibrato en demi-tons ; vibHz : sa fréquence -> malaise
function Synth.tone(opts)
  if not haveSound() then return nil end
  opts = opts or {}
  local kind = opts.wave or "square"
  local dur  = opts.dur or 0.05
  local n    = math.max(1, math.floor(dur * RATE))
  local sd   = love.sound.newSoundData(n, RATE, 16, 1)
  local base, ph, phD, phS = opts.freq or 440, 0, 0, 0
  local vol  = opts.vol or 0.5
  local detune, sub, harm = opts.detune or 0, opts.sub or 0, opts.harm or 0
  local drive, crush, lp = opts.drive, opts.crush, opts.lp or 0
  local vib, vibHz = opts.vib or 0, opts.vibHz or 5
  local A, D, S, R = opts.a or 0.002, opts.d or 0.01, opts.s or 0.5, opts.r or 0.03
  local levels = crush and (2 ^ crush) or nil
  local lpState = 0
  for i = 0, n - 1 do
    local time = i / RATE
    base = base + (opts.slide or 0) / RATE
    if base < 1 then base = 1 end
    local fv = base
    if vib > 0 then fv = base * (2 ^ ((vib / 12) * math.sin(2 * math.pi * vibHz * time))) end
    ph  = ph  + fv / RATE
    phD = phD + (fv * (1 + detune)) / RATE
    phS = phS + (fv * 0.5) / RATE
    local v = wave(kind, ph)
    if detune > 0 then v = v * 0.6 + wave(kind, phD) * 0.4 end
    if harm > 0   then v = v * (1 - harm) + wave(kind, ph * 2) * harm end
    if sub > 0    then v = v + math.sin(2 * math.pi * phS) * sub end
    v = saturate(v, drive)
    if levels then v = math.floor(v * levels + 0.5) / levels end
    if lp > 0 then lpState = lpState + (v - lpState) * (1 - lp); v = lpState end
    sd:setSample(i, clamp1(v * adsr(time, dur, A, D, S, R) * vol))
  end
  return sd
end

-- Bruit filtré, cutoff fixe : clic sec / poussière. opts = { dur, vol, lp, a, r }
function Synth.noiseHit(opts)
  if not haveSound() then return nil end
  opts = opts or {}
  local dur = opts.dur or 0.04
  local n   = math.max(1, math.floor(dur * RATE))
  local sd  = love.sound.newSoundData(n, RATE, 16, 1)
  local vol, lp = opts.vol or 0.4, opts.lp or 0.4
  local A, R, drive = opts.a or 0.001, opts.r or 0.03, opts.drive
  local last = 0
  for i = 0, n - 1 do
    local time = i / RATE
    local raw = (love and love.math and love.math.random() or math.random()) * 2 - 1
    last = last + (raw - last) * (1 - lp)
    sd:setSample(i, clamp1(saturate(last, drive) * adsr(time, dur, A, 0.005, 0.4, R) * vol))
  end
  return sd
end

-- SQUELCH (humide/viscéral) : bruit dont le passe-bas BALAIE (cutoff de `from` -> `to`, coeff lp 0..1).
-- from haut (clair) -> to bas (étouffé) = « blurp » qui se referme ; inverse = « splort » qui s'ouvre.
function Synth.squelch(opts)
  if not haveSound() then return nil end
  opts = opts or {}
  local dur = opts.dur or 0.16
  local n   = math.max(1, math.floor(dur * RATE))
  local sd  = love.sound.newSoundData(n, RATE, 16, 1)
  local vol = opts.vol or 0.3
  local from, to = opts.from or 0.2, opts.to or 0.92
  local A, R, drive = opts.a or 0.004, opts.r or 0.06, opts.drive or 1.4
  local last = 0
  for i = 0, n - 1 do
    local time, prog = i / RATE, i / n
    local cut = from + (to - from) * prog
    local raw = (love and love.math and love.math.random() or math.random()) * 2 - 1
    last = last + (raw - last) * (1 - cut)
    sd:setSample(i, clamp1(saturate(last * 3, drive) * adsr(time, dur, A, 0.01, 0.6, R) * vol))
  end
  return sd
end

-- Accord/arpège (root + intervalles) ; opts.arp = décalage d'attaque (s) ; opts.detune/vib pour le malaise.
function Synth.chord(freqs, opts)
  if not haveSound() then return nil end
  opts = opts or {}
  local dur = opts.dur or 0.32
  local n   = math.max(1, math.floor(dur * RATE))
  local sd  = love.sound.newSoundData(n, RATE, 16, 1)
  local vol = (opts.vol or 0.4) / math.max(1, #freqs)
  local arp, detune, drive = opts.arp or 0, opts.detune or 0, opts.drive
  for i = 0, n - 1 do
    local time = i / RATE
    local v = 0
    for k, f in ipairs(freqs) do
      local onset = (k - 1) * arp
      if time >= onset then
        local env = adsr(time - onset, dur - onset, 0.004, 0.04, 0.6, opts.r or 0.12)
        v = v + math.sin(2 * math.pi * f * (time - onset)) * env
        if detune > 0 then v = v + math.sin(2 * math.pi * f * (1 + detune) * (time - onset)) * env * 0.6 end
      end
    end
    sd:setSample(i, clamp1(saturate(v * vol, drive)))
  end
  return sd
end

-- CAVERN : réverb pauvre par échos décroissants (le Puits). Renvoie une NOUVELLE SoundData plus longue.
-- opts = { delay (s), taps, decay }. À réserver aux moments forts (success/défaite/thud) : c'est plus lourd.
function Synth.cavern(sd, opts)
  if not sd or not haveSound() then return sd end
  opts = opts or {}
  local n = sd:getSampleCount()
  local delaySamp = math.max(1, math.floor((opts.delay or 0.07) * RATE))
  local taps, decay = opts.taps or 3, opts.decay or 0.5
  local extra = delaySamp * taps
  local out = love.sound.newSoundData(n + extra, RATE, 16, 1)
  for i = 0, n - 1 do out:setSample(i, sd:getSample(i)) end
  for k = 1, taps do
    local g, off = decay ^ k, delaySamp * k
    for i = 0, n - 1 do
      local j = i + off
      if j < n + extra then out:setSample(j, clamp1(out:getSample(j) + sd:getSample(i) * g)) end
    end
  end
  return out
end

-- REVERB diffuse (Schroeder/Freeverb : 4 combs amortis en parallèle + 2 allpass en série) = queue ONIRIQUE
-- lisse, pas des échos discrets comme cavern(). opts = { tail (s), mix 0..1, damp 0..1 (queue + sombre),
-- room 0..0.95 (longueur) }. Bakée UNE FOIS au boot (coût par-frame nul). Renvoie une SoundData plus longue.
function Synth.reverb(sd, opts)
  if not sd or not haveSound() then return sd end
  opts = opts or {}
  local n = sd:getSampleCount()
  local total = n + math.max(1, math.floor((opts.tail or 0.5) * RATE))
  local mix, damp, room = opts.mix or 0.35, opts.damp or 0.5, opts.room or 0.72
  local out = love.sound.newSoundData(total, RATE, 16, 1)
  -- délais (samples @44100 ; tunings Freeverb) — lignes de délai en tableaux 1-BASED (array-backed LuaJIT = rapide)
  local cD = { 1116, 1188, 1277, 1356 }
  local cBuf, cPos, cLP = {}, {}, {}
  for c = 1, #cD do local b = {}; for i = 1, cD[c] do b[i] = 0 end; cBuf[c] = b; cPos[c] = 1; cLP[c] = 0 end
  local aD = { 556, 441 }
  local aBuf, aPos = {}, {}
  for c = 1, #aD do local b = {}; for i = 1, aD[c] do b[i] = 0 end; aBuf[c] = b; aPos[c] = 1 end
  local apFB = 0.5
  local nc = #cD
  for i = 0, total - 1 do
    local dry = (i < n) and sd:getSample(i) or 0
    local wet = 0
    for c = 1, nc do
      local buf, p = cBuf[c], cPos[c]
      local y = buf[p]
      local lp = y * (1 - damp) + cLP[c] * damp           -- amortissement (passe-bas dans la boucle)
      cLP[c] = lp
      buf[p] = dry + lp * room
      cPos[c] = p % cD[c] + 1                              -- 1..d, wrap
      wet = wet + y
    end
    wet = wet / nc
    for c = 1, 2 do
      local buf, p = aBuf[c], aPos[c]
      local bv = buf[p]
      local y = -wet * apFB + bv
      buf[p] = wet + bv * apFB
      aPos[c] = p % aD[c] + 1
      wet = y
    end
    out:setSample(i, clamp1(dry * (1 - mix) + wet * mix))
  end
  return out
end

-- fréquence d'un intervalle (demi-tons tempérés) relatif à une base. n<0 = plus grave.
function Synth.semis(base, n) return base * (2 ^ (n / 12)) end

return Synth
