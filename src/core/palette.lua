-- src/core/palette.lua
-- Palette procédurale "Wraeclast" : chaque caractère -> couleur RGBA (floats 0..1).
-- Portée depuis le bestiaire PixiJS. On stocke en hex puis on convertit une seule fois.
-- ' ' et tout caractère absent = transparent (la grille laisse le pixel vide).

local HEX = {
  K = 0x05030a, F = 0x110a14,
  I = 0x8a8278, i = 0x44403c, A = 0x6a605a, a = 0x342e36,
  P = 0xa68872, p = 0x6a4c3a, d = 0x301c10,
  R = 0x8a2c20, r = 0x4a1810, H = 0x240808,
  V = 0x4c2a5e, v = 0x281438,
  Y = 0x7e6428, y = 0x3e3010, T = 0xc4a04a,
  L = 0x6c4a2a, l = 0x2c1808, N = 0x4a2c1a, n = 0x1e0e08,
  C = 0x6890a0, c = 0x2c4858,
  X = 0x1c1620, x = 0x0c0810,
  S = 0xa89070, s = 0x60503c,
  B = 0x90a8b8, b = 0x405468,
  D = 0x6a1410,
  O = 0x7a3818, o = 0x3c1808,
  E = 0x6e7c4a, e = 0x383e22,
  G = 0x4a5e30, g = 0x2a3a18,
  M = 0x7a3850, m = 0x3c1828,

  -- ── Extension RELIQUES (artefacts maudits) : 4 teintes de "point de focus lumineux"
  -- manquantes au bestiaire. Désaturées Wraeclast (jamais de primaire pur). Append-only :
  -- caractères neufs -> grilles/créatures existantes inchangées.
  q = 0xc05a44, -- sang VIF (highlight de gemme/goutte ; éclat luisant, pas 0xff0000)
  Q = 0xe08a52, -- BRAISE chaude (cœur de feu ; orange-jaune terni, vivant mais sale)
  z = 0x7a8a34, -- poison clair (résidu/spore maladif, vert-jaune bilieux)
  Z = 0x46562a, -- poison sombre (ombre du vert maladif)
  W = 0xd8cfae, -- lueur SACRÉE / ivoire pâle (halo terni, os blanchi ; chaud, jamais blanc pur)
}

-- Arithmétique pure (pas de bibliothèque bit) -> portable Lua 5.1 / LuaJIT.
local function hex2rgb(hex)
  local r = math.floor(hex / 0x10000) % 0x100
  local g = math.floor(hex / 0x100) % 0x100
  local b = hex % 0x100
  return { r / 255, g / 255, b / 255, 1 }
end

local Palette = {}
for ch, hex in pairs(HEX) do
  Palette[ch] = hex2rgb(hex)
end

return Palette
