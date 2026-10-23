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
   -- // The world Y every boomerang flies at: a thrown boomerang starts there, and a manually recalled dead boomerang lifts to it and
   -- // returns at it. It doesn't depend on the player's height (jumps, dashes). Obstructions are only detected within BoomerangRaycastHeight
   -- // of it, so it must sit inside the arena walls. 158.2 is what live thrown boomerangs measured in a playtest (they drew at 158.1 to 158.4
   -- // while the character's root part stood at about 159.25).
   BoomerangFlightHeight = 158.7,
   BoomerangVisualHeightSyncSeconds = 1.5, -- // A thrown boomerang is DRAWN from the thrower's height and eases to BoomerangFlightHeight within this long (visual only)
   -- // Radius (studs) of every player's Hitbox, the vertical cylinder boomerangs hit (3.3 studs across). A boomerang strikes a player when
   -- // its own radius (tool HitboxRadius) plus this reaches them. Live-tunable with Cmdr `sethitboxradius` (HitboxService).
   PlayerHitboxRadius = 1.65,
   -- // A RETURNING boomerang bounces, takes player hits and loses energy exactly like an outgoing one. After a bounce (or clash) its
   -- // bounce momentum is in charge and fades back into steering toward the player over this many seconds (Cmdr `tune RecallBounceRecovery`).
   BoomerangRecallBounceRecoverySeconds = 0.35,
   -- // A dying boomerang that keeps sliding with nothing to land on returns to its player on its own after this long (T-062)
   DyingBoomerangNoGroundRecallSeconds = 0.75, -- // Seconds of sliding with nothing below to land on
   -- // While a boomerang is dying (sliding to a stop after running out of energy) it keeps checking for its player: with line of sight
   -- // and within this many studs (horizontal) it resumes its recall even at 0 energy. Checked this often (seconds), server only.
   DyingBoomerangRecallDistance = 50,
   DyingBoomerangRecallCheckSeconds = 0.1,
   -- // Before a boomerang dies the server also simulates its dying slide this many seconds ahead; if the player would be in sight and
   -- // within range at any point of it, the boomerang keeps returning instead of dying (no die-then-revive flicker).
   DyingBoomerangRecallLookaheadSeconds = 0.4,
   -- // Manual recall of a dying/dead boomerang (held recall): slower and heavier. It must first be charged (RecallCharge below)
   CrateClicksToOpen = 20, -- // T-114: clicks / taps it takes to open a bought weapon crate (CrateService). TODO:RELEASE placeholder
   RecallCharge = 0.3, -- // T-092: seconds a tapped manual recall charges (boomerang stays on the ground, player slowed, no dash, can't be interrupted) before it starts returning
   ManualRecallRiseSeconds = 0.8, -- // T-095 (only if Boomerang.luau's MANUAL_RECALL_RISES_DURING_FLIGHT is on; the charge lifts it now): a manual recall rises from the ground to BoomerangFlightHeight over this long (eased start and finish)
   ManualRecallLiftRate = 2.5, -- // UNUSED for manual recalls since T-095 -- // How quickly a manually recalled boomerang rises to flight height while returning (the automatic from-ground lift is 8)
   ManualRecallMaxTiltDegrees = 35, -- // Visual tilt toward the player while it's being lifted
   RecallChargeCancelDropSeconds = 0.25, -- // UNUSED since T-104 (a released charge now falls and slides with the dying motion, see Dead.luau RELEASE_MOMENTUM) -- // Releasing the recall before it is charged drops the boomerang back to the ground over this long
   DeadBeamFadeSeconds = 0.4, -- // T-094: the beam to a dead boomerang fades in / out over this long (a full 0 to 1 fade)
   RecallChargeBeamOpacity = 0.2, -- // UNUSED since T-094 (the beam now fades to invisible as the charge builds) -- // The player-to-dead-boomerang beam fades to at most this opacity while the recall is charging (1 = normal beam)
   RecallReturnBeamFadeInSeconds = 0.3, -- // The beam to the returning boomerang fades in over this long once the charged recall starts moving it
   SelectionRingGrowSeconds = 0.3, -- // The SelectionRing tweens from nothing to full size (with a small overshoot) over this long
   SelectionRingVanishSeconds = 0.15, -- // ...and shrinks away over this long when the recall is released early
   ManualRecallMomentumMultiplier = 0.15, -- // How quickly its heading swings toward the player (1 = normal recall). Tunable live via Cmdr `tune RecallCurveAcceleration`
   ManualRecallAcceleration = 1, -- // How quickly it reaches full recall speed and spin (1 = the time set by MANUAL_RECALL_FULL_SPEED_SECONDS in Boomerang.luau; 2 = twice as fast). Tunable live via Cmdr `tune RecallAcceleration`
   -- // Manual recall speed-up: the boomerang starts at ManualRecallRampStartFraction of its max recall speed and builds up
   -- // along a curve that stays slow at first and then climbs steeply, reaching max speed after MANUAL_RECALL_FULL_SPEED_SECONDS / RecallAcceleration.
   -- // speed = max * (StartFraction + (1 - StartFraction) * (t / RampSeconds) ^ RampPower). Tunable live via Cmdr `tune RecallAcceleration` / `RecallRampPower`.
   ManualRecallRampPower = 3, -- // Curve steepness: 1 = steady speed-up, higher = slower start and a sharper late surge
   ManualRecallRampStartFraction = 0.12, -- // Fraction of max recall speed at the moment the recall starts
   ManualRecallHighlightFadeOutSeconds = 0.6, -- // The dead boomerang's highlight fades this slowly when a manual recall starts (normal fade: 0.1)
   DeadWeaponDeceleration = 4, -- // How much faster a boomerang loses its slide momentum (and spin) and drops to the ground once it starts dying (1 = the original pace). The slide itself is set up in Dead.luau (INTERNAL CONFIG: dying slide "on ice"). Tunable live via Cmdr `tune DeadWeaponDeceleration`.
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

   LagCompensationMilliseconds = 200, -- // Most the server rewinds players when a boomerang sweep checks for hits (LagCompensationLibrary). 0 = lag compensation off. Cmdr `setlagcompensation` changes it live.

   -- Use for debugging
   -- Enabling these can greatly increase lag or network traffic
   RaycastVisualizersEnabled = false,
   ProjectileHitboxVisualizerEnabled = false, -- // Default for the red server-position part on thrown boomerangs. Cmdr `toggleprojectilevisualizer` changes it live (affects boomerangs thrown afterwards).
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