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

local isServer = RunService:IsServer()
local GameTeamService
local SoundLibrary
local CharacterRenderController
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
else
   SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
   CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local HOT_POTATO_EFFECT_ID = "HotPotato"
local EXPLOSION_COUNTER = 10
local NEXT_HOLDER_DELAY = 3

local explodePlayerRemote = SimpleRemotes.getEvent("ExplodePlayerPotato")
local pickupEffectStateChanged = SimpleRemotes.getEvent("PickupEffectStateChanged")

--------------------------------------------------------------------------------
-- PER-SESSION VALUES
--------------------------------------------------------------------------------

local currentHolder: Player? = nil
local Particles: {[Player]: Part} = {}
local Kills: {[Player]: number} = {}
local elapsed = 0
local heartbeatConnection: RBXScriptConnection? = nil
local nextHolderElapsed = 0
local nextHolderRoundId: number? = nil
local PerMatchDestroyerFunctions: {()->()} = {}

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------

local function generateHolderLivePickupId(player: Player): string
   return `HotPotato_{player.UserId}`
end

local function clearHolderEffect(player: Player)
   PickupLibrary.removePickupEffectActive(player.UserId, generateHolderLivePickupId(player), nil, false)
end

local function grantHolderEffect(player: Player)
   currentHolder = player
   PickupLibrary.setPickupEffectActive(player.UserId, generateHolderLivePickupId(player), HOT_POTATO_EFFECT_ID)
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

local function start()
   elapsed = 0
   if heartbeatConnection then
      heartbeatConnection:Disconnect()
   end
   heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
      elapsed += dt
      if elapsed >= EXPLOSION_COUNTER and currentHolder then
         local exploding = currentHolder
         currentHolder = nil
         explode(exploding)
      end

      if nextHolderRoundId ~= nil then
         nextHolderElapsed += dt
         if nextHolderElapsed >= NEXT_HOLDER_DELAY then
            local roundIdAtExplosion = nextHolderRoundId
            nextHolderRoundId = nil
            nextHolderElapsed = 0
            elapsed = 0

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
   if currentHolder then
      clearHolderEffect(currentHolder)
   end
   currentHolder = nil
   elapsed = 0
   nextHolderElapsed = 0
   nextHolderRoundId = nil

   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)

   CombatLibrary.removeAttackHitPlayerCallback(HOT_POTATO_EFFECT_ID)
end

--------------------------------------------------------------------------------
-- CORE
--------------------------------------------------------------------------------

function HotPotatoRoundLogic.setup()
   if isServer then
      GameTeamService.setFreeForAll()
      start()

      local currentGameData = CurrentGameState.getGameStateData()
      local players = currentGameData.LivingPlayersInArena:Get()
      local randomPlayer = players[math.random(1, #players)]
      if randomPlayer then
         grantHolderEffect(randomPlayer)
      end

      table.insert(PerMatchDestroyerFunctions, CurrentGameState.getGameStateData().LivingPlayersInArena:Subscribe(function(livingPlayers: {Player})
         if #livingPlayers <= 1 and not (RunService:IsStudio() and #game.Players:GetPlayers() == 1) then
            local winner = livingPlayers[1]
            HotPotatoRoundLogic.teardown(winner)
         end
      end))
   end
end

function HotPotatoRoundLogic.teardown(winner: Player?)
   if isServer then
      teardown()
      CurrentGameState.RoundFinishedTasks:Execute("parallel", winner, winner and (winner.Name .. " won!") or "No winner")
   end
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