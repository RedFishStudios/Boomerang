local ToolLibrary = {}

local ToolAssetsFolder = game:GetService("ReplicatedStorage").Shared.Assets.Tools

function ToolLibrary.getToolAssetsFolder()
   return ToolAssetsFolder
end

function ToolLibrary.init()
   -- // For some reason, rbxmx models loaded via rojo don't seem to have their primary part set
   local function setupToolModel(model: Model)
      if not model.PrimaryPart then
         local primary = model:WaitForChild("Handle", 30)
         if not primary then
            warn(`Critical: Tool model {model.Name} has no PrimaryPart and no Handle`)
            return
         end
         model.PrimaryPart = primary
      end
   end
   
   for _, model in pairs(ToolAssetsFolder:GetChildren()) do
      if model:IsA("Model") then
         setupToolModel(model)
      end
   end
   ToolAssetsFolder.ChildAdded:Connect(function(child)
      if child:IsA("Model") then
         setupToolModel(child)
      end
   end)
end

function ToolLibrary.start()
   
end

return ToolLibrary