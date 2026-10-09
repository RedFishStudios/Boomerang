local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type Tool = {
   Id: string,
   LogicClass: "Boomerang", -- Name of the logics module responsible for handling this weapon's behavior when thrown
   Rarity: string?, -- Shown in the Inventory (e.g. "Common"); not used by gameplay
   Viewport: { -- How the model is posed in GUI item viewports (Client/UI/ItemViewport)
      Rotation: CFrame, -- Model orientation; the camera looks at it along -Z and is fitted automatically
      Zoom: number?, -- Above 1 moves the camera closer (when the bounding box is much bigger than the visible shape)
   }?,

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
      Rarity = "Common", -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(25)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         Bounces = 2,
         HitboxRadius = 2,
         Speed = 0,
         ThrowDistance = 70,
         ManualRecallSpeed = 50
      }
   },
   Shuriken = {
      Id = "Shuriken",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(15)) * CFrame.Angles(math.rad(75), 0, 0), Zoom = 1.2 },
      Boomerang = {
         Bounces = 3,
         HitboxRadius = 1,
         Speed = 50,
         ThrowDistance = 70,
         ManualRecallSpeed = 50
      }
   },
   Fan = {
      Id = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
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