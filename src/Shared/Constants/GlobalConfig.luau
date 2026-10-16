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
   -- // Boomerang ENERGY. A thrown boomerang starts with BoomerangMinEnergy (a tap) up to BoomerangMaxEnergy (aim held for a
   -- // full ChargeTime), and loses energy as it flies out. At 0 or below: over OPEN AIR it returns to the player whether or not
   -- // it can see them (it can't die with nothing to land on). Over GROUND it asks one question: is there a clear line of sight
   -- // to its player? Yes: it returns. No: it drops into the dead state and must be manually recalled or picked up.
   -- // A recall starts with BoomerangRecallEnergy; the way back costs no distance energy, only bounces, player hits and clashes.
   -- // At 0 again while returning it dies (once over ground). There is no distance limit.
   -- // Every value here is the default of a Cmdr `tuneboomerang` setting (MinEnergy, MaxEnergy, EnergyPerStud,
   -- // BounceEnergyCost, PlayerHitEnergyCost, ClashEnergyCost), so it can be tuned live. Min/Max apply from the next throw.
   BoomerangMinEnergy = 50, -- // Energy of a throw with no charge
   BoomerangMaxEnergy = 100, -- // Energy of a throw charged for a full ChargeTime
   BoomerangEnergyPerStud = 1, -- // Energy lost per stud flown while thrown (so 50-100 energy is about 50-100 studs of flight)
   BoomerangRecallEnergy = 30, -- // Energy a boomerang is refilled to when it starts returning because it ran out. Equal to the bounce cost, so any wall hit on the way back kills it
   BoomerangBounceEnergyCost = 30, -- // Energy lost when it bounces off a wall or other obstruction
   BoomerangPlayerHitEnergyCost = 10, -- // Energy lost when it strikes a player
   BoomerangClashEnergyCost = 40, -- // Energy lost when it strikes another boomerang mid-air (a clash)
   -- // The height (studs) of the flat block the boomerang casts to detect obstructions. ONE value drives both the bounce
   -- // blockcast while it flies AND the line-of-sight cast to the player's Hitbox at 0 energy, so the two always agree on what
   -- // is solid. Taller = walls up to that height count for both (centered on the boomerang's flight height). Tunable live with
   -- // Cmdr `setboomerangcastheight` (ObstructionCastLibrary).
   BoomerangRaycastHeight = 1,
   -- // A RETURNING boomerang bounces, takes player hits and loses energy exactly like an outgoing one. After a bounce (or clash) its
   -- // bounce momentum is in charge and fades back into steering toward the player over this many seconds (Cmdr `tune RecallBounceRecovery`).
   BoomerangRecallBounceRecoverySeconds = 0.35,
   -- // A dying boomerang that keeps sliding with nothing to land on returns to its player on its own after this long (T-062)
   DyingBoomerangNoGroundRecallSeconds = 0.75, -- // Seconds of sliding with nothing below to land on
   -- // While a boomerang is dying (sliding to a stop after running out of energy) it keeps checking for its player: with line of sight
   -- // and within this many studs (horizontal) it resumes its recall even at 0 energy. Checked this often (seconds), server only.
   DyingBoomerangRecallDistance = 50,
   DyingBoomerangRecallCheckSeconds = 0.1,
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
   AimingWalkSpeedMultiplier = 0.3, -- // Walk speed while aiming/charging a throw, as a fraction of the default walk speed (WalkSpeedLibrary.getDefault())

   -- // The game's Roblox group (community), checked by GroupMembershipService (Cmdr `setgroupid` overrides it per server).
   -- // Members can claim GroupRewardCurrency from the lobby Group Rewards chest once every 24 h (T-045).
   GroupId = 293180599,
   GroupRewardCurrency = 100, -- TODO:RELEASE placeholder (the real reward isn't decided yet)

   -- Use for debugging
   -- Enabling these can greatly increase lag or network traffic
   RaycastVisualizersEnabled = false,
   ProjectileHitboxVisualizerEnabled = false,
   LineOfSightVisualizerEnabled = false, -- // Default for the line-of-sight visualizer: when a boomerang runs out of energy the server draws the LOS cast (green = clear, red = blocked + hit marker) for a few seconds. Cmdr `togglelosvisualizer` changes it live.
   ToggleAuthorityView = false, -- // Default for the authority view: a neon red ball at the position the SERVER has for each thrown boomerang (AuthorityViewLibrary; Cmdr `toggleauthorityview` changes it live)
   ParryVisualizersEnabled = false,
   VisualizeElectricChainRadius = true, -- // Client-only red cylinder showing the chain radius around every Electric boomerang elimination
   SyncAbilitiesToEveryPlayer = false,
   -- // Cmdr developer console (F2): true = every player can use it in live servers (for client review builds).
   CmdrOpenToEveryone = true, -- TODO:RELEASE (T-052) RELEASE BLOCKER: must be false before public release, or every player can use admin commands (then only admins, see CmdrService)
   AuthoritativeCharacterDebugVisible = false, -- // Shows the server-authoritative character half-transparent (normally fully invisible)
   ShowAuthoritativeCharacterOnRenderFailure = true, -- // If a player's rendered model failed to load, show the authoritative character so they aren't invisible
}

return GlobalConfig