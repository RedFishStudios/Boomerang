local Speedup = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)

local isServer = RunService:IsServer()

local WeaponService

if isServer then
   WeaponService = require(game.ServerStorage.Server.Core.WeaponService)
end

local TIME_LASTS = 15
local SPEED_MULTIPLIER = 1.5

function Speedup.onPickup(player: Player, startedAt: number?): number?
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + TIME_LASTS
   if isServer then
      -- Server context
      local character = player.Character
      if character then
         local doNotApplyNow = WeaponService.isAiming(player)
         print(doNotApplyNow)
         PlayerStatsLibrary.setStat(player, "RunSpeed", GlobalConfig.DefaultWalkSpeed * SPEED_MULTIPLIER, doNotApplyNow, true)
      end
   else
      -- Client context
      -- Maybe a sound, gui etc
      SoundLibrary.play(nil, "PickupGeneric", nil, nil, nil)
      if player == game.Players.LocalPlayer then
         PlayerStatsLibrary.setStat(player, "RunSpeed", GlobalConfig.DefaultWalkSpeed * SPEED_MULTIPLIER, nil, true)
      end
   end

   return endsAt
end

function Speedup.onEnd(player: Player)
   if isServer then
      -- Server context
      local character = player.Character
      if character then
         local doNotApplyNow = WeaponService.isAiming(player)
         PlayerStatsLibrary.setStat(player, "RunSpeed", GlobalConfig.DefaultWalkSpeed * SPEED_MULTIPLIER, doNotApplyNow, true)
      end
   else
      -- Client context
   end
end

return Speedup :: PickupLibrary.PickupLogic