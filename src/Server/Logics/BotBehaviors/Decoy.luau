--[[
	Decoy bot behavior (T-080)

	The first BotBehavior. The decoy FACES the owner's facing at spawn, but MOVES opposite the
	owner's movement at spawn (a random direction if the owner was standing still) -- so it
	strafes. It lives a few seconds, then BotService despawns it.
]]

local DecoyBehavior = {}
DecoyBehavior.CountsAsElimination = false -- // T-143: popping a decoy isn't an elimination (quests)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BotService = require(ServerStorage.Server.Core.BotService)
local CharacterService = require(ServerStorage.Server.Core.CharacterService)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local LIFETIME_SECONDS = 4 -- // design doc T-080 (tunable)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function randomHorizontal(): Vector3
	local angle = math.random() * math.pi * 2
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-------------------------------------------------------------------------------
-- BEHAVIOR
-------------------------------------------------------------------------------

function DecoyBehavior.start(bot: BotService.Bot)
	local owner = Players:GetPlayerByUserId(bot.OwnerUserId)
	local ownerChar = owner and owner.Character
	local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
	local ownerHumanoid = ownerChar and ownerChar:FindFirstChildOfClass("Humanoid")

	-- // Facing = the owner's facing at spawn (the rig already spawns at the owner's CFrame; make it explicit)
	local facing: Vector3? = nil
	if ownerRoot and ownerRoot:IsA("BasePart") then
		facing = BotService.flattenHorizontal(ownerRoot.CFrame.LookVector)
	elseif owner then
		local look = CharacterService.getLookDirection(owner)
		if look then
			facing = BotService.flattenHorizontal(look)
		end
	end
	facing = facing or Vector3.new(0, 0, -1)
	bot.Root.CFrame = CFrame.lookAt(bot.Root.Position, bot.Root.Position + facing)

	-- // Movement = opposite the owner's movement at spawn; random if they were standing still (so it strafes)
	if ownerHumanoid and ownerHumanoid.MoveDirection.Magnitude > 1e-3 then
		bot.MoveDirection = BotService.flattenHorizontal(-ownerHumanoid.MoveDirection)
	else
		bot.MoveDirection = BotService.flattenHorizontal(randomHorizontal())
	end

	bot.DespawnParticle = "DecoySmokePoof" -- // T-081 / T-078: smoke poof where the decoy vanishes
end

function DecoyBehavior.shouldDespawn(bot: BotService.Bot): boolean
	return (os.clock() - bot.SpawnedAt) >= LIFETIME_SECONDS
end

-- // Only an enemy may eliminate the decoy. The owner can't pop their own decoy unless
--    GlobalConfig.CanHitSelfDecoy is on; teammates follow the team's normal friendly-fire rule.
function DecoyBehavior.onHit(bot: BotService.Bot, throwerPlayer: Player): boolean
	if throwerPlayer.UserId == bot.OwnerUserId then
		return GlobalConfig.CanHitSelfDecoy == true
	end
	local owner = Players:GetPlayerByUserId(bot.OwnerUserId)
	if not owner then
		return true -- // owner left; the orphaned decoy can be popped by anyone (it's being cleaned up anyway)
	end
	return GameTeamLibrary.areEnemies(throwerPlayer, owner)
end

return DecoyBehavior
