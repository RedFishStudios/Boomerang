--[[
  ShopService

  Description:
  Handles server-side shop purchases
]]

local ShopService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Items = require(ReplicatedStorage.Shared.Referential.Items)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local SkinService = require(ServerStorage.Server.Core.SkinService)
local ChargeUpEffectService = require(ServerStorage.Server.Core.ChargeUpEffectService)
local EmoteService = require(ServerStorage.Server.Core.EmoteService)
local CrateService = require(ServerStorage.Server.Core.CrateService)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local requestPurchaseRemoteFunction = SimpleRemotes.getFunction("RequestPurchase")

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ShopService.purchaseItem(player: Player, itemId: string): boolean
   local itemData = Items[itemId]
   if not itemData or itemData.OffSale then
      return false
   end

   local profileData = PlayerDataService.get(player)
   if not profileData then
      return false
   end

   local balance = profileData.Currency or 0
   if balance < itemData.Price then
      return false
   end

   -- Writes go through the data proxy, which replicates them to the client
   profileData.Currency = balance - itemData.Price
   profileData.Inventory[itemId] = (profileData.Inventory[itemId] or 0) + 1

   return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ShopService.init()
   -- // listingType is a ShopItems listing Type: "Item" (default), "Skin", "ChargeUpEffect", "Emote" or "Crate"
   requestPurchaseRemoteFunction.OnServerInvoke = function(player: Player, itemId: unknown, listingType: unknown)
      if type(itemId) ~= "string" then
         return false
      end
      if listingType == "Skin" then
         return SkinService.purchaseSkin(player, itemId)
      end
      if listingType == "ChargeUpEffect" then
         return ChargeUpEffectService.purchaseChargeUpEffect(player, itemId)
      end
      if listingType == "Emote" then
         return EmoteService.purchaseEmote(player, itemId)
      end
      if listingType == "Crate" then
         -- // T-112: also returns the skin id rolled and whether it was new
         return CrateService.purchaseCrate(player, itemId)
      end
      return ShopService.purchaseItem(player, itemId)
   end
end

function ShopService.start() end

return ShopService