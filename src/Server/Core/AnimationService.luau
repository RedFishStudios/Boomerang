local AnimationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Constants.Animations)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local animationRemote = SimpleRemotes.getEvent("Animation")

local ACTION_PLAY_TEST = "PlayTest"

local AnimationTracks: {
   [Player]: {
      [string]: AnimationTrack
   }
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function playAnimationOnPlayerCharacter(player: Player, animationName: string)
	local animationData = Animations[animationName]
	if not animationData then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = string.format("rbxassetid://%d", animationData.Id)

	local track = animator:LoadAnimation(animation)
	track.Looped = animationData.Looping
	track:Play()
end

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(animationRemote, {
		[ACTION_PLAY_TEST] = function(player: Player)
			playAnimationOnPlayerCharacter(player, "Test")
		end,
	})
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AnimationService.init()
	loadRemotes()
end

-- function AnimationService.start() end

-- function AnimationService.test() end

return AnimationService