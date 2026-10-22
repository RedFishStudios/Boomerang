--[[
	UsePickupButtons (T-108)

	A column of round buttons on the left of the screen, one per held pickup that is used by the player (its logic has
	`UseButton = true`: Explosive Boomerang, Teleport Boomerang, Decoy). Pressing a button asks the server to use the pickup
	(PickupLibrary.USE_PICKUP_BUTTON_EVENT -> PickupService, which checks and runs the logic's onUse).

	- A button appears as soon as the pickup is acquired, and is removed whenever the pickup is lost for any reason (used up,
	  timed out, death, round end): it follows PickupLibrary's effect added/removed tasks, like the Effects HUD.
	- Each frame the logic's canUse decides whether it can be pressed; when it can't, the icon is at 50% and non-interactive.
	- A pickup that is used up by one press (ConsumedOnUse) stays non-interactive after the press until the server removes it.
]]

local UsePickupButtonsGui = {}
UsePickupButtonsGui.Type = "HUD"
UsePickupButtonsGui.Open = false
UsePickupButtonsGui.SupercededBy = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedMods = ReplicatedStorage.Shared

local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local PickupLibrary = require(SharedMods.Library.PickupLibrary)
local AcquirableThingData = require(SharedMods.Referential.AcquirableThingData)
local SimpleRemotes = require(SharedMods.Networking.SimpleRemotes)

local PickupLogics = SharedMods.Logics.PickupLogics
local usePickupButtonEvent = SimpleRemotes.getEvent(PickupLibrary.USE_PICKUP_BUTTON_EVENT)

-- // Gui Values // --

local Gui = script:WaitForChild("UsePickupButtons") :: ScreenGui
local RootFrame = Gui:WaitForChild("Root") :: Frame
local ButtonTemplate = script:WaitForChild("ButtonTemplate") :: ImageButton

local UNUSABLE_IMAGE_TRANSPARENCY = 0.5
local USED_PENDING_TIMEOUT_SECONDS = 2 -- // A used-up press the server never answered becomes pressable again after this long

type UseButton = {
	Button: ImageButton,
	ClassId: PickupLibrary.PickupClassId,
	Logic: PickupLibrary.PickupLogic,
	UsedAt: number?, -- // os.clock() of a ConsumedOnUse press still waiting for the server to remove the pickup
}

local buttons: { [PickupLibrary.LivePickupId]: UseButton } = {}
local nextLayoutOrder = 0 -- // Acquisition order, top to bottom
local logicCache: { [string]: PickupLibrary.PickupLogic | false } = {}

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

-- // The pickup's logic if it has a use button, otherwise nil
local function getUseButtonLogic(pickupClassId: PickupLibrary.PickupClassId): PickupLibrary.PickupLogic?
	local cached = logicCache[pickupClassId]
	if cached == nil then
		cached = false
		if not PickupLibrary.isDataOnlyEffect(pickupClassId) then
			local module = PickupLogics:FindFirstChild(pickupClassId, true)
			if module and module:IsA("ModuleScript") then
				local loaded, logic = pcall(require, module)
				if loaded and type(logic) == "table" and logic.UseButton then
					cached = logic
				end
			end
		end
		logicCache[pickupClassId] = cached
	end
	return if cached then cached else nil
end

local function isUsable(useButton: UseButton): boolean
	if useButton.UsedAt then
		if os.clock() - useButton.UsedAt < USED_PENDING_TIMEOUT_SECONDS then
			return false
		end
		useButton.UsedAt = nil
	end
	local canUse = useButton.Logic.canUse
	if not canUse then
		return true
	end
	local ok, result = pcall(canUse, Player)
	return ok and result == true
end

local function updateButton(useButton: UseButton)
	local usable = isUsable(useButton)
	local button = useButton.Button
	button.ImageTransparency = if usable then 0 else UNUSABLE_IMAGE_TRANSPARENCY
	button.Interactable = usable
	button.Active = usable
end

local function updateAllButtons()
	for _, useButton in pairs(buttons) do
		updateButton(useButton)
	end
end

local function onButtonPressed(useButton: UseButton)
	if not isUsable(useButton) then
		return
	end
	local logic = useButton.Logic
	if logic.ConsumedOnUse then
		useButton.UsedAt = os.clock()
	end
	if logic.onUse then
		pcall(logic.onUse, Player) -- // Client-side bookkeeping only (e.g. Explosive marks this throw as exploded)
	end
	usePickupButtonEvent:FireServer(useButton.ClassId)
	updateButton(useButton)
end

local function addButton(livePickupId: PickupLibrary.LivePickupId, pickupClassId: PickupLibrary.PickupClassId)
	if buttons[livePickupId] then
		return
	end
	local logic = getUseButtonLogic(pickupClassId)
	if not logic then
		return -- // Only pickups with a use button get one
	end
	local thingData = AcquirableThingData[pickupClassId]

	local button = ButtonTemplate:Clone()
	button.Name = pickupClassId
	button.Image = if thingData then `rbxassetid://{thingData.Img}` else ""
	nextLayoutOrder += 1
	button.LayoutOrder = nextLayoutOrder

	local useButton: UseButton = {
		Button = button,
		ClassId = pickupClassId,
		Logic = logic,
		UsedAt = nil,
	}
	buttons[livePickupId] = useButton
	button.Activated:Connect(function()
		onButtonPressed(useButton)
	end)
	updateButton(useButton)
	button.Parent = RootFrame
end

local function removeButton(livePickupId: PickupLibrary.LivePickupId)
	local useButton = buttons[livePickupId]
	if not useButton then
		return
	end
	buttons[livePickupId] = nil
	useButton.Button:Destroy()
end

-- // Refresh hud display using current game state data
local function refreshUiFromGameState()
	if GameStateLibrary.getGameStateData().CurrentRoundData:Get() == nil then
		UsePickupButtonsGui.close()
	else
		UsePickupButtonsGui.open()
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

function UsePickupButtonsGui.open()
	UsePickupButtonsGui.Open = true
	if #UsePickupButtonsGui.SupercededBy > 0 then
		return
	end
	Gui.Enabled = true
end

function UsePickupButtonsGui.close(_Instant: boolean?)
	UsePickupButtonsGui.Open = false
	Gui.Enabled = false
end

function UsePickupButtonsGui.supercede()
	if not UsePickupButtonsGui.Open then
		return
	end
	Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
	Gui.Parent = Player.PlayerGui
	Gui.Enabled = false
end
_init()

function UsePickupButtonsGui.start()
	PickupLibrary.PickupEffectAddedTasks:Add(function(userId, livePickupId, pickupClassId, _endsAt)
		if userId == Player.UserId then
			addButton(livePickupId, pickupClassId)
		end
	end)
	PickupLibrary.PickupEffectRemovedTasks:Add(function(userId, livePickupId, _pickupClassId)
		if userId == Player.UserId then
			removeButton(livePickupId)
		end
	end)
	for livePickupId, effectData in pairs(PickupLibrary.UserPickupEffectsActive[Player.UserId] or {}) do
		addButton(livePickupId, effectData.ClassId)
	end

	RunService.Heartbeat:Connect(updateAllButtons)

	GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(_snapshot, _reason)
		refreshUiFromGameState()
	end)
	refreshUiFromGameState()
end

return UsePickupButtonsGui
