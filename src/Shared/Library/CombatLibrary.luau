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
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local Sounds = require(ReplicatedStorage.Shared.Constants.Sounds)
local PickupCancelCodeEnum = require(ReplicatedStorage.Shared.Constants.Enums.PickupCancelCodes)

local isServer = RunService:IsServer()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------


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

function CombatLibrary.attackHitPlayer(attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number)
   warn(`damaged player called`)
   local eventId = `{(if attacker then attacker.UserId else 0)}_vs_{victim.UserId}`

   if HitboxLibrary.isImmunized(victim) then
      print("CombatLibrary.damagePlayer: victim is immunized")
      return
   end
   local humanoid = victimHumanoid or getHumanoid(victim)
   if not humanoid then
      print(`no humanoid found`)
      return
   end
   if PickupLibrary.hasPickupEffectActive(victim.UserId, "Shield") then
      warn(`COMBAT LIBRARY - SHIELD BROKEN`)
      if isServer then
         PickupLibrary.removePickupEffectActiveByClassId(victim.UserId, "Shield", PickupCancelCodeEnum.ShieldBroken, false)
      end
      return
   end

   SoundLibrary.play(eventId, Sounds.Data.Kill.Name, victimHumanoid.Parent.PrimaryPart, nil, true)
   ParticlesLibrary.emit(eventId, "Slash", victimHumanoid.Parent.PrimaryPart.Position, 1)

   if isServer then
      humanoid:TakeDamage(damageAmount)
      if attacker and attackerToolId then
         CombatLibrary.PlayerKilledPlayerTasks:Execute("parallel", attacker, victim, attackerToolId)
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CombatLibrary.init()
end

return CombatLibrary