--[[
	SkinController

	Description:
	Client side of boomerang skins: which skins the local player owns and has equipped, equip requests,
	and the "New skin acquired!" popup. Ownership comes from the replicated profile (`OwnedSkins`),
	the equipped skin from the `EquippedSkin` Player attribute (set by SkinService).
]]

local SkinController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type SkinTask = (skinId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipSkinRemoteFunction = SimpleRemotes.getFunction("EquipSkin")

-- // Skins known to be owned, so only new ones show the popup
local knownOwnedSkins: { [string]: boolean } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SkinController.SkinGrantedTasks = TasksList.new() :: TasksList.TasksList<SkinTask>
SkinController.SkinEquippedTasks = TasksList.new() :: TasksList.TasksList<SkinTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SkinController.ownsSkin(skinId: string): boolean
	return SkinLibrary.dataOwnsSkin(PlayerDataController.get(), skinId)
end

function SkinController.getEquippedSkinId(): string
	return SkinLibrary.getEquippedSkinId(localPlayer)
end

--- Asks the server to equip an owned skin. Yields; returns whether it worked.
function SkinController.requestEquip(skinId: string): boolean
	return equipSkinRemoteFunction:InvokeServer(skinId) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SkinController.init()
	PlayerDataController.getAsync(function(data)
		for skinId, owned in data.OwnedSkins or {} do
			knownOwnedSkins[skinId] = owned == true
		end
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedSkins" or #path ~= 1 or type(index) ~= "string" then
			return
		end

		local wasOwned = knownOwnedSkins[index] == true
		knownOwnedSkins[index] = value == true
		if value == true and not wasOwned then
			local skin = SkinLibrary.getSkin(index)
			ItemAcquiredGui.acquiredCustomItem(nil, "New skin acquired!", if skin then skin.Name else index)
			SkinController.SkinGrantedTasks:Execute("parallel", index)
		end
	end)

	localPlayer:GetAttributeChangedSignal(SkinLibrary.ATTRIBUTE_NAME):Connect(function()
		SkinController.SkinEquippedTasks:Execute("parallel", SkinController.getEquippedSkinId())
	end)
end

function SkinController.start() end

return SkinController
