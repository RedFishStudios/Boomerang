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

-- // Chain eliminations (tuned in GlobalConfig)
local CHAIN_RADIUS = GlobalConfig.ElectricChainRadius
local CHAIN_LINK_DELAY = GlobalConfig.ElectricChainLinkDelay
-- // Weapon id passed to the kill path for chained eliminations (elim message: "Shocked")
local CHAIN_WEAPON_ID = "ElectricChain"
-- // Weapon id ExplosiveBoomerang passes to the kill path for explosion eliminations (T-056: these start chains too)
local EXPLOSION_WEAPON_ID = "ExplosiveBoomerang"
local CHAIN_RADIUS_VISUAL_LIFETIME = 5
local CHAIN_RADIUS_VISUAL_HEIGHT = 0.5

-- // Arc visual (client only), matching the game's electric effects (blue, full light emission)
local ARC_COLOR = Color3.fromRGB(0, 131, 255)
local ARC_CORE_COLOR = Color3.fromRGB(190, 225, 255)
local ARC_GLOW_TEXTURE = "rbxassetid://243660373" -- // Same glow as the ElectrifiedObject particle
local ARC_SEGMENT_LENGTH = 2.5
local ARC_MAX_SEGMENTS = 24
local ARC_JITTER = 1.2
local ARC_CORE_WIDTH = 0.25
local ARC_GLOW_WIDTH = 1.4
local ARC_GLOW_TRANSPARENCY = 0.3
local ARC_FLICKERS = 3
local ARC_FLICKER_INTERVAL = 0.08
local ARC_FADE_TIME = 0.2
local ARC_HIT_EMIT_COUNT = 3

local visualizeChainRadiusRemote = SimpleRemotes.getEvent("VisualizeElectricChainRadius")
local chainArcRemote = SimpleRemotes.getEvent("ElectricChainArc")

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local nextArcId = 0

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

local startChain: (thrower: Player?, victim: Player, origin: Vector3) -> ()

-- // Eliminates every living enemy of the thrower within CHAIN_RADIUS of origin. Each elimination goes through
-- // CombatLibrary.attackHitPlayer, which fires PlayerKilledPlayerTasks again and continues the chain from that player.
-- // With no thrower (the zapchain command on yourself), everyone in range is hit, nobody is credited, and the chain continues here.
local function chainFrom(thrower: Player?, victim: Player, origin: Vector3)
	task.delay(CHAIN_LINK_DELAY, function()
		local gameStateData = GameStateLibrary.getGameStateData()
		if gameStateData.GameplayPhase:Get() ~= GameplayPhaseEnums.RoundActive then
			return
		end

		for _, player in ipairs(gameStateData.LivingPlayersInArena:Get()) do
			if player == thrower or player == victim or not isAlive(player) then
				continue
			end
			if thrower and not GameTeamLibrary.areEnemies(thrower, player) then
				continue
			end
			local targetPosition = player.Character.PrimaryPart.Position
			if (targetPosition - origin).Magnitude > CHAIN_RADIUS then
				continue
			end
			CombatLibrary.attackHitPlayer(thrower :: Player, CHAIN_WEAPON_ID, player, nil, 10000, true)
			-- // Only draw the arc if the link actually eliminated them (a shield or immunity can block it)
			if not isAlive(player) then
				chainArcRemote:FireAllClients(origin, targetPosition)
				if not thrower then
					startChain(nil, player, targetPosition)
				end
			end
		end
	end)
end

-- // A chain origin: shows the debug radius (if enabled) and chains to everyone in range of the victim
startChain = function(thrower: Player?, victim: Player, origin: Vector3)
	if GlobalConfig.VisualizeElectricChainRadius then
		visualizeChainRadiusRemote:FireAllClients(origin, CHAIN_RADIUS)
	end
	chainFrom(thrower, victim, origin)
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

-- // Jagged, flickering electric arc between two points, then a burst of the ElectricExplosion particles on the target (client only)
local function drawChainArc(from: Vector3, to: Vector3)
	local segmentCount = math.clamp(math.floor((to - from).Magnitude / ARC_SEGMENT_LENGTH), 2, ARC_MAX_SEGMENTS)
	local basis = CFrame.lookAt(from, to)

	local holder = Instance.new("Part")
	holder.Name = "ElectricChainArc"
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.CFrame = CFrame.new(from)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false

	local attachments: { Attachment } = {}
	for i = 1, segmentCount + 1 do
		local attachment = Instance.new("Attachment")
		attachment.Parent = holder
		attachments[i] = attachment
	end

	local beams: { { Beam: Beam, BaseTransparency: number } } = {}
	local function addBeam(attachment0: Attachment, attachment1: Attachment, color: Color3, width: number, transparency: number, texture: string?)
		local beam = Instance.new("Beam")
		beam.Attachment0 = attachment0
		beam.Attachment1 = attachment1
		beam.Color = ColorSequence.new(color)
		beam.Width0 = width
		beam.Width1 = width
		beam.Transparency = NumberSequence.new(transparency)
		beam.LightEmission = 1
		beam.Brightness = 5
		beam.FaceCamera = true
		beam.Segments = 1
		if texture then
			beam.Texture = texture
			beam.TextureMode = Enum.TextureMode.Stretch
		end
		beam.Parent = holder
		table.insert(beams, { Beam = beam, BaseTransparency = transparency })
	end
	for i = 1, segmentCount do
		addBeam(attachments[i], attachments[i + 1], ARC_COLOR, ARC_GLOW_WIDTH, ARC_GLOW_TRANSPARENCY, ARC_GLOW_TEXTURE)
		addBeam(attachments[i], attachments[i + 1], ARC_CORE_COLOR, ARC_CORE_WIDTH, 0, nil)
	end

	local function reshape()
		for i, attachment in ipairs(attachments) do
			local position = from:Lerp(to, (i - 1) / segmentCount)
			if i > 1 and i < #attachments then
				position += basis.RightVector * (math.random() * 2 - 1) * ARC_JITTER
				position += basis.UpVector * (math.random() * 2 - 1) * ARC_JITTER
			end
			attachment.WorldPosition = position
		end
	end

	reshape()
	holder.Parent = workspace

	nextArcId += 1
	ParticlesLibrary.emit(`ElectricChainHit_{nextArcId}`, "ElectricExplosion", to, ARC_HIT_EMIT_COUNT)

	task.spawn(function()
		for _ = 2, ARC_FLICKERS do
			task.wait(ARC_FLICKER_INTERVAL)
			reshape()
		end
		task.wait(ARC_FLICKER_INTERVAL)

		local fadeStart = os.clock()
		while holder.Parent do
			local alpha = math.min((os.clock() - fadeStart) / ARC_FADE_TIME, 1)
			for _, entry in ipairs(beams) do
				entry.Beam.Transparency = NumberSequence.new(entry.BaseTransparency + (1 - entry.BaseTransparency) * alpha)
			end
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		holder:Destroy()
	end)
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

-- // Server, dev testing (zapchain command): eliminates victim as if by an Electric boomerang and starts a chain from them.
-- // With a thrower, the eliminations are credited to them and their teammates are skipped; the thrower never needs the pickup.
function ElectricBoomerang.triggerChain(victim: Player, thrower: Player?): (boolean, string)
	if not isServer then
		return false, "triggerChain is server-only."
	end
	if GameStateLibrary.getGameStateData().GameplayPhase:Get() ~= GameplayPhaseEnums.RoundActive then
		return false, "A round must be active."
	end
	if not isAlive(victim) then
		return false, `{victim.Name} is not alive.`
	end
	if thrower == victim then
		thrower = nil
	end

	local origin = victim.Character.PrimaryPart.Position
	-- // With a thrower, PlayerKilledPlayerTasks sees CHAIN_WEAPON_ID and starts the chain itself
	CombatLibrary.attackHitPlayer(thrower :: Player, CHAIN_WEAPON_ID, victim, nil, 10000, true)
	if isAlive(victim) then
		return false, `{victim.Name} was not eliminated (shield or immunity?).`
	end
	if not thrower then
		startChain(nil, victim, origin)
	end
	return true, `Started an electric chain on {victim.Name}.`
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

		-- // A chain starts from a thrown-boomerang or Explosive explosion elimination while the pickup is active;
		-- // once started, it runs to the end
		local isChainLink = weaponId == CHAIN_WEAPON_ID
		local tool = Tools[weaponId]
		local isElectricHit = (weaponId == EXPLOSION_WEAPON_ID or (tool ~= nil and tool.LogicClass == "Boomerang"))
			and PickupLibrary.hasPickupEffectActive(killer.UserId, script.Name)
		if not isChainLink and not isElectricHit then
			return
		end

		local character = victim.Character
		local rootPart = character and character.PrimaryPart
		if rootPart then
			startChain(killer, victim, rootPart.Position)
		end
	end)

	ExplosiveBoomerang.ExplosionOccurred:Add(function(player: Player, explosionCFrame: CFrame)
		if not PickupLibrary.hasPickupEffectActive(player.UserId, script.Name) then
			return
		end

		local particleId = `ElectricExplosion_{player.UserId}_{workspace:GetServerTimeNow()}`
		ParticlesLibrary.play(particleId, "ElectricExplosion", explosionCFrame.Position, nil, EXPLOSION_LIFETIME, true)
	end)
else
	chainArcRemote.OnClientEvent:Connect(drawChainArc)

	visualizeChainRadiusRemote.OnClientEvent:Connect(function(position: Vector3, radius: number)
		if GlobalConfig.VisualizeElectricChainRadius then
			showChainRadius(position, radius)
		end
	end)
end

return ElectricBoomerang
