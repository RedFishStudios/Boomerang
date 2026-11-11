local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

export type ToolCategory = "Boomerang" | "Fan" | "Shuriken"

export type Tool = {
   Id: string,
   Category: ToolCategory, -- Which Weapons Shop tab lists it
   LogicClass: "Boomerang", -- Name of the logics module responsible for handling this weapon's behavior when thrown
   Rarity: string?, -- Shown in the Inventory (e.g. "Common"); not used by gameplay
   CrateWeight: number?, -- // Weighted chance in its category's crate (Shared/Referential/Crates); nil/0 = not in the crate
   Viewport: { -- How the model is posed in GUI item viewports (Client/UI/ItemViewport)
      Rotation: CFrame, -- Model orientation; the camera looks at it along -Z and is fitted automatically
      Zoom: number?, -- Above 1 moves the camera closer (when the bounding box is much bigger than the visible shape)
   }?,

   Boomerang: {
      HitboxRadius: number,
      Speed: number,
      ManualRecallSpeed: number -- Max speed (studs/s) of a held manual recall of a dying/dead boomerang
   }?
}

local Tools: {[string]: Tool} = GeneralUtil.deepFreeze({
   -- // Each tool id is also the name of its model in Shared/Assets/Tools; its Category picks the Weapons Shop tab.
   -- // The "Placeholder..." tools are copies (same model and stats) standing in for a second weapon per category.

   -- // Boomerangs // --
   ClassicBoomerang = {
      Id = "Boomerang",
      Category = "Boomerang",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 70, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(25)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 2,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   PlaceholderBoomerang = { -- TODO:RELEASE placeholder (copy of ClassicBoomerang)
      Id = "PlaceholderBoomerang",
      Category = "Boomerang",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 30, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(25)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 2,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },

   -- // Shurikens // --
   ClassicShuriken = {
      Id = "ClassicShuriken",
      Category = "Shuriken",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 70, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(15)) * CFrame.Angles(math.rad(75), 0, 0), Zoom = 1.2 },
      Boomerang = {
         HitboxRadius = 1,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   PlaceholderShuriken = { -- TODO:RELEASE placeholder (copy of ClassicShuriken)
      Id = "PlaceholderShuriken",
      Category = "Shuriken",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 30, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(15)) * CFrame.Angles(math.rad(75), 0, 0), Zoom = 1.2 },
      Boomerang = {
         HitboxRadius = 1,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },

   -- // Fans // --
   ClassicFan = {
      Id = "ClassicFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 70, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   PlaceholderFan = { -- TODO:RELEASE placeholder (copy of ClassicFan)
      Id = "PlaceholderFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Common", -- TODO:RELEASE placeholder
      CrateWeight = 30, -- TODO:RELEASE placeholder
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   -- // Fan skins: stats copied from ClassicFan, not in any crate (no CrateWeight)
   SunsetPopFan = {
      Id = "SunsetPopFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Common",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   BambooBreezeFan = {
      Id = "BambooBreezeFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Common",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   TidalSurgeFan = {
      Id = "TidalSurgeFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Rare",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   SakuraDriftFan = {
      Id = "SakuraDriftFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Rare",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   MoonsongFan = {
      Id = "MoonsongFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Epic",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },
   SunfirePhoenixFan = {
      Id = "SunfirePhoenixFan",
      Category = "Fan",
      LogicClass = "Boomerang",
      Rarity = "Legendary",
      Viewport = { Rotation = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(math.rad(75), 0, 0) },
      Boomerang = {
         HitboxRadius = 3,
         Speed = 75,
         ManualRecallSpeed = 200
      }
   },

   -- // Special Weapons // --
})
return Tools