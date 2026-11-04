--[[
	TopDownCameraLibrary

	Description:
	Live overrides of the top-down camera, set from Cmdr (topdowncam tilt | fov | distance) for testing.
	Stored as attributes on ReplicatedStorage, so the server sets them and every client's camera (CustomCameraController)
	reads them each frame. This server only, not saved. nil = the default in CustomCameraController.
	  - Tilt: degrees the camera leans back from straight down (0 = straight down)
	  - FieldOfView: the narrow vertical field of view it aims for (it still opens up if needed to stay in range)
	  - Distance: a fixed distance in studs (still within 300 of the character); nil = automatic, fitted to the action
]]

local TopDownCameraLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local ATTRIBUTES = {
	Tilt = "TopDownCameraTilt",
	FieldOfView = "TopDownCameraFieldOfView",
	Distance = "TopDownCameraDistance",
}

-- // Allowed ranges (the commands reject anything outside them)
TopDownCameraLibrary.TILT_RANGE = { 0, 80 }
TopDownCameraLibrary.FIELD_OF_VIEW_RANGE = { 1, 90 }
TopDownCameraLibrary.DISTANCE_RANGE = { 10, 300 }

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Setting = "Tilt" | "FieldOfView" | "Distance"

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The override for a setting, or nil when it uses the default
function TopDownCameraLibrary.get(setting: Setting): number?
	local value = ReplicatedStorage:GetAttribute(ATTRIBUTES[setting])
	return if type(value) == "number" then value else nil
end

-- // SERVER: set (or clear with nil) a setting's override for everyone in this server
function TopDownCameraLibrary.set(setting: Setting, value: number?)
	assert(RunService:IsServer(), "TopDownCameraLibrary.set is server only")
	ReplicatedStorage:SetAttribute(ATTRIBUTES[setting], value)
end

return TopDownCameraLibrary
