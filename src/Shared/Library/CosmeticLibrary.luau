--[[
	CosmeticLibrary

	Description:
	The shared home of the "equipped cosmetic" Player attributes, one per cosmetic category (boomerang skins, aim
	arrows...). The server writes a player's equipped id for each category as a Player attribute, which Roblox
	replicates to every client, so each client always knows every other player's equipped cosmetics from one place
	(including players who join late) without any extra remote. Clients can't write another player's attributes
	to the server, and every reader validates the id against its category's data (SkinLibrary, ChargeUpEffectLibrary),
	so a missing or unknown value falls back to the category's default.
	To add a category: add its attribute below, then build its own Library / Service / Controller like ChargeUpEffects.
	Safe to use on both server and client.
]]

local CosmeticLibrary = {}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Category = "Skin" | "ChargeUpEffect" | "WinningEmote" | "ElimEffect"

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Category -> Player attribute holding the player's equipped id. These names are shared by the server and clients.
CosmeticLibrary.ATTRIBUTES = {
	Skin = "EquippedSkin",
	ChargeUpEffect = "EquippedChargeUpEffect",
	WinningEmote = "EquippedWinningEmote",
	ElimEffect = "EquippedElimEffect",
} :: { [Category]: string }

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- The raw equipped id of a player for a category, or nil when it isn't set (yet). Not validated: use the category's
--- Library (SkinLibrary.getEquippedSkinId, ChargeUpEffectLibrary.getEquippedId) for a usable id.
function CosmeticLibrary.getEquippedRaw(player: Player, category: Category): string?
	local value = player:GetAttribute(CosmeticLibrary.ATTRIBUTES[category])
	return if type(value) == "string" then value else nil
end

--- Server only: sets a player's equipped id for a category (replicates to every client).
function CosmeticLibrary.setEquipped(player: Player, category: Category, id: string)
	player:SetAttribute(CosmeticLibrary.ATTRIBUTES[category], id)
end

--- Calls `callback` whenever a player's equipped id for a category changes. Returns a disconnect function.
function CosmeticLibrary.observe(player: Player, category: Category, callback: (id: string?) -> ()): () -> ()
	local connection = player:GetAttributeChangedSignal(CosmeticLibrary.ATTRIBUTES[category]):Connect(function()
		callback(CosmeticLibrary.getEquippedRaw(player, category))
	end)
	return function()
		connection:Disconnect()
	end
end

return CosmeticLibrary
