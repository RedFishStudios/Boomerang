--[[
  Author:
  @Soulsplosion
]]

local RespawnController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingService = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
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

function RespawnController.init()
   local DeathScreenGrayscale = Instance.new("ColorCorrectionEffect")
   DeathScreenGrayscale.Name = "DeathScreenGrayscale"
   DeathScreenGrayscale.Saturation = -1
   DeathScreenGrayscale.Enabled = false
   DeathScreenGrayscale.Parent = LightingService

	localPlayer.CharacterAdded:Connect(function(character)
      print("spawned")
      DeathScreenGrayscale.Enabled = false
      local humanoid = character:WaitForChild("Humanoid")
      humanoid.Died:Connect(function()
         print("died")
         DeathScreenGrayscale.Enabled = true
      end)
   end)
end

-- function RespawnController.start() end

-- function RespawnController.test() end

return RespawnController
