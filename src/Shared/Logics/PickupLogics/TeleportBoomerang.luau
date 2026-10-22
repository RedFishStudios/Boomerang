-- // While active, the player can teleport to their boomerang with the on-screen button (T-108: UsePickupButtons GUI) while it is
-- // out of their hand. One use: the effect ends when they teleport (or when it times out). It no longer triggers by itself.

local TeleportBoomerang = {}

local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()
local PICKUP_CLASS_ID = script.Name

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ParticlesLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))
local GlobalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local PickupLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("PickupLibrary"))

local EFFECT_DURATION_SECONDS = GlobalConfig.GenericEffectTimeout

local CharacterRenderController
if not isServer then
   CharacterRenderController = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Core"):WaitForChild("CharacterRenderController"))
end

local particles = {} -- {[Player]: Part}

TeleportBoomerang.UseButton = true
TeleportBoomerang.ConsumedOnUse = true

-- // T-108: usable while the player's boomerang is out of their hand
function TeleportBoomerang.canUse(player: Player): boolean
   return (PickupLibrary.getWeaponOnField(player)) ~= nil
end

-- // T-108: the button was pressed: teleport to the boomerang, then the effect is used up
function TeleportBoomerang.onUse(player: Player)
   if not isServer then
      return
   end
   local position = PickupLibrary.getWeaponOnField(player)
   local character = player.Character
   if not position or not character or not character.PrimaryPart then
      return
   end
   -- // At the boomerang's spot, at flight height (where the boomerang's physics is), like the old end-of-throw teleport
   local destination = Vector3.new(position.X, GlobalConfig.BoomerangFlightHeight, position.Z)
   character:PivotTo(CFrame.new(destination) * character:GetPivot().Rotation)
   -- // Required lazily to avoid a load-time cycle (PickupService requires this module)
   local PickupService = require(game:GetService("ServerStorage").Server.Core.PickupService)
   PickupService.triggerEnd(player, PICKUP_CLASS_ID)
end

function TeleportBoomerang.onPickup(player: Player, startedAt: number?): number?
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS

   if not isServer then
      local character = CharacterRenderController.getCharacterModel(player)
      if not character then
         return endsAt
      end

      local particle = ParticlesLibrary.play(`{player.UserId}_Forcefield`, "Forcefield", character.PrimaryPart, 1)
      particles[player] = particle
   end

   return endsAt
end

function TeleportBoomerang.onEnd(player: Player)
   if isServer then
      return
   end
   if particles[player] then
      particles[player]:Destroy()
      particles[player] = nil
   end

   local character = CharacterRenderController.getCharacterModel(player)
   if not character then
      return
   end
   ParticlesLibrary.emit(`{player.UserId}_ForcefieldBreak`, "ForcefieldBreak", character.PrimaryPart, 1)
end

return TeleportBoomerang
