local Speedup = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)

local isServer = RunService:IsServer()

local TIME_LASTS = 5
local SPEED_MULTIPLIER = 1.5

function Speedup.onPickup(player: Player, startedAt: number?): number?
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + TIME_LASTS
   if isServer then
      -- Server context
      local character = player.Character
      if character then
         PlayerStatsLibrary.setStat(player, "Speed", GlobalConfig.DefaultWalkSpeed * SPEED_MULTIPLIER, true)
      end
   else
      -- Client context
      -- Maybe a sound, gui etc
      SoundLibrary.play(nil, "PickupGeneric", nil, nil, nil)
      if player == game.Players.LocalPlayer then
         PlayerStatsLibrary.setStat(player, "Speed", GlobalConfig.DefaultWalkSpeed * SPEED_MULTIPLIER, true)
      end
   end

   return endsAt
end

function Speedup.onEnd(player: Player)
   if isServer then
      -- Server context
      local character = player.Character
      if character then
         PlayerStatsLibrary.setStat(player, "Speed", GlobalConfig.DefaultWalkSpeed)
      end
   else
      -- Client context
   end
end

function Speedup.simulateActivation(player: Player, activationTime: number): number?
   if isServer then
      warn(`simulate activation is only for client contexts`)
      return false, nil
   else
      return Speedup.onPickup(player, activationTime)
   end
end

return Speedup :: PickupLibrary.PickupLogic