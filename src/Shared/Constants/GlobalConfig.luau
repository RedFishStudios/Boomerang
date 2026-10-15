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
   CanHitSelfDecoy = false, -- // T-081: if true, a player's own boomerang can eliminate their own decoy (friendly fire on your own decoy). Default off.
   SpawnShieldDuration = 2,
   NilDataType = "nil_",
   ChargeTime = 1, -- // Seconds of holding aim until BOTH the throw is at max power AND the aim arrow is at its full size/length. Default for the Cmdr `tuneboomerang ChargeTime` setting (BoomerangTuningLibrary).
   ForceEquippedTool = "ClassicBoomerang", -- // nil = players hold no weapon. Otherwise the held/thrown model and weapon class come from the equipped skin (SkinLibrary)
   ThrownWeaponTrailLifetime = .3,
   BoomerangHitThrottle = .5,
   ForceOverwritePickup = nil,
   GenericEffectTimeout = 15,
   TelekinesisSteerInfluence = 2, -- // T-077: how strongly a Telekinesis boomerang turns toward the owner's aim each second (bias, not full control). Tunable live via Cmdr `tune TelekinesisInfluence`.
   ElectricChainRadius = 15, -- // Studs: an Electric boomerang elimination chains to every enemy within this distance of the victim
   ElectricChainLinkDelay = 0.05, -- // Seconds between each link of an Electric chain
   -- // Automatic recall range (a failsafe, not a gameplay rule): a boomerang that gets more than this many studs
   -- // (horizontally) from its player, thrown or still dying, starts returning on its own instead of dying. It only exists
   -- // for a boomerang thrown out of the map bounds. About 4x the old death range (30).
   BoomerangAutoRecallRange = 120,
   -- // When a thrown boomerang runs out of energy (bounces) it returns on its own if nothing solid is between it and its
   -- // player (one ray), otherwise it drops into the dead state and must be manually recalled or picked up.
   -- // A dying boomerang that keeps sliding away instead of landing returns to its player on its own (automatic recall,
   -- // no manual recall needed) once either limit is hit (T-062). Previously it snapped straight back at 100 studs.
   DyingBoomerangNoGroundRecallSeconds = 0.75, -- // Seconds of sliding with nothing below to land on
   DyingBoomerangMaxSlideDistance = 100, -- // Studs (horizontal) from where it started dying
   -- // Manual recall of a dying/dead boomerang (held recall): slower, heavier, sluggish lift with a visual tilt
   ManualRecallMomentumMultiplier = 0.15, -- // How quickly it accelerates/turns toward the player (1 = normal recall)
   -- // Manual recall speed-up: the boomerang starts at ManualRecallRampStartFraction of its max recall speed and builds up
   -- // along a curve that stays slow at first and then climbs steeply, reaching max speed after ManualRecallRampSeconds.
   -- // speed = max * (StartFraction + (1 - StartFraction) * (t / RampSeconds) ^ RampPower). Tunable live via Cmdr `tune RecallRampTime` / `RecallRampPower`.
   ManualRecallRampSeconds = 0.7, -- // Seconds from the start of a manual recall until it reaches max speed
   ManualRecallRampPower = 3, -- // Curve steepness: 1 = steady speed-up, higher = slower start and a sharper late surge
   ManualRecallRampStartFraction = 0.12, -- // Fraction of max recall speed at the moment the recall starts
   ManualRecallLiftRate = 2.5, -- // How quickly it rises to hand height (normal from-ground lift is 8)
   ManualRecallMaxTiltDegrees = 35, -- // Visual tilt toward the player while it's being lifted
   ManualRecallHighlightFadeOutSeconds = 0.6, -- // The dead boomerang's highlight fades this slowly when a manual recall starts (normal fade: 0.1)
   DyingSpeedMultiplier = 4, -- // How much faster a boomerang loses its slide momentum and drops to the ground once it starts dying (1 = the original pace). Tunable live via Cmdr `tuneboomerang DyingSpeedMultiplier`.
   ExplosiveBoomerangReturnSpeedMultiplier = 1.5, -- // While the effect is active: recall speed x this, and the post-explosion weapon lock / this

   MyBoomerangTrailColor = Color3.new(0.984314, 0.988235, 0.988235),
   EnemyBoomerangTrailColor = Color3.new(0.952941, 0.07451, 0.368627),

   DefaultWalkSpeed = 20,
   LobbyJumpHeight = 7.2, -- // Jumping is only enabled in the lobby (dash replaces it in the arena)
   AimingWalkSpeed = (16 * .3),

   -- // The game's Roblox group (community), checked by GroupMembershipService (Cmdr `setgroupid` overrides it per server).
   -- // Members can claim GroupRewardCurrency from the lobby Group Rewards chest once every 24 h (T-045).
   GroupId = 293180599,
   GroupRewardCurrency = 100, -- TODO:RELEASE placeholder (the real reward isn't decided yet)

   -- Use for debugging
   -- Enabling these can greatly increase lag or network traffic
   RaycastVisualizersEnabled = false,
   ProjectileHitboxVisualizerEnabled = false,
   ParryVisualizersEnabled = false,
   VisualizeElectricChainRadius = true, -- // Client-only red cylinder showing the chain radius around every Electric boomerang elimination
   SyncAbilitiesToEveryPlayer = false,
   -- // Cmdr developer console (F2): true = every player can use it in live servers (for client review builds).
   CmdrOpenToEveryone = true, -- TODO:RELEASE (T-052) RELEASE BLOCKER: must be false before public release, or every player can use admin commands (then only admins, see CmdrService)
   AuthoritativeCharacterDebugVisible = false, -- // Shows the server-authoritative character half-transparent (normally fully invisible)
   ShowAuthoritativeCharacterOnRenderFailure = true, -- // If a player's rendered model failed to load, show the authoritative character so they aren't invisible
}

return GlobalConfig