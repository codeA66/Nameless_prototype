-- Nameless :: music, heartbeat, win screen (client)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Nameless"):WaitForChild("Remotes")
local bank = SoundService:WaitForChild("NamelessSounds")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("NamelessHUD")

local music = bank.Music:Clone(); music.Parent = SoundService
local heart = bank.Heartbeat:Clone(); heart.Volume = 0; heart.Parent = SoundService
music:Play()
heart:Play()

-- heartbeat rises with the number of people reading you
task.spawn(function()
	while true do
		task.wait(0.15)
		local n = shared.NamelessReadCount or 0
		local vol = (n > 0) and math.min(1.6, 0.6 + n * 0.35) or 0
		heart.Volume = heart.Volume + (vol - heart.Volume) * 0.35
		heart.PlaybackSpeed = 1 + math.min(n, 4) * 0.12
		music.Volume = 0.35 - math.min(0.25, n * 0.08) -- duck the music
	end
end)

-- win banner
local banner = Instance.new("TextLabel")
banner.Name = "WinBanner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.4)
banner.Size = UDim2.new(0, 600, 0, 90)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 64
banner.TextColor3 = Color3.fromRGB(255, 214, 64)
banner.TextStrokeTransparency = 0
banner.TextStrokeColor3 = Color3.fromRGB(40, 20, 60)
banner.Text = ""
banner.Visible = false
banner.Parent = hud
local bscale = Instance.new("UIScale"); bscale.Parent = banner

local shownFor
Remotes.RoundState.OnClientEvent:Connect(function(s)
	if s.phase == "Ended" and shownFor ~= "Ended" then
		shownFor = "Ended"
		if s.alive and s.extra and s.extra.winner then
			banner.Text = "YOU SURVIVED!"
			local win = bank.Win:Clone(); win.Parent = SoundService; win:Play()
			game:GetService("Debris"):AddItem(win, 8)
		else
			banner.Text = (s.extra and s.extra.winner) and "Someone survived..." or "No one survived."
		end
		banner.Visible = true
		bscale.Scale = 0.3
		TweenService:Create(bscale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	elseif s.phase ~= "Ended" then
		shownFor = nil
		banner.Visible = false
	end
end)

-- one-shot cue for every elimination
Remotes.Feedback.OnClientEvent:Connect(function(m)
	if type(m) == "table" and m.kind == "Death" and m.you then
		heart.Volume = 0
	end
end)
