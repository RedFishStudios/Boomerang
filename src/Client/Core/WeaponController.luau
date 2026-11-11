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
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local DeadWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Dead)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)
local SettingsController = require(ReplicatedStorage.Client.Core.SettingsController)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local BoomerangCurveLibrary = require(ReplicatedStorage.Shared.Library.BoomerangCurveLibrary)
local CharacterController = require(ReplicatedStorage.Client.Core.CharacterController)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
local ToolController = require(ReplicatedStorage.Client.Core.ToolController)
local BoomerangDebugController = require(ReplicatedStorage.Client.Core.BoomerangDebugController)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local PlayerStatsLibrary = require(ReplicatedStorage.Shared.Library.PlayerStatsLibrary)
local GameplayPhaseEnum = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local LobbyController = require(ReplicatedStorage.Client.Core.LobbyController)
local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)
local Telekinesis = require(ReplicatedStorage.Shared.Logics.PickupLogics.Telekinesis)

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
local aimCancelEvent = SimpleRemotes.getEvent("WeaponAimCancel") 
local throwFunction = SimpleRemotes.getFunction("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")
local weaponEquipStateEvent = SimpleRemotes.getEvent("WeaponEquipState")
local thrownBoomerangSpawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedEvent = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationEvent = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")
local recallChargeEvent = SimpleRemotes.getEvent("RecallCharge") -- // A dead boomerang's recall charge started / was cancelled (any player)

local UNRELIABLE_CODES = RemoteCodes.Weapon.Unreliable
local SOFT_CORRECTION_RATE = 14
local HARD_SNAP_DISTANCE = 8 -- // A position error this large is a teleport, not drift: snap instead of easing
local MAX_SNAPSHOT_CATCHUP = 0.35
local PORTAL_SNAPSHOT_GRACE = 0.5 -- // Seconds after the local boomerang passes a portal during which far-off snapshots count as stale

local chargeUpEffects: {
   [Player]: {
      Handle: ChargeUpEffectLibrary.ChargeUpEffectHandle, -- // Charge up effect applied when the aim began (fixed for the whole aim)
      AimStart: number
   }
} = {}
local pendingLocalThrow: {
   Token: {},
   ToolId: string,
   Host: Model,
}? = nil
local isAiming = false
-- // For code where a local isAiming shadows this one (e.g. the aim state event handler)
local function isLocalAimingNow(): boolean
   return isAiming
end
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

local MAX_RELEASE_DISTANCE_FROM_CHARACTER = 6 -- // A farther tool pivot is stale; release from the character instead

local function getHorizontalDirection(direction: Vector3): Vector3
   local horizontal = Vector3.new(direction.X, 0, direction.Z)
   if horizontal.Magnitude <= 1e-5 then
      return Vector3.new(0, 0, -1)
   end
   return horizontal.Unit
end

local function getWeaponState(): string
   if ThrownWeapons.Data[Players.LocalPlayer] or DeadWeapons.Data[Players.LocalPlayer] then
      return WeaponController.CurrentWeaponState.OnField
   end

   if isAiming then
      return WeaponController.CurrentWeaponState.Aiming
   end

   return WeaponController.CurrentWeaponState.InHand
end

local function clearDeadWeapon(forPlayer: Player, returnToPlayer: boolean?)
   local deadWeaponData = DeadWeapons.Data[forPlayer]
   if not deadWeaponData then
      return
   end

   DeadWeaponLogic.removeFromField(forPlayer, deadWeaponData, returnToPlayer ~= false)

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

local stopAiming -- // Defined below (removes a player's aim arrow)

-- // The local player's aim. The aim arrow follows it: removed when this goes false, created (on server confirmation)
-- // only
-- // while true. notifyServer: leaving aim without a throw, so the server must end its aim too (else it keeps the
-- // player
-- // aiming and shows the arrow to everyone).
local function setLocalAimState(nextState: boolean, notifyServer: boolean?)
   if isAiming == nextState then
      return
   end

   isAiming = nextState
   CharacterController.setAiming(nextState)

   if not nextState then
      CharacterController.setTouchAimAngle(nil)
      AnimationController.stopCoreAnimation(Players.LocalPlayer, "Charging")
      stopAiming(Players.LocalPlayer)
      if notifyServer then
         aimCancelEvent:FireServer()
      end
   end

   syncWeaponStateChanged()
end

local function clearThrownWeapon(forPlayer: Player, returnToPlayer: boolean?)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]
   if not thrownWeaponData then
      clearDeadWeapon(forPlayer, returnToPlayer)
      return
   end
   local toolData = Tools[thrownWeaponData.ToolId]
   if not toolData then
      -- // Unknown tool: clean up what the entry owns directly
      if thrownWeaponData.MovementConnection then
         thrownWeaponData.MovementConnection:Disconnect()
         thrownWeaponData.MovementConnection = nil
      end
      if thrownWeaponData.Host then
         thrownWeaponData.Host:Destroy()
      end
      local trailHost = thrownWeaponData.TrailObject and thrownWeaponData.TrailObject.TrailHost
      if trailHost then
         trailHost:Destroy()
      end
      if thrownWeaponData.FanTrail then
         thrownWeaponData.FanTrail:Destroy()
      end
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

   local equippedToolId = SkinLibrary.getWeaponClass(Players.LocalPlayer)
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
      localCharacter.Humanoid.WalkSpeed = BoomerangTuningLibrary.getForAnyTool(equippedToolId, "AimWalkSpeed") 
   end

   return true
end

-- // PC: what the mouse is on: another player's character (their UserId) or a bot such as a decoy (its BotId), by
-- // hitbox.
-- // The server curves the throw toward it if it's a reachable enemy (ThrowTargetLibrary). Only a direct click counts,
-- // not a near miss.
local function getEnemyUnderMouse(): (number | string)?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local filter: { Instance } = { workspace:WaitForChild("Characters") }
	local botsFolder = workspace:FindFirstChild("Bots")
	if botsFolder then
		table.insert(filter, botsFolder)
	end
	params.FilterDescendantsInstances = filter
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local model = result and result.Instance:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	if player and player ~= Players.LocalPlayer then
		return player.UserId
	end
	local botId = model and model:GetAttribute("BotId")
	if typeof(botId) == "string" then
		return botId
	end
	return nil
end

local function throwEquippedTool(forcedDirection: Vector3?): boolean
   if not isAiming then
      return false
   end

   if WeaponController.playerIsWeaponLocked() then
      setLocalAimState(false, true)
      return false
   end

   local equippedToolId = SkinLibrary.getWeaponClass(Players.LocalPlayer)
   if equippedToolId == nil then
      setLocalAimState(false, true)
      return false
   end

	local localCharacter = CharacterRenderController.getCharacterModel(localPlayer, true)
	local pendingHost, releasePosition = ToolController.prepareToolForThrow(Players.LocalPlayer)

	 -- // Aim from the character (like the aim arrow), not the tool model: under Server authority the tool's pivot can
	 -- // be
	 -- // stale (reported ~40 studs away), which sent every throw the same way.
	 local characterRoot = localCharacter and localCharacter.PrimaryPart
	 local throwOrigin = if characterRoot then characterRoot.Position else releasePosition
	 if releasePosition and characterRoot and (releasePosition - characterRoot.Position).Magnitude > MAX_RELEASE_DISTANCE_FROM_CHARACTER then
		releasePosition = nil
	 end

      local direction
      if forcedDirection and forcedDirection.Magnitude > 1e-5 then
         direction = getHorizontalDirection(forcedDirection)
      else
         -- // Throw exactly where the aim arrow points (the client's facing from CharacterController), independent of
         -- // the rendered
         -- // model's physics rotation and mouse behaviour at release.
         direction = getHorizontalDirection(CharacterController.LastCFrame.LookVector)
      end

	 if not releasePosition and throwOrigin then
		releasePosition = throwOrigin + direction * 3
	 end

	 -- // The point aimed at, so the server can curve the throw through it (BoomerangCurveLibrary). Only PC mouse aim
	 -- // (top-down
	 -- // camera) sends one: the mouse's spot on the floor. Other aim modes send none and the server picks the distance.
	 local aimTarget: Vector3? = nil
	 local clickedTarget: (number | string)? = nil
	 if not forcedDirection and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
	    and PlatformController.getDominantControlScheme() ~= "Touch" and PlatformController.getDominantControlScheme() ~= "Console" then
		aimTarget = CharacterController.getMouseGroundPosition()
		clickedTarget = getEnemyUnderMouse()
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

    
	throwFunction:InvokeServer(equippedToolId, direction, releasePosition, aimTarget, clickedTarget)
   setLocalAimState(false)

   return true
end

-- // Manual recall input: press and release are both sent to the server (it decides; see WeaponService).
-- // A live boomerang only needs the press; a dying/dead one returns only while held.
local isRecallHeld = false

-- // The recall keys (hold to recall a dead boomerang), shown by the recall prompt
WeaponController.RECALL_KEY = Enum.KeyCode.E
WeaponController.RECALL_GAMEPAD_KEY = Enum.KeyCode.ButtonY

-- // Whether the local player is holding recall right now
function WeaponController.isRecallHeld(): boolean
	return isRecallHeld
end

function WeaponController.beginRecallInput(): boolean
   local localPlayer = Players.LocalPlayer
   if not ThrownWeapons.Data[localPlayer] and not DeadWeapons.Data[localPlayer] then
      return false
   end
   isRecallHeld = true
   recallEvent:FireServer(true)
   return true
end

function WeaponController.endRecallInput()
   if not isRecallHeld then
      return
   end
   isRecallHeld = false
   recallEvent:FireServer(false)

   -- // Letting go of a charged manual recall drops the boomerang. Dropped locally at once, like the server, since
   -- // waiting for
   -- // its reply would let the boomerang fly on for a round trip and then snap back.
   local localPlayer = Players.LocalPlayer
   local thrownWeaponData = ThrownWeapons.Data[localPlayer]
   -- // Not if this client already predicted the catch: the server decides (it counts a release that close as a catch)
   if thrownWeaponData and thrownWeaponData.RecallFromDead == true and thrownWeaponData.State == ThrownWeapons.StateEnum.Returning
      and not thrownWeaponData.PendingCatchAt then
      local toolData = Tools[thrownWeaponData.ToolId]
      local logic = toolData and getLogic(toolData.LogicClass)
      if logic and logic.die then
         local direction = thrownWeaponData.Direction
         if not direction or direction.Magnitude < 1e-5 then
            direction = Vector3.new(0, 0, -1)
         end
         logic.die(localPlayer, thrownWeaponData, {
            Direction = direction,
            Speed = math.max(thrownWeaponData.Speed or 0, DeadWeaponLogic.getReleaseMomentum(1)), -- // Same floor as the server
         })
         local droppedData = DeadWeapons.Data[localPlayer]
         if droppedData then
            droppedData.ReleasedAtServerTime = workspace:GetServerTimeNow()
         end
      end
   end
end

function WeaponController.getWeaponState(): string
   return getWeaponState()
end

function WeaponController.handleEquippedToolButton(): string
   if ThrownWeapons.Data[Players.LocalPlayer] or DeadWeapons.Data[Players.LocalPlayer] then
      -- // On the field: the HUD button recalls through beginRecallInput/endRecallInput (press/release), not this tap
      return getWeaponState()
   elseif isAiming then
      throwEquippedTool()
   else
      beginEquippedToolAim()
   end

   return getWeaponState()
end

-- // Registers a snapshot of a server-authoritative position
-- // Players whose boomerang the server has despawned since its last Spawned. A Dying/Dead snapshot for a boomerang this client
-- // lacks rebuilds it (see onSnapshot), but never for these: those snapshots are stale (sent before the despawn).
-- // Weak keys: entries go away with the Player.
local despawnedSinceSpawn: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- // Rebuilds a dead boomerang this client is missing from the server's snapshot (Boomerang.restoreDeadFromSnapshot)
local function restoreMissingDeadWeapon(forPlayer: Player, position: Vector3, direction: Vector3, speed: number, state: number)
   local toolId = SkinLibrary.getWeaponClass(forPlayer)
   local toolData = toolId and Tools[toolId]
   if not toolData then
      return
   end
   local logic = getLogic(toolData.LogicClass)
   if not logic.restoreDeadFromSnapshot then
      return
   end
   local existingHost: Model? = nil
   if forPlayer == Players.LocalPlayer then
      existingHost = select(1, ToolController.prepareToolForThrow(forPlayer)) -- // Same as a throw: the held model is what lies on the field
   else
      ToolController.setToolVisible(forPlayer, false)
   end
   logic.restoreDeadFromSnapshot(forPlayer, toolId, {
      Position = position,
      Direction = direction,
      Speed = speed,
      IsDead = state == DeadWeapons.StateEnum.Dead,
      ExistingHost = existingHost,
   })
end

-- // The local simulation is already running the return (so a snapshot's movement state can be handed to it)
local function previousStateIsReturning(thrownWeaponData: ThrownWeapons.Data): boolean
   return thrownWeaponData.State == ThrownWeapons.StateEnum.Returning
end

local function onSnapshot(forPlayer: Player, position: Vector3, direction: Vector3, speed: number, state: number, serverTime: number, targetPosition: Vector3?, curvature: number?, recallTravelled: number?)
   local thrownWeaponData = ThrownWeapons.Data[forPlayer]

   -- // The server says this boomerang clashed with another and was knocked onto a new direction (it keeps flying)
   if state == ThrownWeapons.StateEnum.Deflected then
      local deflectedToolData = thrownWeaponData and Tools[thrownWeaponData.ToolId]
      local deflectedLogic = deflectedToolData and getLogic(deflectedToolData.LogicClass)
      if thrownWeaponData and deflectedLogic and deflectedLogic.deflect then
         deflectedLogic.deflect(forPlayer, thrownWeaponData, direction)
      end
      return
   end
   if not thrownWeaponData or not thrownWeaponData.Host or not thrownWeaponData.Host.Parent then
      -- // The server started returning a dying/dead boomerang (manual recall): follow it
      local deadWeaponData = DeadWeapons.Data[forPlayer]
      -- // Returning snapshots sent before the server received the owner's release are stale: ignore them, or the
      -- // dropped
      -- // boomerang would take off again. A genuinely new recall needs a fresh charge, so its snapshots are much
      -- // later.
      local releasedAt = deadWeaponData and deadWeaponData.ReleasedAtServerTime
      if releasedAt and state == ThrownWeapons.StateEnum.Returning
         and serverTime < releasedAt + 2 * Players.LocalPlayer:GetNetworkPing() + 0.15 then
         return
      end
      if state == ThrownWeapons.StateEnum.Returning and deadWeaponData and deadWeaponData.Host and deadWeaponData.Host.Parent then
         local deadToolData = Tools[deadWeaponData.ToolId]
         local deadLogic = deadToolData and getLogic(deadToolData.LogicClass)
         if deadLogic and deadLogic.recallFromDead then
            -- // A manual recall is always the end of a charge (the RecallCharge event started one on this client too);
            -- // otherwise the
            -- // server is recalling it by itself (sliding away, player back in sight...): an automatic recall, which
            -- // has no
            -- // SelectionRing, Summon animation or beams.
            local isManualRecall = DeadWeaponLogic.isRecallCharging(deadWeaponData)
            deadLogic.recallFromDead(forPlayer, deadWeaponData, isManualRecall)
            -- // This client starts the recall when the server's word arrives, after the server already started flying
            -- // it: ease it to
            -- // where the server has it now (the eased-in part doesn't count toward a hard snap)
            local recalledData = ThrownWeapons.Data[forPlayer]
            if recalledData and recalledData.CFrame and targetPosition and deadLogic.advanceReturn then
               local recallCatchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, MAX_SNAPSHOT_CATCHUP)
               local advancedPosition, advancedVelocity, advancedTravelled = deadLogic.advanceReturn({
                  ToolId = recalledData.ToolId,
                  Position = position,
                  Velocity = direction * speed,
                  Target = targetPosition,
                  RecallTravelled = 0,
                  IsManualRecall = isManualRecall,
                  ReturnSpeedMultiplier = recalledData.ReturnSpeedMultiplier,
                  Seconds = recallCatchup,
               })
               local offset = advancedPosition - recalledData.CFrame.Position
               recalledData.SyncCorrection = Vector3.new(offset.X, 0, offset.Z)
               recalledData.SnapshotReturnVelocity = advancedVelocity
               recalledData.SnapshotRecallTravelled = advancedTravelled
            end
         end
         return
      end
      -- // The server has a dying/dead boomerang this client lacks (desync, or joined after the throw): rebuild it
      if not thrownWeaponData and not deadWeaponData and not despawnedSinceSpawn[forPlayer]
         and (state == DeadWeapons.StateEnum.Dying or state == DeadWeapons.StateEnum.Dead) then
         restoreMissingDeadWeapon(forPlayer, position, direction, speed, state)
         return
      end
      DeadWeaponLogic.applyServerSnapshot(forPlayer, position, direction, speed, state, serverTime)
      return
   end

   local previousState = thrownWeaponData.State

   local catchup = math.clamp(workspace:GetServerTimeNow() - serverTime, 0, MAX_SNAPSHOT_CATCHUP)
   local authoritativePosition = position + direction * speed * catchup
   local advancedReturnVelocity: Vector3? = nil -- // A thrown boomerang's return, caught up to now (heading/speed for its loop)
   local returnCatchUpStart = false
   -- // A returning boomerang speeds up and steers toward the thrower, so a straight line is far off at high speed: replay the
   -- // server's return movement over the catch-up time and hand the result to the local simulation.
   -- // Only from the return loop's own snapshots (it has started flying, recallTravelled > 0): the snapshot sent as a return
   -- // starts has a heading straight at the thrower, not the real velocity (still flying outward and turning around),
   -- // and
   -- // replaying it sent the local boomerang back early, 20-40 studs off under lag
   if state == ThrownWeapons.StateEnum.Returning and previousStateIsReturning(thrownWeaponData) and recallTravelled and recallTravelled > 0 and targetPosition then
      local returnToolData = Tools[thrownWeaponData.ToolId]
      local returnLogic = returnToolData and getLogic(returnToolData.LogicClass)
      if returnLogic and returnLogic.advanceReturn then
         local advancedPosition, advancedVelocity, advancedTravelled = returnLogic.advanceReturn({
            ToolId = thrownWeaponData.ToolId,
            Position = position,
            Velocity = direction * speed,
            Target = targetPosition,
            RecallTravelled = recallTravelled,
            IsManualRecall = thrownWeaponData.RecallFromDead == true,
            ReturnSpeedMultiplier = thrownWeaponData.ReturnSpeedMultiplier,
            Seconds = catchup,
         })
         authoritativePosition = advancedPosition
         thrownWeaponData.SnapshotReturnVelocity = advancedVelocity
         thrownWeaponData.SnapshotRecallTravelled = advancedTravelled
      end
   elseif state == ThrownWeapons.StateEnum.Returning and thrownWeaponData.RecallFromDead == nil
      and (recallTravelled == nil or recallTravelled < 0) and targetPosition then
      -- // A thrown boomerang returning on its own (the throw's loop steers it home): same steering, without the manual
      -- // recall's
      -- // speed-up. Its loop adopts the caught-up heading and speed through SnapshotDirection / SnapshotSpeed (set
      -- // below).
      -- // The first Returning snapshot is where it turns around: this client held it at 0 energy until the server's
      -- // verdict arrived,
      -- // so the distance the server has already flown back is eased in, not snapped.
      returnCatchUpStart = not previousStateIsReturning(thrownWeaponData)
      local returnToolData = Tools[thrownWeaponData.ToolId]
      local returnLogic = returnToolData and getLogic(returnToolData.LogicClass)
      if returnLogic and returnLogic.advanceReturn then
         local advancedPosition, advancedVelocity = returnLogic.advanceReturn({
            ToolId = thrownWeaponData.ToolId,
            Position = position,
            Velocity = direction * speed,
            Target = targetPosition,
            RecallTravelled = 0,
            IsManualRecall = false,
            ReturnSpeedMultiplier = thrownWeaponData.ReturnSpeedMultiplier,
            Seconds = catchup,
         })
         authoritativePosition = advancedPosition
         if advancedVelocity.Magnitude > 1e-5 then
            advancedReturnVelocity = advancedVelocity
         end
      end
   end
   -- // A curving boomerang has kept turning since the snapshot: advance it along its arc (position and heading) so the
   -- // prediction matches the server's current state
   if curvature and state ~= ThrownWeapons.StateEnum.Returning then
      local maxCurvature = BoomerangCurveLibrary.getMaxCurvature()
      curvature = if curvature == curvature then math.clamp(curvature, -maxCurvature, maxCurvature) else 0
      thrownWeaponData.Curvature = curvature
      if curvature ~= 0 then
         local displacement
         displacement, direction = BoomerangCurveLibrary.advanceAlongArc(direction, curvature, speed * catchup)
         authoritativePosition = position + displacement
      end
   end

   -- // Just went through a portal locally: snapshots sent before the server's own crossing are stale (still on the
   -- // entry
   -- // side). Skip them briefly instead of snapping the boomerang back through the portal.
   local simulatedPosition = if thrownWeaponData.CFrame then thrownWeaponData.CFrame.Position else thrownWeaponData.Host:GetPivot().Position
   local recentlyCrossedPortal = thrownWeaponData.PortalExitAt ~= nil and os.clock() - thrownWeaponData.PortalExitAt < PORTAL_SNAPSHOT_GRACE
   if recentlyCrossedPortal and previousState == state and (authoritativePosition - simulatedPosition).Magnitude >= HARD_SNAP_DISTANCE then
      return
   end

   thrownWeaponData.ServerDirection = direction
   thrownWeaponData.ServerSpeed = speed
   thrownWeaponData.Direction = direction
   thrownWeaponData.Speed = speed
   -- // The simulation adopts the server's heading and speed on its next step (position is eased below)
   thrownWeaponData.SnapshotDirection = direction
   thrownWeaponData.SnapshotSpeed = speed
   if advancedReturnVelocity then
      thrownWeaponData.SnapshotDirection = getHorizontalDirection(advancedReturnVelocity)
      thrownWeaponData.SnapshotSpeed = advancedReturnVelocity.Magnitude
   end
   thrownWeaponData.ServerTargetPosition = targetPosition

   if previousState ~= state then
      local toolData = Tools[thrownWeaponData.ToolId]
      if toolData then
         local logic = getLogic(toolData.LogicClass)
         if state == ThrownWeapons.StateEnum.Returning then
            logic.recall(forPlayer, thrownWeaponData.ToolId, toolData, thrownWeaponData, {
               InitialSpeed = speed,
            })
         elseif state == DeadWeapons.StateEnum.Dying and logic.die then
            logic.die(forPlayer, thrownWeaponData, {
               Direction = direction,
               Speed = speed,
               Position = position,
            })
         end
      end
   end

   if state == DeadWeapons.StateEnum.Dying then
      return
   end

   thrownWeaponData.State = state

   -- // Already caught on this client (hidden until the server confirms): don't correct its invisible last moments
   if thrownWeaponData.PendingCatchAt then
      return
   end

   local positionError = authoritativePosition - simulatedPosition
   if returnCatchUpStart then
      -- // The turnaround: ease the server's head start in (see above)
      thrownWeaponData.SyncCorrection = positionError
      BoomerangDebugController.recordSnapshot(forPlayer, thrownWeaponData, 0, speed, state, false, catchup, positionError.Magnitude)
      return
   end
   -- // A correction still being eased in (e.g. a fresh throw catching up to the server) is where the boomerang is
   -- // already
   -- // headed, not drift: only the error beyond it decides a hard snap
   local pendingCorrection = thrownWeaponData.SyncCorrection or Vector3.zero
   local errorDistance = (positionError - pendingCorrection).Magnitude
   BoomerangDebugController.recordSnapshot(forPlayer, thrownWeaponData, errorDistance, speed, state, errorDistance >= HARD_SNAP_DISTANCE, catchup, pendingCorrection.Magnitude)
   if errorDistance >= HARD_SNAP_DISTANCE then
      local currentPivot = thrownWeaponData.Host:GetPivot()
      local snappedCFrame = (currentPivot - currentPivot.Position) + authoritativePosition
      -- // A hard snap is a teleport: let the old trail fade in place instead of stretching across the jump
      local snapToolData = Tools[thrownWeaponData.ToolId]
      local snapLogic = snapToolData and getLogic(snapToolData.LogicClass)
      if snapLogic and snapLogic.retireTrail then
         snapLogic.retireTrail(thrownWeaponData)
      end
      thrownWeaponData.CFrame = snappedCFrame
      thrownWeaponData.LastPosition = authoritativePosition
      thrownWeaponData.Host:PivotTo(snappedCFrame)
      thrownWeaponData.SyncCorrection = nil
      return
   end

   -- // Not a position to drag toward (the boomerang keeps moving) but the remaining error to ease out each frame
   thrownWeaponData.SyncCorrection = positionError
end

-- // Eases each boomerang's remaining position error (from the latest snapshot) out of its simulated position, a
-- // fraction per frame
local function updateSmoothing(deltaTime: number)
   for _, thrownWeaponData in pairs(ThrownWeapons.Data) do
      local correction = thrownWeaponData.SyncCorrection
      if not correction then
         continue
      end
      local host = thrownWeaponData.Host
      local simCFrame = thrownWeaponData.CFrame
      if not host or not host.Parent or not simCFrame then
         continue
      end

      local alpha = if correction.Magnitude <= 0.05 then 1 else math.clamp(deltaTime * SOFT_CORRECTION_RATE, 0, 1)
      local step = correction * alpha
      thrownWeaponData.CFrame = simCFrame + step
      if thrownWeaponData.LastPosition then
         thrownWeaponData.LastPosition += step
      end
      host:PivotTo(host:GetPivot() + step)
      thrownWeaponData.SyncCorrection = if alpha >= 1 then nil else correction - step
   end
end

-- // Bumped on every stop/begin, so a beginAiming that yielded (waiting for the character model) can tell it was
-- // overtaken by a stop and must not create a leftover arrow
local chargeUpEffectGeneration: { [Player]: number } = {}

function stopAiming(player: Player)
   chargeUpEffectGeneration[player] = (chargeUpEffectGeneration[player] or 0) + 1
   AnimationController.stopCoreAnimation(player, "Charging")
   local chargeUpEffect = chargeUpEffects[player]
   if chargeUpEffect then
      chargeUpEffect.Handle:remove()
      chargeUpEffects[player] = nil
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
      setLocalAimState(false, true)
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

local chargeUpEffectConnection: RBXScriptConnection? = nil

local function renderChargeUpEffects()
   if chargeUpEffectConnection then
      return
   end
   chargeUpEffectConnection = RunService.RenderStepped:Connect(function()
      if not next(chargeUpEffects) then
         chargeUpEffectConnection:Disconnect()
         chargeUpEffectConnection = nil
         return
      end
      for p, arrows in pairs(chargeUpEffects) do
         if p == Players.LocalPlayer and not isAiming then
            stopAiming(p) -- // The local arrow never outlives the local aim, whatever created it
            continue
         end

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

         local timeSinceAimStart = os.clock() - arrows.AimStart
         local aimStrengthAlpha = math.clamp(timeSinceAimStart / BoomerangTuningLibrary.getForAnyTool(SkinLibrary.getWeaponClass(Players.LocalPlayer), "ChargeTime"), 0, 1) 
         local characterCFrame = if p == Players.LocalPlayer then CharacterController.LastCFrame else humanoidRootPart.CFrame
         -- // The held boomerang the throw leaves from (a pivot too far from the character is stale: none, like the
         -- // throw)
         local throwOrigin = ToolController.getToolPivotPosition(p)
         if throwOrigin and (throwOrigin - humanoidRootPart.Position).Magnitude > MAX_RELEASE_DISTANCE_FROM_CHARACTER then
            throwOrigin = nil
         end

         -- // The effect's logic module animates it from the charge progress (see Shared/Logics/ChargeUpEffects)
         arrows.Handle:update({
            Alpha = aimStrengthAlpha,
            RootPart = humanoidRootPart,
            AimCFrame = characterCFrame,
            ThrowOrigin = throwOrigin,
            LengthScale = if p == Players.LocalPlayer then (SettingsController.getValue("AimArrowLength") :: number) / 100 else 1,
         })
      end
   end)
end

local function beginAiming(player: Player)
   local generation = (chargeUpEffectGeneration[player] or 0) + 1
   chargeUpEffectGeneration[player] = generation
   local character = CharacterRenderController.getCharacterModel(player, true) -- // Can yield (model being built)
   if not character then
      return
   end
   -- // The aim may have ended (throw/cancel) or a newer begin started while waiting
   if chargeUpEffectGeneration[player] ~= generation or (player == Players.LocalPlayer and not isAiming) then
      return
   end

   local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
   if not humanoidRootPart then
      return
   end

   if chargeUpEffects[player] then
      stopAiming(player)
   end

   AnimationController.playCoreAnimation(player, "Charging")

   -- // Every client applies each player's charge up effect locally. The equipped id is replicated on the Player and
   -- // validated
   -- // by ChargeUpEffectLibrary (an unknown or not-yet-replicated value uses the default effect); it names the logic
   -- // module
   -- // in Shared/Logics/ChargeUpEffects that applies and animates the effect.
   -- // With others' Cosmetic Effects setting off, other players charge with the default effect (this player's own
   -- // still shows)
   local showsEquipped = player == Players.LocalPlayer or SettingsController.getValue("ShowCosmeticEffects") == true
   local logic = if showsEquipped then ChargeUpEffectLibrary.getLogicFor(player) else ChargeUpEffectLibrary.getLogic(ChargeUpEffectLibrary.getDefaultId())
   chargeUpEffects[player] = {
      Handle = logic.apply(player, character),
      AimStart = os.clock()
   }
   renderChargeUpEffects()
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
      SyncCorrection = nil,
      ServerDirection = nil,
      ServerSpeed = nil,
   }

   local logic = getLogic(toolData.LogicClass)
   logic.throw(forPlayer, toolId, toolData, ThrownWeapons.Data[forPlayer], initOptions)
end

function WeaponController.beginThumbstickAim(): boolean
   if Telekinesis.isLocalSteering() then
      return true -- // Steering a thrown boomerang (Telekinesis), not starting a new aim
   end
   return beginEquippedToolAim()
end

function WeaponController.setThumbstickAimDirection(angle: number?)
   if Telekinesis.isLocalSteering() then
      Telekinesis.setTouchAngle(angle) -- // Feeds the steer direction; doesn't begin aiming
      return
   end
   if typeof(angle) == "number" then
      CharacterController.setTouchAimAngle(angle)
      beginEquippedToolAim()
      return
   end

   CharacterController.setTouchAimAngle(nil)
end

function WeaponController.releaseThumbstickAim(lastAngle: number?): boolean
   if Telekinesis.isLocalSteering() then
      Telekinesis.setTouchAngle(nil) -- // Stops steering; no throw
      return false
   end
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
         stopAiming(forPlayer) -- // A "stop aiming" must never be dropped, or the arrow stays
         return
      end

      if forPlayer == Players.LocalPlayer then
         if isAiming and not isLocalAimingNow() then
            -- // A late confirmation of an aim the player already left (released, locked, round change):
            -- // no arrow, and the server ends its aim too
            aimCancelEvent:FireServer()
            return
         end
         if not isAiming then
            setLocalAimState(false)
         end
      end

      ToolController.setAimState(forPlayer, isAiming)

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
      local curvature = 0 -- // The curve the server decided for this throw
      if buffer.len(payload) >= offset + 4 then
         curvature = BufferUtil.readf32(payload, offset)
      end

      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         warn(`no player source found for userId: {ownerUserId}`)
         return
      end
      despawnedSinceSpawn[forPlayer] = nil -- // A new boomerang; its snapshots may rebuild it if this client loses it

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
         Curvature = curvature,
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
      despawnedSinceSpawn[forPlayer] = true -- // Snapshots still in flight for this boomerang must not rebuild it
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
      -- // The thrower's position follows the time (dead-weapon snapshots don't carry it)
      local targetPosition: Vector3? = nil
      if buffer.len(payload) >= offset + 12 then
         targetPosition, offset = BufferUtil.readVector3_96(payload, offset)
      end
      -- // The boomerang's current curve (dead-weapon snapshots don't carry it)
      local curvature: number? = nil
      if buffer.len(payload) >= offset + 4 then
         curvature, offset = BufferUtil.readf32(payload, offset)
      end
      -- // Distance a returning boomerang has flown since its recall started (-1 = not returning)
      local recallTravelled: number? = nil
      if buffer.len(payload) >= offset + 4 then
         recallTravelled = BufferUtil.readf32(payload, offset)
      end

      local forPlayer = Players:GetPlayerByUserId(ownerUserId)
      if not forPlayer then
         return
      end

      onSnapshot(forPlayer, position, getHorizontalDirection(direction), speed, state, serverTime, targetPosition, curvature, recallTravelled)
   end)

   RunService.PreSimulation:Connect(function(deltaTime)
      updateSmoothing(deltaTime)
      DeadWeaponLogic.updateSmoothing(deltaTime)
      getLogic("Boomerang").updatePendingCatches() -- // Shows a boomerang again if the server never confirmed the predicted catch
      DeadWeaponLogic.updateRecallCharges(deltaTime) -- // Lifts / drops charging dead boomerangs (same timestamps as the server)
   end)

   -- // The server says a dead boomerang started charging a recall (it lifts) or the charge was released (it drops)
   recallChargeEvent.OnClientEvent:Connect(function(playerUserId: number, action: string, serverTime: number, a: number?, b: number?, c: number?)
      local chargingPlayer = Players:GetPlayerByUserId(playerUserId)
      if chargingPlayer then
         DeadWeaponLogic.applyRecallChargeEvent(chargingPlayer, action, serverTime, a, b, c)
      end
   end)

   local gameStateData = GameStateLibrary.getGameStateData()
   gameStateData.GameplayPhase:Subscribe(function(gameplayPhase)
      if gameplayPhase == GameplayPhaseEnum.LobbyVoting then
         setLocalAimState(false, true)
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

      if input.KeyCode == WeaponController.RECALL_KEY or input.KeyCode == WeaponController.RECALL_GAMEPAD_KEY then
			WeaponController.beginRecallInput()
		end
	end)

   -- Parrying is registered as an Ability and handled via AbilityController

   UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
      -- // Always deliver the recall release (even if a gui took the input), so a held recall can't get stuck
      if input.KeyCode == WeaponController.RECALL_KEY or input.KeyCode == WeaponController.RECALL_GAMEPAD_KEY then
         WeaponController.endRecallInput()
      end
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

   -- // A leaving player's boomerangs are removed here: the server's despawn for them can't be matched to them once they're gone
   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      if ThrownWeapons.Data[player] then
         clearThrownWeapon(player, false)
      end
      if DeadWeapons.Data[player] then
         clearDeadWeapon(player, false)
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
