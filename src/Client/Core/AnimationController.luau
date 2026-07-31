--[[
  Author:
  @Soulsplosion
]]

local AnimationController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game.ReplicatedStorage

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local AnimationLibrary = require(ReplicatedStorage.Shared.Library.AnimationLibrary)

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

local AnimationPlayedConnections: {
   [Player]: RBXScriptConnection
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function playLocalTestAnimation()
   local humanoid = PlayersUtil.getHumanoid(player)
   if not humanoid then
      return
   end

   local animator = humanoid:FindFirstChildOfClass("Animator")
   if not animator then
      animator = Instance.new("Animator")
      animator.Parent = humanoid
   end

   local animationData = Animations.Test
   if not animationData then
      return
   end

   local animation = Instance.new("Animation")
   animation.AnimationId = string.format("rbxassetid://%d", animationData.Id)

   local track = animator:LoadAnimation(animation)
   animation:Destroy()
   track.Looped = animationData.Looping
   track:Play(animationData.FadeIn)
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
   if gameProcessedEvent then
      return
   end

   if input.KeyCode == Enum.KeyCode.F then
      playLocalTestAnimation()
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationController.init()
   UserInputService.InputBegan:Connect(onInputBegan)

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
         --print("a player played an animation!")
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