-- Nameless :: kick input, knockback, zone HUD, spectator camera (client)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Nameless")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("NamelessHUD")
local camera = workspace.CurrentCamera

local INK = Color3.fromRGB(255, 255, 255)
local HOT = Color3.fromRGB(255, 70, 160)
local VOID = Color3.fromRGB(20, 20, 28)

local function make(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end

------------------------------------------------------------ kick button
local actionButton
for _ = 1, 50 do actionButton = shared.NamelessActionButton if actionButton then break end task.wait(0.1) end
local kickBtn = actionButton and actionButton("Kick", "Kick", "F", 2)

local alive, phase = false, "Waiting"
local kickReadyAt = 0

local function cooldownFx(seconds)
	if not kickBtn then return end
	local cd = kickBtn:FindFirstChild("Cooldown")
	cd.Size = UDim2.fromScale(1, 1)
	TweenService:Create(cd, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
end

local function kick()
	if not alive or phase ~= "Playing" then return end
	if os.clock() < kickReadyAt then return end
	kickReadyAt = os.clock() + Config.KickCooldown
	Remotes.Kick:FireServer()
	cooldownFx(Config.KickCooldown)
end
if kickBtn then kickBtn.Activated:Connect(kick) end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then kick() end
end)

------------------------------------------------------------ zone HUD
local zoneLbl = make("TextLabel", {
	Name = "Zone", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.new(0, 420, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 18,
	TextColor3 = INK, TextStrokeTransparency = 0.3, TextStrokeColor3 = VOID, Text = "",
}, hud)
local warnLbl = make("TextLabel", {
	Name = "ZoneWarn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32),
	Size = UDim2.new(0, 520, 0, 48), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 34,
	TextColor3 = HOT, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(1, 1, 1), Text = "", Visible = false,
}, hud)

local zoneInfo
Remotes.Feedback.OnClientEvent:Connect(function(m)
	if type(m) ~= "table" then return end
	if m.kind == "Zone" then
		zoneInfo = m
		if not m.active then zoneLbl.Text = "" return end
		if m.stage == 0 then
			zoneLbl.Text = string.format("Zone closes in %ds", m.nextIn)
		elseif m.shrinking then
			zoneLbl.Text = string.format("ZONE CLOSING  ·  stage %d/%d", m.stage, m.stages)
		elseif m.stage < m.stages then
			zoneLbl.Text = string.format("Next close in %ds", m.nextIn)
		else
			zoneLbl.Text = "Final circle"
		end
	elseif m.kind == "Outside" then
		if m.left == false or not alive then
			warnLbl.Visible = false
		else
			warnLbl.Visible = true
			warnLbl.Text = string.format("GET BACK IN THE ZONE  %.0f", math.ceil(m.left))
		end
	elseif m.kind == "Death" and m.you then
		warnLbl.Visible = false
	elseif m.kind == "KickUsed" then
		kickReadyAt = os.clock() + (m.cooldown or Config.KickCooldown)
	elseif m.kind == "Knocked" then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and typeof(m.dir) == "Vector3" then
			-- slide an exact short distance while staying on your feet (no physics fling)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			local dir = Vector3.new(m.dir.X, 0, m.dir.Z)
			if dir.Magnitude > 0 then dir = dir.Unit end
			local total = math.clamp(m.dist or 3, 0, 8)
			local speed = total / math.max(0.05, m.push or 0.2)
			local cast = RaycastParams.new()
			cast.FilterType = Enum.RaycastFilterType.Exclude
			cast.FilterDescendantsInstances = { char }
			local moved = 0
			local conn
			conn = RunService.Heartbeat:Connect(function(dt)
				if not hrp.Parent then conn:Disconnect() return end
				local step = math.min(total - moved, speed * dt)
				-- stop at walls / hedges; open edges still let you go over (canal!)
				if step <= 0 or workspace:Spherecast(hrp.Position, 1.1, dir * (step + 0.6), cast) then
					conn:Disconnect()
					return
				end
				hrp.CFrame = hrp.CFrame + dir * step
				moved += step
			end)
			-- small hop so the hit reads clearly
			hrp.AssemblyLinearVelocity = Vector3.new(0, 14, 0)
			-- quick camera shake
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.35 do
					local a = (0.35 - (os.clock() - t0)) * 0.6
					hum.CameraOffset = Vector3.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
					RunService.RenderStepped:Wait()
				end
				hum.CameraOffset = Vector3.zero
			end)
			task.delay(m.stun or 1, function()
				if hum.Parent then
					hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
					hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
				end
			end)
		end
	end
end)

------------------------------------------------------------ spectator camera
local specBar = make("Frame", {
	Name = "Spectate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 300, 0, 50), BackgroundColor3 = VOID, BackgroundTransparency = 0.25, Visible = false,
}, hud)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, specBar)
local specLbl = make("TextLabel", { Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 60, 0, 0), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = INK, Text = "Spectating" }, specBar)
local prevBtn = make("TextButton", { Size = UDim2.new(0, 50, 0, 40), Position = UDim2.new(0, 5, 0, 5), BackgroundColor3 = HOT,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = INK, Text = "<" }, specBar)
local nextBtn = make("TextButton", { Size = UDim2.new(0, 50, 0, 40), Position = UDim2.new(1, -55, 0, 5), BackgroundColor3 = HOT,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = INK, Text = ">" }, specBar)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, prevBtn)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, nextBtn)

local targets, idx = {}, 1
local function ownHumanoid() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end

local function applySpectate()
	local spectating = (phase == "Playing") and not alive and #targets > 0
	specBar.Visible = spectating
	if spectating then
		idx = ((idx - 1) % #targets) + 1
		local t = targets[idx]
		local h = t and t:FindFirstChildOfClass("Humanoid")
		if h then camera.CameraSubject = h end
		specLbl.Text = string.format("Spectating  %d / %d", idx, #targets)
	else
		local h = ownHumanoid()
		if h and camera.CameraSubject ~= h then camera.CameraSubject = h end
	end
end
prevBtn.Activated:Connect(function() idx -= 1 applySpectate() end)
nextBtn.Activated:Connect(function() idx += 1 applySpectate() end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not specBar.Visible then return end
	if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then idx -= 1 applySpectate()
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then idx += 1 applySpectate() end
end)

Remotes.Feedback.OnClientEvent:Connect(function(m)
	if type(m) == "table" and m.kind == "Spectate" then
		local clean = {}
		for _, c in ipairs(m.targets or {}) do
			if typeof(c) == "Instance" and c.Parent then table.insert(clean, c) end
		end
		targets = clean
		applySpectate()
	end
end)

Remotes.RoundState.OnClientEvent:Connect(function(s)
	local wasAlive = alive
	alive, phase = s.alive, s.phase
	if phase ~= "Playing" or not alive then warnLbl.Visible = false end
	if kickBtn then kickBtn.Visible = alive and phase == "Playing" end
	if wasAlive ~= alive or phase ~= "Playing" then applySpectate() end
end)
player.CharacterAdded:Connect(function() task.defer(applySpectate) end)

------------------------------------------------------------ outside-the-zone overlay + arrow to safety
local tint = make("Frame", { Name = "ZoneTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = HOT,
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0 }, hud)
local arrow = make("Frame", { Name = "ZoneArrow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0, 70, 0, 70), BackgroundTransparency = 1, Visible = false }, hud)
make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.35, 0), Size = UDim2.new(0, 12, 0.6, 0),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, arrow)
local head = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0, 30, 0, 30),
	Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, arrow)
make("UIStroke", { Color = HOT, Thickness = 3 }, head)

RunService.RenderStepped:Connect(function()
	local out = warnLbl.Visible and alive and phase == "Playing"
	local goal = out and 0.72 or 1
	tint.BackgroundTransparency += (goal - tint.BackgroundTransparency) * 0.15
	arrow.Visible = out and zoneInfo ~= nil and zoneInfo.center ~= nil
	if arrow.Visible then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local to = zoneInfo.center - hrp.Position
			local look = camera.CFrame.LookVector
			local a1 = math.atan2(look.X, look.Z)
			local a2 = math.atan2(to.X, to.Z)
			arrow.Rotation = math.deg(a1 - a2)
			-- gentle pulse
			arrow.Size = UDim2.new(0, 70 + math.sin(os.clock() * 8) * 6, 0, 70 + math.sin(os.clock() * 8) * 6)
		end
	end
end)

-- Roblox's camera scripts reset CameraSubject on respawn; keep enforcing it
task.spawn(function()
	while true do
		task.wait(0.25)
		if specBar.Visible then
			local t = targets[idx]
			local h = t and t.Parent and t:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then
				-- target died: move to the next living one
				for i, c in ipairs(targets) do
					local hh = c.Parent and c:FindFirstChildOfClass("Humanoid")
					if hh and hh.Health > 0 then idx = i h = hh break end
				end
			end
			if h and camera.CameraSubject ~= h then
				camera.CameraSubject = h
				specLbl.Text = string.format("Spectating  %d / %d", idx, #targets)
			end
		end
	end
end)
