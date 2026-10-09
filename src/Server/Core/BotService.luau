--[[
	BotService (T-079)

	A thin server-authoritative "bot" layer. A bot is a minimal INVISIBLE Humanoid rig:
	a HumanoidRootPart (in the Players collision group, so it collides with the environment like
	a player), a Humanoid (moved with Humanoid:Move), and a welded Hitbox part. Clients build the
	visible avatar themselves (BotController), so the server stays lightweight -- it only owns the
	small rig + its hitbox and lets Roblox replicate the rig's transform.

	Each bot runs a BotBehavior ({ start, update, shouldDespawn }); the Decoy is the first behavior.

	NOTE (needs Studio verification): a limbless Humanoid's standing/grounding may need HIP_HEIGHT
	tuning, and the fixed facing (AutoRotate off) may drift under physics. Marked TODO:VITAL below.
]]

local BotService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local BOTS_FOLDER_NAME = "Bots"
local PLAYERS_COLLISION_GROUP = CollisionGroupConstants.Players
local ROOT_SIZE = Vector3.new(2, 2, 1)
local HIP_HEIGHT = 2 -- // TODO:VITAL Studio-tune so the rootless rig stands on the floor at the right height
local HITBOX_SIZE = Vector3.new(10, 2.2, 10) -- // matches HitboxService's player hitbox cylinder

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Bot = {
	Id: string,
	OwnerUserId: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Hitbox: BasePart,
	Behavior: BotBehavior,
	MoveDirection: Vector3, -- // horizontal unit; the behavior sets this, the service applies it each frame
	SpawnedAt: number,
	State: { [any]: any }, -- // scratch space for the behavior
}

export type BotSpawnOptions = {
	CFrame: CFrame?, -- // where to spawn (defaults to the owner's root CFrame)
	WalkSpeed: number?,
}

export type BotBehavior = {
	start: ((bot: Bot) -> ())?,
	update: ((bot: Bot, deltaTime: number) -> ())?,
	shouldDespawn: ((bot: Bot) -> boolean)?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local bots: { [string]: Bot } = {}
local botsFolder: Folder? = nil
local botDespawnedEvent = SimpleRemotes.getEvent("BotDespawned")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getBotsFolder(): Folder
	if botsFolder and botsFolder.Parent then
		return botsFolder
	end
	local existing = workspace:FindFirstChild(BOTS_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		botsFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = BOTS_FOLDER_NAME
		folder.Parent = workspace
		botsFolder = folder
	end
	return botsFolder
end

local function flattenHorizontal(direction: Vector3): Vector3
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude <= 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return horizontal.Unit
end

local function buildRig(ownerUserId: number, botId: string, spawnCFrame: CFrame, walkSpeed: number): (Model, Humanoid, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = `Bot_{botId}`

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true -- // environment collision via the Players group
	root.CanQuery = false -- // not weapon-detectable until T-081 wires elimination
	root.CanTouch = false
	root.CollisionGroup = PLAYERS_COLLISION_GROUP
	root.CFrame = spawnCFrame
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.AutoRotate = false -- // facing is set explicitly; the decoy strafes (facing != movement)
	humanoid.WalkSpeed = walkSpeed
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	humanoid.HipHeight = HIP_HEIGHT
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.Parent = model

	model.PrimaryPart = root

	-- // Weapon hitbox: same shape/group as the player hitbox, kept non-queryable until T-081
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = HITBOX_SIZE
	hitbox.Shape = Enum.PartType.Cylinder
	hitbox.Massless = true
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanQuery = false -- // T-081 flips this on
	hitbox.CanTouch = false
	hitbox.CollisionGroup = PLAYERS_COLLISION_GROUP
	hitbox:PivotTo(root.CFrame * CFrame.Angles(0, 0, math.rad(90)))
	hitbox.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = root
	weld.Parent = hitbox

	model:SetAttribute("BotId", botId)
	model:SetAttribute("OwnerUserId", ownerUserId)

	model.Parent = getBotsFolder()
	return model, humanoid, root, hitbox
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Flatten + normalise a direction to the horizontal plane (shared helper for behaviors)
function BotService.flattenHorizontal(direction: Vector3): Vector3
	return flattenHorizontal(direction)
end

function BotService.spawn(ownerPlayer: Player, behavior: BotBehavior, options: BotSpawnOptions?): Bot?
	local ownerChar = ownerPlayer.Character
	local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
	local spawnCFrame = (options and options.CFrame)
		or (ownerRoot and ownerRoot:IsA("BasePart") and ownerRoot.CFrame)
		or nil
	if not spawnCFrame then
		warn(`BotService.spawn: no spawn CFrame available for {ownerPlayer.Name}`)
		return nil
	end

	local botId = HttpService:GenerateGUID(false)
	local walkSpeed = (options and options.WalkSpeed) or GlobalConfig.DefaultWalkSpeed
	local model, humanoid, root, hitbox = buildRig(ownerPlayer.UserId, botId, spawnCFrame, walkSpeed)

	local bot: Bot = {
		Id = botId,
		OwnerUserId = ownerPlayer.UserId,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Hitbox = hitbox,
		Behavior = behavior,
		MoveDirection = Vector3.zero,
		SpawnedAt = os.clock(),
		State = {},
	}
	bots[botId] = bot

	if behavior.start then
		behavior.start(bot)
	end
	return bot
end

function BotService.getBot(botId: string): Bot?
	return bots[botId]
end

function BotService.despawn(botId: string, reason: string?)
	local bot = bots[botId]
	if not bot then
		return
	end
	bots[botId] = nil
	botDespawnedEvent:FireAllClients(botId, reason)
	if bot.Model then
		bot.Model:Destroy()
	end
end

function BotService.despawnOwnedBy(userId: number, reason: string?)
	for botId, bot in pairs(bots) do
		if bot.OwnerUserId == userId then
			BotService.despawn(botId, reason)
		end
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function step(deltaTime: number)
	for botId, bot in pairs(bots) do
		if not bot.Model.Parent then
			bots[botId] = nil
			continue
		end
		local behavior = bot.Behavior
		if behavior.shouldDespawn and behavior.shouldDespawn(bot) then
			BotService.despawn(botId, "expired")
			continue
		end
		if behavior.update then
			behavior.update(bot, deltaTime)
		end
		bot.Humanoid:Move(bot.MoveDirection, false)
	end
end

function BotService.init()
	SimpleRemotes.getEvent("BotDespawned")
	getBotsFolder()

	GameStateLibrary.RoundFinishedTasks:Add(function()
		for botId in pairs(bots) do
			BotService.despawn(botId, "roundEnd")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		BotService.despawnOwnedBy(player.UserId, "ownerLeft")
	end)

	RunService.Heartbeat:Connect(step)
end

function BotService.start() end

function BotService.test() end

return BotService
