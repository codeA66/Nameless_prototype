-- Combat: server-validated kick (knockback + stun, no damage) and procedural poses.
local Players = game:GetService("Players")

local Combat = {}

local DEFAULT_WALK, DEFAULT_JUMP = 16, 50

-- C0 can't be tweened; lerp it by hand and return to the original pose
local function swing(motor, rot, outT, holdT, backT)
	if not (motor and motor:IsA("Motor6D")) then return end
	if motor:GetAttribute("Busy") then return end
	motor:SetAttribute("Busy", true)
	local base = motor.C0
	local target = base * rot
	task.spawn(function()
		local function run(a, b, dur)
			local t0 = os.clock()
			while motor.Parent and motor.Enabled do
				local k = math.min(1, (os.clock() - t0) / dur)
				motor.C0 = a:Lerp(b, 1 - (1 - k) ^ 2)
				if k >= 1 then break end
				task.wait()
			end
		end
		run(base, target, outT)
		task.wait(holdT)
		run(target, base, backT)
		if motor.Parent then motor:SetAttribute("Busy", nil) end
	end)
end

function Combat.init(ctx)
	local Config, R, State = ctx.Config, ctx.Remotes, ctx.State
	local lastKick = {}
	local stunnedUntil = {}

	function ctx.isStunned(p) return (stunnedUntil[p] or 0) > os.clock() end

	-- notebook writing pose: a quick scribble with the left hand
	function ctx.writePose(player)
		local char = player.Character
		if char then R.Feedback:FireAllClients({ kind = "Anim", char = char, name = "Write" }) end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function applyKnock(target, dir)
		local tc = target.Character
		local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
		local thum = tc and tc:FindFirstChildOfClass("Humanoid")
		if not (thrp and thum) or thum.Health <= 0 then return end
		local pushSpeed = Config.KickPushDistance / Config.KickPushTime
		local vel = dir * pushSpeed -- kept for compatibility; clients use dir/dist/push
		-- no stun: the kick only knocks you back, you keep full control
		if ctx.sfx then ctx.sfx("Hit", thrp) end
		if ctx.hitFx then ctx.hitFx(thrp.Position) end

		if typeof(target) == "Instance" then
			-- the target's client owns its physics, so it slides itself (exact distance)
			R.Feedback:FireClient(target, { kind = "Knocked", vel = vel, dir = dir, dist = Config.KickPushDistance,
				push = Config.KickPushTime, stun = Config.KickPushTime })
		else
			-- Studio bot: anchored, so slide the whole model the same exact distance
			local cast = RaycastParams.new()
			cast.FilterType = Enum.RaycastFilterType.Exclude
			cast.FilterDescendantsInstances = { tc }
			local moved, total = 0, Config.KickPushDistance
			local speed = total / Config.KickPushTime
			local conn
			conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
				if not tc.Parent then conn:Disconnect() return end
				local step = math.min(total - moved, speed * dt)
				if step <= 0 or workspace:Spherecast(thrp.Position, 1.1, dir * (step + 0.6), cast) then
					conn:Disconnect()
					return
				end
				tc:PivotTo(tc:GetPivot() + dir * step)
				moved += step
			end)
		end
	end

	R.Kick.OnServerEvent:Connect(function(player)
		if State.phase ~= "Playing" or not State.alive[player] then return end
		local now = os.clock()
		if lastKick[player] and now - lastKick[player] < Config.KickCooldown then return end
		if ctx.isStunned(player) then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) or hum.Health <= 0 then return end
		lastKick[player] = now
		R.Feedback:FireClient(player, { kind = "KickUsed", cooldown = Config.KickCooldown })

		R.Feedback:FireAllClients({ kind = "Anim", char = char, name = "Kick" })
		if ctx.sfx then ctx.sfx("Kick", hrp) end

		-- server-side hitbox: nearest living target in a frontal cone, in range, with line of sight
		local look = hrp.CFrame.LookVector
		local best, bestD, bestDir
		for t in pairs(State.alive) do
			if t ~= player then
				local tc = t.Character
				local thrp = tc and tc:FindFirstChild("HumanoidRootPart")
				if thrp then
					local off = thrp.Position - hrp.Position
					local flat = Vector3.new(off.X, 0, off.Z)
					local d = flat.Magnitude
					if d > 0.1 and d <= Config.KickRange and math.abs(off.Y) < 5 then
						local dir = flat / d
						if look:Dot(dir) > 0.4 then
							params.FilterDescendantsInstances = { char, tc }
							if not workspace:Raycast(hrp.Position, off, params) and (not bestD or d < bestD) then
								best, bestD, bestDir = t, d, dir
							end
						end
					end
				end
			end
		end
		if best then
			task.delay(0.17, function() -- lands when the leg snaps straight
				if State.alive[best] then applyKnock(best, bestDir) end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(p) lastKick[p] = nil; stunnedUntil[p] = nil end)
	table.insert(ctx.Hooks.onRoundEnd, function() table.clear(lastKick); table.clear(stunnedUntil) end)
end

return Combat
