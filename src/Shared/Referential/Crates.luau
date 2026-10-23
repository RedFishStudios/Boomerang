--[[
	Crates (T-112)

	Description:
	The weapon crates sold in the Weapons Shop, one per weapon category (Shared/Constants/Tools Category). Buying a crate
	gives a random weapon of that category: each tool's CrateWeight (Tools) is its weighted chance, and the player gets
	the skin whose Model is that tool (Shared/Referential/Skins). The roll happens on the server (CrateService).
	Crate ids are sent over the network: don't reuse one for something else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

export type CrateId = string

export type Crate = {
	Name: string,
	Category: Tools.ToolCategory, -- // The weapons it can give
	Price: number, -- // Currency price
	Order: number, -- // Display order in the Weapons Shop
	Model: string, -- // Model in Shared/Assets/Crates shown in the shop listing
	ViewportRotation: CFrame?, -- // How the model is posed in the listing (the camera looks along -Z and is fitted automatically)
	OffSale: true?,
}

local Crates: { [CrateId]: Crate } = {
	BoomerangCrate = {
		Name = "Boomerang Crate",
		Category = "Boomerang",
		Price = 250, -- TODO:RELEASE placeholder
		Order = 1,
		Model = "GenericCrate", -- TODO:RELEASE placeholder (the same generic crate for every category)
		ViewportRotation = CFrame.Angles(0, math.rad(-30), 0),
	},
	ShurikenCrate = {
		Name = "Shuriken Crate",
		Category = "Shuriken",
		Price = 250, -- TODO:RELEASE placeholder
		Order = 2,
		Model = "GenericCrate", -- TODO:RELEASE placeholder (the same generic crate for every category)
		ViewportRotation = CFrame.Angles(0, math.rad(-30), 0),
	},
	FanCrate = {
		Name = "Fan Crate",
		Category = "Fan",
		Price = 250, -- TODO:RELEASE placeholder
		Order = 3,
		Model = "GenericCrate", -- TODO:RELEASE placeholder (the same generic crate for every category)
		ViewportRotation = CFrame.Angles(0, math.rad(-30), 0),
	},
}

return Crates
