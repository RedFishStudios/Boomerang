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

local pickupClasses: {PickupClassId} = {}

local SPAWN_INTERVAL = 5
local lastSpawn = 0

local DESPAWN_TIME = 8
local MAX_LIVE_PICKUPS = 3

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PickupService.PickupEffectEndedTasks = TasksList.new() :: TasksList.TasksList<(forUserId: number, livePickupId: string)->()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(pickupClassId: PickupClassId)
	if not PickupLogicModules[pickupClassId] then
      local _module = PickupLogics:WaitForChild(pickupClassId, 5)
      if not _module then
         warn(`PickupService.getLogic: Pickup logic module {pickupClassId} not found`)
         return
      end
      if not table.find(pickupClasses, pickupClassId) then
         table.insert(pickupClasses, pickupClassId)
      end
		local module = require(_module)
		PickupLogicModules[pickupClassId] = module
	end
	return PickupLogicModules[pickupClassId]
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
      
   if logic.onPickup then
      local longApplication, endsAt = logic.onPickup(player, ...)
      if longApplication then
         -- Replaces any prior effects of the same pickup class for this user.
         for livePickupIdToRemove, activePickupData in pairs(PickupLibrary.UserPickupEffectsActive[player.UserId] or {}) do
            if activePickupData.Id == pickupClassId then
               PickupLibrary.removePickupEffectActive(player.UserId, livePickupIdToRemove)
            end
         end
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
      if activePickupData.Id == pickupClassId then
         PickupLibrary.removePickupEffectActive(player.UserId, livePickupId)
         PickupService.PickupEffectEndedTasks:Execute("parallel", player.UserId, livePickupId)
         local logic = getLogic(activePickupData.Id)
         if logic and logic.onEnd then
            logic.onEnd(player)
         end
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PickupService.init()
   local gameStateData = GameStateLibrary.getGameStateData()

   GameStateLibrary.RoundStartingTasks:Add(function()
      -- Destroy all previous pickup objects
      PickupLibrary.LivePickups = {}

      -- Remove all pickup abilities active on players
      PickupLibrary.clearAllPickupEffectsActive()

      -- Spawn new pickups
      task.spawn(function()
         local now = workspace:GetServerTimeNow()
         local pickupSpawns = ArenaService.getPickupSpawns()
         if #pickupSpawns == 0 then
            return
         end
         local startCount = 1
         for i = 1, startCount do 
            local spawn = pickupSpawns[math.random(1, #pickupSpawns)]
            local pickupClassId = pickupClasses[math.random(1, #pickupClasses)]
            local uuid = HttpService:GenerateGUID(false)
            local despawnTime = now + DESPAWN_TIME
            PickupLibrary.LivePickups[uuid] = {
               --ClassId = pickupClassId,
               ClassId = "Caffeinated",
               --DespawnsAt = despawnTime,
               Position = spawn.Position
            }
         end

         -- Replicate
         local replicationData: PickupLibrary.LivePickupReplicationData = {
            ClearAll = true,
            Spawned = {}
         }
         for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
            replicationData.Spawned[livePickupId] = {
               Position = livePickup.Position,
               --DespawnsAt = livePickup.DespawnsAt
            }
         end
         livePickupReplication:FireAllClients(replicationData)
      end)
   end)

   --requestUsePickup.OnServerEvent:Connect(function(player: Player, livePickupId: LivePickupId, ...)
   --   activatePickup(player, livePickupId, ...)
   --end)

   for _, module in pairs(PickupLogics:GetChildren()) do
      local pickupId = module.Name
      table.insert(pickupClasses, pickupId)
      getLogic(pickupId)
   end

   RunService.Heartbeat:Connect(function()
      local now = workspace:GetServerTimeNow()

      -- Spawn new pickups
      -- Note: Do this before despawns so that new spawns don't immediately consume a released spawn point
      if now - lastSpawn >= SPAWN_INTERVAL and PickupLibrary.getLivePickupCount() < MAX_LIVE_PICKUPS then
         lastSpawn = now
         local pickupSpawns = ArenaService.getPickupSpawns()
         if #pickupSpawns == 0 then
            return
         end

         -- Remove occupied
         for i = #pickupSpawns, 1, -1 do
            local spawn = pickupSpawns[i]
            if spawn then
               local spawnPosition = spawn.Position
               for _, livePickup in pairs(PickupLibrary.LivePickups) do
                  if (spawnPosition - livePickup.Position).Magnitude <= 1 then
                     table.remove(pickupSpawns, i)
                     break
                  end
               end
            end
         end
         if #pickupSpawns == 0 then
            return
         end

         local spawn = pickupSpawns[math.random(1, #pickupSpawns)]
         local pickupClassId = pickupClasses[math.random(1, #pickupClasses)]
         local uuid = HttpService:GenerateGUID(false)
         local despawnTime = now + DESPAWN_TIME
         PickupLibrary.LivePickups[uuid] = {
            --ClassId = pickupClassId,
            ClassId = "Caffeinated",
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

      -- Remove expired pickup effects
      for userId, activePickups in pairs(PickupLibrary.UserPickupEffectsActive) do
         for livePickupId, activePickupData in pairs(activePickups) do
            if activePickupData.EndsAt and activePickupData.EndsAt <= now then
               PickupLibrary.removePickupEffectActive(userId, livePickupId)
               PickupService.PickupEffectEndedTasks:Execute("parallel", userId, livePickupId)
               local logic = getLogic(activePickupData.Id)
               if logic and logic.onEnd then
                  local player = Players:GetPlayerByUserId(userId)
                  if player then
                     logic.onEnd(player)
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
               print(`activate pickup!`)
               activatePickup(p, livePickupId)
            end
         end
      end
   end)
end

-- function PickupService.start() end

-- function PickupService.test() end

return PickupService

--[[

Round ends =
   Destroy all previous pickup objects
   Remove all pickup abilities active on players

]]