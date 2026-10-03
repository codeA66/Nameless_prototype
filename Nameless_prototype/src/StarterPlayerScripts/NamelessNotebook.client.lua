-- Nameless :: notebook UI + action buttons (client)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Nameless")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("NamelessHUD")

local INK = Color3.fromRGB(232, 224, 205)
local DIM = Color3.fromRGB(120, 112, 100)
local BLOOD = Color3.fromRGB(170, 22, 32)
local VOID = Color3.fromRGB(8, 8, 12)
local PAPER = Color3.fromRGB(214, 205, 180)
local LEATHER = Color3.fromRGB(28, 10, 12)

-- custom equip: frees number keys for writing
task.spawn(function()
	for _ = 1, 5 do
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
		task.wait(0.5)
	end
end)

local function make(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, c, t) make("UIStroke", { Color = c or DIM, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end

------------------------------------------------------------------ action buttons (mobile + mouse)
local actions = make("Frame", {
	Name = "Actions", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24),
	Size = UDim2.new(0, 190, 0, 84), BackgroundTransparency = 1, Visible = false,
}, hud)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14),
	HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom }, actions)

local function actionButton(name, label, key, order)
	local b = make("TextButton", {
		Name = name, LayoutOrder = order, Size = UDim2.new(0, 84, 0, 84), BackgroundColor3 = VOID,
		BackgroundTransparency = 0.2, Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = INK,
		Text = label, AutoButtonColor = true,
	}, actions)
	corner(b, 42); stroke(b, BLOOD, 1.5)
	if not UserInputService.TouchEnabled then
		make("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, 2), BackgroundTransparency = 1,
			Font = Enum.Font.Code, TextSize = 13, TextColor3 = DIM, Text = "[" .. key .. "]" }, b)
	end
	local cd = make("Frame", { Name = "Cooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1), BackgroundColor3 = BLOOD, BackgroundTransparency = 0.55, ZIndex = 2 }, b)
	corner(cd, 42)
	return b
end

local bookBtn = actionButton("Book", Config.NotebookName, "Q", 1)
shared.NamelessActionButton = actionButton -- kick button is added by NamelessCombat

------------------------------------------------------------------ notebook panel
local panel = make("Frame", {
	Name = "Notebook", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.new(0, 300, 0, 300), BackgroundColor3 = PAPER, Visible = false, ZIndex = 20,
}, hud)
corner(panel, 8); stroke(panel, LEATHER, 6)
local pscale = make("UIScale", {}, panel)
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	pscale.Scale = math.clamp(math.min(vp.X / 700, vp.Y / 640), 0.6, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

make("TextLabel", { Position = UDim2.new(0, 0, 0, 8), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = LEATHER, Text = Config.NotebookName, ZIndex = 21 }, panel)

local row = make("Frame", { Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0, 260, 0, 48), BackgroundTransparency = 1, ZIndex = 21 }, panel)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, row)
local slots = {}
for i = 1, Config.CodeLength do
	local s = make("TextLabel", { LayoutOrder = i, Size = UDim2.new(0, 42, 0, 48), BackgroundTransparency = 1,
		Font = Enum.Font.Antique, TextSize = 38, TextColor3 = Color3.fromRGB(30, 10, 10), Text = "", ZIndex = 22 }, row)
	make("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = LEATHER,
		BorderSizePixel = 0, ZIndex = 22, Name = "Line" }, s)
	slots[i] = s
end

local grid = make("Frame", { Position = UDim2.new(0.5, 0, 0, 98), AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.new(0, 210, 0, 160), BackgroundTransparency = 1, ZIndex = 21 }, panel)
make("UIGridLayout", { CellSize = UDim2.new(0, 62, 0, 34), CellPadding = UDim2.new(0, 12, 0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder }, grid)

local status = make("TextLabel", { Position = UDim2.new(0, 8, 1, -34), Size = UDim2.new(1, -16, 0, 26),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = LEATHER, Text = "", ZIndex = 21 }, panel)

local entry = ""
local function render()
	for i = 1, Config.CodeLength do
		slots[i].Text = string.sub(entry, i, i)
		slots[i].Line.BackgroundColor3 = (i == #entry + 1) and BLOOD or LEATHER
	end
end

local lastWrite = 0
local function cooldownFx(btn, seconds)
	local cd = btn:FindFirstChild("Cooldown")
	cd.Size = UDim2.fromScale(1, 1)
	TweenService:Create(cd, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
end

local function write()
	if #entry ~= Config.CodeLength then status.Text = "Five digits." return end
	if os.clock() - lastWrite < Config.WriteCooldown then return end
	lastWrite = os.clock()
	Remotes.WriteNote:FireServer(entry)
	cooldownFx(bookBtn, Config.WriteCooldown)
	status.Text = ""
	entry = ""
	render()
end

local function press(k)
	if k == "DEL" then entry = string.sub(entry, 1, -2)
	elseif k == "WRITE" then write() return
	elseif #entry < Config.CodeLength then entry ..= k end
	render()
end

for i, k in ipairs({ "1","2","3","4","5","6","7","8","9","DEL","0","WRITE" }) do
	local b = make("TextButton", { LayoutOrder = i, BackgroundColor3 = (k == "WRITE") and BLOOD or LEATHER,
		Font = (#k == 1) and Enum.Font.Code or Enum.Font.GothamBold, TextSize = (#k == 1) and 22 or 18,
		TextColor3 = INK, Text = (k == "DEL") and "Del" or (k == "WRITE" and "Write" or k), ZIndex = 22 }, grid)
	corner(b, 5)
	b.Activated:Connect(function() press(k) end)
end

------------------------------------------------------------------ equip handling
local function findBook()
	local char = player.Character
	for _, c in ipairs({ char, player:FindFirstChildOfClass("Backpack") }) do
		if c then
			for _, t in ipairs(c:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("NamelessNotebook") then return t, c == char end
			end
		end
	end
end

local function toggleBook()
	local tool, equipped = findBook()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (tool and hum and hum.Health > 0) then return end
	if equipped then hum:UnequipTools() else hum:EquipTool(tool) end
end
bookBtn.Activated:Connect(toggleBook)

local function refresh()
	local tool, equipped = findBook()
	panel.Visible = equipped == true
	if not panel.Visible then entry = ""; render() end
end

local function watch(container)
	if not container then return end
	container.ChildAdded:Connect(function() task.defer(refresh) end)
	container.ChildRemoved:Connect(function() task.defer(refresh) end)
end
player.CharacterAdded:Connect(function(c) watch(c) task.defer(refresh) end)
if player.Character then watch(player.Character) end
player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) end end)
watch(player:FindFirstChildOfClass("Backpack"))

local digitKeys = {}
for i = 0, 9 do
	local names = { "Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine" }
	digitKeys[Enum.KeyCode[names[i + 1]]] = tostring(i)
	digitKeys[Enum.KeyCode["Keypad" .. names[i + 1]]] = tostring(i)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then toggleBook() return end
	if not panel.Visible then return end
	local d = digitKeys[input.KeyCode]
	if d then press(d)
	elseif input.KeyCode == Enum.KeyCode.Backspace then press("DEL")
	elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then press("WRITE") end
end)

------------------------------------------------------------------ feedback
local toast = hud:WaitForChild("Toast")
local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or BLOOD
	toast.TextTransparency = 0
	task.delay(2.8, function()
		if toast.Text == text then TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1 }):Play() end
	end)
end

Remotes.Feedback.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.kind == "WriteRejected" then
		status.Text = (msg.reason == "burst") and "Your hand cramps. Wait."
			or (msg.reason == "stunned" and "You're dazed!" or "Too fast.")
	elseif msg.kind == "Written" then
		status.Text = "The ink sinks in."
	elseif msg.kind == "Death" then
		if msg.you then
			local why = {
				ink = "Your name was written. Your heart stops.",
				fall = "You fell.",
				zone = "The zone caught you.",
				afk = "You stood still too long.",
			}
			showToast(why[msg.cause] or "Your heart stops.")
		else
			showToast(string.format("Someone was eliminated!  %d left", msg.remain), Color3.fromRGB(60, 40, 120))
		end
	end
end)

Remotes.RoundState.OnClientEvent:Connect(function(s)
	actions.Visible = (s.phase == "Playing") and s.alive
	if not actions.Visible then panel.Visible = false end
end)

render()
