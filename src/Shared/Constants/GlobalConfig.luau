local RunService = game:GetService("RunService")

local isStudio = RunService:IsStudio()

local GlobalConfig = {
   WeaponHeight = 21.081,
   DeathHeight = 14.207,

  -- PlayersRequredToStart = if isStudio then 1 else 2,
  PlayersRequiredToStart = 1,
   
   CharacterFocalHeight = 6.6,
   SkipVoting = false,
   CanHurtSelf = false,
   SpawnShieldDuration = 2,
   NilDataType = "nil_",
   AimFullStrength = 2.0,
   ForceEquippedTool = "ClassicBoomerang",
   ThrownWeaponTrailLifetime = .3,
   BoomerangHitThrottle = .5,
   ForceOverwritePickup = nil,
   GenericEffectTimeout = 15,

   MyBoomerangTrailColor = Color3.new(0.984314, 0.988235, 0.988235),
   EnemyBoomerangTrailColor = Color3.new(0.952941, 0.07451, 0.368627),

   DefaultWalkSpeed = 16,
   AimingWalkSpeed = (16 * .3),

   -- Use for debugging
   -- Enabling these can greatly increase lag or network traffic
   RaycastVisualizersEnabled = false,
   ProjectileHitboxVisualizerEnabled = false,
   ParryVisualizersEnabled = false,
   SyncAbilitiesToEveryPlayer = false
}

return GlobalConfig