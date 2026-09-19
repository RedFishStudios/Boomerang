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
      Title = "Teleport Boomerang",
      Subtitle = "Weapon will teleport you",
      Img = 2
   },
   FireBoomerang = {
      Id = "FireBoomerang",
      Title = "Fire Boomerang",
      Subtitle = "Weapon leaves a trail of fire",
      Img = 3
   },
   ElectricBoomerang = {
      Id = "ElectricBoomerang",
      Title = "Shock Boomerang",
      Subtitle = "Weapon zaps players touching water",
      Img = 4
   },
   ExplosiveBoomerang = {
      Id = "ExplosiveBoomerang",
      Title = "Bomb Boomerang",
      Subtitle = "Weapon will make an explosion",
      Img = 5
   },
   HotPotato = {
      Id = "HotPotato",
      Title = "Hot Potato",
      Subtitle = "Pass the explosive to another player!",
      Img = 6
   },
}

return AcquirableNotifData