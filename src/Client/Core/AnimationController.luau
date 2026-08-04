--[[
  Author:
  @Soulsplosion
]]

local AnimationController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game.ReplicatedStorage
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local AnimationLibrary = require(ReplicatedStorage.Shared.Library.AnimationLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

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
   PlayersUtil.CharacterLoaded:Add(function(player: Player)
      local elapsed = 0
      repeat
         elapsed += RunService.RenderStepped:Wait()
      until CharacterRenderController.getCharacterModel(player, false) or elapsed > 300
      local customCharacter = CharacterRenderController.getCharacterModel(player, false)
      if not customCharacter then
         warn(`AnimationController: Failed to find custom character model for player {player.Name}`)
         return
      end

      local humanoid: Humanoid = customCharacter:WaitForChild("Humanoid", 30)
      if not humanoid then
         warn(`AnimationController: Failed to find humanoid for custom character of player {player.Name}`)
         return 
      end

      local animator: Animator = humanoid:WaitForChild("Animator", 30)
      if not animator then
         warn(`AnimationController: Failed to find animator for custom character of player {player.Name}`)  
         return
      end

      -- TODO: set up animation tracks for this character!
   end)
  
   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      -- TODO: clear any local values!
   end)

   RunService:BindToSimulation(function(deltaTime)
      -- Check the current animation state of the local player
      -- If it is different than the target animation state, update the server
   end, Enum.StepFrequency.Hz60, 4000)
end

-- function AnimationController.start() end

-- function AnimationController.test() end

return AnimationController