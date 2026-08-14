local PickupController = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)

local localPlayer = Players.LocalPlayer

local PickupLogics = ReplicatedStorage.Shared.Logics.PickupLogics
local PickupLogicModules = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local pickupUsed = SimpleRemotes.getEvent("PickupUsed")
local pickupReplication = SimpleRemotes.getUnreliableEvent("PickupReplication")

local livePickupVisuals: {[string]: Instance} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function destroy(livePickupId: string)
   PickupLibrary.LivePickups[livePickupId] = nil
   if livePickupVisuals[livePickupId] then
      print(`destroying visual`)
      livePickupVisuals[livePickupId]:Destroy()
      livePickupVisuals[livePickupId] = nil
   end
end

local function getLogic(pickupId: string)
	if not PickupLogicModules[pickupId] then
      local _module = PickupLogics:WaitForChild(pickupId, 5)
      if not _module then
         warn(`PickupService.getLogic: Pickup logic module {pickupId} not found`)
         return
      end
		local module = require(_module)
		PickupLogicModules[pickupId] = module
	end
	return PickupLogicModules[pickupId]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PickupController.activate(pickupId: string, ...)
   local logic = getLogic(pickupId)
   if not logic or not logic.simulateActivation then
      return
   end
   if logic.canActivate and not logic.canActivate(localPlayer, ...) then
      print("cancelling pickup; cannot activate")
      return
   end
   logic.simulateActivation(localPlayer.UserId, game.Workspace:GetServerTimeNow())
	pickupUsed:FireServer(pickupId)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PickupController.init()
   pickupReplication.OnClientEvent:Connect(function(livePickupId: string, pickupId: string, userId: number, timestamp: number)
      print(`received: livePickupId: {livePickupId}, pickupId: {pickupId}, userId: {userId}, timestamp: {timestamp}`)
      destroy(livePickupId)

      if userId == localPlayer.UserId then
         return
      end

      local logic = getLogic(pickupId)
      if not logic or not logic.simulateActivation then
         return
      end

      logic.simulateActivation(userId, timestamp)
   end)

   SimpleRemotes.getEvent("LivePickupReplication").OnClientEvent:Connect(function(replicationData: PickupLibrary.LivePickupReplicationData)
      if replicationData.ClearAll then
         for livePickupId, _ in pairs(PickupLibrary.LivePickups) do
            destroy(livePickupId)
         end
         PickupLibrary.LivePickups = {}
      end

      if replicationData.Spawned then
         for livePickupId, livePickup in pairs(replicationData.Spawned) do
            destroy(livePickupId)

            PickupLibrary.LivePickups[livePickupId] = {
               --ClassId = livePickup.ClassId,
               --DespawnsAt = livePickup.DespawnsAt,
               Position = livePickup.Position
            }

            local visual = Instance.new("Part")
            visual.Anchored = true
            visual.CanCollide = false
            visual.CanTouch = false
            visual.CanQuery = false
            visual.Size = Vector3.new(1, 1, 1)
            visual.Material = "Neon"
            visual.Position = livePickup.Position
            visual.Parent = workspace
            livePickupVisuals[livePickupId] = visual
         end
      end

      if replicationData.Despawned then
         for _, livePickupId in ipairs(replicationData.Despawned) do
            destroy(livePickupId)
         end
      end
   end)

   RunService.Heartbeat:Connect(function(dt: number)
      local now = workspace:GetServerTimeNow()
      for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
         --if livePickup.DespawnsAt <= now then
         --   destroy(livePickupId)
         --end
      end
   end)
end

-- function PickupController.start() end

-- function PickupController.test() end

return PickupController