--[[
	Telekinesis (pickup)

	While the effect is active, the owner steers their THROWN boomerang while it flies out. Everyone sees a bright cyan SelectionRing
	around it (the same asset the manual recall uses).

	How the player steers:
	  - PC, top-down camera: the boomerang turns toward the mouse cursor.
	  - PC, over-the-shoulder camera: nothing yet (TODO, see TASKS.md).
	  - Mobile: it turns toward the direction the aim button is dragged. While a thrown boomerang exists and the effect is active the
	    aim button steers instead of aiming a new throw.
	  - Console: nothing yet (TODO, see TASKS.md).

	How it works (same on every machine that steers, so they agree):
	  - The owner's client works out the direction it wants every frame and streams it to the server (about 20 per second, "TelekinesisSteer"),
	    and also applies it to its own boomerang at once so the owner sees no delay.
	  - The server validates it (the effect is active, a boomerang is thrown) and keeps it on the thrown weapon with the time it arrived.
	    A direction that stops arriving expires on its own (STEER_STALE_SECONDS), so letting go always stops the steering.
	  - Both flight loops (WeaponLogics/Boomerang) call Telekinesis.steer() each fixed step with the current direction (Telekinesis.getBias).
	  - Other clients don't steer: they follow the server's snapshots like any boomerang. The owner's client keeps its own heading
	    while it steers (see Boomerang.luau) because the server's heading is always a little behind the owner's input; the server's position
	    corrections keep the two together.
]]

local Telekinesis = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

-------------------------------------------------------------------------------
-- SETTINGS (tune here)
-------------------------------------------------------------------------------

-- // How strongly a Telekinesis boomerang turns toward the direction the player wants, per second.
-- //   Higher = sharper turns: the boomerang swings quickly to point exactly where the player wants.
-- //   Lower = a gentle nudge: the player only bends its path, without precise control.
-- // (It is the rate at which the remaining turn closes: 2 closes about 86% of it each second, 6 closes almost all of it in a second.)
Telekinesis.STEER_STRENGTH = 2

local STEER_STALE_SECONDS = 0.35 -- // A steer direction older than this is ignored (the owner let go, or the updates stopped arriving)
local STEER_SEND_INTERVAL = 0.05 -- // Seconds between streamed steer updates (caps network traffic)
local STEER_RESEND_DOT = 0.9995 -- // Also send sooner when the wanted direction turns by more than about 1.8 degrees
local MIN_CURSOR_DISTANCE = 1 -- // Studs: a cursor this close to the boomerang gives no direction
local RING_COLOR = Color3.fromRGB(0, 255, 255)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

type RingEntry = {
	Ring: MeshPart,
	Tweens: { Tween },
}

local RING_CONTAINER_NAME = "TelekinesisSelectionRings"
local RING_START_SIZE = Vector3.new(0.001, 0.001, 0.001)

-- // Client only
local activePlayers: { [Player]: boolean } = {} -- // Players whose Telekinesis effect is active (replicated to every client)
local rings: { [Player]: RingEntry } = {}
local ringContainer: Folder? = nil
local ringTemplate: MeshPart? = nil
local ringFullSize: Vector3 = Vector3.one
local ringRotation: CFrame = CFrame.identity
local ringConnection: RBXScriptConnection? = nil
local localSteeringConnection: RBXScriptConnection? = nil
local touchAngle: number? = nil -- // Mobile: the angle the aim button is dragged to (nil = not dragging)
local lastSentDirection: Vector3? = nil
local lastSentAt = 0
local steerRemote: any = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS (shared)
-------------------------------------------------------------------------------

-- // Steer while flying out (an automatic return already pulls the boomerang toward the player)
local function isSteerableState(state: number?): boolean
	return state == ThrownWeapons.StateEnum.Outgoing or state == ThrownWeapons.StateEnum.Exhausted
end

local function getHorizontalUnit(vector: Vector3): Vector3?
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 1e-3 then
		return nil
	end
	return horizontal.Unit
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (shared)
-------------------------------------------------------------------------------

-- // The direction (horizontal unit) the owner currently wants this thrown weapon to head, or nil. Old directions expire.
function Telekinesis.getBias(thrownWeaponData: ThrownWeapons.Data): Vector3?
	local bias = thrownWeaponData.TelekinesisBias
	if not bias then
		return nil
	end
	local setAt = thrownWeaponData.TelekinesisBiasAt
	if setAt and os.clock() - setAt > STEER_STALE_SECONDS then
		return nil
	end
	return bias
end

-- // `direction` turned toward `bias` for one step of `deltaTime` seconds (both horizontal). Frame-rate independent, and it turns the
-- // short way round (including when the wanted direction is straight behind).
function Telekinesis.steer(direction: Vector3, bias: Vector3, deltaTime: number): Vector3
	local current = getHorizontalUnit(direction)
	local wanted = getHorizontalUnit(bias)
	if not current or not wanted then
		return direction
	end
	local alpha = 1 - math.exp(-Telekinesis.STEER_STRENGTH * deltaTime)
	local angle = math.atan2(current:Cross(wanted).Y, current:Dot(wanted)) -- // Signed turn from current to wanted, about +Y
	return CFrame.fromAxisAngle(Vector3.yAxis, angle * alpha):VectorToWorldSpace(current)
end

-------------------------------------------------------------------------------
-- SERVER
-------------------------------------------------------------------------------

-- // WeaponService passes on what the owner's client streamed. A zero direction means "let go".
function Telekinesis.onSteerReceived(player: Player, direction: unknown)
	if typeof(direction) ~= "Vector3" or direction ~= direction then -- // (a NaN is never equal to itself)
		return
	end
	local thrownWeaponData = ThrownWeapons.Data[player]
	if not thrownWeaponData then
		return
	end
	local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
	if not PickupLibrary.isEffectActive(player.UserId, "Telekinesis") then
		return
	end
	local horizontal = getHorizontalUnit(direction)
	thrownWeaponData.TelekinesisBias = horizontal
	thrownWeaponData.TelekinesisBiasAt = if horizontal then os.clock() else nil
end

-------------------------------------------------------------------------------
-- CLIENT: steering input (the local player)
-------------------------------------------------------------------------------

-- // Where the local player wants their boomerang to head right now, by control scheme. Add the missing schemes here.
local function getLocalSteerDirection(thrownWeaponData: ThrownWeapons.Data): Vector3?
	local PlatformController = require(ReplicatedStorage.Client.Core.PlatformController)
	local CharacterController = require(ReplicatedStorage.Client.Core.CharacterController)
	local CustomCameraController = require(ReplicatedStorage.Client.Core.CustomCameraController)

	local scheme = PlatformController.getDominantControlScheme()
	if scheme == "Touch" then
		if touchAngle == nil then
			return nil
		end
		local lookVector = CharacterController.getTouchAimLookVector(touchAngle)
		return if lookVector then getHorizontalUnit(lookVector) else nil
	elseif scheme == "Console" then
		return nil -- // TODO: console steering (see TASKS.md)
	end

	-- // PC
	if CustomCameraController.getMode() ~= "Overhead" then
		return nil -- // TODO: steering with the over-the-shoulder camera (see TASKS.md)
	end
	local cursorPosition = CharacterController.getMouseGroundPosition()
	local weaponCFrame = thrownWeaponData.CFrame
	local host = thrownWeaponData.Host
	local weaponPosition = if weaponCFrame then weaponCFrame.Position elseif host and host.Parent then host:GetPivot().Position else nil
	if not cursorPosition or not weaponPosition then
		return nil
	end
	local toCursor = Vector3.new(cursorPosition.X - weaponPosition.X, 0, cursorPosition.Z - weaponPosition.Z)
	if toCursor.Magnitude < MIN_CURSOR_DISTANCE then
		return nil
	end
	return toCursor.Unit
end

local function sendSteer(direction: Vector3)
	if not steerRemote then
		steerRemote = SimpleRemotes.getUnreliableEvent("TelekinesisSteer")
	end
	steerRemote:FireServer(direction)
end

local function updateLocalSteering()
	local thrownWeaponData = ThrownWeapons.Data[Players.LocalPlayer]
	local direction: Vector3? = nil
	if thrownWeaponData and isSteerableState(thrownWeaponData.State) then
		direction = getLocalSteerDirection(thrownWeaponData)
	end

	-- // The owner's own boomerang steers right away (the flight loop reads this); the server gets the same direction streamed
	if thrownWeaponData then
		thrownWeaponData.TelekinesisBias = direction
		thrownWeaponData.TelekinesisBiasAt = if direction then os.clock() else nil
	end

	if direction then
		local now = os.clock()
		if lastSentDirection == nil or now - lastSentAt >= STEER_SEND_INTERVAL or direction:Dot(lastSentDirection) < STEER_RESEND_DOT then
			sendSteer(direction)
			lastSentDirection = direction
			lastSentAt = now
		end
	elseif lastSentDirection ~= nil then
		sendSteer(Vector3.zero) -- // Let go (if this is lost the server's copy expires by itself)
		lastSentDirection = nil
	end
end

local function startLocalSteering()
	if localSteeringConnection then
		return
	end
	localSteeringConnection = RunService.Heartbeat:Connect(updateLocalSteering)
end

local function stopLocalSteering()
	if localSteeringConnection then
		localSteeringConnection:Disconnect()
		localSteeringConnection = nil
	end
	touchAngle = nil
	if lastSentDirection ~= nil then
		sendSteer(Vector3.zero)
		lastSentDirection = nil
	end
	local thrownWeaponData = ThrownWeapons.Data[Players.LocalPlayer]
	if thrownWeaponData then
		thrownWeaponData.TelekinesisBias = nil
		thrownWeaponData.TelekinesisBiasAt = nil
	end
end

-- // True while the local player's Telekinesis is active and their boomerang is steerable. WeaponController then sends the mobile aim
-- // button here instead of starting a throw.
function Telekinesis.isLocalSteering(): boolean
	if isServer or localSteeringConnection == nil then
		return false
	end
	local thrownWeaponData = ThrownWeapons.Data[Players.LocalPlayer]
	return thrownWeaponData ~= nil and isSteerableState(thrownWeaponData.State)
end

-- // Mobile: the angle the aim button is dragged to (nil = let go)
function Telekinesis.setTouchAngle(angle: number?)
	touchAngle = angle
end

-------------------------------------------------------------------------------
-- CLIENT: the SelectionRing (every player's, so everyone sees whose boomerang is steered)
-------------------------------------------------------------------------------

local function getRingContainer(): Folder
	if ringContainer and ringContainer.Parent then
		return ringContainer
	end
	local existing = workspace:FindFirstChild(RING_CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		ringContainer = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = RING_CONTAINER_NAME
	folder.Parent = workspace
	ringContainer = folder
	return folder
end

local function getWeaponPosition(player: Player): Vector3?
	local thrownWeaponData = ThrownWeapons.Data[player]
	if not thrownWeaponData or not isSteerableState(thrownWeaponData.State) then
		return nil
	end
	local host = thrownWeaponData.Host
	if host and host.Parent and (host:IsA("Model") or host:IsA("BasePart")) then
		return host:GetPivot().Position
	end
	return nil
end

local function createRing(player: Player, position: Vector3)
	if not ringTemplate then
		return
	end
	local ring = ringTemplate:Clone()
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.CastShadow = false
	ring.Color = RING_COLOR
	ring.Size = RING_START_SIZE
	ring.Transparency = 1
	ring.CFrame = CFrame.new(position) * ringRotation
	ring.Parent = getRingContainer()

	local growSeconds = GlobalConfig.SelectionRingGrowSeconds
	local sizeTween = TweenService:Create(ring, TweenInfo.new(growSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = ringFullSize })
	local transparencyTween = TweenService:Create(ring, TweenInfo.new(growSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 })
	sizeTween:Play()
	transparencyTween:Play()

	rings[player] = { Ring = ring, Tweens = { sizeTween, transparencyTween } }
end

-- // immediate = destroy now (the effect ended or the player left); otherwise it shrinks away (the boomerang is no longer steerable)
local function removeRing(player: Player, immediate: boolean)
	local entry = rings[player]
	if not entry then
		return
	end
	rings[player] = nil
	for _, tween in entry.Tweens do
		tween:Cancel()
	end
	table.clear(entry.Tweens)

	local ring = entry.Ring
	if immediate or not ring.Parent then
		ring:Destroy()
		return
	end
	local vanishSeconds = GlobalConfig.SelectionRingVanishSeconds
	local vanishTween = TweenService:Create(ring, TweenInfo.new(vanishSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = RING_START_SIZE, Transparency = 1 })
	vanishTween.Completed:Once(function()
		ring:Destroy()
	end)
	vanishTween:Play()
	Debris:AddItem(ring, vanishSeconds + 1) -- // Safety net: a ring is never left behind
end

-- // Every frame: the ring exists exactly while the player's Telekinesis is active and their boomerang can be steered
local function reconcileRings()
	for player in activePlayers do
		if player.Parent == nil then
			activePlayers[player] = nil
			removeRing(player, true)
			continue
		end
		local position = getWeaponPosition(player)
		local entry = rings[player]
		if position then
			if entry and entry.Ring.Parent then
				entry.Ring.CFrame = CFrame.new(position) * ringRotation
			else
				if entry then
					removeRing(player, true)
				end
				createRing(player, position)
			end
		elseif entry then
			removeRing(player, false)
		end
	end
end

local function startRings()
	if ringConnection then
		return
	end
	if not ringTemplate then
		task.spawn(function()
			-- // The asset's current size is the ring's full (100%) size
			local template = ReplicatedStorage.Shared:WaitForChild("Assets"):WaitForChild("SelectionRing") :: MeshPart
			ringFullSize = template.Size
			ringRotation = template.CFrame.Rotation
			ringTemplate = template
		end)
	end
	ringConnection = RunService.RenderStepped:Connect(reconcileRings)
end

local function stopRingsIfUnused()
	if next(activePlayers) == nil and ringConnection then
		ringConnection:Disconnect()
		ringConnection = nil
	end
end

-------------------------------------------------------------------------------
-- PICKUP HOOKS (PickupController / PickupService)
-------------------------------------------------------------------------------

-- // Called on the server and on every client for the player who got the effect. (A client's own activation passes the UserId.)
function Telekinesis.onPickup(player: Player | number, startedAt: number?): number
	local effectPlayer = if typeof(player) == "number" then Players:GetPlayerByUserId(player) else player
	if effectPlayer and not isServer then
		activePlayers[effectPlayer] = true
		startRings()
		if effectPlayer == Players.LocalPlayer then
			startLocalSteering()
		end
	end

	return (startedAt or workspace:GetServerTimeNow()) + GlobalConfig.GenericEffectTimeout
end

function Telekinesis.onEnd(player: Player)
	if isServer then
		local thrownWeaponData = ThrownWeapons.Data[player]
		if thrownWeaponData then
			thrownWeaponData.TelekinesisBias = nil
			thrownWeaponData.TelekinesisBiasAt = nil
		end
		return
	end

	activePlayers[player] = nil
	removeRing(player, true)
	stopRingsIfUnused()
	if player == Players.LocalPlayer then
		stopLocalSteering()
	end
end

return Telekinesis
