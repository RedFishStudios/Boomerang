--[[
	EmoteController

	Description:
	Client side of emotes: which emotes the local player owns and has equipped, equip requests, and the
	"New emote acquired!" popup. Ownership comes from the replicated profile (`OwnedEmotes`); the equipped emote comes
	from the `WinningEmote` Player attribute that EmoteService sets (EmoteLibrary). Same shape as ChargeUpEffectController.
]]

local EmoteController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local EmoteLibrary = require(ReplicatedStorage.Shared.Library.EmoteLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type EmoteTask = (emoteId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipEmoteRemoteFunction = SimpleRemotes.getFunction("EquipEmote")

-- // Emotes known to be owned, so only new ones show the popup
local knownOwnedEmotes: { [string]: boolean } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

EmoteController.EmoteGrantedTasks = TasksList.new() :: TasksList.TasksList<EmoteTask>
EmoteController.EmoteEquippedTasks = TasksList.new() :: TasksList.TasksList<EmoteTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function EmoteController.ownsEmote(emoteId: string): boolean
	return EmoteLibrary.dataOwns(PlayerDataController.get(), emoteId)
end

function EmoteController.getEquippedId(): string
	return EmoteLibrary.getEquippedId(localPlayer)
end

--- Asks the server to equip an owned emote. Yields; returns whether it worked.
function EmoteController.requestEquip(emoteId: string): boolean
	return equipEmoteRemoteFunction:InvokeServer(emoteId) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function EmoteController.init()
	PlayerDataController.getAsync(function(data)
		for emoteId, owned in data.OwnedEmotes or {} do
			knownOwnedEmotes[emoteId] = owned == true
		end
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedEmotes" or #path ~= 1 or type(index) ~= "string" then
			return
		end

		local wasOwned = knownOwnedEmotes[index] == true
		knownOwnedEmotes[index] = value == true
		if value == true and not wasOwned then
			local emote = EmoteLibrary.getEmote(index)
			ItemAcquiredGui.acquiredCustomItem(nil, "New emote acquired!", if emote then emote.Name else index)
			EmoteController.EmoteGrantedTasks:Execute("parallel", index)
		end
	end)

	CosmeticLibrary.observe(localPlayer, "WinningEmote", function()
		EmoteController.EmoteEquippedTasks:Execute("parallel", EmoteController.getEquippedId())
	end)
end

function EmoteController.start() end

return EmoteController
