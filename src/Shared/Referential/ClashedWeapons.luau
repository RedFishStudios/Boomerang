-- // Data on clashed weapons that exist in the field

local ClashedWeapons = {}

ClashedWeapons.StateEnum = {
   Clashed = 4,
   Dead = 5,
} :: {
   ["Clashed"]: number,
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
   ClashOrigin: Vector3?,
   VisualRotation: number?,
   
   MovementConnection: RBXScriptConnection?,
   TestRaycastVisualizers: {Part}
}

ClashedWeapons.Data = {} :: {
   [Player]: Data
}

return ClashedWeapons