local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

local MovementConstants = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

MovementConstants.WalkSpeed = GlobalConfig.DefaultWalkSpeed -- // Static copy; for the live value (Cmdr can change it) use WalkSpeedLibrary.getDefault()
MovementConstants.SprintSpeed = 24

return MovementConstants
