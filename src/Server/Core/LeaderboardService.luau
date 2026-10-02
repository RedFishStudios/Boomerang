--[[
	LeaderboardService

	Description:
	Saves each player's Elims / Wins (all-time and this month) to OrderedDataStores and loads the top
	players for the lobby leaderboards (T-032). Everything runs in one background loop every
	LeaderboardConstants.RefreshInterval; nothing runs per frame. Clients draw the boards themselves
	(LeaderboardController), the server only sends the entries.
]]

local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local UserService = game:GetService("UserService")

local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local LeaderboardConstants = require(ReplicatedStorage.Shared.Constants.LeaderboardConstants)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Separate stores for Studio and live servers, like PlayerDataService's "Dev" / "Live" keys
local STORE_PREFIX = if RunService:IsStudio() then "Dev" else "Live"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type LeaderboardData = LeaderboardConstants.LeaderboardData
type Entry = LeaderboardConstants.Entry

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local leaderboardsUpdated = SimpleRemotes.getEvent("LeaderboardsUpdated")
local getLeaderboards = SimpleRemotes.getFunction("GetLeaderboards")
local swapLeaderboardPeriods = SimpleRemotes.getEvent("SwapLeaderboardPeriods")

local stores: { [string]: OrderedDataStore } = {}
local currentData: LeaderboardData = {}

-- // userId -> store name -> last value saved, so unchanged scores aren't written again
local lastWritten: { [number]: { [string]: number } } = {}
local displayNameCache: { [number]: string } = {}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getStoreName(boardId: string, period: string, monthKey: string): string
	if period == "Monthly" then
		return `{STORE_PREFIX}_{boardId}_{monthKey}`
	end
	return `{STORE_PREFIX}_{boardId}_AllTime`
end

local function getStore(storeName: string): OrderedDataStore
	local store = stores[storeName]
	if not store then
		store = DataStoreService:GetOrderedDataStore(storeName)
		stores[storeName] = store
	end
	return store
end

-- // Store name -> the player's current score, read from their profile
local function getScores(data: PlayerDataService.Data, monthKey: string): { [string]: number }
	local scores = {}
	local monthly = data.MonthlyStats
	for boardId, board in LeaderboardConstants.Boards do
		scores[getStoreName(boardId, "AllTime", monthKey)] = (data :: any)[board.StatField]
		if monthly.MonthKey == monthKey then
			scores[getStoreName(boardId, "Monthly", monthKey)] = (monthly :: any)[board.StatField]
		end
	end
	return scores
end

-- // Yields. Only writes scores above 0 that changed since the last write
local function writeScores(userId: number, scores: { [string]: number })
	local written = lastWritten[userId]
	if not written then
		written = {}
		lastWritten[userId] = written
	end

	for storeName, value in scores do
		if value <= 0 or written[storeName] == value then
			continue
		end
		local store = getStore(storeName)
		local ok, err = pcall(store.SetAsync, store, tostring(userId), value)
		if ok then
			written[storeName] = value
		else
			warn(`LeaderboardService: couldn't save {storeName} for {userId}: {err}`)
		end
	end
end

-- // Yields. Returns the top entries (without display names), or nil if the request failed
local function readTop(storeName: string): { { UserId: number, Value: number } }?
	local store = getStore(storeName)
	local ok, pages = pcall(store.GetSortedAsync, store, false, LeaderboardConstants.EntriesShown)
	if not ok then
		warn(`LeaderboardService: couldn't load {storeName}: {pages}`)
		return nil
	end

	local top = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(top, { UserId = userId, Value = item.value })
		end
	end
	return top
end

-- // Yields. Fills displayNameCache for any ids not in it yet (one batched request)
local function cacheDisplayNames(userIds: { number })
	local missing = {}
	for _, userId in userIds do
		if not displayNameCache[userId] and not table.find(missing, userId) then
			table.insert(missing, userId)
		end
	end
	if #missing == 0 then
		return
	end

	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if not ok then
		warn(`LeaderboardService: couldn't load display names: {infos}`)
		return
	end
	for _, info in infos do
		displayNameCache[info.Id] = info.DisplayName
	end
end

-- // Yields. Saves everyone's scores, then reloads all boards and sends them to clients
local function refresh()
	local monthKey = LeaderboardConstants.getMonthKey()

	for _, player in Players:GetPlayers() do
		local data = PlayerDataService.get(player)
		if data then
			writeScores(player.UserId, getScores(data, monthKey))
		end
	end

	local tops: { [string]: { [string]: { { UserId: number, Value: number } } } } = {}
	local userIds = {}
	for boardId in LeaderboardConstants.Boards do
		tops[boardId] = {}
		for _, period in LeaderboardConstants.Periods do
			-- // Keep showing the previous entries if a request fails
			local top = readTop(getStoreName(boardId, period, monthKey))
			if top then
				tops[boardId][period] = top
				for _, item in top do
					table.insert(userIds, item.UserId)
				end
			end
		end
	end

	cacheDisplayNames(userIds)

	local newData: LeaderboardData = table.clone(currentData)
	for boardId, periods in tops do
		newData[boardId] = if newData[boardId] then table.clone(newData[boardId]) else {}
		for period, top in periods do
			local entries: { Entry } = {}
			for rank, item in top do
				table.insert(entries, {
					Rank = rank,
					UserId = item.UserId,
					DisplayName = displayNameCache[item.UserId] or `Player {item.UserId}`,
					Value = item.Value,
				})
			end
			newData[boardId][period] = entries
		end
	end

	currentData = newData
	leaderboardsUpdated:FireAllClients(currentData)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Yields. Saves scores and reloads the boards now (for testing: Cmdr "refreshleaderboards")
function LeaderboardService.refreshNow()
	refresh()
end

-- // Makes every client's boards fade to the next period now (for testing: Cmdr "triggerleaderboardchange")
function LeaderboardService.swapPeriodsNow()
	swapLeaderboardPeriods:FireAllClients()
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function LeaderboardService.init()
	getLeaderboards.OnServerInvoke = function()
		return currentData
	end

	-- // Read the scores while the profile is still loaded, then save them in the background
	PlayerDataService.ProfileRemovingTasks:Add(function(player: Player)
		local data = PlayerDataService.get(player)
		if not data then
			return
		end
		local userId = player.UserId
		local scores = getScores(data, LeaderboardConstants.getMonthKey())
		task.spawn(function()
			writeScores(userId, scores)
			lastWritten[userId] = nil
		end)
	end)
end

function LeaderboardService.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(LeaderboardConstants.RefreshInterval)
		end
	end)
end

return LeaderboardService
