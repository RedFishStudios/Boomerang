local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Tool = {
   Id: string,
   LogicClass: "Boomerang", -- Name of the logics module responsible for handling this weapon's behavior when thrown

   Boomerang: {
      Bounces: number, -- How many times the boomerang can bounce off objects before exhaustion
      HitboxRadius: number,
      Speed: number,
      ThrowDistance: number,
      ManualRecallSpeed: number -- Max speed (studs/s) of a held manual recall of a dying/dead boomerang
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
         Speed = 80,
         ThrowDistance = 70,
         ManualRecallSpeed = 80
      }
   },
   Shuriken = {
      Id = "Shuriken",
      LogicClass = "Boomerang",
      Boomerang = {
         Bounces = 3,
         HitboxRadius = 1,
         Speed = 80,
         ThrowDistance = 70,
         ManualRecallSpeed = 80
      }
   },
   Fan = {
      Id = "Fan",
      LogicClass = "Boomerang",
      Boomerang = {
         Bounces = 1,
         HitboxRadius = 3,
         Speed = 50,
         ThrowDistance = 70,
         ManualRecallSpeed = 50
      }
   },

   -- // Special Weapons // --
})
return Tools