--[[
	ArrowEffect

	Description:
	The shared implementation of arrow-style charge up effects: the arrow shown on the ground in front of a player while
	they charge a throw. It is not an effect id itself; an effect module (e.g. DefaultChargeUpEffect) calls
	`ArrowEffect.apply` with its own arrow template, so different effects can show a different arrow visual.
	Returns the handle shape described by ChargeUpEffectLibrary.ChargeUpEffectHandle.
	Client only in practice (it makes instances in Workspace); the effect modules call it from `apply`.
]]

local ArrowEffect = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local ChargeUpEffectLibrary = require(ReplicatedStorage.Shared.Library.ChargeUpEffectLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local START_SIZE_SCALE = 0.7 -- // The arrow starts at this fraction of its template size and grows to full size
local ARROW_BASE_DISTANCE = 3 -- // Studs in front of the character at zero charge
local ARROW_DISTANCE_PER_STRENGTH = 2.5 -- // Extra distance multiplier at full strength (times GlobalConfig.AimFullStrength)
local ARROW_HEIGHT_OFFSET = -2 -- // The arrow sits this far below the root part
local SHAKE_START_ALPHA = 0.8 -- // Charge progress at which the arrow starts to shake
local SHAKE_MAX_OFFSET_SCALE = 0.25 -- // Shake amplitude as a fraction of the arrow image's default offset
local SHAKE_SPEED = 4.5
local SHAKE_NOISE_SCALE = 0.11

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- Clones `template` (a Model whose PrimaryPart has a SurfaceGui > CanvasGroup > Arrows frame) into Workspace for the
--- player and returns its handle. `update` sizes, fades, places and shakes the arrow from the charge progress;
--- `remove` destroys it.
function ArrowEffect.apply(template: Model, player: Player): ChargeUpEffectLibrary.ChargeUpEffectHandle
	local arrow = template:Clone()
	arrow.Name = `ChargeUpEffect_{player.UserId}`
	arrow.Parent = workspace
	local primaryPart = arrow.PrimaryPart :: BasePart
	primaryPart.Anchored = true

	local fullSize = template.PrimaryPart.Size
	local startSize = fullSize * START_SIZE_SCALE
	local shakingFrame = primaryPart.SurfaceGui.CanvasGroup.Arrows
	local defaultPosition = template.PrimaryPart.SurfaceGui.CanvasGroup.Arrows.Position

	local handle = {} :: ChargeUpEffectLibrary.ChargeUpEffectHandle

	function handle.update(_self, frame: ChargeUpEffectLibrary.ChargeUpFrame)
		local alpha = frame.Alpha
		primaryPart.Size = startSize:Lerp(fullSize, alpha)
		primaryPart.SurfaceGui.CanvasGroup.GroupTransparency = 1 - alpha

		local lookVector = frame.AimCFrame.LookVector
		local distance = ARROW_BASE_DISTANCE + ((GlobalConfig.AimFullStrength * alpha) * ARROW_DISTANCE_PER_STRENGTH)
		local arrowPosition = frame.RootPart.Position + Vector3.new(0, ARROW_HEIGHT_OFFSET, 0) + (lookVector.Unit * distance)
		arrow:PivotTo(CFrame.new(arrowPosition, arrowPosition + lookVector))

		-- // Shaking
		if alpha > SHAKE_START_ALPHA then
			local now = os.clock()
			local shakeAlpha = (alpha - SHAKE_START_ALPHA) / (1 - SHAKE_START_ALPHA)
			local defaultOffsetMagnitude = math.max(1, math.abs(defaultPosition.X.Offset) + math.abs(defaultPosition.Y.Offset))
			local shakePixels = defaultOffsetMagnitude * SHAKE_MAX_OFFSET_SCALE * shakeAlpha

			-- // Smooth noise so the direction shifts fluidly over multiple frames
			local shakeX = (math.noise(player.UserId * SHAKE_NOISE_SCALE, now * SHAKE_SPEED, 0) * shakePixels) * 100
			local shakeY = (math.noise((player.UserId + 97) * SHAKE_NOISE_SCALE, now * SHAKE_SPEED, 0) * shakePixels) * 100
			shakingFrame.Position = UDim2.new(
				defaultPosition.X.Scale,
				defaultPosition.X.Offset + shakeX,
				defaultPosition.Y.Scale,
				defaultPosition.Y.Offset + shakeY
			)
		else
			shakingFrame.Position = defaultPosition
		end
	end

	function handle.remove(_self)
		arrow:Destroy()
	end

	return handle
end

return ArrowEffect
