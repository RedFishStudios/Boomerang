--[[
	Lobby station framework, client side (T-047). See LobbyStationLibrary for the tag and attributes.

	For every tagged station: draws the world-space title, makes the pad glow (brighter while the
	prompt is shown, dimmed when the station's state isn't "Active"), and applies this player's
	per-station state from the server to the prompt and title.

	Station code can react through ApproachedTasks / LeftTasks (e.g. show an odds panel) and
	StateChangedTasks.

	Author:
	@Soulsplosion
]]

local LobbyStationController = {}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyStationLibrary = require(ReplicatedStorage.Shared.Library.LobbyStationLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TITLE_NAME = "LobbyStationTitle"
local GLOW_NAME = "LobbyStationGlow"

local TITLE_SIZE = UDim2.fromScale(12, 2.5) -- studs
local TITLE_MAX_DISTANCE = 150

local GLOW_BRIGHTNESS = 1.5
local GLOW_NEAR_MULTIPLIER = 2.5
local GLOW_DIMMED_BRIGHTNESS = 0.3
local GLOW_PULSE_SPEED = 2
local GLOW_PULSE_AMOUNT = 0.25
local GLOW_MIN_RANGE = 8

local PROMPT_WAIT_TIMEOUT = 10

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type StationRecord = {
	Station: Instance,
	StationId: string,
	Title: TextLabel?,
	Glow: PointLight?,
	Prompt: ProximityPrompt?,
	IsNear: boolean,
	Connections: { RBXScriptConnection },
	Instances: { Instance },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local stateEvent = SimpleRemotes.getEvent(LobbyStationLibrary.STATE_EVENT)
local getStatesFunction = SimpleRemotes.getFunction(LobbyStationLibrary.GET_STATES_FUNCTION)

local records: { [Instance]: StationRecord } = {}
-- // Stations whose parts haven't streamed in yet
local pendingConnections: { [Instance]: RBXScriptConnection } = {}
local states: { [string]: LobbyStationLibrary.StationState } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

LobbyStationController.ApproachedTasks = TasksList.new() :: TasksList.TasksList<(stationId: string, station: Instance) -> ()>
LobbyStationController.LeftTasks = TasksList.new() :: TasksList.TasksList<(stationId: string, station: Instance) -> ()>
LobbyStationController.StateChangedTasks =
	TasksList.new() :: TasksList.TasksList<(stationId: string, state: LobbyStationLibrary.StationState?) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isDimmed(state: LobbyStationLibrary.StationState?): boolean
	return state ~= nil and state.State ~= nil and state.State ~= "Active"
end

local function applyState(record: StationRecord)
	local station = record.Station
	local state = states[record.StationId]

	if record.Title then
		local title = (state and state.Title) or LobbyStationLibrary.getStringAttribute(station, "Title", "")
		record.Title.Text = title
		record.Title.Visible = title ~= ""
	end

	if record.Prompt then
		record.Prompt.Enabled = not (state and state.PromptEnabled == false)
		record.Prompt.ActionText = (state and state.ActionText)
			or LobbyStationLibrary.getStringAttribute(station, "ActionText", LobbyStationLibrary.DEFAULT_ACTION_TEXT)
	end
end

local function setNear(record: StationRecord, isNear: boolean)
	if record.IsNear == isNear then
		return
	end
	record.IsNear = isNear
	local tasks = if isNear then LobbyStationController.ApproachedTasks else LobbyStationController.LeftTasks
	tasks:Execute("parallel", record.StationId, record.Station)
end

local function createTitle(record: StationRecord, promptPart: BasePart)
	local topY = LobbyStationLibrary.getTopY(record.Station) or (promptPart.Position.Y + promptPart.Size.Y / 2)
	local height = LobbyStationLibrary.getNumberAttribute(record.Station, "TitleHeight", LobbyStationLibrary.DEFAULT_TITLE_HEIGHT)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TITLE_NAME
	billboard.Adornee = promptPart
	billboard.Size = TITLE_SIZE
	billboard.StudsOffsetWorldSpace = Vector3.new(0, topY - promptPart.Position.Y + height + TITLE_SIZE.Y.Scale / 2, 0)
	billboard.MaxDistance = TITLE_MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	billboard.Parent = promptPart
	record.Title = label
	table.insert(record.Instances, billboard)
end

local function createGlow(record: StationRecord)
	local pad = LobbyStationLibrary.getPadPart(record.Station)
	if not pad then
		return
	end
	local glow = Instance.new("PointLight")
	glow.Name = GLOW_NAME
	glow.Color = pad.Color
	glow.Range = math.max(GLOW_MIN_RANGE, math.max(pad.Size.X, pad.Size.Z))
	glow.Brightness = GLOW_BRIGHTNESS
	glow.Shadows = false
	glow.Parent = pad
	record.Glow = glow
	table.insert(record.Instances, glow)
end

local function attachPrompt(record: StationRecord, promptPart: BasePart)
	local prompt = promptPart:WaitForChild(LobbyStationLibrary.PROMPT_NAME, PROMPT_WAIT_TIMEOUT) :: ProximityPrompt?
	if not prompt or records[record.Station] ~= record then
		return
	end
	record.Prompt = prompt
	table.insert(record.Connections, prompt.PromptShown:Connect(function()
		setNear(record, true)
	end))
	table.insert(record.Connections, prompt.PromptHidden:Connect(function()
		setNear(record, false)
	end))
	applyState(record)
end

local cleanupStation: (station: Instance) -> ()

local function setupStation(station: Instance)
	if records[station] or not station:IsDescendantOf(workspace) then
		return
	end
	local stationId = LobbyStationLibrary.getStationId(station)
	if not stationId then
		return
	end

	local promptPart = LobbyStationLibrary.getPromptPart(station)
	if not promptPart then
		-- // Not streamed in yet: try again when a part arrives
		if not pendingConnections[station] then
			pendingConnections[station] = station.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("BasePart") and LobbyStationLibrary.getPromptPart(station) then
					pendingConnections[station]:Disconnect()
					pendingConnections[station] = nil
					setupStation(station)
				end
			end)
		end
		return
	end

	local record: StationRecord = {
		Station = station,
		StationId = stationId,
		IsNear = false,
		Connections = {},
		Instances = {},
	}
	records[station] = record

	createTitle(record, promptPart)
	createGlow(record)
	applyState(record)
	task.spawn(attachPrompt, record, promptPart)
end

function cleanupStation(station: Instance)
	local pending = pendingConnections[station]
	if pending then
		pending:Disconnect()
		pendingConnections[station] = nil
	end

	local record = records[station]
	if not record then
		return
	end
	records[station] = nil
	setNear(record, false)
	for _, connection in record.Connections do
		connection:Disconnect()
	end
	for _, instance in record.Instances do
		instance:Destroy()
	end
end

local function onStateChanged(stationId: string, state: LobbyStationLibrary.StationState?)
	states[stationId] = state
	for _, record in records do
		if record.StationId == stationId then
			applyState(record)
		end
	end
	LobbyStationController.StateChangedTasks:Execute("parallel", stationId, state)
end

local function updateGlows()
	local pulse = 1 + math.sin(os.clock() * GLOW_PULSE_SPEED) * GLOW_PULSE_AMOUNT
	for _, record in records do
		local glow = record.Glow
		if not glow then
			continue
		end
		if isDimmed(states[record.StationId]) then
			glow.Brightness = GLOW_DIMMED_BRIGHTNESS
		else
			glow.Brightness = GLOW_BRIGHTNESS * pulse * (if record.IsNear then GLOW_NEAR_MULTIPLIER else 1)
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // This player's state for a station, as last sent by the server (nil = default)
function LobbyStationController.getState(stationId: string): LobbyStationLibrary.StationState?
	return states[stationId]
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LobbyStationController.init()
	stateEvent.OnClientEvent:Connect(onStateChanged)
end

function LobbyStationController.start()
	for stationId, state in getStatesFunction:InvokeServer() do
		onStateChanged(stationId, state)
	end

	CollectionService:GetInstanceAddedSignal(LobbyStationLibrary.TAG):Connect(setupStation)
	CollectionService:GetInstanceRemovedSignal(LobbyStationLibrary.TAG):Connect(cleanupStation)
	for _, station in CollectionService:GetTagged(LobbyStationLibrary.TAG) do
		setupStation(station)
	end

	RunService.Heartbeat:Connect(updateGlows)
end

-- function LobbyStationController.test() end

return LobbyStationController
