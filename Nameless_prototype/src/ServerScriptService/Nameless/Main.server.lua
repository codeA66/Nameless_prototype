-- Nameless :: server entry point / round manager
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Nameless")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local CodeStore = require(script.Parent:WaitForChild("CodeStore"))

local MIN_PLAYERS = RunService:IsStudio() and Config.MinPlayersStudio or Config.MinPlayers

------------------------------------------------------------------
-- Gate: only players standing inside the lobby gate join the next round
------------------------------------------------------------------
local function gateZone()
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	return lobby and lobby:FindFirstChild("QueueZone")
end

local function inGate(p)
	local z = gateZone()
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not (z and hrp and h and h.Health > 0) then return false end
	local rel = z.CFrame:PointToObjectSpace(hrp.Position)
	local s = z.Size / 2
	return math.abs(rel.X) <= s.X and math.abs(rel.Y) <= s.Y and math.abs(rel.Z) <= s.Z
end

local function queued()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if inGate(p) then table.insert(list, p) end
	end
	return list
end

local function updateGateSign(n)
	local map = workspace:FindFirstChild("Map")
	local sign = map and map.Lobby:FindFirstChild("Gate") and map.Lobby.Gate:FindFirstChild("GateSign")
	local label = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Count")
	if label then label.Text = string.format("%d / %d players", n, MIN_PLAYERS) end
end

local State = {
	phase = "Waiting",   -- Waiting | Intermission | CodeEntry | Playing | Ended
	endsAt = 0,
	participants = {},  -- [Player] = true  (in this round)
	alive = {},         -- [Player] = true
}

local function timeLeft()
	return math.max(0, math.floor(State.endsAt - os.clock() + 0.5))
end

local function broadcast(extra)
	local q = queued()
	updateGateSign(#q)
	local inQ = {}
	for _, p in ipairs(q) do inQ[p] = true end
	for _, p in ipairs(Players:GetPlayers()) do
		Remotes.RoundState:FireClient(p, {
			phase = State.phase,
			timeLeft = timeLeft(),
			participant = State.participants[p] == true,
			alive = State.alive[p] == true,
			aliveCount = (function() local n = 0 for _ in pairs(State.alive) do n += 1 end return n end)(),
			inGate = inQ[p] == true,
			gate = #q,
			need = MIN_PLAYERS,
			extra = extra,
		})
	end
end

local function setPhase(phase, duration, extra)
	State.phase = phase
	State.endsAt = os.clock() + (duration or 0)
	broadcast(extra)
end

------------------------------------------------------------------
-- Phase 1: code submission (server-validated, never echoed to others)
------------------------------------------------------------------
local lastSubmit = {}

Remotes.SubmitCode.OnServerInvoke = function(player, code)
	local now = os.clock()
	if lastSubmit[player] and now - lastSubmit[player] < 0.3 then
		return { ok = false, msg = "Too fast." }
	end
	lastSubmit[player] = now

	if State.phase ~= "CodeEntry" or not State.participants[player] then
		return { ok = false, msg = "Codes are sealed right now." }
	end
	if not CodeStore.isValid(code) then
		return { ok = false, msg = "Exactly 5 digits." }
	end
	CodeStore.set(player, code)
	-- Deliberately identical response whether or not the code is shared.
	return { ok = true }
end

Players.PlayerRemoving:Connect(function(player)
	State.participants[player] = nil
	State.alive[player] = nil
	CodeStore.clear(player)
	lastSubmit[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	-- Late joiners become spectators until the next round
	task.defer(broadcast)
end)

------------------------------------------------------------------
-- Round loop
------------------------------------------------------------------
local Hooks = { onRoundStart = {}, onRoundEnd = {}, onTick = {} }

-- Server-only context handed to every system module. Never sent to clients.
local ctx = {
	State = State, Hooks = Hooks, Config = Config, Remotes = Remotes,
	CodeStore = CodeStore, broadcast = broadcast,
}
local systemsFolder = script.Parent:WaitForChild("Systems")
local order = { "Audio", "Identity", "Vision", "Notebook", "Combat", "Zone", "Lifecycle", "StudioBots" }
for _, name in ipairs(order) do
	local m = systemsFolder:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, err = pcall(function() require(m).init(ctx) end)
		if not ok then warn("[Nameless] system failed: " .. name .. " " .. tostring(err)) end
	end
end

local function countAlive()
	local n = 0
	for _ in pairs(State.alive) do n += 1 end
	return n
end

local function runRound()
	-- Intermission
	setPhase("Intermission", Config.IntermissionTime)
	while timeLeft() > 0 do
		if #queued() < MIN_PLAYERS then return end
		task.wait(1); broadcast()
	end

	-- Lock participants: exactly the players standing in the gate right now
	local entrants = queued()
	if #entrants < MIN_PLAYERS then return end
	CodeStore.clearAll()
	table.clear(State.participants); table.clear(State.alive)
	for _, p in ipairs(entrants) do
		State.participants[p] = true
	end

	-- Code entry
	setPhase("CodeEntry", Config.CodeEntryTime)
	while timeLeft() > 0 do
		task.wait(1); broadcast()
		local allIn = true
		for p in pairs(State.participants) do
			if not CodeStore.has(p) then allIn = false break end
		end
		if allIn then break end
	end

	-- Anyone who didn't submit gets a random code, told privately
	for p in pairs(State.participants) do
		if p.Parent then
			if not CodeStore.has(p) then
				local c = CodeStore.random()
				CodeStore.set(p, c)
				Remotes.Feedback:FireClient(p, { kind = "AssignedCode", code = c })
			end
			State.alive[p] = true
			-- each player privately receives ONLY their own code, to draw on their own plate
			Remotes.Feedback:FireClient(p, { kind = "YourCode", code = CodeStore.get(p) })
		end
	end

	-- Playing
	setPhase("Playing", Config.RoundTime)
	for _, fn in ipairs(Hooks.onRoundStart) do task.spawn(fn) end
	while State.phase == "Playing" do
		task.wait(1)
		for _, fn in ipairs(Hooks.onTick) do task.spawn(fn) end
		local n = countAlive()
		if n <= 1 then break end
		if timeLeft() <= 0 then break end
		broadcast()
	end

	local winner
	for p in pairs(State.alive) do winner = p end
	setPhase("Ended", 6, { winner = (countAlive() == 1 and winner) and "A nameless survivor" or nil })
	for _, fn in ipairs(Hooks.onRoundEnd) do task.spawn(fn) end
	task.wait(6)
	CodeStore.clearAll()
	table.clear(State.alive)
end

task.spawn(function()
	while true do
		if #queued() >= MIN_PLAYERS then
			runRound()
		else
			if State.phase ~= "Waiting" then setPhase("Waiting", 0) end
			broadcast()
			task.wait(1)
		end
	end
end)
