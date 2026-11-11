-- Cosmetic ownership and what each player has equipped. Each category's equipped item id lives in a player
-- attribute (Shared.Cosmetics: EquippedSkin, EquippedTaunt, EquippedArrow, EquippedKillEffect), so every client can
-- see it (e.g. to render other players' boomerangs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))

local Inventory = {}

-- TODO: real ownership once there's a data store; see Cosmetics.ownedByDefault.
function Inventory.owns(_player: Player, categoryId: string, itemId: string): boolean
	local category = Cosmetics.byId[categoryId]
	local item = category and category.byId[itemId]
	return item ~= nil and Cosmetics.ownedByDefault(item)
end

function Inventory.equipped(player: Player, categoryId: string): string?
	local category = Cosmetics.byId[categoryId]
	if not category then
		return nil
	end
	return player:GetAttribute(category.attribute) or category.default
end

function Inventory.equip(player: Player, categoryId: string, itemId: string): boolean
	if not Inventory.owns(player, categoryId, itemId) then
		return false
	end
	player:SetAttribute(Cosmetics.byId[categoryId].attribute, itemId)
	return true
end

function Inventory.start()
	local function init(player: Player)
		for _, category in Cosmetics.list do
			if player:GetAttribute(category.attribute) == nil then
				player:SetAttribute(category.attribute, category.default)
			end
		end
	end
	Players.PlayerAdded:Connect(init)
	for _, player in Players:GetPlayers() do
		init(player)
	end

	Remotes.event(Remotes.Equip).OnServerEvent:Connect(function(player: Player, categoryId: unknown, itemId: unknown)
		-- Remote arguments come from the client; accept only ids of an item the player owns.
		if typeof(categoryId) ~= "string" or typeof(itemId) ~= "string" then
			return
		end
		Inventory.equip(player, categoryId, itemId)
	end)
end

return Inventory
