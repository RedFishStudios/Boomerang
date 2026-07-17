local StarterGuiController = {}

local StarterGuiService = game:GetService("StarterGui")

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function StarterGuiController.init()
   StarterGuiService:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end

function StarterGuiController.start() end

return StarterGuiController