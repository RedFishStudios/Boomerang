--[[
	AuthorityViewLibrary

	Description:
	Debug view of where the SERVER thinks a thrown (or dying) boomerang is. While it is enabled, the server keeps one
	neon red ball per player's boomerang at the server-side position, sized to the weapon's hitbox
	(Tools[toolId].Boomerang.HitboxRadius, so the ball's diameter is twice the radius). Because the ball is a server-made
	part it replicates to every client, so comparing it with the client's rendered boomerang shows any client-server desync.

	The default comes from GlobalConfig.ToggleAuthorityView; the Cmdr command `toggleauthorityview` changes it live for this
	server session only (not saved). The enabled flag is server-side state: the weapon logics in Shared/Logics/WeaponLogics
	call update() every time the server moves a boomerang and clear() when it leaves the field; both do nothing on a client.
]]

local AuthorityViewLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local FOLDER_NAME = "AuthorityView"
local BALL_COLOR = Color3.fromRGB(255, 0, 0)
local BALL_TRANSPARENCY = 0.35
local FALLBACK_RADIUS = 1.5 -- // For a tool without Boomerang stats

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()
local enabled: boolean = GlobalConfig.ToggleAuthorityView
local balls: { [number]: Part } = {} -- // By the boomerang owner's UserId
local folder: Folder? = nil

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

local function getRadius(toolId: string?): number
	local toolData = toolId and Tools[toolId]
	return if toolData and toolData.Boomerang then toolData.Boomerang.HitboxRadius else FALLBACK_RADIUS
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function AuthorityViewLibrary.isEnabled(): boolean
	return enabled
end

-- // Server only. Turning it off removes every ball at once.
function AuthorityViewLibrary.setEnabled(value: boolean)
	assert(isServer, "AuthorityViewLibrary.setEnabled is server only")
	enabled = value
	if not value then
		for userId, ball in balls do
			ball:Destroy()
			balls[userId] = nil
		end
	end
end

-- // Server only. Moves (creating it if needed) the owner's ball to the position the server has for their boomerang.
function AuthorityViewLibrary.update(ownerUserId: number?, toolId: string?, position: Vector3)
	if not isServer or not enabled or not ownerUserId then
		return
	end

	local ball = balls[ownerUserId]
	if not ball or not ball.Parent then
		ball = Instance.new("Part")
		ball.Name = `AuthorityView_{ownerUserId}`
		ball.Shape = Enum.PartType.Ball
		ball.Material = Enum.Material.Neon
		ball.Color = BALL_COLOR
		ball.Transparency = BALL_TRANSPARENCY
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.CastShadow = false
		ball.Parent = getFolder()
		balls[ownerUserId] = ball
	end

	local diameter = getRadius(toolId) * 2
	ball.Size = Vector3.new(diameter, diameter, diameter)
	ball.Position = position
end

-- // Server only. Removes the owner's ball (their boomerang left the field).
function AuthorityViewLibrary.clear(ownerUserId: number?)
	if not isServer or not ownerUserId then
		return
	end
	local ball = balls[ownerUserId]
	if ball then
		ball:Destroy()
		balls[ownerUserId] = nil
	end
end

return AuthorityViewLibrary
