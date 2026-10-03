-- // Shared lobby checks, usable on the server and the client

local LobbyLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--- True if the character's pivot is inside the lobby volume (workspace.Lobby.LobbyVolume, collision group LobbyVolume)
function LobbyLibrary.isCharacterInLobby(character: Model?): boolean
	if not character then
		return false
	end

	local params = OverlapParams.new()
	params.CollisionGroup = CollisionGroupConstants.LobbyVolume
	local partsInVolume = workspace:GetPartBoundsInBox(character:GetPivot(), Vector3.new(1, 1, 1), params)
	return next(partsInVolume) ~= nil
end

--- Jumping is enabled only in the lobby (dash replaces it in the arena). Run on BOTH the server and the owning client:
--- with Workspace.AuthorityMode = Server the server simulates the character, so a jump only enabled on the client gets
--- predicted and then corrected (T-070).
function LobbyLibrary.applyJumpState(humanoid: Humanoid, isInLobby: boolean)
	local jumpHeight = if isInLobby then GlobalConfig.LobbyJumpHeight else 0
	if humanoid.UseJumpPower then
		humanoid.UseJumpPower = false
	end
	if humanoid.JumpHeight ~= jumpHeight then
		humanoid.JumpHeight = jumpHeight
	end
	if humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) ~= isInLobby then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, isInLobby)
	end
end

return LobbyLibrary
