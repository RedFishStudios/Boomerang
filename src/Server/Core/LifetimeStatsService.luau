--[[
	LifetimeStatsService

	Description:
	Owns the lifetime stats saved in the player's profile: Elims, Defeats, Wins, RoundsPlayed,
	TimePlayed, Throws, AbilityUses, PickupsAcquired and MonthlyStats. Other code shouldn't write these fields directly.
	(Live, per-life stats like health are in PlayerStatService.)
]]

local LifetimeStatsService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local PickupService = require(ServerStorage.Server.Core.PickupService)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Constants.LeaderboardConstants)
local PlayerStatAttributes = require(ReplicatedStorage.Shared.Constants.PlayerStatAttributes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local TIME_PLAYED_FLUSH_INTERVAL = 60 -- // Seconds between saving time played into the profile

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Stats = {
	Elims: number,
	Defeats: number,
	Wins: number,
	RoundsPlayed: number,
	TimePlayed: number,
	Throws: number,
	AbilityUses: { [string]: number },
	PickupsAcquired: { [string]: number },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-- // os.clock() of the last time each player's time played was added to their profile
local timeCountedSince: { [Player]: number } = {}

-- // Players in the server when the current round started; only they get RoundsPlayed
local roundParticipants: { [Player]: true } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function incrementCount(player: Player, field: "AbilityUses" | "PickupsAcquired", id: string)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local counts = data[field]
	counts[id] = (counts[id] or 0) + 1
end

-- // Adds 1 to this month's Elims or Wins, starting a new month if it changed
local function incrementMonthly(data: PlayerDataService.Data, field: "Elims" | "Wins")
	local monthly = data.MonthlyStats
	local monthKey = LeaderboardConstants.getMonthKey()
	if monthly.MonthKey ~= monthKey then
		monthly.MonthKey = monthKey
		monthly.Elims = 0
		monthly.Wins = 0
	end
	monthly[field] += 1
end

-- // T-130: copy the player's lifetime totals onto their Player attributes, so every client's Stats panel can show them
local function publishLifetimeStats(player: Player)
	local data = PlayerDataService.get(player)
	if not data or player.Parent ~= Players then
		return
	end
	player:SetAttribute(PlayerStatAttributes.Elims, data.Elims)
	player:SetAttribute(PlayerStatAttributes.Defeats, data.Defeats)
	player:SetAttribute(PlayerStatAttributes.Wins, data.Wins)
	player:SetAttribute(PlayerStatAttributes.Losses, math.max(0, data.RoundsPlayed - data.Wins))
end

local function addRoundStat(player: Player, attribute: string)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)
end

local function flushTimePlayed(player: Player)
	local since = timeCountedSince[player]
	local data = PlayerDataService.get(player)
	if not since or not data then
		return
	end
	local now = os.clock()
	data.TimePlayed += math.floor(now - since)
	-- // Keep the fractional second for the next flush
	timeCountedSince[player] = now - ((now - since) % 1)
end

local function onRoundFinished(winner: Player?, winningTeam: Team?, isTie: boolean?)
	local participants = table.clone(roundParticipants)
	for player in roundParticipants do
		if player.Parent == Players then
			local data = PlayerDataService.get(player)
			if data then
				data.RoundsPlayed += 1
			end
		end
	end
	table.clear(roundParticipants)

	if isTie then
		for player in participants do
			publishLifetimeStats(player)
		end
		return
	end

	-- // Team wins count for every member of the winning team
	local winners: { Player } = {}
	if winningTeam then
		winners = winningTeam:GetPlayers()
	elseif winner then
		winners = { winner }
	end
	for _, player in winners do
		LifetimeStatsService.addWin(player)
	end
	for player in participants do
		publishLifetimeStats(player)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LifetimeStatsService.addWin(player: Player)
	local data = PlayerDataService.get(player)
	if data then
		data.Wins += 1
		incrementMonthly(data, "Wins")
		publishLifetimeStats(player)
	end
end

-- // Returns a copy of the player's lifetime stats, or nil if their data isn't loaded
function LifetimeStatsService.getStats(player: Player): Stats?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	flushTimePlayed(player)
	return {
		Elims = data.Elims,
		Defeats = data.Defeats,
		Wins = data.Wins,
		RoundsPlayed = data.RoundsPlayed,
		TimePlayed = data.TimePlayed,
		Throws = data.Throws,
		AbilityUses = table.clone((data.AbilityUses :: any)()),
		PickupsAcquired = table.clone((data.PickupsAcquired :: any)()),
	}
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LifetimeStatsService.init()
	-- // Eliminations and defeats only count when another player did it
	CombatLibrary.PlayerKilledPlayerTasks:Add(function(killer: Player, victim: Player, _weaponId: string)
		if not killer or not victim then
			return
		end
		local killerData = PlayerDataService.get(killer)
		if killerData then
			killerData.Elims += 1
			incrementMonthly(killerData, "Elims")
		end
		local victimData = PlayerDataService.get(victim)
		if victimData then
			victimData.Defeats += 1
		end
		addRoundStat(killer, PlayerStatAttributes.RoundElims)
		addRoundStat(victim, PlayerStatAttributes.RoundDefeats)
		publishLifetimeStats(killer)
		publishLifetimeStats(victim)
	end)

	-- // Every successful throw (fired by WeaponService after the throw is accepted)
	SharedTasks.WeaponThrownTasks:Add(function(player: Player, _toolId: string)
		local data = PlayerDataService.get(player)
		if data then
			data.Throws += 1
		end
	end)

	SharedTasks.PlayerUsedAbility:Add(function(player: Player, abilityId: string)
		incrementCount(player, "AbilityUses", abilityId)
	end)

	PickupService.PickupAcquiredTasks:Add(function(player: Player, pickupClassId: string)
		incrementCount(player, "PickupsAcquired", pickupClassId)
	end)

	GameStateLibrary.RoundStartingTasks:Add(function()
		table.clear(roundParticipants)
		for _, player in Players:GetPlayers() do
			roundParticipants[player] = true
			-- // T-130: a new round's elims and defeats start from 0 (the last round's stay shown until then)
			player:SetAttribute(PlayerStatAttributes.RoundElims, 0)
			player:SetAttribute(PlayerStatAttributes.RoundDefeats, 0)
		end
	end)
	GameStateLibrary.RoundFinishedTasks:Add(onRoundFinished)

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player)
		timeCountedSince[player] = os.clock()
		publishLifetimeStats(player)
	end)
	-- // Runs before the profile session ends, so the last stretch of time played is saved
	PlayerDataService.ProfileRemovingTasks:Add(function(player: Player)
		flushTimePlayed(player)
		timeCountedSince[player] = nil
		roundParticipants[player] = nil
	end)
end

function LifetimeStatsService.start()
	task.spawn(function()
		while true do
			task.wait(TIME_PLAYED_FLUSH_INTERVAL)
			for player in timeCountedSince do
				flushTimePlayed(player)
			end
		end
	end)
end

return LifetimeStatsService
