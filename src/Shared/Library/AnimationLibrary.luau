--[[

animation system
- Client is completely in control of locomotion animations
- Client/server share custom animations

]]

local AnimationLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProviderService = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_SERVER = RunService:IsServer()
local ANIMATION_REMOTE = SimpleRemotes.getEvent("AnimationLibrary")

local ACTION_PLAY_CORE = "PlayCore"
local ACTION_STOP_CORE = "StopCore"
local ACTION_STOP_ALL_CORE = "StopAllCore"

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

local AnimationTracks: {
	[Player]: PlayerTracks,
} = {}

local creatingAnimationTracks: {[Player]: true} = {}

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

	if not IS_SERVER then
		ContentProviderService:PreloadAsync({ animation })
	end

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

local function loadAnimationTracks(player: Player, character: Model, humanoid: Humanoid)
   if creatingAnimationTracks[player] then
      return
   end
   creatingAnimationTracks[player] = true

   if AnimationTracks[player] then
		unloadAnimationTracks(player)
	end

	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator then
		print(`animator never loaded for {player}`)
		return
	end

	if AnimationTracks[player] then
		unloadAnimationTracks(player)
	end

	local tracks: PlayerTracks = {}

	local necessaryAnimationNames = { "Charging", "Throw", "Catch", "Stab", "Dash" }
	for _, animationName in ipairs(necessaryAnimationNames) do
		local entry = createTrackEntry(animator, animationName, animationName)
		if not entry then
			print(`animation service setup: no animation {animationName}`)
			continue
		end

		tracks[animationName] = entry
	end

	AnimationTracks[player] = tracks
   creatingAnimationTracks[player] = nil
end

local function characterLoaded(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
	loadAnimationTracks(player, character, humanoid)
end

local function playCoreAnimationLocal(player: Player, coreTrackName: CoreTrackNames)
	local humanoid = PlayersUtil.getHumanoid(player)
	if not humanoid then
		print("no humanoid")
		return
	end

	local tracks = AnimationTracks[player]
	if not tracks then
      if not player.Character or not player.Character:FindFirstChild("Humanoid") then
         warn(`animationtracks.playCoreAnimation failed, no character or humanoid for {player}`)
         return
      end
      loadAnimationTracks(player, player.Character, player.Character.Humanoid)
      tracks = AnimationTracks[player]
		if not tracks then
         warn(`animationtracks.playCoreAnimation failed, no tracks for {player}`)
         return
      end
	end

	local trackData = tracks[coreTrackName]
	if not trackData then
		warn(`animationtracks.playCoreAnimation failed, no track for {coreTrackName} and {player}`)
		return
	end

	local animation = trackData.LoadedAnimationKey
	local animationData = Animations[animation]
	if not animationData then
		return
	end

	local track = trackData.Track
	track:Play(animationData.FadeIn)

	task.spawn(function()
		local layer = trackData.Layer
		for _coreTrackName, _trackData in pairs(tracks) do
			if _coreTrackName ~= coreTrackName and _trackData.Layer == layer and _trackData.Track and _trackData.Track.IsPlaying then
				AnimationLibrary.stopCoreAnimation(player, _coreTrackName)
			end
		end
	end)
end

local function stopAllCoreAnimationsLocal(player: Player)
	local tracks = AnimationTracks[player]
	if not tracks then
		warn(`animationtracks.stopAllCoreAnimations failed, no tracks for {player}`)
		return
	end
	task.spawn(function()
		for _coreTrackName, _trackData in pairs(tracks) do
			if _trackData.Track and _trackData.Track.IsPlaying then
				AnimationLibrary.stopCoreAnimation(player, _coreTrackName)
			end
		end
	end)
end

local function stopCoreAnimationLocal(player: Player, coreTrackName: CoreTrackNames, debugId: string?)
	if coreTrackName == "Charging" then
		debugId = "misc"
	end
	if debugId then
		--warn(`STOPPING CORE ANIMATION {coreTrackName} for {player}`, debugId)
		--print(AnimationTracks)
	end
	local tracks = AnimationTracks[player]
	if not tracks then
		warn(`animationtracks.stopCoreAnimation failed, no tracks for {player}`)
		return
	end

	if debugId then
		for _, trackData in pairs(tracks) do
			if trackData.Track and trackData.Track.IsPlaying then
				print(trackData.Track)
			end
		end
	end

	local trackData = tracks[coreTrackName]
	if not trackData then
		if debugId then
			warn(`animationtracks.stopCoreAnimation failed, no track for {coreTrackName} and {player}`)
		end
		return
	end

	local track = trackData.Track
	if not track.IsPlaying then
		if debugId then
			print("track is not playing")
		end
		return
	end

	local animation = trackData.LoadedAnimationKey
	local animationData = Animations[animation]
	if not animationData then
		if debugId then
			print("no animation data found for ", animation)
		end
		return
	end

	if debugId then
		warn(`successfully stopped playing`)
	end
	track:Stop(animationData.FadeOut)
end

local function getPlayerByUserId(userId: number): Player?
	for _, player in pairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AnimationLibrary.playCoreAnimation(player: Player, coreTrackName: CoreTrackNames)
	if IS_SERVER then
		ANIMATION_REMOTE:FireAllClients(ACTION_PLAY_CORE, player.UserId, coreTrackName)
		return
	end

	playCoreAnimationLocal(player, coreTrackName)
end

function AnimationLibrary.stopAllCoreAnimations(player: Player)
	if IS_SERVER then
		ANIMATION_REMOTE:FireAllClients(ACTION_STOP_ALL_CORE, player.UserId)
		return
	end

	stopAllCoreAnimationsLocal(player)
end

function AnimationLibrary.stopCoreAnimation(player: Player, coreTrackName: CoreTrackNames, debugId: string?)
	if IS_SERVER then
		ANIMATION_REMOTE:FireAllClients(ACTION_STOP_CORE, player.UserId, coreTrackName)
		return
	end

	stopCoreAnimationLocal(player, coreTrackName, debugId)
end

function AnimationLibrary.setCoreAnimation(player: Player, trackName: string, animation: string)
	local animationData = Animations[animation]
	if not animationData then
		warn(`animation not found: {animation}`)
		return
	end

	local humanoid = PlayersUtil.getHumanoid(player)
	if not humanoid then
		warn(`setCoreAnimation failed, no humanoid for {player}`)
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks = AnimationTracks[player]
	if not tracks then
		tracks = {}
		AnimationTracks[player] = tracks
	end

	local existing = tracks[trackName]
	if existing then
		destroyTrackEntry(existing)
		tracks[trackName] = nil
	end

	local newEntry = createTrackEntry(animator, trackName, animation)
	if not newEntry then
		warn(`failed to create animation track {trackName} using {animation}`)
		return
	end

	tracks[trackName] = newEntry
end

function AnimationLibrary.playVariableAnimation(player: Player, animation: string)
end

function AnimationLibrary.stopAllTracks(player: Player)
   local Animator = player.Character.Humanoid.Animator
   local playingTracks = Animator:GetPlayingAnimationTracks()
   for _, track in pairs(playingTracks) do
      track:Stop()
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationLibrary.init()
	if IS_SERVER then
		return
	end

	for _, p in pairs(PlayersUtil.getPlayersWithLoadedCharacters()) do
		characterLoaded(p, p.Character, p.Character.Humanoid, p.Character.PrimaryPart)
	end

	PlayersUtil.CharacterLoaded:Add(characterLoaded)

	PlayersUtil.CharacterDestroying:Add(function(player: Player)
		if AnimationTracks[player] then
			unloadAnimationTracks(player)
		end
	end)

	PlayersUtil.PlayerRemoving:Add(function(player: Player)
		if AnimationTracks[player] then
			unloadAnimationTracks(player)
		end
	end)

	ANIMATION_REMOTE.OnClientEvent:Connect(function(action: string, userId: number, coreTrackName: CoreTrackNames?)
		local player = getPlayerByUserId(userId)
		if not player then
			return
		end

		if action == ACTION_PLAY_CORE then
			if coreTrackName then
				playCoreAnimationLocal(player, coreTrackName)
			end
			return
		end

		if action == ACTION_STOP_CORE then
			if coreTrackName then
				stopCoreAnimationLocal(player, coreTrackName)
			end
			return
		end

		if action == ACTION_STOP_ALL_CORE then
			stopAllCoreAnimationsLocal(player)
		end
	end)
end

function AnimationLibrary.start()

end

return AnimationLibrary
