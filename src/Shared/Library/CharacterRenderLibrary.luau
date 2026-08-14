local CharacterRenderLibrary = {}

local StarterGui = game:GetService("StarterGui")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterRenderLibrary.CHARACTER_REPLICATION_FOLDER_NAME = "CharacterReplication"

local TEST_CHARACTER_USER_IDS = {
   817970896,
   2722681535,
   331516,
   7468812920,
   162613945,
   1484913853,
}

local DEFAULT_PLAYER_GUI_WAIT_TIMEOUT = 10

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderLibrary.getReplicationFolderForPlayer(player: Player): Folder?
   local playerGui = player:FindFirstChild("PlayerGui")
   if not playerGui then
      return nil
   end

   local replicationFolder = playerGui:FindFirstChild(CharacterRenderLibrary.CHARACTER_REPLICATION_FOLDER_NAME)
   if not replicationFolder then
      return nil
   end

   return replicationFolder
end

function CharacterRenderLibrary.getModelNameForUserId(userId: number): string
   return tostring(userId)
end

function CharacterRenderLibrary.getCharacterSourceUserId(userId: number): number
   if userId == 817970896 or userId <= 0 then
      local index = math.abs(userId) % #TEST_CHARACTER_USER_IDS
      if index == 0 then
         index = #TEST_CHARACTER_USER_IDS
      end
      return TEST_CHARACTER_USER_IDS[index]
   end
   return userId
end

function CharacterRenderLibrary.getReplicatedModelFromFolder(replicationFolder: Folder, userId: number): Model?
   local replicatedModel = replicationFolder:FindFirstChild(CharacterRenderLibrary.getModelNameForUserId(userId))
   if replicatedModel and replicatedModel:IsA("Model") then
      return replicatedModel
   end
   return nil
end

function CharacterRenderLibrary.getOrCreateStarterReplicationFolder(): Folder
   local existingFolder = StarterGui:FindFirstChild(CharacterRenderLibrary.CHARACTER_REPLICATION_FOLDER_NAME)
   if existingFolder and existingFolder:IsA("Folder") then
      return existingFolder
   end

   local folder = Instance.new("Folder")
   folder.Name = CharacterRenderLibrary.CHARACTER_REPLICATION_FOLDER_NAME
   folder.Parent = StarterGui
   return folder
end

function CharacterRenderLibrary.ensureReplicationFolderForPlayer(player: Player, canYield: boolean?): Folder?
   local playerGui = player:FindFirstChild("PlayerGui")
   if not playerGui and canYield ~= false then
      playerGui = player:WaitForChild("PlayerGui", DEFAULT_PLAYER_GUI_WAIT_TIMEOUT)
   end
   if not playerGui then
      return nil
   end

   local existingFolder = playerGui:FindFirstChild(CharacterRenderLibrary.CHARACTER_REPLICATION_FOLDER_NAME)
   if existingFolder and existingFolder:IsA("Folder") then
      return existingFolder
   end

   local starterFolder = CharacterRenderLibrary.getOrCreateStarterReplicationFolder()
   local clonedFolder = starterFolder:Clone()
   clonedFolder.Parent = playerGui
   return clonedFolder
end

function CharacterRenderLibrary.cloneModelToFolderIfMissing(replicationFolder: Folder, sourceModel: Model, userId: number): Model?
   if CharacterRenderLibrary.getReplicatedModelFromFolder(replicationFolder, userId) then
      return nil
   end

   local clone = sourceModel:Clone()
   clone.Name = CharacterRenderLibrary.getModelNameForUserId(userId)
   clone.Parent = replicationFolder
   return clone
end

function CharacterRenderLibrary.getReplicatedModelForPlayer(player: Player, userId: number): Model?
   local replicationFolder = CharacterRenderLibrary.getReplicationFolderForPlayer(player)
   if not replicationFolder then
      return nil
   end

   return CharacterRenderLibrary.getReplicatedModelFromFolder(replicationFolder, userId)
end

function CharacterRenderLibrary.removeReplicatedModelForPlayer(player: Player, userId: number)
   local replicationFolder = CharacterRenderLibrary.getReplicationFolderForPlayer(player)
   if not replicationFolder then
      return
   end

   CharacterRenderLibrary.removeReplicatedModelFromFolder(replicationFolder, userId)
end

function CharacterRenderLibrary.removeReplicatedModelFromFolder(replicationFolder: Folder, userId: number)
   local modelName = CharacterRenderLibrary.getModelNameForUserId(userId)

   -- There should only ever be one model, but make destruction absolute to fight any possible race condition
   for _, child in pairs(replicationFolder:GetChildren()) do
      if child:IsA("Model") and child.Name == modelName then
         child:Destroy()
         return
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderLibrary.init()
end

function CharacterRenderLibrary.start()
end

return CharacterRenderLibrary