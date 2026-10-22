local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Constants.Icons)

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
      Subtitle = "Dash to heal yourself!",
      Img = Icons.OnFireEffect
   },
   -- // Display-only: the Dash module shows this in the effects bar on the local client while the dash is cooling down. It is never
   -- // acquired (no item-acquired notification) and the server doesn't know about it.
   DashCooldown = {
      Id = "DashCooldown",
      Title = "Dash Cooldown",
      Subtitle = "You can dash again soon",
      Img = Icons.DashCooldown
   },
   Zapped = {
      Id = "Zapped",
      Title = "Zapped",
      Subtitle = "You're stunned for a moment",
      Img = 0
   },
   TeleportBoomerang = {
      Id = "TeleportBoomerang",
      Title = "Teleportation",
      Subtitle = "Teleport to where you throw",
      Img = Icons.TeleportBoomerang
   },
   FireBoomerang = {
      Id = "FireBoomerang",
      Title = "Flaming",
      Subtitle = "Create a trail of fire",
      Img = Icons.FireBoomerang
   },
   ElectricBoomerang = {
      Id = "ElectricBoomerang",
      Title = "Electric",
      Subtitle = "Electricity shocks players in range",
      Img = Icons.ElectricBoomerang
   },
   ExplosiveBoomerang = {
      Id = "ExplosiveBoomerang",
      Title = "Explosive",
      Subtitle = "Weapon will make an explosion",
      Img = Icons.ExplosiveBoomerang
   },
   HotPotato = {
      Id = "HotPotato",
      Title = "Hot Potato",
      Subtitle = "Pass the explosive to another player!",
      Img = Icons.HotPotato
   },
   Shield = {
      Id = "Shield",
      Title = "Shield",
      Subtitle = "Blocks the next hit you take",
      Img = Icons.ShieldPickup
   },
   Speedup = {
      Id = "Speedup",
      Title = "Speed Boost",
      Subtitle = "Move faster for a short time",
      Img = 8
   },
   DashNoclip = {
      Id = "DashNoclip",
      Title = "Clip Dash",
      Subtitle = "Dash straight through walls!",
      Img = 9
   },
   Decoy = {
      Id = "Decoy",
      Title = "Decoy",
      Subtitle = "A decoy will spawn to distract enemies",
      Img = Icons.DecoyPickup
   },
   Disguise = {
      Id = "Disguise",
      Title = "Disguise",
      Subtitle = "Become disguised when standing still",
      Img = Icons.DisguisePickup
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
      Img = Icons.HomingBoomerang
   },
   IceBoomerang = {
      Id = "IceBoomerang",
      Title = "Ice Weapon",
      Subtitle = "Weapon leaves a trail of ice",
      Img = 16
   },
   Telekinesis = {
      Id = "Telekinesis",
      Title = "Telekinesis",
      Subtitle = "Steer your weapon in flight",
      Img = 17
   },
}

return AcquirableNotifData