-- // Manages replication states of player characters

local CharacterRenderService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CharacterRenderLibrary = require(ReplicatedStorage.Shared.Library.CharacterRenderLibrary)

local LOAD_FAILURE_COOLDOWN_SECONDS = 2

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local loadingModelsByUserId: { [number]: true } = {}
local lastLoadFailureByUserId: { [number]: number } = {}

local function isPlayerConnected(player: Player): boolean
   return player.Parent == Players
end

local function createCharacterModelForPlayer(player: Player): Model?
   task.wait(math.random() * 0.5) -- Random wait to avoid hammering the API if multiple players join at once

   local sourceUserId = CharacterRenderLibrary.getCharacterSourceUserId(player.UserId)

   local descriptionSuccess, descriptionResult 
   local descriptionAttempts = 0
   while not descriptionSuccess and descriptionAttempts < 5 do
      descriptionAttempts = descriptionAttempts + 1
      descriptionSuccess, descriptionResult = pcall(function()
         return Players:GetHumanoidDescriptionFromUserIdAsync(sourceUserId)
      end)
      if not descriptionSuccess then
         warn(`CharacterRenderService: Failed to load HumanoidDescription for {player.Name} ({player.UserId}): {descriptionResult}`)
         task.wait(descriptionAttempts * ((math.random() * 0.5) * 2)) -- Exponential backoff with slight randomization if still overloading with simultaneous requests
      end
   end

   if not descriptionSuccess then
      warn(`Critical: Failed to load HumanoidDescription for {player.Name} ({player.UserId}) after {descriptionAttempts} attempts.`)
      return nil
   end

   local modelSuccess, modelResult
   local modelAttempts = 0
   while not modelSuccess and modelAttempts < 5 do
      modelAttempts = modelAttempts + 1
      modelSuccess, modelResult = pcall(function()
         return Players:CreateHumanoidModelFromDescriptionAsync(descriptionResult, Enum.HumanoidRigType.R15)
      end)
      if not modelSuccess then
         warn(`CharacterRenderService: Failed to create humanoid model for {player.Name} ({player.UserId}): {modelResult}`)
         task.wait(modelAttempts * ((math.random() * 0.5) * 2))
      end
   end

   if not modelSuccess then
      warn(`CharacterRenderService: Failed to create humanoid model for {player.Name} ({player.UserId}): {modelResult}`)
      return nil
   end

   local humanoid = modelResult:FindFirstChildOfClass("Humanoid")
   if humanoid then
      humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
      humanoid.BreakJointsOnDeath = false
   end

   modelResult.Name = CharacterRenderLibrary.getModelNameForUserId(player.UserId)

   for _, d in pairs(modelResult:GetDescendants()) do
      if d:IsA("BasePart") then
         d.CanCollide = false
         d.CanTouch = false
         d.CanQuery = false
      end
   end

   return modelResult
end

local function replicateModelToPlayerFolder(targetPlayer: Player, sourceModel: Model, userId: number)
   local replicationFolder = CharacterRenderLibrary.ensureReplicationFolderForPlayer(targetPlayer, true)
   if not replicationFolder then
      return
   end

   CharacterRenderLibrary.cloneModelToFolderIfMissing(replicationFolder, sourceModel, userId)
end

local function replicateModelToAllPlayerFolders(sourceModel: Model, userId: number)
   for _, targetPlayer in pairs(Players:GetPlayers()) do
      replicateModelToPlayerFolder(targetPlayer, sourceModel, userId)
   end
end

local function ensureReplicatedCharacterForPlayer(player: Player)
   if not isPlayerConnected(player) then
      return
   end

   local userId = player.UserId

   local starterReplicationFolder = CharacterRenderLibrary.getOrCreateStarterReplicationFolder()
   local existingStarterModel = CharacterRenderLibrary.getReplicatedModelFromFolder(starterReplicationFolder, userId)
   if existingStarterModel then
      replicateModelToAllPlayerFolders(existingStarterModel, userId)
      return
   end

   if loadingModelsByUserId[userId] then
      return
   end

   local lastFailureAt = lastLoadFailureByUserId[userId]
   if lastFailureAt and os.clock() - lastFailureAt < LOAD_FAILURE_COOLDOWN_SECONDS then
      return
   end

   loadingModelsByUserId[userId] = true

   task.spawn(function()
      local model = createCharacterModelForPlayer(player)
      loadingModelsByUserId[userId] = nil

      if not model then
         lastLoadFailureByUserId[userId] = os.clock()
         return
      end

      if not isPlayerConnected(player) then
         model:Destroy()
         return
      end

      local existingModel = CharacterRenderLibrary.getReplicatedModelFromFolder(starterReplicationFolder, userId)
      if existingModel then
         model:Destroy()
         replicateModelToAllPlayerFolders(existingModel, userId)
         return
      end

      model.Parent = starterReplicationFolder
      replicateModelToAllPlayerFolders(model, userId)
   end)
end

local function removeReplicatedCharacterForUserId(userId: number)
   CharacterRenderLibrary.removeReplicatedModelFromFolder(CharacterRenderLibrary.getOrCreateStarterReplicationFolder(), userId)

   for _, targetPlayer in pairs(Players:GetPlayers()) do
      CharacterRenderLibrary.removeReplicatedModelForPlayer(targetPlayer, userId)
   end

   loadingModelsByUserId[userId] = nil
   lastLoadFailureByUserId[userId] = nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderService.init()
   local starterReplicationFolder = CharacterRenderLibrary.getOrCreateStarterReplicationFolder()

   for _, player in pairs(Players:GetPlayers()) do
      CharacterRenderLibrary.ensureReplicationFolderForPlayer(player, true)
   end

   for _, child in pairs(starterReplicationFolder:GetChildren()) do
      if not child:IsA("Model") then
         continue
      end

      local userId = tonumber(child.Name)
      if userId then
         replicateModelToAllPlayerFolders(child, userId)
      end
   end

   for _, player in pairs(Players:GetPlayers()) do
      ensureReplicatedCharacterForPlayer(player)
   end

   PlayersUtil.PlayerAdded:Add(function(player: Player)
      CharacterRenderLibrary.ensureReplicationFolderForPlayer(player, true)

      for _, child in pairs(starterReplicationFolder:GetChildren()) do
         if child:IsA("Model") then
            local userId = tonumber(child.Name)
            if userId then
               replicateModelToPlayerFolder(player, child, userId)
            end
         end
      end

      ensureReplicatedCharacterForPlayer(player)
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      removeReplicatedCharacterForUserId(player.UserId)
   end)
end

function CharacterRenderService.start()
end

function CharacterRenderService.test() end

return CharacterRenderService
