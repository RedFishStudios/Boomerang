local PickupController = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)

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
local initLivePickups = SimpleRemotes.getFunction("InitLivePickups")

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
      livePickupVisuals[livePickupId]:Destroy()
      livePickupVisuals[livePickupId] = nil
   end
end

local function clearLivePickups()
   for _, visual in pairs(livePickupVisuals) do
      visual:Destroy()
   end
   table.clear(livePickupVisuals)
   table.clear(PickupLibrary.LivePickups)
end

local function applyLivePickupReplication(replicationData: PickupLibrary.LivePickupReplicationData)
   if replicationData.ClearAll then
      clearLivePickups()
   end

   if replicationData.Spawned then
      for livePickupId, livePickup in pairs(replicationData.Spawned) do
         destroy(livePickupId)

         PickupLibrary.LivePickups[livePickupId] = {
            Position = livePickup.Position,
            DespawnsAt = livePickup.DespawnsAt,
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
end

local function getLogic(pickupId: string)
   if not pickupId then
      error(`why is pickupId nil?`)
   end
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
   --print(`pickup activated: {pickupId}`)
   local logic = getLogic(pickupId)
   if not logic or not logic.onPickup then
      return
   end
   if logic.canActivate and not logic.canActivate(localPlayer, ...) then
     -- print("cancelling pickup; cannot activate")
      return
   end
   if logic.onPickup then
      --print(`simulating activation`)
      logic.onPickup(localPlayer.UserId, game.Workspace:GetServerTimeNow(), ...)
   end
   --print(`firing server`)
	pickupUsed:FireServer(pickupId)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PickupController.init()
   

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(newPhase: string)
      if newPhase == GameplayPhaseEnum.LobbyVoting then
         clearLivePickups()
      end
   end)

   pickupReplication.OnClientEvent:Connect(function(livePickupId: string, pickupId: string, userId: number, timestamp: number)
      --print(`received: livePickupId: {livePickupId}, pickupId: {pickupId}, userId: {userId}, timestamp: {timestamp}`)
      destroy(livePickupId)

      local logic = getLogic(pickupId)
      if not logic or not logic.onPickup then
         return
      end

      local player = Players:GetPlayerByUserId(userId)
      if not player then
         warn(`PickupController.activate: No player found for userId {userId}`)
         return
      end

      if logic.onPickup then
         local endsAt = logic.onPickup(player, timestamp)
         if endsAt then
            PickupLibrary.setPickupEffectActive(userId, livePickupId, pickupId, endsAt)
         end
      else
         PickupLibrary.setPickupEffectActive(userId, livePickupId, pickupId)
      end
   end)

   SimpleRemotes.getEvent("LivePickupReplication").OnClientEvent:Connect(applyLivePickupReplication)
   applyLivePickupReplication(initLivePickups:InvokeServer())

   SimpleRemotes.getEvent("PickupEffectStateChanged").OnClientEvent:Connect(function(effectData: PickupLibrary.PickupEffectStateChangedReplicationData)
      if effectData.ClearAll then
         for userId, activePickups in pairs(PickupLibrary.UserPickupEffectsActive) do
            local player = Players:GetPlayerByUserId(userId)
            if player then
               for _, activePickupData in pairs(activePickups) do
                  local logic = getLogic(activePickupData.ClassId)
                  if logic and logic.onEnd then
                     logic.onEnd(player)
                  end
               end
            end
         end
         PickupLibrary.UserPickupEffectsActive = {}
      end

      if effectData.active then
         PickupLibrary.setPickupEffectActive(effectData.userId, effectData.livePickupId, effectData.pickupClassId, effectData.endsAt)
      else
         PickupLibrary.removePickupEffectActive(effectData.userId, effectData.livePickupId, effectData.cancelCode, false)
         if effectData.classId then
            local logic = getLogic(effectData.classId)
            if logic and logic.onEnd then
               local player = Players:GetPlayerByUserId(effectData.userId)
               if player then
                  logic.onEnd(player, effectData.cancelCode)
               end
            end
         end
      end
   end)

   RunService.Heartbeat:Connect(function(dt: number)
      --print(PickupLibrary.UserPickupEffectsActive)
      for _, p in pairs(game.Players:GetPlayers()) do
         if PickupLibrary.hasPickupEffectActive(p.UserId, "Shield") then
            --print("A shield is active for player: " .. p.Name)
            break
         end
      end

      local now = workspace:GetServerTimeNow()
      --for livePickupId, livePickup in pairs(PickupLibrary.LivePickups) do
         --if livePickup.DespawnsAt <= now then
         --   destroy(livePickupId)
         --end
      --end

      -- // Simulate removal of expired pickup effects
      for userId, activePickups in pairs(PickupLibrary.UserPickupEffectsActive) do
         for livePickupId, activePickupData in pairs(activePickups) do
            if activePickupData.EndsAt and activePickupData.EndsAt <= now then
               PickupLibrary.removePickupEffectActive(userId, livePickupId, nil, false)
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
   end)
end

-- function PickupController.start() end

-- function PickupController.test() end

return PickupController