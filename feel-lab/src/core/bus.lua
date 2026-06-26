-- src/core/bus.lua
-- Bus d'événements DÉTERMINISTE pour la couche SIM (combat). Tableau ordonné + ipairs :
-- l'ordre de dispatch = l'ordre d'enregistrement, reproductible sur toute machine/version.
--
-- ⚠️ NE PAS remplacer par hump.signal : son emit fait `for f in pairs(...)` = ordre de hash =
-- NON déterministe (https://github.com/vrld/hump/blob/master/signal.lua), ce qui desync les
-- replays seedés et la vérification des snapshots async. (cf. docs/research/engine-architecture.md §6.3)
--
-- Règle : on crée UN bus par combat (dans Arena.new), jamais un global. Aucun appel love.*.

local Bus = {}
Bus.__index = Bus

function Bus.new()
  return setmetatable({ _h = {} }, Bus) -- _h[event] = { fn, fn, ... } (ordre = ordre d'abonnement)
end

-- S'abonner à un événement. `priority` plus haut = appelé plus tôt ; tie-break stable par
-- ordre d'enregistrement (seq) car table.sort N'EST PAS stable (manuel Lua 5.1).
function Bus:on(event, fn, priority)
  local list = self._h[event]
  if not list then list = {}; self._h[event] = list end
  list[#list + 1] = { fn = fn, prio = priority or 0, seq = #list }
  if priority and priority ~= 0 then
    table.sort(list, function(a, b)
      if a.prio ~= b.prio then return a.prio > b.prio end
      return a.seq < b.seq
    end)
  end
  return fn
end

function Bus:off(event, fn)
  local list = self._h[event]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i].fn == fn then table.remove(list, i); break end
  end
end

-- Émettre : itération numérique (jamais pairs), aucun objet créé par emit (perf).
function Bus:emit(event, ...)
  local list = self._h[event]
  if not list then return end
  for i = 1, #list do list[i].fn(...) end
end

return Bus
