--[[
	BoomerangDebugController

	Dev testing for boomerang replication (Cmdr `boomerangdebug`, see BoomerangDebugLibrary):
	  - Log: records each server snapshot of a thrown/returning boomerang and the client's drift from it. Prints a summary
	    per flight and each hard snap (teleport to the server position).
	  - Walk: drives the local character's movement input.
	  - Actions: full-charge throw at an angle, or manual recall held for some seconds, via the WeaponController touch input functions.
]]

local BoomerangDebugController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoomerangDebugLibrary = require(ReplicatedStorage.Shared.Library.BoomerangDebugLibrary)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local LOG_PREFIX = "[BoomerangDebug]"
local STRAFE_PERIOD = 2 -- // Seconds per left-right-left strafe
local STATE_NAMES = { [1] = "Outgoing", [2] = "Exhausted", [3] = "Returning" }

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type FlightStats = {
	Player: Player,
	Data: any,
	StartedAt: number,
	Snapshots: number,
	ErrorSum: number,
	MaxError: number,
	MaxErrorSpeed: number,
	MaxErrorState: number,
	HardSnaps: number,
	TopSpeed: number,
	ManualRecall: boolean,
	ErrorBySpeed: { [number]: { Sum: number, Count: number } }, -- // Per 50 studs/s band
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local flights: { [any]: FlightStats } = {}
local walkStartedAt: number? = nil
local walkCentre: Vector3? = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isLogging(): boolean
	return BoomerangDebugLibrary.get("Log") >= 1
end

local function printSummary(stats: FlightStats)
	if stats.Snapshots == 0 then
		return
	end
	local bands = {}
	for band, entry in stats.ErrorBySpeed do
		table.insert(bands, { Band = band, Text = `{band * 50}-{band * 50 + 49}: {string.format("%.2f", entry.Sum / entry.Count)} ({entry.Count})` })
	end
	table.sort(bands, function(a, b)
		return a.Band < b.Band
	end)
	local bandTexts = {}
	for _, band in bands do
		table.insert(bandTexts, band.Text)
	end
	print(string.format(
		"%s %s's %s: %.2fs, %d snapshots, avg drift %.2f, max %.2f (at %.0f studs/s, %s), %d hard snaps, top speed %.0f | avg drift by speed: %s",
		LOG_PREFIX,
		stats.Player.Name,
		if stats.ManualRecall then "manual recall" else "flight",
		os.clock() - stats.StartedAt,
		stats.Snapshots,
		stats.ErrorSum / stats.Snapshots,
		stats.MaxError,
		stats.MaxErrorSpeed,
		STATE_NAMES[stats.MaxErrorState] or tostring(stats.MaxErrorState),
		stats.HardSnaps,
		stats.TopSpeed,
		table.concat(bandTexts, ", ")
	))
end

local function flushEndedFlights()
	for key, stats in flights do
		if ThrownWeapons.Data[stats.Player] ~= stats.Data then
			flights[key] = nil
			if isLogging() then
				printSummary(stats)
			end
		end
	end
end

local function getWalkDirection(root: BasePart, pattern: number, radius: number): Vector3?
	local now = os.clock()
	walkStartedAt = walkStartedAt or now
	walkCentre = walkCentre or root.Position
	local elapsed = now - (walkStartedAt :: number)
	local fromCentre = root.Position - (walkCentre :: Vector3)
	fromCentre = Vector3.new(fromCentre.X, 0, fromCentre.Z)

	if pattern == 1 then
		-- // Circle: tangent plus a pull back onto the circle
		local radial = if fromCentre.Magnitude > 0.1 then fromCentre.Unit else Vector3.xAxis
		local tangent = Vector3.new(-radial.Z, 0, radial.X)
		local pull = (radius - fromCentre.Magnitude) / math.max(radius, 1)
		return (tangent + radial * pull * 2)
	elseif pattern == 2 then
		local side = if math.sin(elapsed * math.pi * 2 / STRAFE_PERIOD) >= 0 then 1 else -1
		local back = -fromCentre / math.max(radius, 1) -- // Keeps it around the starting spot
		return Vector3.xAxis * side + Vector3.new(0, 0, back.Z)
	elseif pattern == 3 or pattern == 4 then
		local data = ThrownWeapons.Data[Players.LocalPlayer]
		local weaponPosition = data and data.CFrame and data.CFrame.Position
		if not weaponPosition then
			return nil
		end
		local toWeapon = weaponPosition - root.Position
		toWeapon = Vector3.new(toWeapon.X, 0, toWeapon.Z)
		if toWeapon.Magnitude < 0.1 then
			return nil
		end
		return if pattern == 3 then -toWeapon.Unit else toWeapon.Unit
	end
	return nil
end

local function stepWalk()
	local pattern = BoomerangDebugLibrary.get("Walk")
	if pattern <= 0 then
		walkStartedAt, walkCentre = nil, nil
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local direction = getWalkDirection(root, pattern, BoomerangDebugLibrary.get("WalkRadius"))
	if direction and direction.Magnitude > 0.01 then
		humanoid:Move(direction.Unit, false)
	end
end

local function runAction()
	local action, value = BoomerangDebugLibrary.getAction(Players.LocalPlayer)
	if not action or not value then
		return
	end
	-- // Required here, not at the top: WeaponController requires this module
	local WeaponController = require(ReplicatedStorage.Client.Core.WeaponController) :: any
	if action == "throw" then
		local angle = math.rad(value)
		local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary) :: any
		local WeaponLibrary = require(ReplicatedStorage.Shared.Library.WeaponLibrary) :: any
		local toolId = SkinLibrary.getWeaponClass(Players.LocalPlayer)
		-- // The lobby ForceField survives the arena teleport and canThrow refuses while one exists. Wait for the
		-- // server (BoomerangDebugServer) to remove it, and remove any local copy
		local character = Players.LocalPlayer.Character
		if character then
			local deadline = os.clock() + 1
			while character:FindFirstChildWhichIsA("ForceField") and os.clock() < deadline do
				task.wait()
			end
			for _, forceField in character:GetChildren() do
				if forceField:IsA("ForceField") then
					forceField:Destroy()
				end
			end
		end
		local began = WeaponController.beginThumbstickAim()
		if not began then
			print(`{LOG_PREFIX} test throw: couldn't start aiming (weapon locked: {WeaponController.playerIsWeaponLocked()}, weapon: {toolId}, can throw: {toolId and WeaponLibrary.canThrow(Players.LocalPlayer, toolId)})`)
			return
		end
		WeaponController.setThumbstickAimDirection(angle)
		task.wait(GlobalConfig.ChargeTime + 0.1)
		local threw = WeaponController.releaseThumbstickAim(angle)
		print(`{LOG_PREFIX} test throw at {value} degrees: {if threw then "thrown" else "not thrown"}`)
	elseif action == "recall" then
		local began = WeaponController.beginRecallInput()
		print(`{LOG_PREFIX} test recall for {value}s: {if began then "holding" else "nothing to recall"}`)
		if began then
			task.wait(value)
			WeaponController.endRecallInput()
		end
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Called by WeaponController on a server snapshot of `forPlayer`'s boomerang. `drift` = studs between the client
-- // simulation and the server position (advanced to now); `hardSnap` = it was too far and teleported.
function BoomerangDebugController.recordSnapshot(forPlayer: Player, data: any, drift: number, speed: number, state: number, hardSnap: boolean, catchup: number?, pendingCorrection: number?)
	if not isLogging() then
		return
	end
	local stats = flights[data]
	if not stats then
		stats = {
			Player = forPlayer,
			Data = data,
			StartedAt = os.clock(),
			Snapshots = 0,
			ErrorSum = 0,
			MaxError = 0,
			MaxErrorSpeed = 0,
			MaxErrorState = state,
			HardSnaps = 0,
			TopSpeed = 0,
			ManualRecall = false,
			ErrorBySpeed = {},
		}
		flights[data] = stats
	end
	stats.Snapshots += 1
	stats.ErrorSum += drift
	stats.TopSpeed = math.max(stats.TopSpeed, speed)
	stats.ManualRecall = stats.ManualRecall or data.RecallFromDead == true
	if drift > stats.MaxError then
		stats.MaxError, stats.MaxErrorSpeed, stats.MaxErrorState = drift, speed, state
	end
	local band = math.floor(speed / 50)
	local entry = stats.ErrorBySpeed[band]
	if not entry then
		entry = { Sum = 0, Count = 0 }
		stats.ErrorBySpeed[band] = entry
	end
	entry.Sum += drift
	entry.Count += 1
	if hardSnap then
		stats.HardSnaps += 1
		print(string.format("%s HARD SNAP %s's boomerang: %.2f studs at %.0f studs/s (%s, ping %.0f ms, snapshot caught up %.0f ms, %.2f studs of correction still pending, snapshot #%d)", LOG_PREFIX, forPlayer.Name, drift, speed,
			STATE_NAMES[state] or tostring(state), Players.LocalPlayer:GetNetworkPing() * 1000, (catchup or 0) * 1000, pendingCorrection or 0, stats.Snapshots))
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function BoomerangDebugController.init()
	RunService.Heartbeat:Connect(flushEndedFlights)
	BoomerangDebugLibrary.getActionChangedSignal(Players.LocalPlayer):Connect(function()
		task.spawn(runAction)
	end)
	-- // Runs after the default controls set movement, so the debug walk wins
	RunService:BindToRenderStep("BoomerangDebugWalk", Enum.RenderPriority.Character.Value + 1, stepWalk)
end

function BoomerangDebugController.start() end

return BoomerangDebugController
