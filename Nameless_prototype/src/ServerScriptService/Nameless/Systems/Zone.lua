-- Zone: shrinking play area + environmental deaths (canal, long falls) + AFK.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Zone = {}

function Zone.init(ctx)
	local Config, R, State = ctx.Config, ctx.Remotes, ctx.State

	-- visible wall (not secret; CanQuery off so it never blocks sight or kicks)
	local wall = Instance.new("Part")
	wall.Name = "ZoneWall"
	wall.Shape = Enum.PartType.Cylinder
	wall.Anchored, wall.CanCollide, wall.CanQuery, wall.CanTouch = true, false, false, false
	wall.CastShadow = false
	wall.Material = Enum.Material.ForceField
	wall.Color = Color3.fromRGB(255, 70, 160)
	wall.Transparency = 0.1

	local zone = { center = Vector3.zero, radius = Config.ZoneStartRadius, active = false, stage = 0, nextAt = 0, shrinking = false,
		nextCenter = nil, nextRadius = nil }

	-- white ghost ring: where the NEXT safe circle will be
	local preview = Instance.new("Part")
	preview.Name = "ZoneNext"
	preview.Shape = Enum.PartType.Cylinder
	preview.Anchored, preview.CanCollide, preview.CanQuery, preview.CanTouch = true, false, false, false
	preview.CastShadow = false
	preview.Material = Enum.Material.ForceField
	preview.Color = Color3.fromRGB(255, 255, 255)
	preview.Transparency = 0.35

	local function showPreview()
		if zone.nextCenter and zone.nextRadius then
			preview.Size = Vector3.new(14, zone.nextRadius * 2, zone.nextRadius * 2)
			preview.CFrame = CFrame.new(zone.nextCenter.X, 7, zone.nextCenter.Z) * CFrame.Angles(0, 0, math.rad(90))
			preview.Parent = nil -- white next-zone ring removed (by request)
		else
			preview.Parent = nil
		end
	end

	local function pickNext(i)
		local st = Config.ZoneStages[i]
		if not st then zone.nextCenter, zone.nextRadius = nil, nil return end
		local newR = st[1]
		-- the new circle always sits inside the current one
		local maxOff = math.max(0, math.min(zone.radius - newR, 22))
		local ang = math.random() * math.pi * 2
		local c = zone.center + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (math.random() * maxOff)
		zone.nextCenter = Vector3.new(math.clamp(c.X, -55, 55), 0, math.clamp(c.Z, -55, 55))
		zone.nextRadius = newR
	end

	local function place()
		wall.Size = Vector3.new(60, zone.radius * 2, zone.radius * 2)
		wall.CFrame = CFrame.new(zone.center.X, 20, zone.center.Z) * CFrame.Angles(0, 0, math.rad(90))
	end

	local function announce()
		R.Feedback:FireAllClients({
			kind = "Zone", active = zone.active, center = zone.center, radius = zone.radius,
			stage = zone.stage, stages = #Config.ZoneStages,
			nextIn = math.max(0, math.floor(zone.nextAt - os.clock() + 0.5)), shrinking = zone.shrinking,
			nextCenter = zone.nextCenter, nextRadius = zone.nextRadius,
		})
	end

	local function runZone(roundId)
		zone.center = Vector3.zero
		zone.radius = Config.ZoneStartRadius
		zone.stage = 0
		zone.active = true
		zone.shrinking = false
		zone.nextAt = os.clock() + Config.ZoneFirstDelay
		place()
		wall.Parent = workspace
		pickNext(1)
		showPreview()
		announce()
		task.wait(Config.ZoneFirstDelay)

		for i, st in ipairs(Config.ZoneStages) do
			if State.phase ~= "Playing" or ctx.roundId ~= roundId then return end
			local shrinkT, holdT = st[2], st[3]
			local fromC, fromR = zone.center, zone.radius
			local toC, newR = zone.nextCenter, zone.nextRadius

			zone.stage = i
			zone.shrinking = true
			zone.nextAt = os.clock() + shrinkT
			announce()
			local t0 = os.clock()
			while true do
				if State.phase ~= "Playing" or ctx.roundId ~= roundId then return end
				local k = math.min(1, (os.clock() - t0) / shrinkT)
				zone.center = fromC:Lerp(toC, k)
				zone.radius = fromR + (newR - fromR) * k
				place()
				if k >= 1 then break end
				task.wait(0.1)
			end
			zone.shrinking = false
			pickNext(i + 1)  -- reveal the next circle during the hold
			showPreview()
			zone.nextAt = os.clock() + holdT
			announce()
			task.wait(holdT)
		end
	end

	ctx.roundId = 0
	table.insert(ctx.Hooks.onRoundStart, function()
		ctx.roundId += 1
		runZone(ctx.roundId)
	end)
	table.insert(ctx.Hooks.onRoundEnd, function()
		zone.active = false
		wall.Parent = nil
		zone.nextCenter, zone.nextRadius = nil, nil
		preview.Parent = nil
		announce()
	end)

	------------------------------------------------------------ per-player checks (4 Hz)
	local outside = {}   -- [p] = seconds outside
	local airPeak = {}   -- [p] = highest Y since leaving the ground
	local lastMove = {}  -- [p] = { pos, t }
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then return end
		local step = acc
		acc = 0
		if State.phase ~= "Playing" then
			table.clear(outside); table.clear(airPeak); table.clear(lastMove)
			return
		end
		local now = os.clock()
		for p in pairs(State.alive) do
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then continue end
			local pos = hrp.Position

			-- canal / out of world
			if pos.Y < Config.FallDeathY then ctx.kill(p, "fall") continue end
			-- touching the canal water (it is swimmable terrain, so check the volume)
			if pos.Z > -43.5 and pos.Z < -32.5 and pos.Y < 1.2 then ctx.kill(p, "fall") continue end

			-- long falls (skip anchored test bots)
			if not hrp.Anchored then
				down.FilterDescendantsInstances = { char }
				local hit = workspace:Raycast(pos, Vector3.new(0, -4, 0), down)
				if hit then
					local peak = airPeak[p]
					if peak and peak - pos.Y > Config.FallDeathHeight then
						airPeak[p] = nil
						ctx.kill(p, "fall")
						continue
					end
					airPeak[p] = nil
				else
					airPeak[p] = math.max(airPeak[p] or pos.Y, pos.Y)
				end
			end

			-- zone
			if zone.active then
				local flat = Vector3.new(pos.X - zone.center.X, 0, pos.Z - zone.center.Z).Magnitude
				if flat > zone.radius then
					local was = outside[p]
					outside[p] = (was or 0) + step
					if typeof(p) == "Instance" then
						R.Feedback:FireClient(p, { kind = "Outside", left = math.max(0, Config.ZoneGrace - outside[p]) })
					end
					if outside[p] >= Config.ZoneGrace then
						outside[p] = nil
						ctx.kill(p, "zone")
						continue
					end
				elseif outside[p] then
					outside[p] = nil
					if typeof(p) == "Instance" then R.Feedback:FireClient(p, { kind = "Outside", left = false }) end
				end
			end

			-- AFK (real players only)
			if typeof(p) == "Instance" then
				local lm = lastMove[p]
				if not lm or (pos - lm.pos).Magnitude > 2 then
					lastMove[p] = { pos = pos, t = now }
				elseif now - lm.t > Config.AfkTime then
					lastMove[p] = nil
					ctx.kill(p, "afk")
				end
			end
		end
	end)

	-- keep HUD timers fresh
	task.spawn(function()
		while true do
			task.wait(1)
			if zone.active then announce() end
		end
	end)

	Players.PlayerRemoving:Connect(function(p) outside[p] = nil; airPeak[p] = nil; lastMove[p] = nil end)
end

return Zone
