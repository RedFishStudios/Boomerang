-- // QuestReroll developer product: rerolls the quest the player reserved (see QuestService)

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceLibrary = require(ReplicatedStorage.Shared.Library.MarketplaceLibrary)
local QuestService = require(ServerStorage.Server.Core.QuestService)

local QuestReroll = {}
QuestReroll.ProductId = MarketplaceLibrary.getItemId("QuestReroll")

function QuestReroll.grant(player: Player): boolean
	return QuestService.applyPaidReroll(player)
end

return QuestReroll
