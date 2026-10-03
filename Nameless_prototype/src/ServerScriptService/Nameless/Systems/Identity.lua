-- Identity: anonymity + chest plate. Players keep their own Roblox avatar.
-- The plate is a BLANK part on the server; digits are drawn only on clients.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Identity = {}

local PAPER = Color3.fromRGB(242, 238, 226)

local function weldTo(part, base, offset)
	part.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = base, part
	w.Parent = part
end

local function accessoryPart(name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then p.Shape = shape end
	p.CanCollide, p.CanTouch, p.Massless = false, false, true
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

function Identity.init(ctx)
	ctx.plates = {} -- [Player] = BasePart (server-side reference only)

	local function dress(player, char)
		local hum = char:WaitForChild("Humanoid", 10)
		local head = char:WaitForChild("Head", 10)
		local torso = char:WaitForChild("UpperTorso", 3) or char:FindFirstChild("Torso")
		if not (hum and head and torso) then return end

		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0
		hum.HealthDisplayDistance = 0
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false -- ragdoll is handled on death

		-- keep the player's own avatar: wait for it to finish loading, because
		-- body packages can replace the torso (which would drop the plate weld)
		if typeof(player) == "Instance" and not player:HasAppearanceLoaded() then
			local done = false
			local c = player.CharacterAppearanceLoaded:Connect(function() done = true end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 6 and char.Parent do task.wait(0.1) end
			c:Disconnect()
		 end
		if not char.Parent then return end
		torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
		if not torso then return end
		local old = char:FindFirstChild("Plate")
		if old then old:Destroy() end

		-- the chest plate: blank, no text, no attributes
		local ts = torso.Size
		local plate = accessoryPart("Plate", Vector3.new(math.max(ts.X * 0.62, 1.1), math.max(ts.Y * 0.26, 0.42), 0.06), PAPER, Enum.Material.SmoothPlastic)
		-- pushed slightly forward so shirts / layered clothing don't cover it
		weldTo(plate, torso, CFrame.new(0, ts.Y * 0.12, -(ts.Z * 0.5 + 0.18)))
		plate.Parent = char
		ctx.plates[player] = plate
	end
	ctx.dress = dress

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char) dress(player, char) end)
		if player.Character then task.spawn(dress, player, player.Character) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(p) ctx.plates[p] = nil end)

	-- Server-side chat block (clients can't bypass by re-enabling their UI)
	local function block(ch)
		if ch:IsA("TextChannel") then
			ch.ShouldDeliverCallback = function() return false end
		end
	end
	for _, d in ipairs(TextChatService:GetDescendants()) do block(d) end
	TextChatService.DescendantAdded:Connect(block)
end

return Identity
