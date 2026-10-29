--[[
	QuestController (T-143)

	Description:
	Client side of quests: the local player's current quests (from the replicated profile's `Quests`, written by
	QuestService on the server) and claim requests. The server decides everything; this only reads and asks.
]]

local QuestController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local QuestLibrary = require(ReplicatedStorage.Shared.Library.QuestLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local claimQuestFunction = SimpleRemotes.getFunction("ClaimQuest")
local rerollQuestFunction = SimpleRemotes.getFunction("RerollQuest")

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

--- T-147: asks the server to swap this quest (in place) for another. Free for now. Yields; returns whether it was swapped.
function QuestController.reroll(poolName: string, slotIndex: number): boolean
	return rerollQuestFunction:InvokeServer(poolName, slotIndex) == true
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
