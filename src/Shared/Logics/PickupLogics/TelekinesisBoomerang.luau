-- STUD
-- TODO
-- Player can control boomerang movement within a short radius
-- TODO: system for this?

local TelekinesisBoomerang = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

function TelekinesisBoomerang.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
   else
      -- Client context
      -- Maybe a sound, gui etc
   end
end

return TelekinesisBoomerang