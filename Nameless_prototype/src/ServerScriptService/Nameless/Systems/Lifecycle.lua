-- Lifecycle: moves players between the lobby and the arena.
-- (Phase 4 extends this with spectators, AFK and leaver handling.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lifecycle = {}

function Lifecycle.init(ctx)
	local State = ctx.State
	local spawnsFolder = workspace:WaitForChild("Map"):WaitForChild("Spawns")

	local function arenaSpawns()
		local list = spawnsFolder:GetChildren()
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	ctx.arenaOrigin = function() return arenaSpawns()[1].Position end

	------------------------------------------------------------ random drop points
	-- Picks open ground anywhere on the map: not on roofs, not in water / the canal,
	-- not inside walls, hedges or props, and well apart from everyone else.
	local MIN_GAP = 14
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	down.IgnoreWater = false
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	local function randomSpots(n, reserved)
		local ignore = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
		local bots = workspace:FindFirstChild("StudioBots"); if bots then table.insert(ignore, bots) end
		local zw = workspace:FindFirstChild("ZoneWall"); if zw then table.insert(ignore, zw) end
		local zn = workspace:FindFirstChild("ZoneNext"); if zn then table.insert(ignore, zn) end
		down.FilterDescendantsInstances = ignore
		overlap.FilterDescendantsInstances = ignore

		local spots = {}
		for _, r in ipairs(reserved or {}) do table.insert(spots, r) end
		local want = #spots + n
		local tries = 0
		while #spots < want and tries < 4000 do
			tries += 1
			local x = math.random(-70, 70) + math.random()
			local z = math.random(-72, 72) + math.random()
			if z > -45 and z < -31 then continue end -- the canal
			local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), down)
			if not hit or hit.Material == Enum.Material.Water then continue end
			if hit.Position.Y < -0.5 or hit.Position.Y > 1.2 then continue end -- ground only (no roofs/props)
			local feet = hit.Position
			local blockers = workspace:GetPartBoundsInBox(CFrame.new(feet + Vector3.new(0, 3.2, 0)), Vector3.new(4, 5.2, 4), overlap)
			local clear = true
			for _, b in ipairs(blockers) do if b.CanCollide then clear = false break end end
			if not clear then continue end
			local gap = (tries < 2500) and MIN_GAP or MIN_GAP * 0.5 -- relax if the map is crowded
			local ok = true
			for _, s in ipairs(spots) do
				if (Vector3.new(s.X, 0, s.Z) - Vector3.new(feet.X, 0, feet.Z)).Magnitude < gap then ok = false break end
			end
			if ok then table.insert(spots, feet) end
		end
		-- never fail: fall back to the fixed spawn markers
		local fallback = arenaSpawns()
		local k = 0
		while #spots < want do
			k += 1
			table.insert(spots, fallback[((k - 1) % #fallback) + 1].Position)
		end
		return spots
	end

	table.insert(ctx.Hooks.onRoundStart, function()
		local players = {}
		for p in pairs(State.alive) do
			if typeof(p) == "Instance" and p.Character then table.insert(players, p) end
		end
		-- in Studio the first tester stands at Spawn01 so the test bots line up with them
		local reserved = {}
		if RunService:IsStudio() and #players > 0 then
			reserved = { arenaSpawns()[1].Position }
			local bots = workspace:FindFirstChild("StudioBots")
			if bots then
				for _, b in ipairs(bots:GetChildren()) do
					if b:IsA("Model") then table.insert(reserved, b:GetPivot().Position) end
				end
			end
		end
		local spots = randomSpots(#players - (#reserved > 0 and 1 or 0), reserved)
		for i, p in ipairs(players) do
			local pos
			if #reserved > 0 then
				pos = (i == 1) and reserved[1] or spots[#reserved + i - 1]
			else
				pos = spots[i]
			end
			p.Character:PivotTo(CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
		end
	end)
	ctx.randomSpots = randomSpots

	-- everyone returns to the lobby when the night ends
	table.insert(ctx.Hooks.onRoundEnd, function()
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(function() pcall(function() p:LoadCharacter() end) end)
		end
	end)

	------------------------------------------------------------ spectators
	Players.RespawnTime = 3 -- the dead (and late joiners) reappear in the lobby

	-- send the living characters (models only) to everyone who is NOT alive
	local lastSig = {}
	local function pushSpectate(force)
		local list = {}
		if State.phase == "Playing" then
			for p in pairs(State.alive) do
				if p.Character and p.Character.Parent then table.insert(list, p.Character) end
			end
		end
		local sig = tostring(#list)
		for _, c in ipairs(list) do sig ..= "|" .. c.Name end
		for _, pl in ipairs(Players:GetPlayers()) do
			if not State.alive[pl] and (force or lastSig[pl] ~= sig) then
				lastSig[pl] = sig
				ctx.Remotes.Feedback:FireClient(pl, { kind = "Spectate", targets = list })
			end
		end
	end
	ctx.pushSpectate = pushSpectate

	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			pushSpectate(tick % 5 == 0) -- periodic resend heals dropped/nil refs

			-- the dead and late joiners may never walk into the arena
			if State.phase == "Playing" then
				local lobby = workspace.Map.Lobby:FindFirstChild("LobbySpawn")
				for _, pl in ipairs(Players:GetPlayers()) do
					if not State.alive[pl] then
						local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
						local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
						if hrp and hum and hum.Health > 0 and lobby and (hrp.Position - lobby.Position).Magnitude > 45 then
							pl.Character:PivotTo(lobby.CFrame + Vector3.new(0, 4, 0))
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) lastSig[p] = nil end)
end

return Lifecycle
