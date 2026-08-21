local HomingBoomerang = {}

HomingBoomerang.Disabled = true

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

local isServer = RunService:IsServer()

function HomingBoomerang.onPickup(player: Player, timestamp: number)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

function HomingBoomerang.onEnd(player: Player, timestamp: number)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return HomingBoomerang