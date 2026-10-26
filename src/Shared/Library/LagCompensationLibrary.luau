--[[
	LagCompensationLibrary

	Description:
	Server-side "rewind" for boomerang hits. The server remembers where every player's Hitbox was for the last second or so. When
	a boomerang's hit sweep runs, it also asks this library which players the sweep would have hit if they were where the
	thrower SAW them (a bit in the past: the thrower's ping plus a little interpolation delay), so a hit that looks like a hit on the
	thrower's screen counts. It only ever adds hits to the normal (live) check; flight, bounces and recalls are never rewound.
	The slash (Stab ability, T-125) uses the same rewind: its swing is checked against where the swinging player saw everyone too.

	The setting is one number, in milliseconds: the most the server will rewind. 200 by default (GlobalConfig.LagCompensationMilliseconds).
	0 turns lag compensation off completely (nothing is recorded, hits are exactly as before). Cmdr `setlagcompensation` changes it live
	for this server session only (not saved). Server only: on a client every function does nothing.
]]

local LagCompensationLibrary = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local SAMPLE_CAPACITY = 90 -- // Samples kept per player: 1.5 s at 60 Hz (the longest rewind allowed is MAX_REWIND_MILLISECONDS)
local MAX_REWIND_MILLISECONDS = 1000
local INTERPOLATION_DELAY_SECONDS = 0.1 -- // Roughly how far behind the thrower's screen draws other players, on top of their ping. TUNABLE

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

type History = {
	Character: Model,
	Next: number, -- // Slot the next sample goes into (the buffer is circular)
	Count: number,
	Times: { number },
	Positions: { Vector3 },
	Immune: { boolean },
}

local histories: { [Player]: History } = {}
local maxRewindSeconds: number = math.clamp(GlobalConfig.LagCompensationMilliseconds, 0, MAX_REWIND_MILLISECONDS) / 1000

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getAliveHitbox(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hitbox = character and character:FindFirstChild("Hitbox")
	if character and humanoid and humanoid.Health > 0 and hitbox and hitbox:IsA("BasePart") then
		return character, hitbox
	end
	return nil, nil
end

local function record()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character, hitbox = getAliveHitbox(player)
		if not character or not hitbox then
			histories[player] = nil
			continue
		end
		local history = histories[player]
		if not history or history.Character ~= character then
			history = { Character = character, Next = 1, Count = 0, Times = {}, Positions = {}, Immune = {} }
			histories[player] = history
		end
		local slot = history.Next
		history.Times[slot] = now
		history.Positions[slot] = hitbox.Position
		history.Immune[slot] = HitboxLibrary.isImmunized(player)
		history.Next = slot % SAMPLE_CAPACITY + 1
		history.Count = math.min(history.Count + 1, SAMPLE_CAPACITY)
	end
end

-- // Where the player's Hitbox was at `time` (an os.clock value), blended between the two samples around it, and whether they were
-- // immune around then. Nil when the history doesn't reach back that far.
local function getSampleAt(history: History, time: number): (Vector3?, boolean)
	local newerSlot: number? = nil
	for offset = 0, history.Count - 1 do
		local slot = (history.Next - 2 - offset) % SAMPLE_CAPACITY + 1
		local sampleTime = history.Times[slot]
		if sampleTime <= time then
			if not newerSlot then
				return history.Positions[slot], history.Immune[slot]
			end
			local span = history.Times[newerSlot] - sampleTime
			local alpha = if span > 0 then (time - sampleTime) / span else 0
			local position = history.Positions[slot]:Lerp(history.Positions[newerSlot], alpha)
			return position, history.Immune[slot] or history.Immune[newerSlot]
		end
		newerSlot = slot
	end
	return nil, false
end

-- // Distance from `point` to the segment a-b, measured on the ground plane (a boomerang flies flat; the Y overlap is checked separately)
local function horizontalDistanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(point.X - a.X, 0, point.Z - a.Z)
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 1e-6 then math.clamp(ap:Dot(ab) / lengthSquared, 0, 1) else 0
	return (ap - ab * t).Magnitude
end

-------------------------------------------------------------------------------
-- DASH RULE (balanced, favors the dasher). Change how dashes interact with rewinding HERE and nowhere else.
-------------------------------------------------------------------------------

-- // A rewound hit is skipped when the target was immune (dashing, spawn protection) at the rewound moment or just around it
-- // (immune in either of the two samples beside it). A target who is immune right now needs nothing here: CombatLibrary.attackHitPlayer
-- // already turns every hit on them away. Together that means: a dash that started after the thrower's view of the target still
-- // saves the dasher (immune now), and a dash that thrower's screen showed in progress can't be hit by a rewound hit (immune then).
local function isDodgingRewoundHit(wasImmuneAroundThatMoment: boolean): boolean
	return wasImmuneAroundThatMoment
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function LagCompensationLibrary.getRewindMilliseconds(): number
	return maxRewindSeconds * 1000
end

function LagCompensationLibrary.getDefaultMilliseconds(): number
	return GlobalConfig.LagCompensationMilliseconds
end

function LagCompensationLibrary.getMaxMilliseconds(): number
	return MAX_REWIND_MILLISECONDS
end

function LagCompensationLibrary.isEnabled(): boolean
	return maxRewindSeconds > 0
end

-- // Server only. 0 turns lag compensation off (and forgets the history). Not saved.
function LagCompensationLibrary.setRewindMilliseconds(milliseconds: number)
	assert(isServer, "LagCompensationLibrary.setRewindMilliseconds is server only")
	maxRewindSeconds = math.clamp(milliseconds, 0, MAX_REWIND_MILLISECONDS) / 1000
	if maxRewindSeconds <= 0 then
		table.clear(histories)
	end
end

-- // How far back to look for this thrower: their ping plus a little interpolation delay, but never more than the setting. 0 = off.
function LagCompensationLibrary.getRewindSeconds(thrower: Player): number
	if not isServer or maxRewindSeconds <= 0 then
		return 0
	end
	return math.min(thrower:GetNetworkPing() + INTERPOLATION_DELAY_SECONDS, maxRewindSeconds)
end

-- // The characters a boomerang sweep (a ball of `radius` moving from `origin` along `direction` for `distance`) would hit if every
-- // other player were where `thrower` saw them `rewindSeconds` ago.
function LagCompensationLibrary.getRewoundHitModels(thrower: Player, rewindSeconds: number, origin: Vector3, direction: Vector3, distance: number, radius: number): { Model }
	local hitModels: { Model } = {}
	if not isServer or rewindSeconds <= 0 then
		return hitModels
	end

	local sweepEnd = origin + direction * distance
	local pastTime = os.clock() - rewindSeconds
	for player, history in pairs(histories) do
		if player == thrower then
			continue
		end
		local character, hitbox = getAliveHitbox(player)
		if not character or not hitbox or history.Character ~= character then
			continue
		end
		local pastPosition, wasImmune = getSampleAt(history, pastTime)
		if not pastPosition or isDodgingRewoundHit(wasImmune) then
			continue
		end
		-- // The Hitbox is a vertical cylinder: its Size is (height, diameter, diameter)
		local hitboxRadius = math.min(hitbox.Size.Y, hitbox.Size.Z) / 2
		local halfHeight = hitbox.Size.X / 2
		if math.abs(origin.Y - pastPosition.Y) <= halfHeight + radius
			and horizontalDistanceToSegment(pastPosition, origin, sweepEnd) <= hitboxRadius + radius
		then
			table.insert(hitModels, character)
		end
	end
	return hitModels
end

export type RewoundTarget = {
	Player: Player,
	Character: Model,
	Hitbox: BasePart, -- // The live Hitbox (for its size; its position is Position below)
	Position: Vector3, -- // Where the Hitbox's centre was at the rewound moment
}

-- // Every other living player as `viewer` saw them `rewindSeconds` ago (T-125: the slash checks its swing against these). Leaves out
-- // anyone who was immune around that moment (same dash rule as boomerang hits), and anyone the history doesn't reach back for.
function LagCompensationLibrary.getRewoundTargets(viewer: Player, rewindSeconds: number): { RewoundTarget }
	local targets: { RewoundTarget } = {}
	if not isServer or rewindSeconds <= 0 then
		return targets
	end

	local pastTime = os.clock() - rewindSeconds
	for player, history in pairs(histories) do
		if player == viewer then
			continue
		end
		local character, hitbox = getAliveHitbox(player)
		if not character or not hitbox or history.Character ~= character then
			continue
		end
		local pastPosition, wasImmune = getSampleAt(history, pastTime)
		if not pastPosition or isDodgingRewoundHit(wasImmune) then
			continue
		end
		table.insert(targets, { Player = player, Character = character, Hitbox = hitbox, Position = pastPosition })
	end
	return targets
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

if isServer then
	RunService.Heartbeat:Connect(function()
		if maxRewindSeconds > 0 then
			record()
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		histories[player] = nil
	end)
end

return LagCompensationLibrary
