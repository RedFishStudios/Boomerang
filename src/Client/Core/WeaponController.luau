-- // TEST: Fires throw remote when player presses E

local WeaponController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = game.Players.LocalPlayer

local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local ClashedWeapons = require(ReplicatedStorage.Shared.Referential.ClashedWeapons)
local ClashedWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Clashed)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local RaycastsUtility = require(ReplicatedStorage.Shared.Utils.RaycastsUtility)
local CharacterController = require(ReplicatedStorage.Client.Core.CharacterController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
local ToolController = require(ReplicatedStorage.Client.Core.ToolController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local LobbyController = require(ReplicatedStorage.Client.Core.LobbyController)

local ToolLogics = ReplicatedStorage.Shared.Logics.WeaponLogics
local ToolLogicModules = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

WeaponController.CurrentWeaponState = {
   InHand = 0,
   Aiming = 1,
   OnField = 2
}

WeaponController.WeaponStateChanged = TasksList.new() :: TasksList.TasksList<number>

------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local aimEvent = SimpleRemotes.getEvent("WeaponAim")
local aimStateEvent = SimpleRemotes.getEvent("WeaponAimState")
local throwFunction = SimpleRemotes.getFunction("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local weaponEquipStateEvent = SimpleRemotes.getEvent("WeaponEquipState")
local thrownBoomerangSpawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationEvent = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")

local aimArrowTemplate = ReplicatedStorage.Shared.Assets.Gui.AimArrow

local UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local SOFT_CORRECTION_RATE = 14
local HARD_SNAP_DISTANCE = 14
local MAX_SNAPSHOT_CATCHUP = 0.35

local aimArrows: {
   [Player]: {
      Instance: Instance,
      AimStart: number
   }
} = {}
local pendingLocalThrow: {
   Token: {},
   ToolId: string,
   Host: Model,
}? = nil
local isAiming = false
local currentWeaponState = WeaponController.CurrentWeaponState.InHand
local isWeaponVisuallyLocked = false
local weaponLockHeartbeatConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(toolId: string)
	if not ToolLogicModules[toolId] then
		local module = require(ToolLogics:WaitForChild(toolId))
		ToolLogicModules[toolId] = module
	end
	return ToolLogicModules[toolId]
end

local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

local function getWeaponState(): string
   if ThrownWeapons.Data[Players.LocalPlayer] or ClashedWeapons.Data[Players.LocalPlayer] then
      return WeaponController.CurrentWeaponState.OnField
   end

   if isAiming then
      return WeaponController.CurrentWeaponState.Aiming
   end

   return WeaponController.CurrentWeaponState.InHand
end

local function clearClashedWeapon(forPlayer: Player, returnToPlayer: boolean?)
   local clashedWeaponData = ClashedWeapons.Data[forPlayer]
   if not clashedWeaponData then
      return
   end

   ClashedWeaponLogic.removeFromField(forPlayer, clashedWeaponData, returnToPlayer ~= false)

   if returnToPlayer ~= false and forPlayer ~= Players.LocalPlayer then
      ToolController.setToolVisible(forPlayer, true)
   end
end

local function syncWeaponStateChanged()
   local newWeaponState = getWeaponState()
   if newWeaponState == currentWeaponState then
      return
   end

   currentWeaponState = newWeaponState
   WeaponController.WeaponStateChanged:Execute("serial", newWeaponState)
end

local function setLocalAimState(nextState: boolean)
   if isAiming == nextState then
      return
   end

   isAiming = nextState
   CharacterController.setAiming(nextState)

   if not nextState then
      CharacterController.setTouchAimAngle(nil)
      AnimationController.stopCoreAnimation(Players.LocalPlayer, "Charging")
   end

   syncWeaponStateChanged()
end

local function clearThrownWeapon(forPlayer: Player, returnToPlayer: boolean?)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]
   if not thrownWeaponData then
      clearClashedWeapon(forPlayer, returnToPlayer)
      return
   end
   local toolData = Tools[thrownWeaponData.ToolId]
   if not toolData then
      ThrownWeapons.Data[forPlayer] = nil
      return
   end

   local logic = getLogic(toolData.LogicClass)
   logic.removeFromField(forPlayer, thrownWeaponData, {
      ReturnToPlayer = returnToPlayer ~= false,
   })

   if returnToPlayer ~= false and forPlayer ~= Players.LocalPlayer then
      ToolController.setToolVisible(forPlayer, true)
   end
end

local function beginEquippedToolAim(): boolean
   if isAiming then
      return true
   end

   if WeaponController.playerIsWeaponLocked() then
      return false
   end

   local equippedToolId = GlobalConfig.ForceEquippedTool
   if equippedToolId == nil then
      return false
   end

   local canThrow = WeaponLibrary.canThrow(Players.LocalPlayer, equippedToolId)
   if not canThrow then
      return false
   end

	aimEvent:FireServer(equippedToolId)
	setLocalAimState(true)
   local localCharacter = CharacterRenderController.getCharacterModel(localPlayer, true)
   if localCharacter and localCharacter:FindFirstChildOfClass("Humanoid") then
      AnimationController.playCoreAnimation(Players.LocalPlayer, "Charging")
      localCharacter.Humanoid.WalkSpeed = GlobalConfig.AimingWalkSpeed
   end

   return true
end

local function throwEquippedTool(forcedDirection: Vector3?): boolean
   if not isAiming then
      return false
   end

   if WeaponController.playerIsWeaponLocked() then
      setLocalAimState(false)
      return false
   end

   local equippedToolId = GlobalConfig.ForceEquippedTool
   if equippedToolId == nil then
      setLocalAimState(false)
      return false
   end

	local localCharacter = CharacterRenderController.getCharacterModel(localPlayer, true)
	local pendingHost, releasePosition = ToolController.prepareToolForThrow(Players.LocalPlayer)

	 local throwOrigin = releasePosition
	 if not throwOrigin and localCharacter and localCharacter.PrimaryPart then
		throwOrigin = localCharacter.PrimaryPart.Position
	 end

      local direction
      if forcedDirection and forcedDirection.Magnitude > 1e-5 then
         direction = getHorizontalDirection(forcedDirection)
      elseif PlatformController.getDominantControlScheme() == "Touch" or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition) then
      direction = getHorizontalDirection(localCharacter.PrimaryPart.CFrame.LookVector)
    else
      local lastInWorld = PlatformController.getLastMousePositionInWorld()
      local mouseWorldPosition = RaycastsUtility.getMouseWorldPosition(2048, nil, if lastInWorld then Vector2.new(lastInWorld.X, lastInWorld.Y) else nil)
      if throwOrigin and mouseWorldPosition then
         direction = getHorizontalDirection(mouseWorldPosition - throwOrigin)
      elseif localCharacter and localCharacter.PrimaryPart then
         direction = getHorizontalDirection(localCharacter.PrimaryPart.CFrame.LookVector)
      else
         direction = Vector3.new(0, 0, -1)
      end
    end

	 if not releasePosition and throwOrigin then
		releasePosition = throwOrigin + direction * 3
	 end

	 if pendingHost then
		local pendingToken = {}
		pendingLocalThrow = {
			Token = pendingToken,
         ToolId = equippedToolId,
			Host = pendingHost,
		}

		task.delay(0.75, function()
			if pendingLocalThrow and pendingLocalThrow.Token == pendingToken then
				pendingLocalThrow = nil
				ToolController.finishToolThrow(Players.LocalPlayer)
			end
		end)
	 end

    
	throwFunction:InvokeServer(equippedToolId, direction, releasePosition)
   setLocalAimState(false)

   return true
end

local function recallEquippedTool(): boolean
   if not ThrownWeapons.Data[Players.LocalPlayer] then
      return false
   end

   recallEvent:FireServer()
   return true
end

function WeaponController.getWeaponState(): string
   return getWeaponState()
end

function WeaponController.handleEquippedToolButton(): string
   if ThrownWeapons.Data[Players.LocalPlayer] then
      recallEquippedTool()
   elseif ClashedWeapons.Data[Players.LocalPlayer] then
      return getWeaponState()
   elseif isAiming then
      throwEquippedTool()
   else
      beginEquippedToolAim()
   end

   return getWeaponState()
end

-- // Register a snapshot of a server-authoritative position
local function onSnapshot(forPlayer: Player, position: Vector3, direction: Vector3, speed: number, state: number, serverTime: number)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]
   if not thrownWeaponData or not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
      ClashedWeaponLogic.applyServerSnapshot(forPlayer, position, direction, speed, state, serverTime)
      return
   end

   local previousState = thrownWeaponData.State

   local catchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, MAX_SNAPSHOT_CATCHUP)
   local authoritativePosition = position + direction * speed * catchup

   thrownWeaponData.ServerDirection = direction
   thrownWeaponData.ServerSpeed = speed
   thrownWeaponData.Direction = direction
   thrownWeaponData.Speed = speed

   if previousState ~= state then
      local toolData = Tools[thrownWeaponData.ToolId]
      if toolData then
         local logic = getLogic(toolData.LogicClass)
         if state == ThrownWeapons.StateEnum.Returning then
            logic.recall(forPlayer, thrownWeaponData.ToolId, toolData, thrownWeaponData, {
               InitialSpeed = speed,
            })
         elseif state == ClashedWeapons.StateEnum.Clashed and logic.clash then
            logic.clash(forPlayer, thrownWeaponData, {
               Direction = direction,
               Speed = speed,
               Position = position,
            })
         end
      end
   end

   if state == ClashedWeapons.StateEnum.Clashed then
      return
   end

   thrownWeaponData.State = state

   local currentPosition = thrownWeaponData.Host:GetPivot().Position
   local errorDistance = (authoritativePosition - currentPosition).Magnitude
   if errorDistance >= HARD_SNAP_DISTANCE then
      local currentPivot = thrownWeaponData.Host:GetPivot()
      local snappedCFrame = (currentPivot - currentPivot.Position) + authoritativePosition
      thrownWeaponData.CFrame = snappedCFrame
      thrownWeaponData.Host:PivotTo(snappedCFrame)
      thrownWeaponData.SyncTargetPosition = nil
      return
   end

   thrownWeaponData.SyncTargetPosition = authoritativePosition
end

-- // Sync client-rendered positions smoothly to server-authoritative positions
local function updateSmoothing(deltaTime: number)
   for _, thrownWeaponData in pairs(ThrownWeapons.Data) do
      if not thrownWeaponData.SyncTargetPosition then
         continue
      end
      if not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
         continue
      end

      local host = thrownWeaponData.Host
      local currentPivot = host:GetPivot()
      local currentPosition = currentPivot.Position
      local targetPosition = thrownWeaponData.SyncTargetPosition
      local errorDistance = (targetPosition - currentPosition).Magnitude

      if errorDistance <= 0.05 then
         thrownWeaponData.SyncTargetPosition = nil
         continue
      end

      local alpha = math.clamp(deltaTime * SOFT_CORRECTION_RATE, 0, 1)
      local correctedPosition = currentPosition:Lerp(targetPosition, alpha)
      local correctedCFrame = (currentPivot - currentPivot.Position) + correctedPosition
      thrownWeaponData.CFrame = correctedCFrame
      host:PivotTo(correctedCFrame)
   end
end

local function stopAiming(player: Player)
   AnimationController.stopCoreAnimation(player, "Charging")
   local aimArrow = aimArrows[player]
   if aimArrow then
      aimArrow.Instance:Destroy()
      aimArrows[player] = nil
   end
end

local function disconnectWeaponLockHeartbeat()
   if weaponLockHeartbeatConnection then
      weaponLockHeartbeatConnection:Disconnect()
      weaponLockHeartbeatConnection = nil
   end
end

local function setLocalWeaponLocked(isLocked: boolean)
   if isWeaponVisuallyLocked == isLocked then
      return
   end
   isWeaponVisuallyLocked = isLocked

   if isLocked then
      setLocalAimState(false)
      stopAiming(localPlayer)
      ToolController.setAimState(localPlayer, false)
      ToolController.setWeaponLocked(localPlayer, true)
   else
      ToolController.setWeaponLocked(localPlayer, false)
   end
end

local function observeWeaponLockTimestamp()
   if not WeaponController.playerIsWeaponLocked() then
      disconnectWeaponLockHeartbeat()
      setLocalWeaponLocked(false)
      return
   end

   setLocalWeaponLocked(true)
   if weaponLockHeartbeatConnection then
      return
   end

   weaponLockHeartbeatConnection = RunService.Heartbeat:Connect(function()
      if WeaponController.playerIsWeaponLocked() then
         return
      end

      disconnectWeaponLockHeartbeat()
      setLocalWeaponLocked(false)
   end)
end

local remoteWeaponLockedPlayers: {[Player]: true} = {}
local remoteWeaponLockHeartbeatConnection: RBXScriptConnection? = nil

local function setRemoteWeaponLocked(player: Player, isLocked: boolean)
   if (remoteWeaponLockedPlayers[player] ~= nil) == isLocked then
      return
   end

   if isLocked then
      remoteWeaponLockedPlayers[player] = true
      stopAiming(player)
      ToolController.setAimState(player, false)
      ToolController.setWeaponLocked(player, true)
   else
      remoteWeaponLockedPlayers[player] = nil
      ToolController.setWeaponLocked(player, false)
   end
end

local function observeRemoteWeaponLock(player: Player)
   setRemoteWeaponLocked(player, WeaponController.playerIsWeaponLocked(player))

   if next(remoteWeaponLockedPlayers) == nil then
      if remoteWeaponLockHeartbeatConnection then
         remoteWeaponLockHeartbeatConnection:Disconnect()
         remoteWeaponLockHeartbeatConnection = nil
      end
      return
   end

   if remoteWeaponLockHeartbeatConnection then
      return
   end

   remoteWeaponLockHeartbeatConnection = RunService.Heartbeat:Connect(function()
      for lockedPlayer in pairs(remoteWeaponLockedPlayers) do
         if not lockedPlayer.Parent then
            remoteWeaponLockedPlayers[lockedPlayer] = nil
         elseif not WeaponController.playerIsWeaponLocked(lockedPlayer) then
            setRemoteWeaponLocked(lockedPlayer, false)
         end
      end

      if next(remoteWeaponLockedPlayers) == nil and remoteWeaponLockHeartbeatConnection then
         remoteWeaponLockHeartbeatConnection:Disconnect()
         remoteWeaponLockHeartbeatConnection = nil
      end
   end)
end

local aimArrowConnection: RBXScriptConnection? = nil

local function renderAimArrows()
   if aimArrowConnection then
      return
   end
   aimArrowConnection = RunService.RenderStepped:Connect(function()
      if not next(aimArrows) then
         aimArrowConnection:Disconnect()
         aimArrowConnection = nil
         return
      end
      for p, arrows in pairs(aimArrows) do
         local character = CharacterRenderController.getCharacterModel(p, false)
         if not character then
            stopAiming(p)
            continue
         end

         local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
         if not humanoidRootPart then
            stopAiming(p)
            continue
         end

         local fullSize = aimArrowTemplate.PrimaryPart.Size
         local startSize = fullSize * .7
         local timeSinceAimStart = os.clock() - arrows.AimStart
         local aimStrengthAlpha = math.clamp(timeSinceAimStart / GlobalConfig.AimFullStrength, 0, 1)
         local currentSize = startSize:Lerp(fullSize, aimStrengthAlpha)
         arrows.Instance.PrimaryPart.Size = currentSize
         arrows.Instance.PrimaryPart.SurfaceGui.CanvasGroup.GroupTransparency = (1 - aimStrengthAlpha)

         local characterCFrame = if p == Players.LocalPlayer then CharacterController.LastCFrame else humanoidRootPart.CFrame

         local distance = 3 + ((GlobalConfig.AimFullStrength * aimStrengthAlpha)*2.5)
         local aimArrow = arrows.Instance
         local arrowOffset = Vector3.new(0, -2, 0) + (characterCFrame.LookVector.Unit * distance)
         local arrowPosition = humanoidRootPart.Position + arrowOffset
         aimArrow:PivotTo(CFrame.new(arrowPosition, arrowPosition + characterCFrame.LookVector))

         -- Shaking
         local frameThatShakes = arrows.Instance.PrimaryPart.SurfaceGui.CanvasGroup.Arrows
         local defaultPosition = aimArrowTemplate.PrimaryPart.SurfaceGui.CanvasGroup.Arrows.Position
         if aimStrengthAlpha > .8 then
            local now = os.clock()
            local shakeAlpha = (aimStrengthAlpha - 0.8) / 0.2
            local defaultOffsetMagnitude = math.max(1, math.abs(defaultPosition.X.Offset) + math.abs(defaultPosition.Y.Offset))
            local maxShakePixels = defaultOffsetMagnitude * 0.25
            local shakePixels = maxShakePixels * shakeAlpha

            -- Use smooth noise so direction shifts fluidly over multiple frames.
            local shakeX = (math.noise(p.UserId * 0.11, now * 4.5, 0) * shakePixels) * 100
            local shakeY = (math.noise((p.UserId + 97) * 0.11, now * 4.5, 0) * shakePixels) * 100
            frameThatShakes.Position = UDim2.new(
               defaultPosition.X.Scale,
               defaultPosition.X.Offset + shakeX,
               defaultPosition.Y.Scale,
               defaultPosition.Y.Offset + shakeY
            )
         else
            frameThatShakes.Position = defaultPosition
         end
      end
   end)
end

local function beginAiming(player: Player)
   local character = CharacterRenderController.getCharacterModel(player, true)
   if not character then
      return
   end

   local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
   if not humanoidRootPart then
      return
   end

   if aimArrows[player] then
      stopAiming(player)
   end

   AnimationController.playCoreAnimation(player, "Charging")

   local aimArrow = aimArrowTemplate:Clone()
   aimArrow.Name = `AimArrow_{player.UserId}`
   aimArrow.Parent = game.Workspace
   aimArrow.PrimaryPart.Anchored = true
   aimArrows[player] = {
      Instance = aimArrow,
      AimStart = os.clock()
   }
   renderAimArrows()
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.playerIsWeaponLocked(player: Player?): boolean
   return WeaponLibrary.playerIsWeaponLocked(player)
end

function WeaponController.startThrownWeapon(forPlayer: Player, toolId: string, toolData: Tools.Tool, initOptions)
   clearThrownWeapon(forPlayer)

   ThrownWeapons.Data[forPlayer] = {
      OwnerUserId = forPlayer.UserId,
      ToolId = toolId,
      State = ThrownWeapons.StateEnum.Outgoing,
      ReplicationPart = nil,
      SyncTargetPosition = nil,
      ServerDirection = nil,
      ServerSpeed = nil,
   }

   local logic = getLogic(toolData.LogicClass)
   logic.throw(forPlayer, toolId, toolData, ThrownWeapons.Data[forPlayer], initOptions)
end

function WeaponController.beginThumbstickAim(): boolean
   return beginEquippedToolAim()
end

function WeaponController.setThumbstickAimDirection(angle: number?)
   if typeof(angle) == "number" then
      CharacterController.setTouchAimAngle(angle)
      beginEquippedToolAim()
      return
   end

   CharacterController.setTouchAimAngle(nil)
end

function WeaponController.releaseThumbstickAim(lastAngle: number?): boolean
   if typeof(lastAngle) == "number" then
      CharacterController.setTouchAimAngle(lastAngle)
   end

   local forcedDirection = CharacterController.getTouchAimLookVector(lastAngle)
   local threwTool = throwEquippedTool(forcedDirection)
   CharacterController.setTouchAimAngle(nil)
   return threwTool
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.init()
   RunService.Heartbeat:Connect(function(dt)
      syncWeaponStateChanged()
   end)

   weaponEquipStateEvent.OnClientEvent:Connect(function(playerUserId: number, action: string, value)
      local forPlayer = Players:GetPlayerByUserId(playerUserId)
      if not forPlayer then
         return
      end

      if action == "Equip" then
         if typeof(value) == "string" then
            ToolController.setEquippedTool(forPlayer, value, "weaponEquipStateEvent_Equip")
         end
      elseif action == "Unequip" then
         ToolController.setEquippedTool(forPlayer, nil, "weaponEquipStateEvent_Unequip")
      elseif action == "SetVisible" then
         if forPlayer == Players.LocalPlayer then
            return
         end
         if typeof(value) == "boolean" then
            ToolController.setToolVisible(forPlayer, value)
         end
      end
   end)

   aimStateEvent.OnClientEvent:Connect(function(playerUserId: number, isAiming: boolean)
      local forPlayer = Players:GetPlayerByUserId(playerUserId)
      if not forPlayer then
         return
      end

      if forPlayer == localPlayer and WeaponController.playerIsWeaponLocked() then
         setLocalWeaponLocked(true)
         return
      end

      ToolController.setAimState(forPlayer, isAiming)

      if forPlayer == Players.LocalPlayer then
         setLocalAimState(isAiming)
      end

      if isAiming then
         beginAiming(forPlayer)
      else
         stopAiming(forPlayer)
      end
   end)

   thrownBoomerangSpawnedEvent.OnClientEvent:Connect(function(toolId: string, payload: buffer, instanceId: string)
   local ownerUserId, offset = BufferUtil.readUserId(payload, 0)
      local startPosition
      startPosition, offset = BufferUtil.readVector3_96(payload, offset)
      local direction
      direction, offset = BufferUtil.readVector3_96(payload, offset)
      local speed
      speed, offset = BufferUtil.readf32(payload, offset)
      local throwServerTime
      throwServerTime, offset = BufferUtil.readf64(payload, offset)

      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         warn(`no player source found for userId: {ownerUserId}`)
         return
      end

      local toolData = Tools[toolId]
      if not toolData then
         warn(`no tool data found for toolId: {toolId}`)
         return
      end

      local startOptions = {
         StartPosition = startPosition,
         Direction = getHorizontalDirection(direction),
         Speed = speed,
         InstanceId = instanceId,
         ThrowServerTime = throwServerTime,
      }

      if forPlayer == Players.LocalPlayer then
         local existingHost: Model? = nil
         if pendingLocalThrow and pendingLocalThrow.ToolId == toolId then
            existingHost = pendingLocalThrow.Host
            pendingLocalThrow = nil
         else
            existingHost = select(1, ToolController.prepareToolForThrow(forPlayer))
         end

         if existingHost then
            startOptions.ExistingHost = existingHost
         end
      else
         ToolController.setToolVisible(forPlayer, false)
      end

      WeaponController.startThrownWeapon(forPlayer, toolId, toolData, startOptions)
   end)

   thrownBoomerangDespawnedEvent.OnClientEvent:Connect(function(payload: buffer)
      local ownerUserId, offset = BufferUtil.readUserId(payload, 0)
      local returnToPlayer = BufferUtil.readu8(payload, offset) == 1
      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         return
      end
      clearThrownWeapon(forPlayer, returnToPlayer)
   end)

   thrownWeaponReplicationEvent.OnClientEvent:Connect(function(payload: buffer)
      local code, offset = BufferUtil.readu8(payload, 0)
      if code ~= UNRELIABLE_CODES.BoomerangSnapshot then
         return
      end

      local ownerUserId
      ownerUserId, offset = BufferUtil.readUserId(payload, offset)
      local position
      position, offset = BufferUtil.readVector3_96(payload, offset)
      local direction
      direction, offset = BufferUtil.readVector3_96(payload, offset)
      local speed
      speed, offset = BufferUtil.readf32(payload, offset)
      local state
      state, offset = BufferUtil.readu8(payload, offset)
      local serverTime
      serverTime, offset = BufferUtil.readf64(payload, offset)

      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         return
      end

      onSnapshot(forPlayer, position, getHorizontalDirection(direction), speed, state, serverTime)
   end)

   RunService.PreSimulation:Connect(function(deltaTime)
      updateSmoothing(deltaTime)
      ClashedWeaponLogic.updateSmoothing(deltaTime)
   end)

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase)
      if gameplayPhase == GameplayPhaseEnum.LobbyVoting then
         setLocalAimState(false)
         pendingLocalThrow = nil
         AnimationController.stopAllCoreAnimations(Players.LocalPlayer)
      end
   end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

      if input.UserInputType == Enum.UserInputType.MouseButton2 then
         beginEquippedToolAim()
		end

      if input.KeyCode == Enum.KeyCode.E then
			recallEvent:FireServer()
		end
	end)

   -- NOTE: Parrying is registered as an Ability and handled via AbilityController

   UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
      if gameProcessed then
         return
      end 

      if input.UserInputType == Enum.UserInputType.MouseButton2 then
       throwEquippedTool(nil)
      end
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
      stopAiming(player)
      if player == Players.LocalPlayer then
         setLocalAimState(false)
         pendingLocalThrow = nil
      end
      ToolController.clearRenderedTool(player)
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, character: Model, humanoid: Humanoid)
      stopAiming(player)
      if player == Players.LocalPlayer then
         setLocalAimState(false)
      end
   end)

   PlayerStatsLibrary.StatChangedTasks:Add(function(player: Player, statName: string, value)
      if statName ~= "WeaponLockedUntilTimestamp" then
         return
      end

      if player == localPlayer then
         observeWeaponLockTimestamp()
      else
         observeRemoteWeaponLock(player)
      end
   end)

   observeWeaponLockTimestamp()
   for _, player in ipairs(Players:GetPlayers()) do
      if player ~= localPlayer then
         observeRemoteWeaponLock(player)
      end
   end
end

function WeaponController.start() end

return WeaponController
