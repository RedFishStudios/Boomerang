local ElectricBoomerang = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local GameplayPhaseEnums = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local ParticlesLibrary = require(ReplicatedStorage.Shared.Library.ParticlesLibrary)
local PickupLibrary = require(ReplicatedStorage.Shared.Library.PickupLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameTeamLibrary = require(ReplicatedStorage.Shared.Library.GameTeamLibrary)
local ExplosiveBoomerang = require(ReplicatedStorage.Shared.Logics.PickupLogics.ExplosiveBoomerang)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

local isServer = RunService:IsServer()
local EFFECT_DURATION_SECONDS = GlobalConfig.GenericEffectTimeout
local EXPLOSION_LIFETIME = 1

-- // Chain eliminations. TODO: move these to GlobalConfig with the visuals pass (T-029)
local CHAIN_RADIUS = 15
local CHAIN_LINK_DELAY = 0.05
-- // Weapon id passed to the kill path for chained eliminations (elim message: "Shocked")
local CHAIN_WEAPON_ID = "ElectricChain"
local CHAIN_RADIUS_VISUAL_LIFETIME = 5
local CHAIN_RADIUS_VISUAL_HEIGHT = 0.5

local visualizeChainRadiusRemote = SimpleRemotes.getEvent("VisualizeElectricChainRadius")

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local ToolController
if not isServer then
	ToolController = require(ReplicatedStorage.Client.Core.ToolController)
end

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character.PrimaryPart ~= nil
end

-- // Eliminates every living enemy of the thrower within CHAIN_RADIUS of origin. Each elimination goes through
-- // CombatLibrary.attackHitPlayer, which fires PlayerKilledPlayerTasks again and continues the chain from that player.
local function chainFrom(thrower: Player, victim: Player, origin: Vector3)
	task.delay(CHAIN_LINK_DELAY, function()
		local gameStateData = GameStateLibrary.getGameStateData()
		if gameStateData.GameplayPhase:Get() ~= GameplayPhaseEnums.RoundActive then
			return
		end

		for _, player in ipairs(gameStateData.LivingPlayersInArena:Get()) do
			if player == thrower or player == victim or not isAlive(player) then
				continue
			end
			if not GameTeamLibrary.areEnemies(thrower, player) then
				continue
			end
			if (player.Character.PrimaryPart.Position - origin).Magnitude > CHAIN_RADIUS then
				continue
			end
			CombatLibrary.attackHitPlayer(thrower, CHAIN_WEAPON_ID, player, nil, 10000, true)
		end
	end)
end

-- // Debug: semi-transparent red cylinder showing the chain radius around a chain victim (client only)
local function showChainRadius(position: Vector3, radius: number)
	local cylinder = Instance.new("Part")
	cylinder.Name = "ElectricChainRadius"
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Size = Vector3.new(CHAIN_RADIUS_VISUAL_HEIGHT, radius * 2, radius * 2)
	cylinder.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	cylinder.Color = Color3.fromRGB(255, 0, 0)
	cylinder.Material = Enum.Material.SmoothPlastic
	cylinder.Transparency = 0.6
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.CanQuery = false
	cylinder.CanTouch = false
	cylinder.CastShadow = false
	cylinder.Parent = workspace
	Debris:AddItem(cylinder, CHAIN_RADIUS_VISUAL_LIFETIME)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ElectricBoomerang.onPickup(player: Player, startedAt: number?): number
	if not isServer then
		ToolController.addParticleToTool(player, "ElectricBoomerang")
	end

	return (startedAt or workspace:GetServerTimeNow()) + EFFECT_DURATION_SECONDS
end

function ElectricBoomerang.onEnd(player: Player)
	if not isServer then
		ToolController.removeParticleFromTool(player, "ElectricBoomerang")
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

if isServer then
	CombatLibrary.PlayerKilledPlayerTasks:Add(function(killer: Player, victim: Player, weaponId: string)
		if not killer or not victim or killer == victim then
			return
		end

		-- // A chain starts from a thrown-boomerang elimination while the pickup is active; once started, it runs to the end
		local isChainLink = weaponId == CHAIN_WEAPON_ID
		local tool = Tools[weaponId]
		local isElectricThrow = tool ~= nil
			and tool.LogicClass == "Boomerang"
			and PickupLibrary.hasPickupEffectActive(killer.UserId, script.Name)
		if not isChainLink and not isElectricThrow then
			return
		end

		local character = victim.Character
		local rootPart = character and character.PrimaryPart
		if rootPart then
			if isChainLink and GlobalConfig.VisualizeElectricChainRadius then
				visualizeChainRadiusRemote:FireAllClients(rootPart.Position, CHAIN_RADIUS)
			end
			chainFrom(killer, victim, rootPart.Position)
		end
	end)

	-- TODO: T-029 follow-up: eliminations from an Electric + Explosive explosion should also start chains
	ExplosiveBoomerang.ExplosionOccurred:Add(function(player: Player, explosionCFrame: CFrame)
		if not PickupLibrary.hasPickupEffectActive(player.UserId, script.Name) then
			return
		end

		local particleId = `ElectricExplosion_{player.UserId}_{workspace:GetServerTimeNow()}`
		ParticlesLibrary.play(particleId, "ElectricExplosion", explosionCFrame.Position, nil, EXPLOSION_LIFETIME, true)
	end)
else
	visualizeChainRadiusRemote.OnClientEvent:Connect(function(position: Vector3, radius: number)
		if GlobalConfig.VisualizeElectricChainRadius then
			showChainRadius(position, radius)
		end
	end)
end

return ElectricBoomerang
