--[[
  Root of handling environment logics for the client
]]

local EnvironmentService = {}

local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaService = require(game.ServerStorage.Server.Core.ArenaService)

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

local dynamicsCount = 0

local dynamicEnvironmentObjectsFolderName = "Dynamic"

local requiredDynamicAttributes = {
   ClassName = typeof("")
}

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
   local mapModels = ArenaService.getAllMapModels()
   for _, map in pairs(mapModels) do
      local dynamicsFolder = map:FindFirstChild(dynamicEnvironmentObjectsFolderName)
      if not dynamicsFolder then
         continue
      end
      for _, c in pairs(dynamicsFolder:GetChildren()) do
         local attributes = c:GetAttributes()
         local valid = true
         for attributeName, attributeType in pairs(requiredDynamicAttributes) do
            if typeof(attributes[attributeName]) ~= attributeType then
               warn(`Dynamic object {c.Name} is missing required attribute {attributeName} of type {attributeType}`)
               valid = false
            end
         end
         if not valid then
            warn(`Dynamic object {c.Name} is not valid and will be ignored.`)
            c:SetAttribute("Invalid", true)
            continue
         end
         local className = attributes["ClassName"]
         local logicModule = EnvironmentLogicModules[className]
         if not logicModule then
            warn(`No logic module found for dynamic object class {className}`)
            c:SetAttribute("Invalid", true)
            continue
         end
         dynamicsCount = dynamicsCount + 1
         c.Name = tostring(dynamicsCount)
      end
   end

   ArenaService.MapChangedTasks:Add(function(newMapName: string)
      local mapModel = ArenaService.getArenaModel()
      if not mapModel then
         warn(`EnvironmentService new arena setup: No arena model found`)
         return
      end
      local dynamicsFolder = mapModel:FindFirstChild(dynamicEnvironmentObjectsFolderName)
      if not dynamicsFolder then
         return
      end
      for _, c in pairs(dynamicsFolder:GetChildren()) do
         local attributes = c:GetAttributes()
         if attributes.Invalid then
            warn(`skipping an invalid dynamic object {c.Name}`)
            continue
         end
         local className = attributes["ClassName"]
         local logicModule = EnvironmentLogicModules[className]
         logicModule.onObjectAdded(c)
      end
   end)
end

return EnvironmentService
