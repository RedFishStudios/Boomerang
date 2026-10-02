-- // Handles measuring the offsets for the sides of the screen that should be used by the custom camera

-- // TEST: Fires throw remote when player presses E

local CameraPaddingController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GamemodeHudGui = require(ReplicatedStorage.Client.UI.Gui.GamemodeHud)
local HudButtonsGui = require(ReplicatedStorage.Client.UI.Gui.HudButtons)

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CameraPaddingController.getTopPadding(): number
   return GamemodeHudGui.getCameraPadding()
end

function CameraPaddingController.getBottomPadding(): number
   return HudButtonsGui.getCameraPadding()
end

function CameraPaddingController.getLeftPadding(): number
   return 0
end

function CameraPaddingController.getRightPadding(): number
   return 0
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CameraPaddingController.init()
end

function CameraPaddingController.start() end

return CameraPaddingController
