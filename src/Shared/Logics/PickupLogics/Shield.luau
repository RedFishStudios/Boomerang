-- STUD
-- TODO
-- Gives the player an extra hit. If the player is hit, the shield is removed.

local Shield = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function Shield.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return Shield