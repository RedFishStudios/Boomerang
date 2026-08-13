local PickupService = {}

local HttpService = game:GetService("HttpService")

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

local UserPickupEffectsActive: {
   [number]: {
      [LivePickupId]: {
         Id: PickupClassId,
         EndsAt: number?
      }
   }
} = {}

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
      return
   end
   local position = livePickup.Position
   local character = player.Character
   if not character then
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
      
   if logic.activate then
      local longApplication, endsAt = logic.activate(player, ...)
      if longApplication then
         if not UserPickupEffectsActive[player.UserId] then
            UserPickupEffectsActive[player.UserId] = {}
         end
         UserPickupEffectsActive[player.UserId][livePickupId] = {
            Id = pickupClassId,
            EndsAt = endsAt
         }
      end
      pickupReplication:FireAllClients(pickupClassId, player.UserId, workspace:GetServerTimeNow())
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PickupService.hasPickupEffectActive(player: Player, pickupClassId: string)
   local userEffects = UserPickupEffectsActive[player.UserId]
   if not userEffects then
      return false
   end
   for _, activePickupId in pairs(userEffects) do
      if activePickupId == pickupClassId then
         return true
      end
   end
   return false
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
      UserPickupEffectsActive = {}

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
               ClassId = pickupClassId,
               DespawnsAt = despawnTime,
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
               DespawnsAt = livePickup.DespawnsAt
            }
         end
         livePickupReplication:FireAllClients(replicationData)
      end)
   end)

   requestUsePickup.OnServerEvent:Connect(function(player: Player, livePickupId: LivePickupId, ...)
      activatePickup(player, livePickupId, ...)
   end)

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
            ClassId = pickupClassId,
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

      -- Despawn expired live pickups
      for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
         if livePickup.DespawnsAt <= now then
            PickupLibrary.LivePickups[livePickupId] = nil
            -- Replicate
            local replicationData: PickupLibrary.LivePickupReplicationData = {
               Despawned = {livePickupId}
            }
            livePickupReplication:FireAllClients(replicationData)
         end
      end

      -- Remove expired pickup effects
      for userId, activePickups in pairs(UserPickupEffectsActive) do
         for livePickupId, activePickupData in pairs(activePickups) do
            if activePickupData.EndsAt and activePickupData.EndsAt <= now then
               UserPickupEffectsActive[userId][livePickupId] = nil
               PickupService.PickupEffectEndedTasks:run(userId, livePickupId)
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