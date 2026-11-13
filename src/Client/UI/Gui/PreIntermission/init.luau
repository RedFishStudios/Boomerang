--[[
	PreIntermission

	Description:
	The end-of-round results, shown during GameplayPhases.RoundEnded while players are still in the arena. Nothing covers
	the screen: a red ribbon with "Match!", and floating icons and text under it (Sol, 2026-11-12):
	- The winner, large: one player's avatar with "<DisplayName> won!" and "@<username>", or the winning team's avatars
	  with "<TeamName> won!" (or "Game tied!" / "No winner").
	- Below, every other player's avatar with their place ("2nd", "3rd"...). The local player's is fully visible, the
	  others slightly see-through. In team modes each avatar has a border in its team's colour.
	- At the bottom, "Returning to lobby in <seconds>", counting down to the end of RoundEnded (CurrentTimerEndsAt).
	Places come from the server (IntermissionData.Placements, RoundResultsService). Avatars are Roblox headshots.
	Looks: the ribbon is ClientArt/Assets.RoundResults.Ribbon; text is the menus' cream lettering (ClientArt/Kit).
]]

local PreIntermissionGui = {}
PreIntermissionGui.Type = "HUD"
PreIntermissionGui.Open = false

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).RoundResults

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type WinnerInfo = {
	Type: "Player" | "Team" | "Tie",
	UserId: number?,
	TeamName: string?,
	TeamColor: Color3?,
	UserIds: { number }?,
}

type Placement = {
	UserId: number,
	Place: number,
	TeamColor: Color3?,
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Laid out on a 900 px wide canvas, scaled with the screen (reference 1280 x 720)
local CANVAS_WIDTH = 900
local REFERENCE = Vector2.new(1280, 720)
local MIN_SCALE, MAX_SCALE = 0.55, 1.6
local TOP_MARGIN = 12

local RIBBON = Vector2.new(560, 127) -- // The ribbon art is 725 x 164
local RIBBON_TEXT = { 90, 26, 380, 64 } -- // "Match!", inside the ribbon
local WINNER_ICON = 116 -- // One winner
local TEAM_ICON = 88 -- // Each winning team player
local PLACE_ICON = 62
local PLACE_LABEL_HEIGHT = 26
local OTHERS_TRANSPARENCY = 0.4 -- // Other players' icons and places; the local player's are fully visible
local BORDER = Color3.fromRGB(252, 243, 224) -- // Icon border outside team modes (the menus' cream)
local ICON_BACKDROP = Theme.Colors.AvatarBackdrop
local TEXT_SIZE = { Ribbon = 52, Winner = 44, Username = 26, Place = 22, Countdown = 28 }

local SLIDE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local gui: ScreenGui
local holder: Frame -- // Slides in and out
local fitScale: UIScale
local winnerArea: Frame
local placesArea: Frame
local countdownLabel: Frame
local countdownConnection: RBXScriptConnection?
local shownSeconds: number? = nil

local lastRegisteredGameplayPhase = nil
local activeTween: Tween?
local closeId = 0

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Cream lettering with a dark outline (Kit.label), shrunk to fit its box
local function outlined(name: string, text: string, size: number, parent: Instance, props: { [string]: any }?): Frame
	local label = Kit.label(text, size, { Name = name, Parent = parent })
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	for _, layer in label:GetChildren() do
		if layer:IsA("TextLabel") then
			layer.TextScaled = true
			layer.TextWrapped = true
			Kit.create("UITextSizeConstraint", { MaxTextSize = size, Parent = layer })
		end
	end
	return label
end

local function setTextTransparency(label: Frame, transparency: number)
	for _, layer in label:GetDescendants() do
		if layer:IsA("TextLabel") then
			layer.TextTransparency = transparency
		elseif layer:IsA("UIStroke") then
			layer.Transparency = transparency
		end
	end
end

-- // "1st", "2nd", "3rd", "4th", "11th", "22nd"...
local function ordinal(place: number): string
	local lastTwo = place % 100
	local suffix = if lastTwo >= 11 and lastTwo <= 13
		then "th"
		elseif place % 10 == 1 then "st"
		elseif place % 10 == 2 then "nd"
		elseif place % 10 == 3 then "rd"
		else "th"
	return `{place}{suffix}`
end

local function getPlayerNames(userId: number): (string, string)
	local found = Players:GetPlayerByUserId(userId)
	if found then
		return found.DisplayName, found.Name
	end
	local success, userInfos = pcall(function()
		return Players:GetUserInfosByUserIdsAsync({ userId })
	end)
	local userInfo = success and userInfos[1]
	if userInfo then
		return userInfo.DisplayName, userInfo.Username
	end
	return "Player", "Unknown"
end

-- // A round avatar headshot with a coloured border
local function createIcon(userId: number, size: number, borderColor: Color3, transparency: number): Frame
	local icon = Kit.create("Frame", {
		Name = `Icon{userId}`,
		BackgroundColor3 = ICON_BACKDROP,
		BackgroundTransparency = transparency,
		Size = UDim2.fromOffset(size, size),
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Kit.create("UIStroke", {
			Color = borderColor,
			Thickness = math.max(3, size / 22),
			Transparency = transparency,
		}),
		Kit.create("ImageLabel", {
			Name = "Headshot",
			BackgroundTransparency = 1,
			Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`,
			ImageTransparency = transparency,
			Size = UDim2.fromScale(1, 1),
		}, {
			Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}),
	})
	return icon
end

local function clear(frame: Frame)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

-- // The winner: one player, the winning team, or a tie / no-winner line
local function showWinner(winnerInfo: WinnerInfo?)
	clear(winnerArea)
	local order = 0
	local function add(instance: GuiObject)
		order += 1
		instance.LayoutOrder = order
		instance.Parent = winnerArea
	end

	if winnerInfo and winnerInfo.Type == "Player" and winnerInfo.UserId then
		add(createIcon(winnerInfo.UserId, WINNER_ICON, BORDER, 0))
		local nameLabel = outlined("Winner", "", TEXT_SIZE.Winner, winnerArea, { Size = UDim2.fromOffset(CANVAS_WIDTH, 54) })
		local usernameLabel = outlined("Username", "", TEXT_SIZE.Username, winnerArea, { Size = UDim2.fromOffset(CANVAS_WIDTH, 32) })
		add(nameLabel)
		add(usernameLabel)
		local userId = winnerInfo.UserId
		task.spawn(function()
			local displayName, username = getPlayerNames(userId)
			Kit.setText(nameLabel, `{displayName} won!`)
			Kit.setText(usernameLabel, `@{username}`)
		end)
	elseif winnerInfo and winnerInfo.Type == "Team" then
		local row = Kit.create("Frame", {
			Name = "Team",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CANVAS_WIDTH, TEAM_ICON + 8),
		}, {
			Kit.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
		})
		for _, userId in winnerInfo.UserIds or {} do
			createIcon(userId, TEAM_ICON, winnerInfo.TeamColor or BORDER, 0).Parent = row
		end
		add(row)
		add(outlined("Winner", `{winnerInfo.TeamName or "Team"} won!`, TEXT_SIZE.Winner, winnerArea, {
			Size = UDim2.fromOffset(CANVAS_WIDTH, 54),
		}))
	else
		local text = if winnerInfo and winnerInfo.Type == "Tie" then "Game tied!" else "No winner"
		add(outlined("Winner", text, TEXT_SIZE.Winner, winnerArea, { Size = UDim2.fromOffset(CANVAS_WIDTH, 54) }))
	end
end

-- // Everyone else's place, in order; the local player's at full opacity
local function showPlacements(placements: { Placement }?)
	clear(placesArea)
	for index, placement in placements or {} do
		local isLocal = placement.UserId == player.UserId
		local transparency = if isLocal then 0 else OTHERS_TRANSPARENCY
		local cell = Kit.create("Frame", {
			Name = `Place{index}`,
			BackgroundTransparency = 1,
			LayoutOrder = index,
		})
		local icon = createIcon(placement.UserId, PLACE_ICON, placement.TeamColor or BORDER, transparency)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 4)
		icon.Parent = cell
		local label = outlined("Place", ordinal(placement.Place), TEXT_SIZE.Place, cell, {
			Position = UDim2.fromOffset(0, PLACE_ICON + 8),
			Size = UDim2.new(1, 0, 0, PLACE_LABEL_HEIGHT),
		})
		setTextTransparency(label, transparency)
		cell.Parent = placesArea
	end
end

-- // "Returning to lobby in N": whole seconds left until the round-ended phase is over
local function updateCountdown()
	local endsAt = GameStateLibrary.getGameStateData().CurrentTimerEndsAt:Get()
	local seconds = if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else nil
	if seconds == shownSeconds then
		return
	end
	shownSeconds = seconds
	countdownLabel.Visible = seconds ~= nil
	Kit.setText(countdownLabel, `Returning to lobby in {seconds or 0}`)
end

local function rescale()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else REFERENCE
	fitScale.Scale = math.clamp(math.min(viewport.X / REFERENCE.X, viewport.Y / REFERENCE.Y), MIN_SCALE, MAX_SCALE)
end

local function slide(info: TweenInfo, goal: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(holder, info, { Position = goal })
	activeTween:Play()
end

local function build()
	gui = Kit.create("ScreenGui", {
		Name = "PreIntermission",
		Enabled = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	holder = Kit.create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, -1, 0),
		Size = UDim2.fromOffset(CANVAS_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, {
		Kit.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	fitScale = Kit.create("UIScale", { Parent = holder })

	local ribbon = Kit.create("ImageLabel", {
		Name = "Ribbon",
		BackgroundTransparency = 1,
		Image = Art.Ribbon,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(RIBBON.X, RIBBON.Y),
		Parent = holder,
	})
	outlined("Title", "Match!", TEXT_SIZE.Ribbon, ribbon, {
		Position = UDim2.fromOffset(RIBBON_TEXT[1], RIBBON_TEXT[2]),
		Size = UDim2.fromOffset(RIBBON_TEXT[3], RIBBON_TEXT[4]),
		ZIndex = 2,
	})

	winnerArea = Kit.create("Frame", {
		Name = "Winner",
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(CANVAS_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	}, {
		Kit.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})

	placesArea = Kit.create("Frame", {
		Name = "Places",
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Size = UDim2.fromOffset(CANVAS_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = holder,
	}, {
		Kit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(PLACE_ICON + 22, PLACE_ICON + PLACE_LABEL_HEIGHT + 14),
			CellPadding = UDim2.fromOffset(8, 6),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	countdownLabel = outlined("Countdown", "", TEXT_SIZE.Countdown, holder, {
		LayoutOrder = 4,
		Size = UDim2.fromOffset(CANVAS_WIDTH, 36),
	})

	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		rescale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	gui.Parent = player:WaitForChild("PlayerGui")
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PreIntermissionGui.open()
	closeId += 1
	PreIntermissionGui.Open = true
	rescale()
	gui.Enabled = true
	holder.Position = UDim2.new(0.5, 0, -1, 0)
	slide(SLIDE_IN, UDim2.new(0.5, 0, 0, TOP_MARGIN))
	shownSeconds = nil
	updateCountdown()
	if not countdownConnection then
		countdownConnection = RunService.Heartbeat:Connect(updateCountdown)
	end
	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", true)
end

function PreIntermissionGui.close(instant: boolean?)
	closeId += 1
	local thisClose = closeId
	PreIntermissionGui.Open = false
	if countdownConnection then
		countdownConnection:Disconnect()
		countdownConnection = nil
	end
	if instant then
		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end
		holder.Position = UDim2.new(0.5, 0, -1, 0)
		gui.Enabled = false
	else
		slide(SLIDE_OUT, UDim2.new(0.5, 0, -1, 0))
		task.delay(SLIDE_OUT.Time, function()
			if closeId == thisClose then
				gui.Enabled = false
			end
		end)
	end
	UIController.GuiToggledTasks:Execute("parallel", "PreIntermission", false)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

build()

function PreIntermissionGui.start()
	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(snapshot)
		local gameplayPhase = snapshot.GameplayPhase
		if gameplayPhase == lastRegisteredGameplayPhase then
			return
		end
		lastRegisteredGameplayPhase = gameplayPhase
		if gameplayPhase == GameplayPhases.RoundEnded and GlobalConfig.ShowRoundEndedScreen then
			local intermissionData = snapshot.IntermissionData
			showWinner(intermissionData and intermissionData.WinnerInfo)
			showPlacements(intermissionData and intermissionData.Placements)
			PreIntermissionGui.open()
		elseif PreIntermissionGui.Open then
			PreIntermissionGui.close()
		end
	end)
end

return PreIntermissionGui
