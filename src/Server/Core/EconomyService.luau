--[[
	EconomyService

	Description:
	Handles server-side economy operations. The game has a single currency: the profile's `Currency` number.

	Author:
	@SixthAtom
]]

local EconomyService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type CurrencyChangedTask = (player: Player, newBalance: number, delta: number) -> ()

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EconomyService.CurrencyChangedTasks = TasksList.new() :: TasksList.TasksList<CurrencyChangedTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Returns the player's Currency, or nil if their data isn't loaded.
function EconomyService.getBalance(player: Player): number?
	local data = PlayerDataService.get(player)
	if not data then
		return nil
	end

	return data.Currency or 0
end

--- Returns true if the player's data is loaded and they have at least `amount` Currency.
function EconomyService.canAfford(player: Player, amount: number): boolean
	local balance = EconomyService.getBalance(player)
	return balance ~= nil and balance >= amount
end

--- Adds (or, with a negative amount, removes) Currency. The balance never goes below 0.
--- Returns false if the player's data isn't loaded.
function EconomyService.addCurrency(player: Player, amount: number): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end

	local oldBalance = data.Currency or 0
	local newBalance = math.max(0, oldBalance + amount)
	data.Currency = newBalance -- // Writes go through the data proxy, which replicates them to the client

	EconomyService.CurrencyChangedTasks:Execute("parallel", player, newBalance, newBalance - oldBalance)
	return true
end

--- Removes `amount` Currency only if the player can afford it. Returns true if it was spent.
function EconomyService.spendCurrency(player: Player, amount: number): boolean
	if amount < 0 then
		return false
	end

	if not EconomyService.canAfford(player, amount) then
		return false
	end

	return EconomyService.addCurrency(player, -amount)
end

return EconomyService
