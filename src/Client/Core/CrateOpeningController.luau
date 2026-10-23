--[[
	CrateOpeningController (T-114)

	Description:
	The client side of opening a bought weapon crate (the server places and counts: Server/Core/CrateService).
	For the local player's own crates (workspace.PlacedCrates, attribute OwnerUserId):
	  - a label above the crate: "Tap to open!" and the clicks / taps left (attribute ClicksLeft, counted by the server)
	  - a little bounce on every click / tap (shown right away, before the server's count comes back)
	  - when the server opens it (CrateOpened event): the crate pops (grows and vanishes), and a weapon the player already owned
	    is shown as "Duplicate weapon" (a new one shows "New skin acquired!" through SkinController).
	Other players' crates are just models.
]]

local CrateOpeningController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FOLDER_NAME = "PlacedCrates" -- // CrateService.FOLDER_NAME
local OPENED_EVENT = "CrateOpened" -- // CrateService.OPENED_EVENT
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local BOUNCE_SCALE = 1.12 -- // Size of the crate at the top of a hit bounce
local BOUNCE_SECONDS = 0.12
local POP_SCALE = 1.6 -- // The opened crate grows to this while vanishing
local POP_SECONDS = 0.35

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer

type TrackedCrate = {
	Model: Model,
	Label: BillboardGui,
	CountText: TextLabel,
	BaseScale: number,
	BounceStartedAt: number?,
	Connections: { RBXScriptConnection },
}

local tracked: { [Model]: TrackedCrate } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getPromptText(): string
	return if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap to open!" else "Click to open!"
end

local function createLabel(model: Model): (BillboardGui, TextLabel)
	local _, size = model:GetBoundingBox()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CrateOpenLabel"
	billboard.Size = UDim2.fromScale(5, 2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.6, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120

	local prompt = Instance.new("TextLabel")
	prompt.Name = "Prompt"
	prompt.BackgroundTransparency = 1
	prompt.Size = UDim2.fromScale(1, 0.5)
	prompt.FontFace = FONT
	prompt.TextScaled = true
	prompt.TextColor3 = Color3.new(1, 1, 1)
	prompt.Text = getPromptText()
	prompt.Parent = billboard

	local count = prompt:Clone()
	count.Name = "Count"
	count.Position = UDim2.fromScale(0, 0.5)
	count.TextColor3 = Color3.fromRGB(255, 220, 90)
	count.Parent = billboard

	for _, label in { prompt, count } do
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(45, 28, 12)
		stroke.Thickness = 2
		stroke.Parent = label
	end

	billboard.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	billboard.Parent = model
	return billboard, count
end

local function updateCount(entry: TrackedCrate)
	local clicksLeft = entry.Model:GetAttribute("ClicksLeft")
	entry.CountText.Text = if type(clicksLeft) == "number" then tostring(math.max(clicksLeft, 0)) else ""
end

-- // A quick grow-and-settle on every hit (local only)
local function bounce(entry: TrackedCrate)
	local startedAt = os.clock()
	entry.BounceStartedAt = startedAt
	task.spawn(function()
		while entry.BounceStartedAt == startedAt and entry.Model.Parent do
			local alpha = (os.clock() - startedAt) / BOUNCE_SECONDS
			if alpha >= 1 then
				entry.Model:ScaleTo(entry.BaseScale)
				break
			end
			-- // Up then back down (sine), so it ends exactly at its size
			entry.Model:ScaleTo(entry.BaseScale * (1 + (BOUNCE_SCALE - 1) * math.sin(alpha * math.pi)))
			task.wait()
		end
	end)
end

local function untrack(model: Model)
	local entry = tracked[model]
	if not entry then
		return
	end
	tracked[model] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
end

-- // The opened crate grows and turns invisible (the server removes it shortly after)
local function pop(entry: TrackedCrate)
	entry.BounceStartedAt = nil
	entry.Label.Enabled = false
	local parts = {}
	for _, descendant in entry.Model:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(parts, descendant)
		end
	end
	local startedAt = os.clock()
	task.spawn(function()
		while entry.Model.Parent do
			local alpha = math.clamp((os.clock() - startedAt) / POP_SECONDS, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3
			entry.Model:ScaleTo(entry.BaseScale * (1 + (POP_SCALE - 1) * eased))
			for _, part in parts do
				part.LocalTransparencyModifier = alpha
			end
			if alpha >= 1 then
				break
			end
			task.wait()
		end
	end)
end

local function track(model: Model)
	if tracked[model] or model:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return
	end
	local label, countText = createLabel(model)
	local entry: TrackedCrate = {
		Model = model,
		Label = label,
		CountText = countText,
		BaseScale = model:GetScale(),
		BounceStartedAt = nil,
		Connections = {},
	}
	tracked[model] = entry
	updateCount(entry)

	table.insert(entry.Connections, model:GetAttributeChangedSignal("ClicksLeft"):Connect(function()
		updateCount(entry)
	end))
	local clickDetector = model:FindFirstChildWhichIsA("ClickDetector")
	if clickDetector then
		table.insert(entry.Connections, clickDetector.MouseClick:Connect(function(clicker: Player)
			if clicker == localPlayer and not model:GetAttribute("Opened") then
				bounce(entry)
			end
		end))
	end
	table.insert(entry.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			untrack(model)
		end
	end))
end

local function onCrateOpened(placedCrateId: string, skinId: string, isNew: boolean)
	for model, entry in tracked do
		if model:GetAttribute("PlacedCrateId") == placedCrateId then
			pop(entry)
			break
		end
	end
	if not isNew then
		local skin = SkinLibrary.getSkin(skinId)
		ItemAcquiredGui.acquiredModelItem(skin and skin.Model, "Duplicate weapon", if skin then skin.Name else skinId)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CrateOpeningController.init()
	SimpleRemotes.getEvent(OPENED_EVENT).OnClientEvent:Connect(onCrateOpened)
end

function CrateOpeningController.start()
	local folder = workspace:WaitForChild(FOLDER_NAME, math.huge) :: Folder
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			-- // Attributes and the ClickDetector arrive with the model; wait a frame in case they replicate just after
			task.defer(track, child)
		end
	end)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			track(child)
		end
	end
end

return CrateOpeningController
