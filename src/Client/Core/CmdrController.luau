--[[
	CmdrController

	Description:
	Loads the Cmdr developer console on the client, only for players the server marked with the
	"CmdrAdmin" attribute (everyone in Studio). Open/close it with F2.
	Permissions are enforced on the server by CmdrService; this only hides the console from everyone else.
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

		-- // Cmdr blocks every command in live games unless a BeforeRun hook exists on this side too.
		-- // The real permission check is CmdrService's hook on the server; this one only mirrors it.
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
