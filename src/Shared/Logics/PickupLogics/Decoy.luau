-- STUD
-- TODO
-- Spawns a wandering decoy copy of the player. It does not participate in combat, but it can be affected by other effects and can die, just like a player.
-- Good god lord that's like, "create an extremely advanced system just for this one thing"

local Decoy = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function Decoy.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return Decoy