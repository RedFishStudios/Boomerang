local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

local GlobalConfig = {
   WeaponHeight = 21.081,
   DeathHeight = 14.207,

  --PlayersRequiredToStart = if isStudio then 1 else 2,
  PlayersRequiredToStart = 1,
   
   CharacterFocalHeight = 154.902,
   SkipVoting = false,
   CanHurtSelf = false,
   CanHitSelfDecoy = false, -- // Whether a player's own boomerang can eliminate their own decoy
   SpawnShieldDuration = 2,
   NilDataType = "nil_",
   ChargeTime = 1, -- // Seconds of aiming to reach max throw power and full aim arrow length
   ForceEquippedTool = "ClassicBoomerang", -- // nil = no held weapon; otherwise the model and class come from the equipped skin
   ThrownWeaponTrailLifetime = .3,
   BoomerangHitThrottle = .5,
   ForceOverwritePickup = nil,
   GenericEffectTimeout = 15,
   ElectricChainRadius = 15, -- // Studs from the victim an Electric elimination chains to
   ElectricChainLinkDelay = 0.05, -- // Seconds between Electric chain links

   -- // Boomerang energy: spent flying out and on impacts; at 0 it returns if it can see its player, otherwise it dies.
   -- // Defaults for Cmdr `tuneboomerang`.
   BoomerangMinEnergy = 50, -- // Uncharged throw
   BoomerangMaxEnergy = 100, -- // Fully charged throw
   BoomerangEnergyPerStud = 1,
   BoomerangRecallEnergy = 30, -- // Refill when it starts returning after running out
   BoomerangBounceEnergyCost = 30,
   BoomerangPlayerHitEnergyCost = 10,
   BoomerangClashEnergyCost = 40,
   BoomerangRaycastHeight = 1, -- // Height of the obstruction and line-of-sight casts
   BoomerangFlightHeight = 158.7, -- // Physics height of boomerang raycasts while in flight
   BoomerangVisualHeightSyncSeconds = 1.5, -- // Seconds a thrown boomerang's drawn height takes to reach flight height
   PlayerHitboxRadius = 1.65,
   BoomerangRecallBounceRecoverySeconds = 0.35, -- // Seconds for a returning boomerang's bounce momentum to fade
   DyingBoomerangNoGroundRecallSeconds = 0.75, -- // Seconds a dying boomerang slides with no ground before returning
   DyingBoomerangRecallDistance = 50, -- // Studs within which a dying boomerang in sight of its player keeps returning
   DyingBoomerangRecallCheckSeconds = 0.1,
   DyingBoomerangRecallLookaheadSeconds = 0.4, -- // Seconds of dying slide checked ahead for line of sight before it dies
   CrateClicksToOpen = 20, -- TODO:RELEASE placeholder

   -- // Manual recall
   RecallCharge = 0.3, -- // Seconds a manual recall charges before it starts returning
   ManualRecallRiseSeconds = 0.8, -- // Only used when ManualRecallGroundApproach is false
   ManualRecallGroundApproach = true, -- // true: flies along the ground while speeding up; false: rises during the charge, then flies
   ManualRecallFullSpeedDistance = 60, -- // Studs flown before full recall speed
   ManualRecallApproachStartFraction = 0.17, -- // Fraction of full recall speed it starts at
   ManualRecallApproachCurve = 2, -- // Speed-up shape: 1 = steady, below 1 = picks up pace sooner
   ManualRecallRiseDistance = 60, -- // Studs flown while the drawn boomerang rises to flight height
   ManualRecallMaxTiltDegrees = 35,
   RecallChargeCancelDropSeconds = 0.25, -- // Unused
   DeadBeamFadeSeconds = 0.4,
   RecallReturnBeamFadeInSeconds = 0.3,
   SelectionRingGrowSeconds = 0.3,
   SelectionRingVanishSeconds = 0.15,
   ManualRecallMomentumMultiplier = 0.15, -- // How quickly its heading turns toward the player (1 = normal recall)
   ManualRecallAcceleration = 1, -- // Old recall only
   ManualRecallRampPower = 3, -- // Old recall only
   ManualRecallRampStartFraction = 0.12, -- // Old recall only
   ManualRecallHighlightFadeOutSeconds = 0.6,
   DeadWeaponDeceleration = 4, -- // How much faster a dying boomerang stops sliding (1 = original pace)
   ExplosiveBoomerangReturnSpeedMultiplier = 1.5,

   MyBoomerangTrailColor = Color3.new(0.984314, 0.988235, 0.988235),
   EnemyBoomerangTrailColor = Color3.new(0.952941, 0.07451, 0.368627),

   DefaultWalkSpeed = 20,
   LobbyJumpHeight = 7.2,
   AimingWalkSpeedMultiplier = 0.3, -- // Fraction of the default walk speed while aiming

   GroupId = 293180599,
   GroupRewardCurrency = 100, -- TODO:RELEASE placeholder

   LagCompensationMilliseconds = 200, -- // Max server rewind for hit checks (0 = off)

   -- // Debugging (can add lag or network traffic)
   RaycastVisualizersEnabled = false,
   ProjectileHitboxVisualizerEnabled = false,
   LineOfSightVisualizerEnabled = false,
   ToggleAuthorityView = false,
   ParryVisualizersEnabled = false,
   VisualizeElectricChainRadius = true,
   SyncAbilitiesToEveryPlayer = false, -- // Every player performs any player's ability or throw
   CmdrOpenToEveryone = true, -- TODO:RELEASE RELEASE BLOCKER: must be false before public release
   AuthoritativeCharacterDebugVisible = false,
   ShowAuthoritativeCharacterOnRenderFailure = true,
}

return GlobalConfig
