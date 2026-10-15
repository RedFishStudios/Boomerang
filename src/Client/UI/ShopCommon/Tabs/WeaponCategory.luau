--[[
	WeaponCategory tab (Weapons Shop)

	Description:
	Builds a Weapons Shop tab listing every skin on sale whose tool (Shared/Constants/Tools) has the given Category
	("Boomerang", "Fan" or "Shuriken"), in the order of the Inventory's Skins tab (SkinLibrary / SkinController, data in
	Shared/Referential/Skins). Skins that are off sale are left out by ShopListings. Scrolls past 6 listings.
	Follows the ShopTab shape in ShopCommon/ShopBuilder.
]]

local WeaponCategory = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopItems = require(ReplicatedStorage.Shared.Referential.ShopItems)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local SkinController = require(ReplicatedStorage.Client.Core.SkinController)

function WeaponCategory.create(category: Tools.ToolCategory)
	local tab = {}
	tab.Scrollable = true

	function tab.getListings(): { ShopItems.ShopListing }
		local listings = {}
		for _, skinId in SkinLibrary.getSortedSkinIds() do
			local skin = SkinLibrary.getSkin(skinId)
			local tool = skin and Tools[skin.Model]
			if tool and tool.Category == category then
				table.insert(listings, { Type = "Skin", Id = skinId })
			end
		end
		return listings
	end

	function tab.subscribe(onChanged: () -> ())
		SkinController.SkinGrantedTasks:Add(onChanged)
	end

	return tab
end

return WeaponCategory
