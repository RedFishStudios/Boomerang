--[[
	RecallChargeController

	Visuals of a manual recall of a dead boomerang, for EVERY player (rendered on each client from replicated state):
	  - the "Summon" animation on the player, with pale-yellow pulse rings at the pulling (right) hand
	  - the SelectionRing around their boomerang, tinted like their boomerang trail (BoomerangColorUtil)
	Both exist exactly while DeadWeaponLogic.isRecallChargeActive(player): the recall is held on a dead boomerang (lifting),
	or the charged boomerang is flying back. They end when the recall is released early (the ring shrinks away) or the
	boomerang is caught / removed (the ring is destroyed at once and the animation stops). An automatic return shows neither.
	(The lift and charge timing are in Dead.luau; the player-to-boomerang beam is DeadWeaponBeamController.)

	Like the beam controller, nothing reacts to events: every frame it compares what should exist with what does, so late,
	duplicated or missing events can't leave a stray ring or stuck animation.
]]

local RecallChargeController = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local DeadWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Dead)
local BoomerangColorUtil = require(ReplicatedStorage.Shared.Utils.BoomerangColorUtil)
local AnimationController = require(ReplicatedStorage.Client.Core.AnimationController)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CONTAINER_NAME = "RecallSelectionRings"
local RING_START_SIZE = Vector3.new(0.001, 0.001, 0.001)
local RING_START_TRANSPARENCY = 1
-- // Grow: size overshoots slightly (Back) and settles; transparency fades in alongside
local GROW_SIZE_EASING = Enum.EasingStyle.Back
local GROW_TRANSPARENCY_EASING = Enum.EasingStyle.Quad

-- // Hand pulse: two rings growing out of the pulling hand, half a cycle apart, around a faint centre
local PULSE_HAND_NAME = "RightHand"
local PULSE_COLOR = Color3.fromRGB(255, 248, 159)
local PULSE_SIZE = 1.65 -- // Studs across at full size, for a hand 0.65 studs wide (scales with the hand)
local PULSE_PERIOD = 0.62 -- // Seconds per ring cycle
local PULSE_RING_THICKNESS = 1.7
local PULSE_CENTRE_TRANSPARENCY = 0.92

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type RingEntry = {
	Ring: MeshPart,
	Tweens: { Tween },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local rings: { [Player]: RingEntry } = {}
-- // Rings shrinking away after an early release, following their player's boomerang until gone
local vanishingRings: { [MeshPart]: Player } = {}
local summonPlaying: { [Player]: boolean } = {}
local handPulses: { [Player]: { Gui: BillboardGui, Hand: BasePart, Rings: { UIStroke }, StartedAt: number } } = {}
local container: Folder? = nil
local ringTemplate: MeshPart? = nil
local ringFullSize: Vector3 = Vector3.one
local ringRotation: CFrame = CFrame.identity -- // The asset's own orientation (lies flat)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	local existing = workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		container = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = workspace
	container = folder
	return folder
end

-- // Where the player's boomerang model is drawn now (dead, dying or flying back), regardless of recall state
local function getAnyWeaponPosition(player: Player): Vector3?
	local deadWeaponData = DeadWeapons.Data[player]
	local thrownWeaponData = ThrownWeapons.Data[player]
	local host: Instance? = if deadWeaponData then deadWeaponData.Host elseif thrownWeaponData then thrownWeaponData.Host else nil
	if host and host.Parent and (host:IsA("Model") or host:IsA("BasePart")) then
		return host:GetPivot().Position
	end
	return nil
end

-- // The part the ring follows: the boomerang's pivot (dead, or charged and flying back)
local function getWeaponPosition(player: Player): Vector3?
	local host: Instance? = nil
	local deadWeaponData = DeadWeapons.Data[player]
	if deadWeaponData then
		host = deadWeaponData.Host
	else
		local thrownWeaponData = ThrownWeapons.Data[player]
		if thrownWeaponData and thrownWeaponData.RecallFromDead == true then
			host = thrownWeaponData.Host
		end
	end
	if host and host.Parent and (host:IsA("Model") or host:IsA("BasePart")) then
		return host:GetPivot().Position
	end
	return nil
end

local function cancelTweens(entry: RingEntry)
	for _, tween in entry.Tweens do
		tween:Cancel()
	end
	table.clear(entry.Tweens)
end

local function createRing(player: Player, position: Vector3)
	if not ringTemplate then
		return
	end
	local ring = ringTemplate:Clone()
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.CastShadow = false
	ring.Color = BoomerangColorUtil.getColor(player)
	ring.Size = RING_START_SIZE
	ring.Transparency = RING_START_TRANSPARENCY
	ring.CFrame = CFrame.new(position) * ringRotation
	ring.Parent = getContainer()

	local growSeconds = GlobalConfig.SelectionRingGrowSeconds
	local sizeTween = TweenService:Create(ring, TweenInfo.new(growSeconds, GROW_SIZE_EASING, Enum.EasingDirection.Out), { Size = ringFullSize })
	local transparencyTween = TweenService:Create(ring, TweenInfo.new(growSeconds, GROW_TRANSPARENCY_EASING, Enum.EasingDirection.Out), { Transparency = 0 })
	sizeTween:Play()
	transparencyTween:Play()

	rings[player] = { Ring = ring, Tweens = { sizeTween, transparencyTween } }
end

-- // immediate = the boomerang was caught / removed: destroy now. Otherwise (released early) it shrinks away quickly.
local function removeRing(player: Player, immediate: boolean)
	local entry = rings[player]
	if not entry then
		return
	end
	rings[player] = nil
	cancelTweens(entry)

	local ring = entry.Ring
	if immediate or not ring.Parent then
		ring:Destroy()
		return
	end

	local vanishSeconds = GlobalConfig.SelectionRingVanishSeconds
	local info = TweenInfo.new(vanishSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local vanishTween = TweenService:Create(ring, info, { Size = RING_START_SIZE, Transparency = 1 })
	vanishingRings[ring] = player -- // Keeps following the boomerang as it drops and slides after release
	vanishTween.Completed:Once(function()
		vanishingRings[ring] = nil
		ring:Destroy()
	end)
	vanishTween:Play()
	Debris:AddItem(ring, vanishSeconds + 1) -- // Safety net: no ring is left behind if the tween is cancelled
end

local function setSummon(player: Player, wanted: boolean)
	local playing = summonPlaying[player] == true
	if wanted == playing then
		return
	end
	summonPlaying[player] = if wanted then true else nil
	if wanted then
		AnimationController.playCoreAnimation(player, "Summon")
	else
		AnimationController.stopCoreAnimation(player, "Summon")
	end
end

local function removeHandPulse(player: Player)
	local pulse = handPulses[player]
	if pulse then
		pulse.Gui:Destroy()
		handPulses[player] = nil
	end
end

local function createPulseRing(parent: Instance): UIStroke
	local frame = Instance.new("Frame")
	frame.Name = "PulseRing"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = PULSE_COLOR
	stroke.Thickness = PULSE_RING_THICKNESS
	stroke.Transparency = 1
	stroke.Parent = frame
	return stroke
end

local function updateHandPulse(player: Player, wanted: boolean)
	local character = if wanted then CharacterRenderController.getCharacterModel(player, false) else nil
	local hand = character and character:FindFirstChild(PULSE_HAND_NAME)
	if not hand or not hand:IsA("BasePart") then
		removeHandPulse(player)
		return
	end

	local pulse = handPulses[player]
	if pulse and (pulse.Hand ~= hand or not pulse.Gui.Parent) then
		removeHandPulse(player)
		pulse = nil
	end
	if not pulse then
		local size = PULSE_SIZE * math.clamp(hand.Size.X / 0.65, 0.65, 1.5)
		local gui = Instance.new("BillboardGui")
		gui.Name = "RecallHandPulse"
		gui.Adornee = hand
		gui.Size = UDim2.fromScale(size, size)
		gui.LightInfluence = 0
		local centre = Instance.new("Frame")
		centre.Name = "Centre"
		centre.AnchorPoint = Vector2.new(0.5, 0.5)
		centre.Position = UDim2.fromScale(0.5, 0.5)
		centre.Size = UDim2.fromScale(0.6, 0.6)
		centre.BackgroundColor3 = PULSE_COLOR
		centre.BackgroundTransparency = PULSE_CENTRE_TRANSPARENCY
		centre.BorderSizePixel = 0
		centre.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = centre
		pulse = { Gui = gui, Hand = hand, Rings = { createPulseRing(gui), createPulseRing(gui) }, StartedAt = os.clock() }
		handPulses[player] = pulse
		gui.Parent = getContainer()
	end

	local elapsed = os.clock() - pulse.StartedAt
	for index, stroke in pulse.Rings do
		local phase = (elapsed / PULSE_PERIOD + (index - 1) * 0.5) % 1
		local frame = stroke.Parent :: Frame
		local scale = 0.38 + phase * 0.6
		frame.Size = UDim2.fromScale(scale, scale)
		stroke.Transparency = 1 - math.sin(phase * math.pi) * 0.8 -- // Fades in and out so a restarting ring doesn't pop
	end
end

local function reconcilePlayer(player: Player)
	local position = getWeaponPosition(player)
	local wanted = position ~= nil and DeadWeaponLogic.isRecallChargeActive(player)
	setSummon(player, wanted)
	updateHandPulse(player, wanted)

	local entry = rings[player]
	if wanted then
		if entry and entry.Ring.Parent then
			entry.Ring.CFrame = CFrame.new(position :: Vector3) * ringRotation
		else
			if entry then
				removeRing(player, true)
			end
			createRing(player, position :: Vector3)
		end
	elseif entry then
		-- // A resting dead boomerang means the recall was released early: shrink away. Otherwise it was caught.
		removeRing(player, DeadWeapons.Data[player] == nil)
	end
end

local function reconcile()
	for _, player in Players:GetPlayers() do
		reconcilePlayer(player)
	end
	-- // Shrinking rings follow the boomerang until gone
	for ring, player in vanishingRings do
		if not ring.Parent then
			vanishingRings[ring] = nil
			continue
		end
		local position = getAnyWeaponPosition(player)
		if position then
			ring.CFrame = CFrame.new(position) * ringRotation
		end
	end
end

local function cleanupPlayer(player: Player)
	removeRing(player, true)
	removeHandPulse(player)
	summonPlaying[player] = nil
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function RecallChargeController.init()
	Players.PlayerRemoving:Connect(cleanupPlayer)
end

function RecallChargeController.start()
	task.spawn(function()
		-- // The asset is in ReplicatedStorage.Shared.Assets; its size is the ring's full (100%) size
		local template = ReplicatedStorage.Shared:WaitForChild("Assets"):WaitForChild("SelectionRing") :: MeshPart
		ringTemplate = template
		ringFullSize = template.Size
		ringRotation = template.CFrame.Rotation
		-- // After the frame's movement (boomerangs move in Stepped / PreSimulation), so the ring tracks the boomerang's
		-- // drawn
		-- // position without lagging a frame (RenderStepped runs before they move)
		RunService.Heartbeat:Connect(reconcile)
	end)
end

return RecallChargeController
