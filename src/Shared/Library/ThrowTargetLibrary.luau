--[[
	ThrowTargetLibrary

	Description:
	SERVER: picks the enemy a thrown boomerang curves toward (BoomerangCurveLibrary bends the throw through the target).
	  1. A clicked target: on PC the client reports the enemy (a player's UserId, or a bot's BotId) whose character the
	     mouse was on when the throw was released. The server only accepts it if it's a living enemy within the throw's
	     range, and uses its position on the server.
	  2. Otherwise the cone: of the living enemies within CONE_HALF_ANGLE_DEGREES either side of the aim and within the
	     throw's range, the one closest to the thrower. This is how touch and console throws find a target, and PC's
	     fallback.
	  3. Neither: nil (the throw curves through the aimed point, or at full range).
	Disguised players are never targeted, by a click or by the cone. Bots (e.g. decoys) are targets like players: any
	bot whose owner isn't the thrower or an ally of theirs.
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
	-- // Teammates and allies are never targets: areEnemies is false for a player on the thrower's own team, unless that
	-- // team has friendly fire on (its FriendlyFire attribute, GameTeamService). Bots follow their owner's team below.
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

-- // A bot (workspace.Bots, e.g. a decoy) the thrower may target: alive, and not theirs or an ally's. Its root part, or nil.
local function getTargetableBotRoot(thrower: Player, botModel: Instance?): BasePart?
	if not botModel or not botModel:IsA("Model") or typeof(botModel:GetAttribute("BotId")) ~= "string" then
		return nil
	end
	local ownerUserId = botModel:GetAttribute("OwnerUserId")
	if ownerUserId == thrower.UserId then
		return nil
	end
	local owner = if type(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
	if owner and not GameTeamLibrary.areEnemies(thrower, owner) then
		return nil
	end
	local humanoid = botModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return botModel.PrimaryPart
end

local function getBotModels(): { Instance }
	local botsFolder = workspace:FindFirstChild("Bots")
	return if botsFolder then botsFolder:GetChildren() else {}
end

local function findBotModel(botId: string): Instance?
	for _, model in getBotModels() do
		if model:GetAttribute("BotId") == botId then
			return model
		end
	end
	return nil
end

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The root parts of every bot (e.g. a decoy) the thrower may target: not theirs or an ally's, alive
function ThrowTargetLibrary.getEnemyBotRoots(thrower: Player): { BasePart }
	local roots: { BasePart } = {}
	for _, botModel in getBotModels() do
		local root = getTargetableBotRoot(thrower, botModel)
		if root then
			table.insert(roots, root)
		end
	end
	return roots
end

-- // The position to curve through, or nil. origin: where the throw starts. aimDirection: horizontal unit aim.
-- // clickedTarget: what the PC client says was clicked, a player's UserId or a bot's BotId (nil for other controls).
-- // maxDistance: the throw's range.
function ThrowTargetLibrary.findTarget(thrower: Player, origin: Vector3, aimDirection: Vector3, clickedTarget: (number | string)?, maxDistance: number): Vector3?
	-- // 1. Clicked directly on an enemy (player or bot)
	if clickedTarget then
		local root = if type(clickedTarget) == "number"
			then getTargetableRoot(thrower, Players:GetPlayerByUserId(clickedTarget))
			else getTargetableBotRoot(thrower, findBotModel(clickedTarget))
		if root and horizontal(root.Position - origin).Magnitude <= maxDistance then
			return root.Position
		end
	end

	-- // 2. The cone: of the enemies inside it, the one closest to the thrower
	local minDot = math.cos(math.rad(ThrowTargetLibrary.CONE_HALF_ANGLE_DEGREES))
	local bestPosition: Vector3? = nil
	local bestDistance = math.huge
	local candidates: { BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = getTargetableRoot(thrower, player)
		if root then
			table.insert(candidates, root)
		end
	end
	for _, botModel in getBotModels() do
		local root = getTargetableBotRoot(thrower, botModel)
		if root then
			table.insert(candidates, root)
		end
	end
	for _, root in candidates do
		local toTarget = horizontal(root.Position - origin)
		local distance = toTarget.Magnitude
		if distance < 1e-3 or distance > maxDistance then
			continue
		end
		local dot = (toTarget / distance):Dot(aimDirection)
		if dot >= minDot and distance < bestDistance then
			bestDistance = distance
			bestPosition = root.Position
		end
	end
	return bestPosition
end

return ThrowTargetLibrary
