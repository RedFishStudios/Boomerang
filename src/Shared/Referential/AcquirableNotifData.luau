local AcquirableNotifData: {
   [string]: {
      Id: string,
      Title: string,
      Subtitle: string,
      Img: number
   }
} = {
   OnFire = {
      Id = "OnFire",
      Title = "On Fire",
      Subtitle = "Dash or enter water to survive",
      Img = 1
   },
   TeleportBoomerang = {
      Id = "TeleportBoomerang",
      Title = "Teleportation",
      Subtitle = "Teleport to where you throw",
      Img = 2
   },
   FireBoomerang = {
      Id = "FireBoomerang",
      Title = "Flaming",
      Subtitle = "Create a trail of fire",
      Img = 3
   },
   ElectricBoomerang = {
      Id = "ElectricBoomerang",
      Title = "Electric",
      Subtitle = "Use water to zap players",
      Img = 4
   },
   ExplosiveBoomerang = {
      Id = "ExplosiveBoomerang",
      Title = "Explosive",
      Subtitle = "Weapon will make an explosion",
      Img = 5
   },
   HotPotato = {
      Id = "HotPotato",
      Title = "Hot Potato",
      Subtitle = "Pass the explosive to another player!",
      Img = 6
   },
   Shield = {
      Id = "Shield",
      Title = "Shield",
      Subtitle = "Blocks the next hit you take",
      Img = 7
   },
   Speedup = {
      Id = "Speedup",
      Title = "Speed Boost",
      Subtitle = "Move faster for a short time",
      Img = 8
   },
   DashNoclip = {
      Id = "DashNoclip",
      Title = "Phase Dash",
      Subtitle = "Dash straight through obstacles",
      Img = 9
   },
   Decoy = {
      Id = "Decoy",
      Title = "Decoy",
      Subtitle = "A copy of you wanders off to distract others",
      Img = 10
   },
   Disguise = {
      Id = "Disguise",
      Title = "Disguise",
      Subtitle = "Blend in as a map object while standing still",
      Img = 11
   },
   BattleRoyale = {
      Id = "BattleRoyale",
      Title = "Battle Royale",
      Subtitle = "The storm closes in on your position",
      Img = 12
   },
   ExtraBoomerang = {
      Id = "ExtraBoomerang",
      Title = "Extra Weapon",
      Subtitle = "Throw two boomerangs instead of one",
      Img = 13
   },
   MultiBoomerang = {
      Id = "MultiBoomerang",
      Title = "Multi Weapon",
      Subtitle = "Weapon splits apart at the end of the throw",
      Img = 14
   },
   HomingBoomerang = {
      Id = "HomingBoomerang",
      Title = "Homing",
      Subtitle = "Weapon tilts toward nearby enemies",
      Img = 15
   },
   IceBoomerang = {
      Id = "IceBoomerang",
      Title = "Ice Weapon",
      Subtitle = "Weapon leaves a trail of ice",
      Img = 16
   },
   TelekinesisBoomerang = {
      Id = "TelekinesisBoomerang",
      Title = "Telekinesis",
      Subtitle = "Steer your weapon in flight",
      Img = 17
   },
}

return AcquirableNotifData