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
   TelekinesisBias: Vector3?, -- // T-077: owner's desired steer direction (horizontal unit) while a Telekinesis effect is active; nil = no steering
   ReuseEquippedHost: boolean?,
   ExistingHost: Model?,
   LastMovementPositions: {Vector3}?,
   HitPlayers: {[Player]: number}?,
   RecallFromDead: boolean?, -- // Recalled off the ground: true = only while recall is held, false = automatic (recovered)
   RecallTiltAngle: number?, -- // Client visual: current manual-recall tilt (radians)
   RecallTilt: CFrame?, -- // Client visual: rotation applied to the model while a manual recall lifts it
   PortalExitAt: number?, -- // os.clock() of the last portal exit (Environment/Portal)
   PortalExitPart: BasePart?, -- // The portal it last came out of
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