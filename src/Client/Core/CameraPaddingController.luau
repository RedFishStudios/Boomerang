-- // Measures the screen-side offsets used as padding by the custom camera

local CameraPaddingController = {}

local GuiService = game:GetService("GuiService")
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

-- // The topbar row is drawn over the 3D view, so it counts as padding
function CameraPaddingController.getTopPadding(): number
   local topbar = GuiService.TopbarInset
   return math.max(GamemodeHudGui.getCameraPadding(), topbar.Min.Y + topbar.Height)
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
