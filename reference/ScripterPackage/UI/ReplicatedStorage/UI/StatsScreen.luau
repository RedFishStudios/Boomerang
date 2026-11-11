-- Personal Stats window: the player's avatar headshot, display name and @username, the current match row (name,
-- eliminations, defeats) and the all-time Elims / Defeats / Wins / Losses cards. Built from the supplied Stats art;
-- every value is live text over painted-out boxes (the numbers in the reference were examples).
--
-- local stats = StatsScreen.mount(playerGui)
-- stats.setPlayer(player)                           -- headshot, names
-- stats.setValues({ MatchElims = 2, Elims = 306 })  -- any subset of the keys below
-- stats.open() / stats.close() / stats.isOpen()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Theme = require(Shared:WaitForChild("Theme"))
local Kit = require(script.Parent:WaitForChild("Kit"))

-- Falls back to blank images if the art ids are missing, so a missing upload can never stop the rest of the UI.
local Art = Assets.StatsScreen or { Window = "", Close = "" }

local StatsScreen = {}

export type Handle = Kit.Window & {
	setPlayer: (player: Player) -> (),
	setValues: (values: { [string]: number }) -> (),
	setAvatar: (image: string) -> (), -- any image id, e.g. a custom character render
}

-- Canvas and rectangles {x, y, w, h} in the art's pixels (art/stats/layout.txt).
local CANVAS = Vector2.new(1448, 1086)
local CLOSE = { 1233, 50, 108, 108 }
local AVATAR = { 435, 185, 152, 137 }
local AVATAR_RADIUS = 20
local DISPLAY_NAME = { 615, 196, 400, 62 }
local USERNAME = { 615, 262, 400, 38 }
local MATCH_NAME = { 262, 500, 420, 52 }
local MATCH_VALUES = {
	MatchElims = { 792, 500, 100, 52 },
	MatchDefeats = { 1057, 500, 100, 52 },
}
local ALL_TIME = {
	Elims = { 213, 846, 223, 90 },
	Defeats = { 477, 846, 222, 90 },
	Wins = { 745, 846, 222, 90 },
	Losses = { 1010, 846, 226, 90 },
}
local TEXT_SIZE = { name = 62, username = 36, row = 44, number = 82 }

-- Dark brown lettering printed on the cream panel (no outline), as in the reference.
local function printed(name: string, r: { number }, size: number, alignment: Enum.TextXAlignment?): TextLabel
	return Kit.create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Position = UDim2.fromOffset(r[1], r[2]),
		Size = UDim2.fromOffset(r[3], r[4]),
		Text = "",
		TextColor3 = Theme.Colors.Ink,
		TextSize = size,
		TextScaled = size > 100,
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

function StatsScreen.mount(parent: Instance): Handle
	local window = Kit.window(parent, "StatsScreen", Art.Window, CANVAS)
	local root = window.root

	local avatar = Kit.create("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = Theme.Colors.AvatarBackdrop,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(AVATAR[1], AVATAR[2]),
		Size = UDim2.fromOffset(AVATAR[3], AVATAR[4]),
		Image = "",
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
		Parent = root,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0, AVATAR_RADIUS) }),
	})

	local displayName = printed("DisplayName", DISPLAY_NAME, TEXT_SIZE.name, Enum.TextXAlignment.Left)
	displayName.Parent = root
	local username = printed("Username", USERNAME, TEXT_SIZE.username, Enum.TextXAlignment.Left)
	username.TextColor3 = Theme.Colors.InkSoft
	username.Parent = root
	local matchName = printed("MatchName", MATCH_NAME, TEXT_SIZE.row, Enum.TextXAlignment.Left)
	matchName.Parent = root

	local labels: { [string]: TextLabel } = {}
	for key, r in MATCH_VALUES do
		labels[key] = printed(key, r, TEXT_SIZE.row)
		labels[key].Parent = root
	end
	for key, r in ALL_TIME do
		labels[key] = printed(key, r, TEXT_SIZE.number)
		labels[key].Parent = root
	end

	Kit.overlayButton(root, "Close", Art.Close, CLOSE).Activated:Connect(window.close)

	local handle = window :: Handle
	local thumbnailFor: number? = nil
	handle.setAvatar = function(image: string)
		avatar.Image = image
	end
	handle.setPlayer = function(player: Player)
		displayName.Text = player.DisplayName
		username.Text = "@" .. player.Name
		matchName.Text = player.DisplayName
		if thumbnailFor ~= player.UserId then
			thumbnailFor = player.UserId
			task.spawn(function()
				local ok, image = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size420x420
					)
				end)
				if ok and thumbnailFor == player.UserId then
					avatar.Image = image
				end
			end)
		end
	end
	handle.setValues = function(values: { [string]: number })
		for key, value in values do
			local label = labels[key]
			if label then
				label.Text = formatCount(value)
			end
		end
	end
	for key in labels do
		labels[key].Text = "0"
	end
	return handle
end

return StatsScreen
