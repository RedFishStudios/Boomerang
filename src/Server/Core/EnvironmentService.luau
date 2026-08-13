--[[
  Root of handling functional environment objects

  DOCUMENTATION
   A map model optionally contains a folder named "Functional"
   That folder contains any kind of part or object with a kind of behavior (not just an obstruction)
   Every direct child of Functional must have an attribute "ClassName" which corresponds to a module in ReplicatedStorage.Shared.Logics.Environment
   That child (and descendants) may necessitate additional attributes depending on the classname; check the logic module's "Validate" function for details
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

local functionalsCount = 0

local functionalEnvironmentObjectsFolderName = "Functional"

local requiredFunctionalAttributes = {
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
      local functionalsFolder = map:FindFirstChild(functionalEnvironmentObjectsFolderName)
      if not functionalsFolder then
         continue
      end

      for _, c in pairs(functionalsFolder:GetChildren()) do
         local attributes = c:GetAttributes()
         local valid = true

         for attributeName, attributeType in pairs(requiredFunctionalAttributes) do
            if typeof(attributes[attributeName]) ~= attributeType then
               warn(`Functional object {c.Name} is missing required attribute {attributeName} of type {attributeType}`)
               valid = false
            end
         end

         if not valid then
            warn(`Functional object {c.Name} is not valid and will be ignored.`)
            c:SetAttribute("Invalid", true)
            continue
         end

         local className = attributes["ClassName"]
         local logicModule = EnvironmentLogicModules[className]
         if not logicModule then
            warn(`No logic module found for functional object class {className}`)
            c:SetAttribute("Invalid", true)
            continue
         end

         if logicModule.validate then
            local success, result = pcall(logicModule.validate, c)
            if success then
               local isValid = result
               if not isValid then
                  c:SetAttribute("Invalid", true)
                  continue
               end
            else
               warn(`Error validating functional object {c.Name}: {result}`)
               c:SetAttribute("Invalid", true)
               continue
            end
         end

         functionalsCount = functionalsCount + 1
         c.Name = tostring(functionalsCount)
      end
   end

   ArenaService.MapChangedTasks:Add(function(newMapName: string)
      local mapModel = ArenaService.getArenaModel()
      if not mapModel then
         warn(`EnvironmentService new arena setup: No arena model found`)
         return
      end
      local functionalsFolder = mapModel:FindFirstChild(functionalEnvironmentObjectsFolderName)
      if not functionalsFolder then
         return
      end
      for _, c in pairs(functionalsFolder:GetChildren()) do
         local attributes = c:GetAttributes()
         if attributes.Invalid then
            warn(`skipping an invalid functional object {c.Name}`)
            continue
         end
         local className = attributes["ClassName"]
         local logicModule = EnvironmentLogicModules[className]
         logicModule.onObjectAdded(c)
      end
   end)
end

return EnvironmentService
