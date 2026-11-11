--@script:server
-- Server entry point for the UI's data: AFK toggle, quests and the Stats counters. Equipped cosmetics, taunts and kill
-- effects start from their own scripts (StartInventory, StartTaunts, StartKillEffects).

local Afk = require(script.Parent:WaitForChild("Afk"))
local Quests = require(script.Parent:WaitForChild("Quests"))
local Stats = require(script.Parent:WaitForChild("Stats"))

Afk.start()
Quests.start()
Stats.start()

print("[BoomerangUI] server started")
