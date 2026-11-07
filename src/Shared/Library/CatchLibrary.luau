--[[
	CatchLibrary

	Catching a returning boomerang: which catch it is, and the heavy catch's push.
	  - Normal or heavy: by how fast the boomerang is closing in on the catcher just before contact (its velocity minus the
	    catcher's, along the line from the boomerang to them). At or above the HeavyCatchSpeed tuning setting it's heavy.
	  - Heavy push: a grounded heavy catch shoves the catcher back HeavyCatchPushDistance studs over HeavyCatchPushSeconds,
	    away from the incoming boomerang, fastest at first. It's shortened in front of walls and stops short of an edge or
	    water.
	  - With server authority over characters it's run like the dash: started and moved inside the simulation step, on the
	    server and on the catcher's own client from the same replicated input, its state kept in attributes on the
	    HumanoidRootPart (rolled back and replayed with it). The client sees its catch later than the server does, so the
	    client starts it: its predicted heavy catch presses HeavyPushAction (the push direction). The server goes along
	    only if it had a heavy catch for that player just before, or that player's manual recall is about to arrive, and
	    pushes on its own if the input never comes.
]]

local CatchLibrary = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local BoomerangTuningLibrary = require(ReplicatedStorage.Shared.Library.BoomerangTuningLibrary)
local BoomerangDebugLibrary = require(ReplicatedStorage.Shared.Library.BoomerangDebugLibrary)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)

local isServer = RunService:IsServer()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local MIN_TOWARD_DISTANCE = 0.01
local BODY_SIZE = Vector3.new(2, 4, 1) -- // Blockcast for walls in the push's way (torso width, step height to head)
local WALL_MARGIN = 0.3
local GROUND_PROBE_STEP = 0.5 -- // Studs between ground checks along the push
local BODY_BELOW_ROOT = 3 -- // Feet are this far below the root (R6), as in the dash
local GROUND_PROBE_DEPTH = BODY_BELOW_ROOT + 5 -- // Studs below the root a probe looks for ground (any deeper is an edge)
local MIN_GROUND_NORMAL_Y = 0.65

local PUSH_ACTION_NAME = "HeavyPushAction"
local INPUT_HOLD_SECONDS = 0.15 -- // How long the client holds the push input after its predicted catch
local INPUT_WAIT_SECONDS = 0.35 -- // Server: how long after its heavy catch (on top of the player's ping) it waits for the input
local EARLY_INPUT_SECONDS = 0.25 -- // Server: an input counts before its own heavy catch if the manual recall is this close (seconds out)
local CATCH_MEMORY_SECONDS = 1.5 -- // Server: how long a heavy catch is remembered (and an accepted push blocks another)

-- // Push state, on the HumanoidRootPart
local ATTRIBUTE_INPUT_HELD = "HeavyPushInputHeld" -- // The push input's state last step (a push starts when it's pressed)
local ATTRIBUTE_STARTED_AT = "HeavyPushStartedAt" -- // time() the latest push started
local ATTRIBUTE_ENDS_AT = "HeavyPushEndsAt" -- // time() it ends; 0 once it's over
local ATTRIBUTE_DIRECTION = "HeavyPushDirection"
local ATTRIBUTE_START = "HeavyPushStart" -- // Root position it started from
local ATTRIBUTE_DISTANCE = "HeavyPushDistance"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type CatchInfo = {
	Heavy: boolean,
	ClosingSpeed: number,
	Direction: Vector3, -- // Horizontal unit direction the boomerang is moving in, relative to the catcher (the push direction)
}

type ServerCatch = {
	Direction: Vector3,
	At: number, -- // os.clock()
	Pushed: boolean, -- // Its push has started (from the input, or on its own)
	PushedAt: number?, -- // time() of the step its input started it on (that step may be run again)
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local serverCatches: { [Player]: ServerCatch } = {} -- // Server: recent heavy catches
local earlyPushes: { [Player]: { At: number, Frame: number } } = {} -- // Server: a push started from an input before the heavy catch (os.clock(), time() of its step)
local inputReleaseToken = 0 -- // Client

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- // Casts that see what the player's body collides with (the same as the dash's)
local function getCastParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.CollisionGroup = CollisionGroupConstants.Players
	params.RespectCanCollide = true
	return params
end

-- // Lazily required, like the dash (load order)
local WaterLogic = nil
local function getWaterCastParams(): RaycastParams?
	if not WaterLogic then
		WaterLogic = require(ReplicatedStorage.Shared.Logics.Environment.Water)
	end
	local waterParts = WaterLogic.getCurrentWaterParts()
	if #waterParts == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = waterParts
	return params
end

-- // How far the push can go: up to a wall, and only over standable ground (not water, not off an edge)
local function getSafeDistance(character: Model, rootPart: BasePart, direction: Vector3, distance: number): number
	local params = getCastParams(character)
	local rootPosition = rootPart.Position
	local wall = workspace:Blockcast(CFrame.lookAt(rootPosition, rootPosition + direction), BODY_SIZE, direction * distance, params)
	local safe = if wall then math.max(0, wall.Distance - WALL_MARGIN) else distance

	local waterParams = getWaterCastParams()
	local travelled = GROUND_PROBE_STEP
	while travelled <= safe do
		local probe = rootPosition + direction * travelled
		local hit = workspace:Raycast(probe, Vector3.new(0, -GROUND_PROBE_DEPTH, 0), params)
		local overWater = hit ~= nil and waterParams ~= nil
			and workspace:Raycast(probe, Vector3.new(0, hit.Position.Y - probe.Y - 0.05, 0), waterParams) ~= nil
		if not hit or hit.Normal.Y < MIN_GROUND_NORMAL_Y or overWater then
			return math.max(0, travelled - GROUND_PROBE_STEP)
		end
		travelled += GROUND_PROBE_STEP
	end
	return safe
end

local function debugPrint(message: string)
	if BoomerangDebugLibrary.get("Log") >= 1 then
		print(`[BoomerangDebug] heavy push ({if isServer then "server" else "client"}): {message}`)
	end
end

local function getPushAction(player: Player): InputAction?
	local inputContexts = player:FindFirstChild("InputContexts")
	local characterContext = inputContexts and inputContexts:FindFirstChild("CharacterContext")
	local action = characterContext and characterContext:FindFirstChild(PUSH_ACTION_NAME)
	return if action and action:IsA("InputAction") then action else nil
end

local function startPush(character: Model, rootPart: BasePart, humanoid: Humanoid, direction: Vector3, now: number)
	if humanoid.FloorMaterial == Enum.Material.Air then
		debugPrint("skipped, in the air")
		return
	end
	local distance = getSafeDistance(character, rootPart, direction, GlobalConfig.HeavyCatchPushDistance)
	if distance <= 0.05 then
		debugPrint("skipped, no room")
		return
	end
	rootPart:SetAttribute(ATTRIBUTE_STARTED_AT, now)
	rootPart:SetAttribute(ATTRIBUTE_ENDS_AT, now + math.max(GlobalConfig.HeavyCatchPushSeconds, 1 / 60))
	rootPart:SetAttribute(ATTRIBUTE_DIRECTION, direction)
	rootPart:SetAttribute(ATTRIBUTE_START, rootPart.Position)
	rootPart:SetAttribute(ATTRIBUTE_DISTANCE, distance)
	debugPrint(string.format("started at %.3f, %.2f studs", now, distance))
end

-- // Server: whether that player's manual recall is about to reach them (the client predicts its catch a little early)
local function isRecallArriving(player: Player, rootPart: BasePart): boolean
	local data = ThrownWeapons.Data[player]
	if not data or data.RecallFromDead ~= true or not data.CFrame or not data.Speed then
		return false
	end
	local distance = flat(data.CFrame.Position - rootPart.Position).Magnitude
	return distance <= data.Speed * EARLY_INPUT_SECONDS + 4
end

-- // Server: whether the client's push input is backed by a heavy catch. The server can run a step more than once, so
-- // this only reads (and marks) state
local function acceptInput(player: Player, rootPart: BasePart, now: number): boolean
	local catch = serverCatches[player]
	if catch and catch.PushedAt == now then
		return true
	end
	if catch and not catch.Pushed and os.clock() - catch.At <= INPUT_WAIT_SECONDS + player:GetNetworkPing() then
		catch.Pushed = true
		catch.PushedAt = now
		return true
	end
	local early = earlyPushes[player]
	if (early and early.Frame == now) or isRecallArriving(player, rootPart) then
		earlyPushes[player] = { At = os.clock(), Frame = now }
		return true
	end
	debugPrint(string.format("input at %.3f ignored, no heavy catch%s", now,
		if catch and catch.PushedAt then string.format(" (last push %.3f)", catch.PushedAt) else ""))
	return false
end

local function stepPlayerPush(player: Player, now: number)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not rootPart or not humanoid or humanoid.Health <= 0 or rootPart.Anchored then
		return
	end

	local action = getPushAction(player)
	local state = if action then action:GetState() else nil
	local input = if typeof(state) == "Vector2" then Vector3.new(state.X, 0, state.Y) else Vector3.zero
	local held = input.Magnitude > 0.5
	local wasHeld = rootPart:GetAttribute(ATTRIBUTE_INPUT_HELD) == true
	if held ~= wasHeld then
		rootPart:SetAttribute(ATTRIBUTE_INPUT_HELD, held)
	end
	if held and not wasHeld then
		-- // The client's own direction, so both sides push the same way (it only moves the catcher, a few studs)
		if not isServer or acceptInput(player, rootPart, now) then
			startPush(character, rootPart, humanoid, input.Unit, now)
		end
	end
	if isServer then
		local catch = serverCatches[player]
		if catch and os.clock() - catch.At > CATCH_MEMORY_SECONDS then
			serverCatches[player] = nil
		elseif catch and not catch.Pushed and os.clock() - catch.At > INPUT_WAIT_SECONDS + player:GetNetworkPing() then
			-- // No input on time: the server pushes on its own
			catch.Pushed = true
			debugPrint("no input, pushing on its own")
			startPush(character, rootPart, humanoid, catch.Direction, now)
		end
	end

	local endsAt = rootPart:GetAttribute(ATTRIBUTE_ENDS_AT) or 0
	if endsAt == 0 then
		return
	end
	local startedAt: number = rootPart:GetAttribute(ATTRIBUTE_STARTED_AT) or now
	local direction: Vector3 = rootPart:GetAttribute(ATTRIBUTE_DIRECTION) or Vector3.zAxis
	local start: Vector3 = rootPart:GetAttribute(ATTRIBUTE_START) or rootPart.Position
	local distance: number = rootPart:GetAttribute(ATTRIBUTE_DISTANCE) or 0

	local velocity = rootPart.AssemblyLinearVelocity
	local remaining = distance - flat(rootPart.Position - start):Dot(direction)
	local timeLeft = endsAt - now
	if timeLeft <= 0 or remaining <= 0.05 then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0) -- // Keeps falling/jumping speed
		rootPart:SetAttribute(ATTRIBUTE_ENDS_AT, 0)
		return
	end
	-- // Strongest at the start, slowing to a stop. Re-aimed every step at what's left (the Humanoid's own movement drags
	-- // on it), so it still covers the distance; capped so a stuck push can't build up a launch
	local initialSpeed = 2 * distance / math.max(endsAt - startedAt, 1 / 60)
	local speed = math.min(2 * remaining / timeLeft, initialSpeed * 1.5)
	rootPart.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
end

local function stepPushes(_deltaTime: number)
	local now = time()
	if isServer then
		for _, player in Players:GetPlayers() do
			stepPlayerPush(player, now)
		end
	else
		stepPlayerPush(Players.LocalPlayer, now)
	end
end

-- // Server: every player gets the push input next to the character controls (replicated like them)
local function addPushAction(player: Player)
	task.spawn(function()
		local inputContexts = player:WaitForChild("InputContexts", 60)
		local characterContext = inputContexts and inputContexts:WaitForChild("CharacterContext", 60)
		if not characterContext or characterContext:FindFirstChild(PUSH_ACTION_NAME) then
			return
		end
		local action = Instance.new("InputAction")
		action.Name = PUSH_ACTION_NAME
		action.Type = Enum.InputActionType.Direction2D
		action.Parent = characterContext
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Which catch this is. `weaponPosition` and `weaponVelocity` (studs/s) are the boomerang's just before contact.
function CatchLibrary.resolve(player: Player, toolId: string?, weaponPosition: Vector3?, weaponVelocity: Vector3?): CatchInfo
	local info: CatchInfo = { Heavy = false, ClosingSpeed = 0, Direction = Vector3.zero }
	local rootPart = player.Character and player.Character.PrimaryPart
	if not rootPart or not weaponPosition or not weaponVelocity then
		return info
	end

	local relative = flat(weaponVelocity - rootPart.AssemblyLinearVelocity)
	local toward = flat(rootPart.Position - weaponPosition)
	if toward.Magnitude < MIN_TOWARD_DISTANCE then
		toward = relative
	end
	if toward.Magnitude < MIN_TOWARD_DISTANCE then
		return info
	end

	toward = toward.Unit
	info.ClosingSpeed = math.max(0, relative:Dot(toward))
	-- // Pushed the way the boomerang is going: steadier than its position against the catcher's right at contact
	info.Direction = if relative.Magnitude >= MIN_TOWARD_DISTANCE then relative.Unit else toward
	info.Heavy = info.ClosingSpeed >= BoomerangTuningLibrary.getForAnyTool(toolId, "HeavyCatchSpeed")
	return info
end

-- // The heavy catch's push. Server: any player (waits for the client's input, see the top). Client: only the local
-- // player, which presses the push input. Skipped in the air.
function CatchLibrary.push(player: Player, direction: Vector3)
	local unit = flat(direction)
	if unit.Magnitude < MIN_TOWARD_DISTANCE then
		return
	end
	unit = unit.Unit
	if isServer then
		local early = earlyPushes[player]
		earlyPushes[player] = nil
		local pushed = early ~= nil and os.clock() - early.At <= CATCH_MEMORY_SECONDS -- // The client's input already started it
		debugPrint(if pushed and early then string.format("heavy catch %.0f ms after the input", (os.clock() - early.At) * 1000) else "heavy catch")
		serverCatches[player] = { Direction = unit, At = os.clock(), Pushed = pushed, PushedAt = if pushed and early then early.Frame else nil }
		return
	end
	if player ~= Players.LocalPlayer then
		return
	end
	local action = getPushAction(player)
	if not action then
		debugPrint("no push input yet")
		return
	end
	inputReleaseToken += 1
	local token = inputReleaseToken
	action:Fire(Vector2.new(unit.X, unit.Z))
	task.delay(INPUT_HOLD_SECONDS, function()
		if inputReleaseToken == token then
			action:Fire(Vector2.zero)
		end
	end)
end

function CatchLibrary.cancelPush(player: Player)
	serverCatches[player] = nil
	earlyPushes[player] = nil
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart:SetAttribute(ATTRIBUTE_ENDS_AT, 0)
	end
end

RunService:BindToSimulation(stepPushes, Enum.StepFrequency.Hz60)

if isServer then
	Players.PlayerAdded:Connect(addPushAction)
	for _, player in Players:GetPlayers() do
		addPushAction(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	serverCatches[player] = nil
	earlyPushes[player] = nil
end)

return CatchLibrary
