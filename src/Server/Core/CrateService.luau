--[[
	CrateService (T-112)

	Description:
	Buying a weapon crate (Shared/Referential/Crates) from the Weapons Shop: the Currency is spent, a weapon of the crate's
	category is rolled with CrateLibrary (weighted by Tools.CrateWeight) and its skin is granted (SkinService). Called by
	ShopService for "Crate" listings.
	Duplicates: rolling a weapon the player already owns still costs the crate and gives nothing more for now.
	TODO: decide what a duplicate gives (refund, currency, shards...).
]]

local CrateService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CrateLibrary = require(ReplicatedStorage.Shared.Library.CrateLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local SkinService = require(ServerStorage.Server.Core.SkinService)

local rng = Random.new()

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Returns success, the skin id rolled, and whether it was new to the player
function CrateService.purchaseCrate(player: Player, crateId: string): (boolean, string?, boolean?)
	local crate = CrateLibrary.getCrate(crateId)
	if not crate or crate.OffSale or not PlayerDataService.get(player) then
		return false
	end
	if #CrateLibrary.getEntries(crateId) == 0 then
		warn(`CrateService: {crateId} has nothing to give (no tools of category {crate.Category} with a CrateWeight and a skin)`)
		return false
	end
	if not EconomyService.spendCurrency(player, crate.Price) then
		return false
	end

	local entry = CrateLibrary.roll(crateId, rng)
	if not entry then
		EconomyService.addCurrency(player, crate.Price) -- // Can't happen (checked above); never charge for nothing
		return false
	end

	local isNew = not SkinService.ownsSkin(player, entry.SkinId)
	if isNew then
		SkinService.grantSkin(player, entry.SkinId) -- // The client shows "New skin acquired!" when it replicates
	end
	return true, entry.SkinId, isNew
end

function CrateService.init() end

function CrateService.start() end

return CrateService
