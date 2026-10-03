-- Vision: server-authoritative plate reading.
-- For each (viewer, target) pair at Config.VisionHz the server checks:
--   1. distance from viewer's eyes to target plate <= ReadDistance
--   2. viewer is inside the cone in FRONT of the plate (no reading from behind)
--   3. viewer is looking toward the plate (camera dir reported by client, sanitized)
--   4. an unobstructed raycast from eyes to plate
-- Only qualifying viewers are sent that one code; it is revoked the moment they stop qualifying.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Vision = {}

function Vision.init(ctx)
	local Config, R, State, CodeStore = ctx.Config, ctx.Remotes, ctx.State, ctx.CodeStore
	local cosT = math.cos(math.rad(Config.ReadHalfAngleTarget))
	local cosV = math.cos(math.rad(Config.ReadHalfAngleViewer))
	local maxD = Config.ReadDistance
	local ALWAYS = Config.AlwaysShowPlates == true
	local shown = {} -- AlwaysShow mode: [target] = plate already broadcast
	local firstSeen = {} -- [plate] = os.clock() when the plate first appeared
	local lastResync = 0

	local function syncAlways()
		local now = os.clock()
		for target in pairs(State.alive) do
			local plate = ctx.plates and ctx.plates[target]
			local code = CodeStore.get(target)
			if plate and plate.Parent and code and shown[target] ~= plate then
				firstSeen[plate] = firstSeen[plate] or now
				-- give the new character time to replicate, otherwise clients receive nil
				if now - firstSeen[plate] >= 1 then
					shown[target] = plate
					R.PlateVision:FireAllClients({ plate = plate, code = code })
				end
			end
		end
		for target, plate in pairs(shown) do
			if not State.alive[target] then
				shown[target] = nil
				firstSeen[plate] = nil
				R.PlateVision:FireAllClients({ plate = plate, code = false })
			end
		end
		-- periodic resync: cheap (<= 20 entries) and heals any dropped message
		if now - lastResync >= 3 then
			lastResync = now
			for target, plate in pairs(shown) do
				local code = CodeStore.get(target)
				if code and plate.Parent then R.PlateVision:FireAllClients({ plate = plate, code = code }) end
			end
		end
	end

	-- late joiners / respawned clients get the current set
	Players.PlayerAdded:Connect(function(p)
		task.wait(2)
		if not ALWAYS then return end
		for target, plate in pairs(shown) do
			local code = CodeStore.get(target)
			if code then R.PlateVision:FireClient(p, { plate = plate, code = code }) end
		end
	end)

	local look = {}     -- [Player] = Vector3 (unit)
	local seen = {}     -- [viewer] = { [target] = plate }
	local readers = {}  -- [target] = number of current readers (for heartbeat feedback)

	R.Look.OnServerEvent:Connect(function(p, v)
		if typeof(v) ~= "Vector3" then return end
		local m = v.Magnitude
		if m ~= m or m < 0.5 or m > 1.5 then return end -- NaN / garbage guard
		look[p] = v / m
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local function revoke(viewer, target)
		local row = seen[viewer]
		if not row or row[target] == nil then return end
		local plate = row[target]
		row[target] = nil
		if viewer.Parent and not ALWAYS then R.PlateVision:FireClient(viewer, { plate = plate, code = false }) end
	end

	local function revokeAll(viewer)
		local row = seen[viewer]
		if not row then return end
		for t in pairs(row) do revoke(viewer, t) end
	end

	local function revokeTarget(target)
		for v in pairs(seen) do revoke(v, target) end
	end

	ctx.revokeVisionTarget = revokeTarget
	ctx.revokeVisionViewer = revokeAll

	local function qualifies(viewer, target)
		local vc, tc = viewer.Character, target.Character
		if not (vc and tc) then return false end
		local head = vc:FindFirstChild("Head")
		local plate = ctx.plates and ctx.plates[target]
		if not (head and plate and plate.Parent == tc) then return false end

		local eye = head.Position
		local toEye = eye - plate.Position
		local d = toEye.Magnitude
		if d > maxD or d < 0.3 then return false end
		local dir = toEye / d

		-- must stand in front of the plate
		if plate.CFrame.LookVector:Dot(dir) < cosT then return false end
		-- must be looking at it
		local lv = look[viewer] or head.CFrame.LookVector
		if lv:Dot(-dir) < cosV then return false end
		-- line of sight (any wall, prop or other body blocks it)
		params.FilterDescendantsInstances = { vc, tc }
		if workspace:Raycast(eye, plate.Position - eye, params) then return false end
		return true
	end

	local acc = 0
	local step = 1 / Config.VisionHz
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < step then return end
		acc = 0

		if State.phase ~= "Playing" then
			for v in pairs(seen) do revokeAll(v) end
			if ALWAYS then syncAlways() end -- alive is empty outside rounds -> clears everything
			return
		end
		if ALWAYS then syncAlways() end

		local count = {}
		for viewer in pairs(State.alive) do
			if typeof(viewer) ~= "Instance" then continue end -- Studio test bots never view
			seen[viewer] = seen[viewer] or {}
			local row = seen[viewer]
			for target in pairs(State.alive) do
				if target ~= viewer then
					local ok = qualifies(viewer, target)
					local code = ok and CodeStore.get(target)
					if code then
						count[target] = (count[target] or 0) + 1
						local plate = ctx.plates[target]
						if row[target] ~= plate then
							row[target] = plate
							if not ALWAYS then R.PlateVision:FireClient(viewer, { plate = plate, code = code }) end
						end
					elseif row[target] ~= nil then
						revoke(viewer, target)
					end
				end
			end
		end
		-- viewers who died / left: drop everything
		for v in pairs(seen) do
			if not State.alive[v] then revokeAll(v); seen[v] = nil end
		end
		-- tell targets how many eyes are on them (no identities)
		for target in pairs(State.alive) do
			if typeof(target) ~= "Instance" then continue end
			local n = count[target] or 0
			if (readers[target] or 0) ~= n then
				readers[target] = n
				R.Feedback:FireClient(target, { kind = "Read", count = n })
			end
		end
		for t in pairs(readers) do
			if not State.alive[t] then
				readers[t] = nil
				if typeof(t) == "Instance" and t.Parent then R.Feedback:FireClient(t, { kind = "Read", count = 0 }) end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		look[p] = nil
		seen[p] = nil
		readers[p] = nil
		revokeTarget(p)
	end)
end

return Vision
