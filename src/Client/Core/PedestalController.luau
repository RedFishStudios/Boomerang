--[[
	PedestalController

	Description:
	Displays a player's avatar on every pedestal in the world and plays the player's equipped emote on it.

	A pedestal is any BasePart or Model tagged "PlayerPedestal". Its `UserId` attribute (number) says whose avatar
	to show. The avatar is a standalone clone of that player's client-rendered character (see
	CharacterRenderController.getFreshCharacterModelForUserId), stood on the top surface of the pedestal, facing the
	pedestal's front (-Z, the way its LookVector points). The animation comes from the player's equipped "WinningEmote"
	cosmetic (PlayerCosmeticController, resolved by WinningEmoteLibrary, which falls back to its default animation)
	and follows later changes of it.

	The cosmetic's value may be an Animation, an animation asset id (digits, as a string or number) or a "rbxassetid://"
	string. If it can't be retrieved or understood, WinningEmoteLibrary's default animation plays instead.

	Pedestals are detected as they stream in (and out), and the avatar is rebuilt when `UserId` is added or changed.

	The server (PedestalService) creates each pedestal's label, a BillboardGui named LABEL_NAME. This controller
	adorns it to the pedestal itself (so it stays still while the avatar animates) and offsets it up to just above the
	top of the avatar as measured when the avatar was placed, plus a margin for animations that reach higher.
	It hides the label while the pedestal has no avatar.
]]

local PedestalController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local PlayerCosmeticController = require(ReplicatedStorage.Client.Core.PlayerCosmeticController)
local WinningEmoteLibrary = require(ReplicatedStorage.Shared.Library.WinningEmoteLibrary)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type PedestalState = {
	Request: number, -- // Bumped on every refresh/release; an async build that finds a newer number discards itself
	Model: Model?,
	AvatarTopY: number?, -- // World Y of the top of the avatar when it was placed (before animating)
	Track: AnimationTrack?,
	StopObserving: (() -> ())?,
	AttributeConnection: RBXScriptConnection?,
	ChildConnection: RBXScriptConnection?,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PEDESTAL_TAG = "PlayerPedestal"
local USER_ID_ATTRIBUTE = "UserId"
local COSMETIC_CATEGORY = "WinningEmote"
local ASSET_ID_PREFIX = "rbxassetid://"
local LABEL_NAME = "PedestalLabel"
local LABEL_PADDING = 2.25 -- // Studs between the top of the avatar (at rest) and the bottom of the label; room for raised arms

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local states: { [Instance]: PedestalState } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function toAnimation(value: any): Animation?
	if typeof(value) == "Instance" and value:IsA("Animation") then
		return value
	end

	local animationId: string? = nil
	if type(value) == "number" and value > 0 then
		animationId = `{ASSET_ID_PREFIX}{value}`
	elseif type(value) == "string" and value:sub(1, #ASSET_ID_PREFIX) == ASSET_ID_PREFIX then
		animationId = value
	elseif type(value) == "string" and value:match("^%d+$") then
		animationId = `{ASSET_ID_PREFIX}{value}`
	end
	if not animationId then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return animation
end

-- // A part of the pedestal that doesn't move: the pedestal itself, or a part of it that isn't the avatar
local function getLabelAdornee(pedestal: Instance, avatar: Model): BasePart?
	if pedestal:IsA("BasePart") then
		return pedestal
	end
	if pedestal:IsA("Model") and pedestal.PrimaryPart then
		return pedestal.PrimaryPart
	end
	for _, descendant in pedestal:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant:IsDescendantOf(avatar) then
			return descendant
		end
	end
	return nil
end

-- // Shows the pedestal's label above the avatar, or hides it when there is no avatar. The label is adorned to the
--   pedestal (static) and offset upward, so it doesn't follow the animation.
local function updateLabel(pedestal: Instance, state: PedestalState)
	local label = pedestal:FindFirstChild(LABEL_NAME)
	if not label or not label:IsA("BillboardGui") then
		return
	end

	local avatar = state.Model
	local avatarTopY = state.AvatarTopY
	local adornee = if avatar and avatarTopY then getLabelAdornee(pedestal, avatar) else nil
	if not adornee or not avatarTopY then
		label.Enabled = false
		label.Adornee = nil
		return
	end

	label.Adornee = adornee
	label.StudsOffsetWorldSpace = Vector3.new(0, avatarTopY + LABEL_PADDING + label.Size.Y.Scale / 2 - adornee.Position.Y, 0)
	label.Enabled = true
end

local function stopAnimation(state: PedestalState)
	if state.Track then
		state.Track:Stop(0)
		state.Track:Destroy()
		state.Track = nil
	end
end

local function clearAvatar(pedestal: Instance, state: PedestalState)
	if state.StopObserving then
		state.StopObserving()
		state.StopObserving = nil
	end
	stopAnimation(state)
	if state.Model then
		state.Model:Destroy()
		state.Model = nil
	end
	state.AvatarTopY = nil
	updateLabel(pedestal, state)
end

-- // Plays the player's equipped cosmetic on the model, or leaves it without animation if it can't be retrieved
local function playEquippedAnimation(state: PedestalState, model: Model, player: Player)
	stopAnimation(state)

	local ok, value = pcall(PlayerCosmeticController.get, player, COSMETIC_CATEGORY)
	local animation = if ok then toAnimation(value) else nil
	if not animation then
		animation = toAnimation(WinningEmoteLibrary.DEFAULT_ANIMATION_ID)
	end
	if not animation then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not loaded then
		warn(`PedestalController: Failed to load animation for {player.Name}`)
		return
	end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
	state.Track = track
end

-- // The center of the pedestal's top surface; its up vector is the pedestal's, its front the pedestal's front
local function getTopCFrame(pedestal: Instance): CFrame?
	if pedestal:IsA("Model") then
		local boxCFrame, boxSize = pedestal:GetBoundingBox()
		return boxCFrame * CFrame.new(0, boxSize.Y / 2, 0)
	elseif pedestal:IsA("BasePart") then
		return pedestal.CFrame * CFrame.new(0, pedestal.Size.Y / 2, 0)
	end
	return nil
end

-- // Makes the clone purely visual and stands it on the pedestal. Returns the world Y of the top of the model at rest,
--   or nil if it can't be placed.
local function placeModel(pedestal: Instance, model: Model): number?
	local topCFrame = getTopCFrame(pedestal)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not topCFrame or not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	root.Anchored = true
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local rootCFrame = topCFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	model:PivotTo(rootCFrame * root.CFrame:ToObjectSpace(model:GetPivot()))

	local boxCFrame, boxSize = model:GetBoundingBox()
	return boxCFrame.Position.Y + boxSize.Y / 2
end

local function refresh(pedestal: Instance)
	local state = states[pedestal]
	if not state then
		return
	end

	state.Request += 1
	local request = state.Request
	clearAvatar(pedestal, state)

	local userId = pedestal:GetAttribute(USER_ID_ATTRIBUTE)
	if type(userId) ~= "number" then
		return
	end

	task.spawn(function()
		local model = CharacterRenderController.getFreshCharacterModelForUserId(userId)
		if states[pedestal] ~= state or state.Request ~= request then
			if model then
				model:Destroy()
			end
			return
		end
		if not model then
			warn(`PedestalController: No character model available for UserId {userId}`)
			return
		end
		local avatarTopY = placeModel(pedestal, model)
		if not avatarTopY then
			warn(`PedestalController: Could not place the model for UserId {userId} on pedestal {pedestal:GetFullName()}`)
			model:Destroy()
			return
		end

		model.Name = "PedestalAvatar"
		model.Parent = pedestal
		state.Model = model
		state.AvatarTopY = avatarTopY
		updateLabel(pedestal, state)

		local player = Players:GetPlayerByUserId(userId)
		if player then
			playEquippedAnimation(state, model, player)
			state.StopObserving = PlayerCosmeticController.observe(player, COSMETIC_CATEGORY, function()
				if state.Model == model then
					playEquippedAnimation(state, model, player)
				end
			end)
		end
	end)
end

local function onPedestalAdded(pedestal: Instance)
	if states[pedestal] then
		return
	end

	local state: PedestalState = { Request = 0 }
	states[pedestal] = state
	state.AttributeConnection = pedestal:GetAttributeChangedSignal(USER_ID_ATTRIBUTE):Connect(function()
		refresh(pedestal)
	end)
	-- // The label may replicate after the avatar is already placed
	state.ChildConnection = pedestal.ChildAdded:Connect(function(child)
		if child.Name == LABEL_NAME then
			updateLabel(pedestal, state)
		end
	end)
	refresh(pedestal)
end

local function onPedestalRemoved(pedestal: Instance)
	local state = states[pedestal]
	if not state then
		return
	end

	states[pedestal] = nil
	state.Request += 1
	if state.AttributeConnection then
		state.AttributeConnection:Disconnect()
		state.AttributeConnection = nil
	end
	if state.ChildConnection then
		state.ChildConnection:Disconnect()
		state.ChildConnection = nil
	end
	clearAvatar(pedestal, state)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PedestalController.start()
	CollectionService:GetInstanceAddedSignal(PEDESTAL_TAG):Connect(onPedestalAdded)
	CollectionService:GetInstanceRemovedSignal(PEDESTAL_TAG):Connect(onPedestalRemoved)
	for _, pedestal in CollectionService:GetTagged(PEDESTAL_TAG) do
		task.spawn(onPedestalAdded, pedestal)
	end
end

return PedestalController
