--[[
	Stats

	Description:
	The Stats menu, opened from the Stats button in the left lobby menu (MenuButtons). The client's Stats art (from the
	client's scripter package, StatsScreen): the local player's headshot, display name and @username, a "Current match"
	row (this round's elims and defeats) and four all-time cards (Elims, Defeats, Wins, Losses).
	Values come from the attributes the server puts on each Player (Shared/Constants/PlayerStatAttributes, written by
	LifetimeStatsService); Losses is rounds played minus wins. Built in code with the ClientArt Kit; art ids in
	ClientArt/Assets.StatsScreen.
	Time played, games played, throws, ability uses and pickups are still saved but not shown here (Sol, 2026-11-11: the
	client's layout first, to be reviewed).
]]

local StatsGui = {}
StatsGui.Type = "HUD"
StatsGui.Open = false
StatsGui.RequiresMouse = true -- // Frees the mouse in a locked camera (MouseUnlockController)

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local PlayerStatAttributes = require(ReplicatedStorage.Shared.Constants.PlayerStatAttributes)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).StatsScreen

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Canvas and rectangles {x, y, w, h} in the art's pixels (the package's art/stats/layout.txt)
local CANVAS = Vector2.new(1448, 1086)
local CLOSE = { 1233, 50, 108, 108 }
local AVATAR = { 435, 185, 152, 137 }
local AVATAR_RADIUS = 20
local DISPLAY_NAME = { 615, 196, 400, 62 }
local USERNAME = { 615, 262, 400, 38 }
local MATCH_NAME = { 262, 500, 420, 52 }
local TEXT_SIZE = { Name = 62, Username = 36, Row = 44, Number = 82 }

-- // Each number on the window: where it goes, its size, and the Player attribute it shows
local VALUES = {
	{ Rect = { 792, 500, 100, 52 }, Size = TEXT_SIZE.Row, Attribute = PlayerStatAttributes.RoundElims },
	{ Rect = { 1057, 500, 100, 52 }, Size = TEXT_SIZE.Row, Attribute = PlayerStatAttributes.RoundDefeats },
	{ Rect = { 213, 846, 223, 90 }, Size = TEXT_SIZE.Number, Attribute = PlayerStatAttributes.Elims },
	{ Rect = { 477, 846, 222, 90 }, Size = TEXT_SIZE.Number, Attribute = PlayerStatAttributes.Defeats },
	{ Rect = { 745, 846, 222, 90 }, Size = TEXT_SIZE.Number, Attribute = PlayerStatAttributes.Wins },
	{ Rect = { 1010, 846, 226, 90 }, Size = TEXT_SIZE.Number, Attribute = PlayerStatAttributes.Losses },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local window: Kit.Window
local valueLabels: { [string]: TextLabel } = {} -- // Player attribute -> its label

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Dark brown lettering printed on the cream panel, as in the art
local function printed(name: string, rect: { number }, size: number, alignment: Enum.TextXAlignment?): TextLabel
	return Kit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Position = UDim2.fromOffset(rect[1], rect[2]),
		Size = UDim2.fromOffset(rect[3], rect[4]),
		Text = "0",
		TextColor3 = Theme.Colors.Ink,
		TextSize = size,
		TextXAlignment = alignment or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
end

local function formatCount(value: number): string
	value = math.max(0, math.floor(value))
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e5 then
		return string.format("%dK", value // 1000)
	end
	return tostring(value)
end

local function updateValues()
	for attribute, label in valueLabels do
		local value = player:GetAttribute(attribute)
		label.Text = formatCount(if type(value) == "number" then value else 0)
	end
end

local function build()
	window = Kit.window(player:WaitForChild("PlayerGui"), "Stats", Art.Window, CANVAS)
	local root = window.root

	local avatar = Kit.create("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = Theme.Colors.AvatarBackdrop,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(AVATAR[1], AVATAR[2]),
		Size = UDim2.fromOffset(AVATAR[3], AVATAR[4]),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
		Parent = root,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0, AVATAR_RADIUS) }),
	})
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok then
			avatar.Image = image
		end
	end)

	local displayName = printed("DisplayName", DISPLAY_NAME, TEXT_SIZE.Name, Enum.TextXAlignment.Left)
	displayName.Text = player.DisplayName
	displayName.Parent = root
	local username = printed("Username", USERNAME, TEXT_SIZE.Username, Enum.TextXAlignment.Left)
	username.Text = `@{player.Name}`
	username.TextColor3 = Theme.Colors.InkSoft
	username.Parent = root
	local matchName = printed("MatchName", MATCH_NAME, TEXT_SIZE.Row, Enum.TextXAlignment.Left)
	matchName.Text = player.DisplayName
	matchName.Parent = root

	for _, value in VALUES do
		local label = printed(value.Attribute, value.Rect, value.Size)
		label.Parent = root
		valueLabels[value.Attribute] = label
	end

	Kit.overlayButton(root, "Close", Art.Close, CLOSE).Activated:Connect(function()
		StatsGui.close()
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function StatsGui.open()
	StatsGui.Open = true
	updateValues()
	window.open()
	UIController.supercede("Stats", "GamemodeHud")
	UIController.closeOtherMenus("Stats") -- // After superceding, so the closing menu doesn't restore the HUD
end

function StatsGui.close()
	StatsGui.Open = false
	window.close()
	UIController.unSupercede("Stats", "GamemodeHud")
end

function StatsGui.toggle()
	if StatsGui.Open then
		StatsGui.close()
	else
		StatsGui.open()
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function StatsGui.start()
	-- // Keeps the numbers current while the menu is open
	for attribute in valueLabels do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if StatsGui.Open then
				updateValues()
			end
		end)
	end
end

build()

return StatsGui
