-- // Data on dying and dead weapons that exist in the field (a boomerang that ran out of energy out of line of sight)

local DeadWeapons = {}

DeadWeapons.StateEnum = {
   Dying = 4,
   Dead = 5,
} :: {
   ["Dying"]: number,
   ["Dead"]: number,
}

export type Data = {
   ToolId: string,
   State: number,
   InstanceId: string,
   OwnerUserId: number,

   Host: (Part | Model)?,
   LastPosition: Vector3?,
   CFrame: CFrame?,
   Direction: Vector3?,
   Speed: number?,
   SyncTargetPosition: Vector3?,
   ServerDirection: Vector3?,
   ServerSpeed: number?,
   ReuseEquippedHost: boolean?,
   ExistingHost: Model?,
   DeathOrigin: Vector3?,
   VisualRotation: number?,

   -- // T-090 recall charge (Dead.luau). Timestamps are server time (workspace:GetServerTimeNow()), replicated by the RecallCharge event
   RecallHeld: boolean?, -- // Server only: the owner is holding the recall button
   RecallChargeStart: number?, -- // When the current charge began
   RecallChargeStartY: number?, -- // Height the boomerang had when the charge began
   RecallChargeTargetY: number?, -- // Height it lifts to (hand height) by the end of the charge
   RecallRestY: number?, -- // Its resting height on the ground
   RecallCancelAt: number?, -- // When an uncharged recall was released (it then drops back to RecallRestY)
   RecallCancelFromY: number?, -- // Height it had at that moment
   
   MovementConnection: RBXScriptConnection?,
}

DeadWeapons.Data = {} :: {
   [Player]: Data
}

return DeadWeapons