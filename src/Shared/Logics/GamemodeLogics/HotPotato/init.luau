local HotPotatoRoundLogic = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local isServer = RunService:IsServer()
local GameTeamService
local WeaponService
local SoundLibrary
local CharacterRenderController
local ItemAcquiredGui
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   WeaponService = require(ServerStorage.Server.Core.WeaponService)
else
   SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
   CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
   ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local HOT_POTATO_EFFECT_ID = "HotPotato"
local EXPLOSION_COUNTER = 10
local NEXT_HOLDER_DELAY = 3
local NON_HOLDER_WEAPON_LOCK_DURATION = 60 * 60 -- Outlasts the round; cleared on teardown

local explodePlayerRemote = SimpleRemotes.getEvent("ExplodePlayerPotato")
local pickupEffectStateChanged = SimpleRemotes.getEvent("PickupEffectStateChanged")

--------------------------------------------------------------------------------
-- PER-SESSION VALUES
--------------------------------------------------------------------------------

-- Server Only
local initialHolderSet = false
local currentHolder: Player? = nil
local Particles: {[Player]: Part} = {}
local Elims: {[Player]: number} = {}
-- // workspace:GetServerTimeNow() timestamp the current bomb explodes at. Shown to the holder as the HotPotato pickup effect timer; nil while no bomb is live
local bombExplodesAt: number? = nil
local nextHolderElapsed = 0
local nextHolderRoundId: number? = nil
local PerMatchDestroyerFunctions: {()->()} = {}

-- Dual-Context
local heartbeatConnection: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------

local function generateHolderLivePickupId(player: Player): string
   return `HotPotato_{player.UserId}`
end

local function clearHolderEffect(player: Player)
   PickupLibrary.removePickupEffectActive(player.UserId, generateHolderLivePickupId(player), nil, false)
end

local function lockNonHolderWeapons()
   for _, player in ipairs(CurrentGameState.getGameStateData().LivingPlayersInArena:Get()) do
      if player ~= currentHolder then
         WeaponService.applyLockOnWeapon(player, NON_HOLDER_WEAPON_LOCK_DURATION)
      end
   end
end

local function grantHolderEffect(player: Player)
   initialHolderSet = true
   currentHolder = player
   -- // A new bomb starts its countdown when first held; passing it on keeps the same explosion time
   if not bombExplodesAt then
      bombExplodesAt = workspace:GetServerTimeNow() + EXPLOSION_COUNTER
   end
   WeaponService.removeLockOnWeapon(player)
   lockNonHolderWeapons()
   PickupLibrary.setPickupEffectActive(player.UserId, generateHolderLivePickupId(player), HOT_POTATO_EFFECT_ID, bombExplodesAt)
end

local function explode(player: Player)
   local character = player.Character
   if not character then
      return
   end
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid or humanoid.Health <= 0 then
      return
   end

   clearHolderEffect(player)
   humanoid.Health = 0
   explodePlayerRemote:FireAllClients(player)

   local currentRoundData = CurrentGameState.getGameStateData().CurrentRoundData:Get()
   nextHolderElapsed = 0
   nextHolderRoundId = currentRoundData and currentRoundData.CurrentRoundId
end

local function startservercontext()
   bombExplodesAt = nil
   if heartbeatConnection then
      heartbeatConnection:Disconnect()
   end
   heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
      if bombExplodesAt and currentHolder and workspace:GetServerTimeNow() >= bombExplodesAt then
         local exploding = currentHolder
         currentHolder = nil
         bombExplodesAt = nil
         explode(exploding)
         WeaponService.applyLockOnWeapon(exploding, NON_HOLDER_WEAPON_LOCK_DURATION)
      end

      if nextHolderRoundId ~= nil then
         nextHolderElapsed += dt
         if nextHolderElapsed >= NEXT_HOLDER_DELAY then
            local roundIdAtExplosion = nextHolderRoundId
            nextHolderRoundId = nil
            nextHolderElapsed = 0

            local gameStateData = CurrentGameState.getGameStateData()
            local currentRoundData = gameStateData.CurrentRoundData:Get()
            if currentRoundData and currentRoundData.Gamemode == "HotPotato" and currentRoundData.CurrentRoundId == roundIdAtExplosion then
               local livingPlayers = gameStateData.LivingPlayersInArena:Get()
               if #livingPlayers > 0 then
                  local randomPlayer = livingPlayers[math.random(1, #livingPlayers)]
                  grantHolderEffect(randomPlayer)
               else
                  warn(`hot potato gamemode has no living players to give potato to!`)
               end
            end
         end
      end
   end)

   CombatLibrary.addAttackHitPlayerCallback(HOT_POTATO_EFFECT_ID, function(attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number)
      if attacker == currentHolder then
         clearHolderEffect(attacker)
         grantHolderEffect(victim)
         return true
      end
      return false
   end)
end

local function teardown()
   if heartbeatConnection then
      heartbeatConnection:Disconnect()
      heartbeatConnection = nil
   end

   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)

   if isServer then
      if currentHolder then
         clearHolderEffect(currentHolder)
      end
      currentHolder = nil
      bombExplodesAt = nil
      nextHolderElapsed = 0
      nextHolderRoundId = nil

      for i, p in pairs(game.Players:GetPlayers()) do
         WeaponService.removeLockOnWeapon(p)
      end

      CombatLibrary.removeAttackHitPlayerCallback(HOT_POTATO_EFFECT_ID)
   end
end

--------------------------------------------------------------------------------
-- CORE
--------------------------------------------------------------------------------

function HotPotatoRoundLogic.setup()
   if isServer then
      GameTeamService.setFreeForAll()
      startservercontext()

      local currentGameData = CurrentGameState.getGameStateData()

      local playersInArena = currentGameData.LivingPlayersInArena:Get()
      if #playersInArena > 0 then
         local randomPlayer = playersInArena[math.random(1, #playersInArena)]
         grantHolderEffect(randomPlayer)
      end

      table.insert(PerMatchDestroyerFunctions, CurrentGameState.PlayerRemovedFromArenaTasks:Add(function(player: Player)
         if player == currentHolder then
            clearHolderEffect(currentHolder)
            currentHolder = nil
            bombExplodesAt = nil
            nextHolderElapsed = 0
            nextHolderRoundId = currentGameData.CurrentRoundData:Get().CurrentRoundId
         end

         local currentLivingPlayersCount = #currentGameData.LivingPlayersInArena:Get()
         if currentLivingPlayersCount <= 1 and not (RunService:IsStudio() and #game.Players:GetPlayers() == 1) then
            local winner = currentGameData.LivingPlayersInArena:Get()[1]
            HotPotatoRoundLogic.teardown(winner)
         end
      end))

      -- Race condition failsafe: If this runs before anyone loads into the arena (meaning no one was immediately granted the bomb), then grant the bomb to the first player to load in
      table.insert(PerMatchDestroyerFunctions, CurrentGameState.PlayerAddedToArenaTasks:Add(function(player: Player)
         if not currentHolder and not initialHolderSet then
            grantHolderEffect(player)
         end
      end))

      -- // Only declare a winner if a single involved player remains; otherwise there is no winner
      table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
         local livingPlayers = currentGameData.LivingPlayersInArena:Get()
         local winner = if #livingPlayers == 1 then livingPlayers[1] else nil
         HotPotatoRoundLogic.teardown(winner)
      end))
   end
end

function HotPotatoRoundLogic.teardown(winner: Player?)
   teardown()
   if isServer then
      CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, nil)
   end
end

-- // True if removing this player would leave the round at (or below) its last-player-standing threshold
function HotPotatoRoundLogic.willKillEndRound(player: Player): boolean
   if RunService:IsStudio() and #game.Players:GetPlayers() == 1 then
      return false
   end
   local livingPlayers = CurrentGameState.getGameStateData().LivingPlayersInArena:Get()
   local remaining = 0
   for _, livingPlayer in ipairs(livingPlayers) do
      if livingPlayer ~= player then
         remaining += 1
      end
   end
   return remaining <= 1
end

if not isServer then
   -- // Holder's particle follows the replicated "HotPotato" data-only effect state instead of an onPickup/onEnd pickup logic module
   pickupEffectStateChanged.OnClientEvent:Connect(function(effectData: PickupLibrary.PickupEffectStateChangedReplicationData)
      if effectData.ClearAll then
         for _, particle in pairs(Particles) do
            ParticlesLibrary.destroy(particle)
         end
         table.clear(Particles)
         return
      end

      if effectData.classId ~= HOT_POTATO_EFFECT_ID or not effectData.userId then
         return
      end
      local player = Players:GetPlayerByUserId(effectData.userId)
      if not player then
         return
      end

      if Particles[player] then
         ParticlesLibrary.destroy(Particles[player])
         Particles[player] = nil
      end

      if effectData.active then
         Particles[player] = ParticlesLibrary.play(`{player.UserId}_HotPotato`, "HotPotato", player.Character)
         ItemAcquiredGui.acquiredItem("HotPotato")
      end
   end)

   explodePlayerRemote.OnClientEvent:Connect(function(player: Player)
      SoundLibrary.play(`{player.UserId}_HotPotato_Explode`, "Explosion", player.Character.PrimaryPart, nil, true)
      if Particles[player] then
         ParticlesLibrary.destroy(Particles[player], false)
         Particles[player] = nil
      end
      local character = CharacterRenderController.getCharacterModel(player)
      if character then
         for _, d in pairs(character:GetDescendants()) do
            if d:IsA("BallSocketConstraint") or d:IsA("Motor6D") then
               d:Destroy()
            elseif d:IsA("MeshPart") or d:IsA("Part") or d:IsA("BasePart") then
               d.Anchored = false
               d.CanCollide = true
               d.CollisionGroup = "Default"
               local randomDirection = Vector3.new(
                  math.random(-10, 10),
                  math.random(5, 15),
                  math.random(-10, 10)
               ).Unit
               local power = math.random(30, 60)
               d.AssemblyLinearVelocity = randomDirection * power
            end
         end
      end
   end)
end

return HotPotatoRoundLogic