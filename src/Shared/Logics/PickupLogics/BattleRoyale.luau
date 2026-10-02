-- STUD
-- TODO
-- Storm close starts shrinking towards this players' position. Any players who die from out of bounds damage are considered to have been killed by this player.

local BattleRoyale = {}

BattleRoyale.Disabled = true

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function BattleRoyale.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return BattleRoyale