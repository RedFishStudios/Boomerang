--[[
  Author:
  @Soulsplosion
]]

local AnimationController = {}

local ReplicatedStorage = game.ReplicatedStorage

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local AnimationPlayedConnections: {
   [Player]: RBXScriptConnection
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


-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationController.init()
   PlayersUtil.CharacterLoaded:Add(function(player: Player, character: Model, humanoid: Humanoid)
      if AnimationPlayedConnections[player] then
         AnimationPlayedConnections[player]:Disconnect()
         AnimationPlayedConnections[player] = nil
      end

      local animator: Animator = humanoid:WaitForChild("Animator", 30)
      if not animator then
         return
      end

      -- in case it was somehow done while waiting
      if AnimationPlayedConnections[player] then
         AnimationPlayedConnections[player]:Disconnect()
         AnimationPlayedConnections[player] = nil
      end

      AnimationPlayedConnections[player] = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
         print("a player played an animation!")
      end)
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
      if AnimationPlayedConnections[player] then
         AnimationPlayedConnections[player]:Disconnect()
         AnimationPlayedConnections[player] = nil
      end
   end)
end

-- function AnimationController.start() end

-- function AnimationController.test() end

return AnimationController