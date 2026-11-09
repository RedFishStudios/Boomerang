--[[
	CmdrController

	Description:
	Loads the Cmdr console for players with the "CmdrAdmin" attribute (everyone in Studio). Toggle with F2.
	Permissions are enforced by CmdrService on the server.
]]

local CmdrController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local ADMIN_ATTRIBUTE = "CmdrAdmin"
local ACTIVATION_KEYS = { Enum.KeyCode.F2 }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local player = Players.LocalPlayer
local cmdrClient = nil
local isLoading = false

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function refresh()
	local isAdmin = player:GetAttribute(ADMIN_ATTRIBUTE) == true

	if isAdmin and not cmdrClient and not isLoading then
		isLoading = true
		cmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient"))
		cmdrClient:SetActivationKeys(ACTIVATION_KEYS)

		-- // Cmdr blocks all commands in live games unless a client BeforeRun hook exists.
		-- // The real permission check is CmdrService's server hook.
		cmdrClient.Registry:RegisterHook("BeforeRun", function(_context)
			if player:GetAttribute(ADMIN_ATTRIBUTE) ~= true then
				return "You don't have permission to run this command."
			end
			return nil
		end)
	end

	if cmdrClient then
		cmdrClient:SetEnabled(isAdmin)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CmdrController.start()
	player:GetAttributeChangedSignal(ADMIN_ATTRIBUTE):Connect(refresh)
	refresh()
end

return CmdrController
