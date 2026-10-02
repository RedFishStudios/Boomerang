--[[
	EconomyController

	Description:
	Handles the economy on the client. The game has a single currency: the profile's `Currency` number.

	Author:
	@SixthAtom
]]

local EconomyController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CurrencyChangedTask = (newBalance: number) -> ()

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EconomyController.CurrencyChangedTasks = TasksList.new() :: TasksList.TasksList<CurrencyChangedTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.getBalance(): number
	local data = PlayerDataController.get()
	return if data then data.Currency or 0 else 0
end

function EconomyController.canAfford(amount: number): boolean
	return EconomyController.getBalance() >= amount
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.init()
	PlayerDataController.UpdatedTasks:Add(function(index: number | string, value, path: { number | string })
		if #path == 0 and index == "Currency" then
			EconomyController.CurrencyChangedTasks:Execute("parallel", value)
		end
	end)
end

return EconomyController
