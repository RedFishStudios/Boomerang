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
   -- // The Stats panel (Client/UI/Gui/StatsPanel) replaces Roblox's player list; Tab opens it
   StarterGuiService:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end

function StarterGuiController.start() end

return StarterGuiController