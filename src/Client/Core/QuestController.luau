--[[
	QuestController

	Description:
	Client side of quests: the local player's current quests (from the replicated profile's `Quests`, written by
	QuestService on the server) and claim requests. The server decides everything; this only reads and asks.
]]

local QuestController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local QuestLibrary = require(ReplicatedStorage.Shared.Library.QuestLibrary)
local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimQuestFunction = SimpleRemotes.getFunction("ClaimQuest")
local reserveQuestRerollFunction = SimpleRemotes.getFunction("ReserveQuestReroll")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // The local player's quests changed (new quests, progress, a claim)
QuestController.QuestsChangedTasks = TasksList.new() :: TasksList.TasksList<() -> ()>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The local player's saved state for a pool, or nil before it's loaded
function QuestController.getPoolData(poolName: string): QuestLibrary.PoolData?
	local data = PlayerDataController.get()
	local quests = data and (data :: any).Quests
	return quests and quests[poolName]
end

-- // Whether any quest is finished and waiting to be claimed
function QuestController.hasClaimable(): boolean
	for _, poolName in QuestLibrary.getPoolNames() do
		local poolData = QuestController.getPoolData(poolName)
		for _, slot in (poolData and poolData.Slots) or {} do
			if QuestLibrary.isClaimable(slot) then
				return true
			end
		end
	end
	return false
end

--- Asks the server for a finished quest's reward. Yields; returns whether it was granted.
function QuestController.claim(poolName: string, slotIndex: number): boolean
	return claimQuestFunction:InvokeServer(poolName, slotIndex) == true
end

--- Buying a reroll for this quest. The server first reserves the quest (it stops counting progress), then the
--- QuestReroll purchase prompt opens; the server swaps the quest when the purchase goes through. Yields until the
--- prompt is answered; returns whether it was bought.
function QuestController.reroll(poolName: string, slotIndex: number): boolean
	if reserveQuestRerollFunction:InvokeServer(poolName, slotIndex) ~= true then
		return false
	end
	return MarketplaceLibrary.promptDeveloperProduct("QuestReroll", nil, true) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function QuestController.init() end

function QuestController.start()
	PlayerDataController.UpdatedTasks:Add(function(index, _value, path)
		if index == "Quests" or (path and path[1] == "Quests") then
			QuestController.QuestsChangedTasks:Execute("parallel")
		end
	end)
end

return QuestController
