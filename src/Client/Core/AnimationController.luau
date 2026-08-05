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

type TrackEntry = {
   Track: AnimationTrack,
   LoadedAnimationKey: string,
   AnimationObject: Animation,
   Layer: string,
}

type PlayerTracks = {
   [CoreTrackNames | string]: TrackEntry,
}

type PlayerTrackData = {
   Tracks: PlayerTracks,
   Character: Model,
   Animator: Animator,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local creatingTrackData: { [Player]: true } = {}
local playerTrackData: {
   [Player]: PlayerTrackData
} = {}

local DefaultCoreTrackNames: { CoreTrackNames } = { "Charging", "Throw", "Catch", "Stab", "Dash" }

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

   table.clear(entry)
end

local function getPlayerData(player: Player): PlayerTrackData?
   return playerTrackData[player]
end

local function getPlayerTracks(player: Player): PlayerTracks?
   local data = getPlayerData(player)
   if not data then
      return nil
   end
   return data.Tracks
end

local function createTrackEntry(animator: Animator, trackName: string, animationName: string): TrackEntry?
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

local function clear(player: Player)
   local data = getPlayerData(player)
   if not data then
      return
   end
   local tracks = data.Tracks
   if tracks then
      for name, entry in pairs(tracks) do
         destroyTrackEntry(entry)
         tracks[name] = nil
      end
   end
   table.clear(data)
   playerTrackData[player] = nil
end

local function getCurrentCharacterAndAnimator(player: Player, canYield: boolean?): (Model?, Animator?)
   local customCharacter = CharacterRenderController.getCharacterModel(player, canYield)
   if not customCharacter then
      return nil, nil
   end

   local humanoid = customCharacter:FindFirstChildOfClass("Humanoid") or customCharacter:WaitForChild("Humanoid", if canYield then 10 else 0)
   if not humanoid then
      return nil, nil
   end

   local animator = humanoid:FindFirstChildOfClass("Animator")
   if not animator then
      animator = Instance.new("Animator")
      animator.Parent = humanoid
   end

   return customCharacter, animator
end

local function areTracksCurrentForPlayer(player: Player, character: Model, animator: Animator): boolean
   local data = getPlayerData(player)
   if not data then
      return false
   end

   if data.Character ~= character then
      return false
   end

   if data.Animator ~= animator then
      return false
   end

   local tracks = data.Tracks
   if not tracks then
      return false
   end

   for _, coreTrackName in ipairs(DefaultCoreTrackNames) do
      local entry = tracks[coreTrackName]
      if not entry then
         return false
      end
      if not entry.Track:IsDescendantOf(animator) then
         return false
      end
      if not entry.AnimationObject:IsDescendantOf(animator) then
         return false
      end
   end

   return true
end

local function buildDefaultAnimationTracks(player: Player, character: Model, animator: Animator): PlayerTracks
   local tracks: PlayerTracks = {}
   for _, animationName in ipairs(DefaultCoreTrackNames) do
      local entry = createTrackEntry(animator, animationName, animationName)
      if entry then
         tracks[animationName] = entry
      end
   end

   playerTrackData[player] = {
      Tracks = tracks,
      Character = character,
      Animator = animator,
   }

   return tracks
end

local function ensureAnimationTracksForCurrentCharacter(player: Player, yield: number?): PlayerTracks?
   if creatingTrackData[player] then
      if not yield then
         return nil
      end

      local elapsed = 0
      repeat
         elapsed += RunService.Heartbeat:Wait()
      until elapsed > yield or not creatingTrackData[player]

      return getPlayerTracks(player)
   end

   creatingTrackData[player] = true

   local character, animator = getCurrentCharacterAndAnimator(player, yield ~= nil)
   if not character or not animator then
      creatingTrackData[player] = nil
      return nil
   end

   if not areTracksCurrentForPlayer(player, character, animator) then
      clear(player)
      buildDefaultAnimationTracks(player, character, animator)
   end

   creatingTrackData[player] = nil
   return getPlayerTracks(player)
end

local function playCoreAnimationLocal(player: Player, coreTrackName: CoreTrackNames)
   local tracks = ensureAnimationTracksForCurrentCharacter(player, 10)
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
   local tracks = getPlayerTracks(player)
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
   local tracks = getPlayerTracks(player)
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

   local tracks = ensureAnimationTracksForCurrentCharacter(player, true)
   if not tracks then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
   end

   local existing = tracks[trackName]
   if existing then
      destroyTrackEntry(existing)
      tracks[trackName] = nil
   end

   local customCharacter, animator = getCurrentCharacterAndAnimator(player, true)
   if not customCharacter or not animator then
      warn(`failed to create animation track {trackName} using {animation}`)
      return
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
   local tracks = getPlayerTracks(player)
   if not tracks then
      return
   end

   for _, trackData in pairs(tracks) do
      if trackData.Track and trackData.Track.IsPlaying then
         trackData.Track:Stop()
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationController.init()
   for _, existingPlayer in pairs(Players:GetPlayers()) do
      if CharacterRenderController.getCharacterModel(existingPlayer, false) then
         ensureAnimationTracksForCurrentCharacter(existingPlayer, false)
      end
   end

   CharacterRenderController.CustomCharacterLoaded:Add(function(customPlayer: Player, _customCharacter: Model)
      clear(customPlayer)
      ensureAnimationTracksForCurrentCharacter(customPlayer, true)
   end)

   PlayersUtil.CharacterDestroying:Add(function(destroyingPlayer: Player)
      clear(destroyingPlayer)
   end)

   PlayersUtil.PlayerRemoving:Add(function(removingPlayer: Player)
      clear(removingPlayer)
   end)
end

function AnimationController.start() end

function AnimationController.test() end

return AnimationController