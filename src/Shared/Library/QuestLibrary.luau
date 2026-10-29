--[[
	QuestLibrary (T-143)

	Description:
	Shared quest helpers, used by QuestService (server) and the Quests menu (client): finding quests and pools, their
	text and reward, and the reset timing. Reset times are in UTC, so every server and client agrees on them.
	Definitions are in Shared/Referential/Quests; saved progress is the profile's `Quests` (see ProfileTemplate).
]]

local QuestLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Quests = require(ReplicatedStorage.Shared.Referential.Quests)
local RewardLibrary = require(ReplicatedStorage.Shared.Library.RewardLibrary)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // One quest a player has, as saved in the profile (Quests[pool].Slots)
export type QuestSlot = {
	Id: string, -- // Quest id (Shared/Referential/Quests)
	Progress: number,
	Claimed: boolean,
}

-- // A pool's saved state: which period the slots belong to, and the slots
export type PoolData = {
	PeriodKey: string, -- // QuestLibrary.getPeriodKey for the pool's ResetPeriod when these quests were drawn ("" = never)
	Slots: { QuestSlot },
}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SECONDS_IN_DAY = 86400
local DAYS_IN_WEEK = 7
local WEEK_START_OFFSET_DAYS = 3 -- // Day 0 (1970-01-01) was a Thursday: shifting by 3 days makes weeks start on Monday

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local questsById: { [string]: Quests.Quest } = {}
local questsByPool: { [string]: { Quests.Quest } } = {}
for _, quest in Quests.List do
	assert(not questsById[quest.Id], `QuestLibrary: duplicate quest id {quest.Id}`)
	assert(Quests.Pools[quest.Pool], `QuestLibrary: quest {quest.Id} is in unknown pool {quest.Pool}`)
	questsById[quest.Id] = quest
	questsByPool[quest.Pool] = questsByPool[quest.Pool] or {}
	table.insert(questsByPool[quest.Pool], quest)
end

local poolNames: { string } = {}
for poolName in Quests.Pools do
	table.insert(poolNames, poolName)
end
table.sort(poolNames, function(a, b)
	return Quests.Pools[a].Order < Quests.Pools[b].Order
end)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // "FireBoomerang" -> "Fire Boomerang"
local function spaceOut(id: string): string
	return (id:gsub("(%l)(%u)", "%1 %2"))
end

local function plural(count: number, singular: string, pluralForm: string?): string
	return if count == 1 then singular else (pluralForm or `{singular}s`)
end

local function getGamemodeSuffix(objective: Quests.Objective): string
	if not objective.Gamemode then
		return ""
	end
	return ` in {spaceOut(objective.Gamemode)}`
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function QuestLibrary.getQuest(questId: string): Quests.Quest?
	return questsById[questId]
end

function QuestLibrary.getPool(poolName: string): Quests.Pool?
	return Quests.Pools[poolName]
end

-- // Pool names in display order
function QuestLibrary.getPoolNames(): { string }
	return table.clone(poolNames)
end

function QuestLibrary.getQuestsInPool(poolName: string): { Quests.Quest }
	return questsByPool[poolName] or {}
end

-- // The quest's own reward, else its pool's
function QuestLibrary.getReward(quest: Quests.Quest): RewardLibrary.Reward
	return quest.Reward or Quests.Pools[quest.Pool].Reward
end

-- // What the player has to do, e.g. "Eliminate 5 opponents"
function QuestLibrary.getText(quest: Quests.Quest): string
	if quest.Text then
		return quest.Text
	end
	local objective = quest.Objective
	local goal = objective.Goal
	local suffix = getGamemodeSuffix(objective)
	if objective.Type == "Eliminations" then
		return `Eliminate {goal} {plural(goal, "opponent")}{suffix}`
	elseif objective.Type == "Wins" then
		return `Win {goal} {plural(goal, "round")}{suffix}`
	elseif objective.Type == "RoundsPlayed" then
		return `Play {goal} {plural(goal, "round")}{suffix}`
	elseif objective.Type == "MinutesPlayed" then
		return `Play for {goal} {plural(goal, "minute")}`
	elseif objective.Type == "Throws" then
		return `Throw {goal} {plural(goal, "time")}`
	elseif objective.Type == "AbilityUses" then
		local abilityId = objective.AbilityId or "an ability"
		if abilityId == "Dash" then
			return `Dash {goal} {plural(goal, "time")}`
		elseif abilityId == "Stab" then
			return `Stab {goal} {plural(goal, "time")}`
		end
		return `Use {spaceOut(abilityId)} {goal} {plural(goal, "time")}`
	elseif objective.Type == "Pickups" then
		if objective.PickupId then
			return `Collect {goal} {spaceOut(objective.PickupId)} {plural(goal, "pickup")}`
		end
		return `Collect {goal} {plural(goal, "pickup")}`
	elseif objective.Type == "PickupUses" then
		return `Use {spaceOut(objective.PickupId or "a pickup")} {goal} {plural(goal, "time")}`
	end
	return quest.Id
end

function QuestLibrary.isComplete(slot: QuestSlot): boolean
	local quest = questsById[slot.Id]
	return quest ~= nil and slot.Progress >= quest.Objective.Goal
end

function QuestLibrary.isClaimable(slot: QuestSlot): boolean
	return not slot.Claimed and QuestLibrary.isComplete(slot)
end

-- // Whether a quest can be swapped for another (T-147): any quest whose reward hasn't been claimed yet
function QuestLibrary.canReroll(slot: QuestSlot): boolean
	return not slot.Claimed
end

-- // Which period a time falls in, for a reset period: quests drawn in another period are replaced.
-- // Day: "D20390" (days since 1970-01-01 UTC). Week: "W2913" (Monday-to-Sunday weeks, UTC). Never: "".
function QuestLibrary.getPeriodKey(resetPeriod: Quests.ResetPeriod, now: number?): string
	local day = math.floor((now or os.time()) / SECONDS_IN_DAY)
	if resetPeriod == "Day" then
		return `D{day}`
	elseif resetPeriod == "Week" then
		return `W{math.floor((day + WEEK_START_OFFSET_DAYS) / DAYS_IN_WEEK)}`
	end
	return ""
end

-- // When the current period ends (Unix time), or nil if it never resets
function QuestLibrary.getPeriodEnd(resetPeriod: Quests.ResetPeriod, now: number?): number?
	local day = math.floor((now or os.time()) / SECONDS_IN_DAY)
	if resetPeriod == "Day" then
		return (day + 1) * SECONDS_IN_DAY
	elseif resetPeriod == "Week" then
		local week = math.floor((day + WEEK_START_OFFSET_DAYS) / DAYS_IN_WEEK)
		return ((week + 1) * DAYS_IN_WEEK - WEEK_START_OFFSET_DAYS) * SECONDS_IN_DAY
	end
	return nil
end

return QuestLibrary
