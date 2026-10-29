--[[
	RewardLibrary (T-143)

	Description:
	The shared shape of a reward, for anything that hands one out (quests today; daily rewards, events and achievements
	can use it too). Granting happens on the server (RewardService.grant); this module only describes rewards, so the
	client can show them.

	A cosmetic the player already owns turns into its FallbackCurrency instead (0 or nil = nothing).
]]

local RewardLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skins = require(ReplicatedStorage.Shared.Referential.Skins)
local ChargeUpEffects = require(ReplicatedStorage.Shared.Referential.ChargeUpEffects)
local Emotes = require(ReplicatedStorage.Shared.Referential.Emotes)
local Items = require(ReplicatedStorage.Shared.Referential.Items)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CurrencyReward = {
	Type: "Currency",
	Value: number,
}

-- // A boomerang skin (also how alternate weapons are given: a skin's WeaponClass decides the weapon)
export type SkinReward = {
	Type: "Skin",
	Value: string, -- // Skin id (Shared/Referential/Skins)
	FallbackCurrency: number?,
}

-- // An aim arrow
export type ChargeUpEffectReward = {
	Type: "ChargeUpEffect",
	Value: string, -- // Charge up effect id (Shared/Referential/ChargeUpEffects)
	FallbackCurrency: number?,
}

export type EmoteReward = {
	Type: "Emote",
	Value: string, -- // Emote id (Shared/Referential/Emotes)
	FallbackCurrency: number?,
}

export type ItemReward = {
	Type: "Item",
	Value: string, -- // Item id (Shared/Referential/Items)
	Amount: number?, -- // Default 1
}

export type Reward = CurrencyReward | SkinReward | ChargeUpEffectReward | EmoteReward | ItemReward

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Short text for a reward, e.g. "100" (currency) or "Shuriken" (a skin)
function RewardLibrary.getText(reward: Reward): string
	if reward.Type == "Currency" then
		return tostring(reward.Value)
	elseif reward.Type == "Skin" then
		local skin = Skins[reward.Value]
		return if skin then skin.Name else reward.Value
	elseif reward.Type == "ChargeUpEffect" then
		local chargeUpEffect = ChargeUpEffects[reward.Value]
		return if chargeUpEffect then chargeUpEffect.Name else reward.Value
	elseif reward.Type == "Emote" then
		local emote = Emotes[reward.Value]
		return if emote then emote.Name else reward.Value
	elseif reward.Type == "Item" then
		local item = (Items :: any)[reward.Value]
		local name = if item then item.Name else reward.Value
		local amount = reward.Amount or 1
		return if amount > 1 then `{amount}x {name}` else name
	end
	return "?"
end

-- // Whether a value from data or a definition is a usable reward (the server checks before granting)
function RewardLibrary.isValid(reward: any): boolean
	if type(reward) ~= "table" or type(reward.Type) ~= "string" then
		return false
	end
	if reward.Type == "Currency" then
		return type(reward.Value) == "number" and reward.Value > 0
	elseif reward.Type == "Skin" then
		return Skins[reward.Value] ~= nil
	elseif reward.Type == "ChargeUpEffect" then
		return ChargeUpEffects[reward.Value] ~= nil
	elseif reward.Type == "Emote" then
		return Emotes[reward.Value] ~= nil
	elseif reward.Type == "Item" then
		return (Items :: any)[reward.Value] ~= nil
	end
	return false
end

return RewardLibrary
