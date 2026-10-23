--[[
	RecallChargeController (T-090)

	The visuals of a manual recall of a dead boomerang, for EVERY player (each client renders them from the replicated state, so
	everyone sees the same thing):
	  - the "Summon" animation on the player, and
	  - the SelectionRing around their boomerang, tinted like their boomerang trail (BoomerangColorUtil).
	Both exist exactly while DeadWeaponLogic.isRecallChargeActive(player): the recall is being held on a dead boomerang (it is
	lifting), or the charged boomerang is flying back. They end when the recall is released early (the ring shrinks away) or when
	the boomerang is caught / removed (the ring is destroyed at once and the animation stops).
	(The lift itself and the charge timing live in Dead.luau; the player-to-boomerang beam is DeadWeaponBeamController.)

	Like the beam controller, nothing here reacts to events: every frame it compares what should exist with what does, so a
	late, duplicated or missing event can't leave a stray ring or a stuck animation.
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

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local CONTAINER_NAME = "RecallSelectionRings"
local RING_START_SIZE = Vector3.new(0.001, 0.001, 0.001)
local RING_START_TRANSPARENCY = 1
-- // Grow: the size overshoots a little (Back) and settles; transparency fades in smoothly alongside
local GROW_SIZE_EASING = Enum.EasingStyle.Back
local GROW_TRANSPARENCY_EASING = Enum.EasingStyle.Quad

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
-- // T-111: rings shrinking away after an early release, still following their player's boomerang until they are gone
local vanishingRings: { [MeshPart]: Player } = {}
local summonPlaying: { [Player]: boolean } = {}
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

-- // Where the player's boomerang model is drawn right now (dead or dying, or flying back), whatever the recall state
local function getAnyWeaponPosition(player: Player): Vector3?
	local deadWeaponData = DeadWeapons.Data[player]
	local thrownWeaponData = ThrownWeapons.Data[player]
	local host: Instance? = if deadWeaponData then deadWeaponData.Host elseif thrownWeaponData then thrownWeaponData.Host else nil
	if host and host.Parent and (host:IsA("Model") or host:IsA("BasePart")) then
		return host:GetPivot().Position
	end
	return nil
end

-- // The part the ring follows: the boomerang's pivot (dead boomerang, or the charged one flying back)
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

-- // immediate = the boomerang was caught / removed: destroy it now. Otherwise (released early) it shrinks away quickly.
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
	vanishingRings[ring] = player -- // T-111: keeps clinging to the boomerang as it drops and slides after the release
	vanishTween.Completed:Once(function()
		vanishingRings[ring] = nil
		ring:Destroy()
	end)
	vanishTween:Play()
	Debris:AddItem(ring, vanishSeconds + 1) -- // Safety net: never leaves a ring behind even if the tween is cancelled
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

local function reconcilePlayer(player: Player)
	local position = getWeaponPosition(player)
	local wanted = position ~= nil and DeadWeaponLogic.isRecallChargeActive(player)

	setSummon(player, wanted)

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
		-- // Still has a (resting) dead boomerang = the recall was released early: shrink away. Otherwise it was caught.
		removeRing(player, DeadWeapons.Data[player] == nil)
	end
end

local function reconcile()
	for _, player in Players:GetPlayers() do
		reconcilePlayer(player)
	end
	-- // T-111: shrinking rings follow the boomerang too, until they are gone
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
		-- // The asset lives in ReplicatedStorage.Shared.Assets; its current size is the ring's full (100%) size
		local template = ReplicatedStorage.Shared:WaitForChild("Assets"):WaitForChild("SelectionRing") :: MeshPart
		ringTemplate = template
		ringFullSize = template.Size
		ringRotation = template.CFrame.Rotation
		-- // T-111: after the frame's movement (boomerangs move in Stepped / PreSimulation), so the ring is placed on where the
		-- // boomerang is drawn this frame instead of lagging a frame behind it (RenderStepped runs before they move)
		RunService.Heartbeat:Connect(reconcile)
	end)
end

return RecallChargeController
