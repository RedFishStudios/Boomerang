--[[
	MarketplaceLibrary

	Description:
	The game's wrapper around MarketplaceService, shared by the client and the server (the same caches, the same
	functions). Items are defined in Shared/Referential/MarketplaceItems and can be passed by name or id.

	Where things happen (keep server work and client <-> server traffic down):
	- Prices / product info and purchase prompts: on the CLIENT. The client prompts its own purchases directly; the server
	  is only involved when Roblox sends it the developer product's receipt (ProductService).
	- Gamepass ownership: either side can ask; each keeps its own cache (the client's normally only holds the local player).

	Caching (every Roblox web call is cached, and only one call per key is ever in flight; anyone else asking for the
	same thing meanwhile waits for that call's answer instead of making another):
	- Product / gamepass info: per id and type (product ids and gamepass ids are separate ranges), INFO_CACHE_SECONDS.
	  A failed lookup isn't retried for FAILED_LOOKUP_RETRY_SECONDS.
	- Gamepass ownership: GamepassAccessCache[userId][gamepassId], kept for the whole session (a purchase in this game
	  updates it at once; gifts come from the profile's GiftedPasses). Cleared when the player leaves.
	  Every gamepass in MarketplaceItems is looked up once, in parallel, when the player's data loads: the server for
	  every player, the client for the local player. After that, checks are answered from the cache without yielding.
	  GamepassOwnershipChangedTasks fires when a player gets a gamepass mid-session (purchase, gift, refresh).
	- Admins (the "CmdrAdmin" player attribute, set by CmdrService) count as owning every gamepass while
	  ADMINS_OWN_ALL_GAMEPASSES is on (GamepassAccess.Privileged), for testing.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PolicyLibrary = require(script.Parent.PolicyLibrary)
local GamepassAccess = require(ReplicatedStorage.Shared.Constants.Enums.GamepassAccess)
local MarketplaceItems = require(ReplicatedStorage.Shared.Referential.MarketplaceItems)

local MarketplaceLibrary = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local INFO_CACHE_SECONDS = 600 -- // Product / gamepass info (name, price, icon) is kept this long
local FAILED_LOOKUP_RETRY_SECONDS = 10 -- // After a failed web call, the same lookup answers "unknown" this long instead of calling again
local PROMPT_ANSWER_TIMEOUT = 60 -- // promptX(..., yieldForAnswer): seconds to wait for the player to finish the prompt
local ADMINS_OWN_ALL_GAMEPASSES = true -- // Admins (CmdrAdmin attribute) count as owning every gamepass (testing)
local ADMIN_ATTRIBUTE = "CmdrAdmin" -- // Set on the player by CmdrService (replicated, so both sides see it)

local isServer = RunService:IsServer()

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-- // https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#GetProductInfoAsync
export type RobuxItemInfo = {
	Name: string,
	Description: string?,
	PriceInRobux: number,
	IconImageAssetId: number,
	UserBasePriceInRobux: number,
	PriceDiscountDetails: {
		Type: Enum.DiscountType,
		AmountInRobux: number,
		Percent: number,
	},
	ProductId: number,
	ProductType: string,
	Created: string,
	Updated: string,
	ContentRatingType: number,
	MinimumMembershipLevel: number,
	IsPublicDomain: boolean,
	TargetId: number,
}

type InfoCacheEntry = {
	Info: RobuxItemInfo?, -- // nil = the lookup failed (retried after FAILED_LOOKUP_RETRY_SECONDS)
	CachedAt: number,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local ProductInfoCache: { [number]: InfoCacheEntry } = {}
local GamepassInfoCache: { [number]: InfoCacheEntry } = {}

-- // Same shape on the client and the server. Kept for the session; cleared when the player leaves.
local GamepassAccessCache: {
	[number]: { -- // UserId
		[number]: number, -- // GamepassId : GamepassAccess
	},
} = {}

-- // Web calls in flight, by key: the threads waiting for each one's answer
local inFlight: { [string]: { thread } } = {}

-- // Threads waiting for a purchase prompt to finish, by "<kind>_<userId>_<id>"
local promptWaiters: { [string]: { thread } } = {}

-------------------------------------------------------------------------------
-- PUBLIC VALUES
-------------------------------------------------------------------------------

MarketplaceLibrary.ProductPurchasePromptFinishedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, productId: number, wasPurchased: boolean) -> ()>
MarketplaceLibrary.GamepassPurchasePromptFinishedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, gamepassId: number, wasPurchased: boolean) -> ()>
-- // A player got a gamepass during the session (purchase, gift or refresh). Server: any player. Client: the local player.
-- // access is the GamepassAccess value (Owns / Gifted). Use it to switch a gamepass's benefit on without polling.
MarketplaceLibrary.GamepassOwnershipChangedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, gamepassId: number, access: number) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Runs fetch() for key unless a call for the same key is already running, in which case it waits for that call's
-- // result. fetch must not error (wrap web calls in pcall); its result is handed to every waiter.
local function singleFlight<T>(key: string, fetch: () -> T): T
	local waiting = inFlight[key]
	if waiting then
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end
	waiting = {}
	inFlight[key] = waiting
	local ok, result = pcall(fetch)
	inFlight[key] = nil
	if not ok then
		warn(`MarketplaceLibrary: lookup {key} failed: {result}`)
		result = nil
	end
	for _, thread in waiting do
		task.spawn(thread, result)
	end
	return result
end

-- // A product or gamepass id from a name or an id. A name says which type it is; an id is taken as the type asked for.
local function resolveId(item: string | number, expectedType: MarketplaceItems.RobuxItemType?): number?
	if typeof(item) == "number" then
		return item
	end
	local data = MarketplaceItems.ByName[item]
	if not data then
		return nil
	end
	if expectedType and data.Type ~= expectedType then
		warn(`MarketplaceLibrary: {item} is a {data.Type}, not a {expectedType}`)
		return nil
	end
	return data.Id
end

local function getItemData(item: string | number, itemType: MarketplaceItems.RobuxItemType): MarketplaceItems.RobuxItem?
	if typeof(item) == "string" then
		local data = MarketplaceItems.ByName[item]
		return if data and data.Type == itemType then data else nil
	end
	return if itemType == "Gamepass" then MarketplaceItems.GamepassesById[item] else MarketplaceItems.ProductsById[item]
end

-- // Cached product / gamepass info, fetched once per id (and type) at a time
local function getInfo(itemId: number, infoType: Enum.InfoType, cache: { [number]: InfoCacheEntry }): RobuxItemInfo?
	local cached = cache[itemId]
	local now = os.clock()
	if cached then
		local maxAge = if cached.Info then INFO_CACHE_SECONDS else FAILED_LOOKUP_RETRY_SECONDS
		if now - cached.CachedAt <= maxAge then
			return cached.Info
		end
	end

	return singleFlight(`Info_{infoType.Name}_{itemId}`, function()
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(itemId, infoType)
		end)
		local result = if success and typeof(info) == "table" then info else nil
		if not success then
			warn(`MarketplaceLibrary: GetProductInfoAsync({itemId}, {infoType.Name}) failed: {info}`)
		end
		cache[itemId] = { Info = result, CachedAt = os.clock() }
		return result
	end)
end

-- // The player's profile data (raw table), or nil where it isn't available (another player, on a client)
local function getPlayerProfileData(player: Player)
	if isServer then
		local PlayerDataService = require(game:GetService("ServerStorage").Server.Core.PlayerDataService)
		local profile = PlayerDataService.getProfile(player)
		return profile and profile.Data
	end
	if player ~= Players.LocalPlayer then
		return nil
	end
	local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
	return PlayerDataController.get()
end

-- // Caches a player's access to a gamepass. announce: fire GamepassOwnershipChangedTasks if they didn't have it before
-- // (a gain during the session; the first lookup when they join isn't announced).
local function setCachedGamepassAccess(userId: number, gamepassId: number, access: number, announce: boolean?)
	local userCache = GamepassAccessCache[userId]
	if not userCache then
		userCache = {}
		GamepassAccessCache[userId] = userCache
	end
	local previous = userCache[gamepassId]
	userCache[gamepassId] = access
	if announce and access ~= GamepassAccess.NoAccess and (previous == nil or previous == GamepassAccess.NoAccess) then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			MarketplaceLibrary.GamepassOwnershipChangedTasks:Execute("parallel", player, gamepassId, access)
		end
	end
end

local function isPrivileged(player: Player): boolean
	return ADMINS_OWN_ALL_GAMEPASSES and player:GetAttribute(ADMIN_ATTRIBUTE) == true
end

local function getGamepassAccess(player: Player, gamepassId: number): number
	if isPrivileged(player) then
		return GamepassAccess.Privileged
	end
	local userId = player.UserId
	local userCache = GamepassAccessCache[userId]
	local cached = userCache and userCache[gamepassId]
	if cached then
		return cached
	end

	-- // (A lookup that errored hands its waiters nil: that's no access)
	return singleFlight(`Owns_{userId}_{gamepassId}`, function()
		local profileData = getPlayerProfileData(player)
		if profileData and profileData.GiftedPasses and table.find(profileData.GiftedPasses, gamepassId) then
			setCachedGamepassAccess(userId, gamepassId, GamepassAccess.Gifted)
			return GamepassAccess.Gifted
		end

		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
		end)
		if not success then
			warn(`MarketplaceLibrary: UserOwnsGamePassAsync({userId}, {gamepassId}) failed: {owns}`)
			return GamepassAccess.NoAccess -- // Not cached: asked again next time
		end

		local access = if owns then GamepassAccess.Owns else GamepassAccess.NoAccess
		-- // A "no" is only final once the gifts could be checked too (the profile may not have loaded yet), and nothing is
		-- // cached for someone who already left (their cache was cleared)
		if (access ~= GamepassAccess.NoAccess or profileData) and player.Parent == Players then
			setCachedGamepassAccess(userId, gamepassId, access)
		end
		return access
	end) or GamepassAccess.NoAccess
end

-- // Waits (yields) for the player to finish a purchase prompt; nil if they haven't within PROMPT_ANSWER_TIMEOUT
local function waitForPromptAnswer(kind: string, userId: number, itemId: number): boolean?
	local key = `{kind}_{userId}_{itemId}`
	local waiters = promptWaiters[key]
	if not waiters then
		waiters = {}
		promptWaiters[key] = waiters
	end
	local thread = coroutine.running()
	table.insert(waiters, thread)
	task.delay(PROMPT_ANSWER_TIMEOUT, function()
		local current = promptWaiters[key]
		local index = current and table.find(current, thread)
		if index then
			table.remove(current, index)
			if #current == 0 then
				promptWaiters[key] = nil
			end
			task.spawn(thread, nil)
		end
	end)
	return coroutine.yield()
end

local function answerPromptWaiters(kind: string, userId: number, itemId: number, wasPurchased: boolean)
	local key = `{kind}_{userId}_{itemId}`
	local waiters = promptWaiters[key]
	if not waiters then
		return
	end
	promptWaiters[key] = nil
	for _, thread in waiters do
		task.spawn(thread, wasPurchased)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The id of an item given by name (either type) or id
function MarketplaceLibrary.getItemId(item: string | number): number?
	return resolveId(item)
end

-- // A developer product's definition (MarketplaceItems)
function MarketplaceLibrary.getItemDataById(id: number): MarketplaceItems.RobuxItem?
	return MarketplaceItems.ProductsById[id]
end

-- // A gamepass's definition (MarketplaceItems)
function MarketplaceLibrary.getGamepassDataById(id: number): MarketplaceItems.RobuxItem?
	return MarketplaceItems.GamepassesById[id]
end

-- // MAY YIELD (first lookup only). Developer product info; nil if unknown or the lookup failed.
function MarketplaceLibrary.getProductInfo(item: string | number): RobuxItemInfo?
	local itemId = resolveId(item, "Product")
	return if itemId then getInfo(itemId, Enum.InfoType.Product, ProductInfoCache) else nil
end

-- // MAY YIELD (first lookup only)
function MarketplaceLibrary.getProductPrice(item: string | number): number?
	local info = MarketplaceLibrary.getProductInfo(item)
	local price = info and info.PriceInRobux
	return if typeof(price) == "number" then price else nil
end

-- // MAY YIELD (first lookup only). Gamepass info; nil if unknown or the lookup failed.
function MarketplaceLibrary.getGamepassInfo(item: string | number): RobuxItemInfo?
	local itemId = resolveId(item, "Gamepass")
	return if itemId then getInfo(itemId, Enum.InfoType.GamePass, GamepassInfoCache) else nil
end

-- // MAY YIELD (first lookup only)
function MarketplaceLibrary.getGamepassPrice(item: string | number): number?
	local info = MarketplaceLibrary.getGamepassInfo(item)
	local price = info and info.PriceInRobux
	return if typeof(price) == "number" then price else nil
end

-- // Opens the developer product purchase prompt. Call it on the client for the local player (no server round trip).
-- // yieldForAnswer: wait for the player to finish the prompt and return whether they bought it (nil = no answer in time).
-- // The purchase itself is granted by the server when the receipt arrives (ProductService), not by this answer.
function MarketplaceLibrary.promptProductPurchase(player: Player, item: string | number, yieldForAnswer: boolean?): boolean?
	local itemId = resolveId(item, "Product")
	if not itemId then
		warn(`MarketplaceLibrary: invalid product: {item}`)
		return nil
	end
	MarketplaceService:PromptProductPurchase(player, itemId)
	if yieldForAnswer then
		return waitForPromptAnswer("Product", player.UserId, itemId)
	end
	return nil
end

-- // Player is optional on the client (defaults to LocalPlayer) and required on the server
function MarketplaceLibrary.promptDeveloperProduct(item: string | number, player: Player?, yieldForAnswer: boolean?): boolean?
	local targetPlayer = player or (if isServer then nil else Players.LocalPlayer)
	if not targetPlayer then
		warn("MarketplaceLibrary.promptDeveloperProduct requires a player on the server")
		return nil
	end
	return MarketplaceLibrary.promptProductPurchase(targetPlayer, item, yieldForAnswer)
end

-- // Opens the gamepass purchase prompt (call it on the client). yieldForAnswer as for promptProductPurchase.
function MarketplaceLibrary.promptGamepassPurchase(player: Player, gamepass: string | number, yieldForAnswer: boolean?): boolean?
	local gamepassId = resolveId(gamepass, "Gamepass")
	if not gamepassId then
		warn(`MarketplaceLibrary: invalid gamepass: {gamepass}`)
		return nil
	end
	MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	if yieldForAnswer then
		return waitForPromptAnswer("Gamepass", player.UserId, gamepassId)
	end
	return nil
end

-- // MAY YIELD (policy lookup). Whether the player may buy this item where they live (paid random items are
-- // restricted in some regions; an unknown policy counts as restricted).
function MarketplaceLibrary.playerCanPurchaseItem(player: Player, item: string | number): boolean
	local itemData = getItemData(item, "Product") or getItemData(item, "Gamepass")
	if not itemData then
		return false
	end
	if itemData.IsPaidRandomItem then
		local policyData = PolicyLibrary.getPlayerPolicyData(player)
		if not policyData or policyData.ArePaidRandomItemsRestricted then
			return false
		end
	end
	return true
end

-- // MAY YIELD (first check only). Whether the player has the gamepass (bought or gifted).
function MarketplaceLibrary.playerOwnsGamepass(player: Player, gamepass: string | number): boolean
	local gamepassId = resolveId(gamepass, "Gamepass")
	if not gamepassId then
		return false
	end
	return getGamepassAccess(player, gamepassId) ~= GamepassAccess.NoAccess
end

-- // MAY YIELD (first check only). The player's GamepassAccess value for a gamepass (NoAccess / Owns / Gifted / Privileged).
function MarketplaceLibrary.getGamepassAccess(player: Player, gamepass: string | number): number
	local gamepassId = resolveId(gamepass, "Gamepass")
	if not gamepassId then
		return GamepassAccess.NoAccess
	end
	return getGamepassAccess(player, gamepassId)
end

-- // SERVER. Gives the player a gamepass as a gift: saved in their profile (GiftedPasses, which also tells their client)
-- // and counted as owned at once. Returns false if their data isn't loaded or the gamepass is unknown.
function MarketplaceLibrary.giftGamepass(player: Player, gamepass: string | number): boolean
	assert(isServer, "MarketplaceLibrary.giftGamepass is server only")
	local gamepassId = resolveId(gamepass, "Gamepass")
	if not gamepassId then
		return false
	end
	local PlayerDataService = require(game:GetService("ServerStorage").Server.Core.PlayerDataService)
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	local giftedPasses = (data.GiftedPasses :: any)() :: { number }
	if not table.find(giftedPasses, gamepassId) then
		data.GiftedPasses[#giftedPasses + 1] = gamepassId -- // Through the proxy, so it replicates
	end
	local userCache = GamepassAccessCache[player.UserId]
	if not (userCache and userCache[gamepassId] == GamepassAccess.Owns) then
		setCachedGamepassAccess(player.UserId, gamepassId, GamepassAccess.Gifted, true)
	end
	return true
end

-- // MAY YIELD. Forgets the cached ownership and asks Roblox again (e.g. a purchase made on the website during the
-- // session). One gamepass, or all of MarketplaceItems' gamepasses. A newly owned one fires GamepassOwnershipChangedTasks.
function MarketplaceLibrary.refreshGamepassOwnership(player: Player, gamepass: (string | number)?)
	local gamepassIds: { number } = {}
	if gamepass ~= nil then
		local gamepassId = resolveId(gamepass, "Gamepass")
		if gamepassId then
			table.insert(gamepassIds, gamepassId)
		end
	else
		for gamepassId in MarketplaceItems.GamepassesById do
			table.insert(gamepassIds, gamepassId)
		end
	end
	local userCache = GamepassAccessCache[player.UserId]
	for _, gamepassId in gamepassIds do
		local previous = userCache and userCache[gamepassId]
		if userCache then
			userCache[gamepassId] = nil
		end
		local access = getGamepassAccess(player, gamepassId)
		local gained = access ~= GamepassAccess.NoAccess and access ~= GamepassAccess.Privileged
			and (previous == nil or previous == GamepassAccess.NoAccess)
		if gained then
			MarketplaceLibrary.GamepassOwnershipChangedTasks:Execute("parallel", player, gamepassId, access)
		end
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

-- // Looks up every known gamepass for the player at once (in parallel), so later checks don't yield
local function prefetchGamepasses(player: Player)
	for gamepassId in MarketplaceItems.GamepassesById do
		task.spawn(getGamepassAccess, player, gamepassId)
	end
end

-- // Client: gifts arrive through the replicated profile (GiftedPasses); count them as owned and announce them
local function watchLocalGifts()
	local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
	local localPlayer = Players.LocalPlayer
	PlayerDataController.UpdatedTasks:Add(function(_index, value, path)
		if path[1] ~= "GiftedPasses" or typeof(value) ~= "number" then
			return
		end
		local userCache = GamepassAccessCache[localPlayer.UserId]
		if not (userCache and userCache[value] == GamepassAccess.Owns) then
			setCachedGamepassAccess(localPlayer.UserId, value, GamepassAccess.Gifted, true)
		end
	end)
end

function MarketplaceLibrary.init()
	Players.PlayerRemoving:Connect(function(player: Player)
		GamepassAccessCache[player.UserId] = nil
	end)

	-- // Note: this event passes the buyer's UserId (not a Player)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, wasPurchased: boolean)
		answerPromptWaiters("Product", userId, productId, wasPurchased)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			MarketplaceLibrary.ProductPurchasePromptFinishedTasks:Execute("parallel", player, productId, wasPurchased)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassId: number, wasPurchased: boolean)
		if wasPurchased then
			setCachedGamepassAccess(player.UserId, gamepassId, GamepassAccess.Owns, true)
		end
		answerPromptWaiters("Gamepass", player.UserId, gamepassId, wasPurchased)
		MarketplaceLibrary.GamepassPurchasePromptFinishedTasks:Execute("parallel", player, gamepassId, wasPurchased)
	end)

	-- // Look up every gamepass once the player's data has loaded (so gifts are checked too)
	if isServer then
		local PlayerDataService = require(game:GetService("ServerStorage").Server.Core.PlayerDataService)
		PlayerDataService.ProfileAddedTasks:Add(prefetchGamepasses)
	else
		local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
		PlayerDataController.getAsync(function()
			prefetchGamepasses(Players.LocalPlayer)
		end)
		watchLocalGifts()
	end
end

return MarketplaceLibrary
