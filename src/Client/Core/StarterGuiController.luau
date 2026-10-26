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
   -- // T-130: the Stats panel (Client/UI/Gui/StatsPanel) replaces Roblox's player list; Tab opens the panel instead
   StarterGuiService:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end

function StarterGuiController.start() end

return StarterGuiController