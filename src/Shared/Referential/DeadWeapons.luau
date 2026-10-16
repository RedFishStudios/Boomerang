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
   
   MovementConnection: RBXScriptConnection?,
}

DeadWeapons.Data = {} :: {
   [Player]: Data
}

return DeadWeapons