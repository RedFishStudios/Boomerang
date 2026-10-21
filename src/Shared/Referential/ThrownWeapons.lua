-- // Data on thrown weapons that exist in the field

local ThrownWeapons = {}

ThrownWeapons.StateEnum = {
   Outgoing = 1,
   Exhausted = 2,
   Returning = 3,
   Deflected = 6, -- // Snapshot-only event: the server says this boomerang clashed with another and was knocked onto a new direction (never stored as a State; 4 and 5 are Dying/Dead)
} :: {
   ["Outgoing"]: number,
   ["Exhausted"]: number,
   ["Returning"]: number,
   ["Deflected"]: number,
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
   SyncCorrection: Vector3?, -- // Client: position error still to ease out (set by each server snapshot, applied gradually by WeaponController)
   SnapshotDirection: Vector3?, -- // Client: the server's latest heading, adopted by the simulation on its next step
   SnapshotSpeed: number?, -- // Client: the server's latest speed, adopted with SnapshotDirection
   ServerTargetPosition: Vector3?, -- // Client: where the server had the thrower at the latest snapshot (remote clients steer a recall toward it)
   ServerDirection: Vector3?,
   ServerSpeed: number?,
   Homing: boolean?,
   Energy: number?, -- // Remaining energy while thrown (GlobalConfig.BoomerangMinEnergy..MaxEnergy at the throw)
   EnergyDepletedHandled: boolean?, -- // The 0-energy decision (recall or die) has been made
   ReturnRescued: boolean?, -- // A returning boomerang that ran out of energy was already saved from dying once (see Boomerang.canAvoidDying)
   ReturnSpeedMultiplier: number?, -- // Max recall speed multiplier for a returning boomerang (Explosive effect), set by Boomerang.recall
   PendingDirection: Vector3?, -- // A new flight direction to adopt on the next step (set by a clash)
   TelekinesisBias: Vector3?, -- // T-077: owner's desired steer direction (horizontal unit) while a Telekinesis effect is active; nil = no steering
   ReuseEquippedHost: boolean?,
   ExistingHost: Model?,
   LastMovementPositions: {Vector3}?,
   HitPlayers: {[Player]: number}?,
   HitBots: {[Model]: number}?, -- // When a bot (decoy) was last struck by this boomerang, for the same per-target cooldown as HitPlayers
   RecallFromDead: boolean?, -- // Recalled off the ground: true = the player's charged manual recall (only while recall is held), false = automatic (recovered)
   RecallTiltAngle: number?, -- // Client visual: current manual-recall tilt (radians)
   RecallTilt: CFrame?, -- // Client visual: rotation applied to the model while a manual recall lifts it
   HasBeenDead: boolean?, -- // It has been fully Dead at least once (T-093): it never recalls by itself again, only by the owner's manual recall
   VisualYOffset: number?, -- // Client drawing only: how far the freshly thrown boomerang is still drawn above/below its physics height (eases to 0)
   VisualYOffsetStartedAt: number?, -- // os.clock() of the throw
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