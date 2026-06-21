-- tools/gamed/json.lua
-- Encodeur JSON minimal (ENCODE seulement) pour le daemon de jeu. Pas de décodage : le protocole
-- d'ENTRÉE est en lignes « commande arg1 arg2 » (parse trivial) ; seules les RÉPONSES sont en JSON.
-- Déterministe : les clés d'objet sont triées -> sortie diff-able. Pur Lua 5.1 / LuaJIT.

local json = {}

local ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t', ['\b'] = '\\b', ['\f'] = '\\f' }
local function encStr(s)
  return '"' .. (s:gsub('[%z\1-\31\\"]', function(ch)
    return ESC[ch] or string.format('\\u%04x', string.byte(ch))
  end)) .. '"'
end

local function encNum(v)
  if v ~= v or v == math.huge or v == -math.huge then return "null" end -- NaN/Inf -> null (JSON valide)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

local encVal
-- Tableau « dense » (clés 1..#t contiguës) -> array JSON ; sinon -> object (clés triées).
local function isArray(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

encVal = function(v, out)
  local ty = type(v)
  if v == nil then out[#out + 1] = "null"
  elseif ty == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif ty == "number" then out[#out + 1] = encNum(v)
  elseif ty == "string" then out[#out + 1] = encStr(v)
  elseif ty == "table" then
    if isArray(v) then
      out[#out + 1] = "["
      for i = 1, #v do if i > 1 then out[#out + 1] = "," end; encVal(v[i], out) end
      out[#out + 1] = "]"
    else
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      out[#out + 1] = "{"
      for i, k in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        out[#out + 1] = encStr(tostring(k)); out[#out + 1] = ":"; encVal(v[k], out)
      end
      out[#out + 1] = "}"
    end
  else
    out[#out + 1] = "null"
  end
end

function json.encode(v)
  local out = {}
  encVal(v, out)
  return table.concat(out)
end

return json
