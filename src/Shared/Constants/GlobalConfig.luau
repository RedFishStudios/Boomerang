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
   SpawnShieldDuration = 2,
   NilDataType = "nil_",
   AimFullStrength = 2.0,
   ForceEquippedTool = "ClassicBoomerang", -- // nil = players hold no weapon. Otherwise the held/thrown model and weapon class come from the equipped skin (SkinLibrary)
   ThrownWeaponTrailLifetime = .3,
   BoomerangHitThrottle = .5,
   ForceOverwritePickup = nil,
   GenericEffectTimeout = 15,
   TelekinesisSteerInfluence = 2, -- // T-077: how strongly a Telekinesis boomerang turns toward the owner's aim each second (bias, not full control). Tunable live via Cmdr `tune TelekinesisInfluence`.
   ElectricChainRadius = 15, -- // Studs: an Electric boomerang elimination chains to every enemy within this distance of the victim
   ElectricChainLinkDelay = 0.05, -- // Seconds between each link of an Electric chain
   -- // Recall range: when a thrown boomerang would start returning on its own (end of its flight, or out of bounces),
   -- // it only does so if it's within this many studs (horizontally) of its player and can see them (nothing solid in
   -- // between, T-063). Otherwise it loses momentum and
   -- // drops into the dead state, like after a clash, and must be manually recalled or picked up.
   BoomerangRecallRange = 30,
   -- // If true, a boomerang that is losing momentum because it was out of range resumes returning automatically when it
   -- // comes back into range and can see its player (line of sight, as for auto-return). On since 2026-10-03 (Sol, T-063).
   DyingBoomerangCanRecoverInRange = true,
   -- // A dying boomerang that keeps sliding away instead of landing returns to its player on its own (automatic recall,
   -- // no manual recall needed) once either limit is hit (T-062). Previously it snapped straight back at 100 studs.
   DyingBoomerangNoGroundRecallSeconds = 0.75, -- // Seconds of sliding with nothing below to land on
   DyingBoomerangMaxSlideDistance = 100, -- // Studs (horizontal) from where it started dying
   -- // Manual recall of a dying/dead boomerang (held recall): slower, heavier, sluggish lift with a visual tilt
   ManualRecallMomentumMultiplier = 0.15, -- // How quickly it accelerates/turns toward the player (1 = normal recall)
   ManualRecallLiftRate = 2.5, -- // How quickly it rises to hand height (normal from-ground lift is 8)
   ManualRecallMaxTiltDegrees = 35, -- // Visual tilt toward the player while it's being lifted
   ManualRecallHighlightFadeOutSeconds = 0.6, -- // The dead boomerang's highlight fades this slowly when a manual recall starts (normal fade: 0.1)
   ExplosiveBoomerangReturnSpeedMultiplier = 1.5, -- // While the effect is active: recall speed x this, and the post-explosion weapon lock / this

   MyBoomerangTrailColor = Color3.new(0.984314, 0.988235, 0.988235),
   EnemyBoomerangTrailColor = Color3.new(0.952941, 0.07451, 0.368627),

   DefaultWalkSpeed = 16,
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