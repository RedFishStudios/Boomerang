--[[
	SkinService

	Description:
	Owns boomerang skins on the server: granting, buying and equipping them (profile `OwnedSkins` / `EquippedSkin`).
	Sets the `EquippedSkin` Player attribute that SkinLibrary reads on both sides, and fires SkinEquippedTasks
	so WeaponService can swap the held model. Skin data: Shared/Referential/Skins.
]]

local SkinService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type SkinTask = (player: Player, skinId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipSkinRemoteFunction = SimpleRemotes.getFunction("EquipSkin")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SkinService.SkinGrantedTasks = TasksList.new() :: TasksList.TasksList<SkinTask>
SkinService.SkinEquippedTasks = TasksList.new() :: TasksList.TasksList<SkinTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedSkin(player: Player, skinId: string)
	player:SetAttribute(SkinLibrary.ATTRIBUTE_NAME, skinId)
	SkinService.SkinEquippedTasks:Execute("parallel", player, skinId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinService.ownsSkin(player: Player, skinId: string): boolean
	return SkinLibrary.dataOwnsSkin(PlayerDataService.get(player), skinId)
end

--- Gives the player a skin. Returns false if the skin doesn't exist, the data isn't loaded, or it's already owned.
function SkinService.grantSkin(player: Player, skinId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not SkinLibrary.getSkin(skinId) or SkinLibrary.dataOwnsSkin(data, skinId) then
		return false
	end

	data.OwnedSkins[skinId] = true
	SkinService.SkinGrantedTasks:Execute("parallel", player, skinId)
	return true
end

--- Buys a skin with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function SkinService.purchaseSkin(player: Player, skinId: string): boolean
	local skin = SkinLibrary.getSkin(skinId)
	if not skin or skin.OffSale or not PlayerDataService.get(player) or SkinService.ownsSkin(player, skinId) then
		return false
	end

	if not EconomyService.spendCurrency(player, skin.Price) then
		return false
	end

	return SkinService.grantSkin(player, skinId)
end

--- Equips an owned skin. Returns false if the player doesn't own it or the data isn't loaded.
function SkinService.equipSkin(player: Player, skinId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not SkinLibrary.dataOwnsSkin(data, skinId) then
		return false
	end

	if data.EquippedSkin ~= skinId then
		data.EquippedSkin = skinId
	end
	if player:GetAttribute(SkinLibrary.ATTRIBUTE_NAME) ~= skinId then
		applyEquippedSkin(player, skinId)
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SkinService.init()
	equipSkinRemoteFunction.OnServerInvoke = function(player: Player, skinId: unknown)
		if type(skinId) ~= "string" then
			return false
		end
		return SkinService.equipSkin(player, skinId)
	end

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved skin no longer exists or isn't owned
		local skinId = data.EquippedSkin
		if type(skinId) ~= "string" or not SkinLibrary.dataOwnsSkin(data, skinId) then
			skinId = SkinLibrary.getDefaultSkinId()
			data.EquippedSkin = skinId
		end
		applyEquippedSkin(player, skinId)
	end)
end

function SkinService.start() end

return SkinService
