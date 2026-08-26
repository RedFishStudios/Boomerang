-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local CombatLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local PickupCancelCodeEnum = require(ReplicatedStorage.Shared.Constants.Enums.PickupCancelCodes)

local playerDeathReasonRemote = SimpleRemotes.getEvent("PlayerDeathReason")

local isServer = RunService:IsServer()

local PickupService
if isServer then
   PickupService = require(game:GetService("ServerStorage").Server.Core.PickupService)
end

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type attackHitPlayerCallback = (attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number) -> (boolean)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local attackHitPlayerCallbacks: {[string]: attackHitPlayerCallback} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CombatLibrary.PlayerKilledPlayerTasks = TasksList.new() :: TasksList.TasksList<(killer: Player, victim: Player, weaponId: string) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character then
		return character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CombatLibrary.applyDamageToHumanoid(player: Player, humanoid: Humanoid, damageAmount: number, deathCause: string)
   humanoid:TakeDamage(damageAmount)
   if humanoid.Health <= 0 then
      playerDeathReasonRemote:FireClient(player, deathCause)
   end
end

function CombatLibrary.addAttackHitPlayerCallback(key: string, callback: attackHitPlayerCallback)
   attackHitPlayerCallbacks[key] = callback
end

function CombatLibrary.removeAttackHitPlayerCallback(key: string)
   attackHitPlayerCallbacks[key] = nil
end

function CombatLibrary.attackHitPlayer(attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number, doNotPlaySliceEffect: boolean?)
   warn(`damaged player called`)
   local eventId = `{(if attacker then attacker.UserId else 0)}_vs_{victim.UserId}`

   if HitboxLibrary.isImmunized(victim) then
      print("CombatLibrary.damagePlayer: victim is immunized")
      return
   end
   local humanoid = victimHumanoid or getHumanoid(victim)
   if not humanoid then
      return
   end
   
   if PickupLibrary.hasPickupEffectActive(victim.UserId, "Shield") then
      if isServer then
         PickupLibrary.removePickupEffectActiveByClassId(victim.UserId, "Shield", PickupCancelCodeEnum.ShieldBroken, false)
      end
      return
   end

   for k, v in pairs(attackHitPlayerCallbacks) do
      local attackInterruptedByCallback = v(attacker, attackerToolId, victim, humanoid, damageAmount)
      if attackInterruptedByCallback then
         return
      end
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData
   if not currentRoundData or not currentRoundData:Get() then
      return
   end
   local currentGamemode = currentRoundData:Get().Gamemode
   if currentGamemode == "HotPotato" then
      return
   end

   if not doNotPlaySliceEffect then
      SoundLibrary.play(eventId, Sounds.Data.Kill.Name, victimHumanoid.Parent.PrimaryPart, nil, true)
      ParticlesLibrary.emit(eventId, "Slash", victimHumanoid.Parent.PrimaryPart.Position, 1)
   end

   if isServer then
      if attacker and attackerToolId then
         CombatLibrary.applyDamageToHumanoid(victim, humanoid, 10000, `Killed by {attacker.DisplayName}`)
         CombatLibrary.PlayerKilledPlayerTasks:Execute("parallel", attacker, victim, attackerToolId)
      else
         CombatLibrary.applyDamageToHumanoid(victim, humanoid, 10000, `Killed by environment`)
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CombatLibrary.init()
end

return CombatLibrary