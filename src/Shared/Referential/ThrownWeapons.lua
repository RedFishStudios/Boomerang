-- // Data on thrown weapons that exist in the field

local ThrownWeapons = {}

ThrownWeapons.StateEnum = {
   Outgoing = 1,
   Exhausted = 2,
   Returning = 3,
} :: {
   ["Outgoing"]: number,
   ["Exhausted"]: number,
   ["Returning"]: number,
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
   Homing: boolean?,
   ReuseEquippedHost: boolean?,
   ExistingHost: Model?,
   LastMovementPositions: {Vector3}?,
   HitPlayers: {[Player]: number}?,
   TrailObject: {
      TrailHost: Part,
      Trail: Trail,
      Attachment0: Attachment,
      Attachment1: Attachment
   },
   
   MovementConnection: RBXScriptConnection?,
}

ThrownWeapons.Data = {} :: {
   [Player]: Data
}

return ThrownWeapons