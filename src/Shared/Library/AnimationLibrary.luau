local AnimationLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProviderService = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local IS_SERVER = RunService:IsServer()

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CoreTrackNames = "Charging" | "Throw" | "Catch"

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

local function characterLoaded(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
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

	local necessaryAnimationNames = { "Charging", "Throw", "Catch" }
	for _, animationName in ipairs(necessaryAnimationNames) do
		local entry = createTrackEntry(animator, animationName, animationName)
		if not entry then
			print(`animation service setup: no animation {animationName}`)
			continue
		end

		tracks[animationName] = entry
	end

	AnimationTracks[player] = tracks
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AnimationLibrary.playCoreAnimation(player: Player, coreTrackName: CoreTrackNames)
	local humanoid = PlayersUtil.getHumanoid(player)
	if not humanoid then
		print("no humanoid")
		return
	end

	local tracks = AnimationTracks[player]
	if not tracks then
		warn(`animationtracks.playCoreAnimation failed, no tracks for {player}`)
		return
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

function AnimationLibrary.stopCoreAnimation(player: Player, coreTrackName: CoreTrackNames)
	local tracks = AnimationTracks[player]
	if not tracks then
		warn(`animationtracks.stopCoreAnimation failed, no tracks for {player}`)
		return
	end

	local trackData = tracks[coreTrackName]
	if not trackData then
		warn(`animationtracks.stopCoreAnimation failed, no track for {coreTrackName} and {player}`)
		return
	end

	local track = trackData.Track
	if not track.IsPlaying then
		print("track is not playing")
		return
	end

	local animation = trackData.LoadedAnimationKey
	local animationData = Animations[animation]
	if not animationData then
		print("no animation data found for ", animation)
		return
	end

	track:Stop(animationData.FadeOut)
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

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationLibrary.init()
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
end

function AnimationLibrary.start()

end

return AnimationLibrary
