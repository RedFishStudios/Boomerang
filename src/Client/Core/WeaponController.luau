-- // TEST: Fires throw remote when player presses E

local WeaponController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local ToolLogics = ReplicatedStorage.Shared.Logics.WeaponLogics
local ToolLogicModules = {}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local thrownBoomerangSpawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationEvent = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")

local UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local SOFT_CORRECTION_RATE = 14
local HARD_SNAP_DISTANCE = 14
local MAX_SNAPSHOT_CATCHUP = 0.35

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

local function createRaycastVisualizers()
   local visualizers = {}
   for i = 1, 3 do
      local part = Instance.new("Part")
      part.Size = Vector3.new(1, 1, 1)
      part.Anchored = true
      part.CanTouch = false
      part.CanQuery = false
      part.CanCollide = false
      part.Transparency = 1
      part.Parent = workspace
      visualizers[i] = part
   end
   return visualizers
end

local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

local function clearThrownWeapon(forPlayer: Player)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]
   if not thrownWeaponData then
      return
   end

   local toolData = Tools[thrownWeaponData.ToolId]
   if not toolData then
      ThrownWeapons.Data[forPlayer] = nil
      return
   end

   local logic = getLogic(toolData.LogicClass)
   logic.removeFromField(forPlayer, thrownWeaponData)
end

-- // Register a snapshot of a server-authoritative position
local function onSnapshot(forPlayer: Player, position: Vector3, direction: Vector3, speed: number, state: number, serverTime: number)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]
   if not thrownWeaponData or not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
      return
   end

   local previousState = thrownWeaponData.State
   local catchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, MAX_SNAPSHOT_CATCHUP)
   local authoritativePosition = position + direction * speed * catchup

   thrownWeaponData.ServerDirection = direction
   thrownWeaponData.ServerSpeed = speed
   thrownWeaponData.Direction = direction
   thrownWeaponData.Speed = speed

   if previousState ~= ThrownWeapons.StateEnum.Returning and state == ThrownWeapons.StateEnum.Returning then
      print(`client returning`)
      local toolData = Tools[thrownWeaponData.ToolId]
      if toolData then
         local logic = getLogic(toolData.LogicClass)
         logic.recall(forPlayer, thrownWeaponData.ToolId, toolData, thrownWeaponData, {
            InitialSpeed = speed,
         })
      end
   end

   thrownWeaponData.State = state

   local currentPosition = thrownWeaponData.Host:GetPivot().Position
   local errorDistance = (authoritativePosition - currentPosition).Magnitude
   if errorDistance >= HARD_SNAP_DISTANCE then
      local currentPivot = thrownWeaponData.Host:GetPivot()
      thrownWeaponData.Host:PivotTo((currentPivot - currentPivot.Position) + authoritativePosition)
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
      host:PivotTo((currentPivot - currentPivot.Position) + correctedPosition)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.startThrownWeapon(forPlayer: Player, toolId: string, toolData: Tools.Tool, initOptions)
   clearThrownWeapon(forPlayer)

   ThrownWeapons.Data[forPlayer] = {
      ToolId = toolId,
      State = ThrownWeapons.StateEnum.Outgoing,
      ReplicationPart = nil,
      TestRaycastVisualizers = createRaycastVisualizers(),
      SyncTargetPosition = nil,
      ServerDirection = nil,
      ServerSpeed = nil,
   }

   local logic = getLogic(toolData.LogicClass)
   logic.throw(forPlayer, toolId, toolData, ThrownWeapons.Data[forPlayer], initOptions)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WeaponController.init()
    thrownBoomerangSpawnedEvent.OnClientEvent:Connect(function(toolId: string, payload: buffer)
      local ownerUserId, offset = BufferUtil.readu32(payload, 0)
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
         return
      end

      local toolData = Tools[toolId]
      if not toolData then
         return
      end

      WeaponController.startThrownWeapon(forPlayer, toolId, toolData, {
         StartPosition = startPosition,
         Direction = getHorizontalDirection(direction),
         Speed = speed,
         ThrowServerTime = throwServerTime,
      })
   end)

   thrownBoomerangDespawnedEvent.OnClientEvent:Connect(function(payload: buffer)
      local ownerUserId = BufferUtil.readu32(payload, 0)
      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         return
      end
      clearThrownWeapon(forPlayer)
   end)

   thrownWeaponReplicationEvent.OnClientEvent:Connect(function(payload: buffer)
      local code, offset = BufferUtil.readu8(payload, 0)
      if code ~= UNRELIABLE_CODES.BoomerangSnapshot then
         return
      end

      local ownerUserId
      ownerUserId, offset = BufferUtil.readu32(payload, offset)
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

   RunService.PreSimulation:Connect(updateSmoothing)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			throwEvent:FireServer("ClassicBoomerang")
		end

		if input.KeyCode == Enum.KeyCode.F then
			recallEvent:FireServer()
		end
	end)
end

function WeaponController.start() end

return WeaponController
