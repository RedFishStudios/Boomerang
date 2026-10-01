-- // Shared lobby checks, usable on the server and the client

local LobbyLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)

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

return LobbyLibrary
