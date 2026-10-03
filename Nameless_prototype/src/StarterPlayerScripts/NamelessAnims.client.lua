-- Nameless :: procedural character animations (client)
-- Motor6D.C0 is read-only for scripts now, so every client layers poses on top of
-- the Animator by multiplying Motor6D.Transform each frame (after animation runs).
-- No uploaded animation assets are needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Remotes = ReplicatedStorage:WaitForChild("Nameless"):WaitForChild("Remotes")

local rad = math.rad

-- Each clip: list of keyframes { t, { Joint = {x, y, z} degrees } }. Joints not listed = 0.
-- Axis notes (R15): +X on a hip/shoulder swings the limb FORWARD; -X on Waist/Neck leans FORWARD;
-- -X on a knee bends it; +Z on RightShoulder / -Z on LeftShoulder lifts the arm sideways.
local CLIPS = {
	Kick = {
		{ 0.00, {} },
		{ 0.11, { RightHip = { -40, 0, 0 }, RightKnee = { -55, 0, 0 }, Waist = { -12, 0, 0 },
			RightShoulder = { -35, 0, 10 }, LeftShoulder = { 35, 0, -10 }, LeftKnee = { -12, 0, 0 } } },
		{ 0.19, { RightHip = { 100, 0, 0 }, RightKnee = { 0, 0, 0 }, Waist = { 20, 0, 0 }, Neck = { -10, 0, 0 },
			RightShoulder = { -20, 0, 75 }, LeftShoulder = { -20, 0, -75 }, LeftKnee = { -18, 0, 0 }, LeftHip = { -10, 0, 0 } } },
		{ 0.34, { RightHip = { 95, 0, 0 }, RightKnee = { -5, 0, 0 }, Waist = { 18, 0, 0 }, Neck = { -10, 0, 0 },
			RightShoulder = { -20, 0, 70 }, LeftShoulder = { -20, 0, -70 }, LeftKnee = { -18, 0, 0 }, LeftHip = { -10, 0, 0 } } },
		{ 0.58, {} },
	},
	Write = {
		{ 0.00, {} },
		{ 0.10, { LeftShoulder = { 70, 0, 25 }, LeftElbow = { 30, 0, 0 }, RightShoulder = { 60, 0, -15 }, Neck = { -18, 0, 0 } } },
		{ 0.20, { LeftShoulder = { 65, 0, 15 }, LeftElbow = { 40, 0, 0 }, RightShoulder = { 60, 0, -15 }, Neck = { -18, 0, 0 } } },
		{ 0.30, { LeftShoulder = { 72, 0, 30 }, LeftElbow = { 28, 0, 0 }, RightShoulder = { 60, 0, -15 }, Neck = { -18, 0, 0 } } },
		{ 0.40, { LeftShoulder = { 65, 0, 15 }, LeftElbow = { 40, 0, 0 }, RightShoulder = { 60, 0, -15 }, Neck = { -18, 0, 0 } } },
		{ 0.62, {} },
	},
	HeartAttack = { -- the server ragdolls the body at ~1.1 s
		{ 0.00, {} },
		{ 0.25, { RightShoulder = { 85, 0, -40 }, RightElbow = { 60, 0, 0 }, LeftShoulder = { 60, 0, 35 }, Waist = { -10, 0, 0 }, Neck = { 15, 0, 0 } } },
		{ 0.70, { RightShoulder = { 90, 0, -45 }, RightElbow = { 70, 0, 0 }, LeftShoulder = { 70, 0, 40 }, Waist = { -38, 0, 0 }, Neck = { -28, 0, 0 },
			RightKnee = { -25, 0, 0 }, LeftKnee = { -25, 0, 0 }, RightHip = { 15, 0, 0 }, LeftHip = { 15, 0, 0 } } },
		{ 1.30, { RightShoulder = { 90, 0, -45 }, RightElbow = { 70, 0, 0 }, LeftShoulder = { 70, 0, 40 }, Waist = { -45, 0, 0 }, Neck = { -30, 0, 0 },
			RightKnee = { -40, 0, 0 }, LeftKnee = { -40, 0, 0 }, RightHip = { 25, 0, 0 }, LeftHip = { 25, 0, 0 } }, hold = true },
	},
}

local active = {} -- list of { char, clip, t0, motors }

local function motorsOf(char)
	-- Newer avatars animate through AnimationConstraint joints; older rigs use Motor6D.
	-- Both expose .Transform, so collect whichever joint is active for each name.
	local m = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("AnimationConstraint") and d.Enabled then
			m[d.Name] = d
		elseif d:IsA("Motor6D") and not (m[d.Name] and m[d.Name]:IsA("AnimationConstraint")) then
			m[d.Name] = d
		end
	end
	return m
end

local function sample(clip, t)
	local last = clip[#clip]
	if t >= last[1] then return last[2], last.hold ~= true and t > last[1] end
	for i = 1, #clip - 1 do
		local a, b = clip[i], clip[i + 1]
		if t >= a[1] and t <= b[1] then
			local k = (t - a[1]) / (b[1] - a[1])
			k = k * k * (3 - 2 * k) -- smoothstep
			local out = {}
			for j, v in pairs(a[2]) do out[j] = { v[1] * (1 - k), v[2] * (1 - k), v[3] * (1 - k) } end
			for j, v in pairs(b[2]) do
				local o = out[j] or { 0, 0, 0 }
				out[j] = { o[1] + v[1] * k, o[2] + v[2] * k, o[3] + v[3] * k }
			end
			return out, false
		end
	end
	return {}, true
end

-- white swoosh behind the kicking foot
local function kickTrail(char)
	local foot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")
	if not foot then return end
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.4, 0); a0.Parent = foot
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.4, 0); a1.Parent = foot
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.18
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 170, 210))
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	tr.LightEmission = 0.8
	tr.FaceCamera = true
	tr.WidthScale = NumberSequence.new(1, 0.2)
	tr.Enabled = false
	tr.Parent = foot
	task.delay(0.1, function() tr.Enabled = true end)
	task.delay(0.38, function() tr.Enabled = false end)
	task.delay(0.7, function() tr:Destroy() a0:Destroy() a1:Destroy() end)
end

local function play(char, name)
	local clip = CLIPS[name]
	if not (clip and char and char.Parent) then return end
	if not char:FindFirstChild("UpperTorso") then return end -- R15 only
	-- one clip per character at a time
	for i = #active, 1, -1 do if active[i].char == char then table.remove(active, i) end end
	table.insert(active, { char = char, clip = clip, t0 = os.clock(), motors = motorsOf(char) })
	if name == "Kick" then kickTrail(char) end
end

Remotes.Feedback.OnClientEvent:Connect(function(m)
	if type(m) == "table" and m.kind == "Anim" and typeof(m.char) == "Instance" then
		play(m.char, m.name)
	end
end)

RunService.PreSimulation:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		local a = active[i]
		if not a.char.Parent then
			table.remove(active, i)
		else
			local pose, done = sample(a.clip, now - a.t0)
			if done then
				table.remove(active, i)
			else
				for joint, ang in pairs(pose) do
					local m = a.motors[joint]
					if m and m.Parent and m.Enabled then
						m.Transform = m.Transform * CFrame.Angles(rad(ang[1]), rad(ang[2]), rad(ang[3]))
					end
				end
			end
		end
	end
end)
