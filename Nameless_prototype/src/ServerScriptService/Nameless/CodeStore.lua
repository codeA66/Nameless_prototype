-- Server-only code storage. Lives in ServerScriptService, which never replicates.
-- Codes are kept in a private upvalue table keyed by Player. Nothing here is
-- written to Attributes, ValueObjects or any instance.
local CodeStore = {}

local codes = {} -- [Player] = "01234"

function CodeStore.isValid(code)
	return type(code) == "string" and #code == 5 and string.match(code, "^%d%d%d%d%d$") ~= nil
end

function CodeStore.set(player, code)
	if not CodeStore.isValid(code) then return false end
	codes[player] = code
	return true
end

function CodeStore.get(player) return codes[player] end
function CodeStore.has(player) return codes[player] ~= nil end
function CodeStore.clear(player) codes[player] = nil end
function CodeStore.clearAll() table.clear(codes) end

-- Everyone holding this code (duplicates allowed; caller filters to living players)
function CodeStore.holders(code)
	local list = {}
	for p, c in pairs(codes) do
		if c == code then table.insert(list, p) end
	end
	return list
end

-- Random code for players who never submit one
function CodeStore.random()
	return string.format("%05d", math.random(0, 99999))
end

return CodeStore
