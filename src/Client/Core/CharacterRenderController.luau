-- // Manages clientside replication of player characters, including their own

local CharacterRenderController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

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
local characterDescendantConnections: {[Player]: RBXScriptConnection} = {}
local animationSyncConnections: {[Player]: RBXScriptConnection} = {}
local characterDeathConnections: {[Player]: RBXScriptConnection} = {}
local characterPositionOffsets: {[Player]: Vector3} = {}
local referenceModels: {[Player]: Model} = {}
local ragdollApplied: {[Player]: true} = {}

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

local function clear(player: Player)
   ragdollApplied[player] = nil
   if localCharacterModels[player] then
      localCharacterModels[player]:Destroy()
   end
   localCharacterModels[player] = nil
   creatingCharacterModels[player] = nil
   characterPositionOffsets[player] = nil
   if characterDescendantConnections[player] then
      characterDescendantConnections[player]:Disconnect()
   end
   characterDescendantConnections[player] = nil
   if animationSyncConnections[player] then
      animationSyncConnections[player]:Disconnect()
   end
   animationSyncConnections[player] = nil
   if syncedAnimationTracks[player] then
      for _, track in pairs(syncedAnimationTracks[player]) do
         track:Destroy()  
      end
      table.clear(syncedAnimationTracks[player])
   end
   syncedAnimationTracks[player] = nil
   if characterDeathConnections[player] then
      characterDeathConnections[player]:Disconnect()
   end
   characterDeathConnections[player] = nil
end

local ragdollCollisionEnabledNames = {"LeftHand", "Left Arm", "UpperTorso", "RightHand", "Right Arm", "LeftFoot", "Left Leg", "RightFoot", "Right Leg", "Head"}

local function applyRagdoll(player: Player, model: Model)
   ragdollApplied[player] = true

   model.Humanoid.PlatformStand = true

   task.spawn(function()
      repeat
         RunService.Stepped:Wait()
        	for index, descendant in pairs(model:GetDescendants()) do
            if descendant:IsA("AnimationConstraint") then
               descendant:Destroy()
            elseif descendant:IsA("BasePart") or descendant:IsA("MeshPart") then
               descendant.Anchored = false
               if table.find(ragdollCollisionEnabledNames, descendant.Name) then
                  descendant.CanCollide = true
               else
                  descendant.CanCollide = false
               end
            end
         end
      until not model.Parent
   end)
end

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
            -- custom emotes and such
            --warn(`AnimationController: Failed to find matching animation for {animationName} under {animationParentName} for player {player.Name}`)
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
      local testUserIds = {7468812920, 817970896, 3383554889, 2016889786, 331516}
      userId = testUserIds[math.random(1, #testUserIds)]
   end

   local model
   if referenceModels[player] then
      -- Clone previously created model
      model = referenceModels[player]:Clone()
   else
      -- Create new model
      local success, description = pcall(function()
		   return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
      end)

      if not success then
         warn("Failed to get description:", description)
         creatingCharacterModels[player] = nil
         lastCreationLoadFailure[player] = os.clock()
         return
      end

      local success2
      success2, model = pcall(function()
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

      local customHumanoid = model:FindFirstChildOfClass("Humanoid")
      customHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
      customHumanoid.BreakJointsOnDeath = false
	   model.Name = `{userId}_LocalModel`
      referenceModels[player] = model:Clone()
   end

   task.spawn(function()
      local authorityHumanoid = player.Character:WaitForChild("Humanoid")
      repeat
         RunService.Stepped:Wait()
         for _, d in pairs(model:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Part") then
               d.CanCollide = false
               d.CanQuery = false
               d.CanTouch = false
               d.CollisionGroup = CollisionGroupConstants.Players
            end
         end
      until not model.Parent or not player.Parent or not player.Character or authorityHumanoid.Health <= 0
   end)

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
            local speed = track.Speed
            if syncedTrack and not syncedTrack.IsPlaying then
               syncedTrack:Play()
               syncedTrack:AdjustSpeed(speed*2)
            end
         end

         -- // Stop any synced track that is no longer playing on the authoritative character
         for mappedAnimationId, track in pairs(syncedTracks) do
            if not track.IsPlaying then
               continue
            end
            local isPlaying = false
            for _, playingTrack in pairs(playingTracks) do
               if playingTrack.Animation.AnimationId == mappedAnimationId then
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

   if characterDeathConnections[player] then
      characterDeathConnections[player]:Disconnect()
      characterDeathConnections[player] = nil
   end
   
   characterDeathConnections[player] = authorityHumanoid.Died:Connect(function()
      if animationSyncConnections[player] then
         animationSyncConnections[player]:Disconnect()
         animationSyncConnections[player] = nil
      end
      if characterDeathConnections[player] then
         characterDeathConnections[player]:Disconnect()
         characterDeathConnections[player] = nil
      end
      if syncedAnimationTracks[player] then
         for _, track in pairs(syncedAnimationTracks[player]) do
            track:Stop()
            track:Destroy()
         end
         table.clear(syncedAnimationTracks[player])
      end
   end)

	return model
end

-- // Sync fabricated character model to the authoritative character root without inheriting animation bob
local function syncCharacterPositions(player, character, targetModel)
   local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
   if not targetHumanoid then
      return
   end
   if targetHumanoid.Health <= 0 then
      if not ragdollApplied[player] then
         applyRagdoll(player, character)
      end
      return
   end

   local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
   if not targetRoot or not targetRoot:IsA("BasePart") then
      return
   end

   local renderedRoot = character:FindFirstChild("HumanoidRootPart")
   if not renderedRoot or not renderedRoot:IsA("BasePart") then
      return
   end

   local rootOffset = characterPositionOffsets[player]
   if not rootOffset then
      local pivot = character:GetPivot()
      rootOffset = pivot:PointToObjectSpace(renderedRoot.Position)
      characterPositionOffsets[player] = rootOffset
   end

   local pivot = character:GetPivot()
   local currentRotation = pivot - pivot.Position
   local adjustedPosition = targetRoot.Position - currentRotation:VectorToWorldSpace(rootOffset) - Vector3.new(0, .5, 0)

   character:PivotTo(currentRotation + adjustedPosition)
end

-- // Retrieve fabricated character model, creating it if necessary
local function getCharacterModel(player: Player, canYield: boolean?): Model?
   if not player.Character or not player.Character.PrimaryPart then
      return nil
   end

   -- If the previous render model is in ragdoll state but the authoritative character is alive,
   -- that render model is stale (from the previous life) and must be rebuilt.
   if localCharacterModels[player] and ragdollApplied[player] then
      local authorityHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
      if authorityHumanoid and authorityHumanoid.Health > 0 then
         clear(player)
      end
   end

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
      syncCharacterPositions(p, model, p.Character)
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
      clear(player)
   end)

   PlayersUtil.CharacterDestroying:Add(function(player)
      clear(player)
   end)

   RunService.RenderStepped:Connect(everyFrame)
end

function CharacterRenderController.start()
   
end

return CharacterRenderController

--[[
DYING AND SUCH PLAN
- When a character spawns, they should have a completely new character render and animation tracks.
  - Destroy all old ones when they die
- When a character dies:
  - Their custom model should ragdoll
  This means:
  - Animation sync stops
  - All animaton stops
  - Custom model is rendered into a "Dead" state with ragdoll joints
  - Custom model should cease syncing to the authoritative model position
  - Custom model should collide with map objects, but NOT be considered an object that the authoritative model stands on  

]]