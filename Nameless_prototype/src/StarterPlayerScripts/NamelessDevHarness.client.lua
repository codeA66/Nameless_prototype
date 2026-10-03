-- Studio-only test harness. Does nothing in live servers.
-- Set PlayerGui attribute "DevCmd" to "Remote|arg1|arg2|nonce" to fire a remote as this client.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local player = game:GetService("Players").LocalPlayer
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Nameless"):WaitForChild("Remotes")
local pg = player:WaitForChild("PlayerGui")

pg:GetAttributeChangedSignal("DevCmd"):Connect(function()
	local cmd = pg:GetAttribute("DevCmd")
	if type(cmd) ~= "string" then return end
	local parts = string.split(cmd, "|")
	local r = Remotes:FindFirstChild(parts[1])
	local count = tonumber(parts[3]) or 1
	if r and r:IsA("RemoteEvent") then
		for _ = 1, count do
			if parts[2] == "" then r:FireServer() else r:FireServer(parts[2]) end
		end
	end
end)

-- Mirror feedback into an attribute so tests can read it
local log = {}
Remotes.Feedback.OnClientEvent:Connect(function(m)
	if type(m) == "table" and m.kind ~= "Read" then
		table.insert(log, tostring(m.kind) .. (m.reason and (":" .. m.reason) or ""))
		if #log > 40 then table.remove(log, 1) end
		pg:SetAttribute("DevLog", table.concat(log, ","))
	end
end)
