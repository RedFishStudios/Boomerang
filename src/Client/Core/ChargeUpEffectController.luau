--[[
	ChargeUpEffectController

	Description:
	Client side of charge up effects: which arrows the local player owns and has equipped, equip requests, and the
	"New charge up effect acquired!" popup. Ownership comes from the replicated profile (`OwnedChargeUpEffects`); any player's
	equipped arrow (the local player's too) comes from ChargeUpEffectLibrary / the `EquippedChargeUpEffect` Player attribute that
	ChargeUpEffectService sets and Roblox replicates. WeaponController reads it when a player starts aiming.
]]

local ChargeUpEffectController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ChargeUpEffectTask = (chargeUpEffectId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipChargeUpEffectRemoteFunction = SimpleRemotes.getFunction("EquipChargeUpEffect")

-- // Charge up effects known to be owned, so only new ones show the popup
local knownOwnedChargeUpEffects: { [string]: boolean } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ChargeUpEffectController.ChargeUpEffectGrantedTasks = TasksList.new() :: TasksList.TasksList<ChargeUpEffectTask>
ChargeUpEffectController.ChargeUpEffectEquippedTasks = TasksList.new() :: TasksList.TasksList<ChargeUpEffectTask>

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ChargeUpEffectController.ownsChargeUpEffect(chargeUpEffectId: string): boolean
	return ChargeUpEffectLibrary.dataOwns(PlayerDataController.get(), chargeUpEffectId)
end

function ChargeUpEffectController.getEquippedId(): string
	return ChargeUpEffectLibrary.getEquippedId(localPlayer)
end

--- Asks the server to equip an owned charge up effect. Yields; returns whether it worked.
function ChargeUpEffectController.requestEquip(chargeUpEffectId: string): boolean
	return equipChargeUpEffectRemoteFunction:InvokeServer(chargeUpEffectId) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ChargeUpEffectController.init()
	PlayerDataController.getAsync(function(data)
		for chargeUpEffectId, owned in data.OwnedChargeUpEffects or {} do
			knownOwnedChargeUpEffects[chargeUpEffectId] = owned == true
		end
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedChargeUpEffects" or #path ~= 1 or type(index) ~= "string" then
			return
		end

		local wasOwned = knownOwnedChargeUpEffects[index] == true
		knownOwnedChargeUpEffects[index] = value == true
		if value == true and not wasOwned then
			local chargeUpEffect = ChargeUpEffectLibrary.getChargeUpEffect(index)
			ItemAcquiredGui.acquiredCustomItem(
				chargeUpEffect and chargeUpEffect.Icon,
				"New charge up effect acquired!",
				if chargeUpEffect then chargeUpEffect.Name else index
			)
			ChargeUpEffectController.ChargeUpEffectGrantedTasks:Execute("parallel", index)
		end
	end)

	CosmeticLibrary.observe(localPlayer, "ChargeUpEffect", function()
		ChargeUpEffectController.ChargeUpEffectEquippedTasks:Execute("parallel", ChargeUpEffectController.getEquippedId())
	end)
end

function ChargeUpEffectController.start() end

return ChargeUpEffectController
