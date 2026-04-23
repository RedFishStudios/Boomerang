--[[
  EconomyController

  Description:
  Handles the economy on the client

  Author:
  @SixthAtom

  Date:
  16-04-2026
]]

local EconomyController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local EconomyConstants = require(ReplicatedStorage.Shared.Constants.EconomyConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CurrencyChangedTask = (currency: EconomyConstants.Currency, newAmount: number) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local function getPlayerCurrencies()
	return PlayerDataController.get().Currencies
end

local function getPlayerBalance(currency: EconomyConstants.Currency)
	return getPlayerCurrencies()[currency]
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EconomyController.CurrencyChangedTasks = TasksList.new() :: TasksList.Id<CurrencyChangedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.canAfford(price: EconomyConstants.Price)
	if not EconomyConstants.isLiquid(price.Currency) then
		return true
	end

	return getPlayerBalance(price.Currency) >= price.Amount
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EconomyController.init()
	PlayerDataController.UpdatedTasks:Add(function(index: number | string, value, path: { number | string })
		if path[1] == "Currencies" then
			EconomyController.CurrencyChangedTasks:Execute("parallel", index, value)
		end
	end)
end

function EconomyController.start() end

function EconomyController.test() end

return EconomyController
