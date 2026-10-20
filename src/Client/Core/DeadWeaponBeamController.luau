--[[
	DeadWeaponBeamController

	While the LOCAL player's own boomerang is Dead (resting on the field, waiting for a manual recall), a beam connects the
	boomerang to the player so they can find it. Only the local client ever sees it: other players' dead weapons get no beam.

	The beam is built from scratch here (the `BeamToDeadWeapon` instance in the Studio workspace is only a visual reference
	and is never used at runtime):
	  - Attachment0 sits on the boomerang's PrimaryPart (or the first BasePart found in its model), offset (0, 1, 0).
	  - Attachment1 sits on the local character's `Hitbox` (HitboxService), offset 2 studs straight up.
	    (The Hitbox is a cylinder rotated 90 degrees, so its local "up" is not world up: the offset is converted
	    into the Hitbox's own space once, when the beam is built.)

	One beam at a time, by design (a "single source of truth" instead of event-driven create/destroy):
	  - Every frame `reconcile()` compares what SHOULD exist (derived from DeadWeapons.Data) with what DOES exist and fixes
	    the difference. Late, duplicated or missing events therefore can't leave a stray beam or a missing one.
	  - Everything this module creates is tagged. Before building a beam, and whenever a beam is torn down, every tagged
	    instance is destroyed, so even a leaked beam from an earlier (failed) build is swept up.
	  - Set DEBUG to true to print every create/destroy and to warn if more than one beam is ever found.
]]

local DeadWeaponBeamController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DeadWeapons = require(ReplicatedStorage.Shared.Referential.DeadWeapons)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEBUG = false

local TAG = "DeadWeaponBeamObject" -- // Put on the beam, both attachments and the container folder
local CONTAINER_NAME = "DeadWeaponBeams"
local BEAM_NAME = "BeamToDeadWeapon"
local ATTACHMENT_NAME = "DeadWeaponBeamAttachment"

-- // Attachment offsets (from the BeamToDeadWeapon reference): boomerang (0, 1, 0), player (0, 2, 0)
local WEAPON_ATTACHMENT_OFFSET = Vector3.new(0, 1, 0) -- // In the boomerang part's own space
local PLAYER_ATTACHMENT_OFFSET = Vector3.new(0, 2, 0) -- // In WORLD-upright terms, converted to the Hitbox's space

-- // Beam look (copied from the BeamToDeadWeapon reference)
local BEAM_TEXTURE = "rbxassetid://75521069157462"
local BEAM_WIDTH = 6
local TEXTURE_ASPECT_RATIO = 1 -- // The beam texture image is square (1:1): one tile is as long as it is wide
local BEAM_TEXTURE_SPEED = 1
local BEAM_SEGMENTS = 100
local BEAM_BRIGHTNESS = 1
local BEAM_LIGHT_EMISSION = 0
local BEAM_LIGHT_INFLUENCE = 1
local BEAM_Z_OFFSET = 0
local BEAM_COLOR = ColorSequence.new(Color3.new(1, 1, 1))
local BEAM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.10109288990497589, 0.5061728358268738),
	NumberSequenceKeypoint.new(0.8989070653915405, 0.4938271641731262),
	NumberSequenceKeypoint.new(1, 1),
})

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ActiveBeam = {
	Beam: Beam,
	WeaponAttachment: Attachment,
	PlayerAttachment: Attachment,
	DeadWeaponData: DeadWeapons.Data, -- // The exact Data table this beam was built for (identity check)
	WeaponPart: BasePart,
	Hitbox: BasePart,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local activeBeam: ActiveBeam? = nil
local container: Folder? = nil

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
	CollectionService:AddTag(folder, TAG)
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

-- // Destroys the tracked beam AND every tagged leftover. Safe to call at any time, any number of times.
local function destroyAll(reason: string)
	local hadSomething = activeBeam ~= nil
	activeBeam = nil

	for _, instance in CollectionService:GetTagged(TAG) do
		if instance ~= container then
			instance:Destroy()
			hadSomething = true
		end
	end

	if hadSomething then
		debugPrint("destroyed:", reason)
	end
end

-- // In Static (and Wrap) texture mode, TextureLength is the length of ONE texture tile in studs (verified in Studio). It does
-- // not depend on how far apart the ends are: the pattern simply repeats along the beam, and the last tile is cut off.
-- // For a square (1:1) image to look undistorted, a tile must be as long as the beam is wide, so with width 6 it is 6 studs.
local function getTileLength(): number
	return BEAM_WIDTH * TEXTURE_ASPECT_RATIO
end

local function createBeam(deadWeaponData: DeadWeapons.Data, weaponPart: BasePart, hitbox: BasePart)
	-- // Never build on top of an existing beam: clear the tracked one and anything tagged first
	destroyAll("rebuild")

	local weaponAttachment = Instance.new("Attachment")
	weaponAttachment.Name = ATTACHMENT_NAME
	weaponAttachment.Position = WEAPON_ATTACHMENT_OFFSET
	weaponAttachment.Visible = false
	CollectionService:AddTag(weaponAttachment, TAG)
	weaponAttachment.Parent = weaponPart

	local playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = ATTACHMENT_NAME
	playerAttachment.Position = hitbox.CFrame:VectorToObjectSpace(PLAYER_ATTACHMENT_OFFSET)
	playerAttachment.Visible = false
	CollectionService:AddTag(playerAttachment, TAG)
	playerAttachment.Parent = hitbox

	local beam = Instance.new("Beam")
	beam.Name = BEAM_NAME
	beam.Attachment0 = playerAttachment
	beam.Attachment1 = weaponAttachment
	beam.Texture = BEAM_TEXTURE
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = getTileLength()
	beam.TextureSpeed = BEAM_TEXTURE_SPEED
	beam.Width0 = BEAM_WIDTH
	beam.Width1 = BEAM_WIDTH
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.FaceCamera = true
	beam.Segments = BEAM_SEGMENTS
	beam.Brightness = BEAM_BRIGHTNESS
	beam.LightEmission = BEAM_LIGHT_EMISSION
	beam.LightInfluence = BEAM_LIGHT_INFLUENCE
	beam.ZOffset = BEAM_Z_OFFSET
	beam.Color = BEAM_COLOR
	beam.Transparency = BEAM_TRANSPARENCY
	beam.Enabled = true
	CollectionService:AddTag(beam, TAG)
	beam.Parent = getContainer()

	activeBeam = {
		Beam = beam,
		WeaponAttachment = weaponAttachment,
		PlayerAttachment = playerAttachment,
		DeadWeaponData = deadWeaponData,
		WeaponPart = weaponPart,
		Hitbox = hitbox,
	}
	debugPrint("created")
end

-- // True if the tracked beam is still exactly what we built for these inputs and nothing in it has been lost
local function isActiveBeamValid(deadWeaponData: DeadWeapons.Data, weaponPart: BasePart, hitbox: BasePart): boolean
	local active = activeBeam
	if not active then
		return false
	end
	return active.DeadWeaponData == deadWeaponData
		and active.WeaponPart == weaponPart
		and active.Hitbox == hitbox
		and active.Beam.Parent ~= nil
		and active.Beam.Attachment0 == active.PlayerAttachment
		and active.Beam.Attachment1 == active.WeaponAttachment
		and active.WeaponAttachment.Parent == weaponPart
		and active.PlayerAttachment.Parent == hitbox
end

-- // Compares what should exist with what does, and fixes the difference (runs every frame, cheap when nothing changes)
local function reconcile()
	local deadWeaponData = DeadWeapons.Data[localPlayer]
	local weaponPart: BasePart? = nil
	local hitbox: BasePart? = nil

	if deadWeaponData and deadWeaponData.State == DeadWeapons.StateEnum.Dead then
		weaponPart = getWeaponPart(deadWeaponData.Host)
		hitbox = getLocalHitbox()
	end

	if not deadWeaponData or not weaponPart or not hitbox then
		-- // Nothing should exist: remove the tracked beam, and any untracked leftover still sitting in the container
		if activeBeam or (container and #container:GetChildren() > 0) then
			destroyAll("no dead weapon")
		end
		return
	end

	if isActiveBeamValid(deadWeaponData, weaponPart, hitbox) then
		if DEBUG then
			local beamCount = 0
			for _, instance in CollectionService:GetTagged(TAG) do
				if instance:IsA("Beam") then
					beamCount += 1
				end
			end
			if beamCount > 1 then
				warn("[DeadWeaponBeam] more than one beam exists:", beamCount)
				destroyAll("duplicate beams")
			end
		end
		return
	end

	createBeam(deadWeaponData, weaponPart, hitbox)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Debug helper: how many dead-weapon beams exist right now (should only ever be 0 or 1)
function DeadWeaponBeamController.getBeamCount(): number
	local beamCount = 0
	for _, instance in CollectionService:GetTagged(TAG) do
		if instance:IsA("Beam") then
			beamCount += 1
		end
	end
	return beamCount
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function DeadWeaponBeamController.init()
	-- // Clean slate (e.g. leftovers from a previous run of this script in Studio)
	destroyAll("init")
end

function DeadWeaponBeamController.start()
	RunService.RenderStepped:Connect(reconcile)
end

return DeadWeaponBeamController
