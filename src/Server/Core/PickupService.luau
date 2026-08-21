local PickupService = {}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaService = require(game.ServerStorage.Server.Core.ArenaService)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PickupLogics = ReplicatedStorage.Shared.Logics.PickupLogics
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PickupLogicModules = {}

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local CommandService = require(game.ServerStorage.Server.Core.CommandService)
local ChatService = require(game.ServerStorage.Server.Core.ChatService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type PickupClassId = PickupLibrary.PickupClassId
type LivePickupId = PickupLibrary.LivePickupId

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local requestUsePickup = SimpleRemotes.getEvent("PickupUsed")
local pickupReplication = SimpleRemotes.getUnreliableEvent("PickupReplication")
local livePickupReplication = SimpleRemotes.getEvent("LivePickupReplication")
local initLivePickups = SimpleRemotes.getFunction("InitLivePickups")

local availablePickupClasses: {PickupClassId} = {}

local SPAWN_INTERVAL = 5
local FAILED_SPAWN_COOLDOWN = SPAWN_INTERVAL/2
local lastSpawn = 0
local lastFailedSpawn = 0

local DESPAWN_TIME = 8
local SPAWN_THRESHOLD_DISTANCE = PickupLibrary.PICKUP_DISTANCE * 3

local maxLivePickupsPerPlayerCount = {
   [1] = 1,
   [2] = 1,
   [3] = 1,
   [4] = 2,
   [5] = 2,
   [6] = 3,
   [7] = 3,
   [8] = 4
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PickupService.PickupEffectEndedTasks = TasksList.new() :: TasksList.TasksList<(forUserId: number, livePickupId: string)->()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getMaxLivePickups(): number
   local playerCount = #Players:GetPlayers()
   return maxLivePickupsPerPlayerCount[playerCount] or 0
end

local function getLogic(pickupClassId: PickupClassId)
	if not PickupLogicModules[pickupClassId] then
      local _module = PickupLogics:FindFirstChild(pickupClassId, true)
      if not _module or not _module:IsA("ModuleScript") then
         warn(`PickupService.getLogic: Pickup logic module {pickupClassId} not found`)
         return
      end
		local module = require(_module)
		PickupLogicModules[pickupClassId] = module
	end
	return PickupLogicModules[pickupClassId]
end

local function loadAvailablePickupClasses()
   table.clear(availablePickupClasses)

   for _, descendant in ipairs(PickupLogics:GetDescendants()) do
      if not descendant:IsA("ModuleScript") then
         continue
      end

      local pickupClassId = descendant.Name
      local logic = require(descendant)
      PickupLogicModules[pickupClassId] = logic
      if logic.Disabled ~= true then
         table.insert(availablePickupClasses, pickupClassId)
      end
   end

   table.sort(availablePickupClasses)
end

local function getClassIdCaseInsensitive(insensitivePickupClassId: string)
   insensitivePickupClassId = string.lower(insensitivePickupClassId)
   for _, pickupId in ipairs(availablePickupClasses) do
      if string.lower(pickupId) == insensitivePickupClassId then
         return pickupId
      end
   end
   return nil
end

local function activatePickup(player: Player, livePickupId: LivePickupId, ...)
   local livePickup = PickupLibrary.getLivePickup(livePickupId)
   if not livePickup then
      print(`canceling pickup activation: live pickup {livePickupId} not found`)
      return
   end
   local position = livePickup.Position
   local character = player.Character
   if not character then
      print(`canceling pickup activation: player {player.Name} has no character`)
      return
   end
   if ((character.PrimaryPart.Position - position)*Vector3.new(1, 0, 1)).Magnitude > 5 then
      warn(`PickupService.activatePickup: Player {player.Name} is too far away from pickup {livePickupId}`)
      return
   end
   local pickupClassId = livePickup.ClassId
   local logic = getLogic(pickupClassId)
   if not logic then
      warn(`PickupService.activatePickup: No logic found for pickup {pickupClassId}`)
      return
   end
   if logic.canActivate and not logic.canActivate(player, ...) then
      warn(`PickupService.activatePickup: Player {player.Name} cannot activate pickup {pickupClassId}`)
      return
   end
   PickupLibrary.LivePickups[livePickupId] = nil

   local endsAt = nil
   if logic.onPickup then
      endsAt = logic.onPickup(player, ...)
      if endsAt then
         PickupLibrary.setPickupEffectActive(player.UserId, livePickupId, pickupClassId, endsAt)
      end
   end

   pickupReplication:FireAllClients(livePickupId, pickupClassId, player.UserId, workspace:GetServerTimeNow())
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PickupService.hasPickupEffectActive(player: Player, pickupClassId: string)
   return PickupLibrary.hasPickupEffectActive(player.UserId, pickupClassId)
end

function PickupService.triggerEnd(player: Player, pickupClassId: string)
   local userEffects = PickupLibrary.UserPickupEffectsActive[player.UserId]
   if not userEffects then
      return
   end
   for livePickupId, activePickupData in pairs(userEffects) do
      if activePickupData.ClassId == pickupClassId then
         PickupLibrary.removePickupEffectActive(player.UserId, livePickupId)
         PickupService.PickupEffectEndedTasks:Execute("parallel", player.UserId, livePickupId)
         if not PickupLibrary.isDataOnlyEffect(activePickupData.ClassId) then
            local logic = getLogic(activePickupData.ClassId)
            if logic and logic.onEnd then
               logic.onEnd(player)
            end
         end
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PickupService.init()
   loadAvailablePickupClasses()

   local gameStateData = GameStateLibrary.getGameStateData()

   initLivePickups.OnServerInvoke = function(_player: Player): PickupLibrary.LivePickupReplicationData
      local spawned = {}
      for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
         spawned[livePickupId] = {
            Position = livePickup.Position,
            DespawnsAt = livePickup.DespawnsAt,
         }
      end
      return {
         ClearAll = true,
         Spawned = spawned,
      }
   end

   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase)
      if gameplayPhase == GameplayPhaseEnum.LobbyVoting then
         PickupLibrary.clearAllPickupEffectsActive()
         PickupLibrary.LivePickups = {}
      end
   end)

   GameStateLibrary.RoundStartingTasks:Add(function()
      table.clear(PickupLibrary.LivePickups)

      local replicationData: PickupLibrary.LivePickupReplicationData = {
         ClearAll = true,
         Spawned = {},
      }
      local pickupSpawns = ArenaService.getPickupSpawns()
      if #pickupSpawns > 0 and #availablePickupClasses > 0 then
         local now = workspace:GetServerTimeNow()
         local startCount = 1
         for _ = 1, startCount do
            local spawn = pickupSpawns[math.random(1, #pickupSpawns)]
            local uuid = HttpService:GenerateGUID(false)
            PickupLibrary.LivePickups[uuid] = {
               ClassId = if GlobalConfig.ForceOverwritePickup then GlobalConfig.ForceOverwritePickup else availablePickupClasses[math.random(1, #availablePickupClasses)],
               DespawnsAt = now + DESPAWN_TIME,
               Position = spawn.Position,
            }
            replicationData.Spawned[uuid] = {
               Position = spawn.Position,
               DespawnsAt = now + DESPAWN_TIME,
            }
         end
      end
      livePickupReplication:FireAllClients(replicationData)
   end)

   --requestUsePickup.OnServerEvent:Connect(function(player: Player, livePickupId: LivePickupId, ...)
   --   activatePickup(player, livePickupId, ...)
   --end)

   RunService.Heartbeat:Connect(function()
      local now = workspace:GetServerTimeNow()
      local roundActive = gameStateData.CurrentRoundData:Get() ~= nil

      -- // Spawn new pick ups if round is active
      -- Note: Do this before despawns so that new spawns don't immediately consume a released spawn point
      if roundActive then
         if #availablePickupClasses > 0 and now - lastSpawn >= SPAWN_INTERVAL and now - lastFailedSpawn >= FAILED_SPAWN_COOLDOWN and PickupLibrary.getLivePickupCount() < getMaxLivePickups() then
            local pickupSpawns = ArenaService.getPickupSpawns()
            local livingPlayersInArena = gameStateData.LivingPlayersInArena:Get()

            -- Remove occupied spawns and spawns too close to living players
            for i = #pickupSpawns, 1, -1 do
               local spawn = pickupSpawns[i]
               if spawn then
                  local spawnPosition = spawn.Position
                  local blocked = false
                  for _, livePickup in pairs(PickupLibrary.LivePickups) do
                     if (spawnPosition - livePickup.Position).Magnitude <= 1 then
                        blocked = true
                        break
                     end
                  end

                  if not blocked then
                     for _, player in ipairs(livingPlayersInArena) do
                        local character = player.Character
                        local primaryPart = character and character.PrimaryPart
                        if primaryPart and ((spawnPosition - primaryPart.Position) * Vector3.new(1, 0, 1)).Magnitude <= SPAWN_THRESHOLD_DISTANCE then
                           blocked = true
                           break
                        end
                     end
                  end

                  if blocked then
                     table.remove(pickupSpawns, i)
                  end
               end
            end
            if #pickupSpawns == 0 then
               lastFailedSpawn = now
            else
               lastSpawn = now
               local spawn = pickupSpawns[math.random(1, #pickupSpawns)]
               local pickupClassId = availablePickupClasses[math.random(1, #availablePickupClasses)]
               local uuid = HttpService:GenerateGUID(false)
               local despawnTime = now + DESPAWN_TIME
               PickupLibrary.LivePickups[uuid] = {
                  ClassId = if GlobalConfig.ForceOverwritePickup then GlobalConfig.ForceOverwritePickup else pickupClassId,
                  DespawnsAt = despawnTime,
                  Position = spawn.Position
               }
               -- Replicate
               local replicationData: PickupLibrary.LivePickupReplicationData = {
                  Spawned = {
                     [uuid] = {
                        Position = spawn.Position,
                        DespawnsAt = despawnTime
                     }
                  }
               }
               livePickupReplication:FireAllClients(replicationData)
            end
         end
      end
      -- Remove expired pickup effects
      -- natural decay is simulated locally by each client via their own endsAt loop, so this removal must not replicate
      for userId, activePickups in pairs(PickupLibrary.UserPickupEffectsActive) do
         for livePickupId, activePickupData in pairs(activePickups) do
            if activePickupData.EndsAt and activePickupData.EndsAt <= now then
               PickupLibrary.removePickupEffectActive(userId, livePickupId, nil, true)
               PickupService.PickupEffectEndedTasks:Execute("parallel", userId, livePickupId)
               if not PickupLibrary.isDataOnlyEffect(activePickupData.ClassId) then
                  local logic = getLogic(activePickupData.ClassId)
                  if logic and logic.onEnd then
                     local player = Players:GetPlayerByUserId(userId)
                     if player then
                        logic.onEnd(player)
                     end
                  end
               end
            end
         end
      end

      -- Despawn expired live pickups
      --[[for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
         -- man idk if pickups even need to be despawned. they probably dont.
         if livePickup.DespawnsAt <= now then
            PickupLibrary.LivePickups[livePickupId] = nil
            -- Replicate
            local replicationData: PickupLibrary.LivePickupReplicationData = {
               Despawned = {livePickupId}
            }
            livePickupReplication:FireAllClients(replicationData)
         end
      end]]

      if roundActive then
         for _, p in pairs(Players:GetPlayers()) do
            local character = p.Character
            if not character then
               continue
            end
            local primaryPart = character.PrimaryPart
            if not primaryPart then
               continue
            end
            local position = primaryPart.Position
            
            for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
               if ((position - livePickup.Position)*Vector3.new(1, 0, 1)).Magnitude <= PickupLibrary.PICKUP_DISTANCE then
                  activatePickup(p, livePickupId)
               end
            end
         end
      end
   end)

   CommandService.addCommand("GrantEffect", "/getPickup", "/getpickup", function(player: Player, args: {string})
      local pickupClassId = args[1]
      if not pickupClassId then
         warn(`PickupService.activatePickup: No pickupClassId provided`)
         ChatService.tellPlayerPrintMessage(player, "No pickupClassId provided", Color3.fromRGB(241, 89, 18))
         return
      end
      pickupClassId = getClassIdCaseInsensitive(pickupClassId)
      if not pickupClassId then
         ChatService.tellPlayerPrintMessage(player, `{pickupClassId} is not a recognized class. Recognizable class names are: {table.concat(availablePickupClasses, ", ")}`, Color3.fromRGB(241, 89, 18))
         return
      end
      local logic = getLogic(pickupClassId)
      if not logic then
         warn(`PickupService.activatePickup: No logic found for pickup {pickupClassId}`)
         ChatService.tellPlayerPrintMessage(player, `{pickupClassId} is not a recognized class. Recognizable class names are: {table.concat(availablePickupClasses, ", ")}`, Color3.fromRGB(241, 89, 18))
         return
      end
      if logic.canActivate and not logic.canActivate(player) then
         warn(`PickupService.activatePickup: Player {player.Name} cannot activate pickup {pickupClassId}`)
         ChatService.tellPlayerPrintMessage(player, `You cannot activate pickup {pickupClassId}`, Color3.fromRGB(241, 89, 18))
         return
      end
      local fakeLivePickupId = HttpService:GenerateGUID(false)

      local endsAt = nil
      if logic.onPickup then
         print("calling on pickup")
         endsAt = logic.onPickup(player)
         if endsAt then
            PickupLibrary.setPickupEffectActive(player.UserId, fakeLivePickupId, pickupClassId, endsAt)
            print("setting pickup effect active")
         end
      end

      pickupReplication:FireAllClients(fakeLivePickupId, pickupClassId, player.UserId, workspace:GetServerTimeNow())

      print("GRANTED!")
   end)
end

-- function PickupService.start() end

-- function PickupService.test() end

return PickupService