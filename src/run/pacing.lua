-- src/run/pacing.lua
-- Single source of truth for live combat pacing and player-facing cooldown display.
-- Unit data keeps authored base cooldowns; this module applies the live combat profile.

local Pacing = {}

Pacing.FPS = 60

Pacing.profiles = {
  legacy = {
    id = "legacy_hp2_cd1_f17",
    label = "legacy live: hp x2, cooldown x1, fatigue 17s",
    hpMult = 2,
    cooldownMult = 1,
    fatigue = { start = 1020, base = 1, ramp = 0.01 },
  },
  live = {
    id = "live_hp2_cd15_f26",
    label = "live candidate: hp x2, cooldown x1.5, fatigue 26s",
    hpMult = 2,
    cooldownMult = 1.5,
    fatigue = { start = 1560, base = 1, ramp = 0.01 },
  },
}

local function clone(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, vv in pairs(v) do out[k] = clone(vv) end
  return out
end

local function activeProfile()
  local id = os.getenv("PIT_LIVE_PACE")
  if id and id ~= "" and Pacing.profiles[id] then return Pacing.profiles[id] end
  return Pacing.profiles.live
end

function Pacing.profile(profile)
  if type(profile) == "table" then return profile end
  if type(profile) == "string" and Pacing.profiles[profile] then return Pacing.profiles[profile] end
  return activeProfile()
end

function Pacing.scaleCooldown(frames, profile)
  local p = Pacing.profile(profile)
  return math.max(1, math.floor((tonumber(frames) or 1) * (p.cooldownMult or 1) + 0.5))
end

function Pacing.cooldownSeconds(frames, profile)
  return Pacing.scaleCooldown(frames, profile) / Pacing.FPS
end

function Pacing.formatSeconds(seconds)
  seconds = tonumber(seconds) or 0
  if math.abs(seconds - math.floor(seconds + 0.5)) < 0.05 then
    return tostring(math.floor(seconds + 0.5))
  end
  return string.format("%.1f", seconds)
end

function Pacing.formatCooldown(frames, profile)
  return Pacing.formatSeconds(Pacing.cooldownSeconds(frames, profile))
end

function Pacing.arenaOptions(profile)
  local p = Pacing.profile(profile)
  return {
    hpMult = p.hpMult,
    cooldownMult = p.cooldownMult,
    fatigue = clone(p.fatigue),
  }
end

function Pacing.id(profile)
  return Pacing.profile(profile).id
end

return Pacing
