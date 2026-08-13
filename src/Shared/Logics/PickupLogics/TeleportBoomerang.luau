-- STUD
-- TODO
-- Player teleports to the next boomerang they throw

local TeleportBoomerang = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function TeleportBoomerang.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return TeleportBoomerang