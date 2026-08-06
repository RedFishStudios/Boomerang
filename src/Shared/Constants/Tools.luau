local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Tool = {
   Id: string,
   LogicClass: "Boomerang", -- Name of the logics module responsible for handling this weapon's behavior when thrown

   Boomerang: {
      Bounces: number, -- How many times the boomerang can bounce off objects before exhaustion
      HitboxRadius: number,
      Speed: number,
      ThrowDistance: number
   }?
}

local Tools: {[string]: Tool} = GeneralUtil.deepFreeze({
   -- // Boomerangs // --
   ClassicBoomerang = {
      Id = "Boomerang",
      LogicClass = "Boomerang",
      Boomerang = {
         Bounces = 2,
         HitboxRadius = 2,
         Speed = 60,
         ThrowDistance = 30
      }
   },
   Shuriken = {
      Id = "Shuriken",
      LogicClass = "Boomerang",
      Boomerang = {
         Bounces = 3,
         HitboxRadius = 1,
         Speed = 80,
         ThrowDistance = 40
      }
   },
   Fan = {
      Id = "Fan",
      LogicClass = "Boomerang",
      Boomerang = {
         Bounces = 1,
         HitboxRadius = 3,
         Speed = 50,
         ThrowDistance = 20
      }
   },

   -- // Special Weapons // --
})
return Tools