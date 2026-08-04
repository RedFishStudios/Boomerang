-- // Manages clientside replication of player characters, including their own

local CharacterRenderController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalInstanceController = require(ReplicatedStorage.Client.Controllers.GlobalInstanceController)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local CharactersFolder = game.Workspace.Characters

local localCharacterModels: {[Player]: Model} = {}
local creatingCharacterModels: {[Player]: true} = {}
local characterPositionOffsets: {[Player]: Vector3} = {}
local characterDescendantConnections: {[Player]: RBXScriptConnection} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function createCharacterModel(player: Player)
   creatingCharacterModels[player] = true
	local userId = player.UserId
	local success, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
	end)

	if not success then
		warn("Failed to get description:", description)
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
		return
	end

   task.spawn(function()
      repeat
         task.wait()
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

	return model
end

local function placeCharacterOnTarget(character, targetModel)
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

	character:PivotTo(
		CFrame.new(newPosition) * targetCF.Rotation
	)
end

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
   return createCharacterModel(player)
end

local function everyFrame(deltaTime)
   for _, p in pairs(game.Players:GetPlayers()) do
      local model = getCharacterModel(p, false)
      if not model then
         continue
      end
      if not p.Character or not p.Character.PrimaryPart then
         model.Parent = nil
         continue -- Out of render distance or nonexistent
      end
      if model.Parent ~= CharactersFolder then
         model.Parent = CharactersFolder
      end
      --[[local referencePivot = p.Character:GetPivot()
      local raycastParams = RaycastParams.new()
      raycastParams.FilterType = Enum.RaycastFilterType.Exclude
      raycastParams.FilterDescendantsInstances = { model, p.Character }

      local rayOrigin = referencePivot.Position + Vector3.new(0, 16, 0)
      local rayDirection = Vector3.new(0, -128, 0)
      local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

      local offset = characterPositionOffsets[p] or Vector3.zero
      if raycastResult then
         local humanoid = model:FindFirstChildOfClass("Humanoid")
         local rootPart = model:FindFirstChild("HumanoidRootPart")
         if humanoid and rootPart and rootPart:IsA("BasePart") then
            local targetY = raycastResult.Position.Y + humanoid.HipHeight + rootPart.Size.Y * 0.5
            offset = Vector3.new(0, targetY - referencePivot.Position.Y, 0)
            characterPositionOffsets[p] = offset
         end
      end

      model:PivotTo(referencePivot + offset)]]
      placeCharacterOnTarget(model, p.Character)
   end
end

local function onCharacterLoaded(player, character, humanoid: Humanoid, primaryPart: Part)
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
   for _, P in pairs(PlayersUtil.getPlayersWithLoadedCharacters()) do
      onCharacterLoaded(P, P.Character, P.Character.Humanoid, P.Character.PrimaryPart)
   end

   PlayersUtil.CharacterLoaded:Add(onCharacterLoaded)

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