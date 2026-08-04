-- // Manages clientside replication of player characters, including their own

local CharacterRenderController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local CharactersFolder = game.Workspace.Characters

local localCharacterModels: {[Player]: Model} = {}
local creatingCharacterModels: {[Player]: true} = {}
local lastCreationLoadFailure: {[Player]: number} = {}
local characterPositionOffsets: {[Player]: Vector3} = {}
local characterDescendantConnections: {[Player]: RBXScriptConnection} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterRenderController.CustomCharacterLoaded = TasksList.new() :: TasksList.TasksList<(player: Player, customCharacter: Model) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function setAuthoritativeCharacterTransparency(player: Player, transparency: number)
   if not player.Character then
      return
   end
   for _, d in pairs(player.Character:GetDescendants()) do
      if d:IsA("MeshPart") or d:IsA("BasePart") or d:IsA("Part") then
         if d.Name:match("Hitbox") then
            continue
         end
         d.Transparency = transparency
      end
   end
end

-- // Create fabricated character model
local function createCharacterModel(player: Player)
   creatingCharacterModels[player] = true
	local userId = player.UserId
   if userId <= 0 then
      userId = 817970896 -- Default to my userId in testing environment
   end
	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)

	if not success then
		warn("Failed to get description:", description)
      creatingCharacterModels[player] = nil
      lastCreationLoadFailure[player] = os.clock()
		return
	end

	local success2, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R15
		)
	end)

	if not success2 then
		warn("Failed to create model:", model)
      creatingCharacterModels[player] = nil
      lastCreationLoadFailure[player] = os.clock()
		return
	end

   task.spawn(function()
      repeat
         RunService.Stepped:Wait()
         for _, d in pairs(model:GetDescendants()) do
         if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Part") then
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
         end
      end
      until not player.Parent
   end)

	model.Name = `{userId}_LocalModel`
	model.Parent = CharactersFolder
	localCharacterModels[player] = model
   creatingCharacterModels[player] = nil

   CharacterRenderController.CustomCharacterLoaded:Execute("parallel", player, model)

	return model
end

-- // Sync fabricated character model to authoritative model position and rotation
local function syncCharacterPosition(character, targetModel)
	local targetCF, targetSize = targetModel:GetBoundingBox()
	local charCF, charSize = character:GetBoundingBox()

	local targetBottomY = targetCF.Position.Y - targetSize.Y / 2
	local charBottomY = charCF.Position.Y - charSize.Y / 2

	local offsetY = targetBottomY - charBottomY

	local pivot = character:GetPivot()

	local newPosition = Vector3.new(
		targetCF.Position.X,
		pivot.Position.Y + offsetY,
		targetCF.Position.Z
	)
   local currentRotation = pivot - pivot.Position

	character:PivotTo(
      currentRotation + newPosition
	)
end

-- // Retrieve fabricated character model, creating it if necessary
local function getCharacterModel(player: Player, canYield: boolean?): Model?
	if localCharacterModels[player] then
		return localCharacterModels[player]
	end
   if creatingCharacterModels[player] then
      if canYield then
         local elapsed = 0
         repeat
            elapsed += RunService.Heartbeat:Wait()
         until elapsed > 5 or localCharacterModels[player]
         if localCharacterModels[player] then
            return localCharacterModels[player]
         else
            warn(`getCharacterModel timed out for {player}`)
            return nil
         end
      else
         print(`model already in the process of creation for {player}`)
         return nil
      end
   end
   if lastCreationLoadFailure[player] and os.clock() - lastCreationLoadFailure[player] < 2 then
      print(`recently failed to create model for {player}, skipping creation`)
      return nil
   end
   return createCharacterModel(player)
end

local function everyFrame(deltaTime)
   for _, p in pairs(game.Players:GetPlayers()) do
      local model = getCharacterModel(p, false)
      if not model then
         setAuthoritativeCharacterTransparency(p, .5)
         continue
      end
      if not p.Character or not p.Character.PrimaryPart then
         model.Parent = nil
         continue -- Out of render distance or nonexistent
      end
      if model.Parent ~= CharactersFolder then
         model.Parent = CharactersFolder
      end
      setAuthoritativeCharacterTransparency(p, 1)
      syncCharacterPosition(model, p.Character)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderController.getCharacterModel(player: Player, canYield: boolean?): Model?
   return getCharacterModel(player, canYield)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderController.init()
   PlayersUtil.PlayerRemoving:Add(function(player)
      local model = localCharacterModels[player]
      if model then
         model:Destroy()
      end
      localCharacterModels[player] = nil
      creatingCharacterModels[player] = nil
      characterPositionOffsets[player] = nil
      if characterDescendantConnections[player] then
         characterDescendantConnections[player]:Disconnect()
         characterDescendantConnections[player] = nil
      end
   end)

   RunService.RenderStepped:Connect(everyFrame)
end

function CharacterRenderController.start()
   
end

return CharacterRenderController