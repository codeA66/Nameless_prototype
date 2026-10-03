-- Shared, non-secret configuration. NEVER put player codes here.
local Config = {}

Config.GameName = "Nameless"
Config.NotebookName = "Ledger" -- change this one line to rename the notebook

Config.CodeLength = 5
Config.MinPlayers = 6
Config.MinPlayersStudio = 1 -- lets you test solo in Studio
Config.MaxPlayers = 20

Config.IntermissionTime = 10
Config.CodeEntryTime = 25

-- Sight
Config.AlwaysShowPlates = true -- true: every plate always shows its code on its FRONT face.
                               -- false: server only reveals a code to viewers who are in front,
                               -- in range and in line of sight (exploit-proof mode).
Config.ReadDistance = 14        -- studs; slightly larger than kick range
Config.ReadHalfAngleTarget = 55 -- viewer must be inside this cone in front of the target's chest
Config.ReadHalfAngleViewer = 40 -- target must be inside this cone of the viewer's look direction
Config.VisionHz = 8

-- Notebook
Config.WriteCooldown = 0.75
Config.WriteBurstLimit = 6      -- max writes per WriteBurstWindow seconds
Config.WriteBurstWindow = 6

-- Kick
Config.KickRange = 8
Config.KickCooldown = 6
Config.KickStun = 0            -- no stun: a kick only knocks you back, you can move and write right away
Config.KickPushDistance = 3   -- studs the target slides (about 2-3 floor tiles)
Config.KickPushTime = 0.2     -- seconds the push lasts, then they stop dead
Config.KickLift = 6           -- tiny hop so the hit reads clearly

-- Round flow
Config.RoundTime = 330          -- hard cap; the zone forces an ending well before this
Config.FallDeathY = -4          -- below this (the canal) = death
Config.FallDeathHeight = 17.5   -- a drop longer than this = death (scaffold top, not normal roofs)
Config.AfkTime = 90             -- seconds without moving during a round = eliminated

-- Shrinking zone
Config.ZoneStartRadius = 118    -- starts fully OUTSIDE the map (corners are ~107 studs out)
Config.ZoneFirstDelay = 35
Config.ZoneGrace = 5            -- seconds you can survive outside
Config.ZoneStages = {           -- radius, shrink seconds, hold seconds
	{ 62, 20, 25 },
	{ 42, 18, 25 },
	{ 26, 16, 25 },
	{ 14, 14, 25 },
	{ 6, 12, 60 },
}

return Config
