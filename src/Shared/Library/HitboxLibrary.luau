local HitboxLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local immunized: {
   [Player]: {
      [string]: any
   }
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function HitboxLibrary.immunize(player: Player, source: string, id: any)
   print("immunizing player", player.Name, "for source", source, "with id", id)
      if not immunized[player] then
      immunized[player] = {}
   end
   immunized[player][source] = id
end

function HitboxLibrary.unImmunize(player: Player, source: string, id: any)
   if immunized[player] then
      local current = immunized[player][source]
      if current == id then
         print("successfully unimmunized")
         immunized[player][source] = nil
      end
      if not next(immunized[player]) then
         immunized[player] = nil
      end
   end
end

function HitboxLibrary.isImmunized(player: Player)
   print(player, immunized[player])
   if immunized[player] then
      return true
   end
   return false
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function HitboxLibrary.init()
   PlayersUtil.CharacterAdded:Add(function(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
      local immunizedId = math.random(10000000)
      HitboxLibrary.immunize(player, "SpawnProtection", immunizedId)
      task.wait(2)
      HitboxLibrary.unImmunize(player, "SpawnProtection", immunizedId)
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
      immunized[player] = nil
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, character: Model)
      immunized[player] = nil
   end)
end

return HitboxLibrary