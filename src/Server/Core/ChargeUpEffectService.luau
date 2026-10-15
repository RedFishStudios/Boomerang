--[[
	ChargeUpEffectService

	Description:
	Owns charge up effects on the server: granting, buying and equipping them (profile `OwnedChargeUpEffects` / `EquippedChargeUpEffect`).
	Publishes the equipped arrow as the `EquippedChargeUpEffect` Player attribute (CosmeticLibrary), which replicates to every
	client so each one can render the other players' arrows. Same shape as SkinService.
	Charge up effect data: Shared/Referential/ChargeUpEffects.
]]

local ChargeUpEffectService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ChargeUpEffectTask = (player: Player, chargeUpEffectId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipChargeUpEffectRemoteFunction = SimpleRemotes.getFunction("EquipChargeUpEffect")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ChargeUpEffectService.ChargeUpEffectGrantedTasks = TasksList.new() :: TasksList.TasksList<ChargeUpEffectTask>
ChargeUpEffectService.ChargeUpEffectEquippedTasks = TasksList.new() :: TasksList.TasksList<ChargeUpEffectTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedChargeUpEffect(player: Player, chargeUpEffectId: string)
	CosmeticLibrary.setEquipped(player, "ChargeUpEffect", chargeUpEffectId)
	ChargeUpEffectService.ChargeUpEffectEquippedTasks:Execute("parallel", player, chargeUpEffectId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ChargeUpEffectService.ownsChargeUpEffect(player: Player, chargeUpEffectId: string): boolean
	return ChargeUpEffectLibrary.dataOwns(PlayerDataService.get(player), chargeUpEffectId)
end

--- Gives the player a charge up effect. Returns false if it doesn't exist, the data isn't loaded, or it's already owned.
function ChargeUpEffectService.grantChargeUpEffect(player: Player, chargeUpEffectId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not ChargeUpEffectLibrary.getChargeUpEffect(chargeUpEffectId) or ChargeUpEffectLibrary.dataOwns(data, chargeUpEffectId) then
		return false
	end

	data.OwnedChargeUpEffects[chargeUpEffectId] = true
	ChargeUpEffectService.ChargeUpEffectGrantedTasks:Execute("parallel", player, chargeUpEffectId)
	return true
end

--- Buys a charge up effect with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function ChargeUpEffectService.purchaseChargeUpEffect(player: Player, chargeUpEffectId: string): boolean
	local chargeUpEffect = ChargeUpEffectLibrary.getChargeUpEffect(chargeUpEffectId)
	if
		not chargeUpEffect
		or chargeUpEffect.OffSale
		or not PlayerDataService.get(player)
		or ChargeUpEffectService.ownsChargeUpEffect(player, chargeUpEffectId)
	then
		return false
	end

	if not EconomyService.spendCurrency(player, chargeUpEffect.Price) then
		return false
	end

	return ChargeUpEffectService.grantChargeUpEffect(player, chargeUpEffectId)
end

--- Equips an owned charge up effect. Returns false if the player doesn't own it or the data isn't loaded.
function ChargeUpEffectService.equipChargeUpEffect(player: Player, chargeUpEffectId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not ChargeUpEffectLibrary.dataOwns(data, chargeUpEffectId) then
		return false
	end

	if data.EquippedChargeUpEffect ~= chargeUpEffectId then
		data.EquippedChargeUpEffect = chargeUpEffectId
	end
	if CosmeticLibrary.getEquippedRaw(player, "ChargeUpEffect") ~= chargeUpEffectId then
		applyEquippedChargeUpEffect(player, chargeUpEffectId)
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ChargeUpEffectService.init()
	equipChargeUpEffectRemoteFunction.OnServerInvoke = function(player: Player, chargeUpEffectId: unknown)
		if type(chargeUpEffectId) ~= "string" then
			return false
		end
		return ChargeUpEffectService.equipChargeUpEffect(player, chargeUpEffectId)
	end

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved arrow no longer exists or isn't owned
		local chargeUpEffectId = data.EquippedChargeUpEffect
		if type(chargeUpEffectId) ~= "string" or not ChargeUpEffectLibrary.dataOwns(data, chargeUpEffectId) then
			chargeUpEffectId = ChargeUpEffectLibrary.getDefaultId()
			data.EquippedChargeUpEffect = chargeUpEffectId
		end
		applyEquippedChargeUpEffect(player, chargeUpEffectId)
	end)
end

function ChargeUpEffectService.start() end

return ChargeUpEffectService
