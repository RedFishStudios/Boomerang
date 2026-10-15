--[[
	PedestalService

	Description:
	Server side of the player pedestals (see PedestalController on the client, which renders whoever a pedestal's
	`UserId` attribute points to). This service owns those `UserId` attributes.

	Currently it manages the "WinnerPedestal" (a pedestal tagged "PlayerPedestal" and named "WinnerPedestal"): when a
	round ends it shows the winner of that round. When several players share the win (a tie, or a winning team),
	it steps through them, changing the UserId every TIED_WINNER_SWITCH_INTERVAL seconds and looping.
	Until the first round ends, the pedestal keeps whatever UserId it was placed with in Studio.
]]

local PedestalService = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local PEDESTAL_TAG = "PlayerPedestal"
local WINNER_PEDESTAL_NAME = "WinnerPedestal"
local USER_ID_ATTRIBUTE = "UserId"
local TIED_WINNER_SWITCH_INTERVAL = 2.5

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

local function setWinnerUserId(userId: number)
	displayedUserId = userId
	for pedestal in winnerPedestals do
		pedestal:SetAttribute(USER_ID_ATTRIBUTE, userId)
	end
end

local function registerPedestal(instance: Instance)
	if instance.Name ~= WINNER_PEDESTAL_NAME or winnerPedestals[instance] then
		return
	end
	winnerPedestals[instance] = true
	if displayedUserId then
		instance:SetAttribute(USER_ID_ATTRIBUTE, displayedUserId)
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

	GameStateLibrary.RoundFinishedTasks:Add(onRoundFinished)
end

return PedestalService
