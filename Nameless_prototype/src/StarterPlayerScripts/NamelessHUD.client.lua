-- Nameless :: HUD + code entry keypad (client)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Nameless")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local INK = Color3.fromRGB(232, 224, 205)
local DIM = Color3.fromRGB(120, 112, 100)
local BLOOD = Color3.fromRGB(170, 22, 32)
local VOID = Color3.fromRGB(8, 8, 12)
local PANEL = Color3.fromRGB(18, 17, 22)

local gui = Instance.new("ScreenGui")
gui.Name = "NamelessHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function make(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, c, t) make("UIStroke", { Color = c or DIM, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end

------------------------------------------------------------------ HUD
local top = make("TextLabel", {
	Name = "Phase", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.new(0, 420, 0, 34), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 26, TextColor3 = INK, Text = "",
	TextStrokeTransparency = 0.2, TextStrokeColor3 = VOID,
}, gui)

local myCodeTag = make("TextLabel", {
	Name = "MyCode", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18),
	Size = UDim2.new(0, 240, 0, 26), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.Code, TextSize = 20, TextColor3 = INK, Text = "", Visible = false,
	TextStrokeTransparency = 0.2, TextStrokeColor3 = VOID,
}, gui)

local toast = make("TextLabel", {
	Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.new(0, 520, 0, 28), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = BLOOD, Text = "", TextTransparency = 1,
}, gui)

local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or BLOOD
	toast.TextTransparency = 0
	task.delay(2.5, function()
		if toast.Text == text then
			TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

------------------------------------------------------------------ Keypad
local shade = make("Frame", {
	Name = "CodeEntry", Size = UDim2.fromScale(1, 1), BackgroundColor3 = VOID,
	BackgroundTransparency = 0.15, Visible = false, ZIndex = 10,
}, gui)

local card = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0, 340, 0, 500), BackgroundColor3 = PANEL, ZIndex = 11,
}, shade)
corner(card, 10); stroke(card, BLOOD, 1.5)
make("UISizeConstraint", { MaxSize = Vector2.new(340, 500) }, card)
make("UIAspectRatioConstraint", { AspectRatio = 340 / 500 }, card)
-- shrink on small (mobile) screens
local scale = make("UIScale", { Scale = 1 }, card)
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 400, vp.Y / 600), 0.55, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

make("TextLabel", {
	Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = INK, Text = "Choose your code", ZIndex = 12,
}, card)
make("TextLabel", {
	Position = UDim2.new(0, 20, 0, 52), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1,
	Font = Enum.Font.Gotham, TextSize = 16, TextColor3 = DIM, TextWrapped = true, ZIndex = 12,
	Text = "5 digits, worn on your chest. Anyone who writes it in their notebook eliminates you!",
}, card)

local timerLbl = make("TextLabel", {
	Position = UDim2.new(1, -60, 0, 8), Size = UDim2.new(0, 50, 0, 20), BackgroundTransparency = 1,
	Font = Enum.Font.Code, TextSize = 16, TextColor3 = BLOOD, Text = "", ZIndex = 12,
}, card)

local slotsRow = make("Frame", {
	Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0, 280, 0, 56), BackgroundTransparency = 1, ZIndex = 12,
}, card)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, slotsRow)

local slots = {}
for i = 1, Config.CodeLength do
	local s = make("TextLabel", {
		Size = UDim2.new(0, 46, 0, 56), BackgroundColor3 = VOID, Font = Enum.Font.Code,
		TextSize = 32, TextColor3 = INK, Text = "", ZIndex = 13, LayoutOrder = i,
	}, slotsRow)
	corner(s, 4); stroke(s, DIM, 1)
	slots[i] = s
end

local grid = make("Frame", {
	Position = UDim2.new(0.5, 0, 0, 176), AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0, 252, 0, 248), BackgroundTransparency = 1, ZIndex = 12,
}, card)
make("UIGridLayout", { CellSize = UDim2.new(0, 76, 0, 54), CellPadding = UDim2.new(0, 12, 0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder }, grid)

local statusLbl = make("TextLabel", {
	Position = UDim2.new(0, 10, 1, -36), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = DIM, Text = "", ZIndex = 12,
}, card)

local entry = ""
local sealed = nil -- my confirmed code (local only; it is mine)
local busy = false

local function render()
	for i = 1, Config.CodeLength do
		slots[i].Text = string.sub(entry, i, i)
		local st = slots[i]:FindFirstChildOfClass("UIStroke")
		st.Color = (i == #entry + 1) and BLOOD or DIM
	end
end

local function press(key)
	if busy then return end
	if key == "DEL" then
		entry = string.sub(entry, 1, -2)
	elseif key == "SEAL" then
		if #entry ~= Config.CodeLength then
			statusLbl.Text = "Five digits."
			return
		end
		busy = true
		statusLbl.Text = "Sealing..."
		local ok, res = pcall(function() return Remotes.SubmitCode:InvokeServer(entry) end)
		busy = false
		if ok and type(res) == "table" and res.ok then
			sealed = entry
			statusLbl.Text = "Sealed. You may change it until time runs out."
			statusLbl.TextColor3 = INK
			myCodeTag.Text = "your code  " .. sealed
		else
			statusLbl.Text = (ok and type(res) == "table" and res.msg) or "Rejected."
			statusLbl.TextColor3 = BLOOD
		end
	elseif #entry < Config.CodeLength then
		entry ..= key
	end
	render()
end

local keys = { "1","2","3","4","5","6","7","8","9","DEL","0","SEAL" }
for i, k in ipairs(keys) do
	local b = make("TextButton", {
		LayoutOrder = i, BackgroundColor3 = (k == "SEAL") and BLOOD or VOID, AutoButtonColor = true,
		Font = (#k == 1) and Enum.Font.Code or Enum.Font.GothamBold, TextSize = (#k == 1) and 28 or 20,
		TextColor3 = INK, Text = (k == "DEL") and "Del" or (k == "SEAL" and "Seal" or k), ZIndex = 13,
	}, grid)
	corner(b, 6); stroke(b, DIM, 1)
	b.Activated:Connect(function() press(k) end)
end

-- Physical keyboard support while the keypad is open
local digitKeys = {
	[Enum.KeyCode.Zero] = "0", [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4", [Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6", [Enum.KeyCode.Seven] = "7",
	[Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
	[Enum.KeyCode.KeypadZero] = "0", [Enum.KeyCode.KeypadOne] = "1", [Enum.KeyCode.KeypadTwo] = "2",
	[Enum.KeyCode.KeypadThree] = "3", [Enum.KeyCode.KeypadFour] = "4", [Enum.KeyCode.KeypadFive] = "5",
	[Enum.KeyCode.KeypadSix] = "6", [Enum.KeyCode.KeypadSeven] = "7", [Enum.KeyCode.KeypadEight] = "8",
	[Enum.KeyCode.KeypadNine] = "9",
}
UserInputService.InputBegan:Connect(function(input, processed)
	if not shade.Visible or processed then return end
	local d = digitKeys[input.KeyCode]
	if d then press(d)
	elseif input.KeyCode == Enum.KeyCode.Backspace then press("DEL")
	elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then press("SEAL") end
end)

------------------------------------------------------------------ State
local PHASE_TEXT = {
	Waiting = "Waiting for players",
	Intermission = "Round starts in",
	CodeEntry = "Choose your code",
	Playing = "Survive",
	Ended = "Round over",
}

local lastPhase
Remotes.RoundState.OnClientEvent:Connect(function(s)
	local label = PHASE_TEXT[s.phase] or s.phase
	if s.phase == "Waiting" then
		top.Text = s.inGate
			and string.format("You're in the gate!  Waiting for players  %d / %d", s.gate or 0, s.need or 0)
			or string.format("Step into the PINK GATE to play  %d / %d", s.gate or 0, s.need or 0)
	elseif s.phase == "Intermission" then
		top.Text = s.inGate
			and string.format("You're in!  Round starts in %d", s.timeLeft)
			or string.format("Round starts in %d  ·  enter the PINK GATE to join", s.timeLeft)
	elseif s.phase == "Playing" then
		top.Text = s.alive and string.format("%s  ·  %d remain", label, s.aliveCount)
			or string.format("Spectating  ·  %d remain", s.aliveCount)
	elseif s.phase == "Ended" then
		top.Text = (s.extra and s.extra.winner) and "Round over!" or "Round over"
	else
		top.Text = string.format("%s  %d", label, s.timeLeft)
	end

	if s.phase ~= lastPhase then
		if s.phase == "CodeEntry" then
			entry, sealed = "", nil
			statusLbl.Text = ""; statusLbl.TextColor3 = DIM
			myCodeTag.Text = ""
			render()
		end
		if s.phase == "Intermission" or s.phase == "Waiting" then
			myCodeTag.Visible = false
		end
		lastPhase = s.phase
	end

	shade.Visible = (s.phase == "CodeEntry") and s.participant
	timerLbl.Text = tostring(s.timeLeft)
	myCodeTag.Visible = (s.phase == "Playing") and s.alive and myCodeTag.Text ~= ""
end)

Remotes.Feedback.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.kind == "YourCode" then
		sealed = msg.code
		myCodeTag.Text = "your code  " .. msg.code
	elseif msg.kind == "AssignedCode" then
		sealed = msg.code
		myCodeTag.Text = "your code  " .. msg.code
		showToast("Too slow! Your random code is " .. msg.code)
	elseif msg.kind == "Toast" then
		showToast(msg.text, msg.color)
	end
end)

render()
