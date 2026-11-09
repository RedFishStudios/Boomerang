--[[
	DeadWeaponBeamController

	Two beams between the LOCAL player and their OWN boomerang, visible only to the local client.

	  1. "Dead" beam (BeamToDeadWeapon): while the boomerang is Dead and waiting for a manual recall. Created once when the
	     boomerang first dies, destroyed when it is back in the player's hands. It fades in once the boomerang lands
	     (GlobalConfig.DeadBeamFadeSeconds), fades out as the recall charges (invisible exactly at the charge peak), stays
	     invisible while the boomerang flies back, and fades back in if the recall is released/cancelled or the boomerang
	     is dead again. It fades out the same way when removed for other reasons, unless the boomerang or character is gone
	     (then it is removed at once).
	  2. "Returning" beam (BeamToReturningWeapon): from when a charged recall starts moving the boomerang until it is
	     caught. Fades in over GlobalConfig.RecallReturnBeamFadeInSeconds.

	Both are built here at runtime; the `BeamToDeadWeapon` / `BeamToReturningWeapon` instances in the Studio workspace are
	visual references only:
	  - Attachment0 is on the local character's `Hitbox` (HitboxService) at offset (0, 0, 0). PLAYER_ATTACHMENT_OFFSET is in
	    world-upright terms, converted to the Hitbox's space because the Hitbox cylinder is rotated 90 degrees.
	  - Attachment1 is on the boomerang's PrimaryPart (or the first BasePart in its model), offset (0, 1, 0).

	One beam of each kind at a time. Every frame `reconcile()` compares what SHOULD exist (from DeadWeapons.Data /
	ThrownWeapons.Data) with what DOES and fixes the difference, so late, duplicated or missing events can't leave a stray or
	missing beam.
	  - Everything a kind creates carries that kind's tag; before building and on teardown every tagged instance is destroyed,
	    sweeping up leaked beams.
	  - DEBUG = true prints every create/destroy and warns if more than one beam of a kind is found.
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

-- // Attachment offsets (from the BeamToDeadWeapon / BeamToReturningWeapon references)
local WEAPON_ATTACHMENT_OFFSET = Vector3.new(0, 1, 0) -- // In the boomerang part's space (the dead beam: a stud above it)
local RETURNING_WEAPON_ATTACHMENT_OFFSET = Vector3.zero -- // The returning beam attaches on the boomerang itself
local PLAYER_ATTACHMENT_OFFSET = Vector3.zero -- // In world-upright terms, converted to the Hitbox's space (zero = Hitbox center)

-- // Look shared by both beams
local BEAM_SEGMENTS = 100
local BEAM_BRIGHTNESS = 1
local BEAM_LIGHT_EMISSION = 0
local BEAM_LIGHT_INFLUENCE = 1
local BEAM_Z_OFFSET = 0
local BEAM_TEXTURE_SPEED = 1
local BEAM_COLOR = ColorSequence.new(Color3.new(1, 1, 1))

-- // Dead beam (from the BeamToDeadWeapon reference)
local DEAD_TEXTURE = "rbxassetid://75521069157462"
local DEAD_WIDTH = 6
local DEAD_TEXTURE_ASPECT_RATIO = 1 -- // Square (1:1) texture: one tile is as long as it is wide
-- // Transparency runs 1 -> middle -> 1 so the beam fades in at the start and out at the end; the middle values are
-- // from the
-- // reference. Scaled by an opacity (1 = reference look, 0 = invisible), see deadOpacity.
local DEAD_TRANSPARENCY_START_TIME = 0.10109288990497589
local DEAD_TRANSPARENCY_END_TIME = 0.8989070653915405
local DEAD_NORMAL_MIDDLE_A = 0.5061728358268738
local DEAD_NORMAL_MIDDLE_B = 0.4938271641731262

-- // Returning beam (from the BeamToReturningWeapon reference: no texture, width 1, Wrap mode, TextureLength 1)
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
	CreatedAt: number, -- // os.clock() when built
	FadeDone: boolean?, -- // Returning beam: fade-in finished (nothing more to update)
}

type BeamKind = {
	Id: string,
	Tag: string, -- // On everything this kind creates (beam + attachments), to sweep leftovers
	BeamName: string,
	AttachmentName: string,
	WeaponAttachmentOffset: Vector3, -- // Where the beam attaches, in the boomerang part's space
	Active: ActiveBeam?,
	-- // The boomerang part the beam should point at, or nil if it should not exist
	getWeaponPart: () -> BasePart?,
	-- // Sets the constant look of a new beam
	configure: (beam: Beam) -> (),
	-- // The current transparency (called on creation and every frame while the beam exists)
	getTransparency: (active: ActiveBeam, deltaTime: number) -> NumberSequence?,
	-- // Resets per-beam state when there is no beam
	reset: (() -> ())?,
	-- // Called right before a new beam is built
	onCreate: (() -> ())?,
	-- // When the boomerang goes away the beam keeps fading out (if it still can) before removal
	step: ((wanted: boolean, deltaTime: number) -> ())?,
	-- // True once a fading-out beam is invisible and can be removed
	isFadedOut: (() -> boolean)?,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local container: Folder? = nil
local deadOpacity = 0 -- // Dead beam: 1 = fully shown, 0 = invisible (see getDeadTarget)

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
	-- // Reuse a leftover folder if the reference was lost, to avoid duplicates
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

-- // The part the attachment goes on: the part itself, or a model's PrimaryPart / first BasePart
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

-- // In Static (and Wrap) texture mode, TextureLength is the length of ONE tile in studs, independent of beam length;
-- // the
-- // pattern repeats and the last tile is cut off. A square (1:1) image is undistorted when a tile is as long as the
-- // beam is
-- // wide (width 6 -> 6 studs).
local function getDeadTileLength(): number
	return DEAD_WIDTH * DEAD_TEXTURE_ASPECT_RATIO
end

-- // opacity 1 = reference transparency, 0 = invisible
local function buildDeadTransparency(opacity: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(DEAD_TRANSPARENCY_START_TIME, 1 - (1 - DEAD_NORMAL_MIDDLE_A) * opacity),
		NumberSequenceKeypoint.new(DEAD_TRANSPARENCY_END_TIME, 1 - (1 - DEAD_NORMAL_MIDDLE_B) * opacity),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- // Target opacity of the dead beam, and whether it is a smooth countdown that opacity should follow exactly.
-- //   charging a recall: 1 -> 0 over GlobalConfig.RecallCharge, reaching 0 exactly at the charge peak (server time, so
-- // all
-- //     machines agree; releasing or restarting the charge just changes the value)
-- //   otherwise: 1 while the boomerang rests dead, 0 when the beam shouldn't be shown
local function getDeadTarget(wanted: boolean): (number, boolean)
	if not wanted then
		return 0, false
	end
	local deadWeaponData = DeadWeapons.Data[localPlayer]
	if not deadWeaponData or deadWeaponData.State ~= DeadWeapons.StateEnum.Dead then
		return 0, false -- // Still dying (sliding to a stop) or flying back: the beam exists but is invisible
	end
	if DeadWeaponLogic.isRecallCharging(deadWeaponData) and deadWeaponData.RecallChargeStart then
		local progress = (workspace:GetServerTimeNow() - deadWeaponData.RecallChargeStart) / DeadWeaponLogic.getRecallChargeSeconds(deadWeaponData)
		return 1 - math.clamp(progress, 0, 1), true
	end
	return 1, false
end

-- // Moves deadOpacity toward the target: never up while a charge is in progress (it follows the countdown down),
-- // otherwise at
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

-- // fadeAlpha 0 = fully transparent, 1 = reference transparency
local function buildReturningTransparency(fadeAlpha: number): NumberSequence
	local keypoints = {}
	for _, point in RETURNING_TRANSPARENCY do
		keypoints[#keypoints + 1] = NumberSequenceKeypoint.new(point.Time, 1 + (point.Value - 1) * fadeAlpha)
	end
	return NumberSequence.new(keypoints)
end

-- // Destroys the kind's tracked beam and every instance carrying its tag. Safe to call repeatedly.
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
	-- // Never build on an existing beam: clear the tracked one and anything tagged first
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

-- // True if the tracked beam still matches what was built for these inputs and nothing in it was lost
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

	-- // Life cycle: ONE beam exists from the boomerang's death until it is back in the player's hands. It persists
	-- // through
	-- // every dead -> recall charge -> returning -> dropped -> dead round: built once (the host part stays the same, so
	-- // isActiveBeamValid keeps matching) and only invisible in between (getDeadTarget). Removed once the boomerang is
	-- // neither dead nor being recalled from the dead (caught / removed).
	getWeaponPart = function(): BasePart?
		local deadWeaponData = DeadWeapons.Data[localPlayer]
		if deadWeaponData then
			return getWeaponPart(deadWeaponData.Host)
		end
		local thrownWeaponData = ThrownWeapons.Data[localPlayer]
		-- // Only a manual (charged) recall keeps the dead beam (invisible while flying back, in case it is dropped
		-- // again).
		-- // An automatic recall (RecallFromDead == false) fades it out and removes it.
		if thrownWeaponData and thrownWeaponData.RecallFromDead == true then
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

	-- // Current opacity, advanced once per frame by `step` (called from reconcileKind)
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

	-- // The local boomerang while a charged manual recall moves it back, until caught
	getWeaponPart = function(): BasePart?
		local thrownWeaponData = ThrownWeapons.Data[localPlayer]
		-- // A predicted catch hides the boomerang until the server confirms; the beam goes with it
		if thrownWeaponData and thrownWeaponData.RecallFromDead == true and not thrownWeaponData.HostHidden then
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

	-- // Fades in from fully transparent to the reference transparency
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
		-- // Nothing should be shown. A fading beam whose parts still exist keeps fading out before removal (it comes
		-- // back
		-- // smoothly if the boomerang is Dead again meanwhile); otherwise (boomerang removed, player died) it goes at
		-- // once.
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
		-- // Remove the tracked beam and any untracked leftover of this kind
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

-- // Debug helper: number of beams that exist (expected 0, or 1 per kind)
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
	-- // Clean slate (e.g. Studio leftovers from a previous run)
	for _, kind in beamKinds do
		destroyAll(kind, "init")
	end
end

function DeadWeaponBeamController.start()
	RunService.RenderStepped:Connect(reconcile)
end

return DeadWeaponBeamController
