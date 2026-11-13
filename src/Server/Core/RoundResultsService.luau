--[[
	RoundResultsService

	Description:
	Records what's needed to rank every player when a round ends, and works out the placements shown on the end-of-round
	screen (PreIntermission), sent in IntermissionData.Placements by RoundCyclingService.
	While a round is active it records each participant (anyone who was alive in the arena), their eliminations this round
	(CombatLibrary.PlayerKilledPlayerTasks), when they were last knocked out of the arena, and their team colour.
	Ranking (Sol, 2026-11-12), by the gamemode's CanRespawn (Shared/Constants/Gamemodes):
	- Modes with respawns (Classic, TeamClassic, Assassin...): most eliminations this round first.
	- Last-one-standing modes (Elimination, TeamElimination, HotPotato): whoever stayed in longest first (still alive at
	  the end beats everyone knocked out).
	Players with the same result share a place (1, 2, 2, 4). The winner(s) are left out of the list (the screen shows them
	above it) and the list starts at 2nd; after a tie or with no winner it starts at 1st. In team modes every other player is
	ranked on their own, with their team colour. Players who left mid-round are left out.
]]

local RoundResultsService = {}

-------------------------------------------------------------------------------
-- SERVICES / MODULES
-------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local GameTeamService = require(script.Parent.GameTeamService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Placement = {
	UserId: number,
	Place: number,
	TeamColor: Color3?, -- // Team modes only
}

type Record = {
	Elims: number,
	KnockedOutAt: number?, -- // os.clock() when last removed from the arena; nil while still in it
	TeamColor: Color3?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local records: { [Player]: Record } = {}
local recording = false -- // True while a round is active (stops once its results are taken)
local inArena: { [Player]: boolean } = {}
local roundGamemode: string? = nil -- // Remembered while the round runs (CurrentRoundData is cleared before a timed-out round ends)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getRecord(player: Player): Record
	local record = records[player]
	if not record then
		record = { Elims = 0 }
		records[player] = record
	end
	return record
end

-- // The player's team colour when they're on one of this round's opposing teams (team modes), else nil
local function getTeamColor(player: Player): Color3?
	local team = player.Team
	if team and table.find(GameTeamService.getActiveOppositionTeams(), team) then
		return team.TeamColor.Color
	end
	return nil
end

local function onLivingPlayersChanged(livingPlayers: { Player }?)
	if not recording then
		return
	end
	local now = os.clock()
	local stillIn: { [Player]: boolean } = {}
	for _, player in livingPlayers or {} do
		stillIn[player] = true
		local record = getRecord(player)
		record.KnockedOutAt = nil
		record.TeamColor = getTeamColor(player) or record.TeamColor
	end
	for player in inArena do
		if not stillIn[player] and records[player] then
			records[player].KnockedOutAt = now
		end
	end
	inArena = stillIn
end

-- // Larger is better
local function score(record: Record, byEliminations: boolean): number
	if byEliminations then
		return record.Elims
	end
	return if record.KnockedOutAt then record.KnockedOutAt else math.huge
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Ends recording for this round and returns every non-winning participant's place, best first.
-- // winners: the players shown as the winner (one player, or the winning team); empty after a tie or with no winner.
function RoundResultsService.takePlacements(winners: { Player }): { Placement }
	recording = false
	local gamemode = roundGamemode and Gamemodes[roundGamemode]
	local byEliminations = if gamemode then gamemode.CanRespawn else true

	local isWinner: { [Player]: boolean } = {}
	for _, player in winners do
		isWinner[player] = true
	end

	local entries: { { Player: Player, Score: number, TeamColor: Color3? } } = {}
	for player, record in records do
		if player.Parent ~= Players or isWinner[player] then
			continue
		end
		table.insert(entries, { Player = player, Score = score(record, byEliminations), TeamColor = record.TeamColor })
	end
	table.sort(entries, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Player.UserId < b.Player.UserId
	end)

	local placements: { Placement } = {}
	local firstPlace = if #winners > 0 then 2 else 1
	for index, entry in entries do
		local previous = entries[index - 1]
		local place = if previous and previous.Score == entry.Score
			then placements[index - 1].Place
			else firstPlace + index - 1
		table.insert(placements, { UserId = entry.Player.UserId, Place = place, TeamColor = entry.TeamColor })
	end
	return placements
end

-- // The team colour recorded for a player this round (team modes), if any
function RoundResultsService.getTeamColor(player: Player): Color3?
	local record = records[player]
	return record and record.TeamColor
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RoundResultsService.start()
	local gameStateData = GameStateLibrary.getGameStateData()

	-- // A new round starts recording from scratch
	gameStateData.GameplayPhase:Subscribe(function(phase: number)
		if phase == GameplayPhases.RoundActive and not recording then
			table.clear(records)
			table.clear(inArena)
			recording = true
			onLivingPlayersChanged(gameStateData.LivingPlayersInArena:Get())
		end
	end)
	gameStateData.LivingPlayersInArena:Subscribe(onLivingPlayersChanged)
	gameStateData.CurrentRoundData:Subscribe(function(roundData)
		if roundData and roundData.Gamemode then
			roundGamemode = roundData.Gamemode
		end
	end)

	CombatLibrary.PlayerKilledPlayerTasks:Add(function(attacker: Player, _victim: Player)
		if recording and attacker then
			getRecord(attacker).Elims += 1
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		records[player] = nil
		inArena[player] = nil
	end)
end

return RoundResultsService
