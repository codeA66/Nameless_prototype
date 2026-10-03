-- Notebook: server-validated writing + death sequence.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Notebook = {}

local TEMPLATE = ServerStorage:WaitForChild("Nameless"):WaitForChild("Notebook")
local ctxRef -- set in init

------------------------------------------------------------------ death fx
local function ragdoll(char)
	for _, m in ipairs(char:GetDescendants()) do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Name ~= "RootJoint" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment"); a0.CFrame = m.C0; a0.Parent = m.Part0
			local a1 = Instance.new("Attachment"); a1.CFrame = m.C1; a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0, bs.Attachment1 = a0, a1
			bs.LimitsEnabled, bs.TwistLimitsEnabled = true, true
			bs.UpperAngle, bs.TwistLowerAngle, bs.TwistUpperAngle = 60, -45, 45
			bs.Parent = m.Part0
			m.Enabled = false
		elseif m:IsA("AnimationConstraint") and m.Enabled and m.Name ~= "Root" and m.Name ~= "RootJoint"
			and m.Attachment0 and m.Attachment1 then
			-- newer avatars: AnimationConstraint joints already have attachments
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0, bs.Attachment1 = m.Attachment0, m.Attachment1
			bs.LimitsEnabled, bs.TwistLimitsEnabled = true, true
			bs.UpperAngle, bs.TwistLowerAngle, bs.TwistUpperAngle = 60, -45, 45
			bs.Parent = m.Parent
			m.Enabled = false
		end
	end
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			if p.Name ~= "HumanoidRootPart" and p.Name ~= "Hood" and p.Name ~= "Mask" and p.Name ~= "Plate" then
				p.CanCollide = true
			end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CanCollide = false end
end

local function darkFx(char)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso then return end
	local att = Instance.new("Attachment"); att.Parent = torso
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DeathSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(10, 0, 4), Color3.fromRGB(40, 0, 10))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.2) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2.2)
	smoke.Rate = 40
	smoke.Speed = NumberRange.new(0.5, 2)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.Parent = att
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 0, 20)
	glow.Range = 10
	glow.Brightness = 0
	glow.Parent = torso
	TweenService:Create(glow, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 3, true), { Brightness = 3 }):Play()
	task.delay(2.5, function() smoke.Enabled = false end)
	Debris:AddItem(glow, 3)
	return torso
end

-- Heart attack: clutch chest, fold forward, collapse into ragdoll.
local function heartAttack(char, done)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then if done then done() end return end
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	local torso = darkFx(char)
	if ctxRef and ctxRef.sfx then ctxRef.sfx("Death", torso) end
	if ctxRef then ctxRef.Remotes.Feedback:FireAllClients({ kind = "Anim", char = char, name = "HeartAttack" }) end

	local waist = char:FindFirstChild("Waist", true)
	local rs = char:FindFirstChild("RightShoulder", true)
	local ls = char:FindFirstChild("LeftShoulder", true)
	local neck = char:FindFirstChild("Neck", true)
	-- C0 can't be tweened, so interpolate it by hand
	local poses = {}
	local function pose(m, rot) if m and m:IsA("Motor6D") then table.insert(poses, { m = m, a = m.C0, b = m.C0 * rot }) end end
	pose(rs, CFrame.Angles(math.rad(70), 0, math.rad(-60)))
	pose(ls, CFrame.Angles(math.rad(50), 0, math.rad(40)))
	pose(waist, CFrame.Angles(math.rad(-35), 0, 0))
	pose(neck, CFrame.Angles(math.rad(25), 0, 0))
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / 0.9)
			local e = 1 - (1 - a) ^ 2
			for _, p in ipairs(poses) do
				if p.m.Parent then pcall(function() p.m.C0 = p.a:Lerp(p.b, e) end) end
			end
			if a >= 1 then break end
			task.wait()
		end
	end)

	task.delay(1.1, function()
		if char.Parent then
			ragdoll(char)
			hum.Health = 0
		end
		if done then done() end
	end)
end

------------------------------------------------------------------
function Notebook.init(ctx)
	ctxRef = ctx
	local Config, R, State, CodeStore = ctx.Config, ctx.Remotes, ctx.State, ctx.CodeStore

	local function isNotebook(t)
		return t and t:IsA("Tool") and t:GetAttribute("NamelessNotebook") == true
	end

	local function removeNotebook(player)
		if typeof(player) ~= "Instance" then return end
		for _, c in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
			if c then
				for _, t in ipairs(c:GetChildren()) do if isNotebook(t) then t:Destroy() end end
			end
		end
	end

	local function giveNotebook(player)
		if typeof(player) ~= "Instance" then return end
		removeNotebook(player)
		local bp = player:FindFirstChildOfClass("Backpack")
		if not bp then return end
		local t = TEMPLATE:Clone()
		t.Name = Config.NotebookName
		t.Parent = bp
	end
	ctx.giveNotebook = giveNotebook
	ctx.removeNotebook = removeNotebook

	-- kill: the single authority for ending a life
	function ctx.kill(target, cause)
		if not State.alive[target] then return false end
		State.alive[target] = nil
		if ctx.revokeVisionTarget then ctx.revokeVisionTarget(target) end
		if typeof(target) == "Instance" and ctx.revokeVisionViewer then ctx.revokeVisionViewer(target) end
		removeNotebook(target)

		local remain = 0
		for _ in pairs(State.alive) do remain += 1 end
		for _, p in ipairs(Players:GetPlayers()) do
			R.Feedback:FireClient(p, { kind = "Death", remain = remain, you = (p == target), cause = cause })
		end

		local char = target.Character
		if char and char.Parent then
			task.spawn(function()
				local ok, err = pcall(heartAttack, char)
				if not ok then
					warn("[Nameless] death fx: " .. tostring(err))
					local h = char:FindFirstChildOfClass("Humanoid")
					if h then h.Health = 0 end
				end
			end)
		end
		if ctx.onDeath then ctx.onDeath(target, cause) end
		ctx.broadcast()
		return true
	end

	-- rate limiting
	local lastWrite = {}
	local history = {} -- [Player] = { timestamps }

	local function allowed(player)
		local now = os.clock()
		if lastWrite[player] and now - lastWrite[player] < Config.WriteCooldown then return false, "cooldown" end
		local h = history[player] or {}
		history[player] = h
		local i = 1
		while i <= #h do
			if now - h[i] > Config.WriteBurstWindow then table.remove(h, i) else i += 1 end
		end
		if #h >= Config.WriteBurstLimit then return false, "burst" end
		lastWrite[player] = now
		table.insert(h, now)
		return true
	end

	R.WriteNote.OnServerEvent:Connect(function(player, code)
		if State.phase ~= "Playing" or not State.alive[player] then return end
		local char = player.Character
		if not char then return end
		local tool = char:FindFirstChildWhichIsA("Tool")
		if not isNotebook(tool) then return end -- must be holding the notebook
		if not CodeStore.isValid(code) then return end
		-- (being kicked does NOT stop you from writing)

		local ok, why = allowed(player)
		if not ok then
			R.Feedback:FireClient(player, { kind = "WriteRejected", reason = why })
			return
		end

		if ctx.sfx then ctx.sfx("Write", tool:FindFirstChild("Handle")) end
		if ctx.writePose then ctx.writePose(player) end

		-- everyone alive holding this exact code dies (writer included, if it is theirs)
		local victims = {}
		for _, p in ipairs(CodeStore.holders(code)) do
			if State.alive[p] then table.insert(victims, p) end
		end
		R.Feedback:FireClient(player, { kind = "Written" })
		if #victims > 0 then
			task.delay(0.6, function() -- ink takes a moment
				for _, v in ipairs(victims) do ctx.kill(v, "ink") end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(p) lastWrite[p] = nil; history[p] = nil end)

	table.insert(ctx.Hooks.onRoundStart, function()
		for p in pairs(State.alive) do giveNotebook(p) end
	end)
	table.insert(ctx.Hooks.onRoundEnd, function()
		for _, p in ipairs(Players:GetPlayers()) do removeNotebook(p) end
	end)
end

return Notebook
