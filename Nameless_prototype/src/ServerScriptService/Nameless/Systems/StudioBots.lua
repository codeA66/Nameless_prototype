-- StudioBots: Studio-only test dummies so mechanics can be verified solo.
-- Never runs in a live server. Bot codes are fixed so tests are repeatable.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local StudioBots = {}

-- name, code, offset from spawn, yaw (degrees; 0 = facing -Z toward spawn when placed at -Z... see below)
local LAYOUT = {
	{ name = "Facing",   code = "11111", offset = Vector3.new(0, 0, -9),  facePlayer = true },
	{ name = "Away",     code = "22222", offset = Vector3.new(6, 0, -9),  facePlayer = false },
	{ name = "Walled",   code = "33333", offset = Vector3.new(-7, 0, -9), facePlayer = true, wall = true },
	{ name = "Far",      code = "44444", offset = Vector3.new(0, 0, -30), facePlayer = true },
	{ name = "Twin",     code = "11111", offset = Vector3.new(14, 0, -12), facePlayer = true }, -- duplicate code
}

function StudioBots.init(ctx)
	if not RunService:IsStudio() then return end
	local bots = {}
	ctx.bots = bots

	local folder = Instance.new("Folder")
	folder.Name = "StudioBots"
	folder.Parent = workspace

	local function clear()
		for _, b in ipairs(bots) do
			ctx.State.alive[b] = nil
			ctx.CodeStore.clear(b)
			if b.Character then b.Character:Destroy() end
		end
		table.clear(bots)
		folder:ClearAllChildren()
	end

	local function spawnBots()
		clear()
		local origin = ctx.arenaOrigin and ctx.arenaOrigin() or Vector3.new(0, 0, 0)
		for _, spec in ipairs(LAYOUT) do
			local ok, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
			end)
			if not ok then warn("[StudioBots] " .. tostring(model)) return end
			model.Name = "Bot_" .. spec.name
			local pos = origin + spec.offset + Vector3.new(0, 3, 0)
			local lookAt = spec.facePlayer and Vector3.new(origin.X, pos.Y, origin.Z) or (pos + (pos - Vector3.new(origin.X, pos.Y, origin.Z)))
			model:PivotTo(CFrame.lookAt(pos, lookAt))
			model.HumanoidRootPart.Anchored = true
			model.Parent = folder

			local fake = { Name = model.Name, Character = model, Parent = folder, IsBot = true }
			ctx.dress(fake, model)
			ctx.CodeStore.set(fake, spec.code)
			ctx.State.alive[fake] = true
			table.insert(bots, fake)

			if spec.wall then
				local w = Instance.new("Part")
				w.Name = "TestWall"
				w.Anchored = true
				w.Size = Vector3.new(6, 8, 1)
				w.Color = Color3.fromRGB(60, 60, 66)
				w.CFrame = CFrame.lookAt(pos - (pos - Vector3.new(origin.X, pos.Y, origin.Z)).Unit * 2.5, Vector3.new(origin.X, pos.Y, origin.Z))
				w.Parent = folder
			end
		end
	end
	ctx.spawnStudioBots = spawnBots

	table.insert(ctx.Hooks.onRoundStart, spawnBots)
	table.insert(ctx.Hooks.onRoundEnd, clear)
end

return StudioBots
