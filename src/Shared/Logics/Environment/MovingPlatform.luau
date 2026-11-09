--[[
	MovingPlatform (environment logic)

	A platform that travels back and forth between two pivots, resting RestTime seconds at each end. Each trip speeds up to
	Speed (studs/s) over AccelerationTime seconds, runs at that speed, and stops over DecelerationTime seconds. The platform is
	a single part directly in the map's Functional folder with attributes ClassName = "MovingPlatform", Speed, StartPivot,
	EndPivot, and optionally RestTime, AccelerationTime, DecelerationTime, StartCrush, EndCrush.

	SERVER AUTHORITY (Workspace.AuthorityMode = Server):
	- Its position is a pure function of the synced simulation clock, time(). It is driven inside RunService:BindToSimulation()
	  on the server and every client (initialised by EnvironmentService and EnvironmentController). Clients force prediction on
	  for it (RunService:SetPredictionMode), so each drives it like the server, including frames replayed after a rollback.
	- DRIVE (PHYSICS_DRIVEN): the platform is an unanchored, heavy body held to its path by a rigid AlignPosition and
	  AlignOrientation (created by the server; each client drives its own local copy); each step only their targets are set, and
	  Roblox physics pushes and carries characters. PHYSICS_DRIVEN = false uses the anchored platform moved by setting its CFrame
	  each step, which needs CARRY and PUSH (those sections only run in that mode).
	- The server stamps the platform with its start time (attribute MovingPlatformStartTime); clients read it from the replicated
	  part and find platforms by watching the live arena map (they can stream in and out).
	- CARRY (anchored mode only): players standing on the platform are carried along (RIDE_MODE). CARRY_ENABLED turns it off.
	- PUSH (anchored mode only): physics can't push characters out of the way of an anchored part that jumps forward each step
	  (at full speed it moves further per step than half a torso). So each step every character (players and bots) caught by the
	  leading face is moved forward, just clear of it. Only their position along the travel changes, never their velocity.
	- CRUSH (server only): StartCrush / EndCrush (booleans) make that end crush. While the platform closes in on a crushing end,
	  a player inside its footprint between its leading face and that end is crushed once the gap is too small for their Hitbox.
	  The end must have a wall (map rule). Runs right after each server simulation step (eliminations can't be applied inside
	  one); clients never predict it.
]]

local MovingPlatform = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local DynamicCollisionLibrary = require(ReplicatedStorage.Shared.Library.DynamicCollisionLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local START_TIME_ATTRIBUTE = "MovingPlatformStartTime" -- // Set by the server on the platform part: time() it started moving
local CLASS_NAME = "MovingPlatform"

-- // Riding needs the anchored mode: the physics drive moves the platform with no velocity of its own, so the Humanoid
-- // doesn't follow it and riders are left behind
local PHYSICS_DRIVEN = false -- // Unanchored and held to its path by rigid constraints, so Roblox physics does the pushing and carrying (see DRIVE)
local PLATFORM_DENSITY = 100 -- // Maximum density: characters can't shove the platform off its path
local ALIGN_POSITION_NAME = "MovingPlatformAlignPosition"
local ALIGN_ORIENTATION_NAME = "MovingPlatformAlignOrientation"
local DRIVE_ATTACHMENT_NAME = "MovingPlatformAttachment"

local CARRY_ENABLED = true -- // Players standing on a platform ride along with it (see CARRY; anchored mode only)
-- // How riders are carried (anchored mode): "Delta" moves them by the platform's own movement every step (exact;
-- // platform velocity stays zero so the Humanoid doesn't carry them twice). "Velocity" only writes the platform's
-- // velocity and lets the Humanoid follow its floor (slips about 2 studs per 35-stud trip)
local RIDE_MODE: "Delta" | "Velocity" = "Delta"
local RIDE_FOOTPRINT_MARGIN = 0.5 -- // Studs past the platform's edge a rider's root can be and still ride
local RIDE_HEIGHT_TOLERANCE = 0.6 -- // Feet within this of the platform's top (above or below) count as standing on it

local PUSH_ENABLED = true -- // Characters in the way are moved clear of the leading face (see PUSH; anchored mode only)
local PUSH_BODY_HALF_SIZE = Vector3.new(1, 1, 0.5) -- // Half the collidable torso (2 x 2 x 1, R6 and bots), in the root's space
local PUSH_SKIN = 0.05 -- // Studs left between the face and a pushed torso
local PUSH_CATCH_DEPTH = 0.3 -- // Studs a torso may already be into the face (its own walking into it) and still be pushed out
local PUSH_BODY_BELOW_ROOT = 3 -- // Feet are this far below the root (R6 and bots)
local PUSH_BODY_ABOVE_ROOT = 2.5 -- // Top of the head is this far above the root
local PUSH_STEP_TOLERANCE = 0.25 -- // Feet within this of the platform's top count as standing on it (riding, not pushed)
local PUSH_MAX_VERTICAL_TRAVEL = 0.7 -- // Platforms travelling more steeply than this (|direction.Y|) aren't pushers: lifts carry instead
local BOTS_FOLDER_NAME = "Bots" -- // BotService's folder in the workspace (decoys and other bots)

local DEFAULT_ACCELERATION_TIME = 0.5 -- // Seconds a trip takes to reach full speed (attribute AccelerationTime)
local DEFAULT_DECELERATION_TIME = 0.2 -- // Seconds it takes to stop at the end of a trip (attribute DecelerationTime)

local CRUSH_CAUSE_LABEL = "Crushed"
local CRUSH_GAP_TOLERANCE = 0.3 -- // Studs: a gap this much smaller than a Hitbox's width still counts as fitting (brushing the face is safe)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type MovingPlatformAttributes = {
	Speed: number,
	StartPivot: CFrame,
	EndPivot: CFrame,
	RestTime: number?, -- // Seconds it rests at each end before going back
	AccelerationTime: number?,
	DecelerationTime: number?,
	StartCrush: boolean?, -- // Crushes players against the wall at the start end
	EndCrush: boolean?, -- // Crushes players against the wall at the end end
}

type PlatformData = {
	Part: BasePart,
	Speed: number,
	StartPivot: CFrame,
	EndPivot: CFrame,
	RestTime: number,
	AccelerationTime: number,
	DecelerationTime: number,
	StartTime: number, -- // time() it started moving (the same value on the server and every client)
	Size: Vector3, -- // Read once at registration (only simulation-synced members are read inside the simulation step)
	AlignPosition: AlignPosition?, -- // PHYSICS_DRIVEN: the constraints the step retargets
	AlignOrientation: AlignOrientation?,
	CrushAtStart: boolean,
	CrushAtEnd: boolean,
	-- // Updated every simulation step (read by the crush check)
	MovingToEnd: boolean, -- // Heading for (or resting at) the end pivot
	Moving: boolean, -- // Travelling (not resting)
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

local platforms: { [BasePart]: PlatformData } = {}
local pushableRoots: { [BasePart]: true } = {} -- // Root parts of characters platforms push (see PUSH)
local simulationConnection: RBXScriptConnection? = nil
local crushConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PATH (pure functions of time: identical on the server and every client)
-------------------------------------------------------------------------------

-- // One trip's speed profile: steady speed-up to top speed, a run at it, a steady stop. Returns the top speed actually
-- // reached (lower on a trip too short to reach it) and the trip's duration.
local function getTripProfile(distance: number, speed: number, accelerationTime: number, decelerationTime: number): (number, number)
	local rampTime = accelerationTime + decelerationTime
	local topSpeed = speed
	if topSpeed * rampTime / 2 > distance then
		topSpeed = 2 * distance / rampTime -- // Too short to reach full speed: speeds up, then straight into the stop
	end
	return topSpeed, rampTime + (distance - topSpeed * rampTime / 2) / topSpeed
end

-- // Fraction of the trip covered `t` seconds in
local function getTripAlpha(t: number, distance: number, topSpeed: number, tripTime: number, accelerationTime: number, decelerationTime: number): number
	local travelled
	if t <= 0 then
		travelled = 0
	elseif t < accelerationTime then
		travelled = topSpeed * t * t / (2 * accelerationTime)
	elseif t < tripTime - decelerationTime then
		travelled = topSpeed * accelerationTime / 2 + topSpeed * (t - accelerationTime)
	elseif t < tripTime then
		local left = tripTime - t
		travelled = distance - topSpeed * left * left / (2 * decelerationTime)
	else
		travelled = distance
	end
	return math.clamp(travelled / distance, 0, 1)
end

-- // Where the platform is at simulation time `now`; also whether it is heading for the end pivot and whether it is travelling
local function getPivotAt(platformData: PlatformData, now: number): (CFrame, boolean, boolean)
	local startPivot, endPivot = platformData.StartPivot, platformData.EndPivot
	local distance = (endPivot.Position - startPivot.Position).Magnitude
	if distance <= 1e-5 or platformData.Speed <= 1e-5 then
		return startPivot, true, false
	end

	local restTime = platformData.RestTime
	local accelerationTime, decelerationTime = platformData.AccelerationTime, platformData.DecelerationTime
	local topSpeed, travelTime = getTripProfile(distance, platformData.Speed, accelerationTime, decelerationTime)
	local cycleTime = 2 * (restTime + travelTime)
	local cycle = (now - platformData.StartTime) % cycleTime

	if cycle < restTime then -- // Resting at the start
		return startPivot, true, false
	end
	cycle -= restTime
	if cycle < travelTime then -- // Start -> end
		return startPivot:Lerp(endPivot, getTripAlpha(cycle, distance, topSpeed, travelTime, accelerationTime, decelerationTime)), true, true
	end
	cycle -= travelTime
	if cycle < restTime then -- // Resting at the end
		return endPivot, false, false
	end
	cycle -= restTime
	return endPivot:Lerp(startPivot, getTripAlpha(cycle, distance, topSpeed, travelTime, accelerationTime, decelerationTime)), false, true -- // End -> start
end

-------------------------------------------------------------------------------
-- CARRY (riding along / being pushed). Kept separate: if riding misbehaves, look here (or set CARRY_ENABLED = false).
-------------------------------------------------------------------------------

-- // An anchored part's velocity is what physics uses for contacts: characters standing on it move with it, and
-- // characters in its way are pushed at its speed. Called inside the simulation step (both properties have simulation
-- // access).
local function applyCarryVelocity(part: BasePart, velocity: Vector3)
	part.AssemblyLinearVelocity = if CARRY_ENABLED and RIDE_MODE == "Velocity" then velocity else Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

-- // RIDE_MODE "Delta": every character standing on the platform (feet on its top, root over it, as of its previous
-- // pivot) moves with it this step (same move and turn). Their own walking is untouched. Inside the simulation step:
-- // the server carries everyone, a client its own predicted character.
local function carryRiders(platformData: PlatformData, previousPivot: CFrame, pivot: CFrame)
	if not CARRY_ENABLED or RIDE_MODE ~= "Delta" then
		return
	end
	local delta = pivot * previousPivot:Inverse()
	if delta.Position.Magnitude <= 1e-6 and delta.Rotation == CFrame.identity then
		return
	end
	local halfSize = platformData.Size / 2
	for root in pairs(pushableRoots) do
		local rootCFrame = root.CFrame
		local localPosition = previousPivot:PointToObjectSpace(rootCFrame.Position)
		local feet = localPosition.Y - PUSH_BODY_BELOW_ROOT
		if math.abs(feet - halfSize.Y) <= RIDE_HEIGHT_TOLERANCE
			and math.abs(localPosition.X) <= halfSize.X + RIDE_FOOTPRINT_MARGIN
			and math.abs(localPosition.Z) <= halfSize.Z + RIDE_FOOTPRINT_MARGIN then
			root.CFrame = delta * rootCFrame
		end
	end
end

-------------------------------------------------------------------------------
-- PUSH (characters in the way). Kept separate: if pushing misbehaves, look here (or set PUSH_ENABLED = false).
-------------------------------------------------------------------------------

-- // How far a box of `size` (in its own space) reaches along `localDirection` (a unit vector in that space)
local function getHalfExtentAlong(size: Vector3, localDirection: Vector3): number
	return (math.abs(localDirection.X) * size.X + math.abs(localDirection.Y) * size.Y + math.abs(localDirection.Z) * size.Z) / 2
end

-- // Moves characters caught by the platform's leading face (from previousPivot to pivot this step) forward along the
-- // travel, just clear of the face. Only their position along the travel changes (velocity, height, sideways position
-- // untouched). Runs inside the simulation step so a client pushes its own predicted character exactly as the server
-- // does, replays included.
local function pushCharacters(platformData: PlatformData, previousPivot: CFrame, pivot: CFrame)
	local travel = pivot.Position - previousPivot.Position
	local stepDistance = travel.Magnitude
	if stepDistance <= 1e-5 then
		return
	end
	local direction = travel / stepDistance
	if math.abs(direction.Y) > PUSH_MAX_VERTICAL_TRAVEL then
		return
	end

	local size = platformData.Size
	local faceDistance = getHalfExtentAlong(size, pivot:VectorToObjectSpace(direction)) -- // Leading face, from the centre
	local lateral = direction:Cross(Vector3.yAxis).Unit
	local halfWidth = getHalfExtentAlong(size, pivot:VectorToObjectSpace(lateral))
	local halfHeight = getHalfExtentAlong(size, pivot:VectorToObjectSpace(Vector3.yAxis))
	local top = pivot.Position.Y + halfHeight
	local bottom = pivot.Position.Y - halfHeight

	-- // An end that doesn't crush may still have a wall: stop pushing once there's no room left before it (physics takes over)
	local targetPivot = if platformData.MovingToEnd then platformData.EndPivot else platformData.StartPivot
	local crushes = if platformData.MovingToEnd then platformData.CrushAtEnd else platformData.CrushAtStart
	local roomLeft = (targetPivot.Position - pivot.Position):Dot(direction)

	for root in pairs(pushableRoots) do
		local rootCFrame = root.CFrame
		local rootPosition = rootCFrame.Position

		-- // Height: overlaps the platform, and isn't standing on top of it (riders are CARRY's)
		local feet = rootPosition.Y - PUSH_BODY_BELOW_ROOT
		if feet >= top - PUSH_STEP_TOLERANCE or rootPosition.Y + PUSH_BODY_ABOVE_ROOT <= bottom then
			continue
		end

		-- // Across the travel: the torso overlaps the face
		local offset = rootPosition - pivot.Position
		local bodyHalfWidth = getHalfExtentAlong(PUSH_BODY_HALF_SIZE * 2, rootCFrame:VectorToObjectSpace(lateral))
		if math.abs(offset:Dot(lateral)) >= halfWidth + bodyHalfWidth then
			continue
		end

		-- // Along the travel: the torso's back was in front of the face before this step (allowing for it walking a
		-- // little into it) and is now short of being clear of it
		local bodyHalfDepth = getHalfExtentAlong(PUSH_BODY_HALF_SIZE * 2, rootCFrame:VectorToObjectSpace(direction))
		local clearAlong = faceDistance + bodyHalfDepth + PUSH_SKIN
		local along = offset:Dot(direction)
		if along >= clearAlong then
			continue -- // Not reached yet
		end
		if along - bodyHalfDepth < faceDistance - stepDistance - PUSH_CATCH_DEPTH then
			continue -- // Already behind the face (or inside the platform) before this step: not in the way
		end
		if not crushes and roomLeft < bodyHalfDepth * 2 then
			continue
		end

		root.CFrame = rootCFrame + direction * (clearAlong - along)
	end
end

-------------------------------------------------------------------------------
-- DRIVE (PHYSICS_DRIVEN). Kept separate: if the physics-driven platform misbehaves, look here (or set PHYSICS_DRIVEN = false).
-------------------------------------------------------------------------------

-- // Server: turns the platform into a heavy unanchored body held to its path by rigid constraints (they replicate to clients)
local function setUpPhysicsDrive(part: BasePart, startPivot: CFrame)
	part.Anchored = true -- // Placed exactly before physics takes over
	part:PivotTo(startPivot)
	local properties = part.CurrentPhysicalProperties
	part.CustomPhysicalProperties = PhysicalProperties.new(PLATFORM_DENSITY, properties.Friction, properties.Elasticity,
		properties.FrictionWeight, properties.ElasticityWeight)

	local attachment = Instance.new("Attachment")
	attachment.Name = DRIVE_ATTACHMENT_NAME
	attachment.Parent = part

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = ALIGN_POSITION_NAME
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.RigidityEnabled = true
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.Position = startPivot.Position
	alignPosition.Parent = part

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = ALIGN_ORIENTATION_NAME
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.CFrame = startPivot.Rotation
	alignOrientation.Parent = part

	part.Anchored = false
end

-- // Inside the simulation step: aim the constraints at where the platform should be now; physics moves it there
local function drivePlatform(platformData: PlatformData, pivot: CFrame)
	local alignPosition, alignOrientation = platformData.AlignPosition, platformData.AlignOrientation
	if alignPosition and alignOrientation then
		alignPosition.Position = pivot.Position
		alignOrientation.CFrame = pivot.Rotation
	end
end

-------------------------------------------------------------------------------
-- SIMULATION (server and clients)
-------------------------------------------------------------------------------

local function stepPlatforms(deltaTime: number)
	local now = time()
	-- // Only simulation-synced members here (CFrame, velocities, time()); platforms that left the workspace are
	-- // unregistered outside the simulation (see register)
	for part, platformData in pairs(platforms) do
		local pivot, movingToEnd, moving = getPivotAt(platformData, now)
		platformData.MovingToEnd = movingToEnd
		platformData.Moving = moving

		DynamicCollisionLibrary.capturePreviousTransform(part, now)
		if PHYSICS_DRIVEN then
			drivePlatform(platformData, pivot)
			DynamicCollisionLibrary.recordCurrentTransform(part, pivot, now)
			continue
		end

		-- // Anchored mode: move it ourselves, then carry riders and push characters in the way
		part.CFrame = pivot
		DynamicCollisionLibrary.recordCurrentTransform(part, pivot, now)

		local previousPivot = getPivotAt(platformData, now - math.max(deltaTime, 1e-3))
		applyCarryVelocity(part, (pivot.Position - previousPivot.Position) / math.max(deltaTime, 1e-3))
		carryRiders(platformData, previousPivot, pivot)
		if PUSH_ENABLED and moving then
			pushCharacters(platformData, previousPivot, pivot)
		end
	end
end

-------------------------------------------------------------------------------
-- CRUSH (server only, right after each simulation step). Kept separate from the movement.
-------------------------------------------------------------------------------

-- // A player's Hitbox: a vertical cylinder centred on their root, Size = (height, diameter, diameter)
local function getAliveHitbox(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hitbox = character and character:FindFirstChild("Hitbox")
	if not humanoid or humanoid.Health <= 0 or not hitbox or not hitbox:IsA("BasePart") then
		return nil, nil
	end
	return hitbox, humanoid
end

-- // Whether this player is caught between the platform's leading face and the crushing end with no room left
local function isCrushed(platformData: PlatformData, hitbox: BasePart): boolean
	local part = platformData.Part
	local targetPivot = if platformData.MovingToEnd then platformData.EndPivot else platformData.StartPivot
	local travel = targetPivot.Position - part.Position
	local gap = travel.Magnitude -- // How much further the platform still goes, i.e. the room left before the wall
	local radius = math.min(hitbox.Size.Y, hitbox.Size.Z) / 2
	if gap >= radius * 2 - CRUSH_GAP_TOLERANCE then
		return false -- // There is still room for anyone to fit
	end

	local direction = if gap > 1e-4
		then travel / gap
		else (targetPivot.Position - (if platformData.MovingToEnd then platformData.StartPivot else platformData.EndPivot).Position).Unit
	local platformCFrame = part.CFrame
	local localDirection = platformCFrame:VectorToObjectSpace(direction)
	local halfExtent = getHalfExtentAlong(part.Size, localDirection)

	-- // Along the travel: between the leading face (allowing for the Hitbox's radius) and the wall
	local offset = hitbox.Position - platformCFrame.Position
	local along = offset:Dot(direction)
	if along < halfExtent - radius or along > halfExtent + gap + radius then
		return false
	end

	-- // Across the travel: within the platform's footprint, widened by the Hitbox's size on each side
	local halfHeight = hitbox.Size.X / 2
	local localOffset = platformCFrame:VectorToObjectSpace(offset - direction * along)
	for _, axis in ipairs({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }) do
		local alignment = math.abs(axis:Dot(localDirection))
		if alignment > 0.99 then
			continue -- // The travel axis (handled above)
		end
		local worldAxis = platformCFrame:VectorToWorldSpace(axis)
		local upness = math.abs(worldAxis.Y)
		local reach = upness * halfHeight + (1 - upness) * radius
		local partHalf = math.abs(axis.X) * part.Size.X / 2 + math.abs(axis.Y) * part.Size.Y / 2 + math.abs(axis.Z) * part.Size.Z / 2
		if math.abs(localOffset:Dot(axis)) > partHalf + reach then
			return false
		end
	end
	return true
end

-- // Crushing ignores shields (TakeDamage does nothing under a ForceField): set Health directly and send the death
-- // reason ourselves (as applyDamageToHumanoid and Water do)
local function crushPlayer(player: Player, humanoid: Humanoid)
	humanoid.Health = 0
	CombatLibrary.notifyDeathReason(player, nil, CRUSH_CAUSE_LABEL)
end

local function checkCrushes()
	for _, platformData in pairs(platforms) do
		-- // Only while travelling toward an end that crushes: most frames cost nothing
		if not platformData.Moving then
			continue
		end
		local crushes = if platformData.MovingToEnd then platformData.CrushAtEnd else platformData.CrushAtStart
		if not crushes then
			continue
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local hitbox, humanoid = getAliveHitbox(player)
			if hitbox and humanoid and isCrushed(platformData, hitbox) then
				crushPlayer(player, humanoid)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- REGISTRATION
-------------------------------------------------------------------------------

local function ensureRunning()
	if not simulationConnection then
		simulationConnection = RunService:BindToSimulation(stepPlatforms)
	end
	if isServer and not crushConnection then
		crushConnection = RunService.PostSimulation:Connect(checkCrushes)
	end
end

local function unregister(part: BasePart)
	if platforms[part] then
		platforms[part] = nil
		DynamicCollisionLibrary.unregister(part)
	end
end

local function reset()
	for part in pairs(platforms) do
		DynamicCollisionLibrary.unregister(part)
	end
	table.clear(platforms)
	if simulationConnection then
		simulationConnection:Disconnect()
		simulationConnection = nil
	end
	if crushConnection then
		crushConnection:Disconnect()
		crushConnection = nil
	end
end

-- // The constraint the simulation step retargets. On a client the server's copy is switched off locally and replaced
-- // by a local one: the server keeps retargeting its copy, and those writes would arrive late and drag the predicted
-- // platform back (jitter).
local function getDriveConstraint(part: BasePart, name: string): Instance?
	local replicated = part:FindFirstChild(name)
	if isServer or not replicated then
		return replicated
	end
	local localName = name .. "Local"
	local existing = part:FindFirstChild(localName)
	if existing then
		return existing
	end
	local localConstraint = replicated:Clone()
	localConstraint.Name = localName
	localConstraint.Parent = part;
	(replicated :: any).Enabled = false
	return localConstraint
end

local function register(part: BasePart, startTime: number)
	if platforms[part] then
		return
	end
	local attributes: MovingPlatformAttributes = part:GetAttributes() :: any
	local startPivot = attributes.StartPivot or part:GetPivot()
	platforms[part] = {
		Part = part,
		Speed = attributes.Speed or 5,
		StartPivot = startPivot,
		EndPivot = attributes.EndPivot or startPivot,
		RestTime = attributes.RestTime or 0,
		AccelerationTime = math.max(attributes.AccelerationTime or DEFAULT_ACCELERATION_TIME, 0),
		DecelerationTime = math.max(attributes.DecelerationTime or DEFAULT_DECELERATION_TIME, 0),
		StartTime = startTime,
		Size = part.Size,
		AlignPosition = getDriveConstraint(part, ALIGN_POSITION_NAME) :: AlignPosition?,
		AlignOrientation = getDriveConstraint(part, ALIGN_ORIENTATION_NAME) :: AlignOrientation?,
		CrushAtStart = attributes.StartCrush == true,
		CrushAtEnd = attributes.EndCrush == true,
		MovingToEnd = true,
		Moving = false,
	}
	DynamicCollisionLibrary.register(part, startPivot, startTime)

	if not isServer then
		-- // This client simulates the platform itself (from time()), ahead of the replicated server state like its own character
		RunService:SetPredictionMode(part, Enum.PredictionMode.On)
	end
	-- // Destroyed, or streamed out on a client (it registers again if it streams back in)
	local ancestryConnection
	ancestryConnection = part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			ancestryConnection:Disconnect()
			unregister(part)
		end
	end)
	ensureRunning()
end

-- // A character (or bot) root that platforms push, until it leaves the workspace
local function trackPushableRoot(root: Instance?)
	if not root or not root:IsA("BasePart") or pushableRoots[root] then
		return
	end
	pushableRoots[root] = true
	local connection
	connection = root.AncestryChanged:Connect(function()
		if not root:IsDescendantOf(workspace) then
			connection:Disconnect()
			pushableRoots[root] = nil
		end
	end)
end

local function trackCharacter(character: Model)
	task.spawn(function()
		trackPushableRoot(character:WaitForChild("HumanoidRootPart", 10))
	end)
end

local function trackPlayer(player: Player)
	player.CharacterAdded:Connect(trackCharacter)
	if player.Character then
		trackCharacter(player.Character)
	end
end

-- // Server: every player's character and every bot. Client: only its own (predicted) character; others are shown where
-- // the server has them
local function startTrackingPushables()
	if not isServer then
		trackPlayer(Players.LocalPlayer)
		return
	end
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		trackPlayer(player)
	end

	local function trackBotsFolder(folder: Instance)
		folder.ChildAdded:Connect(function(bot)
			if bot:IsA("Model") then
				trackCharacter(bot)
			end
		end)
		for _, bot in ipairs(folder:GetChildren()) do
			if bot:IsA("Model") then
				trackCharacter(bot)
			end
		end
	end
	local botsFolder = workspace:FindFirstChild(BOTS_FOLDER_NAME)
	if botsFolder then
		trackBotsFolder(botsFolder)
	else
		local connection
		connection = workspace.ChildAdded:Connect(function(child)
			if child.Name == BOTS_FOLDER_NAME and child:IsA("Folder") then
				connection:Disconnect()
				trackBotsFolder(child)
			end
		end)
	end
end

-- // Client: a MovingPlatform part in the live arena map (it may stream in after the map loads)
local function tryRegisterClientPart(part: Instance)
	if not part:IsA("BasePart") or part:GetAttribute("ClassName") ~= CLASS_NAME or part:GetAttribute("Invalid") then
		return
	end
	task.spawn(function()
		-- // The server may not have started it yet: wait for its start time
		while part.Parent and type(part:GetAttribute(START_TIME_ATTRIBUTE)) ~= "number" do
			part:GetAttributeChangedSignal(START_TIME_ATTRIBUTE):Wait()
		end
		if PHYSICS_DRIVEN then
			-- // Its constraints replicate with it, but may arrive a moment later
			part:WaitForChild(ALIGN_POSITION_NAME, 10)
			part:WaitForChild(ALIGN_ORIENTATION_NAME, 10)
		end
		if part:IsDescendantOf(workspace) then
			register(part, part:GetAttribute(START_TIME_ATTRIBUTE))
		end
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS (environment logic interface)
-------------------------------------------------------------------------------

function MovingPlatform.validate(functionalChild: Instance): boolean
	if not functionalChild:IsA("BasePart") then
		warn(`Functional child of class 'MovingPlatform' is not a part (the platform itself): {functionalChild.Name}`)
		return false
	end
	local platform = functionalChild

	local attributes: MovingPlatformAttributes = platform:GetAttributes() :: any
	if not attributes.Speed or not attributes.StartPivot or not attributes.EndPivot then
		warn(`Moving platform missing required attributes: {functionalChild.Name}`)
		warn(`Possessed attributes: {attributes.Speed}, {attributes.StartPivot}, {attributes.EndPivot}`)
		return false
	end

	platform.CollisionGroup = CollisionGroupConstants.ArenaWalls
	return true
end

-- // Server: the live map's platform starts moving now (EnvironmentService, when a map is placed)
function MovingPlatform.onObjectAdded(platform: Instance)
	if not isServer then
		return
	end
	if platform:GetAttribute("Invalid") then
		warn(`skipping invalid moving platform: {platform.Name}`)
		return
	end
	if not platform:IsA("BasePart") then
		return
	end

	local startPivot = platform:GetAttribute("StartPivot") or platform:GetPivot()
	if PHYSICS_DRIVEN then
		setUpPhysicsDrive(platform, startPivot)
	else
		-- // Moved by setting its CFrame each simulation step (kinematic), never by physics
		platform.Anchored = true
	end
	local startTime = time()
	platform:SetAttribute(START_TIME_ATTRIBUTE, startTime)
	register(platform, startTime)
end

function MovingPlatform.init()
	startTrackingPushables()

	GameStateLibrary.getGameStateData().CurrentRoundData:Subscribe(function(currentRoundData)
		if currentRoundData == nil then
			reset()
		end
	end)

	if not isServer then
		-- // Clients find platforms in the live arena map as its parts arrive
		task.spawn(function()
			local arena = workspace:WaitForChild("Arena")
			arena.DescendantAdded:Connect(tryRegisterClientPart)
			for _, descendant in ipairs(arena:GetDescendants()) do
				tryRegisterClientPart(descendant)
			end
		end)
	end
end

return MovingPlatform
