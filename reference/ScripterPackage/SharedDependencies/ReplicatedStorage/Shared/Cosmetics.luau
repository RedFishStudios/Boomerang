-- Cosmetic catalog, one entry per Inventory tab. Add an item here (and its art to Shared.Assets) and it shows up
-- in the Inventory screen. Each category's equipped item id lives in a player attribute set by Server.Inventory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"

export type Item = {
	id: string,
	name: string,
	rarity: Rarity,
	image: string,
	source: string?, -- set for items you don't start with, e.g. "Garbage Egg"; shown in the Index
	effect: string?, -- Kill Effects only: which effect Client.KillEffects plays ("Stone", "Ashes"); nil = plain death
	taunt: string?, -- Taunts only: which taunt Client.Taunts plays ("TooEasy", "Bonk", "RoyalTreatment", "NapTime")
}

export type Category = {
	id: string, -- also the tab name
	attribute: string, -- player attribute holding the equipped item id
	default: string, -- item everyone starts with
	items: { Item },
	byId: { [string]: Item },
}

local Cosmetics = {}

-- Only Bronzeguin's rarity comes from the mockup; the rest are placeholders.
Cosmetics.list = {
	{
		id = "Skins",
		attribute = "EquippedSkin",
		default = "Default",
		items = {
			{ id = "Bronzeguin", name = "Bronzeguin", rarity = "Common", image = Assets.Skins.Bronzeguin },
			{ id = "Default", name = "Default", rarity = "Common", image = Assets.Skins.Default },
			{ id = "Chubby", name = "Chubby", rarity = "Common", image = Assets.Skins.Chubby },
			-- From the Garbage Egg in the Shop (rarity follows the egg odds: 61 / 29 / 9 / 1 %).
			{
				id = "PaperMecha",
				name = "Paper Mecha",
				rarity = "Common",
				image = Assets.Skins.PaperMecha,
				source = "Garbage Egg",
			},
			{
				id = "LunchBagSpy",
				name = "Lunch Bag Spy",
				rarity = "Rare",
				image = Assets.Skins.LunchBagSpy,
				source = "Garbage Egg",
			},
			{ id = "CptRed", name = "Cpt. Red", rarity = "Epic", image = Assets.Skins.CptRed, source = "Garbage Egg" },
			{
				id = "ParaBottler",
				name = "Para Bottler",
				rarity = "Legendary",
				image = Assets.Skins.ParaBottler,
				source = "Garbage Egg",
			},
		},
	},
	{
		id = "Taunts",
		attribute = "EquippedTaunt",
		default = "TooEasy",
		-- Card art is placeholder (Assets.Taunts).
		items = {
			{ id = "TooEasy", name = "Too Easy", rarity = "Common", image = Assets.Taunts.Laugh, taunt = "TooEasy" },
			{ id = "Bonk", name = "Bonk!", rarity = "Rare", image = Assets.Taunts.Dance, taunt = "Bonk" },
			{
				id = "RoyalTreatment",
				name = "Royal Treatment",
				rarity = "Epic",
				image = Assets.Taunts.Flex,
				taunt = "RoyalTreatment",
			},
			{ id = "NapTime", name = "Nap Time", rarity = "Legendary", image = Assets.Taunts.Laugh, taunt = "NapTime" },
		},
	},
	{
		id = "Arrows",
		attribute = "EquippedArrow",
		default = "Classic",
		items = {
			{ id = "Classic", name = "Classic", rarity = "Common", image = Assets.Arrows.Classic },
			{ id = "Gold", name = "Gold", rarity = "Rare", image = Assets.Arrows.Gold },
			{ id = "Frost", name = "Frost", rarity = "Epic", image = Assets.Arrows.Frost },
		},
	},
	{
		id = "KillEffects",
		attribute = "EquippedKillEffect",
		default = "Skull",
		items = {
			-- Skull is the plain Roblox death (no effect).
			{ id = "Skull", name = "Skull", rarity = "Common", image = Assets.KillEffects.Skull },
			{
				id = "Stone",
				name = "Stone Statue",
				rarity = "Rare",
				image = Assets.KillEffects.Stone,
				effect = "Stone",
			},
			{ id = "Ashes", name = "Ashes", rarity = "Epic", image = Assets.KillEffects.Ashes, effect = "Ashes" },
			{ id = "Sakura", name = "Sakura", rarity = "Epic", image = Assets.KillEffects.Sakura, effect = "Sakura" },
			{
				id = "Shark",
				name = "Shark Attack",
				rarity = "Legendary",
				image = Assets.KillEffects.Shark,
				effect = "Shark",
			},
		},
	},
} :: { Category }

-- TODO: real ownership once there's a data store. For now everyone owns every item except ones that come from
-- somewhere (eggs etc.). Server.Inventory uses the same rule.
function Cosmetics.ownedByDefault(item: Item): boolean
	return item.source == nil
end

Cosmetics.byId = {} :: { [string]: Category }
for _, category in Cosmetics.list do
	category.byId = {}
	for _, item in category.items do
		category.byId[item.id] = item
	end
	Cosmetics.byId[category.id] = category
end

return Cosmetics
