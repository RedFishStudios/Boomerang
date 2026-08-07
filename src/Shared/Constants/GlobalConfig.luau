local GlobalConfig = {
   BoomerangHeight = 6.6,
   CharacterFocalHeight = 6.6,
   SkipVoting = false,
   CanHurtSelf = false,
   MinimumNeededPlayers = 1,
   SpawnShieldDuration = 2,
   NilDataType = "Nil",
   AimFullStrength = 2.0,
   ForceEquippedTool = "ClassicBoomerang",
   ThrownWeaponTrailLifetime = .5, 

   DefaultWalkSpeed = 16,
   AimingWalkSpeed = (16 * .3),

   -- Use for debugging
   -- Enabling these can greatly increase lag or network traffic
   RaycastVisualizersEnabled = true,
   ProjectileHitboxVisualizerEnabled = false,
   ParryVisualizersEnabled = false,
   SyncAbilitiesToEveryPlayer = false
}

return GlobalConfig