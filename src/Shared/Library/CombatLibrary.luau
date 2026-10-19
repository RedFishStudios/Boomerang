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

-- // Lazily required: ArenaService (required by RoundCyclingService) also requires CombatLibrary, so requiring
-- // RoundCyclingService eagerly here would be a load-time circular require. Safe to resolve on first real use.
local RoundCyclingService
local function getRoundCyclingService()
   if not RoundCyclingService and isServer then
      RoundCyclingService = require(game:GetService("ServerStorage").Server.Core.RoundCyclingService)
   end
   return RoundCyclingService
end

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // What became of an attack: "Hit" (damage applied on the server), "Immune" (dash / spawn protection), "Blocked" (a shield took it),
-- // "Interrupted" (a gamemode callback handled it), "Ignored" (no humanoid, no round, or a mode where hits do nothing)
export type HitResult = "Hit" | "Immune" | "Blocked" | "Interrupted" | "Ignored"

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

function CombatLibrary.applyDamageToHumanoid(player: Player, humanoid: Humanoid, damageAmount: number, killer: Player?, causeLabel: string?)
   humanoid:TakeDamage(damageAmount)
   if humanoid.Health <= 0 then
      CombatLibrary.notifyDeathReason(player, killer, causeLabel)
   end
end

-- // Single chokepoint for the death screen notification; skipped when this player's death is what ends the round (PreIntermission covers that case instead)
function CombatLibrary.notifyDeathReason(player: Player, killer: Player?, causeLabel: string?)
   local roundCyclingService = isServer and getRoundCyclingService()
   if roundCyclingService and roundCyclingService.willKillEndRound(player) then
      return
   end
   playerDeathReasonRemote:FireClient(player, killer and killer.UserId or nil, causeLabel)
end

function CombatLibrary.addAttackHitPlayerCallback(key: string, callback: attackHitPlayerCallback)
   attackHitPlayerCallbacks[key] = callback
end

function CombatLibrary.removeAttackHitPlayerCallback(key: string)
   attackHitPlayerCallbacks[key] = nil
end

-- // The slash and kill sound are played by the server only (they replicate to every client), so a client can never show a hit the
-- // server rejected. Returns what became of the attack so callers (e.g. a boomerang's energy cost) can react to it.
function CombatLibrary.attackHitPlayer(attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number, doNotPlaySliceEffect: boolean?): HitResult
   if HitboxLibrary.isImmunized(victim) then
      return "Immune"
   end
   local humanoid = victimHumanoid or getHumanoid(victim)
   if not humanoid then
      return "Ignored"
   end

   if PickupLibrary.hasPickupEffectActive(victim.UserId, "Shield") then
      if isServer then
         PickupLibrary.removePickupEffectActiveByClassId(victim.UserId, "Shield", PickupCancelCodeEnum.ShieldBroken, false)
      end
      return "Blocked"
   end

   for k, v in pairs(attackHitPlayerCallbacks) do
      local attackInterruptedByCallback = v(attacker, attackerToolId, victim, humanoid, damageAmount)
      if attackInterruptedByCallback then
         return "Interrupted"
      end
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData
   if not currentRoundData or not currentRoundData:Get() then
      return "Ignored"
   end
   local currentGamemode = currentRoundData:Get().Gamemode
   if currentGamemode == "HotPotato" then
      return "Ignored"
   end

   if not isServer then
      return "Hit" -- // Clients never play the effect or apply damage themselves
   end

   if not doNotPlaySliceEffect then
      local victimRootPart = humanoid.Parent and (humanoid.Parent :: Model).PrimaryPart
      if victimRootPart then
         -- // One id per hit, so the clients' repeat-play guard can never swallow a real hit's effect
         local eventId = `{(if attacker then attacker.UserId else 0)}_vs_{victim.UserId}_{workspace:GetServerTimeNow()}`
         SoundLibrary.play(eventId, Sounds.Data.Kill.Name, victimRootPart, nil, true)
         ParticlesLibrary.emit(eventId, "Slash", victimRootPart.Position, 1)
      end
   end

   if attacker and attackerToolId then
      CombatLibrary.applyDamageToHumanoid(victim, humanoid, 10000, attacker, nil)
      CombatLibrary.PlayerKilledPlayerTasks:Execute("parallel", attacker, victim, attackerToolId)
   else
      CombatLibrary.applyDamageToHumanoid(victim, humanoid, 10000, nil, "Unknown")
   end
   return "Hit"
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CombatLibrary.init()
end

return CombatLibrary