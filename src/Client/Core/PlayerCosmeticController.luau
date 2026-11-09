--[[
	PlayerCosmeticController

	Description:
	The client's cache of every player's equipped cosmetics (the local player's too), for client systems that render
	players (effects, emotes, skins...). Raw ids come from the `Equipped*` Player attributes in CosmeticLibrary. Per player
	and category it keeps the resolved value (the category resolver's result for the raw id, e.g. a validated id or a
	template; the raw id itself if there is no resolver) and notifies listeners of changes.

	A category's Library registers a resolver with `registerResolver`. A resolver gets the raw id (nil when unset) and
	must always return a usable value, falling back to the category's default.
	Entries are created when a player is added (or on first `get`) and dropped when the player leaves.
]]

local PlayerCosmeticController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Category = CosmeticLibrary.Category
type Resolver = (rawId: string?) -> any
type ChangedTask = (player: Player, category: Category, value: any) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-- // [player]: [category]: resolved value
local cache: { [Player]: { [Category]: any } } = {}
local attributeConnections: { [Player]: { RBXScriptConnection } } = {}
local resolvers: { [Category]: Resolver } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // Fires when a player's resolved value for a category changes (not on the first fill of a new entry)
PlayerCosmeticController.Changed = TasksList.new() :: TasksList.TasksList<ChangedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function resolve(player: Player, category: Category): any
	local rawId = CosmeticLibrary.getEquippedRaw(player, category)
	local resolver = resolvers[category]
	if resolver then
		return resolver(rawId)
	end
	return rawId
end

-- // Re-resolves one category for a player and announces a change
local function refresh(player: Player, category: Category)
	local entry = cache[player]
	if not entry then
		return
	end

	local value = resolve(player, category)
	if entry[category] == value then
		return
	end

	entry[category] = value
	PlayerCosmeticController.Changed:Execute("parallel", player, category, value)
end

local function untrack(player: Player)
	local connections = attributeConnections[player]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	attributeConnections[player] = nil
	cache[player] = nil
end

local function track(player: Player): { [Category]: any }?
	if cache[player] then
		return cache[player]
	end
	if not player:IsDescendantOf(Players) then
		return nil
	end

	local entry: { [Category]: any } = {}
	cache[player] = entry

	local connections = {}
	for category, attributeName in CosmeticLibrary.ATTRIBUTES do
		entry[category] = resolve(player, category)
		table.insert(
			connections,
			player:GetAttributeChangedSignal(attributeName):Connect(function()
				refresh(player, category)
			end)
		)
	end
	attributeConnections[player] = connections

	return entry
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- The player's resolved value for a category: the resolver's result, or the raw equipped id (nil when unset) if there is
--- no resolver. Nil for a player who has left.
function PlayerCosmeticController.get(player: Player, category: Category): any
	local entry = track(player)
	return if entry then entry[category] else nil
end

--- Sets how a category turns a raw id into its usable value and re-resolves everyone cached (announcing changes).
--- Called by the category's Library.
function PlayerCosmeticController.registerResolver(category: Category, resolver: Resolver)
	resolvers[category] = resolver
	for player in cache do
		refresh(player, category)
	end
end

--- Calls `callback` whenever the player's resolved value for a category changes (not immediately; use `get` for the
--- current value). Returns a disconnect function.
function PlayerCosmeticController.observe(
	player: Player,
	category: Category,
	callback: (value: any) -> ()
): () -> ()
	return PlayerCosmeticController.Changed:Add(function(changedPlayer, changedCategory, value)
		if changedPlayer == player and changedCategory == category then
			callback(value)
		end
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerCosmeticController.init()
	for _, player in Players:GetPlayers() do
		track(player)
	end

	PlayersUtil.PlayerAdded:Add(function(player)
		track(player)
	end)

	PlayersUtil.PlayerRemoving:Add(function(player)
		untrack(player)
	end)
end

function PlayerCosmeticController.start() end

return PlayerCosmeticController
