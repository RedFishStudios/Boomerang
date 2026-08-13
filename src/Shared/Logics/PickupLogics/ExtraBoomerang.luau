-- STUD
-- TODO
-- Gives the player two boomerangs instead of one

local ExtraBoomerang = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function ExtraBoomerang.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return ExtraBoomerang