-- // Manages clientside replication of player characters, including their own

local CharacterRenderController = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CharacterRenderLibrary = require(ReplicatedStorage.Shared.Library.CharacterRenderLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local MapData = require(ReplicatedStorage.Shared.Constants.MapData)
local Disguise = require(ReplicatedStorage.Shared.Logics.PickupLogics.Disguise)
local CharacterMovementController = require(ReplicatedStorage.Client.Core.CharacterMovementController)

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
local ragdollApplied: {[Player]: true} = {}
local disguiseModels: {[Player]: Model} = {}

-- // [authoritativeAnimationId]: [customCharacterAnimationTrack]
--    The authoritative model is used as the reference point for animations and animations are synced to that authoritative model
local syncedAnimationTracks: {
   [Player]: {
      [string]: AnimationTrack
   }
} = {}

-- // Server authority (Workspace.AuthorityMode = Server): Roblox's Animate is a ModuleScript that keeps its state in
--    HumanoidRootPart attributes ("pose", "currentAnimId", ...). Those attributes replicate to every client, so the rendered
--    model is animated from the authoritative character's "pose" attribute instead of mirroring its tracks (T-068).
--    When the attribute is missing (AuthorityMode = Automatic, classic Animate LocalScript), the old track mirroring is used.
type PoseAnimationData = {
   Animate: Instance, -- // the rendered model's Animate (LocalScript or ModuleScript); holds the animation folders
   Animator: Animator,
   Tracks: {[string]: AnimationTrack}, -- // [animation folder name, e.g. "walk"]: track on the rendered model
   Active: {[string]: true}, -- // folder names wanted last frame
}
local poseAnimationData: {[Player]: PoseAnimationData} = {}

-- // Same mapping as the Server-authority Animate's POSE_TO_ANIM_NAME
local POSE_TO_ANIMATION_NAME = {
   Standing = "idle",
   Running = "walk",
   Jumping = "jump",
   FreeFall = "fall",
   Climbing = "climb",
   Seated = "sit",
   Swimming = "swim",
   SwimIdle = "swimidle",
}
local LOOPED_POSE_ANIMATIONS = {idle = true, walk = true, run = true, fall = true, climb = true, sit = true, swim = true, swimidle = true, toolnone = true}
local POSE_TRANSITION_TIME = 0.2
-- // R15 walk/run blend, matching the Animate's getRunWalkBlendWeights
local NORMALIZED_WALK_SPEED = 0.5
local NORMALIZED_RUN_SPEED = 1
local HUMANOID_HIP_HEIGHT = 2

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CharacterRenderController.CustomCharacterLoaded = TasksList.new() :: TasksList.TasksList<(player: Player, customCharacter: Model) -> ()>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function destroyPoseAnimationData(player: Player)
   local data = poseAnimationData[player]
   poseAnimationData[player] = nil
   if not data then
      return
   end
   for _, track in pairs(data.Tracks) do
      track:Stop()
      track:Destroy()
   end
   table.clear(data.Tracks)
   table.clear(data.Active)
end

local function clear(player: Player)
   ragdollApplied[player] = nil
   if localCharacterModels[player] then
      localCharacterModels[player]:Destroy()
   end
   localCharacterModels[player] = nil
   if disguiseModels[player] then
      disguiseModels[player]:Destroy()
   end
   disguiseModels[player] = nil
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
   destroyPoseAnimationData(player)
   if characterDeathConnections[player] then
      characterDeathConnections[player]:Disconnect()
   end
   characterDeathConnections[player] = nil
end

local function getDisguiseModel(player: Player): Model?
   local assetId = Disguise.getAssetId(player)
   if not assetId then
      return nil
   end

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local mapData = currentRoundData and MapData[currentRoundData.CurrentMapName]
   local mapAssetId = mapData and mapData.DisguiseAssets and table.find(mapData.DisguiseAssets, assetId) and assetId

   local model = Instance.new("Model")
   model.Name = `{player.UserId}_Disguise_{mapAssetId or assetId}`

   local part = Instance.new("Part")
   part.Name = "DisguisePlaceholder"
   part.Size = Vector3.new(5, 5, 5)
   part.Anchored = true
   part.CanCollide = false
   part.CanTouch = false
   part.CanQuery = false
   part.Transparency = 0
   part.Parent = model
   model.PrimaryPart = part
   return model
end

local function employDisguise(player: Player)
   if not Disguise.isActive(player) or disguiseModels[player] then
      return
   end

   local disguiseModel = getDisguiseModel(player)
   if not disguiseModel then
      return
   end

   if localCharacterModels[player] then
      localCharacterModels[player].Parent = nil
   end
   disguiseModel.Parent = CharactersFolder
   disguiseModels[player] = disguiseModel
end

local function removeDisguise(player: Player)
   if disguiseModels[player] then
      disguiseModels[player]:Destroy()
      disguiseModels[player] = nil
   end

   if localCharacterModels[player] and player.Character then
      localCharacterModels[player].Parent = CharactersFolder
   end
end

local function syncDisguisePosition(player: Player, disguiseModel: Model)
   local character = player.Character
   if character and character.PrimaryPart then
      disguiseModel:PivotTo(character:GetPivot())
   end
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
         -- // LocalScript with AuthorityMode = Automatic, ModuleScript with AuthorityMode = Server
         if c.Name == "Animate" and (c:IsA("LocalScript") or c:IsA("ModuleScript")) then
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

   destroyPoseAnimationData(player)
   poseAnimationData[player] = {
      Animate = animateScript,
      Animator = customAnimator,
      Tracks = {},
      Active = {},
   }

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

-- // Loads (once) the rendered model's track for an Animate folder such as "walk"; picks the variant with the highest Weight
local function getPoseTrack(data: PoseAnimationData, animationName: string): AnimationTrack?
   local track = data.Tracks[animationName]
   if track then
      return track
   end
   local folder = data.Animate:FindFirstChild(animationName)
   if not folder then
      return nil
   end
   local bestAnimation: Animation? = nil
   local bestWeight = -math.huge
   for _, child in pairs(folder:GetChildren()) do
      if child:IsA("Animation") then
         local weightValue = child:FindFirstChild("Weight")
         local weight = if weightValue and weightValue:IsA("NumberValue") then weightValue.Value else 1
         if weight > bestWeight then
            bestAnimation = child
            bestWeight = weight
         end
      end
   end
   if not bestAnimation then
      return nil
   end
   track = data.Animator:LoadAnimation(bestAnimation)
   track.Looped = LOOPED_POSE_ANIMATIONS[animationName] == true
   track.Priority = if animationName == "toolnone" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Core
   data.Tracks[animationName] = track
   return track
end

local function getRenderedHeightScale(data: PoseAnimationData): number
   local humanoid = data.Animator.Parent
   if not humanoid or not humanoid:IsA("Humanoid") then
      return 1
   end
   local hipHeight = humanoid.HipHeight
   local dampening = data.Animate:FindFirstChild("ScaleDampeningPercent")
   if dampening and dampening:IsA("NumberValue") then
      return 1 + (hipHeight - HUMANOID_HIP_HEIGHT) * dampening.Value / HUMANOID_HIP_HEIGHT
   end
   return hipHeight / HUMANOID_HIP_HEIGHT
end

-- // Drives the rendered model from the authoritative character's replicated "pose" attribute (Server authority)
local function syncPoseAnimations(player: Player, authorityCharacter: Model, authorityRoot: BasePart, pose: string)
   local data = poseAnimationData[player]
   if not data then
      return
   end

   local wanted: {[string]: true} = {}
   local animationName = if pose:sub(1, 6) == "EMOTE_" then pose:sub(7) else POSE_TO_ANIMATION_NAME[pose]
   if animationName then
      wanted[animationName] = true
   end
   if pose == "Running" then
      wanted.run = true
   end
   if animationName and authorityCharacter:FindFirstChildOfClass("Tool") then
      wanted.toolnone = true
   end

   -- // Stop what's no longer wanted ("Dead", "PlatformStanding", etc. stop everything)
   for name, track in pairs(data.Tracks) do
      if not wanted[name] and track.IsPlaying then
         track:Stop(POSE_TRANSITION_TIME)
      end
   end

   -- // Start what's newly wanted; restart looped tracks that were stopped by something else
   for name in pairs(wanted) do
      local track = getPoseTrack(data, name)
      if track and not track.IsPlaying and (not data.Active[name] or track.Looped) then
         track:Play(POSE_TRANSITION_TIME)
      end
   end

   if pose == "Running" then
      local velocity = authorityRoot.AssemblyLinearVelocity
      local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
      local runSpeed = horizontalSpeed * 1.25 / getRenderedHeightScale(data)
      local walkWeight, runWeight, timeWarp = 0.0001, 0.0001, 1
      if runSpeed <= NORMALIZED_WALK_SPEED then
         walkWeight = 1
         timeWarp = runSpeed / NORMALIZED_WALK_SPEED
      elseif runSpeed < NORMALIZED_RUN_SPEED then
         local fadeInRun = (runSpeed - NORMALIZED_WALK_SPEED) / (NORMALIZED_RUN_SPEED - NORMALIZED_WALK_SPEED)
         walkWeight = 1 - fadeInRun
         runWeight = fadeInRun
      else
         timeWarp = runSpeed / NORMALIZED_RUN_SPEED
         runWeight = 1
      end
      local walkTrack = data.Tracks.walk
      local runTrack = data.Tracks.run
      if walkTrack then
         walkTrack:AdjustWeight(walkWeight)
         walkTrack:AdjustSpeed(timeWarp)
      end
      if runTrack then
         runTrack:AdjustWeight(runWeight)
         runTrack:AdjustSpeed(timeWarp)
      end
   end

   data.Active = wanted
end

local function setAuthoritativeCharacterTransparency(player: Player, transparency: number)
   if not player.Character then
      return
   end
   for _, d in pairs(player.Character:GetDescendants()) do
      if d:IsA("BasePart") then
         if d.Name:match("Hitbox") then
            continue
         end
         d.Transparency = transparency
      elseif d:IsA("Decal") then -- // e.g. the face
         d.Transparency = transparency
      end
   end
end

-- // The server-authoritative character is never meant to be seen; only the client-rendered model is
local function getHiddenAuthoritativeTransparency(): number
   return if GlobalConfig.AuthoritativeCharacterDebugVisible then 0.5 else 1
end

-- // Create fabricated character model
local function createCharacterModel(player: Player, canYield: boolean?)
   creatingCharacterModels[player] = true

   local sourceUserId = CharacterRenderLibrary.getCharacterSourceUserId(player.UserId)
   local sourceModel: Model?
   local localPlayer = Players.LocalPlayer
   sourceModel = CharacterRenderLibrary.getReplicatedModelForPlayer(localPlayer, player.UserId)
   if not sourceModel then
      sourceModel = CharacterRenderLibrary.getReplicatedModelForPlayer(localPlayer, sourceUserId)
   end

   if not sourceModel and canYield then
      local elapsed = 0
      repeat
         elapsed += RunService.Heartbeat:Wait()

         local loadedDescendants = 0
         local targetDescendants = 0

         sourceModel = CharacterRenderLibrary.getReplicatedModelForPlayer(localPlayer, player.UserId)
         if not sourceModel then
            sourceModel = CharacterRenderLibrary.getReplicatedModelForPlayer(localPlayer, sourceUserId)
         end

         if sourceModel then
            targetDescendants = sourceModel:GetAttribute("Descendants")
            if not targetDescendants then
               sourceModel = nil
               continue
            end
            for _, d in pairs(sourceModel:GetDescendants()) do
               loadedDescendants += 1
            end
            if loadedDescendants < targetDescendants then
               --warn(`skipping loaded model without enough descendants`)
               sourceModel = nil
            end
         end
      until sourceModel or elapsed > 5
   end

   if not sourceModel then
      warn(`CharacterRenderController: Missing replicated model for player {player.Name} ({player.UserId})`)
      creatingCharacterModels[player] = nil
      lastCreationLoadFailure[player] = os.clock()
      return
   end

   local model = sourceModel:Clone()
   model.Name = `{player.UserId}_LocalModel`

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

   local authorityCharacter = player.Character
   local authorityRoot = authorityCharacter and authorityCharacter:FindFirstChild("HumanoidRootPart")

   local function sync()
      local pose = authorityRoot and authorityRoot:GetAttribute("pose")
      if typeof(pose) == "string" then
         syncPoseAnimations(player, authorityCharacter :: Model, authorityRoot :: BasePart, pose)
         return
      end

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
            if syncedTrack then
               if not syncedTrack.IsPlaying then
                  syncedTrack:Play()
               end
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
      destroyPoseAnimationData(player)
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

   local customHumanoid = character:FindFirstChildOfClass("Humanoid")
   if not customHumanoid then
      return
   end

   local rootOffset = characterPositionOffsets[player]
   if not rootOffset then
      local pivot = character:GetPivot()
      rootOffset = pivot:PointToObjectSpace(renderedRoot.Position)
      characterPositionOffsets[player] = rootOffset
   end

   local hipHeightTestValue = game.Workspace:FindFirstChild("HipHeightTestValue")

   local heightOffset = ((2-customHumanoid.HipHeight)/customHumanoid.HipHeight)
   heightOffset = hipHeightTestValue.Value
   heightOffset = 2 - customHumanoid.HipHeight

   local pivot = character:GetPivot()
   local currentRotation = pivot - pivot.Position
   local adjustedPosition = targetRoot.Position - currentRotation:VectorToWorldSpace(rootOffset) - Vector3.new(0, heightOffset, 0)

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
      print(`recently failed to load replicated model for {player}, skipping creation`)
      return nil
   end
   return createCharacterModel(player, canYield)
end

local function everyFrame(deltaTime)
   for _, p in pairs(game.Players:GetPlayers()) do
      if disguiseModels[p] then
         if Disguise.isActive(p) then
            setAuthoritativeCharacterTransparency(p, 1)
            syncDisguisePosition(p, disguiseModels[p])
            continue
         end
         removeDisguise(p)
      end

      local model = getCharacterModel(p, false)
      if not model then
         -- // Still loading: stay hidden. Load failed: fall back to showing the authoritative character so the player isn't invisible
         local renderFailed = lastCreationLoadFailure[p] ~= nil and GlobalConfig.ShowAuthoritativeCharacterOnRenderFailure
         setAuthoritativeCharacterTransparency(p, if renderFailed then 0 else getHiddenAuthoritativeTransparency())
         continue
      end
      if not p.Character or not p.Character.PrimaryPart then
         model.Parent = nil
         continue -- Out of render distance or nonexistent
      end
      if model.Parent ~= CharactersFolder then
         model.Parent = CharactersFolder
      end
      setAuthoritativeCharacterTransparency(p, getHiddenAuthoritativeTransparency())
      syncCharacterPositions(p, model, p.Character)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderController.getCharacterModel(player: Player, canYield: boolean?): Model?
   if disguiseModels[player] then
      return disguiseModels[player]
   end
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

   CharacterMovementController.PlayerStoppedMoving:Add(function(player)
      if Disguise.isActive(player) then
         employDisguise(player)
      end
   end)

   CharacterMovementController.PlayerStartedMoving:Add(function(player)
      removeDisguise(player)
   end)

   Disguise.StateChanged:Add(function(userId: number, active: boolean)
      local player = Players:GetPlayerByUserId(userId)
      if not player then
         return
      end
      if active then
         if not CharacterMovementController.isMoving(player) then
            employDisguise(player)
         end
      else
         removeDisguise(player)
      end
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