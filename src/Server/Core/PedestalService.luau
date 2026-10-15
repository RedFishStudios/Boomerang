--[[
	PedestalService

	Description:
	Server side of the player pedestals (see PedestalController on the client, which renders whoever a pedestal's
	`UserId` attribute points to). This service owns those `UserId` attributes.

	Currently it manages the "WinnerPedestal" (a pedestal tagged "PlayerPedestal" and named "WinnerPedestal"): when a
	round ends it shows the winner of that round. When several players share the win (a tie, or a winning team),
	it steps through them, changing the UserId every TIED_WINNER_SWITCH_INTERVAL seconds and looping.
	Until the first round ends, the pedestal keeps whatever UserId it was placed with in Studio.
	The emote the avatar performs is also set here: the pedestal's EMOTE_ATTRIBUTE ("EmoteAnimationId", an animation
	asset id) is the displayed player's equipped WinningEmote (CosmeticLibrary / WinningEmoteLibrary), kept up to date if
	that player equips another one. PedestalController just plays whatever that attribute says.

	Every pedestal can also show a text label. The server builds the label's BillboardGui (a child of the pedestal
	named LABEL_NAME, with a "Title" and a "Subtitle" TextLabel) and sets its text/style with `setLabel`; each pedestal
	can have its own. The BillboardGui starts disabled: PedestalController enables it and positions it above the
	avatar's head once the avatar is on the pedestal.
]]

local PedestalService = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local WinningEmoteLibrary = require(ReplicatedStorage.Shared.Library.WinningEmoteLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PEDESTAL_TAG = "PlayerPedestal"
local WINNER_PEDESTAL_NAME = "WinnerPedestal"
local USER_ID_ATTRIBUTE = "UserId"
local EMOTE_ATTRIBUTE = "EmoteAnimationId"
local TIED_WINNER_SWITCH_INTERVAL = 2.5

local LABEL_NAME = "PedestalLabel"
local LABEL_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local LABEL_SIZE = UDim2.fromScale(12, 3.5) -- // Studs
local LABEL_MAX_DISTANCE = 150
local WINNER_TITLE = "WINNER"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type LabelStyle = {
	TextColor: Color3,
	StrokeColor: Color3,
	StrokeThickness: number?,
}

-------------------------------------------------------------------------------
-- STYLES
-------------------------------------------------------------------------------

local DEFAULT_LABEL_STYLE: LabelStyle = {
	TextColor = Color3.new(1, 1, 1),
	StrokeColor = Color3.new(0, 0, 0),
}

-- // Bright gold with a dark brown outline
local WINNER_LABEL_STYLE: LabelStyle = {
	TextColor = Color3.fromRGB(255, 208, 35),
	StrokeColor = Color3.fromRGB(70, 38, 0),
	StrokeThickness = 3,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local winnerPedestals: { [Instance]: true } = {}
local displayedUserId: number? = nil
-- // Bumped whenever a new round result arrives, which stops any running tie cycle
local displayVersion = 0

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function createLabelText(name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = LABEL_FONT
	label.Text = ""

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Parent = label
	return label
end

local function getOrCreateLabel(pedestal: Instance): BillboardGui
	local existing = pedestal:FindFirstChild(LABEL_NAME)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = LABEL_NAME
	gui.Size = LABEL_SIZE
	gui.MaxDistance = LABEL_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false -- // PedestalController enables it once it has positioned it above the avatar
	createLabelText("Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55)).Parent = gui
	createLabelText("Subtitle", UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.42)).Parent = gui
	gui.Parent = pedestal
	return gui
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Sets the text and look of a pedestal's label (creating the label if the pedestal has none). Each pedestal can show
--- different text. An empty/nil subtitle shows only the title.
function PedestalService.setLabel(pedestal: Instance, title: string, subtitle: string?, style: LabelStyle?)
	local gui = getOrCreateLabel(pedestal)
	local appliedStyle = style or DEFAULT_LABEL_STYLE
	for _, name in { "Title", "Subtitle" } do
		local label = gui:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			label.TextColor3 = appliedStyle.TextColor
			local stroke = label:FindFirstChild("Stroke")
			if stroke and stroke:IsA("UIStroke") then
				stroke.Color = appliedStyle.StrokeColor
				stroke.Thickness = appliedStyle.StrokeThickness or 2
			end
			label.Text = if name == "Title" then title else (subtitle or "")
		end
	end
end

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS (WINNER PEDESTAL)
-------------------------------------------------------------------------------

-- // "WINNER" over "DisplayName @Username!". Players who aren't in the server keep the previous text.
local function applyWinnerLabel(pedestal: Instance, userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	PedestalService.setLabel(pedestal, WINNER_TITLE, `{player.DisplayName} @{player.Name}!`, WINNER_LABEL_STYLE)
end

-- // The pedestal performs the displayed player's equipped winning emote. Players who aren't in the server keep the previous one.
local function applyWinnerEmote(pedestal: Instance, userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end
	local animationId = WinningEmoteLibrary.getAnimationId(CosmeticLibrary.getEquippedRaw(player, "WinningEmote"))
	pedestal:SetAttribute(EMOTE_ATTRIBUTE, animationId)
end

local function setWinnerUserId(userId: number)
	displayedUserId = userId
	for pedestal in winnerPedestals do
		applyWinnerEmote(pedestal, userId) -- // Before the UserId, so the client sees the emote when it builds the avatar
		pedestal:SetAttribute(USER_ID_ATTRIBUTE, userId)
		applyWinnerLabel(pedestal, userId)
	end
end

local function registerPedestal(instance: Instance)
	if instance.Name ~= WINNER_PEDESTAL_NAME or winnerPedestals[instance] then
		return
	end
	winnerPedestals[instance] = true
	getOrCreateLabel(instance)
	if displayedUserId then
		applyWinnerEmote(instance, displayedUserId)
		instance:SetAttribute(USER_ID_ATTRIBUTE, displayedUserId)
	end
	local userId = instance:GetAttribute(USER_ID_ATTRIBUTE)
	if type(userId) == "number" then
		applyWinnerEmote(instance, userId)
		applyWinnerLabel(instance, userId)
	end
end

-- // Loops through the userIds forever (until superseded), skipping players who have left
local function cycleUserIds(userIds: { number }, version: number)
	local index = 0
	while displayVersion == version do
		local found = false
		for _ = 1, #userIds do
			index = index % #userIds + 1
			if Players:GetPlayerByUserId(userIds[index]) then
				found = true
				break
			end
		end
		if not found then
			return
		end

		setWinnerUserId(userIds[index])
		task.wait(TIED_WINNER_SWITCH_INTERVAL)
	end
end

local function onRoundFinished(winner: Player?, _winningTeam: Team?, _isTie: boolean?, winners: { Player }?)
	local userIds: { number } = {}
	if winners and #winners > 0 then
		for _, player in winners do
			table.insert(userIds, player.UserId)
		end
	elseif winner then
		table.insert(userIds, winner.UserId)
	end

	-- // No winner at all (e.g. nobody scored): keep showing the previous round's winner
	if #userIds == 0 then
		return
	end

	displayVersion += 1
	if #userIds == 1 then
		setWinnerUserId(userIds[1])
	else
		task.spawn(cycleUserIds, userIds, displayVersion)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PedestalService.start()
	CollectionService:GetInstanceAddedSignal(PEDESTAL_TAG):Connect(registerPedestal)
	CollectionService:GetInstanceRemovedSignal(PEDESTAL_TAG):Connect(function(instance)
		winnerPedestals[instance] = nil
	end)
	for _, instance in CollectionService:GetTagged(PEDESTAL_TAG) do
		registerPedestal(instance)
	end

	-- // A winner pedestal's UserId may belong to someone who joins after the pedestal registered; and a displayed
	--    player can equip another emote at any time
	local function refreshDisplayedPlayer(player: Player)
		for pedestal in winnerPedestals do
			if pedestal:GetAttribute(USER_ID_ATTRIBUTE) == player.UserId then
				applyWinnerEmote(pedestal, player.UserId)
				applyWinnerLabel(pedestal, player.UserId)
			end
		end
	end
	local function watchPlayer(player: Player)
		CosmeticLibrary.observe(player, "WinningEmote", function()
			refreshDisplayedPlayer(player)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		watchPlayer(player)
		refreshDisplayedPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	GameStateLibrary.RoundFinishedTasks:Add(onRoundFinished)
end

return PedestalService
