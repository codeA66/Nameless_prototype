-- Nameless :: plate reading (client). Draws ONLY what the server sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Nameless"):WaitForChild("Remotes")
local camera = workspace.CurrentCamera

-- Anonymity: no player list, no health bar
local function hideCore()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
	end)
end
for _ = 1, 5 do hideCore() task.wait(0.5) end

-- Report camera direction (server sanitizes; it only narrows what you can read)
task.spawn(function()
	while true do
		Remotes.Look:FireServer(camera.CFrame.LookVector)
		task.wait(0.1)
	end
end)

-- Local-only SurfaceGuis, parented to PlayerGui (never replicated).
-- PlayerGui is wiped on respawn, so the holder is recreated on demand.
local holder
local function getHolder()
	if holder and holder.Parent then return holder end
	holder = Instance.new("Folder")
	holder.Name = "Plates"
	holder.Parent = player:WaitForChild("PlayerGui")
	return holder
end
getHolder()

local guis = {} -- [plate] = SurfaceGui

local function drop(plate)
	local g = guis[plate]
	if g then g:Destroy() guis[plate] = nil end
end

Remotes.PlateVision.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" or typeof(msg.plate) ~= "Instance" then return end
	local plate = msg.plate
	if player.Character and plate:IsDescendantOf(player.Character) then return end -- own plate drawn separately
	if type(msg.code) == "string" then
		local g = guis[plate]
		if g and not g.Parent then guis[plate] = nil g = nil end
		if not g then
			g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Front
			g.Adornee = plate
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 60
			g.LightInfluence = 0.6
			g.ResetOnSpawn = false
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.Antique -- stylized digits: easy to misread from afar
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(28, 14, 14)
			t.Parent = g
			g.Parent = getHolder()
			guis[plate] = g
			plate.AncestryChanged:Connect(function(_, parent) if not parent then drop(plate) end end)
		end
		g.TextLabel.Text = msg.code
	else
		drop(plate)
	end
end)

-- Own plate: always shows MY code on MY chest (server sends only my own code)
local myCode = nil
local myGui = nil

local function drawOwn()
	if myGui then myGui:Destroy() myGui = nil end
	if not myCode then return end
	local char = player.Character
	local plate = char and char:WaitForChild("Plate", 5)
	if not plate then return end
	local g = Instance.new("SurfaceGui")
	g.Name = "OwnPlate"
	g.Face = Enum.NormalId.Front
	g.Adornee = plate
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.6
	g.ResetOnSpawn = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Antique
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(28, 14, 14)
	t.Text = myCode
	t.Parent = g
	g.Parent = getHolder()
	myGui = g
end

player.CharacterAdded:Connect(function() task.defer(drawOwn) end)

Remotes.Feedback.OnClientEvent:Connect(function(msg)
	if type(msg) == "table" and msg.kind == "YourCode" and type(msg.code) == "string" then
		myCode = msg.code
		drawOwn()
	end
end)

Remotes.RoundState.OnClientEvent:Connect(function(s)
	if (s.phase ~= "Playing" or not s.alive) and myCode then
		myCode = nil
		drawOwn()
	end
end)

-- Being read: red pulse at the screen edges, stronger with more readers
local hud = player.PlayerGui:WaitForChild("NamelessHUD")
local vignette = Instance.new("ImageLabel")
vignette.Name = "ReadVignette"
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png"
vignette.ImageTransparency = 1
vignette.ImageColor3 = Color3.fromRGB(120, 0, 10)
vignette.ZIndex = 1
local grad = Instance.new("UIGradient")
grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.18, 0.85),
	NumberSequenceKeypoint.new(0.82, 0.85), NumberSequenceKeypoint.new(1, 0),
})
grad.Parent = vignette
vignette.Parent = hud

local readCount = 0
Remotes.Feedback.OnClientEvent:Connect(function(msg)
	if type(msg) == "table" and msg.kind == "Read" then
		readCount = msg.count
		local target = readCount > 0 and math.max(0.25, 0.7 - readCount * 0.15) or 1
		TweenService:Create(vignette, TweenInfo.new(0.25), { ImageTransparency = target }):Play()
		shared.NamelessReadCount = readCount -- local VM only, used by audio
	end
end)
