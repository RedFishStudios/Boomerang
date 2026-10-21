--[[
	DeadWeaponBeamController

	Two beams between the LOCAL player and their OWN boomerang. Only the local client ever sees them: other players' boomerangs
	never get a beam.

	  1. "Dead" beam (BeamToDeadWeapon): while the boomerang is Dead, resting on the field, waiting for a manual recall. It
	     is created once, when the boomerang first dies, and destroyed when it is back in the player's hands. In between it is the same
	     beam: it fades in once the boomerang has landed (GlobalConfig.DeadBeamFadeSeconds), fades out gradually as the recall charges and
	     is completely invisible exactly when the charge peaks, stays invisible while the boomerang flies back, and fades back in if the
	     recall is released/cancelled or the boomerang is dead again (T-094). It fades out the same way when it goes away for any other reason, if it can still be drawn (if the boomerang or
	     the player's character is gone it is removed at once).
	  2. "Returning" beam (BeamToReturningWeapon): from the moment the charged recall starts moving the boomerang until it is
	     caught. It fades in over GlobalConfig.RecallReturnBeamFadeInSeconds.

	Both are built from scratch here (the `BeamToDeadWeapon` / `BeamToReturningWeapon` instances in the Studio workspace are
	only visual references and are never used at runtime):
	  - Attachment0 sits on the local character's `Hitbox` (HitboxService), at offset (0, 0, 0). (PLAYER_ATTACHMENT_OFFSET is in
	    world-upright terms and converted into the Hitbox's own space, since the Hitbox cylinder is rotated 90 degrees.)
	  - Attachment1 sits on the boomerang's PrimaryPart (or the first BasePart found in its model), offset (0, 1, 0).

	One beam of each kind at a time, by design (a "single source of truth" instead of event-driven create/destroy):
	  - Every frame `reconcile()` compares what SHOULD exist (derived from DeadWeapons.Data / ThrownWeapons.Data) with what DOES
	    exist and fixes the difference. Late, duplicated or missing events therefore can't leave a stray beam or a missing one.
	  - Everything a kind creates is tagged with that kind's own tag. Before building a beam, and whenever it is torn down,
	    every instance with the kind's tag is destroyed, so even a leaked beam from an earlier (failed) build is swept up.
	  - Set DEBUG to true to print every create/destroy and to warn if more than one beam of a kind is ever found.
]]

local DeadWeaponBeamController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local DeadWeaponLogic = require(ReplicatedStorage.Shared.Logics.WeaponLogics.Dead)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEBUG = false

local CONTAINER_NAME = "DeadWeaponBeams"
local CONTAINER_TAG = "DeadWeaponBeamContainer"

-- // Attachment offsets (from the BeamToDeadWeapon / BeamToReturningWeapon references): boomerang (0, 1, 0), player (0, 0, 0)
-- // (the player one was moved from (0, 2, 0) to the Hitbox's center by Sol, 2026-10-20)
local WEAPON_ATTACHMENT_OFFSET = Vector3.new(0, 1, 0) -- // In the boomerang part's own space (the dead beam: a stud above it)
local RETURNING_WEAPON_ATTACHMENT_OFFSET = Vector3.zero -- // The returning beam attaches directly on the boomerang itself
local PLAYER_ATTACHMENT_OFFSET = Vector3.zero -- // In WORLD-upright terms, converted to the Hitbox's space (zero = the Hitbox's center)

-- // Look shared by both beams
local BEAM_SEGMENTS = 100
local BEAM_BRIGHTNESS = 1
local BEAM_LIGHT_EMISSION = 0
local BEAM_LIGHT_INFLUENCE = 1
local BEAM_Z_OFFSET = 0
local BEAM_TEXTURE_SPEED = 1
local BEAM_COLOR = ColorSequence.new(Color3.new(1, 1, 1))

-- // Dead beam (copied from the BeamToDeadWeapon reference)
local DEAD_TEXTURE = "rbxassetid://75521069157462"
local DEAD_WIDTH = 6
local DEAD_TEXTURE_ASPECT_RATIO = 1 -- // The texture image is square (1:1): one tile is as long as it is wide
-- // Transparency flows 1 -> middle -> 1 so the beam fades in at the start and out at the end. The two middle values come from the
-- // reference. The whole beam is then scaled by an opacity (1 = the reference look, 0 = invisible), see deadOpacity.
local DEAD_TRANSPARENCY_START_TIME = 0.10109288990497589
local DEAD_TRANSPARENCY_END_TIME = 0.8989070653915405
local DEAD_NORMAL_MIDDLE_A = 0.5061728358268738
local DEAD_NORMAL_MIDDLE_B = 0.4938271641731262

-- // Returning beam (copied from the BeamToReturningWeapon reference: no texture, width 1, Wrap mode, TextureLength 1)
local RETURNING_WIDTH = 1
local RETURNING_TEXTURE_LENGTH = 1
local RETURNING_TRANSPARENCY: { { Time: number, Value: number } } = {
	{ Time = 0, Value = 1 },
	{ Time = 0.10382513701915741, Value = 1 },
	{ Time = 0.5601092576980591, Value = 0.9506173133850098 },
	{ Time = 0.8715846538543701, Value = 0.5925925970077515 },
	{ Time = 1, Value = 1 },
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ActiveBeam = {
	Beam: Beam,
	WeaponAttachment: Attachment,
	PlayerAttachment: Attachment,
	WeaponPart: BasePart,
	Hitbox: BasePart,
	CreatedAt: number, -- // os.clock() when it was built
	FadeDone: boolean?, -- // Returning beam: its fade-in has finished (nothing more to update)
}

type BeamKind = {
	Id: string,
	Tag: string, -- // On everything this kind creates (beam + attachments), used to sweep leftovers
	BeamName: string,
	AttachmentName: string,
	WeaponAttachmentOffset: Vector3, -- // Where this kind's beam attaches, in the boomerang part's own space
	Active: ActiveBeam?,
	-- // The boomerang part this kind's beam should point at right now, or nil if it should not exist
	getWeaponPart: () -> BasePart?,
	-- // Sets the constant look of a freshly created beam
	configure: (beam: Beam) -> (),
	-- // The transparency to show right now (called on creation and every frame while the beam exists)
	getTransparency: (active: ActiveBeam, deltaTime: number) -> NumberSequence?,
	-- // Resets per-beam state when there is no beam
	reset: (() -> ())?,
	-- // Called right before a fresh beam is built
	onCreate: (() -> ())?,
	-- // The beam fades in and out: when its boomerang goes away it keeps fading out (if it still can) before it is removed
	step: ((wanted: boolean, deltaTime: number) -> ())?,
	-- // True once a fading-out beam is invisible and can be removed
	isFadedOut: (() -> boolean)?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local container: Folder? = nil
local deadOpacity = 0 -- // Dead beam: 1 = fully shown, 0 = invisible. Fades in when it appears, out as the recall charges (see getDeadTarget)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function debugPrint(...)
	if DEBUG then
		print("[DeadWeaponBeam]", ...)
	end
end

local function getContainer(): Folder
	if container and container.Parent then
		return container
	end
	-- // Reuse a folder left in the workspace if our reference was lost, so we never end up with two
	local existing = workspace:FindFirstChild(CONTAINER_NAME)
	if existing and existing:IsA("Folder") then
		container = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	CollectionService:AddTag(folder, CONTAINER_TAG)
	folder.Parent = workspace
	container = folder
	return folder
end

-- // The part the boomerang's attachment goes on: the part itself, or a model's PrimaryPart / first BasePart found
local function getWeaponPart(host: Instance?): BasePart?
	if not host or not host.Parent then
		return nil
	end
	if host:IsA("BasePart") then
		return host
	end
	if host:IsA("Model") then
		if host.PrimaryPart and host.PrimaryPart.Parent then
			return host.PrimaryPart
		end
		return host:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getLocalHitbox(): BasePart?
	local character = localPlayer.Character
	local hitbox = character and character:FindFirstChild("Hitbox")
	if hitbox and hitbox:IsA("BasePart") and hitbox.Parent then
		return hitbox
	end
	return nil
end

-- // In Static (and Wrap) texture mode, TextureLength is the length of ONE texture tile in studs (verified in Studio). It does
-- // not depend on how far apart the ends are: the pattern simply repeats along the beam, and the last tile is cut off.
-- // For a square (1:1) image to look undistorted, a tile must be as long as the beam is wide, so with width 6 it is 6 studs.
local function getDeadTileLength(): number
	return DEAD_WIDTH * DEAD_TEXTURE_ASPECT_RATIO
end

-- // opacity 1 = the reference's transparency, 0 = completely invisible
local function buildDeadTransparency(opacity: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(DEAD_TRANSPARENCY_START_TIME, 1 - (1 - DEAD_NORMAL_MIDDLE_A) * opacity),
		NumberSequenceKeypoint.new(DEAD_TRANSPARENCY_END_TIME, 1 - (1 - DEAD_NORMAL_MIDDLE_B) * opacity),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- // How visible the dead beam should be right now, and whether that value is a smooth countdown that opacity should follow exactly.
-- //   charging a recall: 1 -> 0 over GlobalConfig.RecallCharge, reaching 0 exactly when the charge peaks (server time, so every
-- //     machine agrees, and releasing or restarting the charge simply changes this value; the beam never jumps)
-- //   otherwise: 1 while the boomerang rests dead, 0 when the beam shouldn't be shown
local function getDeadTarget(wanted: boolean): (number, boolean)
	if not wanted then
		return 0, false
	end
	local deadWeaponData = DeadWeapons.Data[localPlayer]
	if not deadWeaponData or deadWeaponData.State ~= DeadWeapons.StateEnum.Dead then
		return 0, false -- // Still dying (sliding to a stop), or flying back to the player: the beam exists but is invisible
	end
	if DeadWeaponLogic.isRecallCharging(deadWeaponData) and deadWeaponData.RecallChargeStart then
		local progress = (workspace:GetServerTimeNow() - deadWeaponData.RecallChargeStart) / math.max(GlobalConfig.RecallCharge, 0.01)
		return 1 - math.clamp(progress, 0, 1), true
	end
	return 1, false
end

-- // Moves deadOpacity toward the target: never up while a charge is in progress (it just follows the countdown down), otherwise at
-- // a fixed rate (GlobalConfig.DeadBeamFadeSeconds for a full fade) in both directions
local function stepDeadOpacity(wanted: boolean, deltaTime: number)
	local target, charging = getDeadTarget(wanted)
	if charging then
		deadOpacity = math.min(deadOpacity, target)
		return
	end
	local step = deltaTime / math.max(GlobalConfig.DeadBeamFadeSeconds, 0.01)
	if target > deadOpacity then
		deadOpacity = math.min(target, deadOpacity + step)
	else
		deadOpacity = math.max(target, deadOpacity - step)
	end
end

-- // fadeAlpha 0 = fully transparent, 1 = the reference's transparency
local function buildReturningTransparency(fadeAlpha: number): NumberSequence
	local keypoints = {}
	for _, point in RETURNING_TRANSPARENCY do
		keypoints[#keypoints + 1] = NumberSequenceKeypoint.new(point.Time, 1 + (point.Value - 1) * fadeAlpha)
	end
	return NumberSequence.new(keypoints)
end

-- // Destroys the kind's tracked beam AND every instance carrying its tag. Safe to call at any time, any number of times.
local function destroyAll(kind: BeamKind, reason: string)
	local hadSomething = kind.Active ~= nil
	kind.Active = nil

	for _, instance in CollectionService:GetTagged(kind.Tag) do
		instance:Destroy()
		hadSomething = true
	end

	if hadSomething then
		debugPrint(kind.Id, "destroyed:", reason)
	end
end

local function createBeam(kind: BeamKind, weaponPart: BasePart, hitbox: BasePart)
	-- // Never build on top of an existing beam: clear the tracked one and anything tagged first
	destroyAll(kind, "rebuild")

	local weaponAttachment = Instance.new("Attachment")
	weaponAttachment.Name = kind.AttachmentName
	weaponAttachment.Position = kind.WeaponAttachmentOffset
	weaponAttachment.Visible = false
	CollectionService:AddTag(weaponAttachment, kind.Tag)
	weaponAttachment.Parent = weaponPart

	local playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = kind.AttachmentName
	playerAttachment.Position = hitbox.CFrame:VectorToObjectSpace(PLAYER_ATTACHMENT_OFFSET)
	playerAttachment.Visible = false
	CollectionService:AddTag(playerAttachment, kind.Tag)
	playerAttachment.Parent = hitbox

	local beam = Instance.new("Beam")
	beam.Name = kind.BeamName
	beam.Attachment0 = playerAttachment
	beam.Attachment1 = weaponAttachment
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.FaceCamera = true
	beam.Segments = BEAM_SEGMENTS
	beam.Brightness = BEAM_BRIGHTNESS
	beam.LightEmission = BEAM_LIGHT_EMISSION
	beam.LightInfluence = BEAM_LIGHT_INFLUENCE
	beam.ZOffset = BEAM_Z_OFFSET
	beam.TextureSpeed = BEAM_TEXTURE_SPEED
	beam.Color = BEAM_COLOR
	beam.Enabled = true
	kind.configure(beam)
	CollectionService:AddTag(beam, kind.Tag)

	local active: ActiveBeam = {
		Beam = beam,
		WeaponAttachment = weaponAttachment,
		PlayerAttachment = playerAttachment,
		WeaponPart = weaponPart,
		Hitbox = hitbox,
		CreatedAt = os.clock(),
	}
	if kind.onCreate then
		kind.onCreate()
	end
	local transparency = kind.getTransparency(active, 0)
	if transparency then
		beam.Transparency = transparency
	end
	beam.Parent = getContainer()

	kind.Active = active
	debugPrint(kind.Id, "created")
end

-- // True if the kind's tracked beam is still exactly what we built for these inputs and nothing in it has been lost
local function isActiveBeamValid(kind: BeamKind, weaponPart: BasePart, hitbox: BasePart): boolean
	local active = kind.Active
	if not active then
		return false
	end
	return active.WeaponPart == weaponPart
		and active.Hitbox == hitbox
		and active.Beam.Parent ~= nil
		and active.Beam.Attachment0 == active.PlayerAttachment
		and active.Beam.Attachment1 == active.WeaponAttachment
		and active.WeaponAttachment.Parent == weaponPart
		and active.PlayerAttachment.Parent == hitbox
end

local function countBeams(kind: BeamKind): number
	local beamCount = 0
	for _, instance in CollectionService:GetTagged(kind.Tag) do
		if instance:IsA("Beam") then
			beamCount += 1
		end
	end
	return beamCount
end

-------------------------------------------------------------------------------
-- BEAM KINDS
-------------------------------------------------------------------------------

local deadKind: BeamKind = {
	Id = "Dead",
	Tag = "DeadWeaponBeamObject",
	BeamName = "BeamToDeadWeapon",
	AttachmentName = "DeadWeaponBeamAttachment",
	WeaponAttachmentOffset = WEAPON_ATTACHMENT_OFFSET,
	Active = nil,

	-- // The beam's whole life cycle (T-094): ONE beam exists from the moment the local player's boomerang dies until it is back in
	-- // their hands. It is the same beam through every dead -> recall charge -> returning -> dropped (released) -> dead again round, so
	-- // it is only built the first time (the boomerang's host part stays the same, so isActiveBeamValid keeps matching it) and it
	-- // only turns invisible in between (getDeadTarget). It is removed once the boomerang is neither dead nor being recalled
	-- // from the dead, i.e. caught / removed.
	getWeaponPart = function(): BasePart?
		local deadWeaponData = DeadWeapons.Data[localPlayer]
		if deadWeaponData then
			return getWeaponPart(deadWeaponData.Host)
		end
		local thrownWeaponData = ThrownWeapons.Data[localPlayer]
		if thrownWeaponData and thrownWeaponData.RecallFromDead ~= nil then
			return getWeaponPart(thrownWeaponData.Host)
		end
		return nil
	end,

	configure = function(beam: Beam)
		beam.Texture = DEAD_TEXTURE
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = getDeadTileLength()
		beam.Width0 = DEAD_WIDTH
		beam.Width1 = DEAD_WIDTH
	end,

	-- // The current opacity, advanced once per frame by `step` (called from reconcileKind)
	getTransparency = function(_active: ActiveBeam, _deltaTime: number): NumberSequence?
		return buildDeadTransparency(deadOpacity)
	end,

	onCreate = function()
		deadOpacity = 0 -- // A new beam fades in from invisible
	end,

	step = function(wanted: boolean, deltaTime: number)
		stepDeadOpacity(wanted, deltaTime)
	end,

	isFadedOut = function(): boolean
		return deadOpacity <= 0.001
	end,

	reset = function()
		deadOpacity = 0
	end,
}

local returningKind: BeamKind = {
	Id = "Returning",
	Tag = "ReturningWeaponBeamObject",
	BeamName = "BeamToReturningWeapon",
	AttachmentName = "ReturningWeaponBeamAttachment",
	WeaponAttachmentOffset = RETURNING_WEAPON_ATTACHMENT_OFFSET,
	Active = nil,

	-- // The local player's own boomerang while a charged manual recall is moving it back to them, until it is caught
	getWeaponPart = function(): BasePart?
		local thrownWeaponData = ThrownWeapons.Data[localPlayer]
		if thrownWeaponData and thrownWeaponData.RecallFromDead == true then
			return getWeaponPart(thrownWeaponData.Host)
		end
		return nil
	end,

	configure = function(beam: Beam)
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = RETURNING_TEXTURE_LENGTH
		beam.Width0 = RETURNING_WIDTH
		beam.Width1 = RETURNING_WIDTH
	end,

	-- // Fades in from fully transparent to the reference's transparency
	getTransparency = function(active: ActiveBeam, _deltaTime: number): NumberSequence?
		local fadeSeconds = math.max(GlobalConfig.RecallReturnBeamFadeInSeconds, 0.001)
		local fadeAlpha = math.clamp((os.clock() - active.CreatedAt) / fadeSeconds, 0, 1)
		if active.FadeDone then
			return nil
		end
		if fadeAlpha >= 1 then
			active.FadeDone = true
		end
		return buildReturningTransparency(fadeAlpha)
	end,

	reset = nil,
}

local beamKinds: { BeamKind } = { deadKind, returningKind }

-- // Compares what should exist with what does, for one kind, and fixes the difference
local function reconcileKind(kind: BeamKind, deltaTime: number)
	local weaponPart = kind.getWeaponPart()
	local hitbox: BasePart? = if weaponPart then getLocalHitbox() else nil

	if not weaponPart or not hitbox then
		-- // Nothing should be shown any more. A fading beam whose parts still exist keeps fading out before it is removed (it comes back
		-- // smoothly if the boomerang is Dead again in the meantime: the branch below then finds it valid); otherwise, e.g. the
		-- // boomerang was removed or the player died, it can't be drawn any more and goes at once.
		local active = kind.Active
		if kind.step and active and active.Beam.Parent and active.WeaponPart.Parent and active.Hitbox.Parent
			and active.WeaponAttachment.Parent == active.WeaponPart and active.PlayerAttachment.Parent == active.Hitbox then
			kind.step(false, deltaTime)
			if not (kind.isFadedOut and kind.isFadedOut()) then
				local fadingTransparency = kind.getTransparency(active, deltaTime)
				if fadingTransparency then
					active.Beam.Transparency = fadingTransparency
				end
				return
			end
		end
		-- // Remove the tracked beam, and any untracked leftover of this kind
		if kind.Active or #CollectionService:GetTagged(kind.Tag) > 0 then
			destroyAll(kind, "no weapon")
		end
		if kind.reset then
			kind.reset()
		end
		return
	end

	if isActiveBeamValid(kind, weaponPart, hitbox) then
		local active = kind.Active :: ActiveBeam
		if kind.step then
			kind.step(true, deltaTime)
		end
		local transparency = kind.getTransparency(active, deltaTime)
		if transparency then
			active.Beam.Transparency = transparency
		end
		if DEBUG then
			local beamCount = countBeams(kind)
			if beamCount > 1 then
				warn("[DeadWeaponBeam] more than one", kind.Id, "beam exists:", beamCount)
				destroyAll(kind, "duplicate beams")
			end
		end
		return
	end

	createBeam(kind, weaponPart, hitbox)
end

local function reconcile(deltaTime: number)
	for _, kind in beamKinds do
		reconcileKind(kind, deltaTime)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Debug helper: how many beams exist right now (should be 0, or 1 of each kind; never both at the same time in practice)
function DeadWeaponBeamController.getBeamCount(): number
	local total = 0
	for _, kind in beamKinds do
		total += countBeams(kind)
	end
	return total
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function DeadWeaponBeamController.init()
	-- // Clean slate (e.g. leftovers from a previous run of this script in Studio)
	for _, kind in beamKinds do
		destroyAll(kind, "init")
	end
end

function DeadWeaponBeamController.start()
	RunService.RenderStepped:Connect(reconcile)
end

return DeadWeaponBeamController
