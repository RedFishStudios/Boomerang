local ElectricBoomerang = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local ExplosiveBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ExplosiveBoomerang)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

local isServer = RunService:IsServer()

local function applyZapped(player: Player)
   if not isServer then
      return
   end
end

function ElectricBoomerang.onPickup()
   if isServer then
      -- Server context
   else
      -- Client context
   end
end

function ElectricBoomerang.onEnd()
   if isServer then
      -- Server context
   else
      -- Client context
   end
end

return ElectricBoomerang