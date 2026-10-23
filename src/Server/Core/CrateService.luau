--[[
	CrateService (T-112, T-114)

	Description:
	Buying a weapon crate (Shared/Referential/Crates) from the Weapons Shop: the Currency is spent and a weapon of the
	crate's category is rolled with CrateLibrary (weighted by Tools.CrateWeight). Called by ShopService for "Crate" listings.

	T-114: the weapon isn't given right away. A copy of the crate model is put in the world next to the player
	(findCrateSpot), and the player opens it by clicking / tapping it GlobalConfig.CrateClicksToOpen times (a ClickDetector:
	only the owner's clicks count, counted here on the server). Opening grants the rolled skin (SkinService) and tells the
	owner's client (CrateOpened event: skin id + whether it was new); the client shows the clicks left, a hit bounce and the
	opening pop (Client/Core/CrateOpeningController).
	A crate never opened is still given: when the player leaves (ProfileRemovingTasks, while the data still saves).
	Duplicates: rolling a weapon the player already owns still costs the crate and gives nothing more for now.
	TODO: decide what a duplicate gives (refund, currency, shards...).
]]

local CrateService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CrateLibrary = require(ReplicatedStorage.Shared.Library.CrateLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)
local SkinService = require(ServerStorage.Server.Core.SkinService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

CrateService.FOLDER_NAME = "PlacedCrates" -- // workspace folder holding the crates waiting to be opened
CrateService.OPENED_EVENT = "CrateOpened" -- // server -> owner: (crateInstanceId, skinId, isNew)

-- // Where a crate is put: in front of the player first, then around them (findCrateSpot)
local SPOT_DISTANCES = { 6, 8, 4.5, 10 } -- // Studs from the player, tried in this order
local SPOT_ANGLES = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 } -- // Degrees from where the player faces
local SPOT_RAY_START_HEIGHT = 8 -- // Rays start this far above the player's feet (under most ceilings)
local SPOT_RAY_LENGTH = 40
local SPOT_LEVEL_TOLERANCE = 2 -- // Ground within this many studs of the player's floor counts as level with them
local SPOT_CLEARANCE = 0.25 -- // Extra room checked around the crate
local CLICK_DETECTOR_DISTANCE = 60
local MIN_CLICK_INTERVAL = 1 / 25 -- // Faster clicks are ignored (auto-clickers)
local OPENED_REMOVE_DELAY = 0.6 -- // The opened crate stays this long so clients can play the pop

-------------------------------------------------------------------------------
-- TYPES / PRIVATE VARIABLES
-------------------------------------------------------------------------------

type PlacedCrate = {
	Id: string,
	Owner: Player,
	CrateId: string,
	SkinId: string,
	Model: Model,
	ClicksLeft: number,
	LastClickAt: number,
	Opened: boolean,
}

local rng = Random.new()
local placedCrates: { [string]: PlacedCrate } = {}
local nextCrateNumber = 0
local crateOpenedEvent = SimpleRemotes.getEvent(CrateService.OPENED_EVENT)

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getFolder(): Folder
	local folder = workspace:FindFirstChild(CrateService.FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CrateService.FOLDER_NAME
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- // Everything a placement ray or space check ignores: every character (players may stand in the way) and the crates
local function getIgnoreList(): { Instance }
	local ignore: { Instance } = { getFolder() }
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer.Character then
			table.insert(ignore, otherPlayer.Character)
		end
	end
	local characters = workspace:FindFirstChild("Characters")
	if characters then
		table.insert(ignore, characters)
	end
	return ignore
end

local function isSolid(part: BasePart): boolean
	return part.CanCollide and part.Transparency < 1
end

-- // Down from above the spot: the first solid surface (non-solid parts are skipped)
local function findGround(x: number, z: number, topY: number, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local filter = table.clone(ignore)
	for _ = 1, 12 do
		params.FilterDescendantsInstances = filter
		local result = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -SPOT_RAY_LENGTH, 0), params)
		if not result then
			return nil
		end
		if result.Instance:IsA("BasePart") and isSolid(result.Instance) then
			return result.Position
		end
		table.insert(filter, result.Instance)
	end
	return nil
end

-- // True if a crate of this size standing on `ground` would overlap solid environment parts
local function isObstructed(ground: Vector3, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local checkSize = size + Vector3.new(SPOT_CLEARANCE, 0, SPOT_CLEARANCE) * 2
	local center = ground + Vector3.new(0, size.Y / 2 + 0.05, 0) -- // Just above the floor, so the floor itself doesn't count
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), checkSize - Vector3.new(0, 0.1, 0), params) do
		if isSolid(part) then
			return true
		end
	end
	return false
end

-- // True if a wall stands between the player and the spot (so a crate isn't put behind it)
local function isBehindWall(fromPosition: Vector3, ground: Vector3, size: Vector3, ignore: { Instance }): boolean
	local target = ground + Vector3.new(0, size.Y / 2, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = workspace:Raycast(fromPosition, target - fromPosition, params)
	return result ~= nil and result.Instance:IsA("BasePart") and isSolid(result.Instance)
end

-- // Where to put a crate for this player: in front of them if that spot is open and level with them, otherwise the first open,
-- // level spot around them (SPOT_DISTANCES x SPOT_ANGLES). If none is both, the open spot closest to their height; if none is
-- // open, the level spot in front (or right in front of them at their floor height).
local function findCrateSpot(player: Player, size: Vector3): (Vector3, Vector3)
	local character = player.Character
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart) :: BasePart?
	local ignore = getIgnoreList()
	if not root then
		return Vector3.zero, Vector3.new(0, 0, -1)
	end

	local rootPosition = root.Position
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local playerFloor = findGround(rootPosition.X, rootPosition.Z, rootPosition.Y, ignore)
	local floorY = if playerFloor then playerFloor.Y else rootPosition.Y - 3
	local topY = floorY + SPOT_RAY_START_HEIGHT

	local bestOpen: Vector3? = nil
	local bestOpenHeightDiff = math.huge
	local frontLevel: Vector3? = nil
	for _, distance in SPOT_DISTANCES do
		for _, angle in SPOT_ANGLES do
			local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(look)
			local candidate = rootPosition + direction * distance
			local ground = findGround(candidate.X, candidate.Z, topY, ignore)
			if not ground then
				continue
			end
			local heightDiff = math.abs(ground.Y - floorY)
			local open = not isObstructed(ground, size, ignore) and not isBehindWall(rootPosition, ground, size, ignore)
			if open and heightDiff <= SPOT_LEVEL_TOLERANCE then
				return ground, direction
			end
			if open and heightDiff < bestOpenHeightDiff then
				bestOpen = ground
				bestOpenHeightDiff = heightDiff
			end
			if not frontLevel and angle == 0 and heightDiff <= SPOT_LEVEL_TOLERANCE then
				frontLevel = ground
			end
		end
	end
	local fallback = bestOpen or frontLevel or Vector3.new(rootPosition.X, floorY, rootPosition.Z) + look * SPOT_DISTANCES[1]
	return fallback, (Vector3.new(fallback.X, 0, fallback.Z) - Vector3.new(rootPosition.X, 0, rootPosition.Z)).Unit
end

local function grantContents(placed: PlacedCrate): boolean
	local isNew = not SkinService.ownsSkin(placed.Owner, placed.SkinId)
	if isNew then
		SkinService.grantSkin(placed.Owner, placed.SkinId) -- // The client shows "New skin acquired!" when it replicates
	end
	return isNew
end

local function openCrate(placed: PlacedCrate)
	if placed.Opened then
		return
	end
	placed.Opened = true
	placedCrates[placed.Id] = nil
	placed.Model:SetAttribute("Opened", true)
	local isNew = grantContents(placed)
	if placed.Owner.Parent then
		crateOpenedEvent:FireClient(placed.Owner, placed.Id, placed.SkinId, isNew)
	end
	task.delay(OPENED_REMOVE_DELAY, function()
		placed.Model:Destroy()
	end)
end

local function onCrateClicked(placed: PlacedCrate, clicker: Player)
	if clicker ~= placed.Owner or placed.Opened then
		return
	end
	local now = os.clock()
	if now - placed.LastClickAt < MIN_CLICK_INTERVAL then
		return
	end
	placed.LastClickAt = now
	placed.ClicksLeft -= 1
	placed.Model:SetAttribute("ClicksLeft", placed.ClicksLeft)
	if placed.ClicksLeft <= 0 then
		openCrate(placed)
	end
end

-- // Puts the crate model in the world next to the player, ready to be clicked open
local function placeCrate(player: Player, crateId: string, skinId: string): boolean
	local crate = CrateLibrary.getCrate(crateId)
	local assets = ReplicatedStorage.Shared:FindFirstChild("Assets")
	local template = crate and assets and assets:FindFirstChild("Crates") and assets.Crates:FindFirstChild(crate.Model)
	if not (template and template:IsA("Model")) then
		warn(`CrateService: crate model {crate and crate.Model} not found in Shared.Assets.Crates`)
		return false
	end

	local model = template:Clone()
	local boundsCFrame, size = model:GetBoundingBox()
	local pivotToBottom = model:GetPivot().Position.Y - (boundsCFrame.Position.Y - size.Y / 2)
	local ground, towardSpot = findCrateSpot(player, size)
	-- // Standing on the ground, facing back toward the player
	local position = ground + Vector3.new(0, pivotToBottom, 0)
	model:PivotTo(CFrame.lookAt(position, position - towardSpot))

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false -- // Never traps or blocks anyone
			descendant.CanTouch = false
			descendant.CanQuery = true -- // ClickDetector needs it
		end
	end

	nextCrateNumber += 1
	local placedId = `{player.UserId}_{nextCrateNumber}`
	local placed: PlacedCrate = {
		Id = placedId,
		Owner = player,
		CrateId = crateId,
		SkinId = skinId,
		Model = model,
		ClicksLeft = GlobalConfig.CrateClicksToOpen,
		LastClickAt = 0,
		Opened = false,
	}
	model.Name = `Crate_{placedId}`
	model:SetAttribute("PlacedCrateId", placedId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("ClicksLeft", placed.ClicksLeft)
	model:SetAttribute("ClicksToOpen", GlobalConfig.CrateClicksToOpen)

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = CLICK_DETECTOR_DISTANCE
	clickDetector.MouseClick:Connect(function(clicker: Player)
		onCrateClicked(placed, clicker)
	end)
	clickDetector.Parent = model

	placedCrates[placedId] = placed
	model.Parent = getFolder()
	return true
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Returns success. The weapon is given when the placed crate is opened (or when the player leaves).
function CrateService.purchaseCrate(player: Player, crateId: string): boolean
	local crate = CrateLibrary.getCrate(crateId)
	if not crate or crate.OffSale or not PlayerDataService.get(player) or not player.Character then
		return false
	end
	if #CrateLibrary.getEntries(crateId) == 0 then
		warn(`CrateService: {crateId} has nothing to give (no tools of category {crate.Category} with a CrateWeight and a skin)`)
		return false
	end
	if not EconomyService.spendCurrency(player, crate.Price) then
		return false
	end

	local entry = CrateLibrary.roll(crateId, rng)
	if not entry or not placeCrate(player, crateId, entry.SkinId) then
		EconomyService.addCurrency(player, crate.Price) -- // Never charge for nothing
		return false
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CrateService.init()
	-- // Unopened crates are given when the player leaves, while their data still saves; their models go away
	PlayerDataService.ProfileRemovingTasks:Add(function(player: Player)
		for placedId, placed in placedCrates do
			if placed.Owner == player then
				placedCrates[placedId] = nil
				placed.Opened = true
				grantContents(placed)
				placed.Model:Destroy()
			end
		end
	end)
end

function CrateService.start() end

return CrateService
