--[[
	AimArrowController

	Description:
	Client side of aim arrows: which arrows the local player owns and has equipped, equip requests, and the
	"New aim arrow acquired!" popup. Ownership comes from the replicated profile (`OwnedAimArrows`); any player's
	equipped arrow (the local player's too) comes from AimArrowLibrary / the `EquippedAimArrow` Player attribute that
	AimArrowService sets and Roblox replicates. WeaponController reads it when a player starts aiming.
]]

local AimArrowController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local AimArrowLibrary = require(ReplicatedStorage.Shared.Library.AimArrowLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type AimArrowTask = (aimArrowId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipAimArrowRemoteFunction = SimpleRemotes.getFunction("EquipAimArrow")

-- // Aim arrows known to be owned, so only new ones show the popup
local knownOwnedAimArrows: { [string]: boolean } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

AimArrowController.AimArrowGrantedTasks = TasksList.new() :: TasksList.TasksList<AimArrowTask>
AimArrowController.AimArrowEquippedTasks = TasksList.new() :: TasksList.TasksList<AimArrowTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AimArrowController.ownsAimArrow(aimArrowId: string): boolean
	return AimArrowLibrary.dataOwns(PlayerDataController.get(), aimArrowId)
end

function AimArrowController.getEquippedId(): string
	return AimArrowLibrary.getEquippedId(localPlayer)
end

--- Asks the server to equip an owned aim arrow. Yields; returns whether it worked.
function AimArrowController.requestEquip(aimArrowId: string): boolean
	return equipAimArrowRemoteFunction:InvokeServer(aimArrowId) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function AimArrowController.init()
	PlayerDataController.getAsync(function(data)
		for aimArrowId, owned in data.OwnedAimArrows or {} do
			knownOwnedAimArrows[aimArrowId] = owned == true
		end
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedAimArrows" or #path ~= 1 or type(index) ~= "string" then
			return
		end

		local wasOwned = knownOwnedAimArrows[index] == true
		knownOwnedAimArrows[index] = value == true
		if value == true and not wasOwned then
			local aimArrow = AimArrowLibrary.getAimArrow(index)
			ItemAcquiredGui.acquiredCustomItem(
				aimArrow and aimArrow.Icon,
				"New aim arrow acquired!",
				if aimArrow then aimArrow.Name else index
			)
			AimArrowController.AimArrowGrantedTasks:Execute("parallel", index)
		end
	end)

	CosmeticLibrary.observe(localPlayer, "AimArrow", function()
		AimArrowController.AimArrowEquippedTasks:Execute("parallel", AimArrowController.getEquippedId())
	end)
end

function AimArrowController.start() end

return AimArrowController
