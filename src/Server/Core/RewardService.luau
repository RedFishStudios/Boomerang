--[[
	RewardService (T-143)

	Description:
	Grants a reward (RewardLibrary.Reward) to a player: currency, a skin, an aim arrow (charge up effect), an emote or
	an item. Shared by everything that hands out rewards (quests today). A cosmetic the player already owns becomes its
	FallbackCurrency instead. The client learns about it through data replication, like any other purchase or grant.
]]

local RewardService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RewardLibrary = require(ReplicatedStorage.Shared.Library.RewardLibrary)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local SkinService = require(ServerStorage.Server.Core.SkinService)
local ChargeUpEffectService = require(ServerStorage.Server.Core.ChargeUpEffectService)
local EmoteService = require(ServerStorage.Server.Core.EmoteService)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // A cosmetic: grant it, or its FallbackCurrency if already owned. Returns (granted, convertedToCurrency)
local function grantCosmetic(player: Player, owns: boolean, grant: () -> boolean, fallbackCurrency: number?): (boolean, boolean)
	if owns then
		if fallbackCurrency and fallbackCurrency > 0 then
			return EconomyService.addCurrency(player, fallbackCurrency), true
		end
		return true, false -- // Nothing to give, but nothing went wrong either
	end
	return grant(), false
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Gives the reward to the player. Returns whether it worked, and whether a cosmetic they already owned was turned into
--- its FallbackCurrency.
function RewardService.grant(player: Player, reward: RewardLibrary.Reward): (boolean, boolean)
	if not RewardLibrary.isValid(reward) then
		warn(`RewardService: invalid reward for {player.Name}`, reward)
		return false, false
	end

	if reward.Type == "Currency" then
		return EconomyService.addCurrency(player, reward.Value), false
	elseif reward.Type == "Skin" then
		return grantCosmetic(player, SkinService.ownsSkin(player, reward.Value), function()
			return SkinService.grantSkin(player, reward.Value)
		end, reward.FallbackCurrency)
	elseif reward.Type == "ChargeUpEffect" then
		return grantCosmetic(player, ChargeUpEffectService.ownsChargeUpEffect(player, reward.Value), function()
			return ChargeUpEffectService.grantChargeUpEffect(player, reward.Value)
		end, reward.FallbackCurrency)
	elseif reward.Type == "Emote" then
		return grantCosmetic(player, EmoteService.ownsEmote(player, reward.Value), function()
			return EmoteService.grantEmote(player, reward.Value)
		end, reward.FallbackCurrency)
	elseif reward.Type == "Item" then
		return ItemService.grantItem(player, reward.Value, reward.Amount or 1), false
	end
	return false, false
end

function RewardService.init() end
function RewardService.start() end

return RewardService
