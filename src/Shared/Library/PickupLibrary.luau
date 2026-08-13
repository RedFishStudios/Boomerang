local PickupLibrary = {}

local initiated = false

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type LivePickupData = {
   ClassId: string?, -- Server-only
   DespawnsAt: number,
   Position: Vector3
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

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local everyFrameCallbacks: (dt: number)->() = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PickupLibrary.LivePickups = {} :: { [LivePickupId]: LivePickupData }

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PickupLibrary.getLivePickupCount(_now: number?)
   local count = 0
   local now = _now or workspace:GetServerTimeNow()
   for _, live in pairs(PickupLibrary.LivePickups) do
      if now - live.DespawnsAt < 0 then
         count += 1
      end
   end
   return count
end

function PickupLibrary.getLivePickup(livePickupId: LivePickupId)
   local live = PickupLibrary.LivePickups[livePickupId]
   if live then
      local now = workspace:GetServerTimeNow()
      if live.DespawnsAt > now then
         return live
      end
   end
   PickupLibrary.LivePickups[livePickupId] = nil
   return nil
end

function PickupLibrary.addToEveryFrame(callback: (dt: number)->())
   table.insert(everyFrameCallbacks, callback)
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