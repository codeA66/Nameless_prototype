-- Audio + FX: positional one-shots and small particle bursts.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Audio = {}

function Audio.init(ctx)
	local bank = SoundService:WaitForChild("NamelessSounds")

	function ctx.sfx(name, where)
		local src = bank:FindFirstChild(name)
		if not src or not where or not where.Parent then return end
		local s = src:Clone()
		s.Looped = false
		s.PlaybackSpeed = 0.94 + math.random() * 0.12
		s.Parent = where
		s:Play()
		Debris:AddItem(s, 6)
	end

	function ctx.hitFx(pos)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(pos)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 120))
		e.LightEmission = 0.6
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(12, 22)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 0
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Parent = p
		p.Parent = workspace
		e:Emit(26)
		Debris:AddItem(p, 1.5)
	end
end

return Audio
