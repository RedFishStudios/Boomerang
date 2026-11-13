--[[
	DeathScreen

	Description:
	Shown while the local player is dead in a round, with the world turned grey. Floating at the top of the screen, like the
	end-of-round results (PreIntermission): the red ribbon with "Downed!" (gamemodes with respawns) or "Eliminated!", and
	under it who did it (their avatar, "By <DisplayName>" and "@<username>") or the cause ("Out of Bounds"...), from the
	server's PlayerDeathReason event. Never shown over the end-of-round results.
	Looks: the results ribbon (ClientArt/Assets.RoundResults.Ribbon) and the menus' cream lettering (ClientArt/Kit).
]]

local DeathScreen = {}
DeathScreen.Type = "HUD"
DeathScreen.Open = false

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local UIController = require(ReplicatedStorage.Client.UI.UIController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local Kit = require(ReplicatedStorage.Client.UI.ClientArt.Kit)
local Theme = require(ReplicatedStorage.Client.UI.ClientArt.Theme)
local Art = require(ReplicatedStorage.Client.UI.ClientArt.Assets).RoundResults

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Same sizes as the end-of-round results: a 900 px wide canvas scaled with the screen (reference 1280 x 720)
local CANVAS_WIDTH = 900
local REFERENCE = Vector2.new(1280, 720)
local MIN_SCALE, MAX_SCALE = 0.55, 1.6
local TOP_MARGIN = 12
local RIBBON = Vector2.new(560, 127)
local RIBBON_TEXT = { 90, 26, 380, 64 }
local KILLER_ICON = 96
local BORDER = Color3.fromRGB(252, 243, 224)
local TEXT_SIZE = { Ribbon = 52, By = 40, Username = 26, Cause = 40 }

local SLIDE_IN = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer

local gui: ScreenGui
local holder: Frame
local fitScale: UIScale
local titleLabel: Frame
local killerIcon: Frame
local killerHeadshot: ImageLabel
local byLabel: Frame
local usernameLabel: Frame
local causeLabelText: Frame
local activeTween: Tween?
local closeId = 0

local grayscale = Instance.new("ColorCorrectionEffect")
grayscale.Name = "DeathScreenGrayscale"
grayscale.Enabled = false
grayscale.Saturation = -1

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Cream lettering with a dark outline (Kit.label), shrunk to fit its box
local function outlined(name: string, size: number, parent: Instance, props: { [string]: any }): Frame
	local label = Kit.label("", size, { Name = name, Parent = parent })
	for key, value in props do
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

local function hideDetails()
	killerIcon.Visible = false
	byLabel.Visible = false
	usernameLabel.Visible = false
	causeLabelText.Visible = false
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
		Name = "DeathScreen",
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
			Padding = UDim.new(0, 6),
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
	titleLabel = outlined("Title", TEXT_SIZE.Ribbon, ribbon, {
		Position = UDim2.fromOffset(RIBBON_TEXT[1], RIBBON_TEXT[2]),
		Size = UDim2.fromOffset(RIBBON_TEXT[3], RIBBON_TEXT[4]),
		ZIndex = 2,
	})

	-- // The eliminator's avatar: round headshot with a cream border
	killerIcon = Kit.create("Frame", {
		Name = "KillerIcon",
		BackgroundColor3 = Theme.Colors.AvatarBackdrop,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(KILLER_ICON, KILLER_ICON),
		Visible = false,
		Parent = holder,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Kit.create("UIStroke", { Color = BORDER, Thickness = 4 }),
	})
	killerHeadshot = Kit.create("ImageLabel", {
		Name = "Headshot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = killerIcon,
	}, {
		Kit.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	byLabel = outlined("ByDisplayName", TEXT_SIZE.By, holder, { LayoutOrder = 3, Size = UDim2.fromOffset(CANVAS_WIDTH, 50), Visible = false })
	usernameLabel = outlined("ByUsername", TEXT_SIZE.Username, holder, { LayoutOrder = 4, Size = UDim2.fromOffset(CANVAS_WIDTH, 32), Visible = false })
	causeLabelText = outlined("ByNonPlayer", TEXT_SIZE.Cause, holder, { LayoutOrder = 5, Size = UDim2.fromOffset(CANVAS_WIDTH, 50), Visible = false })

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

-- // Fills in who (or what) eliminated the player, then shows the screen
function DeathScreen.display(killerUserId: number?, causeLabel: string?)
	local killerPlayer = killerUserId and Players:GetPlayerByUserId(killerUserId)
	hideDetails()
	if killerPlayer then
		killerHeadshot.Image = `rbxthumb://type=AvatarHeadShot&id={killerPlayer.UserId}&w=150&h=150`
		Kit.setText(byLabel, `By {killerPlayer.DisplayName}`)
		Kit.setText(usernameLabel, `@{killerPlayer.Name}`)
		killerIcon.Visible = true
		byLabel.Visible = true
		usernameLabel.Visible = true
	else
		Kit.setText(causeLabelText, causeLabel or "Unknown")
		causeLabelText.Visible = true
	end
	DeathScreen.open()
end

function DeathScreen.open()
	-- // Never show over the end-of-round results (RoundEnded; e.g. a final elimination that also ends the round)
	if UIController.get("PreIntermission").Open then
		return
	end
	local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
	local canRespawn = currentRoundData ~= nil and currentRoundData.CanRespawn
	Kit.setText(titleLabel, if canRespawn then "Downed!" else "Eliminated!")

	if DeathScreen.Open then
		return
	end
	DeathScreen.Open = true
	closeId += 1
	rescale()
	gui.Enabled = true
	holder.Position = UDim2.new(0.5, 0, -1, 0)
	slide(SLIDE_IN, UDim2.new(0.5, 0, 0, TOP_MARGIN))
end

function DeathScreen.close(_instant: boolean?)
	DeathScreen.Open = false
	closeId += 1
	local thisClose = closeId
	slide(SLIDE_OUT, UDim2.new(0.5, 0, -1, 0))
	task.delay(SLIDE_OUT.Time, function()
		if closeId == thisClose then
			gui.Enabled = false
			hideDetails()
		end
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	build()
	grayscale.Parent = Lighting

	UIController.GuiToggledTasks:Add(function(guiName: string, isOpen: boolean)
		if guiName == "PreIntermission" and isOpen and DeathScreen.Open then
			DeathScreen.close()
		end
	end)

	-- // Who or what eliminated the player (arrives just after the death)
	SimpleRemotes.getEvent("PlayerDeathReason").OnClientEvent:Connect(function(killerUserId: number?, causeLabel: string?)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return
		end
		DeathScreen.display(killerUserId, causeLabel)
	end)

	PlayersUtil.CharacterDied:Add(function(diedPlayer)
		if diedPlayer == player then
			grayscale.Enabled = true
			DeathScreen.open()
		end
	end)

	PlayersUtil.CharacterAdded:Add(function(addedPlayer)
		if addedPlayer == player then
			grayscale.Enabled = false
			if DeathScreen.Open then
				DeathScreen.close()
			end
		end
	end)
end
_init()

function DeathScreen.start() end

return DeathScreen
