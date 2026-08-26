local GamemodeController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamemodeLogics = ReplicatedStorage.Shared.Logics.GamemodeLogics
local GamemodeLogicModules = {}

function GamemodeController.init()
   for _, module in pairs(GamemodeLogics:GetChildren()) do
      local gamemodeId = module.Name
      local logic = require(module)
      GamemodeLogicModules[gamemodeId] = logic
   end
end

return GamemodeController