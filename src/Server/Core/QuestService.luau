--[[
	QuestService

	Description:
	Gives players their quests, counts their progress and pays out claimed quests. Server only: the client sees its
	quests through the replicated profile (`Quests`) and asks to claim one with the "ClaimQuest" remote function.

	- Each pool in Shared/Referential/Quests (Daily, Weekly, ...) gives a player `Slots` quests, drawn at random from
	  that pool. When the pool's reset period changes (UTC midnight for Daily, Monday for Weekly) the player gets new
	  ones; unclaimed rewards from the old ones are lost. Checked when the profile loads, every RESET_CHECK_INTERVAL
	  seconds, and before any progress or claim.
	- Progress comes from the same server events the lifetime stats use (see Shared/Referential/Quests for what each
	  objective type counts). Actions only count while the player is alive in the arena, so the lobby can't be farmed.
	- Rewards are granted with RewardService (shared by everything that gives rewards).
	- Reroll: swaps one unclaimed quest, in its place, for another from the same pool that the player doesn't
	  have. Paid with the "QuestReroll" developer product (MarketplaceItems):
	    1. The client reserves the quest ("ReserveQuestReroll" remote function). While it's reserved it gets no progress
	       and can't be claimed.
	    2. Once the server confirms, the client shows the purchase prompt.
	    3. The receipt (ProductLogics/QuestReroll -> QuestService.applyPaidReroll) rerolls the reserved quest. Declining
	       the prompt releases it. A receipt with no usable reservation (e.g. after a rejoin, or the quests reset in
	       between) rerolls a random weekly quest instead, so a purchase always gives something.
]]

local QuestService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Quests = require(ReplicatedStorage.Shared.Referential.Quests)
local QuestLibrary = require(ReplicatedStorage.Shared.Library.QuestLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local SharedTasks = require(ReplicatedStorage.Shared.Constants.SharedTasks)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local PickupService = require(ServerStorage.Server.Core.PickupService)
local BotService = require(ServerStorage.Server.Core.BotService)
local RewardService = require(ServerStorage.Server.Core.RewardService)
local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local RESET_CHECK_INTERVAL = 30 -- // Seconds between checks for a pool reset (so quests refresh at midnight for players online)
local MINUTES_TICK = 5 -- // Seconds between MinutesPlayed checks
local FALLBACK_REROLL_POOL = "Weekly" -- // A paid reroll with no reserved quest rerolls a random quest from this pool
local SECONDS_IN_MINUTE = 60

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // Does this objective count this event?
type ObjectiveMatcher = (objective: Quests.Objective) -> boolean

-- // A quest held for a reroll the player is buying (the quest's id too, in case the slot changes meanwhile)
type RerollReservation = { PoolName: string, SlotIndex: number, QuestId: string }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimQuestFunction = SimpleRemotes.getFunction("ClaimQuest")
local reserveQuestRerollFunction = SimpleRemotes.getFunction("ReserveQuestReroll")
local REROLL_PRODUCT_ID = MarketplaceLibrary.getItemId("QuestReroll")

local random = Random.new()
local roundParticipants: { [Player]: true } = {} -- // Players in the server when the current round started
local currentGamemode: string? = nil -- // The current (or last) round's gamemode id
local secondsInArena: { [Player]: number } = {} -- // Time alive in the arena not yet counted as a whole minute
local claiming: { [Player]: true } = {}
local rerollReservations: { [Player]: RerollReservation } = {} -- // At most one per player (a new one replaces it)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Whether this quest is held for a reroll the player is buying (no progress, no claim)
local function isReservedForReroll(player: Player, poolName: string, slotIndex: number, questId: string): boolean
	local reservation = rerollReservations[player]
	return reservation ~= nil
		and reservation.PoolName == poolName
		and reservation.SlotIndex == slotIndex
		and reservation.QuestId == questId
end

local function isAliveInArena(player: Player): boolean
	local living = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get() or {}
	return table.find(living, player) ~= nil
end

local function isRoundActive(): boolean
	return GameStateLibrary.getGameStateData().GameplayPhase:Get() == GameplayPhases.RoundActive
end

local function getGamemode(): string?
	local roundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
	return (roundData and roundData.Gamemode) or currentGamemode
end

-- // Picks `count` different quests from the pool, preferring different objective types (variety)
local function drawQuests(poolName: string, count: number): { QuestLibrary.QuestSlot }
	local candidates = table.clone(QuestLibrary.getQuestsInPool(poolName))
	local slots: { QuestLibrary.QuestSlot } = {}
	local usedTypes: { [string]: true } = {}
	while #slots < count and #candidates > 0 do
		-- // Quests whose objective type isn't taken yet, unless none are left
		local fresh = {}
		for index, quest in candidates do
			if not usedTypes[quest.Objective.Type] then
				table.insert(fresh, index)
			end
		end
		local index = if #fresh > 0 then fresh[random:NextInteger(1, #fresh)] else random:NextInteger(1, #candidates)
		local quest = table.remove(candidates, index) :: Quests.Quest
		usedTypes[quest.Objective.Type] = true
		table.insert(slots, { Id = quest.Id, Progress = 0, Claimed = false })
	end
	return slots
end

-- // Gives the player new quests in any pool that has reset (or that they've never had). Returns their data, or nil.
local function refreshPools(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end
	if data.Quests == nil then
		data.Quests = {}
	end
	for _, poolName in QuestLibrary.getPoolNames() do
		local pool = Quests.Pools[poolName]
		local periodKey = QuestLibrary.getPeriodKey(pool.ResetPeriod)
		local poolData = data.Quests[poolName]
		local needsDraw = poolData == nil
			or (pool.ResetPeriod ~= "Never" and poolData.PeriodKey ~= periodKey)
		if needsDraw then
			data.Quests[poolName] = {
				PeriodKey = periodKey,
				Slots = drawQuests(poolName, pool.Slots),
			}
		end
	end
	return data
end

-- // Adds progress to every unfinished quest of the player's that counts this event
local function addProgress(player: Player, amount: number, matches: ObjectiveMatcher)
	local data = refreshPools(player)
	if not data then
		return
	end
	for _, poolName in QuestLibrary.getPoolNames() do
		local poolData = data.Quests[poolName]
		if not poolData then
			continue
		end
		local rawSlots = (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
		for index, rawSlot in rawSlots do
			local quest = QuestLibrary.getQuest(rawSlot.Id)
			if not quest or rawSlot.Claimed or rawSlot.Progress >= quest.Objective.Goal then
				continue
			end
			if isReservedForReroll(player, poolName, index, rawSlot.Id) then
				continue
			end
			if matches(quest.Objective) then
				-- // Through the proxy, so the change replicates to the player
				poolData.Slots[index].Progress = math.min(rawSlot.Progress + amount, quest.Objective.Goal)
			end
		end
	end
end

local function matchesGamemode(objective: Quests.Objective, gamemode: string?): boolean
	return objective.Gamemode == nil or objective.Gamemode == gamemode
end

local function addElimination(player: Player)
	local gamemode = getGamemode()
	addProgress(player, 1, function(objective)
		return objective.Type == "Eliminations" and matchesGamemode(objective, gamemode)
	end)
end

local function onRoundFinished(winner: Player?, winningTeam: Team?, isTie: boolean?)
	local gamemode = getGamemode()
	local participants = roundParticipants
	roundParticipants = {}

	for player in participants do
		if player.Parent == Players then
			addProgress(player, 1, function(objective)
				return objective.Type == "RoundsPlayed" and matchesGamemode(objective, gamemode)
			end)
		end
	end

	if isTie then
		return
	end
	-- // Team wins count for every member of the winning team (like the lifetime Wins stat)
	local winners: { Player } = {}
	if winningTeam then
		winners = winningTeam:GetPlayers()
	elseif winner then
		winners = { winner }
	end
	for _, player in winners do
		addProgress(player, 1, function(objective)
			return objective.Type == "Wins" and matchesGamemode(objective, gamemode)
		end)
	end
end

-- // Every MINUTES_TICK seconds: time alive in the arena during a round, counted in whole minutes
local function tickMinutesPlayed()
	if not isRoundActive() then
		return
	end
	for _, player in GameStateLibrary.getGameStateData().LivingPlayersInArena:Get() or {} do
		if player.Parent ~= Players then
			continue
		end
		local seconds = (secondsInArena[player] or 0) + MINUTES_TICK
		if seconds >= SECONDS_IN_MINUTE then
			seconds -= SECONDS_IN_MINUTE
			addProgress(player, 1, function(objective)
				return objective.Type == "MinutesPlayed"
			end)
		end
		secondsInArena[player] = seconds
	end
end

local function claimQuest(player: Player, poolName: any, slotIndex: any): boolean
	if type(poolName) ~= "string" or type(slotIndex) ~= "number" or claiming[player] then
		return false
	end
	local data = refreshPools(player)
	local poolData = data and data.Quests[poolName]
	if not poolData then
		return false
	end
	local rawSlots = (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
	local rawSlot = rawSlots[slotIndex]
	if not rawSlot or not QuestLibrary.isClaimable(rawSlot) or isReservedForReroll(player, poolName, slotIndex, rawSlot.Id) then
		return false
	end
	local quest = QuestLibrary.getQuest(rawSlot.Id)
	if not quest then
		return false
	end

	-- // Marked claimed before granting, so a second request can't pay out twice; undone if the grant fails
	claiming[player] = true
	local slot = poolData.Slots[slotIndex]
	slot.Claimed = true
	local granted = RewardService.grant(player, QuestLibrary.getReward(quest))
	if not granted then
		slot.Claimed = false
		warn(`QuestService: failed to grant the reward for {quest.Id} to {player.Name}`)
	end
	claiming[player] = nil
	return granted
end

-- // Holds one of the player's quests for a reroll they're about to buy (replacing any earlier reservation). Returns
-- // whether it was reserved: the client only shows the purchase prompt after that.
local function reserveQuestReroll(player: Player, poolName: any, slotIndex: any): boolean
	if type(poolName) ~= "string" or type(slotIndex) ~= "number" or claiming[player] then
		return false
	end
	local data = refreshPools(player)
	local poolData = data and data.Quests[poolName]
	if not poolData then
		return false
	end
	local rawSlots = (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
	local rawSlot = rawSlots[slotIndex]
	if not rawSlot or not QuestLibrary.canReroll(rawSlot) then
		return false
	end
	rerollReservations[player] = { PoolName = poolName, SlotIndex = slotIndex, QuestId = rawSlot.Id }
	return true
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (also used by the Cmdr commands in Server/Cmdr/Commands)
-------------------------------------------------------------------------------

-- // Swaps one of the player's quests, in the same place, for another quest from that pool they don't have
-- // (preferring a kind of objective their other quests in the pool don't use). Not for a quest whose reward was claimed.
-- // Returns whether it was swapped.
function QuestService.rerollQuest(player: Player, poolName: string, slotIndex: number): boolean
	local data = refreshPools(player)
	local poolData = data and data.Quests[poolName]
	if not poolData then
		return false
	end
	local rawSlots = (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
	local rawSlot = rawSlots[slotIndex]
	if not rawSlot or not QuestLibrary.canReroll(rawSlot) then
		return false
	end

	local heldIds: { [string]: true } = {}
	local otherTypes: { [string]: true } = {}
	for index, slot in rawSlots do
		heldIds[slot.Id] = true
		local quest = QuestLibrary.getQuest(slot.Id)
		if quest and index ~= slotIndex then
			otherTypes[quest.Objective.Type] = true
		end
	end
	local candidates: { Quests.Quest } = {}
	local freshCandidates: { Quests.Quest } = {}
	for _, quest in QuestLibrary.getQuestsInPool(poolName) do
		if not heldIds[quest.Id] then
			table.insert(candidates, quest)
			if not otherTypes[quest.Objective.Type] then
				table.insert(freshCandidates, quest)
			end
		end
	end
	local pickFrom = if #freshCandidates > 0 then freshCandidates else candidates
	if #pickFrom == 0 then
		return false -- // The pool has no other quest to give
	end
	local quest = pickFrom[random:NextInteger(1, #pickFrom)]
	poolData.Slots[slotIndex] = { Id = quest.Id, Progress = 0, Claimed = false } -- // Through the proxy, so it replicates
	return true
end

-- // The QuestReroll developer product was bought (ProductLogics/QuestReroll). Rerolls the reserved quest, or, if
-- // there's no usable reservation, a random weekly quest. Returns false only if nothing could be rerolled at all
-- // (the receipt then stays unprocessed and Roblox retries it later, e.g. once the quests have reset).
function QuestService.applyPaidReroll(player: Player): boolean
	local reservation = rerollReservations[player]
	rerollReservations[player] = nil
	if reservation then
		local data = refreshPools(player)
		local poolData = data and data.Quests[reservation.PoolName]
		local rawSlots = poolData and (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
		local rawSlot = rawSlots and rawSlots[reservation.SlotIndex]
		if rawSlot and rawSlot.Id == reservation.QuestId
			and QuestService.rerollQuest(player, reservation.PoolName, reservation.SlotIndex) then
			return true
		end
	end

	-- // Fallback: a random weekly quest that can still be rerolled
	local data = refreshPools(player)
	local poolData = data and data.Quests[FALLBACK_REROLL_POOL]
	if not poolData then
		return false
	end
	local rawSlots = (poolData.Slots :: any)() :: { QuestLibrary.QuestSlot }
	local rerollable: { number } = {}
	for index, rawSlot in rawSlots do
		if QuestLibrary.canReroll(rawSlot) then
			table.insert(rerollable, index)
		end
	end
	while #rerollable > 0 do
		local index = table.remove(rerollable, random:NextInteger(1, #rerollable)) :: number
		if QuestService.rerollQuest(player, FALLBACK_REROLL_POOL, index) then
			return true
		end
	end
	warn(`QuestService: {player.Name} bought a quest reroll but none of their quests could be rerolled`)
	return false
end

-- // Draws new quests for the player now, in one pool or all of them. Returns false if their data isn't loaded.
function QuestService.resetQuests(player: Player, poolName: string?): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	if data.Quests == nil then
		data.Quests = {}
	end
	for _, name in QuestLibrary.getPoolNames() do
		if poolName == nil or poolName == name then
			data.Quests[name] = nil
		end
	end
	return refreshPools(player) ~= nil
end

-- // Finishes all of the player's current quests (they still have to claim them). Returns false if their data isn't loaded.
function QuestService.completeQuests(player: Player): boolean
	return QuestService.addProgressForTesting(player, math.huge)
end

-- // Adds progress to every current quest of the player's (testing)
function QuestService.addProgressForTesting(player: Player, amount: number): boolean
	if not PlayerDataService.get(player) then
		return false
	end
	addProgress(player, amount, function()
		return true
	end)
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function QuestService.init()
	claimQuestFunction.OnServerInvoke = claimQuest
	reserveQuestRerollFunction.OnServerInvoke = reserveQuestReroll
	-- // Declined (or closed) the reroll purchase: the quest counts progress again. A purchase keeps it for the receipt.
	MarketplaceLibrary.ProductPurchasePromptFinishedTasks:Add(function(player: Player, productId: number, wasPurchased: boolean)
		if productId == REROLL_PRODUCT_ID and not wasPurchased then
			rerollReservations[player] = nil
		end
	end)

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player)
		refreshPools(player)
	end)
	local function clearPlayer(player: Player)
		roundParticipants[player] = nil
		secondsInArena[player] = nil
		claiming[player] = nil
		rerollReservations[player] = nil
	end
	PlayerDataService.ProfileRemovingTasks:Add(clearPlayer)
	-- // Also for a player whose profile never loaded (no ProfileRemoving for them)
	Players.PlayerRemoving:Connect(clearPlayer)

	-- // Eliminations: another player, or a bot whose behavior counts (decoys don't)
	CombatLibrary.PlayerKilledPlayerTasks:Add(function(killer: Player, victim: Player, _weaponId: string)
		if killer and victim and killer ~= victim then
			addElimination(killer)
		end
	end)
	BotService.BotEliminatedTasks:Add(function(throwerPlayer: Player, bot: BotService.Bot)
		if bot.Behavior.CountsAsElimination ~= false and throwerPlayer.UserId ~= bot.OwnerUserId then
			addElimination(throwerPlayer)
		end
	end)

	SharedTasks.WeaponThrownTasks:Add(function(player: Player, _toolId: string)
		if isAliveInArena(player) then
			addProgress(player, 1, function(objective)
				return objective.Type == "Throws"
			end)
		end
	end)

	SharedTasks.PlayerUsedAbility:Add(function(player: Player, abilityId: string)
		if isAliveInArena(player) then
			addProgress(player, 1, function(objective)
				return objective.Type == "AbilityUses" and objective.AbilityId == abilityId
			end)
		end
	end)

	PickupService.PickupAcquiredTasks:Add(function(player: Player, pickupClassId: string)
		addProgress(player, 1, function(objective)
			return objective.Type == "Pickups" and (objective.PickupId == nil or objective.PickupId == pickupClassId)
		end)
	end)
	PickupService.PickupUsedTasks:Add(function(player: Player, pickupClassId: string)
		addProgress(player, 1, function(objective)
			return objective.Type == "PickupUses" and objective.PickupId == pickupClassId
		end)
	end)

	local gameStateData = GameStateLibrary.getGameStateData()
	gameStateData.CurrentRoundData:Subscribe(function(roundData)
		if roundData and roundData.Gamemode then
			currentGamemode = roundData.Gamemode
		end
	end)
	GameStateLibrary.RoundStartingTasks:Add(function()
		table.clear(roundParticipants)
		for _, player in Players:GetPlayers() do
			roundParticipants[player] = true
		end
	end)
	GameStateLibrary.RoundFinishedTasks:Add(onRoundFinished)
end

function QuestService.start()
	task.spawn(function()
		while true do
			task.wait(MINUTES_TICK)
			tickMinutesPlayed()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(RESET_CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				refreshPools(player)
			end
		end
	end)
end

return QuestService
