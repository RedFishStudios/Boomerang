--[[
	SettingsController

	Description:
	The local player's settings (Shared/Constants/SettingConstants). A value is the one saved in the profile
	(`Settings`), or the default for the current device. Changing one applies it right away here and asks the server
	to save it (SettingsService). Systems that use a setting read it with getValue and listen to SettingChangedTasks:
	  - OverShoulderCamera: CustomCameraController (also changed by its C key)
	  - CameraShake: CustomCameraController (the parry shake)
	  - SoundEffectsVolume: the volume of SoundLibrary's sound effects SoundGroup
	  - MusicVolume: the volume of SoundLibrary's Music SoundGroup
	  - AimArrowLength: WeaponController (the local player's charge up effect)
	  - GuiInset*: GuiInsetController
	  - LeftHandedTouch: CustomTouchscreen, UsePickupButtons, TouchControlsSideController (Roblox's movement stick)
	  - ShowCosmeticEffects: WeaponController (other players' charge up effects)
	  - ShowEliminationFeed: ElimMessage
]]

local SettingsController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local DeviceUtil = require(ReplicatedStorage.Shared.Utils.DeviceUtil)
local SoundLibrary = require(ReplicatedStorage.Shared.Library.SoundLibrary)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local setSettingEvent = SimpleRemotes.getEvent("SetSetting")

-- // Values changed here that the replicated profile may not show yet (so the menu doesn't jump back while the save is
-- // on its way). Cleared once the profile has the same value.
local localValues: { [string]: SettingConstants.SettingValue } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-- // A setting's value changed (the player changed it, their saved settings loaded, or the device changed its default)
SettingsController.SettingChangedTasks = TasksList.new() :: TasksList.TasksList<(settingName: SettingConstants.SettingName, value: SettingConstants.SettingValue) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getSavedValue(settingName: string): SettingConstants.SettingValue?
	local data = PlayerDataController.get()
	local saved = data and (data :: any).Settings
	local value = saved and saved[settingName]
	if value == nil then
		return nil
	end
	return SettingConstants.sanitize(settingName, value)
end

local function applyVolumes()
	local effectsSetting = SettingConstants.Settings.SoundEffectsVolume
	local musicSetting = SettingConstants.Settings.MusicVolume
	SoundLibrary.getSoundEffectsGroup().Volume = (SettingsController.getValue("SoundEffectsVolume") :: number) / (effectsSetting.Max or 100)
	SoundLibrary.getMusicGroup().Volume = (SettingsController.getValue("MusicVolume") :: number) / (musicSetting.Max or 100)
end

-- // Tells every listener the current value of every setting (after loading, or when defaults may have changed)
local function announceAll()
	for _, settingName in SettingConstants.SettingOrder do
		SettingsController.SettingChangedTasks:Execute("parallel", settingName, SettingsController.getValue(settingName))
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingsController.getValue(settingName: SettingConstants.SettingName): SettingConstants.SettingValue
	local localValue = localValues[settingName]
	if localValue ~= nil then
		return localValue
	end
	local saved = getSavedValue(settingName)
	if saved ~= nil then
		return saved
	end
	return SettingConstants.getDefaultValue(settingName, DeviceUtil.getDevice())
end

-- // Changes a setting: applied here at once, saved by the server. Invalid values are ignored.
function SettingsController.setValue(settingName: SettingConstants.SettingName, value: SettingConstants.SettingValue)
	local sanitized = SettingConstants.sanitize(settingName, value)
	if sanitized == nil or sanitized == SettingsController.getValue(settingName) then
		return
	end
	localValues[settingName] = sanitized
	setSettingEvent:FireServer(settingName, sanitized)
	SettingsController.SettingChangedTasks:Execute("parallel", settingName, sanitized)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SettingsController.init()
	SettingsController.SettingChangedTasks:Add(function(settingName, _value)
		if settingName == SettingConstants.SettingNames.SoundEffectsVolume or settingName == SettingConstants.SettingNames.MusicVolume then
			applyVolumes()
		end
	end)
end

function SettingsController.start()
	applyVolumes()

	PlayerDataController.getAsync(function()
		announceAll()
	end)

	PlayerDataController.UpdatedTasks:Add(function(index, _value, path)
		if index ~= "Settings" and not (path and path[1] == "Settings") then
			return
		end
		for settingName, localValue in localValues do
			if getSavedValue(settingName) == localValue then
				localValues[settingName] = nil -- // Saved: the profile has it now
			end
		end
	end)

	-- // Unsaved settings follow the device's default (e.g. switching from keyboard to a controller)
	local lastDevice = DeviceUtil.getDevice()
	DeviceUtil.onDeviceChanged(function(device)
		if device ~= lastDevice then
			lastDevice = device
			announceAll()
		end
	end)
end

return SettingsController
