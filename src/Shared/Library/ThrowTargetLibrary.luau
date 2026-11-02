--[[
	ThrowTargetLibrary

	Description:
	SERVER: picks the enemy a thrown boomerang curves toward (BoomerangCurveLibrary bends the throw through the target).
	  1. A clicked target: on PC the client reports the enemy whose character the mouse was on when the throw was released.
	     The server only accepts it if it's a living enemy in the arena within the throw's range, and uses that player's
	     position on the server.
	  2. Otherwise the cone: the living enemy closest to the aim line within CONE_HALF_ANGLE_DEGREES either side of the
	     aim, within the throw's range. This is how touch and console throws find a target, and PC's fallback.
	  3. Neither: nil (the throw curves through the aimed point, or at full range).
	Disguised players are never targeted, by a click or by the cone.
	Pure lookups; no state.
]]

local ThrowTargetLibrary = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local Disguise = require(ReplicatedStorage.Shared.Logics.PickupLogics.Disguise)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // How far either side of the aim an enemy can be for the cone to pick them
ThrowTargetLibrary.CONE_HALF_ANGLE_DEGREES = 20

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // An enemy of the thrower who is alive in the arena: their root part on the server, or nil
local function getTargetableRoot(thrower: Player, target: Player?): BasePart?
	if not target or target == thrower or not GameTeamLibrary.areEnemies(thrower, target) then
		return nil
	end
	if Disguise.isActive(target) then
		return nil -- // A disguised player is never auto-targeted (it would give the disguise away)
	end
	local living = GameStateLibrary.getGameStateData().LivingPlayersInArena:Get() or {}
	if not table.find(living, target) then
		return nil
	end
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character.PrimaryPart
end

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The position to curve through, or nil. origin: where the throw starts. aimDirection: horizontal unit aim.
-- // clickedUserId: the enemy the PC client says was clicked (nil for other controls). maxDistance: the throw's range.
function ThrowTargetLibrary.findTarget(thrower: Player, origin: Vector3, aimDirection: Vector3, clickedUserId: number?, maxDistance: number): Vector3?
	-- // 1. Clicked directly on an enemy
	if clickedUserId then
		local root = getTargetableRoot(thrower, Players:GetPlayerByUserId(clickedUserId))
		if root and horizontal(root.Position - origin).Magnitude <= maxDistance then
			return root.Position
		end
	end

	-- // 2. The cone: the enemy closest to the aim line
	local minDot = math.cos(math.rad(ThrowTargetLibrary.CONE_HALF_ANGLE_DEGREES))
	local bestPosition: Vector3? = nil
	local bestDot = -math.huge
	for _, player in Players:GetPlayers() do
		local root = getTargetableRoot(thrower, player)
		if not root then
			continue
		end
		local toTarget = horizontal(root.Position - origin)
		local distance = toTarget.Magnitude
		if distance < 1e-3 or distance > maxDistance then
			continue
		end
		local dot = (toTarget / distance):Dot(aimDirection)
		if dot >= minDot and dot > bestDot then
			bestDot = dot
			bestPosition = root.Position
		end
	end
	return bestPosition
end

return ThrowTargetLibrary
