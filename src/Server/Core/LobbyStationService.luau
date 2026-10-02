--[[
	Lobby station framework, server side (T-047). See LobbyStationLibrary for the tag and attributes.

	- Creates the proximity prompt on every tagged station.
	- Runs the handler registered for the station's StationId when a player in the lobby triggers it.
	- Holds each player's per-station state and replicates it to that player (LobbyStationController).

	Station code (pedestals, wheel, crates...) only calls registerHandler / setPlayerState.

	Author:
	@Soulsplosion
]]

local LobbyStationService = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyLibrary = require(ReplicatedStorage.Shared.Library.LobbyLibrary)
local LobbyStationLibrary = require(ReplicatedStorage.Shared.Library.LobbyStationLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Minimum time between two triggers from the same player (any station)
local TRIGGER_COOLDOWN = 0.5

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Handler = (player: Player, station: Instance) -> ()

type StationRecord = {
	Prompt: ProximityPrompt,
	Connection: RBXScriptConnection,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local stateEvent = SimpleRemotes.getEvent(LobbyStationLibrary.STATE_EVENT)
local getStatesFunction = SimpleRemotes.getFunction(LobbyStationLibrary.GET_STATES_FUNCTION)

local handlers: { [string]: Handler } = {}
local stations: { [Instance]: StationRecord } = {}
local playerStates: { [Player]: { [string]: LobbyStationLibrary.StationState } } = {}
local lastTriggerTimes: { [Player]: number } = {}
local warnedMissingHandlers: { [string]: boolean } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onPromptTriggered(station: Instance, player: Player)
	local stationId = LobbyStationLibrary.getStationId(station)
	if not stationId then
		return
	end

	local now = os.clock()
	if now - (lastTriggerTimes[player] or 0) < TRIGGER_COOLDOWN then
		return
	end
	lastTriggerTimes[player] = now

	if not LobbyLibrary.isCharacterInLobby(player.Character) then
		return
	end

	local state = LobbyStationService.getPlayerState(player, stationId)
	if state and state.PromptEnabled == false then
		return
	end

	local handler = handlers[stationId]
	if not handler then
		if RunService:IsStudio() and not warnedMissingHandlers[stationId] then
			warnedMissingHandlers[stationId] = true
			warn(`LobbyStation: no handler registered for "{stationId}"`)
		end
		return
	end

	handler(player, station)
end

local function setupStation(station: Instance)
	if stations[station] or not station:IsDescendantOf(workspace) then
		return
	end

	local stationId = LobbyStationLibrary.getStationId(station)
	if not stationId then
		warn(`LobbyStation: {station:GetFullName()} has no StationId attribute`)
		return
	end

	local promptPart = LobbyStationLibrary.getPromptPart(station)
	if not promptPart then
		warn(`LobbyStation: {station:GetFullName()} has no part for its prompt`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = LobbyStationLibrary.PROMPT_NAME
	prompt.ActionText = LobbyStationLibrary.getStringAttribute(station, "ActionText", LobbyStationLibrary.DEFAULT_ACTION_TEXT)
	prompt.HoldDuration = LobbyStationLibrary.getNumberAttribute(station, "HoldDuration", 0)
	prompt.MaxActivationDistance = LobbyStationLibrary.getNumberAttribute(station, "MaxDistance", LobbyStationLibrary.DEFAULT_MAX_DISTANCE)
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptPart

	stations[station] = {
		Prompt = prompt,
		Connection = prompt.Triggered:Connect(function(player)
			onPromptTriggered(station, player)
		end),
	}
end

local function cleanupStation(station: Instance)
	local record = stations[station]
	if not record then
		return
	end
	stations[station] = nil
	record.Connection:Disconnect()
	record.Prompt:Destroy()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Runs `handler` when a player in the lobby triggers a station with this StationId. Returns a remover.
function LobbyStationService.registerHandler(stationId: string, handler: Handler): () -> ()
	if handlers[stationId] then
		warn(`LobbyStation: replacing the handler for "{stationId}"`)
	end
	handlers[stationId] = handler
	return function()
		if handlers[stationId] == handler then
			handlers[stationId] = nil
		end
	end
end

-- // Sets (or clears, with nil) one player's state for a station, and replicates it to that player
function LobbyStationService.setPlayerState(player: Player, stationId: string, state: LobbyStationLibrary.StationState?)
	if not player.Parent then
		return
	end
	local states = playerStates[player]
	if not states then
		states = {}
		playerStates[player] = states
	end
	states[stationId] = state
	stateEvent:FireClient(player, stationId, state)
end

function LobbyStationService.getPlayerState(player: Player, stationId: string): LobbyStationLibrary.StationState?
	local states = playerStates[player]
	return states and states[stationId]
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LobbyStationService.init()
	getStatesFunction.OnServerInvoke = function(player: Player)
		return playerStates[player] or {}
	end

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
		lastTriggerTimes[player] = nil
	end)
end

function LobbyStationService.start()
	CollectionService:GetInstanceAddedSignal(LobbyStationLibrary.TAG):Connect(setupStation)
	CollectionService:GetInstanceRemovedSignal(LobbyStationLibrary.TAG):Connect(cleanupStation)
	for _, station in CollectionService:GetTagged(LobbyStationLibrary.TAG) do
		setupStation(station)
	end
end

-- function LobbyStationService.test() end

return LobbyStationService
