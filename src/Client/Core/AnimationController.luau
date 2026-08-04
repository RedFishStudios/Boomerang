--[[
  Author:
  @Soulsplosion

  Handles custom character animations

  NOTE: DOES NOT HANDLE LOCOMOTION OR EMOTE ANIMATIONS FOR THE PLAYER'S DEFAULT CHARACTER!
  Check CharacterRenderController for animations for locomotion/emotes that match roblox default animation functionality
  This is only for custom, game-context animations
]]

local AnimationController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProviderService = game:GetService("ContentProvider")

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CoreTrackNames = "Charging" | "Throw" | "Catch" | "Stab" | "Dash"

type PlayerTracks = {
   [CoreTrackNames | string]: {
      Track: AnimationTrack,
      LoadedAnimationKey: string,
      AnimationObject: Animation,
      Layer: string,
   },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local AnimationTracks: { [Player]: PlayerTracks } = {}
local creatingAnimationTracks: { [Player]: true } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function destroyTrackEntry(entry: { Track: AnimationTrack, AnimationObject: Animation })
   if entry.Track.IsPlaying then
      entry.Track:Stop()
   end

   if entry.Track.Parent then
      entry.Track:Destroy()
   end

   if entry.AnimationObject.Parent then
      entry.AnimationObject:Destroy()
   end
end

local function createTrackEntry(animator: Animator, trackName: string, animationName: string)
   local animationData = Animations[animationName]
   if not animationData then
      return nil
   end

   local animation = Instance.new("Animation")
   animation.Name = trackName
   animation.AnimationId = string.format("rbxassetid://%d", animationData.Id)
   animation.Parent = animator
   ContentProviderService:PreloadAsync({ animation })

   local track = animator:LoadAnimation(animation)
   track.Name = trackName
   track.Looped = animationData.Looping

   return {
      Track = track,
      LoadedAnimationKey = animationName,
      AnimationObject = animation,
      Layer = animationData.Layer,
   }
end

local function unloadAnimationTracks(player: Player)
   local tracks = AnimationTracks[player]
   if tracks then
      for name, entry in pairs(tracks) do
         destroyTrackEntry(entry)
         tracks[name] = nil
      end
   end
   AnimationTracks[player] = nil
end

local function getOrLoadTracks(player: Player, canYield: boolean?): PlayerTracks?
   if AnimationTracks[player] then
      return AnimationTracks[player]
   end

   if creatingAnimationTracks[player] then
      if not canYield then
         return nil
      end

      local elapsed = 0
      repeat
         elapsed += RunService.Heartbeat:Wait()
      until elapsed > 5 or not creatingAnimationTracks[player]

      return AnimationTracks[player]
   end

   creatingAnimationTracks[player] = true

   local customCharacter = CharacterRenderController.getCharacterModel(player, canYield)
   if not customCharacter then
      creatingAnimationTracks[player] = nil
      return nil
   end

   local humanoid = customCharacter:FindFirstChildOfClass("Humanoid") or customCharacter:WaitForChild("Humanoid", if canYield then 10 else 0)
   if not humanoid then
      creatingAnimationTracks[player] = nil
      return nil
   end

   local animator = humanoid:FindFirstChildOfClass("Animator")
   if not animator then
      animator = Instance.new("Animator")
      animator.Parent = humanoid
   end

   local tracks: PlayerTracks = {}
   for _, animationName in ipairs({ "Charging", "Throw", "Catch", "Stab", "Dash" }) do
      local entry = createTrackEntry(animator, animationName, animationName)
      if entry then
         tracks[animationName] = entry
      end
   end

   AnimationTracks[player] = tracks
   creatingAnimationTracks[player] = nil
   return tracks
end

local function playCoreAnimationLocal(player: Player, coreTrackName: CoreTrackNames)
   local tracks = getOrLoadTracks(player, true)
   if not tracks then
      warn(`animationtracks.playCoreAnimation failed, no tracks for {player}`)
      return
   end

   local trackData = tracks[coreTrackName]
   if not trackData then
      warn(`animationtracks.playCoreAnimation failed, no track for {coreTrackName} and {player}`)
      return
   end

   local animationData = Animations[trackData.LoadedAnimationKey]
   if not animationData then
      return
   end

   trackData.Track:Play(animationData.FadeIn)

   task.spawn(function()
      local layer = trackData.Layer
      for otherTrackName, otherTrackData in pairs(tracks) do
         if otherTrackName ~= coreTrackName and otherTrackData.Layer == layer and otherTrackData.Track and otherTrackData.Track.IsPlaying then
            AnimationController.stopCoreAnimation(player, otherTrackName)
         end
      end
   end)
end

local function stopAllCoreAnimationsLocal(player: Player)
   local tracks = AnimationTracks[player]
   if not tracks then
      return
   end

   task.spawn(function()
      for coreTrackName, trackData in pairs(tracks) do
         if trackData.Track and trackData.Track.IsPlaying then
            AnimationController.stopCoreAnimation(player, coreTrackName)
         end
      end
   end)
end

local function stopCoreAnimationLocal(player: Player, coreTrackName: CoreTrackNames)
   local tracks = AnimationTracks[player]
   if not tracks then
      return
   end

   local trackData = tracks[coreTrackName]
   if not trackData then
      return
   end

   local animationData = Animations[trackData.LoadedAnimationKey]
   if not animationData then
      return
   end

   trackData.Track:Stop(animationData.FadeOut)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationController.init()
   for _, existingPlayer in pairs(Players:GetPlayers()) do
      if CharacterRenderController.getCharacterModel(existingPlayer, false) then
         getOrLoadTracks(existingPlayer, false)
      end
   end

   CharacterRenderController.CustomCharacterLoaded:Add(function(customPlayer: Player, _customCharacter: Model)
      getOrLoadTracks(customPlayer, false)
   end)

   PlayersUtil.PlayerRemoving:Add(function(removingPlayer: Player)
      unloadAnimationTracks(removingPlayer)
   end)
end

function AnimationController.playCoreAnimation(player: Player, coreTrackName: CoreTrackNames)
   playCoreAnimationLocal(player, coreTrackName)
end

function AnimationController.stopAllCoreAnimations(player: Player)
   stopAllCoreAnimationsLocal(player)
end

function AnimationController.stopCoreAnimation(player: Player, coreTrackName: CoreTrackNames, _debugId: string?)
   stopCoreAnimationLocal(player, coreTrackName)
end

function AnimationController.setCoreAnimation(player: Player, trackName: string, animation: string)
   local animationData = Animations[animation]
   if not animationData then
      warn(`animation not found: {animation}`)
      return
   end

   local tracks = getOrLoadTracks(player, true)
   if not tracks then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
   end

   local existing = tracks[trackName]
   if existing then
      destroyTrackEntry(existing)
      tracks[trackName] = nil
   end

   local customCharacter = CharacterRenderController.getCharacterModel(player, true)
   if not customCharacter then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
   end

   local humanoid = customCharacter:FindFirstChildOfClass("Humanoid")
   if not humanoid then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
   end

   local animator = humanoid:FindFirstChildOfClass("Animator")
   if not animator then
      animator = Instance.new("Animator")
      animator.Parent = humanoid
   end

   local newEntry = createTrackEntry(animator, trackName, animation)
   if not newEntry then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
   end

   tracks[trackName] = newEntry
end

function AnimationController.playVariableAnimation(_player: Player, _animation: string)
end

function AnimationController.stopAllTracks(player: Player)
   local tracks = AnimationTracks[player]
   if not tracks then
      return
   end

   for _, trackData in pairs(tracks) do
      if trackData.Track and trackData.Track.IsPlaying then
         trackData.Track:Stop()
      end
   end
end

function AnimationController.start() end

function AnimationController.test() end

return AnimationController