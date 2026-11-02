--[[
	SettingsService

	Description:
	Saves the players' settings (Shared/Constants/SettingConstants) in their profile (`Settings`), from the client's
	"SetSetting" remote. Every value is checked against the setting first. The client reads the saved values through
	the replicated profile and applies them itself (SettingsController).
]]

local SettingsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SettingConstants = require(ReplicatedStorage.Shared.Constants.SettingConstants)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local setSettingEvent = SimpleRemotes.getEvent("SetSetting")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onSetSetting(player: Player, settingName: any, value: any)
	local sanitized = SettingConstants.sanitize(settingName, value)
	if sanitized == nil then
		return
	end
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	if data.Settings == nil then
		data.Settings = {}
	end
	if data.Settings[settingName] ~= sanitized then
		data.Settings[settingName] = sanitized -- // Through the proxy, so it replicates to the player
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SettingsService.init()
	setSettingEvent.OnServerEvent:Connect(onSetSetting)
end

return SettingsService
