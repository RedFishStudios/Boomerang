local PickupLibrary = {}

local initiated = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local pickupEffectStateChanged = SimpleRemotes.getEvent("PickupEffectStateChanged")

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type LivePickupData = {
   ClassId: string?, -- Server-only
   DespawnsAt: number,
   Position: Vector3
}

export type PickupEffectData = {
   ClassId: string,
   EndsAt: number?
}

export type LivePickupId = string -- UUID
export type PickupClassId = string -- Name of the pickup logic module

export type LivePickupReplicationData = {
   ClearAll: true?,
   Spawned: {
      [LivePickupId]: {
         Position: Vector3,
         DespawnsAt: number
      }
   }?,
   Despawned: {LivePickupId}?
}

export type PickupEffectStateChangedReplicationData = {
   clearAll: true?,
   userId: number?,
   livePickupId: LivePickupId?,
   classId: PickupClassId?,
   cancelCode: number?,
   endsAt: number?,
   active: boolean?
}

export type PickupLogic = {
   -- Play on pickup. Returns [ends at timestamp if it is a generic long lasting effect]
   onPickup: (player: Player, startedAt: number?) -> (number?),
   -- Play on end of an automated long-lasting effect
   onEnd: (player: Player) -> ()?,
   -- Simulate activation for other players besides the local player who picked it up. This is played by clients receiving a replication event for an item pickup by another player.
   onPickup: (userId: number, activationTime: number) -> (),
   fart: string,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PickupLibrary.PICKUP_DISTANCE = 1.3
PickupLibrary.LivePickups = {} :: { [LivePickupId]: LivePickupData }
PickupLibrary.UserPickupEffectsActive = {} :: {
   [number]: {
      [LivePickupId]: PickupEffectData
   }
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PickupLibrary.setPickupEffectActive(userId: number, livePickupId: LivePickupId, pickupClassId: PickupClassId, endsAt: number?)
   local userEffects = PickupLibrary.UserPickupEffectsActive[userId]
   if not userEffects then
      userEffects = {}
      PickupLibrary.UserPickupEffectsActive[userId] = userEffects
   end

   for livePickupIdToRemove, activePickupData in pairs(userEffects) do
      if livePickupIdToRemove ~= livePickupId and activePickupData.ClassId == pickupClassId then
         PickupLibrary.removePickupEffectActive(userId, livePickupIdToRemove, true)
      end
   end

   -- removePickupEffectActive nils out the per-user table once it's emptied, so it must be re-linked
   userEffects = PickupLibrary.UserPickupEffectsActive[userId]
   if not userEffects then
      userEffects = {}
      PickupLibrary.UserPickupEffectsActive[userId] = userEffects
   end

   local effectData = {
      ClassId = pickupClassId,
      EndsAt = endsAt,
   }
   userEffects[livePickupId] = effectData

   if isServer then
      pickupEffectStateChanged:FireAllClients({
         userId = userId,
         livePickupId = livePickupId,
         classId = pickupClassId,
         endsAt = endsAt,
         active = true,
      })
   end
end

function PickupLibrary.removePickupEffectActive(userId: number, livePickupId: LivePickupId, cancelCode: number?, doNotReplicate: boolean)
   local userEffects = PickupLibrary.UserPickupEffectsActive[userId]
   if not userEffects then
      return
   end

   local pickupData = userEffects[livePickupId]

   if livePickupId then
      userEffects[livePickupId] = nil
      if next(userEffects) == nil then
         PickupLibrary.UserPickupEffectsActive[userId] = nil
      end
   else
      PickupLibrary.UserPickupEffectsActive[userId] = nil
   end

   if isServer and not doNotReplicate then
      pickupEffectStateChanged:FireAllClients({
         userId = userId,
         classId = pickupData and pickupData.ClassId,
         livePickupId = livePickupId,
         cancelCode = cancelCode,
         active = false,
      })
   end
end

function PickupLibrary.removePickupEffectActiveByClassId(userId: number, pickupClassId: PickupClassId, cancelCode: number?, doNotReplicate: boolean)
   local userEffects = PickupLibrary.UserPickupEffectsActive[userId]
   if not userEffects then
      return
   end

   for livePickupId, activePickupData in pairs(userEffects) do
      if activePickupData.ClassId == pickupClassId then
         PickupLibrary.removePickupEffectActive(userId, livePickupId, cancelCode, doNotReplicate)
         return
      end
   end
end

function PickupLibrary.clearAllPickupEffectsActive()
   PickupLibrary.UserPickupEffectsActive = {}
   if isServer then
      pickupEffectStateChanged:FireAllClients({
         ClearAll = true,
      })
   end
end

function PickupLibrary.hasPickupEffectActive(userId: number, pickupClassId: PickupClassId): boolean
   local userEffects = PickupLibrary.UserPickupEffectsActive[userId]
   if not userEffects then
      return false
   end

   for _, activePickupData in pairs(userEffects) do
      if activePickupData.ClassId == pickupClassId then
         return true
      end
   end

   return false
end

function PickupLibrary.getLivePickupCount(_now: number?)
   local count = 0
   local now = _now or workspace:GetServerTimeNow()
   for _, live in pairs(PickupLibrary.LivePickups) do
      --if now - live.DespawnsAt < 0 then
         count += 1
      --end
   end
   return count
end

function PickupLibrary.getLivePickup(livePickupId: LivePickupId)
   local live = PickupLibrary.LivePickups[livePickupId]
   --if live then
      --local now = workspace:GetServerTimeNow()
      --if live.DespawnsAt > now then
         return live
     -- end
   --end
   --PickupLibrary.LivePickups[livePickupId] = nil
   --return nil
end

-------------------------------------------------------------------------------
-- CORE
-------------------------------------------------------------------------------

function PickupLibrary.init()
   if initiated then
      return
   end
   initiated = true
end

return PickupLibrary 