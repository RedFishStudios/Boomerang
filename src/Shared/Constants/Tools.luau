
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Tool = {
   Id: string,
   LogicClass: "Boomerang" | "Shuriken" | "Fan" | string,

   Boomerang: {
      Bounces: number, -- How many times the boomerang can bounce of objects before exhaustion
      Speed: number
   }?
}

local Tools: {[string]: Tool} = GeneralUtil.deepFreeze({
   -- // Boomerangs // --
   ClassicBoomerang = {
      Id = "Boomerang",
      LogicClass = "Boomerang",

      Boomerang = {
         Bounces = 1,
         Speed = 100
      }
   },

   -- // Shurikens // --
   Shuriken = {
      Id = "Shuriken",
      LogicClass = "Shuriken"
   },

   -- // Fans // --
   Fan = {
      Id = "Fan",
      LogicClass = "Fan"
   },

   -- // Special Weapons // --
})
return Tools