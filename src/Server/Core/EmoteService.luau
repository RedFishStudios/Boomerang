--[[
	EmoteService

	Description:
	Owns emotes on the server: granting, buying and equipping them (profile `OwnedEmotes` / `EquippedEmote`).
	Publishes the equipped emote's animation asset id as the `WinningEmote` Player attribute (CosmeticLibrary), which
	replicates to every client; the winner pedestal plays it (PedestalController / WinningEmoteLibrary).
	Same shape as ChargeUpEffectService. Emote data: Shared/Referential/Emotes.
]]

local EmoteService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local EmoteLibrary = require(ReplicatedStorage.Shared.Library.EmoteLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type EmoteTask = (player: Player, emoteId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipEmoteRemoteFunction = SimpleRemotes.getFunction("EquipEmote")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EmoteService.EmoteGrantedTasks = TasksList.new() :: TasksList.TasksList<EmoteTask>
EmoteService.EmoteEquippedTasks = TasksList.new() :: TasksList.TasksList<EmoteTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedEmote(player: Player, emoteId: string)
	local emote = EmoteLibrary.getEmote(emoteId)
	if not emote then
		return
	end
	CosmeticLibrary.setEquipped(player, "WinningEmote", emote.AnimationId)
	EmoteService.EmoteEquippedTasks:Execute("parallel", player, emoteId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EmoteService.ownsEmote(player: Player, emoteId: string): boolean
	return EmoteLibrary.dataOwns(PlayerDataService.get(player), emoteId)
end

--- Gives the player an emote. Returns false if it doesn't exist, the data isn't loaded, or it's already owned.
function EmoteService.grantEmote(player: Player, emoteId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not EmoteLibrary.getEmote(emoteId) or EmoteLibrary.dataOwns(data, emoteId) then
		return false
	end

	data.OwnedEmotes[emoteId] = true
	EmoteService.EmoteGrantedTasks:Execute("parallel", player, emoteId)
	return true
end

--- Buys an emote with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function EmoteService.purchaseEmote(player: Player, emoteId: string): boolean
	local emote = EmoteLibrary.getEmote(emoteId)
	if not emote or emote.OffSale or not PlayerDataService.get(player) or EmoteService.ownsEmote(player, emoteId) then
		return false
	end

	if not EconomyService.spendCurrency(player, emote.Price) then
		return false
	end

	return EmoteService.grantEmote(player, emoteId)
end

--- Equips an owned emote. Returns false if the player doesn't own it or the data isn't loaded.
function EmoteService.equipEmote(player: Player, emoteId: string): boolean
	local data = PlayerDataService.get(player)
	local emote = EmoteLibrary.getEmote(emoteId)
	if not data or not emote or not EmoteLibrary.dataOwns(data, emoteId) then
		return false
	end

	if data.EquippedEmote ~= emoteId then
		data.EquippedEmote = emoteId
	end
	if CosmeticLibrary.getEquippedRaw(player, "WinningEmote") ~= emote.AnimationId then
		applyEquippedEmote(player, emoteId)
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EmoteService.init()
	equipEmoteRemoteFunction.OnServerInvoke = function(player: Player, emoteId: unknown)
		if type(emoteId) ~= "string" then
			return false
		end
		return EmoteService.equipEmote(player, emoteId)
	end

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved emote no longer exists or isn't owned
		local emoteId = data.EquippedEmote
		if type(emoteId) ~= "string" or not EmoteLibrary.dataOwns(data, emoteId) then
			emoteId = EmoteLibrary.getDefaultId()
			data.EquippedEmote = emoteId
		end
		applyEquippedEmote(player, emoteId)
	end)
end

function EmoteService.start() end

return EmoteService
