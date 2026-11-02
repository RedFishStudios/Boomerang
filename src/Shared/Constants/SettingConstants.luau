--[[
	SettingConstants

	Description:
	Every player setting: its type, how it's shown in the Settings menu, and its default per device. Players' changes are
	saved in the profile (`Settings`: setting id -> value, only for settings they changed); a setting with no saved value
	uses the default for the device they're on. SettingsService (server) saves changes, SettingsController (client) reads
	and applies them.

	Setting ids are saved: never rename or reuse one.
]]

local SettingConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeviceConstants = require(ReplicatedStorage.Shared.Constants.DeviceConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SETTING_TYPES = table.freeze({
	Toggle = "Toggle",
	Slider = "Slider",
})

local SETTING_NAMES = table.freeze({
	OverShoulderCamera = "OverShoulderCamera",
	CameraShake = "CameraShake",
	SoundEffectsVolume = "SoundEffectsVolume",
	MusicVolume = "MusicVolume",
	AimArrowLength = "AimArrowLength",
	LeftHandedTouch = "LeftHandedTouch",
	GuiInsetLeft = "GuiInsetLeft",
	GuiInsetRight = "GuiInsetRight",
	GuiInsetTop = "GuiInsetTop",
	GuiInsetBottom = "GuiInsetBottom",
	ShowCosmeticEffects = "ShowCosmeticEffects",
	ShowEliminationFeed = "ShowEliminationFeed",
	ShowRecallPopup = "ShowRecallPopup",
})

local DEVICE_TYPES = DeviceConstants.DeviceTypes

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type SettingType = keyof<typeof(SETTING_TYPES)>
export type SettingName = keyof<typeof(SETTING_NAMES)>
export type SettingValue = boolean | number

export type Setting = {
	DisplayName: string,
	Type: SettingType,
	DefaultValues: { [DeviceConstants.DeviceType]: SettingValue },
	OffText: string?, -- // Toggle: text shown when off / on
	OnText: string?,
	Min: number?, -- // Slider: range and step
	Max: number?,
	Step: number?,
	Suffix: string?, -- // Slider: shown after the number (e.g. "%")
}

-- // A titled group of rows in the Settings menu
export type SettingSection = { Title: string, Settings: { SettingName } }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local settings: { [SettingName]: Setting } = {
	[SETTING_NAMES.OverShoulderCamera] = {
		DisplayName = "Camera Mode",
		Type = SETTING_TYPES.Toggle,
		OffText = "Top-Down",
		OnText = "Over-Shoulder",
		DefaultValues = { [DEVICE_TYPES.Mobile] = false, [DEVICE_TYPES.Console] = false, [DEVICE_TYPES.Desktop] = false },
	},
	[SETTING_NAMES.CameraShake] = {
		DisplayName = "Camera Shake",
		Type = SETTING_TYPES.Toggle,
		OffText = "Off",
		OnText = "On",
		DefaultValues = { [DEVICE_TYPES.Mobile] = true, [DEVICE_TYPES.Console] = true, [DEVICE_TYPES.Desktop] = true },
	},
	[SETTING_NAMES.SoundEffectsVolume] = {
		DisplayName = "Sound Effects",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 100,
		Step = 1,
		Suffix = "%",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 100, [DEVICE_TYPES.Console] = 100, [DEVICE_TYPES.Desktop] = 100 },
	},
	[SETTING_NAMES.MusicVolume] = {
		DisplayName = "Music",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 100,
		Step = 1,
		Suffix = "%",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 100, [DEVICE_TYPES.Console] = 100, [DEVICE_TYPES.Desktop] = 100 },
	},
	[SETTING_NAMES.AimArrowLength] = {
		DisplayName = "Aim Arrow Length",
		Type = SETTING_TYPES.Slider,
		Min = 50,
		Max = 200,
		Step = 5,
		Suffix = "%",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 100, [DEVICE_TYPES.Console] = 100, [DEVICE_TYPES.Desktop] = 100 },
	},
	[SETTING_NAMES.LeftHandedTouch] = {
		DisplayName = "Touch Controls",
		Type = SETTING_TYPES.Toggle,
		OffText = "Right-Handed",
		OnText = "Left-Handed",
		DefaultValues = { [DEVICE_TYPES.Mobile] = false, [DEVICE_TYPES.Console] = false, [DEVICE_TYPES.Desktop] = false },
	},
	-- // Screen edge insets (pixels) for every GUI. Roblox's own safe-area insets are turned off (GuiInsetController),
	-- // so these are the only thing keeping the GUIs away from the screen's edges, notches and the top bar.
	[SETTING_NAMES.GuiInsetLeft] = {
		DisplayName = "Left Inset",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 200,
		Step = 1,
		Suffix = "px",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 0, [DEVICE_TYPES.Console] = 0, [DEVICE_TYPES.Desktop] = 0 },
	},
	[SETTING_NAMES.GuiInsetRight] = {
		DisplayName = "Right Inset",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 200,
		Step = 1,
		Suffix = "px",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 0, [DEVICE_TYPES.Console] = 0, [DEVICE_TYPES.Desktop] = 0 },
	},
	[SETTING_NAMES.GuiInsetTop] = {
		DisplayName = "Top Inset",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 200,
		Step = 1,
		Suffix = "px",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 0, [DEVICE_TYPES.Console] = 0, [DEVICE_TYPES.Desktop] = 0 },
	},
	[SETTING_NAMES.GuiInsetBottom] = {
		DisplayName = "Bottom Inset",
		Type = SETTING_TYPES.Slider,
		Min = 0,
		Max = 200,
		Step = 1,
		Suffix = "px",
		DefaultValues = { [DEVICE_TYPES.Mobile] = 0, [DEVICE_TYPES.Console] = 0, [DEVICE_TYPES.Desktop] = 0 },
	},
	[SETTING_NAMES.ShowCosmeticEffects] = {
		DisplayName = "Others' Cosmetic Effects",
		Type = SETTING_TYPES.Toggle,
		OffText = "Hidden",
		OnText = "Shown",
		DefaultValues = { [DEVICE_TYPES.Mobile] = true, [DEVICE_TYPES.Console] = true, [DEVICE_TYPES.Desktop] = true },
	},
	[SETTING_NAMES.ShowEliminationFeed] = {
		DisplayName = "Elimination Feed",
		Type = SETTING_TYPES.Toggle,
		OffText = "Hidden",
		OnText = "Shown",
		DefaultValues = { [DEVICE_TYPES.Mobile] = true, [DEVICE_TYPES.Console] = true, [DEVICE_TYPES.Desktop] = true },
	},
	[SETTING_NAMES.ShowRecallPopup] = {
		DisplayName = "Recall Pop-Up",
		Type = SETTING_TYPES.Toggle,
		OffText = "Hidden",
		OnText = "Shown",
		DefaultValues = { [DEVICE_TYPES.Mobile] = true, [DEVICE_TYPES.Console] = true, [DEVICE_TYPES.Desktop] = true },
	},
}

-- // The Settings menu's sections and rows, in order
local SETTING_SECTIONS: { SettingSection } = {
	{ Title = "Camera", Settings = { SETTING_NAMES.OverShoulderCamera, SETTING_NAMES.CameraShake } },
	{ Title = "Audio", Settings = { SETTING_NAMES.SoundEffectsVolume, SETTING_NAMES.MusicVolume } },
	{ Title = "Controls", Settings = { SETTING_NAMES.AimArrowLength, SETTING_NAMES.LeftHandedTouch } },
	{
		Title = "Screen Insets",
		Settings = { SETTING_NAMES.GuiInsetLeft, SETTING_NAMES.GuiInsetRight, SETTING_NAMES.GuiInsetTop, SETTING_NAMES.GuiInsetBottom },
	},
	{
		Title = "Display",
		Settings = { SETTING_NAMES.ShowCosmeticEffects, SETTING_NAMES.ShowEliminationFeed, SETTING_NAMES.ShowRecallPopup },
	},
}

-- // Every setting, in menu order
local SETTING_ORDER: { SettingName } = {}
for _, section in SETTING_SECTIONS do
	for _, settingName in section.Settings do
		table.insert(SETTING_ORDER, settingName)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

SettingConstants.Settings = settings
SettingConstants.SettingNames = SETTING_NAMES
SettingConstants.SettingTypes = SETTING_TYPES
SettingConstants.SettingOrder = SETTING_ORDER
SettingConstants.SettingSections = SETTING_SECTIONS

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SettingConstants.getDefaultValue(settingName: SettingName, deviceType: DeviceConstants.DeviceType): SettingValue
	local setting = settings[settingName]
	return setting.DefaultValues[deviceType] or setting.DefaultValues[DEVICE_TYPES.Desktop]
end

-- // The value as it should be saved (a slider is clamped and snapped to its step), or nil if it isn't valid for
-- // the setting. The server runs every change through this.
function SettingConstants.sanitize(settingName: any, value: any): SettingValue?
	local setting = type(settingName) == "string" and settings[settingName]
	if not setting then
		return nil
	end
	if setting.Type == SETTING_TYPES.Toggle then
		return if type(value) == "boolean" then value else nil
	end
	if setting.Type == SETTING_TYPES.Slider then
		if type(value) ~= "number" or value ~= value then -- // value ~= value: NaN
			return nil
		end
		local min, max, step = setting.Min or 0, setting.Max or 1, setting.Step
		local clamped = math.clamp(value, min, max)
		if step and step > 0 then
			clamped = math.clamp(min + math.floor((clamped - min) / step + 0.5) * step, min, max)
		end
		return clamped
	end
	return nil
end

return SettingConstants
