--[[
	MovingPlatform (environment logic, T-131)

	A platform that travels back and forth between two pivots, at Speed studs per second, resting RestTime seconds at each end,
	eased in and out (easeInOutQuint). The platform is a single part directly in the map's Functional folder, with attributes
	ClassName = "MovingPlatform", Speed, StartPivot, EndPivot, and optionally RestTime.

	SERVER AUTHORITY (Workspace.AuthorityMode = Server):
	- The platform is anchored and its position is a pure function of the synced simulation clock, time(). It is moved inside
	  RunService:BindToSimulation() on the server AND on every client (this module is initialised by EnvironmentService and by
	  EnvironmentController). Clients force prediction on for it (RunService:SetPredictionMode), so each client computes the
	  same position the server has for every simulation frame, including frames replayed after a rollback. Characters are
	  therefore always predicted against the platform where it really is, and the platform itself never mispredicts.
	- The server stamps the platform with the time it started (attribute MovingPlatformStartTime); clients read it from the
	  replicated part. Clients find platforms by watching the live arena map (they can stream in and out).
	- CARRY (separate section below): the platform's velocity is also written each step, so players standing on it are
	  carried along and players in its way are pushed rather than overlapped. CARRY_ENABLED turns the riding part off.
]]

local MovingPlatform = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local DynamicCollisionLibrary = require(ReplicatedStorage.Shared.Library.DynamicCollisionLibrary)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local START_TIME_ATTRIBUTE = "MovingPlatformStartTime" -- // Set by the server on the platform part: time() it started moving
local CLASS_NAME = "MovingPlatform"

local CARRY_ENABLED = true -- // Players standing on a platform ride along with it (see CARRY)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type MovingPlatformAttributes = {
	Speed: number,
	StartPivot: CFrame,
	EndPivot: CFrame,
	RestTime: number?, -- // Seconds it rests at each end before going back
}

type PlatformData = {
	Part: BasePart,
	Speed: number,
	StartPivot: CFrame,
	EndPivot: CFrame,
	RestTime: number,
	StartTime: number, -- // time() it started moving (the same value on the server and every client)
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

local platforms: { [BasePart]: PlatformData } = {}
local simulationConnection: RBXScriptConnection? = nil

-------------------------------------------------------------------------------
-- PATH (pure functions of time: identical on the server and every client)
-------------------------------------------------------------------------------

local function easeInOutQuint(x: number): number
	x = math.clamp(x, 0, 1)
	if x < 0.5 then
		return 16 * x * x * x * x * x
	end
	return 1 - (-2 * x + 2) ^ 5 / 2
end

-- // Where the platform is at simulation time `now`; also whether it is heading for the end pivot and whether it is travelling
local function getPivotAt(platformData: PlatformData, now: number): (CFrame, boolean, boolean)
	local startPivot, endPivot = platformData.StartPivot, platformData.EndPivot
	local distance = (endPivot.Position - startPivot.Position).Magnitude
	if distance <= 1e-5 or platformData.Speed <= 1e-5 then
		return startPivot, true, false
	end

	local restTime = platformData.RestTime
	local travelTime = distance / platformData.Speed
	local cycleTime = 2 * (restTime + travelTime)
	local cycle = (now - platformData.StartTime) % cycleTime

	if cycle < restTime then -- // Resting at the start
		return startPivot, true, false
	end
	cycle -= restTime
	if cycle < travelTime then -- // Start -> end
		return startPivot:Lerp(endPivot, easeInOutQuint(cycle / travelTime)), true, true
	end
	cycle -= travelTime
	if cycle < restTime then -- // Resting at the end
		return endPivot, false, false
	end
	cycle -= restTime
	return endPivot:Lerp(startPivot, easeInOutQuint(cycle / travelTime)), false, true -- // End -> start
end

-------------------------------------------------------------------------------
-- CARRY (riding along / being pushed). Kept separate: if riding misbehaves, look here (or set CARRY_ENABLED = false).
-------------------------------------------------------------------------------

-- // An anchored part's velocity is what physics uses for contacts with it: characters standing on it move with it, and
-- // characters in its way are pushed at its speed. Called inside the simulation step (both properties have simulation access).
local function applyCarryVelocity(part: BasePart, velocity: Vector3)
	part.AssemblyLinearVelocity = if CARRY_ENABLED then velocity else Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
end

-------------------------------------------------------------------------------
-- SIMULATION (server and clients)
-------------------------------------------------------------------------------

local function stepPlatforms(deltaTime: number)
	local now = time()
	-- // Only simulation-synced members in here (CFrame, velocities, time()); platforms that left the workspace are
	-- // unregistered outside the simulation (see register)
	for part, platformData in pairs(platforms) do
		local pivot = getPivotAt(platformData, now)

		DynamicCollisionLibrary.capturePreviousTransform(part, now)
		part.CFrame = pivot
		DynamicCollisionLibrary.recordCurrentTransform(part, pivot, now)

		local previousPivot = getPivotAt(platformData, now - math.max(deltaTime, 1e-3))
		applyCarryVelocity(part, (pivot.Position - previousPivot.Position) / math.max(deltaTime, 1e-3))
	end
end

-------------------------------------------------------------------------------
-- REGISTRATION
-------------------------------------------------------------------------------

local function ensureRunning()
	if not simulationConnection then
		simulationConnection = RunService:BindToSimulation(stepPlatforms)
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
		StartTime = startTime,
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

-- // Client: a MovingPlatform part in the live arena map (it may stream in after the map loads)
local function tryRegisterClientPart(part: Instance)
	if not part:IsA("BasePart") or part:GetAttribute("ClassName") ~= CLASS_NAME or part:GetAttribute("Invalid") then
		return
	end
	local startTime = part:GetAttribute(START_TIME_ATTRIBUTE)
	if type(startTime) == "number" then
		register(part, startTime)
		return
	end
	-- // The server hasn't started it yet: wait for its start time
	local connection
	connection = part:GetAttributeChangedSignal(START_TIME_ATTRIBUTE):Connect(function()
		local value = part:GetAttribute(START_TIME_ATTRIBUTE)
		if type(value) == "number" then
			connection:Disconnect()
			register(part, value)
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

	-- // Moved by setting its CFrame each simulation step (kinematic), never by physics
	platform.Anchored = true
	local startTime = time()
	platform:SetAttribute(START_TIME_ATTRIBUTE, startTime)
	register(platform, startTime)
end

function MovingPlatform.init()
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
