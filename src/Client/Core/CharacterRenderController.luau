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
local animationSyncConnections: {[Player]: RBXScriptConnection} = {}

-- // [authoritativeAnimationId]: [customCharacterAnimationTrack]
--    The authoritative model is used as the reference point for animations and animations are synced to that authoritative model
local syncedAnimationTracks: {
   [Player]: {
      [string]: AnimationTrack
   }
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterRenderController.CustomCharacterLoaded = TasksList.new() :: TasksList.TasksList<(player: Player, customCharacter: Model) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function extractAnimations(player: Player, customCharacter: Model)
   local animateScript = nil
   local elapsed = 0
   repeat
      for _, c in pairs(customCharacter:GetChildren()) do
         if c:IsA("LocalScript") and c.Name == "Animate" then
            animateScript = c
            break
         end
      end
      elapsed += RunService.RenderStepped:Wait()
   until animateScript or elapsed > 12
   if not animateScript then
      warn(`AnimationController: Failed to find Animate script for custom character of player {player.Name}`)
      return
   end

   local authorityHumanoid = player.Character:WaitForChild("Humanoid", 3)
   if not authorityHumanoid then
      warn(`AnimationController: Failed to find Humanoid for authoritative character of player {player.Name}`)
      return
   end

   local authorityAnimator = authorityHumanoid:WaitForChild("Animator", 3)
   if not authorityAnimator then
      warn(`AnimationController: Failed to find Animator for authoritative character of player {player.Name}`)
      return
   end

   local customHumanoid = customCharacter:WaitForChild("Humanoid", 3)
   if not customHumanoid then
      warn(`AnimationController: Failed to find Humanoid for custom character of player {player.Name}`)
      return
   end

   local customAnimator = customHumanoid:WaitForChild("Animator", 3)
   if not customAnimator then
      warn(`AnimationController: Failed to find Animator for custom character of player {player.Name}`)
      return 
   end

   local function findMatchingDescendant(descendantName: string, parentName: string): Instance?
      for _, d in pairs(player.Character:GetDescendants()) do
         if d.Name == descendantName and d.Parent and d.Parent.Name == parentName then
            return d
         end
      end
      return nil
   end

   syncedAnimationTracks[player] = {}

   for _, c in pairs(animateScript:GetDescendants()) do
      if c:IsA("Animation") then
         local animationName = c.Name
         local animationParentName = c.Parent and c.Parent.Name or "nil"
         local matchingDescendant = findMatchingDescendant(animationName, animationParentName)
         if matchingDescendant and matchingDescendant:IsA("Animation") then
            local track = customAnimator:LoadAnimation(c)
            syncedAnimationTracks[player][matchingDescendant.AnimationId] = track
         else
            warn(`AnimationController: Failed to find matching animation for {animationName} under {animationParentName} for player {player.Name}`)
         end
      end
   end
end

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

   extractAnimations(player, model)

   CharacterRenderController.CustomCharacterLoaded:Execute("parallel", player, model)

   local authorityHumanoid = player.Character:FindFirstChild("Humanoid")

   local function sync()
      local playingTracks = authorityHumanoid:GetPlayingAnimationTracks()
         local syncedTracks = syncedAnimationTracks[player]
         if not syncedTracks then
             warn(`No synced animation tracks for player {player.Name}`)
            return
         end

         -- // Sync any playing track to the custom character if not already playing
         for _, track in pairs(playingTracks) do
            local syncedTrack = syncedTracks[track.Animation.AnimationId]
            if syncedTrack and not syncedTrack.IsPlaying then
               syncedTrack:Play()
            end
         end

         for mappedAnimationId, track in pairs(syncedTracks) do
            if not track.IsPlaying then
               continue
            end
            local isPlaying = false
            for _, playingTrack in pairs(playingTracks) do
               if playingTrack.Animation.AnimationId == mappedAnimationId then
                  print(`it is playing on the authority model`)
                  isPlaying = true
                  break
               end
            end
            if not isPlaying and track.IsPlaying then
               track:Stop()
           end
      end
   end

   if animationSyncConnections[player] then
      animationSyncConnections[player]:Disconnect()
      animationSyncConnections[player] = nil
   end
   animationSyncConnections[player] = game.RunService.Stepped:Connect(sync)

	return model
end

-- // Sync fabricated character model to the authoritative character root without inheriting animation bob
local function syncCharacterPositions(character, targetModel)
   local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
   if not targetRoot or not targetRoot:IsA("BasePart") then
      return
   end

   local renderedRoot = character:FindFirstChild("HumanoidRootPart")
   if not renderedRoot or not renderedRoot:IsA("BasePart") then
      return
   end

   local rootOffset = characterPositionOffsets[character]
   if not rootOffset then
      local pivot = character:GetPivot()
      rootOffset = pivot:PointToObjectSpace(renderedRoot.Position)
      characterPositionOffsets[character] = rootOffset
   end

   local pivot = character:GetPivot()
   local currentRotation = pivot - pivot.Position
   local adjustedPosition = targetRoot.Position - currentRotation:VectorToWorldSpace(rootOffset) - Vector3.new(0, .5, 0)

   character:PivotTo(currentRotation + adjustedPosition)
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
         syncCharacterPositions(model, p.Character)
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
      if animationSyncConnections[player] then
         animationSyncConnections[player]:Disconnect()
         animationSyncConnections[player] = nil
      end
      if syncedAnimationTracks[player] then
         for _, track in pairs(syncedAnimationTracks[player]) do
            track:Destroy()
         end
         table.clear(syncedAnimationTracks[player])
         syncedAnimationTracks[player] = nil
      end
   end)

   RunService.RenderStepped:Connect(everyFrame)
end

function CharacterRenderController.start()
   
end

return CharacterRenderController