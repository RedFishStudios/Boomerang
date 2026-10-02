--[[
	Shared conventions for lobby stations (T-047): the tag, attribute names, the per-player
	state shape, and helpers both sides use to find a station's parts.

	A station is any Model or BasePart in workspace tagged `LobbyStation`. Attributes:
	- StationId (string, required): picks the server handler (LobbyStationService.registerHandler).
	  Several stations may share an id (they share handler and per-player state).
	- Title (string): world-space label above the station. No label if empty.
	- ActionText (string): proximity prompt action. Default "Interact".
	- HoldDuration (number): prompt hold time in seconds. Default 0.
	- MaxDistance (number): prompt activation distance in studs. Default 10.
	- PromptPart (string): name of the descendant BasePart that holds the prompt and label.
	  Default: the part itself, or the model's PrimaryPart (or its first BasePart).
	- PadPart (string): name of the descendant BasePart that glows. Default "Pad". No glow if missing.
	- TitleHeight (number): studs between the top of the station and the label. Default 2.

	Server: LobbyStationService. Client: LobbyStationController.

	Author:
	@Soulsplosion
]]

local LobbyStationLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

LobbyStationLibrary.TAG = "LobbyStation"
LobbyStationLibrary.PROMPT_NAME = "LobbyStationPrompt"

-- // Remotes (created by LobbyStationService)
LobbyStationLibrary.STATE_EVENT = "LobbyStationState"
LobbyStationLibrary.GET_STATES_FUNCTION = "LobbyStationGetStates"

LobbyStationLibrary.DEFAULT_ACTION_TEXT = "Interact"
LobbyStationLibrary.DEFAULT_MAX_DISTANCE = 10
LobbyStationLibrary.DEFAULT_PAD_NAME = "Pad"
LobbyStationLibrary.DEFAULT_TITLE_HEIGHT = 2

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // Per-player state of a station, set by the server. Every field is optional.
-- // State: free-form name owned by the station's code ("Active", "Locked", "Claimed"...).
-- //   The framework only dims the pad glow when State is set and isn't "Active".
-- // PromptEnabled = false hides the prompt for that player (and the server ignores triggers).
-- // ActionText / Title override the attributes for that player.
export type StationState = {
	State: string?,
	PromptEnabled: boolean?,
	ActionText: string?,
	Title: string?,
}

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LobbyStationLibrary.getStationId(station: Instance): string?
	local stationId = station:GetAttribute("StationId")
	if typeof(stationId) == "string" and stationId ~= "" then
		return stationId
	end
	return nil
end

function LobbyStationLibrary.getStringAttribute(station: Instance, name: string, default: string): string
	local value = station:GetAttribute(name)
	return if typeof(value) == "string" then value else default
end

function LobbyStationLibrary.getNumberAttribute(station: Instance, name: string, default: number): number
	local value = station:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function findNamedPart(station: Instance, name: string): BasePart?
	if station.Name == name and station:IsA("BasePart") then
		return station
	end
	local found = station:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

-- // The part that holds the prompt and the title label
function LobbyStationLibrary.getPromptPart(station: Instance): BasePart?
	local partName = station:GetAttribute("PromptPart")
	if typeof(partName) == "string" and partName ~= "" then
		return findNamedPart(station, partName)
	end
	if station:IsA("BasePart") then
		return station
	end
	if station:IsA("Model") and station.PrimaryPart then
		return station.PrimaryPart
	end
	return station:FindFirstChildWhichIsA("BasePart", true)
end

function LobbyStationLibrary.getPadPart(station: Instance): BasePart?
	return findNamedPart(station, LobbyStationLibrary.getStringAttribute(station, "PadPart", LobbyStationLibrary.DEFAULT_PAD_NAME))
end

-- // World-space Y of the top of the station (for placing the title)
function LobbyStationLibrary.getTopY(station: Instance): number?
	if station:IsA("Model") then
		local cframe, size = station:GetBoundingBox()
		return cframe.Position.Y + size.Y / 2
	elseif station:IsA("BasePart") then
		return station.Position.Y + station.Size.Y / 2
	end
	return nil
end

return LobbyStationLibrary
