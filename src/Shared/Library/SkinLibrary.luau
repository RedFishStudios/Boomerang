--[[
	SkinLibrary

	Description:
	Shared helpers for boomerang skins (Shared/Referential/Skins). Works out any player's equipped skin,
	model and weapon class from the `EquippedSkin` attribute that SkinService sets on the Player.
	Safe to use on both server and client.
]]

local SkinLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Referential.Skins)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

SkinLibrary.ATTRIBUTE_NAME = "EquippedSkin"

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local defaultSkinId: string = "ClassicBoomerang"
for skinId, skin in Skins do
	if skin.Default then
		defaultSkinId = skinId
		break
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinLibrary.getSkin(skinId: string?): Skins.Skin?
	return if skinId then Skins[skinId] else nil
end

function SkinLibrary.getDefaultSkinId(): string
	return defaultSkinId
end

-- // Skin ids sorted by their Order
function SkinLibrary.getSortedSkinIds(): { string }
	local skinIds = {}
	for skinId in Skins do
		table.insert(skinIds, skinId)
	end
	table.sort(skinIds, function(a, b)
		return Skins[a].Order < Skins[b].Order
	end)
	return skinIds
end

-- // Whether this saved data owns the skin (default skins are always owned)
function SkinLibrary.dataOwnsSkin(data: { OwnedSkins: { [string]: boolean } }?, skinId: string): boolean
	local skin = Skins[skinId]
	if not skin then
		return false
	end
	if skin.Default then
		return true
	end
	return data ~= nil and data.OwnedSkins ~= nil and data.OwnedSkins[skinId] == true
end

function SkinLibrary.getEquippedSkinId(player: Player): string
	local skinId = player:GetAttribute(SkinLibrary.ATTRIBUTE_NAME)
	if type(skinId) == "string" and Skins[skinId] then
		return skinId
	end
	return defaultSkinId
end

-- // The weapon class (stats id in Shared/Constants/Tools) the player throws, or nil when weapons are off
function SkinLibrary.getWeaponClass(player: Player): string?
	if GlobalConfig.ForceEquippedTool == nil then
		return nil
	end
	return Skins[SkinLibrary.getEquippedSkinId(player)].WeaponClass
end

-- // The model name (in Shared/Assets/Tools) the player holds and throws, or nil when weapons are off
function SkinLibrary.getModelName(player: Player): string?
	if GlobalConfig.ForceEquippedTool == nil then
		return nil
	end
	return Skins[SkinLibrary.getEquippedSkinId(player)].Model
end

return SkinLibrary
