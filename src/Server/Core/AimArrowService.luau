--[[
	AimArrowService

	Description:
	Owns aim arrows on the server: granting, buying and equipping them (profile `OwnedAimArrows` / `EquippedAimArrow`).
	Publishes the equipped arrow as the `EquippedAimArrow` Player attribute (CosmeticLibrary), which replicates to every
	client so each one can render the other players' arrows. Same shape as SkinService.
	Aim arrow data: Shared/Referential/AimArrows.
]]

local AimArrowService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local AimArrowLibrary = require(ReplicatedStorage.Shared.Library.AimArrowLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type AimArrowTask = (player: Player, aimArrowId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipAimArrowRemoteFunction = SimpleRemotes.getFunction("EquipAimArrow")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

AimArrowService.AimArrowGrantedTasks = TasksList.new() :: TasksList.TasksList<AimArrowTask>
AimArrowService.AimArrowEquippedTasks = TasksList.new() :: TasksList.TasksList<AimArrowTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedAimArrow(player: Player, aimArrowId: string)
	CosmeticLibrary.setEquipped(player, "AimArrow", aimArrowId)
	AimArrowService.AimArrowEquippedTasks:Execute("parallel", player, aimArrowId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AimArrowService.ownsAimArrow(player: Player, aimArrowId: string): boolean
	return AimArrowLibrary.dataOwns(PlayerDataService.get(player), aimArrowId)
end

--- Gives the player an aim arrow. Returns false if it doesn't exist, the data isn't loaded, or it's already owned.
function AimArrowService.grantAimArrow(player: Player, aimArrowId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not AimArrowLibrary.getAimArrow(aimArrowId) or AimArrowLibrary.dataOwns(data, aimArrowId) then
		return false
	end

	data.OwnedAimArrows[aimArrowId] = true
	AimArrowService.AimArrowGrantedTasks:Execute("parallel", player, aimArrowId)
	return true
end

--- Buys an aim arrow with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function AimArrowService.purchaseAimArrow(player: Player, aimArrowId: string): boolean
	local aimArrow = AimArrowLibrary.getAimArrow(aimArrowId)
	if
		not aimArrow
		or aimArrow.OffSale
		or not PlayerDataService.get(player)
		or AimArrowService.ownsAimArrow(player, aimArrowId)
	then
		return false
	end

	if not EconomyService.spendCurrency(player, aimArrow.Price) then
		return false
	end

	return AimArrowService.grantAimArrow(player, aimArrowId)
end

--- Equips an owned aim arrow. Returns false if the player doesn't own it or the data isn't loaded.
function AimArrowService.equipAimArrow(player: Player, aimArrowId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not AimArrowLibrary.dataOwns(data, aimArrowId) then
		return false
	end

	if data.EquippedAimArrow ~= aimArrowId then
		data.EquippedAimArrow = aimArrowId
	end
	if CosmeticLibrary.getEquippedRaw(player, "AimArrow") ~= aimArrowId then
		applyEquippedAimArrow(player, aimArrowId)
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AimArrowService.init()
	equipAimArrowRemoteFunction.OnServerInvoke = function(player: Player, aimArrowId: unknown)
		if type(aimArrowId) ~= "string" then
			return false
		end
		return AimArrowService.equipAimArrow(player, aimArrowId)
	end

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved arrow no longer exists or isn't owned
		local aimArrowId = data.EquippedAimArrow
		if type(aimArrowId) ~= "string" or not AimArrowLibrary.dataOwns(data, aimArrowId) then
			aimArrowId = AimArrowLibrary.getDefaultId()
			data.EquippedAimArrow = aimArrowId
		end
		applyEquippedAimArrow(player, aimArrowId)
	end)
end

function AimArrowService.start() end

return AimArrowService
