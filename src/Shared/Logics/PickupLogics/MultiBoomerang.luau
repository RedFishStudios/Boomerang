-- STUD
-- TODO
-- Boomerang splits into multiple boomerangs at the end of the next throw

local MultiBoomerang = {}

MultiBoomerang.Disabled = true

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function MultiBoomerang.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return MultiBoomerang