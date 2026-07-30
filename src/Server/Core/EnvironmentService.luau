--[[
  Root of handling environment logics for the client
]]

local EnvironmentService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentLogics = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logics"):WaitForChild("Environment")
local EnvironmentLogicModules = {}

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

function EnvironmentService.init()
   for _, module in ipairs(EnvironmentLogics:GetChildren()) do
      if module:IsA("ModuleScript") then
         local m = require(module)
         EnvironmentLogicModules[module.Name] = m
         if m.init then
            m.init()
         end
      end
   end
end

function EnvironmentService.start()
end

return EnvironmentService
